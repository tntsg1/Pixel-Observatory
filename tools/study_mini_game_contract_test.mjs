import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [page, entry, script, styles, worker] = await Promise.all([
	readFile(new URL("../web/landing/study/index.html", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study-entry.txt", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study/study.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/study/study.css", import.meta.url), "utf8"),
	readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8"),
]);

for (const document of [page, entry]) {
	assert.match(document, /data-language="en"/);
	assert.match(document, /data-language="zh"/);
	assert.match(document, /study-mini-20260805/);
}

assert.match(script, /const languageStorageKey = "so-lang"/);
assert.match(script, /:mini:\$\{session\?\.participantId/);
assert.doesNotMatch(script, /window\.open\s*\(/);
assert.match(script, /Naked eye/);
assert.match(script, /Sidereal tracking/);
assert.match(script, /Infrared false colour/);
assert.match(script, /Pulsar dispersion/);
assert.match(script, /document\.hidden && document\.hasFocus/);

assert.match(styles, /\.language-switch/);
assert.match(styles, /\.observatory-console/);
assert.match(styles, /@media \(max-width: 600px\)/);
assert.match(styles, /prefers-reduced-motion/);

assert.match(worker, /const STUDY_MIN_GAME_SECONDS = 300/);
assert.match(worker, /activeSeconds = Math\.max\(0, Math\.min\(90/);

console.log("Study language and isolated mini-game contract passed.");
