import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { COSMETIC_BUNDLES } from "../web/landing/study/research-content.mjs";
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
const canonicalRewardIds = [
	"R01", "R02", "R03", "R04", "R05", "R06",
	"R07", "R08", "R09", "R10", "R11", "R12",
];
const programSource = await readFile(new URL("../cloudflare/research-program.mjs", import.meta.url), "utf8");

assert.equal(assignRoute(0), "archive_text");
assert.equal(assignRoute(0x7fffffff), "archive_text");
assert.equal(assignRoute(0x80000000), "field_gameplay");
assert.equal(assignRoute(0xffffffff), "field_gameplay");
assert.match(programSource, /crypto\.subtle\.digest\(\s*["']SHA-256["']/);
assert.doesNotMatch(programSource, /SHA256_(?:INITIAL_HASH|ROUND_CONSTANTS)|function sha256Bytes|function rotateRight/);

const formPromise = selectQuestionForm(participantId, "A");
assert.ok(formPromise instanceof Promise);
const form = await formPromise;
assert.equal(form.questions.length, 3);
assert.deepEqual(await selectQuestionForm(participantId, "A"), form);

const publicQuestionsPromise = orderedQuestions(participantId, form);
assert.ok(publicQuestionsPromise instanceof Promise);
const publicQuestions = await publicQuestionsPromise;
assert.ok(publicQuestions.every(question => !("correctOptionId" in question)));
assert.ok(publicQuestions.every(question => question.options.every(option => !("correctOptionId" in option))));
assert.deepEqual(await orderedQuestions(participantId, form), publicQuestions);
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

assert.deepEqual(COSMETIC_BUNDLES.map(bundle => bundle.id), canonicalRewardIds);
const candidatesPromise = buildRewardCandidates(["R01", "R02"], "STUDY-UNITTEST01:A");
assert.ok(candidatesPromise instanceof Promise);
const candidates = await candidatesPromise;
assert.equal(candidates.length, 3);
assert.ok(candidates.every(id => canonicalRewardIds.includes(id) && !["R01", "R02"].includes(id)));
assert.equal(new Set(candidates).size, 3);
assert.deepEqual(await buildRewardCandidates(["R01", "R02"], "STUDY-UNITTEST01:A"), candidates);
await assert.rejects(
	Promise.resolve().then(() => buildRewardCandidates(canonicalRewardIds.slice(0, 10), "STUDY-UNITTEST01:too-few")),
	RangeError,
);

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
for (const routeArm of ["archive_text", "field_gameplay"]) {
	const baselineStatePromise = publicResearchState({ ...baselineRow, route_arm: routeArm }, [], null);
	assert.ok(baselineStatePromise instanceof Promise);
	const baselineState = await baselineStatePromise;
	assert.equal(Object.hasOwn(baselineState, "routeArm"), false);
	assert.equal(baselineState.currentNode, "baseline");
	assert.equal(baselineState.questions.length, 3);
	assert.ok(!JSON.stringify(baselineState).includes("correctOptionId"));
}

const persistedCompletionState = await publicResearchState(
	{ ...baselineRow, current_node: "A", completed_nodes_json: '["baseline"]' },
	[],
	{
		offer_id: "RO-UNITTEST",
		node_id: "baseline",
		candidate_bundle_1: "R03",
		candidate_bundle_2: "R04",
		candidate_bundle_3: "R05",
	},
);
assert.equal(persistedCompletionState.routeArm, "archive_text");
assert.equal(persistedCompletionState.currentNode, "A");
assert.deepEqual(persistedCompletionState.completedNodes, ["baseline"]);
assert.deepEqual(persistedCompletionState.rewardOffer, {
	offerId: "RO-UNITTEST",
	nodeId: "baseline",
	candidates: ["R03", "R04", "R05"],
});
assert.ok(!JSON.stringify(persistedCompletionState).includes("correctOptionId"));

const responseCompletionState = await publicResearchState(
	{ ...baselineRow, current_node: "A", completed_nodes_json: "[]" },
	[{ node_id: "baseline" }],
	null,
);
assert.equal(responseCompletionState.routeArm, "archive_text");
assert.equal(responseCompletionState.currentNode, "A");
assert.deepEqual(responseCompletionState.completedNodes, ["baseline"]);

const gameplayState = await publicResearchState(
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

const archiveState = await publicResearchState(
	{
		...baselineRow,
		current_node: "C",
		completed_nodes_json: '["baseline", "A"]',
	},
	[{ node_id: "baseline" }, { node_id: "A" }],
	null,
);
assert.equal(archiveState.currentNode, "B");

assert.equal(
	await publicResearchState({ ...baselineRow, participant_id: undefined, participantId: "legacy-id", id: "account-id" }, [], null),
	null,
);

for (const nonFiniteValue of [Infinity, -Infinity, Number.NaN]) {
	const nonFiniteState = await publicResearchState(
		{
			...baselineRow,
			defer_counts_json: { A: Infinity, B: -Infinity, C: Number.NaN, D: 2.9 },
			late_response_count: nonFiniteValue,
		},
		[],
		null,
	);
	assert.deepEqual(nonFiniteState.deferCounts, { D: 2 });
	assert.equal(nonFiniteState.lateResponseCount, 0);
	assert.deepEqual(
		JSON.parse(JSON.stringify({ deferCounts: nonFiniteState.deferCounts, lateResponseCount: nonFiniteState.lateResponseCount })),
		{ deferCounts: { D: 2 }, lateResponseCount: 0 },
	);
}

console.log("research program unit: ok");
