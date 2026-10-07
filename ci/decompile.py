#!/usr/bin/env python3
"""Decompiles selected classes of the patched server jar with Vineflower and prints them.

Usage: decompile.py <server run dir> <vineflower.jar> <output dir>
"""
import os
import subprocess
import sys
import zipfile

run_dir, vineflower, out_dir = sys.argv[1:4]
jars = [os.path.join(r, f) for r, _, fs in os.walk(os.path.join(run_dir, "versions")) for f in fs if f.endswith(".jar")]
server_jar = jars[0]
wanted = [l.strip().replace(".", "/") for l in open(os.path.join(os.path.dirname(__file__), "decompile-classes.txt"))
          if l.strip() and not l.startswith("#")]

# Keep the input outside out_dir: Vineflower writes its source jar under the same file name.
subset = os.path.abspath(out_dir) + "-input.jar"
os.makedirs(out_dir, exist_ok=True)
with zipfile.ZipFile(server_jar) as src, zipfile.ZipFile(subset, "w") as dst:
    for name in src.namelist():
        base = name[:-len(".class")] if name.endswith(".class") else None
        if base and any(base == w or base.startswith(w + "$") for w in wanted):
            dst.writestr(name, src.read(name))

libs = [os.path.join(r, f) for r, _, fs in os.walk(os.path.join(run_dir, "libraries")) for f in fs if f.endswith(".jar")]
cmd = ["java", "-jar", vineflower, "-dgs=1", "-rsy=1", "-e=" + server_jar] + ["-e=" + l for l in libs] + [subset, out_dir]
subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)

for root, _, files in sorted(os.walk(out_dir)):
    for f in sorted(files):
        if f.endswith(".java"):
            path = os.path.join(root, f)
            print(f"::group::source {os.path.relpath(path, out_dir)}\n{open(path).read()}\n::endgroup::")
