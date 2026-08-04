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
assert.match(css, /\.loader-progress-rail\s*\{[\s\S]*?height:\s*16px/, "the primary loading progress is large enough to read at a glance");
assert.match(css, /\.loader-progress-fill\s*\{[\s\S]*?transform-origin:\s*left center/, "the visual progress fill grows from a stable physical origin");
assert.match(css, /transition:\s*transform \.38s cubic-bezier\(\.2, \.8, \.2, 1\)/, "progress changes retarget from the current transform without stepping");
const causticBlock = css.match(/\.loader-caustic\s*\{([^}]*)\}/)?.[1] || "";
assert.doesNotMatch(causticBlock, /mix-blend-mode/, "the full-screen caustic must not use a flicker-prone blend layer");
assert.match(css, /0%, 8% \{ opacity: 0;[\s\S]*?92%, 100% \{ opacity: 0;/, "the caustic resets only while fully transparent");
assert.match(css, /will-change:\s*transform/, "primary loader motion stays on compositor-friendly transforms");
assert.match(
	css,
	/@media \(prefers-reduced-motion: reduce\)[\s\S]*?loader-progress-fill::before \{ animation: none;/,
	"reduced motion removes decorative progress and caustic sweeps",
);
assert.match(patcher, /20260804-loader-stability-v3/, "the loader stability redesign invalidates previous cached shell assets");
assert.match(patcher, /class="loader-progress-rail"/, "the loader shell includes the custom glass progress rail");

console.log("PASS web loader motion: stable compositing, readable glass progress, reduced motion, and cache bust");
