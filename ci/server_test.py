#!/usr/bin/env python3
"""Boots a real Paper/Purpur server through orange.jar and checks that Orange works.

Usage: server_test.py <paper|purpur> <path to orange.jar>

Prints the real config files and class signatures in collapsible log groups so patches and
config keys can be checked against what the server actually ships.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import zipfile

UA = "orange-ci (https://github.com/Perwds/perwd.com)"
JAVA = int(subprocess.run(["java", "-XshowSettings:properties", "-version"], capture_output=True, text=True)
           .stderr.split("java.specification.version = ")[1].split()[0])
failures = []


def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=300) as r, open(dest, "wb") as f:
        shutil.copyfileobj(r, f)


def version_key(v):
    return [int(x) for x in re.findall(r"\d+", v)]


def usable(version):
    """Minecraft 1.x runs on Java 21; the 26.x line needs Java 25."""
    if "-" in version or "pre" in version or "rc" in version:
        return False
    return version.startswith("1.") or JAVA >= 25


def fetch_paper(dest):
    try:
        return fetch_paper_fill(dest)
    except (KeyError, urllib.error.HTTPError) as e:
        print(f"Fill v3 API failed ({e!r}); trying the v2 API")
        return fetch_paper_v2(dest)


def fetch_paper_v2(dest):
    base = "https://api.papermc.io/v2/projects/paper"
    versions = get_json(base)["versions"]
    version = sorted(filter(usable, versions), key=version_key, reverse=True)[0]
    builds = get_json(f"{base}/versions/{version}/builds")["builds"]
    build = builds[-1]
    name = build["downloads"]["application"]["name"]
    print(f"Paper {version} build {build['build']}: {name}")
    download(f"{base}/versions/{version}/builds/{build['build']}/downloads/{name}", os.path.join(dest, name))
    return name


def fetch_paper_fill(dest):
    project = get_json("https://fill.papermc.io/v3/projects/paper")
    versions = [v for group in project["versions"].values() for v in group]
    for version in sorted(filter(usable, versions), key=version_key, reverse=True):
        try:
            build = get_json(f"https://fill.papermc.io/v3/projects/paper/versions/{version}/builds/latest")
        except Exception as e:
            print(f"no build for {version}: {e}")
            continue
        if build.get("channel", "").upper() != "STABLE":
            continue
        d = build["downloads"]["server:default"]
        print(f"Paper {version} build {build.get('id')}: {d['name']}")
        download(d["url"], os.path.join(dest, d["name"]))
        return d["name"]
    raise SystemExit("no stable Paper build found for Java %d" % JAVA)


def fetch_purpur(dest):
    versions = get_json("https://api.purpurmc.org/v2/purpur")["versions"]
    version = sorted(filter(usable, versions), key=version_key, reverse=True)[0]
    name = f"purpur-{version}.jar"
    print(f"Purpur {version}")
    download(f"https://api.purpurmc.org/v2/purpur/{version}/latest/download", os.path.join(dest, name))
    return name


class Server:
    def __init__(self, run_dir, log_path, command=None):
        self.log_path = log_path
        self.cmd_path = os.path.join(run_dir, ".commands")
        open(self.cmd_path, "w").close()
        self.log = open(log_path, "w")
        feeder = subprocess.Popen(["tail", "-f", self.cmd_path], stdout=subprocess.PIPE)
        self.proc = subprocess.Popen(command or ["java", "-jar", "orange.jar"], cwd=run_dir, stdin=feeder.stdout,
                                     stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        self.feeder = feeder
        self.lines = []
        threading.Thread(target=self._pump, daemon=True).start()

    def _pump(self):
        for line in self.proc.stdout:
            sys.stdout.write(line)
            self.log.write(line)
            self.log.flush()
            self.lines.append(line)

    def send(self, command):
        print(f">>> {command}", flush=True)
        with open(self.cmd_path, "a") as f:
            f.write(command + "\n")

    def wait_for(self, pattern, timeout):
        rx = re.compile(pattern)
        deadline = time.time() + timeout
        seen = 0
        while time.time() < deadline:
            while seen < len(self.lines):
                if rx.search(self.lines[seen]):
                    return True
                seen += 1
            if self.proc.poll() is not None and seen >= len(self.lines):
                return False
            time.sleep(0.2)
        return False

    def stop(self):
        self.send("stop")
        try:
            self.proc.wait(timeout=180)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            failures.append("server did not stop within 180s")
        self.feeder.kill()
        time.sleep(1)
        return "".join(self.lines)


def check(condition, message):
    print(("PASS " if condition else "FAIL ") + message, flush=True)
    if not condition:
        failures.append(message)


def group(title, text):
    print(f"::group::{title}\n{text}\n::endgroup::", flush=True)


def boot(run_dir, label, pregen):
    print(f"\n===== {label} =====", flush=True)
    server = Server(run_dir, os.path.join(run_dir, f"{label}.log"))
    started = server.wait_for(r"Done \(\d", 600)
    check(started, f"{label}: server started")
    if started:
        server.send("orange status")
        check(server.wait_for(r"\[Orange\].*TPS", 30), f"{label}: /orange status answers")
        server.send("orange ping")
        check(server.wait_for(r"Nobody is online", 30), f"{label}: /orange ping answers")
        if pregen:
            server.send("orange pregen world 160")
            check(server.wait_for(r"Pre-generation of world finished", 300), f"{label}: pregen finishes")
    return server.stop()


def inspect_classes(run_dir, classes_file):
    jars = []
    for root, _, files in os.walk(os.path.join(run_dir, "versions")):
        jars += [os.path.join(root, f) for f in files if f.endswith(".jar")]
    if not jars:
        print("no patched server jar under versions/; skipping class dump")
        return
    jar = jars[0]
    with zipfile.ZipFile(jar) as z:
        names = set(z.namelist())
    for line in open(classes_file):
        cls = line.strip()
        if not cls or cls.startswith("#"):
            continue
        if cls.replace(".", "/") + ".class" not in names:
            print(f"(not in this version) {cls}")
            continue
        out = subprocess.run(["javap", "-p", "-cp", jar, cls], capture_output=True, text=True)
        group(f"javap {cls}", out.stdout + out.stderr)


def main():
    flavor, orange_jar = sys.argv[1], os.path.abspath(sys.argv[2])
    run_dir = os.path.abspath(f"run-{flavor}-java{JAVA}")
    shutil.rmtree(run_dir, ignore_errors=True)
    os.makedirs(run_dir)
    jar = fetch_paper(run_dir) if flavor == "paper" else fetch_purpur(run_dir)
    shutil.copy(orange_jar, os.path.join(run_dir, "orange.jar"))
    with open(os.path.join(run_dir, "eula.txt"), "w") as f:
        f.write("eula=true\n")
    with open(os.path.join(run_dir, "server.properties"), "w") as f:
        f.write("level-seed=orange\nonline-mode=false\n")
    # orange.yml from the template, with a CI-sized heap.
    dry = subprocess.run(["java", "-jar", "orange.jar", "--dry-run"], cwd=run_dir, check=True,
                         capture_output=True, text=True).stdout
    print(dry)
    open(os.path.join(run_dir, "dry-run.txt"), "w").write(dry)
    yml = os.path.join(run_dir, "orange.yml")
    text = open(yml).read().replace("memory: auto", "memory: 2G")
    open(yml, "w").write(text)

    log1 = boot(run_dir, "boot1", pregen=True)
    check("Applied patch orange:branding" in log1, "branding patch applied to the real MinecraftServer")
    check("Enabling Orange" in log1, "Orange plugin enabled")
    if JAVA >= 25:
        check("UseCompactObjectHeaders" in open(os.path.join(run_dir, "dry-run.txt")).read(),
              "compact object headers enabled on Java 25")

    for name in ["server.properties", "bukkit.yml", "spigot.yml", "config/paper-global.yml",
                 "config/paper-world-defaults.yml", "purpur.yml", "pufferfish.yml"]:
        path = os.path.join(run_dir, name)
        if os.path.exists(path):
            group(f"generated {name}", open(path).read())

    # Second boot: the configs now exist, so the optimizer tunes them.
    log2 = boot(run_dir, "boot2", pregen=False)
    check("Tuned spigot.yml" in log2, "optimizer tuned spigot.yml")
    check("Tuned config/paper-world-defaults.yml" in log2, "optimizer tuned paper-world-defaults.yml")

    for log, label in [(log1, "boot1"), (log2, "boot2")]:
        errors = [l for l in log.splitlines() if "[Orange] ERROR" in l or ("Exception" in l and "orange" in l.lower())]
        check(not errors, f"{label}: no Orange errors" + ("".join("\n    " + e for e in errors[:10])))
        missing = [l for l in log.splitlines() if "not present in" in l or "did not match" in l]
        if missing:
            group(f"{label}: config keys / patches not found", "\n".join(missing))

    inspect_classes(run_dir, os.path.join(os.path.dirname(__file__), "inspect-classes.txt"))

    if failures:
        print("\nFAILED:\n  " + "\n  ".join(failures))
        sys.exit(1)
    print("\nAll server checks passed.")


if __name__ == "__main__":
    main()
