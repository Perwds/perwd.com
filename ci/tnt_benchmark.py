#!/usr/bin/env python3
"""1,000 TNT on the Orange server: how bad is the lag spike, and what do settings change?

Usage: tnt_benchmark.py <orange.jar>

Every variant starts from the same pre-generated world, summons 1,000 primed TNT in one spot
with a 15 s fuse, and reads spark's tick times for a 10 s window that contains the blast but
not the tick that ran the 1,000 summon commands (that tick is reported separately).
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from server_test import Server, download, get_json  # noqa: E402

TNT = 1000
# Oldest Orange server build to benchmark (build 6 adds the TNT time budget). If the release is
# older, wait for the orange-server workflow to publish it.
MIN_BUILD = int(os.environ.get("ORANGE_MIN_BUILD", "6"))
MANIFEST = "https://github.com/Perwds/perwd.com/releases/download/orange-server/orange-server.json"

# name -> {config file: {exact line to replace: new line}}; "orange.yml" lines are appended.
VARIANTS = {
    "No TNT budget (like Paper)": {"orange.yml": "tnt-tick-budget-ms: 0"},
    "Orange default (20 ms budget)": {},
    "20 ms budget + optimize-explosions": {
        "config/paper-world-defaults.yml": {"optimize-explosions: false": "optimize-explosions: true"},
    },
}


def boot_and_stop(run_dir, label):
    s = Server(run_dir, os.path.join(run_dir, f"{label}.log"))
    if not s.wait_for(r"Done \(\d", 900):
        raise SystemExit(f"{label}: server did not start")
    return s


def edit(path, replacements):
    text = open(path).read()
    for old, new in replacements.items():
        if old not in text:
            raise SystemExit(f"{path}: '{old}' not found")
        text = text.replace(old, new)
    open(path, "w").write(text)


def server_pid():
    """PID of the server JVM (orange.jar's child process)."""
    out = subprocess.run(["pgrep", "-f", "versions/.*orange-1"], capture_output=True, text=True).stdout.split()
    return out[0] if out else None


def jfr(pid, *args):
    return subprocess.run(["jcmd", pid, *args], capture_output=True, text=True).stdout


def measure(run_dir, label):
    s = boot_and_stop(run_dir, label)
    s.send("forceload add -32 -32 31 31")
    time.sleep(10)
    s.send("spark tps")
    time.sleep(3)
    idle = "".join(s.lines)
    mark = len(s.lines)
    for _ in range(TNT):
        s.send("execute positioned 0 0 0 positioned over motion_blocking_no_leaves run summon minecraft:tnt ~ ~ ~ {fuse:300}")
    s.wait_for(r"Summoned new", 60)
    time.sleep(5)
    s.send("spark tps")  # 10 s window with the summon tick, before the blast
    time.sleep(3)
    summon_out = "".join(s.lines[mark:])
    mark2 = len(s.lines)
    mark2_time = time.time() - 8  # the TNT was summoned ~8 s ago (5 s + spark), fuse is 15 s
    pid = server_pid()
    time.sleep(6)
    if pid:  # Flight Recorder profile of just the blast
        jfr(pid, "JFR.start", "name=blast", "settings=profile")
    time.sleep(1 + 5)  # rest of the fuse (15 s) plus 5 s of blast and aftermath
    recording = os.path.join(run_dir, "blast.jfr")
    if pid:
        jfr(pid, "JFR.stop", "name=blast", f"filename={recording}")
    s.send("spark tps")  # 10 s window: blast only
    time.sleep(3)
    # How long until every TNT has gone off (the budget spreads the blast over more ticks).
    blast_start = mark2_time + 15.0
    finished = None
    while time.time() - blast_start < 90:
        s.send("execute if entity @e[type=minecraft:tnt]")
        time.sleep(1)
        if re.search(r"Test failed", "".join(s.lines[-5:])):
            finished = time.time() - blast_start
            break
    s.send("spark tps")  # second 10 s window: the rest of a long, budgeted blast
    time.sleep(3)
    s.send("execute if entity @e[type=minecraft:item]")
    time.sleep(2)
    out = "".join(s.lines[mark2:])
    s.stop()
    if os.path.exists(recording):
        for view in ("hot-methods", "allocation-by-class"):
            report = subprocess.run(["jfr", "view", "--width", "220", view, recording], capture_output=True, text=True)
            print(f"::group::{label}: jfr {view}\n{report.stdout[:12000]}{report.stderr[:2000]}\n::endgroup::", flush=True)
        # Hot call paths on the server thread: top frames' callers, to see where explosions spend time.
        stacks = subprocess.run(["jfr", "print", "--events", "jdk.ExecutionSample", "--stack-depth", "12", recording],
                                capture_output=True, text=True).stdout
        counts = {}
        for sample in stacks.split("jdk.ExecutionSample")[1:]:
            if "Server thread" not in sample:
                continue
            frames = re.findall(r"^\s+([\w.$<>]+)\(", sample, re.M)
            for frame in dict.fromkeys(frames):
                counts[frame] = counts.get(frame, 0) + 1
        total = sum(1 for x in stacks.split("jdk.ExecutionSample")[1:] if "Server thread" in x)
        top = sorted(counts.items(), key=lambda kv: -kv[1])[:40]
        print(f"::group::{label}: server-thread samples containing each method (of {total})\n"
              + "\n".join(f"{n:6d} {100 * n / max(total, 1):5.1f}%  {m}" for m, n in top) + "\n::endgroup::", flush=True)

    result = {"label": label}
    durations = re.findall(r"(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)", out)
    if durations:
        # Each spark tps prints a "last 10s" then a "last 1m" tuple; use the 10 s ones (the 1 m
        # window would include the tick that ran the summon commands).
        windows = durations[0::2]
        worst = max(windows, key=lambda w: float(w[3]))
        result.update(median=worst[1], p95=max((w[2] for w in windows), key=float), max=worst[3])
    summon_d = re.findall(r"(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)", summon_out)
    if summon_d:
        result["summon_max"] = summon_d[0][3]
    idle_d = re.findall(r"(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)", idle)
    if idle_d:
        result["idle_max"] = idle_d[-2][3] if len(idle_d) > 1 else idle_d[-1][3]
    # The item count is the last query sent (TNT polling also prints "Test passed" lines before it).
    item_query = out.rsplit("execute if entity @e[type=minecraft:item]", 1)[-1]
    found = re.findall(r"Test passed[.,] [Cc]ount: (\d+)", item_query)
    result["items"] = found[0] if found else "0"
    result["blast_seconds"] = f"{finished:.0f} s" if finished is not None else "> 90 s"
    result["summoned"] = str(summon_out.count("Summoned new"))
    print(json.dumps(result), flush=True)
    return result


def main():
    orange_jar = os.path.abspath(sys.argv[1])
    template = os.path.abspath("tnt-template")
    shutil.rmtree(template, ignore_errors=True)
    os.makedirs(template)
    deadline = time.time() + 40 * 60
    while True:
        build = get_json(MANIFEST + f"?t={int(time.time())}")["versions"]
        version = sorted(build)[-1]
        info = build[version]
        if int(info["build"]) >= MIN_BUILD or time.time() > deadline:
            break
        print(f"Release has build {info['build']}; waiting for build {MIN_BUILD}...", flush=True)
        time.sleep(60)
    print(f"Orange server {version} build {info['build']}")
    download(info["url"], os.path.join(template, info["file"]))
    shutil.copy(orange_jar, os.path.join(template, "orange.jar"))
    open(os.path.join(template, "eula.txt"), "w").write("eula=true\n")
    open(os.path.join(template, "server.properties"), "w").write(
        "level-seed=orange-tnt\nonline-mode=false\nspawn-protection=0\n")
    open(os.path.join(template, "orange.yml"), "w").write("memory: 6G\nserver-args: [nogui]\n")

    # Two starts: the first generates world and configs, the second lets Orange tune the configs.
    for label in ("template1", "template2"):
        s = boot_and_stop(template, label)
        if label == "template1":
            s.send("forceload add -32 -32 31 31")
            time.sleep(20)
        s.stop()

    results = []
    for name, changes in VARIANTS.items():
        run_dir = os.path.abspath("tnt-" + re.sub(r"\W+", "-", name).strip("-").lower())
        shutil.rmtree(run_dir, ignore_errors=True)
        shutil.copytree(template, run_dir)
        for file, replacements in changes.items():
            if file == "orange.yml":
                with open(os.path.join(run_dir, file), "a") as f:
                    f.write(replacements + "\n")
            else:
                edit(os.path.join(run_dir, file), replacements)
        print(f"\n===== {name} =====", flush=True)
        results.append(measure(run_dir, name))

    lines = [f"## {TNT} TNT on the Orange server {version} (build {info['build']})", "",
             "| | " + " | ".join(r["label"] for r in results) + " |",
             "|---|" + "---|" * len(results)]
    for title, key in [("TNT summoned", "summoned"), ("Worst tick during the blast", "max"),
                       ("95th percentile tick", "p95"), ("Median tick", "median"),
                       ("Tick that ran the 1,000 summon commands", "summon_max"),
                       ("Worst tick before summoning (chunk loading)", "idle_max"),
                       ("Time until all TNT went off", "blast_seconds"), ("Dropped items left", "items")]:
        lines.append(f"| {title} | " + " | ".join(str(r.get(key, "?")) + (" ms" if key in ("max", "p95", "median", "idle_max", "summon_max") else "") for r in results) + " |")
    summary = "\n".join(lines)
    print("\n" + summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        open(os.environ["GITHUB_STEP_SUMMARY"], "a").write(summary + "\n")


if __name__ == "__main__":
    main()
