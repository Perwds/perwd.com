#!/usr/bin/env python3
"""Build a .rbxlx place file straight from the source tree.

This is a small, faithful subset of what Rojo does, so the game can be opened in
Roblox Studio by double-clicking one file — no toolchain to install. For an
actual development loop (live sync while you edit), use Rojo instead; this is
for getting the game into Studio once so it can be published.

    python3 scripts/build_place.py

Writes build/perwd-fishing.rbxlx.
"""

from __future__ import annotations

import json
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "default.project.json"
OUTPUT = ROOT / "build" / "perwd-fishing.rbxlx"

# Lighting.Technology is an enum token, and writing the wrong number would
# silently downgrade the renderer. It is one dropdown in Studio, so it is left
# out here rather than guessed; default.project.json still sets it for Rojo.
SKIP_PROPERTIES = {"Technology"}


class Node:
    def __init__(self, class_name: str, name: str):
        self.class_name = class_name
        self.name = name
        self.properties: dict = {}
        self.source: str | None = None
        self.children: list[Node] = []


def script_class(filename: str) -> tuple[str, str]:
    """Map a source filename to (class, instance name), Rojo's rules."""
    stem = filename
    for suffix in (".luau", ".lua"):
        if stem.endswith(suffix):
            stem = stem[: -len(suffix)]
            break

    if stem.endswith(".server"):
        return "Script", stem[: -len(".server")]
    if stem.endswith(".client"):
        return "LocalScript", stem[: -len(".client")]
    return "ModuleScript", stem


def from_path(path: Path, name: str) -> Node:
    """Build a node for a file or directory, following Rojo's init.* rules."""
    if path.is_file():
        class_name, _ = script_class(path.name)
        node = Node(class_name, name)
        node.source = path.read_text()
        return node

    # A directory becomes a Folder unless it holds an init file, in which case
    # the directory itself becomes that script.
    node = Node("Folder", name)
    for init in ("init.server.luau", "init.client.luau", "init.luau"):
        candidate = path / init
        if candidate.exists():
            node.class_name, _ = script_class(init)
            node.source = candidate.read_text()
            break

    for child in sorted(path.iterdir()):
        if child.name.startswith("init.") and node.source is not None:
            continue
        if child.is_dir():
            node.children.append(from_path(child, child.name))
        elif child.suffix in (".luau", ".lua"):
            _, child_name = script_class(child.name)
            node.children.append(from_path(child, child_name))

    return node


def from_tree(name: str, spec: dict) -> Node:
    node = Node(spec.get("$className", "Folder"), name)
    node.properties = spec.get("$properties", {})

    if "$path" in spec:
        source_path = ROOT / spec["$path"]
        built = from_path(source_path, name)
        node.class_name = spec.get("$className", built.class_name)
        node.source = built.source
        node.children.extend(built.children)

    for key, value in spec.items():
        if key.startswith("$"):
            continue
        node.children.append(from_tree(key, value))

    return node


def write_property(parent: ET.Element, name: str, value) -> None:
    if name in SKIP_PROPERTIES:
        return

    if isinstance(value, bool):
        element = ET.SubElement(parent, "bool", {"name": name})
        element.text = "true" if value else "false"
    elif isinstance(value, (int, float)):
        element = ET.SubElement(parent, "float", {"name": name})
        element.text = repr(float(value))
    elif isinstance(value, str):
        element = ET.SubElement(parent, "string", {"name": name})
        element.text = value
    elif isinstance(value, list) and len(value) == 3:
        element = ET.SubElement(parent, "Color3", {"name": name})
        for channel, component in zip(("R", "G", "B"), value):
            ET.SubElement(element, channel).text = repr(float(component) / 255.0)
    else:
        print(f"  skipped property {name}: unsupported type")


def serialize(node: Node, parent: ET.Element, counter: list[int]) -> None:
    item = ET.SubElement(
        parent, "Item", {"class": node.class_name, "referent": f"RBX{counter[0]}"}
    )
    counter[0] += 1

    properties = ET.SubElement(item, "Properties")
    ET.SubElement(properties, "string", {"name": "Name"}).text = node.name

    for key, value in node.properties.items():
        write_property(properties, key, value)

    if node.source is not None:
        # Placeholder; CDATA is spliced in after serialisation, since
        # ElementTree cannot emit it.
        ET.SubElement(
            properties, "ProtectedString", {"name": "Source"}
        ).text = f"\x00SOURCE{counter[0] - 1}\x00"

    for child in node.children:
        serialize(child, item, counter)


def collect_sources(node: Node, counter: list[int], out: dict) -> None:
    index = counter[0]
    counter[0] += 1
    if node.source is not None:
        out[index] = node.source
    for child in node.children:
        collect_sources(child, counter, out)


def main() -> None:
    project = json.loads(PROJECT.read_text())
    tree = project["tree"]

    root = ET.Element(
        "roblox",
        {
            "xmlns:xmime": "http://www.w3.org/2005/05/xmlmime",
            "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
            "xsi:noNamespaceSchemaLocation": "http://www.roblox.com/roblox.xsd",
            "version": "4",
        },
    )

    # Services sit at the top level; Studio merges them onto the real ones.
    services = [from_tree(name, spec) for name, spec in tree.items() if not name.startswith("$")]

    counter = [0]
    sources: dict[int, str] = {}
    for service in services:
        collect_sources(service, counter, sources)

    counter = [0]
    for service in services:
        serialize(service, root, counter)

    xml = ET.tostring(root, encoding="unicode")

    # Splice the real source in as CDATA.
    for index, source in sources.items():
        safe = source.replace("]]>", "]]]]><![CDATA[>")
        xml = xml.replace(f"\x00SOURCE{index}\x00", f"<![CDATA[{safe}]]>")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text('<?xml version="1.0" encoding="UTF-8"?>\n' + xml + "\n")

    scripts = len(sources)
    size = OUTPUT.stat().st_size / 1024
    print(f"wrote {OUTPUT.relative_to(ROOT)} ({size:.0f} KB, {scripts} scripts)")


if __name__ == "__main__":
    main()
