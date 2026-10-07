#!/usr/bin/env python3
"""Benchmarks plain Paper against Paper run through Orange, on the same machine.

Usage: benchmark.py <path to orange.jar>

Each server gets an 8 GB heap, the same seed, spark and TAB, and the same scripted load:
256 force-loaded chunks and ~2,000 mobs (a quarter of them villagers, which have the most
expensive AI). Servers run one at a time so they never compete for CPU.
"""
import json
import os
import re
import shutil
import sys
import time
import urllib.parse

sys.path.insert(0, os.path.dirname(__file__))
from server_test import Server, download, fetch_paper, get_json  # noqa: E402

HEAP = "8G"
SEED = "orange-benchmark"
MOBS = ["minecraft:cow", "minecraft:cow", "minecraft:sheep", "minecraft:chicken", "minecraft:villager",
        "minecraft:cow", "minecraft:pig", "minecraft:villager"]


def modrinth_jar(project, game_version, dest_dir):
    """Newest Paper/Bukkit build of a Modrinth project, preferring one tagged for this MC version."""
    base = f"https://api.modrinth.com/v2/project/{project}"
    try:
        info = get_json(base)
        print(f"{project} on Modrinth: loaders={info.get('loaders')} newest versions={info.get('game_versions', [])[-3:]}")
        loaders = urllib.parse.quote(json.dumps(["paper", "bukkit", "spigot", "purpur", "folia"]))
        for query in (f"?loaders={loaders}&game_versions={urllib.parse.quote(json.dumps([game_version]))}",
                      f"?loaders={loaders}"):
            versions = get_json(f"{base}/version{query}")
            if versions:
                file = next((f for f in versions[0]["files"] if f.get("primary")), versions[0]["files"][0])
                print(f"{project}: {versions[0]['version_number']} ({file['filename']}) from Modrinth")
                download(file["url"], os.path.join(dest_dir, file["filename"]))
                return file["filename"]
    except Exception as e:
        print(f"{project}: Modrinth lookup failed: {e!r}")
    return None


def spark_jar(game_version, dest_dir):
    name = modrinth_jar("spark", game_version, dest_dir)
    if name:
        return name
    # spark's own build server (the source of the downloads on spark.lucko.me).
    try:
        build = get_json("https://ci.lucko.me/job/spark/lastSuccessfulBuild/api/json")
        for artifact in build["artifacts"]:
            if re.search(r"spark-.*-(paper|bukkit)\.jar$", artifact["fileName"]):
                url = f"https://ci.lucko.me/job/spark/lastSuccessfulBuild/artifact/{artifact['relativePath']}"
                print(f"spark: {artifact['fileName']} from ci.lucko.me")
                download(url, os.path.join(dest_dir, artifact["fileName"]))
                return artifact["fileName"]
    except Exception as e:
        print(f"spark: ci.lucko.me lookup failed: {e!r}")
    print("spark: no standalone jar found; using the spark that Paper ships built in")
    return None


def tab_jar(game_version, dest_dir):
    name = modrinth_jar("tab-was-taken", game_version, dest_dir)
    if name:
        return name
    try:
        release = get_json("https://api.github.com/repos/NEZNAMY/TAB/releases/latest")
        for asset in release["assets"]:
            if asset["name"].endswith(".jar"):
                print(f"TAB: {asset['name']} from GitHub releases ({release['tag_name']})")
                download(asset["browser_download_url"], os.path.join(dest_dir, asset["name"]))
                return asset["name"]
    except Exception as e:
        print(f"TAB: GitHub releases lookup failed: {e!r}")
    raise SystemExit("could not download TAB")


def spawn_commands():
    """~2,000 mobs on a grid inside the force-loaded area, each placed on the surface."""
    commands = []
    i = 0
    for x in range(-110, 111, 5):
        for z in range(-110, 111, 5):
            mob = MOBS[i % len(MOBS)]
            i += 1
            commands.append(f"execute positioned {x} 0 {z} positioned over world_surface run "
                            f"summon {mob} ~ ~ ~ {{PersistenceRequired:1b}}")
    return commands


