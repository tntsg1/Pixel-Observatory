import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const baseUrl = (process.env.RESEARCH_TEST_URL || "http://127.0.0.1:8791").replace(/\/$/, "");
const testNetwork = 20 + Math.floor(Math.random() * 200);
const workerSource = await readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8");
const researchBlock = workerSource.slice(
	workerSource.indexOf("const RESEARCH_PARTICIPANT_ID_PATTERN"),
	workerSource.indexOf("async function handleApi"),
);
assert.equal(
	workerSource.match(/sha256\(`\$\{participantId\}:\$\{token\}`\)/g)?.length,
	2,
	"Enrollment and authentication both salt study-token hashes with participantId.",
);
assert.doesNotMatch(researchBlock, /env\.DB\b/, "Research handlers do not access the account database binding.");

function testIp(index) {
	return `198.18.${testNetwork}.${20 + (index % 220)}`;
}

async function post(path, body, { expectedStatus = 200, ip = testIp(0) } = {}) {
	const response = await fetch(`${baseUrl}${path}`, {
		method: "POST",
		headers: {
			"content-type": "application/json",
			"X-Pixel-Observatory-Test-IP": ip,
		},
		body: JSON.stringify(body),
	});
	const data = await response.json().catch(() => ({}));
	assert.equal(
		response.status,
		expectedStatus,
		`POST ${path} returned ${response.status}: ${JSON.stringify(data)}`,
	);
	return data;
}

function answersFor(state) {
	assert.equal(state.questions.length, 3, "A research node presents three questions.");
	return Object.fromEntries(state.questions.map((question) => {
		assert.equal(question.options.length, 4, `${question.id} presents four options.`);
		return [question.id, question.options[0].id];
	}));
}

const enrolled = await Promise.all(Array.from({ length: 40 }, async (_, index) => {
	const ip = testIp(index + 1);
	const result = await post("/api/research/enroll", {
		consent: true,
		language: "en",
		routeArm: "field_gameplay",
	}, { expectedStatus: 201, ip });
	assert.equal(result.state.currentNode, "baseline");
	assert.equal(Object.hasOwn(result.state, "routeArm"), false, "Route assignment stays hidden before baseline.");
	assert.equal(result.state.questions.length, 3);
	assert.ok(result.state.questions.every(question => question.options.length === 4));
	return { ...result, ip, state: result.state, baselineAnswers: answersFor(result.state) };
}));

const sample = enrolled[0];
const beforeBaselineSession = await post("/api/research/session", {
	participantId: sample.participantId,
	token: sample.token,
}, { ip: sample.ip });
assert.equal(Object.hasOwn(beforeBaselineSession.state, "routeArm"), false, "Session cannot reveal an assignment before baseline.");

const assigned = await Promise.all(enrolled.map(async (participant, index) => {
	const result = await post("/api/research/submit", {
		participantId: participant.participantId,
		token: participant.token,
		nodeId: "baseline",
		answers: participant.baselineAnswers,
		durationSeconds: 45,
		lateResponse: index === 0,
	}, { ip: participant.ip });
	assert.equal(result.feedback.nodeId, "baseline");
	assert.equal(result.rewardOffer.candidates.length, 3, "Baseline completion yields exactly three candidates.");
	assert.equal(result.state.lateResponseCount, 0, "A timely baseline ignores a client-declared lateResponse hint.");
	participant.state = result.state;
	return participant;
}));

assert.ok(assigned.some(participant => participant.state.routeArm === "archive_text"), "Server assignment includes archive_text.");
assert.ok(assigned.some(participant => participant.state.routeArm === "field_gameplay"), "Forged routeArm cannot force every participant into field_gameplay.");

const duplicateBaseline = await post("/api/research/submit", {
	participantId: sample.participantId,
	token: sample.token,
	nodeId: "baseline",
	answers: sample.baselineAnswers,
	durationSeconds: 45,
	lateResponse: false,
}, { expectedStatus: 409, ip: sample.ip });
assert.equal(duplicateBaseline.error, "research_node_submitted");

