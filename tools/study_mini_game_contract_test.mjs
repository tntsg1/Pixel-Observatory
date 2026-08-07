import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [page, entry, script, styles, worker, project, gameManager, saveManager, missionManager, mainMenu, learningCard, graduationScene, graduationScript, workflow, cloudflareBuilder] = await Promise.all([
	readFile(new URL("../web/landing/study/index.html", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study-entry.txt", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study/study.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study/study.css", import.meta.url), "utf8"),
	readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8"),
	readFile(new URL("../project.godot", import.meta.url), "utf8"),
	readFile(new URL("../scripts/systems/game_manager.gd", import.meta.url), "utf8"),
	readFile(new URL("../scripts/systems/save_manager.gd", import.meta.url), "utf8"),
	readFile(new URL("../scripts/systems/mission_manager.gd", import.meta.url), "utf8"),
	readFile(new URL("../scripts/ui/main_menu.gd", import.meta.url), "utf8"),
	readFile(new URL("../scripts/ui/learning_card.gd", import.meta.url), "utf8"),
	readFile(new URL("../scenes/study_graduation.tscn", import.meta.url), "utf8"),
	readFile(new URL("../scripts/ui/study_graduation.gd", import.meta.url), "utf8"),
	readFile(new URL("../.github/workflows/deploy-web.yml", import.meta.url), "utf8"),
	readFile(new URL("./build_cloudflare_release.mjs", import.meta.url), "utf8"),
]);

for (const document of [page, entry]) {
	assert.match(document, /data-language="en"/);
	assert.match(document, /data-language="zh"/);
	assert.match(document, /study-godot-20260806/);
}

assert.match(script, /const languageStorageKey = "so-lang"/);
assert.doesNotMatch(script, /window\.open\s*\(/);
assert.match(script, /function godotGame\(\)/);
assert.match(script, /mode:\s*"study"/);
assert.match(script, /study_reset/);
assert.match(script, /study_token:/);
assert.match(script, /pixel-observatory-study-godot/);
assert.match(script, /event\.origin !== location\.origin/);
assert.match(script, /event\.source !== frame\.contentWindow/);
assert.match(script, /if \(serverState\.nextStage === "game"\) return godotGame\(\)/);

assert.match(styles, /\.language-switch/);
assert.match(styles, /\.godot-study-frame/);
assert.match(styles, /@media \(max-width: 600px\)/);
assert.match(styles, /prefers-reduced-motion/);

assert.match(project, /run\/main_scene="res:\/\/scenes\/main_menu\.tscn"/);
assert.match(gameManager, /STUDY_CAMPAIGN_ORDER: Array\[int\] = \[16, 4, 10, 11, 20, 22, 25, 74, 84\]/);
assert.match(gameManager, /func launch_study_current_level/);
assert.match(gameManager, /_debug_prepare_equipment\(\)/);
assert.match(gameManager, /func _prepare_study_inventory/);
assert.match(gameManager, /furthest_completed_index/);
assert.match(saveManager, /STUDY_SAVE_PREFIX := "user:\/\/study_campaign_"/);
assert.match(saveManager, /return STUDY_SAVE_PREFIX \+ _study_participant_id\(\)/);
assert.match(saveManager, /func clear_study_progress/);
assert.match(missionManager, /func use_campaign_order_subset/);
assert.match(mainMenu, /GameManager\.launch_study_current_level\(\)/);
assert.match(learningCard, /if GameManager\.study_mode_active\(\)/);
assert.match(graduationScene, /study_graduation\.gd/);
assert.match(graduationScript, /pixel-observatory-study-godot/);
assert.doesNotMatch(workflow, /--path study_game/);
assert.doesNotMatch(workflow, /build_study_game_shell\.mjs/);
assert.doesNotMatch(cloudflareBuilder, /study\/game\/study\.pck/);
assert.match(cloudflareBuilder, /rel\.startsWith\("\."\)/);

assert.match(worker, /const STUDY_MIN_GAME_SECONDS = 300/);
assert.match(worker, /activeSeconds = Math\.max\(0, Math\.min\(90/);

console.log("Study language and extracted main-game campaign contract passed.");
