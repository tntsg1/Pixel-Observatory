import assert from "node:assert/strict";

const baseUrl = process.env.PLAYTIME_TEST_URL || "http://127.0.0.1:8791";
const password = "ClockTest!2026";
const suffix = `${Date.now().toString(36)}${Math.floor(Math.random() * 10_000)}`;
const segmentSeconds = Math.max(1, Math.min(30, Math.floor(Number(process.env.PLAYTIME_SEGMENT_SECONDS || 2))));
const segmentCount = Math.max(1, Math.min(18, Math.floor(Number(process.env.PLAYTIME_SEGMENTS || 1))));
const testNetwork = 20 + Math.floor(Math.random() * 200);

function sessionCookie(response) {
	const raw = response.headers.get("set-cookie") || "";
	const match = raw.match(/(?:^|,\s*)(po_session=[^;]+)/);
	assert.ok(match, "Registration must return a server session cookie.");
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
	assert.equal(
		response.ok,
		true,
		`${options.method || "GET"} ${path} failed: ${response.status} ${JSON.stringify(data)}`,
	);
	return { response, data };
}

async function register(username, addressOctet) {
	const { response, data } = await request("/api/auth/register", {
		method: "POST",
		headers: { "X-Pixel-Observatory-Test-IP": `198.18.${testNetwork}.${addressOctet}` },
		body: JSON.stringify({
			username,
			password,
			website: "",
			turnstileToken: "local-test",
		}),
	});
	return { username: data.user.username, cookie: sessionCookie(response) };
}

async function heartbeat(account, sessionId, event, activeSeconds, reportId = crypto.randomUUID()) {
	const { data } = await request("/api/social/playtime", {
		method: "POST",
		body: JSON.stringify({ sessionId, reportId, event, activeSeconds }),
	}, account.cookie);
	return data;
}

const accountA = await register(`clocka${suffix}`, 21);
const accountB = await register(`clockb${suffix}`, 22);
const sessionA = `playtime_${suffix}_account_a`;
const sessionB = `playtime_${suffix}_account_b`;

const openedA = await heartbeat(accountA, sessionA, "resume", 0);
assert.equal(openedA.earnedSeconds, 0);
let creditedSeconds = 0;
let tickAReport = "";
for (let segment = 1; segment <= segmentCount; segment += 1) {
	// Cross the whole-second boundary before reporting a capped foreground
	// interval.  A 30-second segment deliberately waits 31 seconds so Worker
	// clock rounding cannot turn a verified 30 seconds into 29.
	await new Promise(resolve => setTimeout(resolve, segmentSeconds * 1_000 + (segmentSeconds >= 30 ? 1_000 : 200)));
	tickAReport = crypto.randomUUID();
	const tickA = await heartbeat(accountA, sessionA, "heartbeat", segmentSeconds, tickAReport);
	assert.equal(tickA.earnedSeconds, segmentSeconds, `Foreground segment ${segment} must be credited exactly.`);
	creditedSeconds += tickA.earnedSeconds;
	console.log(`PROGRESS foreground=${creditedSeconds}/${segmentSeconds * segmentCount}`);
}

const duplicateA = await heartbeat(accountA, sessionA, "heartbeat", segmentSeconds, tickAReport);
assert.equal(duplicateA.earnedSeconds, 0, "Immediate duplicate heartbeat must not double count.");
assert.equal(duplicateA.acknowledgedSeconds, segmentSeconds, "A retry receives its original acknowledgement without duplicate credit.");

await new Promise(resolve => setTimeout(resolve, 1_100));
const hiddenA = await heartbeat(accountA, sessionA, "heartbeat", 0);
assert.equal(hiddenA.earnedSeconds, 0, "A hidden-page heartbeat carries no active seconds.");

const refreshedA = await heartbeat(accountA, sessionA, "resume", 0);
assert.equal(refreshedA.earnedSeconds, 0, "Refreshing the same tab cannot duplicate recorded time.");
const competingA = await heartbeat(accountA, `competing_${suffix}_account_a`, "resume", 0);
assert.equal(competingA.leaseAccepted, false, "A concurrent second tab cannot claim the active lease.");

await heartbeat(accountB, sessionB, "resume", 0);
await new Promise(resolve => setTimeout(resolve, 1_100));
const leaveB = await heartbeat(accountB, sessionB, "leave", 1);
assert.equal(leaveB.earnedSeconds, 1, "A short session is settled on leave.");

const { data: profileA } = await request(
	`/api/social/profile?username=${encodeURIComponent(accountA.username)}`,
	{},
	accountA.cookie,
);
const { data: leaderboard } = await request("/api/social/leaderboard", {}, accountA.cookie);
const entryA = leaderboard.entries.find(entry => entry.username === accountA.username);
const entryB = leaderboard.entries.find(entry => entry.username === accountB.username);
assert.ok(entryA && entryB, "Both authenticated test observers appear on the leaderboard.");
assert.equal(profileA.profile.playSeconds, entryA.playSeconds, "Profile and leaderboard use the same total.");
assert.ok(entryA.playSeconds > 0, "Account A has non-zero effective playtime.");
assert.equal(entryA.playSeconds, creditedSeconds, "The first account records exactly the verified foreground total.");
assert.ok(entryB.playSeconds > 0, "Account B's short session is not lost.");

console.log(JSON.stringify({
	ok: true,
	accountA: { playSeconds: entryA.playSeconds },
	accountB: { playSeconds: entryB.playSeconds },
	profileMatchesLeaderboard: true,
	duplicateEarnedSeconds: duplicateA.earnedSeconds,
	hiddenEarnedSeconds: hiddenA.earnedSeconds,
	refreshEarnedSeconds: refreshedA.earnedSeconds,
	secondTabLeaseAccepted: competingA.leaseAccepted,
	foregroundSeconds: creditedSeconds,
}, null, 2));
