import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [page, source, styles] = await Promise.all([
  readFile(new URL("../web/landing/study/index.html", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/study/study.js", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/study/study.css", import.meta.url), "utf8"),
]);

assert.ok(
  source.includes("pixel-observatory:research-session:v2"),
  "Study session must use the v2 research session key.",
);
assert.ok(source.includes("TEXT_ARCHIVE_MODULES"), "Archive-text sessions must consume the shared content module.");
assert.ok(source.includes("/api/research/session"), "Restored sessions must load their server state.");
assert.ok(source.includes("/api/research/submit"), "The three-question form must submit to the research API.");
assert.ok(source.includes("/api/research/defer"), "The controller must support the two-reminder deferral API.");
assert.ok(source.includes("/api/research/exposure"), "Ordinary-game cross exposure must be recorded first.");
assert.ok(source.includes("/api/research/withdraw"), "Confirmed withdrawal must reach the research API.");
assert.ok(source.includes("noRemindSessionNodes"), "No-reminder choices must remain session-local.");
assert.ok(source.includes("po:research-reward-offer"), "Completed nodes must emit their reward offer event.");
assert.ok(source.includes("research_intro=1"), "Fresh entry must preserve the original Godot introduction.");
assert.ok(source.includes("study_reset"), "Fresh entry must reset the isolated Level 1 session.");
assert.match(page, /<script[^>]*src="study\.js/);
assert.match(styles, /@media \(max-width: 600px\)/);
assert.match(styles, /prefers-reduced-motion/);
assert.doesNotMatch(
  source,
  /renderMiniGame|miniState|reading_posttest|STUDY_MIN_GAME_SECONDS|pixel-observatory:study-session:v1|so-lang/,
  "The previous sequential mini-game and its stale storage keys must not remain active.",
);
assert.match(
  source,
  /function enableReminders\(nodeId\) \{[\s\S]*restartSurveyTimer\(nodeId\)/,
  "Re-enabling a paused survey must restart its answer-duration clock.",
);
assert.match(
  source,
  /function restartSurveyTimer\(nodeId\) \{[\s\S]*surveyNodeId = nodeId;[\s\S]*surveyStartedAt = Date\.now\(\);/,
  "The restarted survey timer must bind the current node to a fresh start time.",
);

console.log("research study page contract: ok");
