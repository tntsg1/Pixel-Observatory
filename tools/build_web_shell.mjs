import { cp, mkdir, readFile, readdir, rename, rm } from "node:fs/promises";
import { join, resolve } from "node:path";
import { patchWebLoader } from "./patch_web_loader.mjs";

const outputDir = resolve(process.argv[2] || "build/web");
const landingDir = resolve("web/landing");
const gameDir = join(outputDir, "game");

await readFile(join(outputDir, "index.html")).catch(() => {
	throw new Error(`Missing Godot Web export at ${outputDir}.`);
});

await rm(gameDir, { recursive: true, force: true });
await mkdir(gameDir, { recursive: true });
for (const entry of await readdir(outputDir)) {
	if (entry !== "game") {
		await rename(join(outputDir, entry), join(gameDir, entry));
	}
}

const gameIndex = join(gameDir, "index.html");
await patchWebLoader(gameIndex);

await cp(landingDir, outputDir, { recursive: true, force: true });
await rename(join(outputDir, "promo.html"), join(outputDir, "index.html"));
console.log(`Published landing at ${outputDir} and game at ${gameDir}`);
