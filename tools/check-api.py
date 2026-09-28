#!/usr/bin/env python3
"""
check-api.py -- validate every Roblox property and enum name in src/ against
the real API dump.

Luau compiles `frame.radius = x` and `Enum.Font.Inter` without complaint; both
only blow up at runtime, and a single bad property name aborts the whole script
that set it -- which is how the client UI once died on its first frame. This
script catches that class of mistake before it reaches Studio.

Usage:
    python3 tools/check-api.py [path/to/API-Dump.json]

With no argument it downloads the dump to .cache/API-Dump.json.
Exits non-zero if anything is wrong, so it can gate CI.
"""

import os
import urllib.request

DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"
CACHE = os.path.join(".cache", "API-Dump.json")


def dump_path() -> str:
    import sys as _sys

    if len(_sys.argv) > 1:
        return _sys.argv[1]
    if not os.path.exists(CACHE):
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        print("downloading API dump...")
        urllib.request.urlretrieve(DUMP_URL, CACHE)
    return CACHE


import json
import re
import sys
import pathlib

api = json.load(open(dump_path()))
classes = {c["Name"]: c for c in api["Classes"]}
enums = {e["Name"]: {i["Name"] for i in e["Items"]} for e in api["Enums"]}

def props(cls):
    """All property names on a class, including inherited, that are scriptable."""
    out = {}
    seen = set()
    while cls and cls in classes and cls not in seen:
        seen.add(cls)
        c = classes[cls]
        for m in c["Members"]:
            if m["MemberType"] != "Property":
                continue
            tags = set(m.get("Tags") or [])
            sec = m.get("Security")
            writable = True
            if "ReadOnly" in tags:
                writable = False
            if isinstance(sec, dict) and sec.get("Write") not in (None, "None"):
                writable = False
            out.setdefault(m["Name"], {"writable": writable, "deprecated": "Deprecated" in tags})
        cls = c.get("Superclass")
    return out

def reserved_keys() -> set:
    """Read Util's RESERVED table rather than duplicating it here.

    These are helper-only option names that Util.new deliberately skips, so
    they are not property mistakes. Parsing them out of the source means the
    two lists cannot drift apart and produce false failures.
    """
    util = pathlib.Path("src/client/ui/Util.lua").read_text()
    block = re.search(r"local RESERVED = \{(.*?)\}", util, re.S)
    if not block:
        raise SystemExit("could not find RESERVED in Util.lua")
    return set(re.findall(r"(\w+)\s*=\s*true", block.group(1)))


RESERVED = reserved_keys()
HELPERS = {
    "Util.text": "TextLabel", "Util.stamp": "TextLabel", "Util.button": "TextButton",
    "Util.well": "Frame", "Util.panel": "Frame", "Util.slot": "Frame",
}

def table_keys(src, start):
    """Top-level `Key =` names inside the table literal beginning at src[start] == '{'."""
    depth, i, keys = 0, start, []
    while i < len(src):
        ch = src[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return keys, i
        elif depth == 1:
            m = re.match(r"\s*([A-Za-z_]\w*)\s*=", src[i:])
            if m and (i == 0 or src[i-1] in "{,\n\t "):
                keys.append((m.group(1), src.count("\n", 0, i) + 1))
                i += m.end() - 1
        i += 1
    return keys, i

problems = []

for path in sorted(pathlib.Path("src").rglob("*.lua")):
    src = path.read_text()

    # Util.new("Class", { ... })  and  the typed helpers
    for m in re.finditer(r'(Util\.new)\(\s*"(\w+)"\s*,\s*\{', src):
        keys, _ = table_keys(src, m.end() - 1)
        cls = m.group(2)
        if cls not in classes:
            problems.append((path, src.count("\n",0,m.start())+1, f"unknown class {cls!r}"))
            continue
        allowed = props(cls)
        for k, line in keys:
            if k in ("Parent",) or k in RESERVED:
                continue
            info = allowed.get(k)
            if not info:
                problems.append((path, line, f"{cls}.{k} is not a property"))
            elif not info["writable"]:
                problems.append((path, line, f"{cls}.{k} is read-only"))
            elif info["deprecated"]:
                problems.append((path, line, f"{cls}.{k} is deprecated"))

    for helper, cls in HELPERS.items():
        for m in re.finditer(re.escape(helper) + r'\(\s*\{', src):
            keys, _ = table_keys(src, m.end() - 1)
            allowed = props(cls)
            for k, line in keys:
                if k in ("Parent",) or k in RESERVED:
                    continue
                info = allowed.get(k)
                if not info:
                    problems.append((path, line, f"{helper} -> {cls}.{k} is not a property"))
                elif not info["writable"]:
                    problems.append((path, line, f"{helper} -> {cls}.{k} is read-only"))

    # Instance.new("Class") assigned to a local, then local.Prop = ...
    for m in re.finditer(r'local\s+(\w+)\s*=\s*Instance\.new\(\s*"(\w+)"\s*\)', src):
        var, cls = m.group(1), m.group(2)
        if cls not in classes:
            problems.append((path, src.count("\n",0,m.start())+1, f"unknown class {cls!r}"))
            continue
        allowed = props(cls)
        for a in re.finditer(r'\b' + re.escape(var) + r'\.([A-Za-z_]\w*)\s*=(?!=)', src[m.end():]):
            k = a.group(1)
            if k == "Parent":
                continue
            line = src.count("\n", 0, m.end() + a.start()) + 1
            info = allowed.get(k)
            if not info:
                problems.append((path, line, f"{cls}.{k} is not a property (via {var})"))
            elif not info["writable"]:
                problems.append((path, line, f"{cls}.{k} is read-only (via {var})"))

    # Enum.Foo.Bar
    for m in re.finditer(r'Enum\.(\w+)\.(\w+)', src):
        name, item = m.group(1), m.group(2)
        line = src.count("\n", 0, m.start()) + 1
        if name not in enums:
            problems.append((path, line, f"Enum.{name} does not exist"))
        elif item not in enums[name]:
            problems.append((path, line, f"Enum.{name}.{item} does not exist"))

if problems:
    for path, line, msg in sorted(set(problems)):
        print(f"{path}:{line}: {msg}")
    print(f"\n{len(set(problems))} problem(s)")
    sys.exit(1)
print("no property or enum problems found")
