#!/bin/bash
# Pre-builds the generated map into map/ShrinkItMap.model.json so it is saved in the place file
# (you can see and edit it in Studio without pressing Play).
# Needs the `luau` command-line runtime (https://github.com/luau-lang/luau/releases) on your PATH.
# Run from the shrink-it folder:   bash tools/mapbake/bake.sh   then   rojo build -o ShrinkIt.rbxlx
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
P="$(cd "$HERE/../.." && pwd)"
python3 - "$HERE" "$P" <<'PY'
import sys
here, p = sys.argv[1], sys.argv[2]
body = ''
for k in ['GameConfig', 'TierConfig', 'ObjectConfig', 'RarityConfig', 'ChaserConfig']:
    body += 'MODULES["%s"] = function(script)\n%s\nend\n\n' % (k, open(p + '/src/ReplicatedStorage/Shared/Config/%s.lua' % k).read())
for k in ['MapDecor', 'MapService']:
    body += 'MODULES["%s"] = function(script)\n%s\nend\n\n' % (k, open(p + '/src/ServerScriptService/Services/%s.lua' % k).read())
run = '''
local RS = game:GetService("ReplicatedStorage")
local Shared = folderUnder(RS, "Shared")
local Config = folderUnder(Shared, "Config")
for _, n in ipairs({"GameConfig","TierConfig","ObjectConfig","RarityConfig","ChaserConfig"}) do mountModule(Config, n) end
local Services = folderUnder(game:GetService("ServerScriptService"), "Services")
mountModule(Services, "MapDecor")
local MapServiceMod = mountModule(Services, "MapService")
local ok, err = xpcall(function()
	require(MapServiceMod).Init({})
	io_out = serialize(workspace:FindFirstChild("ShrinkItMap"))
end, debug.traceback)
if not ok then print("BAKE ERROR " .. tostring(err)) else print(io_out) end
'''
src = ''.join(open(here + '/' + f).read() for f in ['math.luau', 'inst.luau', 'ser.luau'])
open(here + '/.bake_run.luau', 'w').write(src + body + run)
PY
cd "$HERE"
luau .bake_run.luau > .bake.out 2>&1
if grep -q "BAKE ERROR" .bake.out; then grep -A15 "BAKE ERROR" .bake.out; exit 1; fi
grep "^WARN" .bake.out || true
mkdir -p "$P/map"
grep '^{"Name":"ShrinkItMap"' .bake.out | sed 's/^{"Name":"ShrinkItMap",/{/' > "$P/map/ShrinkItMap.model.json"
rm -f .bake_run.luau .bake.out
echo "Baked map -> map/ShrinkItMap.model.json"
