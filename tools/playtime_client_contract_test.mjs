import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../web/landing/game-loader.js", import.meta.url), "utf8");

assert.doesNotMatch(
	source,
	/session\?\.authenticated/,
	"The Worker session response must not depend on a nonexistent client authentication flag.",
);
assert.match(source, /Boolean\(userId\)/, "A signed server-session user controls playtime reporting.");
assert.match(source, /document\.getElementById\("status"\)/, "Timing waits for the game to become interactive.");
assert.match(source, /MutationObserver/, "The loader observes the interactive transition.");
assert.match(source, /visibilitychange/, "Hidden and resumed pages are handled.");
assert.match(source, /pagehide/, "Short sessions are settled when leaving.");
assert.match(source, /beforeunload/, "Navigation has a keepalive fallback.");
assert.match(source, /pending-play-seconds/, "Failed reports retain a bounded pending segment.");
assert.match(source, /sessionUserKey/, "Account changes reset per-tab pending playtime.");
assert.match(source, /pending-playtime-report/, "A failed heartbeat persists one report identity for retry.");
assert.match(source, /reportId:\s*report\.id/, "Each heartbeat carries an idempotency report id.");
assert.match(source, /activeSeconds:\s*report\.activeSeconds/, "Only the measured foreground snapshot is hinted.");
assert.match(source, /acknowledgedSeconds/, "A retry clears only seconds the Worker has already acknowledged.");
assert.match(source, /leaseAccepted/, "The client respects the server's single-tab lease.");
assert.match(source, /playtime-sync/, "Sync failures expose a non-blocking UI state.");
assert.match(source, /effective-play-seconds/, "The rail persists only the current effective session clock across a refresh.");
assert.match(source, /observatory:playtime-local/, "The rail receives foreground-only session time updates.");
assert.match(source, /leaseAccepted && !document\.hidden/, "The visible session clock pauses when this tab loses the server lease.");

console.log("PASS playtime client contract: auth, foreground lifecycle, retry, and account isolation");
