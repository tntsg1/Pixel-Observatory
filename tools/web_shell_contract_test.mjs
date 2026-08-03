import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { patchWebLoader } from "./patch_web_loader.mjs";

const [builder, patcher, cloudflareBuilder, workflow, diagnostic, exportPresets, gameLoader, gameLoaderCss, account] = await Promise.all([
	readFile(new URL("./build_web_shell.mjs", import.meta.url), "utf8"),
	readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8"),
	readFile(new URL("./build_cloudflare_release.mjs", import.meta.url), "utf8"),
	readFile(new URL("../.github/workflows/deploy-web.yml", import.meta.url), "utf8"),
	readFile(new URL("./web_export_diagnostic.gd", import.meta.url), "utf8"),
	readFile(new URL("../export_presets.cfg", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-loader.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/game-loader.css", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/account.js", import.meta.url), "utf8"),
]);

assert.match(builder, /\.godot-export/, "Godot export must stage outside the public game directory.");
assert.match(builder, /patchWebLoader/, "The public game page must be built through the custom shell patcher.");
assert.match(patcher, /pixel-observatory-loader-critical/, "A critical inline style must suppress the stock first paint.");
assert.match(patcher, /data-pixel-observatory-game-shell="v2"/, "The custom shell has a stable assertion marker.");
assert.match(patcher, /loader-loading-word/, "The first paint must clearly identify the loading state.");
assert.match(patcher, /<span>LOADING<\/span><small lang="zh-Hans">在加载中<\/small>/, "The main loading state remains legible in English and Chinese.");
assert.doesNotMatch(patcher, /class="loader-aperture"|class="loader-brand-mark"/, "The loading shell must not substitute an ambiguous icon for status text.");
assert.match(patcher, /messaging\.js/, "The game shell loads the existing messaging controller.");
assert.match(gameLoader, /game-compact-controls/, "Narrow viewports must retain an on-demand social and feedback entry point.");
assert.match(gameLoader, /po:open-inbox/, "The game rail must reuse the existing private-message drawer.");
assert.match(gameLoaderCss, /@media \(max-width: 1727px\)/, "16:9 desktop gutters must keep full rails when there is room.");
assert.doesNotMatch(gameLoaderCss, /max-aspect-ratio:\s*16\/9/, "A 1920×1080 desktop must not collapse the two side rails.");
assert.match(gameLoaderCss, /\.game-compact-actions\[hidden\]\s*\{\s*display: none !important;/, "Collapsed social controls must not leave focusable action buttons visible.");
assert.match(gameLoaderCss, /html\.game-social-compact-open \.game-compact-controls \{ top:/, "A portrait bottom sheet moves its close trigger into the letterbox safe area.");
assert.match(account, /document\.addEventListener\("click",event=>/, "Late-created game shell controls must use shared delegated account handlers.");
assert.match(account, /event\.target\.closest\("#feedback-open"\)/, "The game feedback control opens the existing privacy-scoped form.");
assert.match(cloudflareBuilder, /R2-only/, "Cloudflare packaging keeps large runtime binaries outside static assets.");
assert.match(workflow, /build\/web\/\.godot-export\/index\.html/, "CI exports to staging, not the game homepage.");
assert.match(workflow, /verify_web_game_shell\.mjs/, "CI asserts the final custom shell.");
assert.doesNotMatch(diagnostic, /build\/web\/game\/index\.html/, "The diagnostic export may not overwrite the public shell.");
for (const forbiddenExportPath of [".mailbox-test-users.json", ".mail-*.cookie", ".npm-cache-admin/**", "artifacts/**", "web/**", "tools/**"]) {
	assert.ok(exportPresets.includes(forbiddenExportPath), `Web PCK must exclude ${forbiddenExportPath}.`);
}

const temporaryDirectory = await mkdtemp(join(tmpdir(), "pixel-web-shell-contract-"));
const temporaryIndex = join(temporaryDirectory, "index.html");
try {
	await writeFile(temporaryIndex, '<!doctype html><html lang="en"><head><style>body{}</style></head><body><div id="status"><div id="status-notice"></div></div><script>const GODOT_CONFIG = {"executable":"index","fileSizes":{"index.pck":10,"index.wasm":20}};</script></body></html>');
	await patchWebLoader(temporaryIndex, { buildSha: "first-build" });
	await patchWebLoader(temporaryIndex, { buildSha: "second-build" });
	const patchedTwice = await readFile(temporaryIndex, "utf8");
	const openingHtmlTag = patchedTwice.match(/<html[^>]*>/i)?.[0] || "";
	assert.equal((openingHtmlTag.match(/data-pixel-observatory-game-shell=/g) || []).length, 1, "repatching keeps one shell marker");
	assert.equal((openingHtmlTag.match(/data-pixel-observatory-build=/g) || []).length, 1, "repatching keeps one build marker");
	assert.match(patchedTwice, /data-pixel-observatory-build="second-build"/, "repatching updates the build marker");
	assert.match(patchedTwice, /"executable":"runtime\/second-build\/index"/, "runtime files are content-versioned by build");
	assert.match(patchedTwice, /"mainPack":"runtime\/second-build\/index\.pck"/, "the main pack follows the versioned runtime path");
} finally {
	await rm(temporaryDirectory, { recursive: true, force: true });
}

console.log("PASS web shell contract: staged export, custom loader marker, Cloudflare package, and CI assertion");
