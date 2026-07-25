import { cp, mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { join, resolve } from "node:path";

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

// Keep the engine's loading surface intentionally dark while the game initializes.
const gameIndex = join(gameDir, "index.html");
let gameHtml = await readFile(gameIndex, "utf8");
gameHtml = gameHtml
	.replace("background-color: #242424;", "background: radial-gradient(circle at 50% 42%, #13283a 0%, #050b13 58%, #010305 100%);")
	.replace("<div id=\"status\">", "<div id=\"status\"><div style=\"position:absolute;bottom:12%;font:600 12px/1.4 Arial,sans-serif;letter-spacing:.16em;color:#d6a968;z-index:2\">CALIBRATING OBSERVATORY SYSTEMS</div>");
await writeFile(gameIndex, gameHtml);

await cp(landingDir, outputDir, { recursive: true, force: true });
await rename(join(outputDir, "promo.html"), join(outputDir, "index.html"));
console.log(`Published landing at ${outputDir} and game at ${gameDir}`);
