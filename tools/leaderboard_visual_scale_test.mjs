import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const source = await readFile(new URL("../web/landing/social.js", import.meta.url), "utf8");
const start = source.indexOf("async function renderLeaderboard()");
const end = source.indexOf("async function renderCommunity()", start);
const leaderboard = source.slice(start, end);

assert.ok(start >= 0 && end > start, "leaderboard renderer must exist");
assert.match(leaderboard, /leaderSeconds[\s\S]*entry\.playSeconds/, "scale must use the leading play time");
assert.match(leaderboard, /seconds \/ leaderSeconds/, "each bar must be relative to the leader");
assert.doesNotMatch(leaderboard, /entry\.rank\.progress/, "rank progress must not drive leaderboard bars");
assert.match(leaderboard, /leaderboardLabel/, "the relative scale needs an accessible explanation");

console.log("leaderboard visual scale contract: PASS");
