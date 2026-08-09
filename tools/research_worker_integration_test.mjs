import assert from "node:assert/strict";

const baseUrl = (process.env.RESEARCH_TEST_URL || "http://127.0.0.1:8791").replace(/\/$/, "");
const testNetwork = 20 + Math.floor(Math.random() * 200);

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

const assigned = await Promise.all(enrolled.map(async (participant) => {
	const result = await post("/api/research/submit", {
		participantId: participant.participantId,
		token: participant.token,
		nodeId: "baseline",
		answers: participant.baselineAnswers,
		durationSeconds: 45,
		lateResponse: false,
	}, { ip: participant.ip });
	assert.equal(result.feedback.nodeId, "baseline");
	assert.equal(result.rewardOffer.candidates.length, 3, "Baseline completion yields exactly three candidates.");
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

const exposure = await post("/api/research/exposure", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	kind: "ordinary_game",
}, { ip: textParticipant.ip });
assert.equal(exposure.state.crossExposed, true, "Ordinary-game navigation flags the unfinished text route.");
textParticipant.state = exposure.state;

const lateA = await post("/api/research/submit", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
	nodeId: "A",
	answers: answersFor(textParticipant.state),
	durationSeconds: 60,
	lateResponse: true,
}, { ip: textParticipant.ip });
assert.equal(lateA.state.lateResponseCount, 1, "Late questionnaire completion is retained as analysis metadata.");
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

const withdrawal = await post("/api/research/withdraw", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
}, { ip: textParticipant.ip });
assert.equal(withdrawal.state.withdrawn, true);
assert.equal(withdrawal.state.currentNode, null);

const withdrawnSession = await post("/api/research/session", {
	participantId: textParticipant.participantId,
	token: textParticipant.token,
}, { ip: textParticipant.ip });
assert.equal(withdrawnSession.state.withdrawn, true, "Withdrawal persists across anonymous session refreshes.");

await post("/api/study/enroll", {
	consent: true,
	language: "en",
}, { expectedStatus: 404, ip: testIp(250) });

console.log("research worker integration: ok");
