import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [overlay, styles, builder, patcher, verifier] = await Promise.all([
  readFile(new URL("../web/landing/research-overlay.js", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/research-overlay.css", import.meta.url), "utf8"),
  readFile(new URL("./build_web_shell.mjs", import.meta.url), "utf8"),
  readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8"),
  readFile(new URL("./verify_web_game_shell.mjs", import.meta.url), "utf8"),
]);

assert.match(overlay, /observatory:research-checkpoint/, "The overlay must consume Godot checkpoint events.");
assert.match(overlay, /__poResearchContinue/, "Completion and skip must return control to Godot.");
assert.match(overlay, /__poResearchExitToArchive/, "Archive assignment must leave gameplay through Godot.");
assert.match(overlay, /PixelObservatoryResearch/, "Godot must be able to discover the overlay hooks.");
assert.match(overlay, /function canOfferBaseline\(\)/, "The L1 invitation gate must be explicit.");
assert.match(overlay, /function hasVerifiedGameplaySession\(\)/, "Later checkpoint eligibility must be explicit.");
assert.match(overlay, /const API = "\/api\/research"/, "Research requests must use the research service base path.");
assert.match(overlay, /fetch\(`\$\{API\}\$\{path\}`,\s*\{/, "Research requests must join the base path and endpoint path.");
assert.match(overlay, /request\("\/session"\)/, "Gameplay eligibility must refresh from the research server.");
assert.match(overlay, /request\("\/enroll", "POST"/, "Consent must enroll through the research service.");
assert.match(overlay, /request\("\/checkpoint", "POST"/, "Gameplay checkpoints must be recorded through the research service.");
assert.match(overlay, /request\("\/submit", "POST"/, "Answers must submit through the research service.");
assert.match(overlay, /request\("\/defer", "POST"/, "Later must use the server deferral rule.");
assert.match(overlay, /dataset\.researchProgress/, "Each survey card must expose visible progress.");
assert.match(overlay, /retry-submission/, "Failed answer submissions must retain a retry action.");
assert.match(overlay, /trapFocus/, "The modal must keep keyboard focus contained.");
assert.match(overlay, /Escape/, "Escape must resolve as a later action.");

const verifiedSessionFunction = overlay.match(/function hasVerifiedGameplaySession\(\)\s*\{[\s\S]*?\n\}/)?.[0] || "";
assert.match(verifiedSessionFunction, /serverRefreshedSession/, "Verified gameplay eligibility must use server-refreshed state.");
assert.doesNotMatch(verifiedSessionFunction, /localStorage|URLSearchParams|location\.search/, "Verified gameplay eligibility cannot self-attest from local storage or the URL.");

assert.match(styles, /prefers-reduced-motion:\s*reduce/, "The overlay must offer a reduced-motion fallback.");
assert.match(styles, /(?:1\d\d|2\d\d|3[0-2]0)ms/, "Overlay transitions must remain at or below 320 ms.");
assert.match(styles, /\.po-research-question-card/, "The questionnaire must render as progressive cards.");
assert.match(styles, /focus-visible/, "The overlay must retain a visible keyboard focus indicator.");
assert.match(styles, /overflow-y:\s*auto/, "The research dialog must be scrollable.");
assert.match(styles, /@media \(min-width: 1024px\)/, "The overlay must define desktop presentation.");
assert.match(styles, /@media \(max-width: 1023px\)/, "The overlay must define tablet presentation.");
assert.match(styles, /@media \(max-width: 640px\)/, "The overlay must define mobile presentation.");
assert.match(builder, /research-overlay\.css/, "The web shell build must publish the research stylesheet.");
assert.match(builder, /research-overlay\.js/, "The web shell build must publish the research controller.");
assert.match(patcher, /research-overlay\.css/, "The web shell must inject the research stylesheet.");
assert.match(patcher, /research-overlay\.js/, "The web shell must inject the research controller.");
assert.match(verifier, /research-overlay\.css/, "Shell verification must require the research stylesheet.");
assert.match(verifier, /research-overlay\.js/, "Shell verification must require the research controller.");

console.log("PASS research overlay contract");
