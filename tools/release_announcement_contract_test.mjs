import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const [account, styles, announcement, builder] = await Promise.all([
	readFile(new URL("../web/landing/account.js", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/account.css", import.meta.url), "utf8"),
	readFile(new URL("../web/landing/release-announcement.json", import.meta.url), "utf8").then(JSON.parse),
	readFile(new URL("./build_web_shell.mjs", import.meta.url), "utf8"),
]);

assert.equal(announcement.schema, 1);
assert.equal(announcement.audience, "registered");
assert.match(announcement.version, /^v\d+\.\d+\.\d+/);
assert.ok(announcement.title.en && announcement.title.zh, "Release title must be bilingual.");
assert.ok(announcement.summary.en && announcement.summary.zh, "Release summary must be bilingual.");
const resolved = announcement.sections.find(section => section.heading.en === "Issues resolved");
assert.ok(resolved, "Every release bulletin must include a formal Issues resolved section.");
assert.ok(resolved.items.length > 0, "The bulletin must document at least one resolved issue.");
for (const section of announcement.sections) {
	assert.ok(section.heading.en && section.heading.zh, "Every release section heading must be bilingual.");
	for (const item of section.items) {
		assert.ok(item.en && item.zh, "Every release item must be bilingual.");
	}
}

assert.match(account, /state\.sessionResolved/,
	"The release bulletin waits for registered-user session discovery.");
assert.match(account, /po-release-announcement:\$\{state\.user\?\.id/,
	"Read state is isolated by registered user id and release version.");
assert.match(account, /gameContext\.scene[\s\S]*main_menu/,
	"Automatic presentation is limited to the game main screen.");
assert.match(account, /po-open-release/,
	"Registered observers can reopen the latest bulletin from the account panel.");
assert.match(styles, /po-release-dialog/);
assert.match(styles, /prefers-reduced-motion/);
assert.match(styles, /prefers-contrast/);
assert.match(builder, /cp\(landingDir, outputDir/,
	"The release document is copied into every generated Web release.");

console.log("RELEASE_ANNOUNCEMENT_CONTRACT_TEST_PASS");
