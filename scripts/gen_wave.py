#!/usr/bin/env python3
"""Generate a DiscordWave-style shimmer animation block for Minecraft holograms.

Usage: python3 scripts/gen_wave.py "Crate Infomation" [key] [interval]

Every non-space character gets a colour code + &l (bold). The base colour is
&4, with a &c-&f-&c highlight that walks one character per frame, so the text
looks like a white shine sweeping across dark red bold text.
"""
import sys

SMALL_CAPS = {
    "a": "ᴀ", "b": "ʙ", "c": "ᴄ", "d": "ᴅ", "e": "ᴇ", "f": "ꜰ", "g": "ɢ",
    "h": "ʜ", "i": "ɪ", "j": "ᴊ", "k": "ᴋ", "l": "ʟ", "m": "ᴍ", "n": "ɴ",
    "o": "ᴏ", "p": "ᴘ", "q": "q", "r": "ʀ", "s": "ꜱ", "t": "ᴛ", "u": "ᴜ",
    "v": "ᴠ", "w": "ᴡ", "x": "x", "y": "ʏ", "z": "ᴢ",
}

BASE, TRAIL, PEAK = "&4", "&c", "&f"


def to_small_caps(text):
    return "".join(SMALL_CAPS.get(ch.lower(), ch) for ch in text)


def frames(text):
    chars = to_small_caps(text)
    # indexes of the characters that actually get coloured (spaces stay bare)
    lit = [i for i, ch in enumerate(chars) if ch != " "]
    out = []
    for step, _ in enumerate(lit):
        colours = {}
        for offset, code in ((-1, TRAIL), (0, PEAK), (1, TRAIL)):
            pos = step + offset
            if 0 <= pos < len(lit):
                colours[lit[pos]] = code
        frame = []
        for i, ch in enumerate(chars):
            if ch == " ":
                frame.append(" ")
            else:
                frame.append(f"{colours.get(i, BASE)}&l{ch}")
        out.append("".join(frame))
    return out


def main():
    text = sys.argv[1] if len(sys.argv) > 1 else "Crate Infomation"
    key = sys.argv[2] if len(sys.argv) > 2 else "CrateInfoWave"
    interval = sys.argv[3] if len(sys.argv) > 3 else "150"
    lines = [f"{key}:", f"  change-interval: {interval}", "  texts:"]
    lines += [f'    - "{frame}"' for frame in frames(text)]
    print("\n".join(lines))


if __name__ == "__main__":
    main()
