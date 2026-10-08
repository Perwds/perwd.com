// Packfinder download relay: a Cloudflare Worker that lets the Packfinder page
// read CurseForge modpack files. CurseForge's download server doesn't allow
// web pages to read its files directly; this relays requests and adds the
// header browsers need. It only talks to CurseForge's download servers and the
// public APIs of the other mod sites Packfinder searches.
//
//   GET  /?url=<link>                        relays one (partial) download or API call
//   POST /manifests                          reads the mod list of up to 10 packs at once
//        body: {"files":[{"id":123,"size":4567,"urls":["https://mediafilez.forgecdn.net/..."]}]}
//        answer: {"results":{"123":[projectID, ...] | null | {"error":"..."}}}

const ALLOWED_HOSTS = ["edge.forgecdn.net", "mediafilez.forgecdn.net"];
// Sites some browsers can't search directly; relayed for GET requests only.
const API_HOSTS = ["api.modpacks.ch", "api.feed-the-beast.com", "api.technicpack.net", "hangar.papermc.io", "api.spiget.org"];
const MAX_FILES = 10;
// Free Workers may make 50 outgoing requests per incoming request; keep a margin.
const SUBREQUEST_BUDGET = 45;

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Range, Content-Type",
  "Access-Control-Expose-Headers": "Content-Range, Content-Length",
  "Access-Control-Max-Age": "86400",
};

function allowed(raw, hosts = ALLOWED_HOSTS) {
  try {
    const u = new URL(raw);
    return u.protocol === "https:" && hosts.includes(u.hostname) ? u : null;
  } catch {
    return null;
  }
}

function json(data, status = 200) {
  return new Response(JSON.stringify(data), { status, headers: { ...CORS, "Content-Type": "application/json" } });
}

export default {
  async fetch(request) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    const path = new URL(request.url).pathname;

    if (request.method === "POST" && path === "/manifests") return manifests(request);
    if (request.method !== "GET") return new Response("Only GET and POST /manifests are allowed", { status: 405, headers: CORS });

    const raw = new URL(request.url).searchParams.get("url");
    if (!raw) return new Response("Packfinder relay is running. Add ?url=<CurseForge download link>.", { headers: CORS });
    const target = allowed(raw, [...ALLOWED_HOSTS, ...API_HOSTS]);
    if (!target) return new Response("Only CurseForge downloads and supported mod sites are allowed", { status: 403, headers: CORS });

    const headers = { "User-Agent": "Packfinder relay (https://github.com/Perwds/perwd.com)" };
    const range = request.headers.get("Range");
    if (range) headers.Range = range;
    const upstream = await fetch(target, { headers, redirect: "follow" });
    const response = new Response(upstream.body, upstream);
    for (const [k, v] of Object.entries(CORS)) response.headers.set(k, v);
    return response;
  },
};

async function manifests(request) {
  let body;
  try {
    body = JSON.parse(await request.text());
  } catch {
    return json({ error: "Body must be JSON" }, 400);
  }
  const files = (Array.isArray(body.files) ? body.files : []).slice(0, MAX_FILES);
  const budget = { left: SUBREQUEST_BUDGET };
  const results = {};
  await Promise.all(files.map(async f => {
    const urls = (Array.isArray(f.urls) ? f.urls : []).map(allowed).filter(Boolean);
    const size = Number(f.size);
    if (!urls.length || !(size > 0)) { results[f.id] = { error: "bad file" }; return; }
    let lastErr = "no url worked";
    for (const url of urls) {
      try {
        const text = await readZipEntry(url, size, "manifest.json", budget);
        results[f.id] = text == null ? null : manifestIds(text);
        return;
      } catch (e) {
        lastErr = String(e && e.message || e);
        if (lastErr === "budget") break;
      }
    }
    results[f.id] = { error: lastErr };
  }));
  return json({ results });
}

// Pulls projectIDs out of manifest.json without a full JSON parse (cheaper on CPU).
function manifestIds(text) {
  const ids = new Set();
  for (const m of text.matchAll(/"projectID"\s*:\s*(\d+)/g)) ids.add(Number(m[1]));
  return [...ids];
}

