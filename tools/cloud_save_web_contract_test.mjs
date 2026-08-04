import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [account, loader, cloudSync, saveManager, worker] = await Promise.all([
	readFile("web/landing/account.js", "utf8"),
	readFile("web/landing/game-loader.js", "utf8"),
	readFile("scripts/systems/cloud_sync_manager.gd", "utf8"),
	readFile("scripts/systems/save_manager.gd", "utf8"),
	readFile("cloudflare/worker.mjs", "utf8"),
]);

for (const label of ["刚刚已保存", "正在同步", "离线保存"]) {
	assert.ok(account.includes(label), `Account surface must expose ${label}.`);
	assert.ok(loader.includes(label), `In-game rail must expose ${label}.`);
}
assert.match(account, /pixelObservatoryMergeGuestSave/, "The account modal exposes one-click guest merge.");
assert.match(account, /pixelObservatorySessionChanged/, "Registration refreshes the running game session.");
assert.match(account, /pixelObservatoryCloudRequest/, "Browser-native fetch carries Web cloud requests without compressed HTTPRequest corruption.");
assert.match(cloudSync, /pixelObservatoryCloudResponse/, "Godot receives browser cloud responses through a stable callback.");
assert.match(cloudSync, /_guest_progress_candidate/, "Guest progress is frozen before cloud download.");
assert.match(cloudSync, /merge_required/, "Cloud sync has a non-destructive merge-required state.");
assert.match(cloudSync, /_union_arrays/, "Monotonic archive collections are merged, not replaced.");
assert.match(saveManager, /save_revision/, "Local saves carry a monotonic revision.");
assert.match(saveManager, /save_updated_at/, "Local saves carry an update timestamp.");
assert.match(worker, /stale_progress/, "The Worker rejects stale or regressive uploads.");
assert.match(worker, /preservesMonotonicProgress/, "The Worker verifies monotonic achievements before replacing an archive.");

console.log("CLOUD_SAVE_WEB_CONTRACT_TEST_PASS");
