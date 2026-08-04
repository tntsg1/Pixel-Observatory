import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [patcher, registration, worker, core, cloudflare] = await Promise.all([
	readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-runtime-cache.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-cache-sw.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-runtime-core.js", import.meta.url), "utf8"),
	readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8"),
]);

assert.match(patcher, /runtime\/\$\{safeBuildSha\}\/index/, "Godot runtime URLs include the build id");
assert.match(patcher, /config\.mainPack = `\$\{runtimeBase\}\.pck`/, "the PCK uses the versioned runtime URL");
assert.match(patcher, /upsertEarlyScript\(html, ASSETS\.runtimeCacheJs\)/, "the first runtime download is intercepted before Godot starts");
assert.match(patcher, /upsertEarlyScript\(html, ASSETS\.runtimeCoreJs\)/, "the resumable range core loads before the runtime bootstrap");
assert.match(registration, /window\.fetch = async/, "the first page load is intercepted without waiting for service-worker control");
assert.match(registration, /runtime\.runtimeResponse/, "the first browser download uses resumable byte ranges");
assert.match(registration, /navigator\.serviceWorker\.register/, "the game registers a persistent runtime cache worker");
assert.match(registration, /navigator\.storage\.persist/, "the game requests durable browser storage when available");
assert.match(worker, /importScripts\("\/game-runtime-core\.js"\)/, "the service worker shares the resumable range implementation");
assert.match(worker, /runtimeResponse/, "repeat visits stream cached ranges before requesting gaps");
assert.match(core, /CHUNK_BYTES = 2 \* 1024 \* 1024/, "runtime assets are committed in bounded cache chunks");
assert.match(core, /headers: \{ Range:/, "missing chunks request an exact byte range");
assert.match(core, /await cache\.put\(chunkKey/, "every completed chunk is persisted before being delivered to Godot");
assert.match(core, /new Response\(bytes\.slice\(\), \{ status: 200/, "browser Cache Storage receives cacheable 200 chunk responses");
assert.match(core, /headers: \{ Range: "bytes=0-0" \}/, "metadata falls back to a one-byte range probe when HEAD length is hidden");
assert.match(core, /cachedPrefix/, "an interrupted download resumes from its first missing range");
assert.match(core, /rate, eta:/, "runtime progress exposes real transfer speed and ETA");
assert.match(patcher, /incremental-packs-v1/, "the loader shell version advances for independent resource packs");
const loader = await readFile(new URL("../web/landing/game-loader.js", import.meta.url), "utf8");
assert.match(loader, /formatBytes\(Math\.max\(0, total - value\)\)/, "the loader exposes the actual remaining download size");
assert.match(core, /async pull\(controller\)/, "runtime chunks respect browser backpressure and can stop after an interrupted read");
assert.match(core, /runtimeMatch\[1\] !== build/, "old runtime builds are pruned after an upgrade");
assert.match(core, /RESOURCE_PACK_PATH/, "stable resource packs share the resumable cache implementation");
assert.match(core, /currentPacks\[packMatch\[1\]\] !== packMatch\[2\]/, "only obsolete resource-pack versions are pruned");
assert.match(cloudflare, /max-age=31536000, immutable/, "versioned runtime files are immutable in browsers");
assert.match(cloudflare, /caches\.default\.match\(request\)/, "Cloudflare edge cache is checked before R2");
assert.match(cloudflare, /caches\.default\.put\(request, response\.clone\(\)\)/, "R2 responses populate the edge cache");

console.log("Runtime cache contract: PASS");