const textParticipant = assigned.find(participant => participant.state.routeArm === "archive_text");
assert.ok(textParticipant, "A text-route participant is available for cross-exposure coverage.");
const completedTextParticipant = assigned.find(participant => (
	participant !== textParticipant && participant.state.routeArm === "archive_text"
));
assert.ok(completedTextParticipant, "A second text-route participant is available for completion coverage.");
const fieldParticipant = assigned.find(participant => participant.state.routeArm === "field_gameplay");
assert.ok(fieldParticipant, "A field-route participant is available for checkpoint coverage.");
assert.equal(fieldParticipant.state.currentNode, null, "Field questionnaires wait for their gameplay checkpoint.");

const invalidToken = `${fieldParticipant.token.slice(0, -1)}${fieldParticipant.token.endsWith("A") ? "B" : "A"}`;
const invalidSession = await post("/api/research/session", {
	participantId: fieldParticipant.participantId,
	token: invalidToken,
}, { expectedStatus: 401, ip: fieldParticipant.ip });
assert.equal(invalidSession.error, "invalid_research_session");

const prematureFieldA = await post("/api/research/submit", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	nodeId: "A",
	answers: {},
	durationSeconds: 30,
	lateResponse: false,
}, { expectedStatus: 409, ip: fieldParticipant.ip });
assert.equal(prematureFieldA.error, "research_checkpoint_required");

const invalidCheckpoint = await post("/api/research/checkpoint", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	level: 7,
}, { expectedStatus: 400, ip: fieldParticipant.ip });
assert.equal(invalidCheckpoint.error, "invalid_research_checkpoint");

const outOfOrderCheckpoint = await post("/api/research/checkpoint", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	level: 11,
}, { expectedStatus: 409, ip: fieldParticipant.ip });
assert.equal(outOfOrderCheckpoint.error, "research_checkpoint_unavailable");

const level6Checkpoint = await post("/api/research/checkpoint", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	level: 6,
	routeArm: "archive_text",
}, { ip: fieldParticipant.ip });
assert.equal(level6Checkpoint.state.routeArm, "field_gameplay", "Checkpoint requests cannot change the assigned route.");
assert.equal(level6Checkpoint.state.currentNode, "A");
fieldParticipant.state = level6Checkpoint.state;

const timelyFieldA = await post("/api/research/submit", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	nodeId: "A",
	answers: answersFor(fieldParticipant.state),
	durationSeconds: 50,
	lateResponse: true,
}, { ip: fieldParticipant.ip });
assert.equal(timelyFieldA.state.lateResponseCount, 0, "A timely field node ignores a client-declared lateResponse hint.");
assert.equal(timelyFieldA.state.currentNode, null, "Field state waits after A until the Level 11 checkpoint.");

const prematureFieldB = await post("/api/research/submit", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	nodeId: "B",
	answers: {},
	durationSeconds: 30,
	lateResponse: false,
}, { expectedStatus: 409, ip: fieldParticipant.ip });
assert.equal(prematureFieldB.error, "research_checkpoint_required");

const level11Checkpoint = await post("/api/research/checkpoint", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	level: 11,
}, { ip: fieldParticipant.ip });
assert.equal(level11Checkpoint.state.currentNode, "B");
fieldParticipant.state = level11Checkpoint.state;

const deferredFieldB = await post("/api/research/defer", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	nodeId: "B",
}, { ip: fieldParticipant.ip });
assert.equal(deferredFieldB.deferCount, 1);
fieldParticipant.state = deferredFieldB.state;

const level16Checkpoint = await post("/api/research/checkpoint", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	level: 16,
}, { ip: fieldParticipant.ip });
assert.equal(level16Checkpoint.state.currentNode, "B", "A later checkpoint keeps the deferred questionnaire available.");
fieldParticipant.state = level16Checkpoint.state;

const serverLateFieldB = await post("/api/research/submit", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	nodeId: "B",
	answers: answersFor(fieldParticipant.state),
	durationSeconds: 55,
	lateResponse: false,
}, { ip: fieldParticipant.ip });
assert.equal(serverLateFieldB.state.lateResponseCount, 1, "A later checkpoint overrides a false lateness hint.");
assert.equal(serverLateFieldB.state.currentNode, "C", "The already-recorded Level 16 checkpoint unlocks C.");
fieldParticipant.state = serverLateFieldB.state;

