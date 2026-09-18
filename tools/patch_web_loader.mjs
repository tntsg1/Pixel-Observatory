import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

// Godot paints #status before it can fetch external styles. This critical
// layer is intentionally inline so the stock gray panel and Godot logo never
// get a chance to appear during a cold load.
const BASE_SHELL_CSS = `<style id="pixel-observatory-shell-base">
html,body,#canvas{margin:0;padding:0;border:0}html,body{min-height:100%;background:#05080e;overflow:hidden}#canvas{display:block}#canvas:focus{outline:0}
</style>`;
const CRITICAL_SHELL_CSS = `<style id="pixel-observatory-loader-critical">
html[data-pixel-observatory-game-shell="v2"] #status{position:fixed;inset:0;z-index:50;display:block;visibility:hidden;background:#05080e}
html[data-pixel-observatory-game-shell="v2"] #status-progress{position:absolute;inline-size:1px;block-size:1px;opacity:0;pointer-events:none}
html[data-pixel-observatory-game-shell="v2"] #status-notice{position:absolute;inset:auto 24px 24px;z-index:2}
</style>`;

const STATUS_MARKUP = `
		<div id="status">
			<div class="observatory-loader">
				<canvas id="loader-stars" aria-hidden="true"></canvas>
				<div class="loader-caustic" aria-hidden="true"></div>
				<div class="loader-scanlines" aria-hidden="true"></div>
				<header class="loader-topbar">
					<div class="loader-brand"><span id="loader-brand-name">Pixel Observatory</span></div>
					<div class="loader-link-state" id="loader-link-state">Browser observatory link established</div>
				</header>
				<main class="loader-stage">
					<div class="loader-reticle" aria-hidden="true"></div>
					<div class="loader-ticks" aria-hidden="true"></div>
					<div class="loader-axis" aria-hidden="true"></div>
					<div class="loader-axis horizontal" aria-hidden="true"></div>
					<div class="loader-scan" aria-hidden="true"></div>
					<i class="loader-node one" aria-hidden="true"></i>
					<i class="loader-node two" aria-hidden="true"></i>
					<i class="loader-node three" aria-hidden="true"></i>
					<div class="loader-title">
						<p class="loader-eyebrow" id="loader-eyebrow">Observatory startup sequence</p>
						<h1 class="loader-loading-word"><span>LOADING</span><small lang="zh-Hans">在加载中</small></h1>
						<strong id="loader-orbital-percent" aria-live="polite">0%</strong>
						<p id="loader-summary">Preparing your instruments, sky catalogue and observing station.</p>
					</div>
				</main>
				<footer class="loader-console">
					<div class="loader-progress-head">
						<span id="loader-phase">Preparing observatory runtime</span>
						<span id="loader-percent">0%</span>
					</div>
					<progress id="status-progress" aria-label="Game loading progress"></progress>
					<div class="loader-progress-rail" aria-hidden="true">
						<span class="loader-progress-fill" id="loader-progress-fill"><i></i></span>
					</div>
					<div class="loader-progress-meta"><span id="loader-stream">Live package stream</span><span id="loader-open">Keep this tab open</span></div>
					<div class="loader-systems" aria-live="polite">
						<div class="loader-system"><span id="loader-data-label">Data archive</span><strong id="loader-loaded">Preparing stream</strong></div>
						<div class="loader-system"><span id="loader-optical-label">Optical bench</span><strong id="loader-optical">Awaiting calibration</strong></div>
						<div class="loader-system"><span id="loader-catalogue-label">Sky catalogue</span><strong id="loader-catalogue">Loading coordinates</strong></div>
						<div class="loader-system"><span id="loader-network-label">Network link</span><strong id="loader-network">Measuring transfer</strong></div>
					</div>
				</footer>
			</div>
			<div id="status-notice"></div>
		</div>`;

