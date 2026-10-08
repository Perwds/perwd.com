// Packfinder download relay: a Cloudflare Worker that lets the Packfinder page
// read CurseForge modpack files. CurseForge's download server doesn't allow
// web pages to read its files directly; this relays requests and adds the
// header browsers need. It only relays CurseForge download links.
//
// Use: https://<your-worker>.workers.dev/?url=<CurseForge download link>

const ALLOWED_HOSTS = ["edge.forgecdn.net", "mediafilez.forgecdn.net"];

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Range",
  "Access-Control-Expose-Headers": "Content-Range, Content-Length",
};

export default {
  async fetch(request) {
    if (request.method === "OPTIONS") return new Response(null, { headers: CORS });
    if (request.method !== "GET") return new Response("Only GET is allowed", { status: 405, headers: CORS });

    let target;
    try {
      target = new URL(new URL(request.url).searchParams.get("url"));
    } catch {
      return new Response("Packfinder relay is running. Add ?url=<CurseForge download link>.", { status: 200, headers: CORS });
    }
    if (target.protocol !== "https:" || !ALLOWED_HOSTS.includes(target.hostname)) {
      return new Response("Only CurseForge download links are allowed", { status: 403, headers: CORS });
    }

    const headers = {};
    const range = request.headers.get("Range");
    if (range) headers.Range = range;

    const upstream = await fetch(target, { headers, redirect: "follow" });
    const response = new Response(upstream.body, upstream);
    for (const [k, v] of Object.entries(CORS)) response.headers.set(k, v);
    return response;
  },
};
