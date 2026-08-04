(() => {
  "use strict";

  // Large Godot assets are immutable per build, so they are safe to keep as
  // independently cached byte ranges.  A completed range survives a reload or
  // connection failure; the next launch only asks the server for the gap.
  const CACHE_NAME = "pixel-observatory-runtime-v2";
  const LEGACY_CACHE_NAME = "pixel-observatory-runtime-v1";
  const CHUNK_BYTES = 2 * 1024 * 1024;
  const RUNTIME_PATH = /^\/game\/runtime\/([a-zA-Z0-9._-]+)\/index\.(?:pck|wasm)$/;
  const CACHE_KEY = "__po_runtime_cache";

  function matchesRuntime(request) {
    const url = new URL(request.url);
    return request.method === "GET"
      && url.origin === self.location.origin
      && RUNTIME_PATH.test(url.pathname)
      && !request.headers.has("Range");
  }

  function keyFor(url, kind, index = "") {
    const key = new URL(url);
    key.searchParams.set(CACHE_KEY, `${kind}${index === "" ? "" : `-${index}`}`);
    return new Request(key.href, { method: "GET" });
  }

  function contentRange(start, end, total) {
    return `bytes ${start}-${end}/${total}`;
  }

  function byteLength(response) {
    const parsed = Number(response.headers.get("Content-Length"));
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
  }

  async function readBytes(response, onChunk) {
    if (!response.body) return new Uint8Array(await response.arrayBuffer());
    const reader = response.body.getReader();
    const pieces = [];
    let length = 0;
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      const value = next.value;
      pieces.push(value);
      length += value.byteLength;
      onChunk?.(value.byteLength, length);
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const piece of pieces) {
      bytes.set(piece, offset);
      offset += piece.byteLength;
    }
    return bytes;
  }

  function normalizeMeta(meta) {
    if (!meta || !Number.isFinite(Number(meta.total)) || Number(meta.total) <= 0) return null;
    return {
      total: Math.floor(Number(meta.total)),
      chunkBytes: Math.floor(Number(meta.chunkBytes)) || CHUNK_BYTES,
      contentType: String(meta.contentType || "application/octet-stream"),
      etag: String(meta.etag || ""),
      savedAt: Number(meta.savedAt) || Date.now(),
    };
  }

  async function readMeta(cache, url) {
    const response = await cache.match(keyFor(url, "meta"));
    if (!response) return null;
    try { return normalizeMeta(await response.json()); } catch (_) { return null; }
  }

  async function fetchMeta(cache, url, fetcher) {
    const previous = await readMeta(cache, url);
    if (previous) return previous;
    const head = await fetcher(new Request(url, { method: "HEAD", credentials: "same-origin" }));
    let total = head.ok ? byteLength(head) : 0;
    let metadataResponse = head;
    if (!total) {
      const probe = await fetcher(new Request(url, {
        method: "GET",
        credentials: "same-origin",
        headers: { Range: "bytes=0-0" },
      }));
      const match = probe.headers.get("Content-Range")?.match(/^bytes 0-0\/(\d+)$/);
      total = probe.status === 206 && match ? Number(match[1]) : 0;
      metadataResponse = probe;
      try { await probe.body?.cancel(); } catch (_) {}
    }
    if (!total) throw new Error("Runtime metadata did not include a content length.");
    const meta = {
      total,
      chunkBytes: CHUNK_BYTES,
      contentType: metadataResponse.headers.get("Content-Type") || head.headers.get("Content-Type") || "application/octet-stream",
      etag: metadataResponse.headers.get("ETag") || head.headers.get("ETag") || "",
      savedAt: Date.now(),
    };
    await cache.put(keyFor(url, "meta"), new Response(JSON.stringify(meta), {
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    }));
    return meta;
  }

  async function cachedPrefix(cache, url, meta) {
    const count = Math.ceil(meta.total / meta.chunkBytes);
    let bytes = 0;
    for (let index = 0; index < count; index += 1) {
      const response = await cache.match(keyFor(url, "chunk", index));
      if (!response) break;
      const expected = Math.min(meta.chunkBytes, meta.total - index * meta.chunkBytes);
      if (byteLength(response) !== expected) break;
      bytes += expected;
    }
    return bytes;
  }

  function notify(callback, detail) {
    try { callback?.({ source: "pixel-observatory-runtime", ...detail }); } catch (_) {}
  }

  async function copyLegacyFullResponse(request) {
    const legacy = await caches.open(LEGACY_CACHE_NAME);
    const response = await legacy.match(request);
    if (!response) return null;
    return response;
  }

  async function runtimeResponse(request, { fetcher = fetch, onProgress } = {}) {
    if (!matchesRuntime(request)) return fetcher(request);
    const url = request.url;
    const report = detail => notify(onProgress, { asset: new URL(url).pathname, ...detail });
    const cache = await caches.open(CACHE_NAME);
    const full = await cache.match(request);
    if (full) {
      report({ phase: "cached", loaded: byteLength(full), total: byteLength(full), cachedBytes: byteLength(full), rate: 0, eta: 0 });
      return full;
    }
    const legacy = await copyLegacyFullResponse(request);
    if (legacy) {
      report({ phase: "cached", loaded: byteLength(legacy), total: byteLength(legacy), cachedBytes: byteLength(legacy), rate: 0, eta: 0 });
      return legacy;
    }

    const meta = await fetchMeta(cache, url, fetcher);
    const prefix = await cachedPrefix(cache, url, meta);
    const totalChunks = Math.ceil(meta.total / meta.chunkBytes);
    let completeBytes = prefix;
    let networkBytes = 0;
    let networkStartedAt = 0;
    let cancelled = false;

    report({
      phase: prefix >= meta.total ? "cached" : (prefix ? "resuming" : "downloading"),
      loaded: completeBytes,
      total: meta.total,
      cachedBytes: prefix,
      rate: 0,
      eta: 0,
    });

    let index = 0;
    let busy = false;
    const body = new ReadableStream({
      async pull(controller) {
        if (busy || cancelled) return;
        busy = true;
        try {
          if (index >= totalChunks) {
            controller.close();
            return;
          }
          const start = index * meta.chunkBytes;
          const end = Math.min(meta.total - 1, start + meta.chunkBytes - 1);
          const expected = end - start + 1;
          const chunkKey = keyFor(url, "chunk", index);
          const cached = await cache.match(chunkKey);
          let bytes;
          if (cached && byteLength(cached) === expected) {
            bytes = new Uint8Array(await cached.arrayBuffer());
            completeBytes = Math.max(completeBytes, end + 1);
            report({ phase: completeBytes >= meta.total ? "ready" : "resuming", loaded: completeBytes, total: meta.total, cachedBytes: Math.max(prefix, completeBytes), rate: 0, eta: 0 });
          } else {
            if (!networkStartedAt) networkStartedAt = performance.now();
            const rangeResponse = await fetcher(new Request(url, { method: "GET", credentials: "same-origin", headers: { Range: `bytes=${start}-${end}` } }));
            if (rangeResponse.status !== 206) throw new Error(`Runtime range request failed (${rangeResponse.status}).`);
            if (rangeResponse.headers.get("Content-Range") !== contentRange(start, end, meta.total)) throw new Error("Runtime range response did not match the requested bytes.");
            bytes = await readBytes(rangeResponse, (delta, currentChunkBytes) => {
              networkBytes += delta;
              const elapsed = Math.max(.001, (performance.now() - networkStartedAt) / 1000);
              const rate = networkBytes / elapsed;
              const loaded = Math.min(meta.total, Math.max(completeBytes, start + currentChunkBytes));
              report({ phase: prefix ? "resuming" : "downloading", loaded, total: meta.total, cachedBytes: prefix, rate, eta: rate > 0 ? Math.max(0, meta.total - loaded) / rate : 0 });
            });
            if (bytes.byteLength !== expected) throw new Error("Runtime range ended before the requested byte count.");
            // Cache Storage rejects partial (206) responses in Chromium. The
            // cache key already identifies the byte range, so persist the
            // completed chunk as a normal 200 response.
            await cache.put(chunkKey, new Response(bytes.slice(), { status: 200, headers: { "Content-Type": meta.contentType, "Content-Length": String(expected), "X-PO-Content-Range": contentRange(start, end, meta.total) } }));
            completeBytes = end + 1;
            const elapsed = Math.max(.001, (performance.now() - networkStartedAt) / 1000);
            const rate = networkBytes / elapsed;
            report({ phase: completeBytes >= meta.total ? "ready" : (prefix ? "resuming" : "downloading"), loaded: completeBytes, total: meta.total, cachedBytes: completeBytes, rate, eta: rate > 0 ? Math.max(0, meta.total - completeBytes) / rate : 0 });
          }
          if (cancelled) return;
          controller.enqueue(bytes);
          index += 1;
          if (index >= totalChunks) controller.close();
        } catch (error) {
          report({ phase: "interrupted", loaded: completeBytes, total: meta.total, cachedBytes: completeBytes, error: String(error?.message || error) });
          controller.error(error);
        } finally {
          busy = false;
        }
      },
      cancel() { cancelled = true; },
    });

    return new Response(body, {
      status: 200,
      headers: {
        "Content-Type": meta.contentType,
        "Content-Length": String(meta.total),
        "Accept-Ranges": "bytes",
        ...(meta.etag ? { ETag: meta.etag } : {}),
      },
    });
  }

  async function prune(build) {
    const cache = await caches.open(CACHE_NAME);
    const keys = await cache.keys();
    await Promise.all(keys.map(request => {
      const match = new URL(request.url).pathname.match(RUNTIME_PATH);
      return match && match[1] !== build ? cache.delete(request) : Promise.resolve(false);
    }));
  }

  self.PORuntimeCache = Object.freeze({ CACHE_NAME, LEGACY_CACHE_NAME, matchesRuntime, runtimeResponse, prune });
})();
