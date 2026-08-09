import assert from "node:assert/strict";
import {
	assignRoute,
	buildRewardCandidates,
	nextResearchNode,
	orderedQuestions,
	publicResearchState,
	scoreAnswers,
	selectQuestionForm,
} from "../cloudflare/research-program.mjs";

const participantId = "STUDY-UNITTEST01";

assert.equal(assignRoute(0), "archive_text");
assert.equal(assignRoute(0xffffffff), "field_gameplay");

const form = selectQuestionForm(participantId, "A");
assert.equal(form.questions.length, 3);
assert.deepEqual(selectQuestionForm(participantId, "A"), form);

const publicQuestions = orderedQuestions(participantId, form);
assert.ok(publicQuestions.every(question => !("correctOptionId" in question)));
assert.ok(publicQuestions.every(question => question.options.every(option => !("correctOptionId" in option))));
assert.deepEqual(orderedQuestions(participantId, form), publicQuestions);
assert.deepEqual(
	scoreAnswers(form, Object.fromEntries(form.questions.map(question => [question.id, question.correctOptionId]))),
	{ score: 3, maxScore: 3 },
);
assert.deepEqual(scoreAnswers(form, {}), { score: 0, maxScore: 3 });

assert.equal(nextResearchNode("archive_text", []), "baseline");
assert.equal(nextResearchNode("archive_text", ["baseline"]), "A");
assert.equal(nextResearchNode("archive_text", ["baseline", "A", "B", "C", "D", "E"]), null);
assert.equal(nextResearchNode("field_gameplay", []), "baseline");
assert.equal(nextResearchNode("field_gameplay", ["baseline", "A", "B"]), "C");

const candidates = buildRewardCandidates(["R01", "R02"], "STUDY-UNITTEST01:A");
assert.equal(candidates.length, 3);
assert.ok(candidates.every(id => !["R01", "R02"].includes(id)));
assert.equal(new Set(candidates).size, 3);
assert.deepEqual(buildRewardCandidates(["R01", "R02"], "STUDY-UNITTEST01:A"), candidates);

const baselineRow = {
	participant_id: participantId,
	language: "en",
	route_arm: "archive_text",
	current_node: "baseline",
	completed_nodes_json: "[]",
	defer_counts_json: "{}",
	late_response_count: 0,
	cross_exposed: 0,
	withdrawn_at: null,
};
const baselineState = publicResearchState(baselineRow, [], null);
assert.equal(baselineState.routeArm, undefined);
assert.equal(baselineState.currentNode, "baseline");
assert.equal(baselineState.questions.length, 3);
assert.ok(!JSON.stringify(baselineState).includes("correctOptionId"));

const assignedState = publicResearchState(
	{ ...baselineRow, current_node: "A", completed_nodes_json: '["baseline"]' },
	[{ node_id: "baseline" }],
	{
		offer_id: "RO-UNITTEST",
		node_id: "baseline",
		candidate_bundle_1: "R03",
		candidate_bundle_2: "R04",
		candidate_bundle_3: "R05",
	},
);
assert.equal(assignedState.routeArm, "archive_text");
assert.equal(assignedState.currentNode, "A");
assert.deepEqual(assignedState.completedNodes, ["baseline"]);
assert.deepEqual(assignedState.rewardOffer, {
	offerId: "RO-UNITTEST",
	nodeId: "baseline",
	candidates: ["R03", "R04", "R05"],
});
assert.ok(!JSON.stringify(assignedState).includes("correctOptionId"));

const gameplayState = publicResearchState(
	{
		...baselineRow,
		route_arm: "field_gameplay",
		current_node: "C",
		completed_nodes_json: '["baseline", "A"]',
	},
	[{ node_id: "baseline" }, { node_id: "A" }],
	null,
);
assert.equal(gameplayState.currentNode, "C");

const archiveState = publicResearchState(
	{
		...baselineRow,
		current_node: "C",
		completed_nodes_json: '["baseline", "A"]',
	},
	[{ node_id: "baseline" }, { node_id: "A" }],
	null,
);
assert.equal(archiveState.currentNode, "B");

console.log("research program unit: ok");
