import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const STATUS_MARKUP = `
		<div id="status">
			<div class="observatory-loader">
				<canvas id="loader-stars" aria-hidden="true"></canvas>
				<div class="loader-caustic" aria-hidden="true"></div>
				<div class="loader-scanlines" aria-hidden="true"></div>
				<header class="loader-topbar">
					<div class="loader-brand"><span class="loader-brand-mark" aria-hidden="true"></span>Starlight Observatory</div>
					<div class="loader-link-state">Browser observatory link established</div>
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
					<div class="loader-aperture" aria-hidden="true"><span id="loader-orbital-percent">0%</span></div>
					<div class="loader-title">
						<p class="loader-eyebrow">Observatory startup sequence</p>
						<h1>Pixel Observatory</h1>
						<p>Preparing your instruments, sky catalogue and observing station.</p>
					</div>
				</main>
				<footer class="loader-console">
					<div class="loader-progress-head">
						<span id="loader-phase">Preparing observatory runtime</span>
						<span id="loader-percent">0%</span>
					</div>
					<progress id="status-progress" aria-label="Game loading progress"></progress>
					<div class="loader-progress-meta"><span>Live package stream</span><span>Keep this tab open</span></div>
					<div class="loader-systems" aria-live="polite">
						<div class="loader-system"><span>Data archive</span><strong id="loader-loaded">Preparing stream</strong></div>
						<div class="loader-system"><span>Optical bench</span><strong id="loader-optical">Awaiting calibration</strong></div>
						<div class="loader-system"><span>Sky catalogue</span><strong id="loader-catalogue">Loading coordinates</strong></div>
					</div>
				</footer>
			</div>
			<img id="status-splash" class="show-image--false" src="index.png" alt="">
			<div id="status-notice"></div>
		</div>`;

export async function patchWebLoader(indexPath) {
	let html = await readFile(indexPath, "utf8");

	if (!html.includes("</head>") || !html.includes("</body>")) {
		throw new Error(`Unexpected Godot web shell in ${indexPath}`);
	}
	const before = html;
	if (!html.includes("href=\"../game-loader.css\"")) {
		html = html.replace("</head>", "\t\t<link rel=\"stylesheet\" href=\"../game-loader.css\">\n\t</head>");
	}
	html = html.replace(
		/<div id="status">[\s\S]*?<div id="status-notice"><\/div>\s*<\/div>/,
		STATUS_MARKUP.trim(),
	);
	if (!html.includes("src=\"../game-loader.js\"")) {
		html = html.replace("</body>", "\t\t<script src=\"../game-loader.js\"></script>\n\t</body>");
	}

	if (!html.includes("class=\"observatory-loader\"")) {
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
