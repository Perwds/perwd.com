#!/usr/bin/env python3
"""Render preview/index.html from preview/template.html + the Luau config.

The preview shows the game's real rarity tables, luck maths and coin values, so
it is generated rather than hand-maintained.

    python3 scripts/build_preview.py
"""

from __future__ import annotations

import json
from pathlib import Path

from export_config import export

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE = ROOT / "preview" / "template.html"
OUTPUT = ROOT / "preview" / "index.html"

DATA_PLACEHOLDER = "__GAME_DATA__"
SVG_PLACEHOLDER = "__FISH_SVG__"
FISH_SVG = ROOT / "preview" / "fish-svg.js"


def main() -> None:
    template = TEMPLATE.read_text()
    for placeholder in (DATA_PLACEHOLDER, SVG_PLACEHOLDER):
        if placeholder not in template:
            raise SystemExit(f"{TEMPLATE} is missing the {placeholder} placeholder")

    data = json.dumps(export(), separators=(",", ":"))
    page = template.replace(DATA_PLACEHOLDER, data)
    # The silhouette module is shared with the static sheet generator; its
    # CommonJS export tail is meaningless in a browser, so drop it.
    svg = FISH_SVG.read_text().split("if (typeof module !==")[0].rstrip()
    page = page.replace(SVG_PLACEHOLDER, svg)
    OUTPUT.write_text(page)

    print(f"wrote {OUTPUT.relative_to(ROOT)} ({len(OUTPUT.read_text()) / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
