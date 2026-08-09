import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [project, gameManager, saveManager, missionManager, mainMenu, learningCard, graduationScene, graduationScript, workflow, cloudflareBuilder] = await Promise.all([
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
assert.match(project, /run\/main_scene="res:\/\/scenes\/main_menu\.tscn"/);
const studyOrderSource = gameManager.match(/STUDY_CAMPAIGN_ORDER: Array\[int\] = \[([\s\S]*?)\n\]/)?.[1] || "";
const studyOrder = [...studyOrderSource.matchAll(/\b(\d+)\b/g)].map(match => Number(match[1]));
assert.deepEqual(studyOrder, Array.from({length: 24}, (_, index) => index + 1), "Study campaign must run every level sequentially from L1 through L24.");
assert.doesNotMatch(gameManager, /\[\s*16,\s*24\s*\]/, "The research route may not retain the retired L16-L24 shortcut.");
assert.match(gameManager, /func research_route_arm\(\) -> String/);
assert.match(gameManager, /func research_participant_id\(\) -> String/);
assert.match(gameManager, /func research_node_for_completed_level\(level_number: int\) -> String/);
assert.match(gameManager, /func launch_study_current_level/);
const studyLaunchBody = gameManager.match(/func launch_study_current_level[\s\S]*?\n\nfunc /)?.[0] || "";
assert.doesNotMatch(studyLaunchBody, /_debug_prepare_equipment\(\)/, "Study entry must not auto-install equipment.");
assert.doesNotMatch(studyLaunchBody, /_prepare_study_inventory\(\)/, "Study entry must not auto-unlock campaign equipment.");
assert.doesNotMatch(studyLaunchBody, /go\("(?:sky|radio_observation|space_observation)"\)/, "Study entry must not jump directly to an observation scene.");
assert.match(studyLaunchBody, /try_story_event\("intro", "observatory"\)/, "A fresh study must preserve the original opening story.");
assert.match(studyLaunchBody, /go\("observatory"\)/, "A resumed study must return to the original observatory flow.");
assert.match(gameManager, /furthest_completed_index/);
assert.match(saveManager, /STUDY_SAVE_PREFIX := "user:\/\/study_campaign_l1_24_"/);
assert.match(saveManager, /return STUDY_SAVE_PREFIX \+ _study_participant_id\(\)/);
assert.match(saveManager, /func seed_research_level_one_complete\(\) -> bool/);
assert.match(saveManager, /func clear_study_progress/);
assert.match(missionManager, /func use_campaign_order_subset/);
assert.match(mainMenu, /GameManager\.launch_study_current_level\(is_new_campaign\)/);
assert.match(learningCard, /if GameManager\.study_mode_active\(\)/);
assert.doesNotMatch(learningCard, /GameManager\.launch_study_current_level\(\)/, "Mission completion must return through the authored story and observatory route.");
assert.match(learningCard, /GameManager\.try_story_epilogue\(completed_level_number, "observatory"\)/);
assert.match(graduationScene, /study_graduation\.gd/);
assert.match(graduationScript, /pixel-observatory-study-godot/);
assert.doesNotMatch(workflow, /--path study_game/);
assert.doesNotMatch(workflow, /build_study_game_shell\.mjs/);
assert.doesNotMatch(cloudflareBuilder, /study\/game\/study\.pck/);
assert.match(cloudflareBuilder, /rel\.startsWith\("\."\)/);

console.log("Research route state and complete L1-L24 main-game campaign contract passed.");
