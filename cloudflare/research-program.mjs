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
const SHA256_INITIAL_HASH = [
	0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
	0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];
const SHA256_ROUND_CONSTANTS = [
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

function rotateRight(value, amount) {
	return (value >>> amount) | (value << (32 - amount));
}

// This produces the same SHA-256 digest bytes as Web Crypto while keeping the
// exported state helpers synchronous and deterministic in Workers and Node.
function sha256Bytes(value) {
	const source = new TextEncoder().encode(String(value));
	const messageLength = Math.ceil((source.length + 9) / 64) * 64;
	const message = new Uint8Array(messageLength);
	message.set(source);
	message[source.length] = 0x80;

	const bitLength = source.length * 8;
	const highBits = Math.floor(bitLength / 0x1_0000_0000);
	message[messageLength - 8] = (highBits >>> 24) & 0xff;
	message[messageLength - 7] = (highBits >>> 16) & 0xff;
	message[messageLength - 6] = (highBits >>> 8) & 0xff;
	message[messageLength - 5] = highBits & 0xff;
	message[messageLength - 4] = (bitLength >>> 24) & 0xff;
	message[messageLength - 3] = (bitLength >>> 16) & 0xff;
	message[messageLength - 2] = (bitLength >>> 8) & 0xff;
	message[messageLength - 1] = bitLength & 0xff;

	const hash = SHA256_INITIAL_HASH.slice();
	const words = new Uint32Array(64);
	for (let blockOffset = 0; blockOffset < message.length; blockOffset += 64) {
		for (let index = 0; index < 16; index += 1) {
			const offset = blockOffset + index * 4;
			words[index] = ((message[offset] << 24)
				| (message[offset + 1] << 16)
				| (message[offset + 2] << 8)
				| message[offset + 3]) >>> 0;
		}
		for (let index = 16; index < 64; index += 1) {
			const low = rotateRight(words[index - 15], 7) ^ rotateRight(words[index - 15], 18) ^ (words[index - 15] >>> 3);
			const high = rotateRight(words[index - 2], 17) ^ rotateRight(words[index - 2], 19) ^ (words[index - 2] >>> 10);
			words[index] = (words[index - 16] + low + words[index - 7] + high) >>> 0;
		}

		let [a, b, c, d, e, f, g, h] = hash;
		for (let index = 0; index < 64; index += 1) {
			const sigma1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25);
			const choose = (e & f) ^ (~e & g);
			const temp1 = (h + sigma1 + choose + SHA256_ROUND_CONSTANTS[index] + words[index]) >>> 0;
			const sigma0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22);
			const majority = (a & b) ^ (a & c) ^ (b & c);
			const temp2 = (sigma0 + majority) >>> 0;
			h = g;
			g = f;
			f = e;
			e = (d + temp1) >>> 0;
			d = c;
			c = b;
			b = a;
			a = (temp1 + temp2) >>> 0;
		}
		hash[0] = (hash[0] + a) >>> 0;
		hash[1] = (hash[1] + b) >>> 0;
		hash[2] = (hash[2] + c) >>> 0;
		hash[3] = (hash[3] + d) >>> 0;
		hash[4] = (hash[4] + e) >>> 0;
		hash[5] = (hash[5] + f) >>> 0;
		hash[6] = (hash[6] + g) >>> 0;
		hash[7] = (hash[7] + h) >>> 0;
	}

	return Uint8Array.from(hash.flatMap(word => [
		(word >>> 24) & 0xff,
		(word >>> 16) & 0xff,
		(word >>> 8) & 0xff,
		word & 0xff,
	]));
}

function seededUint32(seed) {
	const digest = sha256Bytes(seed);
	return digest[0] * 0x1_000000 + digest[1] * 0x1_0000 + digest[2] * 0x100 + digest[3];
}

function seededShuffle(values, seed) {
	const shuffled = values.slice();
	for (let index = shuffled.length - 1; index > 0; index -= 1) {
		const swapIndex = seededUint32(`${seed}:${index}`) % (index + 1);
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
		const count = Math.max(0, Math.floor(Number(storedCounts[nodeId]) || 0));
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

export function selectQuestionForm(participantId, nodeId) {
	const forms = QUESTION_FORMS[nodeIdFrom(nodeId)];
	if (!forms) throw new RangeError("Unknown research node.");
	const index = seededUint32(`${RESEARCH_VERSION}:form:${participantId}:${nodeId}`) % forms.length;
	return forms[index];
}

export function orderedQuestions(participantId, form) {
	if (!form || !Array.isArray(form.questions)) throw new TypeError("A research question form is required.");
	return seededShuffle(form.questions, `${RESEARCH_VERSION}:question-order:${participantId}:${form.id}`).map(question => ({
		id: question.id,
		prompt: { en: question.prompt.en, zh: question.prompt.zh },
		options: seededShuffle(question.options, `${RESEARCH_VERSION}:option-order:${participantId}:${form.id}:${question.id}`)
			.map(option => ({ id: option.id, en: option.en, zh: option.zh })),
	}));
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

export function buildRewardCandidates(ownedBundleIds, seed) {
	const owned = new Set(Array.isArray(ownedBundleIds) ? ownedBundleIds.map(String) : []);
	const available = COSMETIC_BUNDLES.map(bundle => bundle.id).filter(bundleId => !owned.has(bundleId));
	if (available.length < 3) throw new RangeError("At least three unowned research bundles are required.");
	return seededShuffle(available, `${RESEARCH_VERSION}:reward:${seed}`).slice(0, 3);
}

export function publicResearchState(row, responseRows, offerRow) {
	const participantId = String(row?.participant_id ?? row?.participantId ?? row?.id ?? "");
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
		lateResponseCount: Math.max(0, Math.floor(Number(row?.late_response_count ?? row?.lateResponseCount) || 0)),
		crossExposed: Number(row?.cross_exposed ?? row?.crossExposed ?? 0) > 0,
		withdrawn,
		questions: currentNode ? orderedQuestions(participantId, selectQuestionForm(participantId, currentNode)) : [],
		rewardOffer: publicRewardOffer(offerRow),
	};
	if (completedNodes.includes("baseline") && routeArm) state.routeArm = routeArm;
	return state;
}
