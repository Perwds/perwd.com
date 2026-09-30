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

PLACEHOLDER = "__GAME_DATA__"


def main() -> None:
    template = TEMPLATE.read_text()
    if PLACEHOLDER not in template:
        raise SystemExit(f"{TEMPLATE} is missing the {PLACEHOLDER} placeholder")

    data = json.dumps(export(), separators=(",", ":"))
    OUTPUT.write_text(template.replace(PLACEHOLDER, data))

    print(f"wrote {OUTPUT.relative_to(ROOT)} ({len(OUTPUT.read_text()) / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
