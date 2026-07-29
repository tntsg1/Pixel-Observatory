import assert from "node:assert/strict";
import { calculatePlaytimeTransition } from "../cloudflare/worker.mjs";

const SESSION_A = "play_session_account_a_0001";
const SESSION_B = "play_session_account_a_0002";

function apply(row, input) {
	const transition = calculatePlaytimeTransition({
		previousSeconds: row.playSeconds,
		previousHeartbeat: row.heartbeat,
		previousSession: row.session,
		...input,
	});
	return {
		playSeconds: transition.playSeconds,
		heartbeat: transition.nextHeartbeat,
		session: transition.nextSession,
		transition,
	};
}

let row = { playSeconds: 0, heartbeat: 0, session: "" };
row = apply(row, {
	sessionId: SESSION_A,
	event: "resume",
	activeSecondsHint: 0,
	now: 1_000,
});
assert.equal(row.transition.earnedSeconds, 0, "Opening a session does not invent playtime.");
assert.equal(row.session, SESSION_A, "The foreground tab acquires the playtime lease.");

for (let index = 1; index <= 18; index += 1) {
	row = apply(row, {
		sessionId: SESSION_A,
		event: "heartbeat",
		activeSecondsHint: 30,
		now: 1_000 + index * 30,
	});
	assert.equal(row.transition.earnedSeconds, 30, `Heartbeat ${index} credits foreground time.`);
}
assert.equal(row.playSeconds, 540, "Nine foreground minutes are recorded as 540 seconds.");

const duplicate = apply(row, {
	sessionId: SESSION_A,
	event: "heartbeat",
	activeSecondsHint: 30,
	now: row.heartbeat,
});
assert.equal(duplicate.transition.earnedSeconds, 0, "A duplicate heartbeat cannot double count.");
assert.equal(duplicate.playSeconds, 540);

const hidden = apply(row, {
	sessionId: SESSION_A,
	event: "heartbeat",
	activeSecondsHint: 0,
	now: row.heartbeat + 30,
});
assert.equal(hidden.transition.earnedSeconds, 0, "A hidden page with no active hint earns nothing.");

const competingTab = apply(row, {
	sessionId: SESSION_B,
	event: "heartbeat",
	activeSecondsHint: 30,
	now: row.heartbeat + 30,
});
assert.equal(competingTab.transition.leaseAccepted, false, "A second tab cannot double count the account.");
assert.equal(competingTab.transition.earnedSeconds, 0);

const staleTakeover = apply(row, {
	sessionId: SESSION_B,
	event: "resume",
	activeSecondsHint: 60,
	now: row.heartbeat + 76,
});
assert.equal(staleTakeover.transition.leaseAccepted, true, "A stale foreground lease can be recovered.");
assert.equal(staleTakeover.transition.earnedSeconds, 0, "Lease takeover does not claim another tab's time.");
assert.equal(staleTakeover.session, SESSION_B);

const shortLeave = apply(staleTakeover, {
	sessionId: SESSION_B,
	event: "leave",
	activeSecondsHint: 12,
	now: staleTakeover.heartbeat + 12,
});
assert.equal(shortLeave.transition.earnedSeconds, 12, "A sub-30-second session is settled on leave.");
assert.equal(shortLeave.session, "", "Leaving releases the lease.");

let retryRow = { playSeconds: 0, heartbeat: 2_000, session: SESSION_A };
retryRow = apply(retryRow, {
	sessionId: SESSION_A,
	event: "heartbeat",
	activeSecondsHint: 60,
	now: 2_060,
});
assert.equal(retryRow.transition.earnedSeconds, 60, "A bounded pending segment is recovered after a failed request.");

const bounded = apply(
	{ playSeconds: 0, heartbeat: 3_000, session: SESSION_A },
	{
		sessionId: SESSION_A,
		event: "heartbeat",
		activeSecondsHint: 500,
		now: 3_500,
	},
);
assert.equal(bounded.transition.earnedSeconds, 90, "The server caps a single report even if the client exaggerates.");

console.log("PASS playtime accounting: foreground, duplicate, hidden, retry, short leave, and lease cases");
