import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [css, patcher] = await Promise.all([
	readFile(new URL("../web/landing/game-loader.css", import.meta.url), "utf8"),
	readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8"),
]);

assert.match(css, /\.loader-scan::after\s*\{/, "the scanning arm needs a visible moving signal head");
assert.match(css, /\.loader-reticle::before[\s\S]*?conic-gradient/, "the rotating ring must be visually asymmetric");
assert.match(css, /\.loader-ticks[\s\S]*?conic-gradient/, "the rotating ticks need landmark segments so motion is visible");
assert.match(css, /loader-node-ping/, "status nodes provide staggered motion feedback");
assert.match(css, /loader-word-breathe/, "the loading word remains visibly alive during long downloads");
assert.match(css, /will-change:\s*transform/, "primary loader motion stays on compositor-friendly transforms");
assert.match(
	css,
	/@media \(prefers-reduced-motion: reduce\)[\s\S]*?loader-loading-word > span[\s\S]*?animation-duration:\s*5\.5s/,
	"reduced motion retains gentle non-rotational loading feedback",
);
assert.match(patcher, /20260804-loader-motion-v2/, "the Edge motion fix invalidates the previous cached shell assets");

console.log("PASS web loader motion: visible landmarks, compositor hints, reduced-motion feedback, and cache bust");
