import {
	COSMETIC_BUNDLES,
	QUESTION_FORMS,
	RESEARCH_NODES,
	RESEARCH_VERSION,
} from "../web/landing/study/research-content.mjs";

const ROUTE_ARMS = new Set(["archive_text", "field_gameplay"]);
const NODE_IDS = RESEARCH_NODES.map(node => node.id);
const NODE_ID_SET = new Set(NODE_IDS);
const BUNDLE_ID_SET = new Set(COSMETIC_BUNDLES.map(bundle => bundle.id));
async function seededUint32(seed) {
	const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(String(seed))));
	return digest[0] * 0x1_000000 + digest[1] * 0x1_0000 + digest[2] * 0x100 + digest[3];
}

async function seededShuffle(values, seed) {
	const shuffled = values.slice();
	for (let index = shuffled.length - 1; index > 0; index -= 1) {
		const swapIndex = (await seededUint32(`${seed}:${index}`)) % (index + 1);
		[shuffled[index], shuffled[swapIndex]] = [shuffled[swapIndex], shuffled[index]];
	}
	return shuffled;
}

function isRouteArm(value) {
	return ROUTE_ARMS.has(value);
}

function nodeIdFrom(value) {
	const nodeId = String(value || "");
	return NODE_ID_SET.has(nodeId) ? nodeId : "";
}

function parseJson(value, fallback) {
	if (typeof value !== "string") return value ?? fallback;
	try {
		return JSON.parse(value);
	} catch {
		return fallback;
	}
}

function finiteNumber(value) {
	const number = Number(value);
	return Number.isFinite(number) ? number : 0;
}

function publicNonNegativeInteger(value) {
	return Math.max(0, Math.floor(finiteNumber(value)));
}

function completedNodeIds(row, responseRows) {
	const completed = new Set();
	const storedNodes = parseJson(row?.completed_nodes_json ?? row?.completedNodes, []);
	if (Array.isArray(storedNodes)) {
		for (const nodeId of storedNodes) {
			const validNodeId = nodeIdFrom(nodeId);
			if (validNodeId) completed.add(validNodeId);
		}
	}
	for (const responseRow of Array.isArray(responseRows) ? responseRows : []) {
		const validNodeId = nodeIdFrom(responseRow?.node_id ?? responseRow?.nodeId);
		if (validNodeId) completed.add(validNodeId);
	}
	return NODE_IDS.filter(nodeId => completed.has(nodeId));
}

function publicDeferCounts(value) {
	const storedCounts = parseJson(value, {});
	if (!storedCounts || typeof storedCounts !== "object" || Array.isArray(storedCounts)) return {};
	const counts = {};
	for (const nodeId of NODE_IDS) {
		const count = publicNonNegativeInteger(storedCounts[nodeId]);
		if (count > 0) counts[nodeId] = count;
	}
	return counts;
}

function publicRewardOffer(offerRow) {
	if (!offerRow) return null;
	const candidates = [
		offerRow.candidate_bundle_1 ?? offerRow.candidateBundle1,
		offerRow.candidate_bundle_2 ?? offerRow.candidateBundle2,
		offerRow.candidate_bundle_3 ?? offerRow.candidateBundle3,
	].map(value => String(value || ""));
	if (new Set(candidates).size !== 3 || !candidates.every(bundleId => BUNDLE_ID_SET.has(bundleId))) return null;
	return {
		offerId: String(offerRow.offer_id ?? offerRow.offerId ?? ""),
		nodeId: nodeIdFrom(offerRow.node_id ?? offerRow.nodeId),
		candidates,
	};
}

export function assignRoute(randomUint32) {
	return (Number(randomUint32) >>> 0) < 0x8000_0000 ? "archive_text" : "field_gameplay";
}

export async function selectQuestionForm(participantId, nodeId) {
	const forms = QUESTION_FORMS[nodeIdFrom(nodeId)];
	if (!forms) throw new RangeError("Unknown research node.");
	const index = (await seededUint32(`${RESEARCH_VERSION}:form:${participantId}:${nodeId}`)) % forms.length;
	return forms[index];
}

