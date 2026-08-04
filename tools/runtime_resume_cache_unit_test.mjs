import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import vm from "node:vm";

const saved = { self: globalThis.self, caches: globalThis.caches, location: globalThis.location };
const entries = new Map();
const urlFor = request => typeof request === "string" ? request : request.url;
const cache = {
  async match(request) {
    const stored = entries.get(urlFor(request));
    return stored ? stored.clone() : undefined;
  },
  async put(request, response) { entries.set(urlFor(request), response.clone()); },
  async keys() { return [...entries.keys()].map(url => new Request(url)); },
  async delete(request) { return entries.delete(urlFor(request)); },
};

try {
  globalThis.self = globalThis;
  globalThis.location = new URL("https://cache-test.invalid/game/");
  globalThis.caches = { open: async () => cache };
  vm.runInThisContext(await readFile(new URL("../web/landing/game-runtime-core.js", import.meta.url), "utf8"));

  const total = 5 * 1024 * 1024;
  const requests = [];
  const fetcher = async request => {
    if (request.method === "HEAD") {
      return new Response(null, { headers: { "Content-Length": String(total), "Content-Type": "application/octet-stream" } });
    }
    const range = request.headers.get("Range");
    requests.push(range);
    const [, startText, endText] = /bytes=(\d+)-(\d+)/.exec(range);
    const start = Number(startText);
    const end = Number(endText);
    const bytes = new Uint8Array(end - start + 1).fill(start / (1024 * 1024));
    return new Response(bytes, { status: 206, headers: { "Content-Range": `bytes ${start}-${end}/${total}`, "Content-Length": String(bytes.byteLength), "Content-Type": "application/octet-stream" } });
  };
  const runtimeUrl = "https://cache-test.invalid/game/runtime/test-build/index.pck";
  const first = await self.PORuntimeCache.runtimeResponse(new Request(runtimeUrl), { fetcher });
  const reader = first.body.getReader();
  const chunk = await reader.read();
  assert.equal(chunk.value.byteLength, 2 * 1024 * 1024, "the first read receives exactly one persisted runtime chunk");
  await reader.cancel();
  assert.equal(requests.length, 1, "cancelling after one read does not fetch the remainder of the runtime");
  assert.equal(requests[0], "bytes=0-2097151", "the first session begins at byte zero");

  const resumed = await self.PORuntimeCache.runtimeResponse(new Request(runtimeUrl), { fetcher });
  assert.equal((await resumed.arrayBuffer()).byteLength, total, "the resumed stream reconstructs the complete runtime");
  assert.deepEqual(requests, ["bytes=0-2097151", "bytes=2097152-4194303", "bytes=4194304-5242879"], "the second session starts from the first missing persisted range");
  console.log("Runtime resume cache unit test: PASS");
} finally {
  globalThis.self = saved.self;
  globalThis.caches = saved.caches;
  globalThis.location = saved.location;
}