const timelyFieldC = await post("/api/research/submit", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	nodeId: "C",
	answers: answersFor(fieldParticipant.state),
	durationSeconds: 50,
	lateResponse: false,
}, { ip: fieldParticipant.ip });
assert.equal(timelyFieldC.state.currentNode, null, "Field state waits after C until the Level 21 checkpoint.");

const level21Checkpoint = await post("/api/research/checkpoint", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	level: 21,
}, { ip: fieldParticipant.ip });
assert.equal(level21Checkpoint.state.currentNode, "D");
fieldParticipant.state = level21Checkpoint.state;

const timelyFieldD = await post("/api/research/submit", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	nodeId: "D",
	answers: answersFor(fieldParticipant.state),
	durationSeconds: 50,
	lateResponse: false,
}, { ip: fieldParticipant.ip });
assert.equal(timelyFieldD.state.currentNode, null, "Field state waits after D until the Level 24 checkpoint.");

const level24Checkpoint = await post("/api/research/checkpoint", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	level: 24,
}, { ip: fieldParticipant.ip });
assert.equal(level24Checkpoint.state.currentNode, "E");

const repeatedLevel24Checkpoint = await post("/api/research/checkpoint", {
	participantId: fieldParticipant.participantId,
	token: fieldParticipant.token,
	level: 24,
}, { ip: fieldParticipant.ip });
assert.deepEqual(repeatedLevel24Checkpoint, level24Checkpoint, "Checkpoint retries reuse one event and state.");

for (const nodeId of ["A", "B", "C", "D", "E"]) {
	assert.equal(completedTextParticipant.state.currentNode, nodeId);
	const result = await post("/api/research/submit", {
		participantId: completedTextParticipant.participantId,
		token: completedTextParticipant.token,
		nodeId,
		answers: answersFor(completedTextParticipant.state),
		durationSeconds: 45,
		lateResponse: false,
	}, { ip: completedTextParticipant.ip });
	completedTextParticipant.state = result.state;
}
assert.equal(completedTextParticipant.state.currentNode, null);
assert.equal(completedTextParticipant.state.crossExposed, false);

const completedExposure = await post("/api/research/exposure", {
	participantId: completedTextParticipant.participantId,
	token: completedTextParticipant.token,
	kind: "ordinary_game",
}, { ip: completedTextParticipant.ip });
assert.equal(completedExposure.state.crossExposed, false, "Completed archive participants are not cross-exposed.");

const repeatedCompletedExposure = await post("/api/research/exposure", {
	participantId: completedTextParticipant.participantId,
	token: completedTextParticipant.token,
	kind: "ordinary_game",
}, { ip: completedTextParticipant.ip });
assert.deepEqual(repeatedCompletedExposure, completedExposure, "Completed exposure retries are idempotent.");

const firstDeferral = await post("/api/research/defer", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	nodeId: "A",
}, { ip: textParticipant.ip });
assert.equal(firstDeferral.deferCount, 1);
assert.equal(firstDeferral.state.deferCounts.A, 1);
textParticipant.state = firstDeferral.state;

const secondDeferral = await post("/api/research/defer", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	nodeId: "A",
}, { ip: textParticipant.ip });
assert.equal(secondDeferral.deferCount, 2);
assert.equal(secondDeferral.state.deferCounts.A, 2);
textParticipant.state = secondDeferral.state;

const [exposure, repeatedExposure] = await Promise.all([1, 2].map(() => post("/api/research/exposure", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	kind: "ordinary_game",
}, { ip: textParticipant.ip })));
assert.equal(exposure.state.crossExposed, true, "Ordinary-game navigation flags the unfinished text route.");
assert.deepEqual(repeatedExposure, exposure, "Concurrent exposure retries are idempotent.");
textParticipant.state = exposure.state;

const lateA = await post("/api/research/submit", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	nodeId: "A",
	answers: answersFor(textParticipant.state),
	durationSeconds: 60,
	lateResponse: false,
}, { ip: textParticipant.ip });
assert.equal(lateA.state.lateResponseCount, 1, "Ordinary-game exposure derives late status server-side.");
assert.ok(lateA.state.completedNodes.includes("A"));
assert.equal(lateA.rewardOffer.candidates.length, 3, "Each submitted node has exactly three offered candidates.");