export async function orderedQuestions(participantId, form) {
	if (!form || !Array.isArray(form.questions)) throw new TypeError("A research question form is required.");
	const publicQuestions = [];
	for (const question of await seededShuffle(form.questions, `${RESEARCH_VERSION}:question-order:${participantId}:${form.id}`)) {
		publicQuestions.push({
			id: question.id,
			prompt: { en: question.prompt.en, zh: question.prompt.zh },
			options: (await seededShuffle(question.options, `${RESEARCH_VERSION}:option-order:${participantId}:${form.id}:${question.id}`))
				.map(option => ({ id: option.id, en: option.en, zh: option.zh })),
		});
	}
	return publicQuestions;
}

export function scoreAnswers(form, answers) {
	const responses = answers && typeof answers === "object" && !Array.isArray(answers) ? answers : {};
	const questions = Array.isArray(form?.questions) ? form.questions : [];
	const score = questions.reduce(
		(total, question) => total + Number(responses[question.id] === question.correctOptionId),
		0,
	);
	return { score, maxScore: questions.length };
}

export function nextResearchNode(routeArm, completedNodes) {
	if (!isRouteArm(routeArm)) throw new RangeError("Unknown research route arm.");
	const completed = new Set(
		(Array.isArray(completedNodes) ? completedNodes : [])
			.map(nodeIdFrom)
			.filter(Boolean),
	);
	return NODE_IDS.find(nodeId => !completed.has(nodeId)) || null;
}

function currentResearchNode(row, routeArm, completedNodes) {
	const nextNode = nextResearchNode(routeArm, completedNodes);
	if (routeArm !== "field_gameplay" || !completedNodes.includes("baseline")) return nextNode;
	const checkpointNode = nodeIdFrom(row?.current_node ?? row?.currentNode);
	return checkpointNode && !completedNodes.includes(checkpointNode) ? checkpointNode : nextNode;
}

export async function buildRewardCandidates(ownedBundleIds, seed) {
	const owned = new Set(Array.isArray(ownedBundleIds) ? ownedBundleIds.map(String) : []);
	const available = COSMETIC_BUNDLES.map(bundle => bundle.id).filter(bundleId => !owned.has(bundleId));
	if (available.length < 3) throw new RangeError("At least three unowned research bundles are required.");
	return (await seededShuffle(available, `${RESEARCH_VERSION}:reward:${seed}`)).slice(0, 3);
}

export async function publicResearchState(row, responseRows, offerRow) {
	const participantId = typeof row?.participant_id === "string" ? row.participant_id : "";
	if (!participantId) return null;
	const routeArm = isRouteArm(row?.route_arm ?? row?.routeArm) ? (row.route_arm ?? row.routeArm) : "";
	const completedNodes = completedNodeIds(row, responseRows);
	const withdrawn = Number(row?.withdrawn_at ?? row?.withdrawnAt ?? 0) > 0;
	const currentNode = withdrawn || !routeArm ? null : currentResearchNode(row, routeArm, completedNodes);
	const state = {
		participantId,
		language: row?.language === "zh" ? "zh" : "en",
		currentNode,
		completedNodes,
		deferCounts: publicDeferCounts(row?.defer_counts_json ?? row?.deferCounts),
		lateResponseCount: publicNonNegativeInteger(row?.late_response_count ?? row?.lateResponseCount),
		crossExposed: Number(row?.cross_exposed ?? row?.crossExposed ?? 0) > 0,
		withdrawn,
		questions: currentNode ? await orderedQuestions(participantId, await selectQuestionForm(participantId, currentNode)) : [],
		rewardOffer: publicRewardOffer(offerRow),
	};
	if (completedNodes.includes("baseline") && routeArm) state.routeArm = routeArm;
	return state;
}
