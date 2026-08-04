import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [builder, packWriter, patcher, mountLoader, cacheCore, cacheRegistration, worker, publisher, preset, workflow] = await Promise.all([
	readFile(new URL("./build_web_resource_packs.mjs", import.meta.url), "utf8"),
	readFile(new URL("./build_resource_pack.gd", import.meta.url), "utf8"),
	readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8"),
	readFile(new URL("../scripts/systems/web_resource_pack_loader.gd", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-runtime-core.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-runtime-cache.js", import.meta.url), "utf8"),
	readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8"),
	readFile(new URL("./publish_cloudflare_release.mjs", import.meta.url), "utf8"),
	readFile(new URL("../export_presets.cfg", import.meta.url), "utf8"),
	readFile(new URL("../.github/workflows/deploy-web.yml", import.meta.url), "utf8"),
]);

for (const id of ["audio", "astronomy-media", "star-catalog"]) {
	assert.match(builder, new RegExp(`id: ["']${id}["']`), `${id} has an independent pack definition`);
	assert.match(mountLoader, new RegExp(`/resource-packs/${id}\\.pck`), `${id} mounts before gameplay resources load`);
}
assert.match(builder, /createHash\("sha256"\)/, "pack versions are derived from content, not the whole game build");
assert.match(packWriter, /PCKPacker\.new\(\)/, "packs are written from an explicit resource list");
assert.doesNotMatch(packWriter, /project\.binary/, "stable packs do not inherit project metadata or gameplay scripts");
assert.match(patcher, /engine\.preloadFile\(pack\.url, pack\.mountPath\)/, "all independent packs preload before startGame");
assert.match(cacheCore, /RESOURCE_PACK_PATH/, "resource packs use the resumable browser cache");
assert.match(cacheCore, /currentPacks\[packMatch\[1\]\] !== packMatch\[2\]/, "obsolete pack versions are pruned independently");
assert.match(cacheRegistration, /PIXEL_OBSERVATORY_RESOURCE_PACKS/, "the service worker receives current pack versions");
assert.match(worker, /resource-packs\/\$\{pack\[1\]\}/, "Cloudflare resolves content-addressed pack routes from R2");
assert.match(publisher, /packManifest\.packs/, "deployment uploads every manifest pack to R2");
assert.match(preset, /assets\/audio\/\*\*/, "audio is absent from the frequently changing core PCK");
assert.match(preset, /assets\/telescope_view\/\*\*/, "astronomy imagery is absent from the core PCK");
assert.match(preset, /data\/deep_stars\.json/, "the deep-star catalogue is absent from the core PCK");
assert.match(workflow, /build_web_resource_packs\.mjs/, "CI builds independent packs for every release");

console.log("Incremental resource-pack contract: PASS");
