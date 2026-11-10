import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const worker = await readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8");
const adminHtml = await readFile(new URL("../web/landing/admin/index.html", import.meta.url), "utf8");
const adminJs = await readFile(new URL("../web/landing/admin/admin.js", import.meta.url), "utf8");

const handlers = [
	"handleAdminResearchSummary",
	"handleAdminResearchParticipants",
	"handleAdminResearchParticipant",
	"handleAdminResearchExport",
];

for (const handler of handlers) {
	const start = worker.indexOf(`async function ${handler}`);
	assert.ok(start >= 0, `${handler} exists.`);
	const next = worker.indexOf("\nasync function ", start + 1);
	const body = worker.slice(start, next < 0 ? worker.length : next);
	assert.match(body, /requireAdmin\(env, request\)/, `${handler} reuses administrator authentication.`);
}

for (const endpoint of [
	"/api/admin/research/summary",
	"/api/admin/research/participants",
	"/api/admin/research/export.csv",
]) {
	assert.ok(worker.includes(endpoint), `${endpoint} is routed by the worker.`);
	assert.ok(adminJs.includes(endpoint), `${endpoint} is consumed by the administrator UI.`);
}
assert.ok(worker.includes("adminResearchParticipantMatch"), "Participant detail route is present.");

for (const tab of ["Feedback", "Research Overview", "Participants", "Export"]) {
	assert.ok(adminHtml.includes(tab), `${tab} tab is present.`);
}

assert.ok(adminJs.includes("Research database is temporarily unavailable"), "The administrator UI explains database outages.");
assert.ok(worker.includes('"is_skipped"'), "Research CSV exposes skipped events explicitly.");
assert.ok(worker.includes('"question"'), "Research CSV includes the original question text.");

console.log("research admin contract: ok");
