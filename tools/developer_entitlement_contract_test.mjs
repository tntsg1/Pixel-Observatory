import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [worker, migration, cloudSync, gameManager, social, announcement] = await Promise.all([
  readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8"),
  readFile(new URL("../migrations/0011_user_entitlements.sql", import.meta.url), "utf8"),
  readFile(new URL("../scripts/systems/cloud_sync_manager.gd", import.meta.url), "utf8"),
  readFile(new URL("../scripts/systems/game_manager.gd", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/social.js", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/release-announcement.json", import.meta.url), "utf8").then(JSON.parse),
]);

assert.match(migration, /CREATE TABLE IF NOT EXISTS user_entitlements/);
assert.match(migration, /developer_console INTEGER NOT NULL DEFAULT 0/);
assert.match(worker, /developerConsole:\s*user\.role === "admin" \|\| Number\(user\.developer_console \|\| 0\) === 1/);
assert.match(worker, /avatarFrame: SPECIAL_AVATAR_FRAMES\.has\(row\.avatar_frame\)/);
assert.match(cloudSync, /func can_use_developer_console\(\) -> bool:/);
assert.match(cloudSync, /developerConsole/);
assert.match(gameManager, /has_method\("can_use_developer_console"\)/);
assert.match(social, /frame-signal-gold/);
assert.equal(announcement.version, "v0.9.8");

console.log("DEVELOPER ENTITLEMENT CONTRACT PASS");
