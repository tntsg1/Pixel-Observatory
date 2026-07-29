import assert from "node:assert/strict";

const baseUrl = process.env.PLAYTIME_TEST_URL || "https://pixelobservatorygame.com";
const accountA = {
	username: requireEnv("PLAYTIME_ACCOUNT_A"),
	password: requireEnv("PLAYTIME_PASSWORD_A"),
};
const accountB = {
	username: requireEnv("PLAYTIME_ACCOUNT_B"),
	password: requireEnv("PLAYTIME_PASSWORD_B"),
};
const runId = `${Date.now().toString(36)}${Math.floor(Math.random() * 10_000)}`;
const sessionA = `prod_playtime_${runId}_account_a`;
const competingSessionA = `prod_playtime_${runId}_second_tab`;
const sessionB = `prod_playtime_${runId}_account_b`;

function requireEnv(name) {
	const value = String(process.env[name] || "");
	assert.ok(value, `${name} must be set for the isolated production account.`);
	return value;
}

function sessionCookie(response) {
	const raw = response.headers.get("set-cookie") || "";
	const match = raw.match(/(?:^|,\s*)(po_session=[^;]+)/);
	assert.ok(match, "A production login must return a fresh browser-session cookie.");
	return match[1];
}

async function request(path, options = {}, cookie = "") {
	const response = await fetch(`${baseUrl}${path}`, {
		...options,
		headers: {
			"content-type": "application/json",
			...(cookie ? { cookie } : {}),
			...(options.headers || {}),
		},
	});
	const data = await response.json().catch(() => ({}));
	assert.equal(response.ok, true, `${options.method || "GET"} ${path} failed: ${response.status} ${JSON.stringify(data)}`);
	return { response, data };
}

async function login(account) {
	const { response, data } = await request("/api/auth/login", {
		method: "POST",
		body: JSON.stringify(account),
	});
	return { username: data.user.username, cookie: sessionCookie(response) };
}

async function heartbeat(account, sessionId, event, activeSeconds) {
	const { data } = await request("/api/social/playtime", {
		method: "POST",
		body: JSON.stringify({ sessionId, event, activeSeconds }),
	}, account.cookie);
	return data;
}

const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

const observerA = await login(accountA);
const observerB = await login(accountB);
const initialA = await request(`/api/social/profile?username=${encodeURIComponent(observerA.username)}`, {}, observerA.cookie);
const initialSecondsA = Number(initialA.data.profile.playSeconds || 0);

const openedA = await heartbeat(observerA, sessionA, "resume", 0);
assert.equal(openedA.earnedSeconds, 0, "Opening a foreground playtime lease earns no invented time.");

let creditedSeconds = 0;
for (let segment = 1; segment <= 18; segment += 1) {
	// Cross the whole-second boundary before claiming a capped 30-second foreground interval.
	// This keeps the production assertion deterministic when a request begins near a clock tick.
	await sleep(31_000);
	const tick = await heartbeat(observerA, sessionA, "heartbeat", 30);
	assert.equal(tick.earnedSeconds, 30, `Foreground segment ${segment} must earn exactly 30 seconds.`);
	creditedSeconds += tick.earnedSeconds;
	console.log(`PROGRESS: foreground ${creditedSeconds}/540 seconds`);
}
assert.equal(creditedSeconds, 540, "Nine real foreground minutes earn exactly 540 seconds.");

const duplicate = await heartbeat(observerA, sessionA, "heartbeat", 30);
assert.equal(duplicate.earnedSeconds, 0, "An immediate duplicate heartbeat cannot double-count.");

const refreshResume = await heartbeat(observerA, sessionA, "resume", 0);
assert.equal(refreshResume.earnedSeconds, 0, "A same-tab refresh/resume cannot duplicate recorded time.");

await sleep(2_000);
const hidden = await heartbeat(observerA, sessionA, "heartbeat", 0);
assert.equal(hidden.earnedSeconds, 0, "A hidden page with no foreground seconds earns nothing.");

const secondTab = await heartbeat(observerA, competingSessionA, "resume", 0);
assert.equal(secondTab.earnedSeconds, 0, "A concurrent second tab cannot claim the active lease.");
assert.equal(secondTab.leaseAccepted, false, "A concurrent second tab is rejected until the lease is stale.");

const openedB = await heartbeat(observerB, sessionB, "resume", 0);
assert.equal(openedB.earnedSeconds, 0, "The second account opens an independent lease.");
await sleep(2_000);
const leaveB = await heartbeat(observerB, sessionB, "leave", 2);
assert.ok(leaveB.earnedSeconds >= 1 && leaveB.earnedSeconds <= 2, "A short foreground session is settled independently on leave.");

const { data: profileA } = await request(`/api/social/profile?username=${encodeURIComponent(observerA.username)}`, {}, observerA.cookie);
const { data: profileB } = await request(`/api/social/profile?username=${encodeURIComponent(observerB.username)}`, {}, observerB.cookie);
const { data: leaderboard } = await request("/api/social/leaderboard", {}, observerA.cookie);
const entryA = leaderboard.entries.find(entry => entry.username === observerA.username);
const entryB = leaderboard.entries.find(entry => entry.username === observerB.username);
assert.ok(entryA && entryB, "Both freshly logged-in production observers appear on the leaderboard.");
assert.equal(profileA.profile.playSeconds, entryA.playSeconds, "Account A profile and leaderboard totals agree.");
assert.equal(profileB.profile.playSeconds, entryB.playSeconds, "Account B profile and leaderboard totals agree.");
assert.equal(entryA.playSeconds, initialSecondsA + 540, "Account A records exactly the 540 verified foreground seconds.");
assert.ok(entryB.playSeconds >= leaveB.earnedSeconds, "Account B retains its independently settled short session.");

console.log(JSON.stringify({
	ok: true,
	foregroundSeconds: creditedSeconds,
	duplicateEarnedSeconds: duplicate.earnedSeconds,
	refreshEarnedSeconds: refreshResume.earnedSeconds,
	hiddenEarnedSeconds: hidden.earnedSeconds,
	secondTabLeaseAccepted: secondTab.leaseAccepted,
	profileMatchesLeaderboard: true,
	secondAccountEarnedSeconds: leaveB.earnedSeconds,
}, null, 2));
