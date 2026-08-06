import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [page, entry, script, styles, worker, project, scene, gameScript, workflow, cloudflareBuilder, builder] = await Promise.all([
	readFile(new URL("../web/landing/study/index.html", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study-entry.txt", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study/study.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study/study.css", import.meta.url), "utf8"),
	readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8"),
	readFile(new URL("../study_game/project.godot", import.meta.url), "utf8"),
	readFile(new URL("../study_game/main.tscn", import.meta.url), "utf8"),
	readFile(new URL("../study_game/scripts/study_observatory.gd", import.meta.url), "utf8"),
	readFile(new URL("../.github/workflows/deploy-web.yml", import.meta.url), "utf8"),
	readFile(new URL("./build_cloudflare_release.mjs", import.meta.url), "utf8"),
	readFile(new URL("./build_study_game_shell.mjs", import.meta.url), "utf8"),
]);

for (const document of [page, entry]) {
	assert.match(document, /data-language="en"/);
	assert.match(document, /data-language="zh"/);
	assert.match(document, /study-godot-20260806/);
}

assert.match(script, /const languageStorageKey = "so-lang"/);
assert.doesNotMatch(script, /window\.open\s*\(/);
assert.match(script, /function godotGame\(\)/);
assert.match(script, /\/study\/game\/\?lang=/);
assert.match(script, /pixel-observatory-study-godot/);
assert.match(script, /event\.origin !== location\.origin/);
assert.match(script, /event\.source !== frame\.contentWindow/);
assert.match(script, /if \(serverState\.nextStage === "game"\) return godotGame\(\)/);

assert.match(styles, /\.language-switch/);
assert.match(styles, /\.godot-study-frame/);
assert.match(styles, /@media \(max-width: 600px\)/);
assert.match(styles, /prefers-reduced-motion/);

assert.match(project, /config\/custom_user_dir_name="PixelObservatoryStudy"/);
assert.match(project, /run\/main_scene="res:\/\/main\.tscn"/);
assert.match(scene, /study_observatory\.gd/);
assert.match(gameScript, /SAVE_PATH := "user:\/\/study_observation_v1\.json"/);
assert.doesNotMatch(gameScript, /savegame\.json/);
assert.match(gameScript, /tr_text\("Eye", "肉眼"\)/);
assert.match(gameScript, /Poor seeing caps useful magnification/);
assert.match(gameScript, /false.colour/i);
assert.match(gameScript, /dispersion/i);
assert.match(workflow, /--path study_game/);
assert.match(workflow, /--export-pack Web/);
assert.match(workflow, /build_study_game_shell\.mjs/);
assert.match(cloudflareBuilder, /study\/game\/study\.pck/);
assert.match(cloudflareBuilder, /allowedStaticPacks/);
assert.match(cloudflareBuilder, /rel\.startsWith\("\."\)/);
assert.match(builder, /mainPack: "study\.pck"/);

assert.match(worker, /const STUDY_MIN_GAME_SECONDS = 300/);
assert.match(worker, /activeSeconds = Math\.max\(0, Math\.min\(90/);

console.log("Study language and independent Godot mini-game contract passed.");
