#!/usr/bin/env python3
"""Chunk generation speed on the Orange server.

Usage: chunkgen_benchmark.py <orange.jar>

Each variant starts a fresh world (same seed), pre-generates a square of chunks with
/orange pregen, and reports chunks per second and the worst tick while generating.
"""
import os
import re
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from server_test import Server, download, get_json  # noqa: E402
from tnt_benchmark import MANIFEST  # noqa: E402

RADIUS = 480  # blocks: 61 x 61 = 3,721 chunks
CORES = os.cpu_count() or 4

# name -> {file: {exact text: replacement}}
VARIANTS = {
    "Defaults": {},
    "Pregen 64 in flight": {
        "plugins/Orange/config.yml": {"parallel-chunks: 16": "parallel-chunks: 64"},
    },
    f"64 in flight + {CORES} worker threads": {
        "plugins/Orange/config.yml": {"parallel-chunks: 16": "parallel-chunks: 64"},
        "config/paper-global.yml": {"worker-threads: -1": f"worker-threads: {CORES}"},
    },
}


def edit(path, replacements):
    text = open(path).read()
    for old, new in replacements.items():
        if old not in text:
            raise SystemExit(f"{path}: '{old}' not found")
        text = text.replace(old, new)
    open(path, "w").write(text)


def main():
    orange_jar = os.path.abspath(sys.argv[1])
    template = os.path.abspath("gen-template")
    shutil.rmtree(template, ignore_errors=True)
    os.makedirs(template)
    versions = get_json(MANIFEST)["versions"]
    version = sorted(versions)[-1]
    info = versions[version]
    download(info["url"], os.path.join(template, info["file"]))
    shutil.copy(orange_jar, os.path.join(template, "orange.jar"))
    open(os.path.join(template, "eula.txt"), "w").write("eula=true\n")
    open(os.path.join(template, "server.properties"), "w").write("level-seed=orange-gen\nonline-mode=false\n")
    open(os.path.join(template, "orange.yml"), "w").write("memory: 6G\nserver-args: [nogui]\n")
    for label in ("template1", "template2"):
        s = Server(template, os.path.join(template, f"{label}.log"))
        if not s.wait_for(r"Done \(\d", 900):
            raise SystemExit("template boot failed")
        s.stop()
    # Each variant generates into an empty world with the same seed.
    for world in ("world", "world_nether", "world_the_end"):
        shutil.rmtree(os.path.join(template, world), ignore_errors=True)

    results = []
    for name, changes in VARIANTS.items():
        run_dir = os.path.abspath("gen-" + re.sub(r"\W+", "-", name).strip("-").lower())
        shutil.rmtree(run_dir, ignore_errors=True)
        shutil.copytree(template, run_dir)
        for file, replacements in changes.items():
            edit(os.path.join(run_dir, file), replacements)
        print(f"\n===== {name} =====", flush=True)
        s = Server(run_dir, os.path.join(run_dir, "gen.log"))
        if not s.wait_for(r"Done \(\d", 900):
            raise SystemExit(f"{name}: boot failed")
        time.sleep(5)
        mark = len(s.lines)
        start = time.time()
        s.send(f"orange pregen world {RADIUS}")
        done = s.wait_for(r"Pre-generation of world finished", 1200)
        elapsed = time.time() - start
        s.send("spark tps")
        time.sleep(3)
        out = "".join(s.lines[mark:])
        s.stop()
        m = re.search(r"finished: (\d+)/(\d+) chunks .*?([\d.]+) chunks/s", out)
        durations = re.findall(r"(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)/(\d+(?:\.\d+)?)", out)
        results.append({
            "label": name,
            "chunks": m.group(1) if m else "?",
            "rate": f"{float(m.group(3)):.0f}" if m else "?",
            "seconds": f"{elapsed:.0f}" if done else "timeout",
            # 1-minute window: covers the generation (or its last minute)
            "max": durations[1][3] if len(durations) > 1 else (durations[0][3] if durations else "?"),
        })
        print(results[-1], flush=True)

    lines = [f"## Chunk generation on the Orange server {version} ({CORES} CPU cores, radius {RADIUS} blocks)", "",
             "| | " + " | ".join(r["label"] for r in results) + " |", "|---|" + "---|" * len(results)]
    for title, key, unit in [("Chunks generated", "chunks", ""), ("Chunks per second", "rate", ""),
                             ("Total time", "seconds", " s"), ("Worst tick while generating (1 min)", "max", " ms")]:
        lines.append(f"| {title} | " + " | ".join(f"{r[key]}{unit}" for r in results) + " |")
    summary = "\n".join(lines)
    print("\n" + summary)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        open(os.environ["GITHUB_STEP_SUMMARY"], "a").write(summary + "\n")


if __name__ == "__main__":
    main()
