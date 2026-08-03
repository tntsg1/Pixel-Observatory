import { access, cp, mkdir, readFile, readdir, rename, rm } from "node:fs/promises";
import { join, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import { patchWebLoader } from "./patch_web_loader.mjs";

const outputDir = resolve(process.argv[2] || "build/web");
const stagingDir = resolve(process.argv[3] || join(outputDir, ".godot-export"));
const landingDir = resolve("web/landing");
const gameDir = join(outputDir, "game");
const buildSha = process.env.PIXEL_OBSERVATORY_BUILD_SHA
	|| process.env.GITHUB_SHA
	|| (() => {
		try {
			return execFileSync("git", ["rev-parse", "--short=12", "HEAD"], { encoding: "utf8" }).trim();
		} catch {
			return "local";
		}
	})();

await readFile(join(stagingDir, "index.html")).catch(() => {
	throw new Error(`Missing staged Godot Web export at ${stagingDir}.`);
});

await rm(gameDir, { recursive: true, force: true });
await mkdir(gameDir, { recursive: true });
for (const entry of await readdir(stagingDir)) {
	if (entry !== "index.html") await cp(join(stagingDir, entry), join(gameDir, entry), { recursive: true });
}

const gameIndex = join(gameDir, "index.html");
await cp(join(stagingDir, "index.html"), gameIndex);
await patchWebLoader(gameIndex, { buildSha });

const safeBuildSha = buildSha.replace(/[^a-zA-Z0-9._-]/g, "-");
const runtimeDir = join(gameDir, "runtime", safeBuildSha);
await mkdir(runtimeDir, { recursive: true });
for (const runtimeFile of ["index.pck", "index.wasm", "index.side.wasm"]) {
	const source = join(gameDir, runtimeFile);
	await access(source).then(
		() => rename(source, join(runtimeDir, runtimeFile)),
		() => {},
	);
}

// Godot resolves AudioWorklet modules relative to config.executable. Since the
// executable is versioned above, keep the tiny worklet scripts beside it too.
// Retain the root copies for compatibility with cached pre-versioned shells.
for (const workletFile of ["index.audio.position.worklet.js", "index.audio.worklet.js"]) {
	const source = join(gameDir, workletFile);
	await access(source).then(
		() => cp(source, join(runtimeDir, workletFile)),
		() => {},
	);
}

await cp(landingDir, outputDir, { recursive: true, force: true });
await cp(join(landingDir, "promo.html"), join(outputDir, "index.html"));
await rm(stagingDir, { recursive: true, force: true });
console.log(`Published custom game shell at ${gameIndex}; immutable runtime=${runtimeDir}; build=${safeBuildSha}`);
