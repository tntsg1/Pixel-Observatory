import assert from "node:assert/strict";
import { access, readFile, readdir, stat } from "node:fs/promises";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

export async function verifyWebGameShell(outputPath = "build/web", {
	requireRuntime = true,
	allowedStaticPacks = [],
} = {}) {
const outputDir = resolve(outputPath);
const gameDir = join(outputDir, "game");
const gameIndex = join(gameDir, "index.html");
const html = await readFile(gameIndex, "utf8");
const packRoot = join(gameDir, "resource-packs");
const packManifest = JSON.parse(await readFile(join(packRoot, "manifest.json"), "utf8"));
assert.equal(packManifest.schema, 1, "Incremental resource-pack manifest schema must be supported.");
assert.deepEqual(packManifest.packs.map(pack => pack.id).sort(), ["astronomy-media", "audio", "star-catalog"]);

for (const marker of [
	'data-pixel-observatory-game-shell="v2"',
	"pixel-observatory-loader-critical",
	'class="observatory-loader"',
	'class="loader-loading-word"',
	"<span>LOADING</span>",
	'<small lang="zh-Hans">在加载中</small>',
	'../game-loader.css?v=',
	'../game-loader.js?v=',
	'../account.js?v=',
	'../messaging.js?v=',
	'../inbox.js?v=',
	"PIXEL_OBSERVATORY_RESOURCE_PACKS",
]) assert.ok(html.includes(marker), `Missing required custom game-shell marker: ${marker}`);
for (const pack of packManifest.packs) {
	assert.ok(html.includes(pack.version), `Game shell does not preload ${pack.id} version ${pack.version}.`);
	assert.ok(html.includes(pack.mountPath), `Game shell does not expose ${pack.id} at ${pack.mountPath}.`);
}
for (const defaultMarker of ["background-color: #242424", 'id="status-splash"', 'class="loader-aperture"', 'class="loader-brand-mark"']) {
	assert.ok(!html.includes(defaultMarker), `Default Godot splash marker leaked into game shell: ${defaultMarker}`);
}
await access(join(gameDir, "index.js"));
if (requireRuntime) {
	const build = html.match(/data-pixel-observatory-build="([a-zA-Z0-9._-]+)"/)?.[1];
	assert.ok(build, "Game shell must expose its immutable runtime build id.");
	for (const file of [
		"index.wasm",
		"index.pck",
		"index.audio.position.worklet.js",
		"index.audio.worklet.js",
	]) await access(join(gameDir, "runtime", build, file));
	for (const pack of packManifest.packs) {
		const packed = join(packRoot, pack.id, `${pack.version}.pck`);
		assert.equal((await stat(packed)).size, pack.size, `${pack.id} manifest size must match its PCK.`);
	}
}
if (!requireRuntime) {
	const findPackedFiles = async (dir, prefix = "") => {
		const rows = await readdir(join(dir, prefix), { withFileTypes: true });
		const results = [];
		for (const row of rows) {
			const rel = `${prefix}${row.name}`;
			if (row.isDirectory()) results.push(...await findPackedFiles(dir, `${rel}/`));
			else if (/\.pck$/i.test(row.name)) results.push(rel);
		}
		return results;
	};
	const packedFiles = await findPackedFiles(outputDir);
	assert.deepEqual(
		packedFiles.sort(),
		[...allowedStaticPacks].sort(),
		`Cloudflare static assets contain an unexpected PCK set: ${packedFiles.join(", ")}`,
	);
}
await access(join(outputDir, "game-loader.js"));
await access(join(outputDir, "game-loader.css"));
return gameIndex;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	const outputDir = process.argv[2] || "build/web";
	const requireRuntime = !process.argv.includes("--assets-only");
	const gameIndex = await verifyWebGameShell(outputDir, { requireRuntime });
	console.log(`PASS custom Web game shell: ${gameIndex}`);
}
