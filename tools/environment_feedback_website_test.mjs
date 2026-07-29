import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const sourcePath = new URL("../web/landing/promo.html", import.meta.url);
const buildPath = new URL("../build/cloudflare-public/index.html", import.meta.url);
const [source, build] = await Promise.all([
  readFile(sourcePath, "utf8"),
  readFile(buildPath, "utf8"),
]);

const requiredPairs = [
  ["Environmental Simulation and Optical Feedback", "环境模拟与光学反馈"],
  ["The weather is not behind the image. It is inside the result.", "环境不是画面背后的装饰，而是观测结果的一部分。"],
];

for (const [english, chinese] of requiredPairs) {
  assert.ok(source.includes(english), `missing English copy: ${english}`);
  assert.ok(source.includes(chinese), `missing Chinese copy: ${chinese}`);
}

for (const mechanism of [
  "Clouds",
  "Poor seeing",
  "City sky glow",
  "Dark adaptation",
  "Earth rotation",
  "equatorial drive",
  "refractor",
  "Newtonian",
]) {
  assert.ok(source.toLowerCase().includes(mechanism.toLowerCase()), `missing mechanism: ${mechanism}`);
}

for (const codeSource of [
  "telescope_view.gd",
  "observation_system.gd",
]) {
  assert.ok(source.includes(codeSource), `missing implementation source: ${codeSource}`);
}

assert.match(source, /id="difference"/, "difference anchor must remain available");
assert.match(source, /scroll-behavior:smooth/, "smooth anchor navigation must remain enabled");
assert.match(
  source,
  /prefers-reduced-motion[\s\S]*scroll-behavior:auto/,
  "reduced motion must disable smooth anchor scrolling",
);
assert.equal(build, source, "deployed HTML copy must match the website source");

console.log("PASS environment feedback website contract");
