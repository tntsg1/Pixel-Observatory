import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [patcher, registration, worker, cloudflare] = await Promise.all([
	readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-runtime-cache.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-cache-sw.js", import.meta.url), "utf8"),
	readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8"),
]);

assert.match(patcher, /runtime\/\$\{safeBuildSha\}\/index/, "Godot runtime URLs include the build id");
assert.match(patcher, /config\.mainPack = `\$\{runtimeBase\}\.pck`/, "the PCK uses the versioned runtime URL");
assert.match(patcher, /upsertEarlyScript\(html, ASSETS\.runtimeCacheJs\)/, "the first runtime download is intercepted before Godot starts");
assert.match(registration, /window\.fetch = async/, "the first page load writes runtime responses without waiting for service-worker control");
assert.match(registration, /cache\.put\(request, response\.clone\(\)\)/, "the first browser download is persisted immediately");
assert.match(registration, /navigator\.serviceWorker\.register/, "the game registers a persistent runtime cache worker");
assert.match(registration, /navigator\.storage\.persist/, "the game requests durable browser storage when available");
assert.match(worker, /cache\.match\(request/, "repeat visits read runtime files from Cache Storage first");
assert.match(worker, /cache\.put\(request, response\.clone\(\)\)/, "successful first loads are persisted");
assert.match(worker, /match\[1\] !== build/, "old runtime builds are pruned after an upgrade");
assert.match(cloudflare, /max-age=31536000, immutable/, "versioned runtime files are immutable in browsers");
assert.match(cloudflare, /caches\.default\.match\(request\)/, "Cloudflare edge cache is checked before R2");
assert.match(cloudflare, /caches\.default\.put\(request, response\.clone\(\)\)/, "R2 responses populate the edge cache");

console.log("Runtime cache contract: PASS");
