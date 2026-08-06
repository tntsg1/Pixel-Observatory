import { cp, mkdir, readdir, rm } from "node:fs/promises";
import { basename, join, relative, resolve } from "node:path";
import { verifyWebGameShell } from "./verify_web_game_shell.mjs";

const webDir = resolve(process.argv[2] || "build/web");
const publicDir = resolve(process.argv[3] || "build/cloudflare-public");
const r2RuntimeFiles = new Set(["index.pck", "index.wasm", "index.side.wasm"]);

function shouldCopy(source) {
	const rel = relative(webDir, source).replace(/\\/g, "/");
	if (!rel || rel === ".") return true;
	// Local/CI export probes are staging directories, never public assets.
	if (rel.startsWith(".")) return false;
	// The study experience is a separate compact Godot project. Its own pack
	// can remain a Worker asset without joining the main game's R2 runtime.
	if (rel === "study/game/study.pck") return true;
	// PCK files are always delivered by the authenticated R2 runtime route.  A
	// stray audit or prior export PCK in the source directory must never become
	// a Workers static asset (and therefore can never make deployment too large).
	if (basename(source).toLowerCase().endsWith(".pck")) return false;
	return !(rel.startsWith("game/") && r2RuntimeFiles.has(basename(source)));
}

async function listFiles(root, prefix = "") {
	const rows = await readdir(join(root, prefix), { withFileTypes: true });
	const files = [];
	for (const row of rows) {
		const rel = `${prefix}${row.name}`;
		if (row.isDirectory()) files.push(...await listFiles(root, `${rel}/`));
		else files.push(rel);
	}
	return files;
}

await verifyWebGameShell(webDir);
// Cloudflare's local asset server can keep this directory open on Windows, so
// do not remove the root directory.  Instead copy the desired release, then
// remove only individually verified stale files inside this generated output.
// This prevents an old .pck from being uploaded as a Workers Asset while never
// touching source or any path outside build/cloudflare-public.
await mkdir(publicDir, { recursive: true });
await cp(webDir, publicDir, {
	recursive: true,
	filter: shouldCopy,
});
const desiredFiles = new Set((await listFiles(webDir)).filter(rel => shouldCopy(join(webDir, rel))));
const staleFiles = (await listFiles(publicDir)).filter(rel => !desiredFiles.has(rel));
for (const stale of staleFiles) await rm(join(publicDir, stale), { force: true });

const gameIndex = await verifyWebGameShell(publicDir, {
	requireRuntime: false,
	allowedStaticPacks: ["study/game/study.pck"],
});
console.log(`Published Cloudflare static release at ${publicDir}; ${gameIndex} is custom; PCK/WASM remain R2-only.`);