def run(label, run_dir, command):
    results = {"label": label}
    # Warm-up boot: generates the world and configs (and lets Orange tune them), like a real server.
    print(f"\n===== {label}: warm-up boot =====", flush=True)
    s = Server(run_dir, os.path.join(run_dir, "warmup.log"), command)
    if not s.wait_for(r"Done \(\d", 900):
        raise SystemExit(f"{label}: warm-up boot failed")
    s.stop()

    print(f"\n===== {label}: measured boot =====", flush=True)
    s = Server(run_dir, os.path.join(run_dir, "bench.log"), command)
    if not s.wait_for(r"Done \(\d", 900):
        raise SystemExit(f"{label}: measured boot failed")
    results["startup"] = re.search(r"Done \(([\d.]+)s\)", "".join(s.lines)).group(1) + " s"

    start = time.time()
    s.send("forceload add -128 -128 127 127")
    s.wait_for(r"[Mm]arked .*force loaded|force loaded", 60)
    time.sleep(60)  # let chunk generation finish
    for c in spawn_commands():
        s.send(c)
    time.sleep(30)  # let mobs settle
    s.send("execute if entity @e")
    s.wait_for(r"Test passed[.,] [Cc]ount: \d+", 60)
    m = re.findall(r"Test passed[.,] [Cc]ount: (\d+)", "".join(s.lines))
    results["entities"] = m[-1] if m else "?"

    mark = len(s.lines)
    s.send("spark profiler start --timeout 60")
    s.wait_for(r"https://spark\.lucko\.me/\w+", 180)
    urls = re.findall(r"https://spark\.lucko\.me/\w+", "".join(s.lines[mark:]))
    results["profile"] = urls[-1] if urls else "(upload failed)"

    mark = len(s.lines)
    s.send("spark tps")
    time.sleep(5)
    s.send("spark health")
    time.sleep(10)
    out = "".join(s.lines[mark:])
    results["raw"] = out
    durations = re.findall(r"(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)", out)
    if durations:
        # spark prints "last 10s" then "last 1m"; the 1m window covers the whole profile.
        mn, med, p95, mx = durations[1] if len(durations) > 1 else durations[0]
        results.update(mspt_median=med, mspt_p95=p95, mspt_max=mx)
    # e.g. "[12:00:00 INFO]: [⚡]  19.89, 19.94, *20.0, 18.43, 19.45" (5s, 10s, 1m, 5m, 15m)
    tps = re.search(r"TPS from last.*\n.*?\]:\s*\S*\s+\*?([\d.]+)\*?,\s*\*?([\d.]+)\*?,\s*\*?([\d.]+)", out)
    if tps:
        results["tps_1m"] = tps.group(3)
    results["elapsed"] = f"{time.time() - start:.0f} s"
    s.stop()
    return results


def prepare(run_dir, paper_jar_dir, paper_name, plugins):
    os.makedirs(os.path.join(run_dir, "plugins"), exist_ok=True)
    shutil.copy(os.path.join(paper_jar_dir, paper_name), os.path.join(run_dir, paper_name))
    for p in plugins:
        shutil.copy(os.path.join(paper_jar_dir, p), os.path.join(run_dir, "plugins", p))
    with open(os.path.join(run_dir, "eula.txt"), "w") as f:
        f.write("eula=true\n")
    with open(os.path.join(run_dir, "server.properties"), "w") as f:
        f.write(f"level-seed={SEED}\nonline-mode=false\n")


def main():
    orange_jar = os.path.abspath(sys.argv[1])
    downloads = os.path.abspath("bench-downloads")
    shutil.rmtree(downloads, ignore_errors=True)
    os.makedirs(downloads)
    paper = fetch_paper(downloads)
    mc_version = re.match(r"paper-(.+)-\d+\.jar", paper).group(1)
    plugins = [p for p in (spark_jar(mc_version, downloads), tab_jar(mc_version, downloads)) if p]
    print(f"Plugins for both servers: {plugins} (spark is built into Paper if it isn't listed)")

    runs = []
    # 1. Plain Paper, started the way most people start it.
    d = os.path.abspath("bench-paper")
    shutil.rmtree(d, ignore_errors=True)
    prepare(d, downloads, paper, plugins)
    runs.append(run("Paper", d, ["java", f"-Xms{HEAP}", f"-Xmx{HEAP}", "-jar", paper, "nogui"]))

    # 2./3. The same Paper jar through Orange, with the default (vanilla) and balanced profiles.
    for profile in ["vanilla", "balanced"]:
        d = os.path.abspath(f"bench-orange-{profile}")
        shutil.rmtree(d, ignore_errors=True)
        prepare(d, downloads, paper, plugins)
        shutil.copy(orange_jar, os.path.join(d, "orange.jar"))
        with open(os.path.join(d, "orange.yml"), "w") as f:
            f.write(f"memory: {HEAP}\noptimization-profile: {profile}\nserver-args: [nogui]\n")
        runs.append(run(f"Orange ({profile})", d, ["java", "-jar", "orange.jar"]))

    rows = [
        ("Startup (measured boot)", "startup"),
        ("Entities loaded", "entities"),
        ("TPS (last 1m)", "tps_1m"),
        ("MSPT median (1m)", "mspt_median"),
        ("MSPT 95th percentile (1m)", "mspt_p95"),
        ("MSPT max (1m)", "mspt_max"),
        ("spark profile", "profile"),
    ]
    table = [f"## Orange vs Paper ({paper}, {HEAP} heap, Java {sys.version_info and os.environ.get('JAVA_VERSION', '')})",
             "",
             "| | " + " | ".join(r["label"] for r in runs) + " |",
             "|---|" + "---|" * len(runs)]
    for title, key in rows:
        table.append(f"| {title} | " + " | ".join(str(r.get(key, "?")) for r in runs) + " |")
    summary = "\n".join(table)
    print("\n" + summary)
    for r in runs:
        print(f"\n::group::spark output: {r['label']}\n{r.get('raw', '')}\n::endgroup::")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
            f.write(summary + "\n")


if __name__ == "__main__":
    main()
