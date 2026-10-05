"""Upload assets/Sounds/*.ogg to Roblox (Open Cloud Assets API) and write the ids into SoundIds.lua.

Needs environment variables (set them in your environment settings, never paste keys in chat):
  ROBLOX_API_KEY      Open Cloud key with asset:read + asset:write
  ROBLOX_CREATOR_ID   your user id (or group id with ROBLOX_CREATOR_GROUP=1)
Run: python3 tools/sounds/upload.py
"""
import json, os, re, sys, time, urllib.request, uuid

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
SOUNDS = os.path.join(ROOT, "assets", "Sounds")
IDS = os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config", "SoundIds.lua")
KEY = os.environ.get("ROBLOX_API_KEY")
CREATOR = os.environ.get("ROBLOX_CREATOR_ID")
if not KEY or not CREATOR:
    sys.exit("Set ROBLOX_API_KEY and ROBLOX_CREATOR_ID first.")
creator = {"groupId": CREATOR} if os.environ.get("ROBLOX_CREATOR_GROUP") == "1" else {"userId": CREATOR}

def call(req):
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

def upload(name, path):
    boundary = uuid.uuid4().hex
    meta = json.dumps({"assetType": "Audio", "displayName": f"ShrinkIt {name}", "description": "Shrink It! sound",
                       "creationContext": {"creator": creator}})
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"request\"\r\n\r\n{meta}\r\n"
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"fileContent\"; filename=\"{name}.ogg\"\r\n"
            f"Content-Type: audio/ogg\r\n\r\n").encode() + open(path, "rb").read() + f"\r\n--{boundary}--\r\n".encode()
    op = call(urllib.request.Request("https://apis.roblox.com/assets/v1/assets", data=body, method="POST",
              headers={"x-api-key": KEY, "Content-Type": f"multipart/form-data; boundary={boundary}"}))
    for _ in range(30):
        if op.get("done"):
            return op["response"]["assetId"]
        time.sleep(2)
        op = call(urllib.request.Request(f"https://apis.roblox.com/assets/v1/{op['path']}", headers={"x-api-key": KEY}))
    raise RuntimeError(f"{name}: upload timed out")

src = open(IDS).read()
for f in sorted(os.listdir(SOUNDS)):
    if not f.endswith(".ogg"):
        continue
    name = f[:-4]
    if re.search(rf'\b{name} = "rbxassetid://\d+"', src):
        print("skip", name); continue
    aid = upload(name, os.path.join(SOUNDS, f))
    src = re.sub(rf'\b{name} = ""', f'{name} = "rbxassetid://{aid}"', src)
    open(IDS, "w").write(src)
    print(name, aid)