const offeredBundle = lateA.rewardOffer.candidates[0];
const differentOfferedBundle = lateA.rewardOffer.candidates[1];
const unofferedBundle = Array.from({ length: 12 }, (_, index) => `R${String(index + 1).padStart(2, "0")}`)
	.find(bundleId => !lateA.rewardOffer.candidates.includes(bundleId));
assert.ok(unofferedBundle, "A three-choice offer leaves a valid unoffered bundle for rejection coverage.");

const unofferedChoice = await post("/api/research/reward/choose", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	offerId: lateA.rewardOffer.offerId,
	bundleId: unofferedBundle,
}, { expectedStatus: 409, ip: textParticipant.ip });
assert.equal(unofferedChoice.error, "bundle_not_offered");

const firstChoice = await post("/api/research/reward/choose", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	offerId: lateA.rewardOffer.offerId,
	bundleId: offeredBundle,
}, { ip: textParticipant.ip });
assert.equal(firstChoice.bundleId, offeredBundle);
assert.equal(firstChoice.prestigeLevel, 1);
assert.match(firstChoice.receiptToken, /^[A-Za-z0-9_-]{20,}$/i, "Reward receipts are opaque tokens.");

const repeatedChoice = await post("/api/research/reward/choose", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	offerId: lateA.rewardOffer.offerId,
	bundleId: offeredBundle,
}, { ip: textParticipant.ip });
assert.deepEqual(repeatedChoice, firstChoice, "Retrying a valid choice returns its original receipt without a second issuance.");

const consumedChoice = await post("/api/research/reward/choose", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	offerId: lateA.rewardOffer.offerId,
	bundleId: differentOfferedBundle,
}, { expectedStatus: 409, ip: textParticipant.ip });
assert.equal(consumedChoice.error, "reward_offer_consumed");

const [withdrawal, repeatedWithdrawal] = await Promise.all([1, 2].map(() => post("/api/research/withdraw", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
}, { ip: textParticipant.ip })));
assert.equal(withdrawal.state.withdrawn, true);
assert.equal(withdrawal.state.currentNode, null);
assert.match(withdrawal.eventId, /^RE-[A-Z0-9_-]+$/, "Withdrawal returns its persisted event ID.");
assert.equal(repeatedWithdrawal.eventId, withdrawal.eventId, "Concurrent withdrawal retry reuses one event.");
assert.deepEqual(repeatedWithdrawal.state, withdrawal.state);

const withdrawnSession = await post("/api/research/session", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
}, { ip: textParticipant.ip });
assert.equal(withdrawnSession.state.withdrawn, true, "Withdrawal persists across anonymous session refreshes.");

const withdrawnSubmit = await post("/api/research/submit", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	nodeId: "B",
	answers: {},
	durationSeconds: 30,
	lateResponse: false,
}, { expectedStatus: 409, ip: textParticipant.ip });
assert.equal(withdrawnSubmit.error, "research_withdrawn");

const withdrawnDefer = await post("/api/research/defer", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	nodeId: "B",
}, { expectedStatus: 409, ip: textParticipant.ip });
assert.equal(withdrawnDefer.error, "research_withdrawn");

const withdrawnCheckpoint = await post("/api/research/checkpoint", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	level: 6,
}, { expectedStatus: 409, ip: textParticipant.ip });
assert.equal(withdrawnCheckpoint.error, "research_withdrawn");

const withdrawnRewardChoice = await post("/api/research/reward/choose", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	offerId: lateA.rewardOffer.offerId,
	bundleId: offeredBundle,
}, { expectedStatus: 409, ip: textParticipant.ip });
assert.equal(withdrawnRewardChoice.error, "research_withdrawn");

const withdrawnExposure = await post("/api/research/exposure", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	kind: "ordinary_game",
}, { expectedStatus: 409, ip: textParticipant.ip });
assert.equal(withdrawnExposure.error, "research_withdrawn");

const sessionAfterRejectedExposure = await post("/api/research/session", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
}, { ip: textParticipant.ip });
assert.deepEqual(
	sessionAfterRejectedExposure,
	withdrawnSession,
	"Rejected post-withdraw exposure leaves the participant state unchanged.",
);

await post("/api/study/enroll", {
	consent: true,
	language: "en",
}, { expectedStatus: 404, ip: testIp(250) });

console.log("research worker integration: ok");
