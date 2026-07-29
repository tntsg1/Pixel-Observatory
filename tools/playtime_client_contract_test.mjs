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
assert.match(source, /activeSeconds:\s*Math\.floor\(pendingSeconds\)/, "Only measured foreground time is hinted.");
assert.match(source, /leaseAccepted/, "The client respects the server's single-tab lease.");
assert.match(source, /playtime-sync/, "Sync failures expose a non-blocking UI state.");

console.log("PASS playtime client contract: auth, foreground lifecycle, retry, and account isolation");
