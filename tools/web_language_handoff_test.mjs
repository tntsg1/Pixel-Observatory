import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [landing, loader, manager] = await Promise.all([
  readFile(new URL("../web/landing/promo.html", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/game-loader.js", import.meta.url), "utf8"),
  readFile(new URL("../scripts/systems/game_manager.gd", import.meta.url), "utf8"),
]);
const patcher = await readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8");

assert.match(landing, /localStorage\.setItem\('so-lang', l\)/, "homepage persists the explicit language");
assert.match(landing, /updateGameLinks\(l\)/, "homepage refreshes game links when language changes");
assert.match(landing, /url\.searchParams\.set\('lang', l\)/, "game links carry an explicit language handoff");

assert.match(loader, /new URLSearchParams\(location\.search\)\.get\("lang"\)/, "game shell accepts the explicit URL language");
assert.match(loader, /localStorage\.getItem\(languageStorageKey\)/, "game shell falls back to the shared persisted language");
assert.match(loader, /const zh = language === "zh"/, "loader copy uses the resolved language");
assert.match(loader, /window\.POLanguage\?\.current\(\) === "zh"/, "game social rails use the same resolved language");
assert.doesNotMatch(loader, /const zh = \/\^zh\\b\/i\.test\(navigator\.language/, "no game surface bypasses the homepage choice");

const readIndex = manager.indexOf("var website_language := _website_language_mode()")
const saveIndex = manager.indexOf("_unlock_parts_for_current_level()")
assert.ok(readIndex >= 0 && readIndex < saveIndex, "Godot applies the website language before normal startup saves progress");
assert.match(manager, /localStorage\.getItem\('so-lang'\)/, "Godot Web reads the shared website language");
assert.match(manager, /func _sync_website_language\(\)/, "in-game language changes sync back to the surrounding website");
assert.match(patcher, /20260804-loader-stability-v3/, "game shell URLs invalidate cached pre-stability-fix code");

console.log("Web language handoff contract passed.");