const SHELL_VERSION = "20260917-release-bulletin";
const ASSETS = {
	loaderCss: `../game-loader.css?v=${SHELL_VERSION}`,
	loaderJs: `../game-loader.js?v=${SHELL_VERSION}`,
	accountCss: `../account.css?v=${SHELL_VERSION}`,
	accountJs: `../account.js?v=${SHELL_VERSION}`,
	inboxCss: `../inbox.css?v=${SHELL_VERSION}`,
	observationShareCss: `../observation-share.css?v=${SHELL_VERSION}`,
	messagingJs: `../messaging.js?v=${SHELL_VERSION}`,
	inboxJs: `../inbox.js?v=${SHELL_VERSION}`,
	observationShareJs: `../observation-share.js?v=${SHELL_VERSION}`,
	runtimeCacheJs: `../game-runtime-cache.js?v=${SHELL_VERSION}`,
	runtimeCoreJs: `../game-runtime-core.js?v=${SHELL_VERSION}`,
};

function escapeRegExp(value) {
	return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function upsertLink(html, href) {
	const base = href.split("?")[0];
	const matcher = new RegExp(`<link rel="stylesheet" href="${escapeRegExp(base)}(?:\\?[^\"]*)?">`);
	return matcher.test(html)
		? html.replace(matcher, `<link rel="stylesheet" href="${href}">`)
		: html.replace("</head>", `\t\t<link rel="stylesheet" href="${href}">\n\t</head>`);
}

function upsertScript(html, src) {
	const base = src.split("?")[0];
	const matcher = new RegExp(`<script src="${escapeRegExp(base)}(?:\\?[^\"]*)?"><\\/script>`);
	return matcher.test(html)
		? html.replace(matcher, `<script src="${src}"></script>`)
		: html.replace("</body>", `\t\t<script src="${src}"></script>\n\t</body>`);
}

function upsertEarlyScript(html, src) {
	const base = src.split("?")[0];
	const matcher = new RegExp(`\\s*<script src="${escapeRegExp(base)}(?:\\?[^\"]*)?"><\\/script>`);
	html = html.replace(matcher, "");
	const engineScript = /(\s*<script src="index\.js"><\/script>)/;
	return engineScript.test(html)
		? html.replace(engineScript, `\n\t\t<script src="${src}"></script>$1`)
		: html.replace("</head>", `\t\t<script src="${src}"></script>\n\t</head>`);
}

export async function patchWebLoader(indexPath, { buildSha = "local" } = {}) {
	let html = await readFile(indexPath, "utf8");
	if (!html.includes("</head>") || !html.includes("</body>")) {
		throw new Error(`Unexpected Godot web shell in ${indexPath}`);
	}
	const before = html;
	const safeBuildSha = String(buildSha).replace(/[^a-zA-Z0-9._-]/g, "") || "local";
	const runtimeBase = `runtime/${safeBuildSha}/index`;
	const manifestPath = new URL("./resource-packs/manifest.json", pathToFileURL(indexPath));
	const resourcePackManifest = JSON.parse(await readFile(manifestPath, "utf8"));
	if (resourcePackManifest.schema !== 1 || !Array.isArray(resourcePackManifest.packs) || !resourcePackManifest.packs.length) {
		throw new Error(`Invalid incremental resource-pack manifest beside ${indexPath}`);
	}
	const browserPacks = resourcePackManifest.packs.map(pack => ({
		id: String(pack.id),
		version: String(pack.version),
		size: Number(pack.size),
		url: String(pack.url),
		mountPath: String(pack.mountPath),
	}));
	html = html.replace(/<html([^>]*)>/i, (_match, attributes) => {
		const cleanAttributes = attributes
			.replace(/\sdata-pixel-observatory-game-shell="[^"]*"/gi, "")
			.replace(/\sdata-pixel-observatory-build="[^"]*"/gi, "");
		return `<html${cleanAttributes} data-pixel-observatory-game-shell="v2" data-pixel-observatory-build="${safeBuildSha}">`;
	});
	html = html.replace(/<style>[\s\S]*?<\/style>/i, BASE_SHELL_CSS);
	if (!html.includes("pixel-observatory-loader-critical")) {
		html = html.replace("</head>", `${CRITICAL_SHELL_CSS}\n\t</head>`);
	}
	html = upsertLink(html, ASSETS.loaderCss);
	html = upsertLink(html, ASSETS.accountCss);
	html = upsertLink(html, ASSETS.inboxCss);
	html = upsertLink(html, ASSETS.observationShareCss);
	html = html.replace(
		/<div id="status">[\s\S]*?<div id="status-notice"><\/div>\s*<\/div>/,
		STATUS_MARKUP.trim(),
	);
	html = upsertScript(html, ASSETS.accountJs);
	html = upsertScript(html, ASSETS.messagingJs);
	html = upsertScript(html, ASSETS.inboxJs);
	html = upsertScript(html, ASSETS.observationShareJs);
	html = upsertEarlyScript(html, ASSETS.runtimeCoreJs);
	html = upsertEarlyScript(html, ASSETS.runtimeCacheJs);
	html = upsertScript(html, ASSETS.loaderJs);

	// Rebuilding an already-patched shell must first collapse the previous
	// incremental preload wrapper. Otherwise the browser receives duplicate
	// const declarations and the loading UI stops updating before first paint.
	html = html
		.replace(/window\.PIXEL_OBSERVATORY_RESOURCE_PACKS = [^\n]*;\s*/g, "")
		.replace(/const PIXEL_OBSERVATORY_RESOURCE_PACKS = window\.PIXEL_OBSERVATORY_RESOURCE_PACKS;\s*/g, "")
		.replace(
			/const startIncrementalGame = engine\.startGame\.bind\(engine\);\s*engine\.startGame = override => Promise\.all\(PIXEL_OBSERVATORY_RESOURCE_PACKS\.map\(pack => engine\.preloadFile\(pack\.url, pack\.mountPath\)\)\)\.then\(\(\) => startIncrementalGame\(override\)\);\s*/g,
			"",
		);

	html = html.replace(/const GODOT_CONFIG = (\{[^\n]+\});/, (_match, serialized) => {
		const config = JSON.parse(serialized);
		const previousExecutable = config.executable;
		const originalPackSize = config.fileSizes?.[`${previousExecutable}.pck`]
			?? config.fileSizes?.[config.mainPack];
		const originalWasmSize = config.fileSizes?.[`${previousExecutable}.wasm`];
		config.executable = runtimeBase;
		config.mainPack = `${runtimeBase}.pck`;
		config.fileSizes = {
			[`${runtimeBase}.pck`]: originalPackSize,
			[`${runtimeBase}.wasm`]: originalWasmSize,
		};
		return `const GODOT_CONFIG = ${JSON.stringify(config)};`;
	});
	html = html.replace(
		/const engine = new Engine\(GODOT_CONFIG\);/,
		`window.PIXEL_OBSERVATORY_RESOURCE_PACKS = ${JSON.stringify(browserPacks)};\n`
		+ "const PIXEL_OBSERVATORY_RESOURCE_PACKS = window.PIXEL_OBSERVATORY_RESOURCE_PACKS;\n"
		+ "const engine = new Engine(GODOT_CONFIG);\n"
		+ "const startIncrementalGame = engine.startGame.bind(engine);\n"
		+ "engine.startGame = override => Promise.all(PIXEL_OBSERVATORY_RESOURCE_PACKS.map(pack => "
		+ "engine.preloadFile(pack.url, pack.mountPath))).then(() => startIncrementalGame(override));",
	);

	if (!html.includes("class=\"observatory-loader\"")
		|| !html.includes(`\"executable\":\"${runtimeBase}\"`)
		|| !html.includes("PIXEL_OBSERVATORY_RESOURCE_PACKS")
		|| html.includes("id=\"status-splash\"")) {
		throw new Error(`Could not replace Godot loading surface in ${indexPath}`);
	}
	await writeFile(indexPath, html);
	return html !== before;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
	const paths = process.argv.slice(2);
	if (!paths.length) throw new Error("Pass at least one generated Godot index.html path.");
	for (const path of paths) {
		const changed = await patchWebLoader(path);
		console.log(`${changed ? "Patched" : "Already patched"} ${path}`);
	}
}
