"""Shrink It! sound pack: every game sound synthesized from scratch (no samples, no licenses).
Run: python3 tools/sounds/make_sounds.py  ->  assets/Sounds/*.ogg (upload them, paste ids in GameConfig.CustomSounds)."""
import numpy as np, wave, subprocess, os
SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "Sounds")
rng = np.random.default_rng(7)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, d=0.1, s=0.0, r=0.05, hold=0.0):
    a_, d_, h_, r_ = int(a*SR), int(d*SR), int(hold*SR), int(r*SR)
    e = np.concatenate([np.linspace(0, 1, max(a_,1)), np.linspace(1, s, max(d_,1)), np.full(h_, s), np.linspace(s, 0, max(r_,1))])
    return np.pad(e, (0, max(0, n - len(e))))[:n]
def tone(freq, dur, shape="sine", **kw):
    x = t(dur); f = np.full_like(x, freq) if np.isscalar(freq) else np.interp(x, np.linspace(0, dur, len(freq)), freq)
    ph = 2*np.pi*np.cumsum(f)/SR
    w = {"sine": np.sin(ph), "square": np.sign(np.sin(ph))*0.6, "tri": 2/np.pi*np.arcsin(np.sin(ph)), "saw": 2*((ph/(2*np.pi)) % 1)-1}[shape]
    return w * env(len(x), **kw)
def noise(dur, lp=1.0, **kw):
    n = rng.standard_normal(int(SR*dur))
    if lp < 1.0:  # one-pole low-pass
        y = np.zeros_like(n); a = lp
        for i in range(1, len(n)): y[i] = y[i-1] + a*(n[i]-y[i-1])
        n = y / (np.abs(y).max() + 1e-9)
    return n * env(len(n), **kw)
def mix(*parts):
    n = max(int(off*SR) + len(p) for p, off in parts); out = np.zeros(n)
    for p, off in parts:
        o = int(off*SR); out[o:o+len(p)] += p[:n-o]
    return out
def save(name, x, gain=0.85):
    x = x / (np.abs(x).max() + 1e-9) * gain
    path = os.path.join(OUT, name)
    with wave.open(path + ".wav", "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x*32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path + ".wav", "-c:a", "libvorbis", "-q:a", "6", path + ".ogg"], check=True)
    os.remove(path + ".wav")

os.makedirs(OUT, exist_ok=True)
save("Click", mix((tone(1800, 0.04, "sine", d=0.035), 0), (noise(0.02, 0.5, d=0.02), 0)))
save("Pop", tone([300, 900], 0.12, "sine", d=0.11))
save("Grab", mix((tone([500, 1100], 0.09, "tri", d=0.08), 0), (tone([800, 1600], 0.08, "sine", d=0.07), 0.05)))
save("Place", mix((tone([260, 140], 0.14, "sine", d=0.13), 0), (noise(0.05, 0.15, d=0.05), 0)))
save("Coin", mix((tone(1320, 0.12, "square", d=0.11), 0), (tone(1760, 0.3, "square", d=0.28), 0.07)), 0.6)
save("Purchase", mix((tone(1046, 0.1, "square", d=0.09), 0), (tone(1318, 0.1, "square", d=0.09), 0.08), (tone(1568, 0.1, "square", d=0.09), 0.16), (tone(2093, 0.45, "tri", d=0.43), 0.24), (noise(0.25, 0.9, d=0.24), 0.24)), 0.65)
save("Reward", mix(*[(tone(f, 0.18 if i < 3 else 0.6, "tri", d=0.17 if i < 3 else 0.58), i*0.11) for i, f in enumerate([523, 659, 784, 1046])], (tone(1568, 0.6, "sine", d=0.58), 0.33)))
save("Open", mix(*[(tone(f, 0.25, "sine", d=0.24), i*0.06) for i, f in enumerate([1046, 1318, 1568, 2093, 2637])]), 0.7)
save("Rare", mix(*[(tone(f*(1+0.003*np.sin(i)), 0.9, "sine", d=0.88), i*0.07) for i, f in enumerate([880, 1108, 1318, 1760, 2217, 2637])], (noise(0.9, 0.95, a=0.3, d=0.6), 0)), 0.7)
save("Charge", tone(np.linspace(200, 900, 50), 1.0, "saw", a=0.05, d=0.95, s=0.0), 0.5)
save("Shrink", mix((tone(np.linspace(1400, 180, 40), 0.45, "sine", d=0.44), 0), (tone(np.linspace(2100, 260, 40), 0.45, "tri", d=0.44), 0.02)), 0.75)
save("TooBig", mix((tone([220, 150], 0.35, "square", d=0.34), 0), (tone([226, 154], 0.35, "square", d=0.34), 0)), 0.5)
save("Error", mix((tone(200, 0.12, "square", d=0.11), 0), (tone(160, 0.18, "square", d=0.17), 0.13)), 0.5)
save("Hit", mix((noise(0.12, 0.6, d=0.11), 0), (tone([180, 60], 0.15, "sine", d=0.14), 0)))
save("Whack", mix((noise(0.08, 0.8, d=0.07), 0), (tone([400, 90], 0.2, "sine", d=0.19), 0)))
save("Trap", mix((noise(0.05, 1.0, d=0.04), 0), (tone(2600, 0.35, "sine", d=0.34), 0.01), (tone(3900, 0.25, "sine", d=0.24), 0.01)), 0.7)
save("Swing", noise(0.28, 0.25, a=0.08, d=0.2), 0.6)
save("Caught", mix(*[(tone(f, 0.28 if i < 3 else 0.7, "saw", d=0.27 if i < 3 else 0.68), i*0.26) for i, f in enumerate([392, 370, 349, 330])]), 0.55)
save("Alarm", mix(*[(tone(f, 0.16, "square", d=0.15), i*0.17) for i, f in enumerate([880, 660, 880, 660])]), 0.45)
save("Footstep", mix((noise(0.07, 0.12, d=0.06), 0), (tone([120, 70], 0.07, "sine", d=0.06), 0)), 0.6)
save("Notify", mix((tone(1318, 0.12, "sine", d=0.11), 0), (tone(1760, 0.22, "sine", d=0.21), 0.09)), 0.6)
save("LevelUp", mix(*[(tone(f, 0.12, "square", d=0.11), i*0.08) for i, f in enumerate([523, 659, 784, 1046, 1318])], (tone(1568, 0.5, "tri", d=0.48), 0.4)), 0.55)
save("Boss", mix((tone([90, 60], 1.2, "saw", a=0.1, d=1.1), 0), (tone([135, 90], 1.2, "saw", a=0.1, d=1.1), 0), (noise(1.2, 0.05, a=0.2, d=1.0), 0)), 0.7)
print(sorted(os.listdir(OUT)))