async function rangeFetch(url, start, end, budget) {
  if (budget.left-- <= 0) throw new Error("budget");
  const r = await fetch(url, { headers: { Range: `bytes=${start}-${end}` } });
  if (r.status === 206) return new Uint8Array(await r.arrayBuffer());
  if (r.status === 200) {
    if (end - start > 8e6) { r.body?.cancel(); throw new Error("no range support"); }
    return new Uint8Array(await r.arrayBuffer()).subarray(start, end + 1);
  }
  throw new Error("download server returned " + r.status);
}

async function inflateRaw(bytes) {
  const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate-raw"));
  return new Response(stream).text();
}

async function readZipEntry(url, total, wanted, budget) {
  const dec = new TextDecoder();
  // Fast path: CurseForge exports usually put manifest.json first in the zip.
  const headLen = Math.min(total, 32768);
  const head = await rangeFetch(url, 0, headLen - 1, budget);
  const hv = new DataView(head.buffer, head.byteOffset, head.byteLength);
  if (head.length >= 30 && hv.getUint32(0, true) === 0x04034b50) {
    const flags = hv.getUint16(6, true), method = hv.getUint16(8, true), size = hv.getUint32(18, true);
    const nlen = hv.getUint16(26, true), elen = hv.getUint16(28, true);
    if (dec.decode(head.subarray(30, 30 + nlen)) === wanted && !(flags & 8) && size > 0 && (method === 0 || method === 8)) {
      const start = 30 + nlen + elen;
      const data = start + size <= head.length ? head.subarray(start, start + size) : (await rangeFetch(url, 0, start + size - 1, budget)).subarray(start, start + size);
      return method === 0 ? dec.decode(data) : inflateRaw(data);
    }
  }
  // Otherwise find it through the zip's central directory at the end of the file.
  const tailLen = Math.min(total, 65536 + 22);
  const tailStart = total - tailLen;
  const tail = await rangeFetch(url, tailStart, total - 1, budget);
  const tv = new DataView(tail.buffer, tail.byteOffset, tail.byteLength);
  let eocd = -1;
  for (let i = tail.length - 22; i >= 0; i--) if (tv.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
  if (eocd < 0) throw new Error("not a zip");
  const cdSize = tv.getUint32(eocd + 12, true), cdOff = tv.getUint32(eocd + 16, true);
  if (cdOff === 0xffffffff) throw new Error("zip64 not supported");
  const cd = cdOff >= tailStart ? tail.subarray(cdOff - tailStart, cdOff - tailStart + cdSize) : await rangeFetch(url, cdOff, cdOff + cdSize - 1, budget);
  const cv = new DataView(cd.buffer, cd.byteOffset, cd.byteLength);
  let q = 0, entry = null;
  while (q + 46 <= cd.length && cv.getUint32(q, true) === 0x02014b50) {
    const nlen = cv.getUint16(q + 28, true), elen = cv.getUint16(q + 30, true), clen = cv.getUint16(q + 32, true);
    if (dec.decode(cd.subarray(q + 46, q + 46 + nlen)) === wanted) {
      entry = { method: cv.getUint16(q + 10, true), size: cv.getUint32(q + 20, true), off: cv.getUint32(q + 42, true) };
      break;
    }
    q += 46 + nlen + elen + clen;
  }
  if (!entry) return null;
  let local = await rangeFetch(url, entry.off, Math.min(total - 1, entry.off + 30 + 1024 + entry.size), budget);
  const lv = new DataView(local.buffer, local.byteOffset, local.byteLength);
  if (lv.getUint32(0, true) !== 0x04034b50) throw new Error("bad zip entry");
  const start = 30 + lv.getUint16(26, true) + lv.getUint16(28, true);
  if (start + entry.size > local.length) local = await rangeFetch(url, entry.off, entry.off + start + entry.size - 1, budget);
  const data = local.subarray(start, start + entry.size);
  if (entry.method === 0) return dec.decode(data);
  if (entry.method === 8) return inflateRaw(data);
  throw new Error("unsupported compression");
}
