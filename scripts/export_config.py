#!/usr/bin/env python3
"""Parse the Luau game config into JSON.

Used by scripts/build_preview.py so the browser preview shows the game's real
numbers rather than a hand-copied snapshot that drifts.

Handles the subset of Luau table syntax the config files actually use: nested
tables, numbers, strings, booleans, Color3.fromRGB and Vector3.new, and
-- comments.

    python3 scripts/export_config.py            # print everything as JSON
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "src" / "shared" / "Config"

TOKEN = re.compile(
    r"""
      (?P<ws>\s+)
    | (?P<comment>--\[\[.*?\]\]|--[^\n]*)
    | (?P<string>"(?:[^"\\]|\\.)*")
    | (?P<number>-?\d+\.?\d*(?:[eE][-+]?\d+)?)
    | (?P<name>[A-Za-z_][A-Za-z0-9_.]*)
    | (?P<punct>[{}(),=\[\]])
    """,
    re.VERBOSE | re.DOTALL,
)


def tokenize(source: str):
    tokens = []
    position = 0
    while position < len(source):
        match = TOKEN.match(source, position)
        if not match:
            raise SyntaxError(f"cannot tokenize at {source[position:position + 40]!r}")
        position = match.end()
        kind = match.lastgroup
        if kind in ("ws", "comment"):
            continue
        tokens.append((kind, match.group()))
    return tokens


class Parser:
    def __init__(self, tokens):
        self.tokens = tokens
        self.index = 0

    def peek(self):
        return self.tokens[self.index] if self.index < len(self.tokens) else (None, None)

    def next(self):
        token = self.peek()
        self.index += 1
        return token

    def expect(self, value):
        kind, text = self.next()
        if text != value:
            raise SyntaxError(f"expected {value!r}, got {text!r}")

    def value(self):
        kind, text = self.next()

        if kind == "string":
            return json.loads(text)
        if kind == "number":
            number = float(text)
            return int(number) if number.is_integer() and "." not in text and "e" not in text.lower() else number
        if text == "{":
            return self.table()
        if kind == "name":
            if text == "true":
                return True
            if text == "false":
                return False

            # Any constructor call: Color3.fromRGB, Vector3.new, NumberRange.new.
            if self.peek()[1] == "(":
                args = self.call_args()
                if text == "Color3.fromRGB":
                    return {"r": args[0], "g": args[1], "b": args[2]}
                if text == "Color3.new":
                    return {"r": args[0] * 255, "g": args[1] * 255, "b": args[2] * 255}
                if text == "Vector3.new":
                    return {"x": args[0], "y": args[1], "z": args[2]}
                if text == "NumberRange.new":
                    return {"min": args[0], "max": args[1] if len(args) > 1 else args[0]}
                return args

            # A bare dotted name, e.g. Enum.Material.Sand: keep the leaf.
            return text.rsplit(".", 1)[-1]

        raise SyntaxError(f"unexpected token {text!r}")

    def call_args(self):
        self.expect("(")
        args = []
        while True:
            kind, text = self.peek()
            if text == ")":
                self.next()
                break
            if text == ",":
                self.next()
                continue
            args.append(self.value())
        return args

    def table(self):
        mapping: dict = {}
        array: list = []

        while True:
            kind, text = self.peek()
            if text == "}":
                self.next()
                break
            if text == ",":
                self.next()
                continue

            # key = value, or a bare array item
            if kind == "name" and self.tokens[self.index + 1][1] == "=":
                key = self.next()[1]
                self.expect("=")
                mapping[key] = self.value()
            elif text == "[":
                self.next()
                key = self.value()
                self.expect("]")
                self.expect("=")
                mapping[str(key)] = self.value()
            else:
                array.append(self.value())

        if mapping and array:
            mapping["_items"] = array
            return mapping
        return mapping if mapping or not array else array


def slice_table(source: str, start: int) -> str:
    """Return source[start:] up to and including the brace matching source[start].

    Brace counting has to skip braces inside strings and comments, and the
    tokenizer must not be handed anything past the table -- the rest of the file
    is function bodies with type annotations it does not parse.
    """
    assert source[start] == "{"

    depth = 0
    index = start
    length = len(source)

    while index < length:
        char = source[index]

        if char == '"':
            index += 1
            while index < length and source[index] != '"':
                index += 2 if source[index] == "\\" else 1
            index += 1
            continue

        if source.startswith("--", index):
            newline = source.find("\n", index)
            index = length if newline == -1 else newline
            continue

        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]

        index += 1

    raise SyntaxError("unbalanced table")


def assignments(path: Path) -> dict:
    """Pull every `Something.Field = <table>` assignment out of a config file."""
    source = path.read_text()
    found = {}

    for match in re.finditer(r"^(\w+)\.(\w+)\s*=\s*\{", source, re.MULTILINE):
        field = match.group(2)
        parser = Parser(tokenize(slice_table(source, match.end() - 1)))
        parser.expect("{")
        found[field] = parser.table()

    return found


def export() -> dict:
    data = {}

    for name in ("Rarities", "Mutations", "Rods", "Zones", "Visuals"):
        data[name] = assignments(CONFIG / f"{name}.luau")

    # Fish.luau holds its roster in a local, not an assignment.
    source = (CONFIG / "Fish.luau").read_text()
    start = source.index("local ROSTER = {") + len("local ROSTER = ")
    parser = Parser(tokenize(slice_table(source, start)))
    parser.expect("{")
    data["Fish"] = parser.table()

    return data


if __name__ == "__main__":
    json.dump(export(), sys.stdout, indent=2)
    print()
