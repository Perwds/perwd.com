#!/usr/bin/env python3
"""Imports the ShrinkIt_Individual_Assets pack into the Rojo project.

usage: python3 tools/import_assets.py <path to Individual_Assets folder>
       python3 tools/import_assets.py --sleeping <path to Sleeping_Character_Assets folder>

- chasers            -> assets/Chasers/Tier1..Tier10.rbxmx          (ServerStorage > Chasers)
- collectibles/rewards matching an ObjectConfig id
                     -> assets/ShrinkableTemplates/<ObjectId>.rbxmx (ReplicatedStorage > ShrinkableTemplates)
- everything else    -> assets/Pack/<name>.rbxmx                     (ServerStorage > AssetPack)
--sleeping: sleeping chasers   -> assets/Sleeping/Chasers/Tier1..Tier10.rbxmx (ServerStorage > SleepingChasers)
            sleeping shopkeepers -> assets/Sleeping/Shopkeepers/<name>.rbxmx (ServerStorage > SleepingShopkeepers)

The pack uses the newest Roblox XML format (<uri>, MeshContent, ContentId ...). Rojo 7.4 reads the
classic form, so Content properties are rewritten to MeshId / TextureID / ColorMap ... (same assets).
"""
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

CHASERS = ["grandpa_joe", "angry_neighbor", "officer_doug", "captain_barnacle", "sheriff_sandy",
           "jungle_jim", "security_bot", "magma_golem", "yeti", "alien_overlord"]
RENAME = {"trash_can": "TrashBin", "ufo": "UFO", "moon": "TheMoon"}

MAP = {"MeshContent": "MeshId", "TextureContent": "TextureID", "ColorMapContent": "ColorMap",
       "NormalMapContent": "NormalMap", "MetalnessMapContent": "MetalnessMap", "RoughnessMapContent": "RoughnessMap"}
PAT = re.compile(r'<Content name="(\w+)">(.*?)</Content>', re.S)


def fix(m):
    name, body = m.group(1), m.group(2)
    uri = re.search(r"<uri>(.*?)</uri>", body, re.S)
    if not uri or name not in MAP:
        return ""  # empty, or no classic equivalent (EmissiveMaskContent)
    return '<Content name="%s"><url>%s</url></Content>' % (MAP[name], uri.group(1).strip())


def convert(src, dst):
    s = open(src, encoding="utf-8").read()
    s = PAT.sub(fix, s)
    s = re.sub(r'<ContentId name="(\w+)">', r'<Content name="\1">', s).replace("</ContentId>", "</Content>")
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    open(dst, "w", encoding="utf-8").write(s)


def camel(snake):
    return "".join(p.capitalize() for p in snake.split("_"))


def sleeping(pack):
    out = os.path.join(ROOT, "assets", "Sleeping")
    n = 0
    for name in sorted(os.listdir(pack)):
        src = os.path.join(pack, name, name + ".rbxmx")
        if not os.path.isfile(src):
            continue
        if name in CHASERS:
            dst = os.path.join(out, "Chasers", "Tier%d.rbxmx" % (CHASERS.index(name) + 1))
        else:
            dst = os.path.join(out, "Shopkeepers", name + ".rbxmx")
        convert(src, dst)
        n += 1
    print({"Sleeping": n})


def main():
    if sys.argv[1] == "--sleeping":
        return sleeping(sys.argv[2])
    pack = sys.argv[1]
    ids = set(re.findall(r"^\t(\w+) = \{ Name", open(os.path.join(ROOT, "src/ReplicatedStorage/Shared/Config/ObjectConfig.lua")).read(), re.M))
    out = os.path.join(ROOT, "assets")
    counts = {"Chasers": 0, "ShrinkableTemplates": 0, "Pack": 0}
    for name in sorted(os.listdir(pack)):
        src = os.path.join(pack, name, name + ".rbxmx")
        if not os.path.isfile(src):
            continue
        if name in CHASERS:
            dst, kind = os.path.join(out, "Chasers", "Tier%d.rbxmx" % (CHASERS.index(name) + 1)), "Chasers"
        elif RENAME.get(name, camel(name)) in ids:
            dst, kind = os.path.join(out, "ShrinkableTemplates", RENAME.get(name, camel(name)) + ".rbxmx"), "ShrinkableTemplates"
        else:
            dst, kind = os.path.join(out, "Pack", name + ".rbxmx"), "Pack"
        convert(src, dst)
        counts[kind] += 1
    print(counts)


if __name__ == "__main__":
    main()
