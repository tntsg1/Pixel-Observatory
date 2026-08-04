import assert from "node:assert/strict";

const baseUrl = process.env.CLOUD_SAVE_TEST_URL || "http://127.0.0.1:8791";
const suffix = `${Date.now().toString(36)}${Math.floor(Math.random() * 10_000)}`;

function sessionCookie(response) {
	const raw = response.headers.get("set-cookie") || "";
	const match = raw.match(/(?:^|,\s*)(po_session=[^;]+)/);
	assert.ok(match, "Registration must return a session cookie.");
	return match[1];
}

async function request(path, options = {}, cookie = "", expectedStatus = 200) {
	const response = await fetch(`${baseUrl}${path}`, {
		...options,
		headers: {
			"content-type": "application/json",
			"X-Pixel-Observatory-Test-IP": `198.18.77.${Math.floor(Math.random() * 120) + 20}`,
			...(cookie ? { cookie } : {}),
			...(options.headers || {}),
		},
	});
	const data = await response.json().catch(() => ({}));
	assert.equal(response.status, expectedStatus, `${path}: ${response.status} ${JSON.stringify(data)}`);
	return { response, data };
}

const registration = await request("/api/auth/register", {
	method: "POST",
	body: JSON.stringify({
		username: `save${suffix}`,
		password: "CloudMerge!2026",
		website: "",
		turnstileToken: "local-test",
	}),
}, "", 201);
const cookie = sessionCookie(registration.response);

const richProgress = {
	campaign_version: 2,
	save_initialized: true,
	save_revision: 9,
	save_updated_at: 900,
	current_level: 12,
	credits: 900,
	completed_levels: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11],
	observed_objects: ["moon", "jupiter", "saturn"],
	journal_entries: ["first_light", "rings"],
	unlocked_parts: ["tripod", "mount", "tube"],
};
const firstUpload = await request("/api/cloud-save", {
	method: "PUT",
	body: JSON.stringify({ progress: richProgress, baseVersion: 0, schemaVersion: 2, clientUpdatedAt: 900 }),
}, cookie);
assert.equal(firstUpload.data.version, 1);

const staleProgress = {
	...richProgress,
	save_revision: 4,
	save_updated_at: 400,
	current_level: 5,
	credits: 100,
	completed_levels: [1, 2, 3, 4],
	observed_objects: ["moon"],
};
const rejected = await request("/api/cloud-save", {
	method: "PUT",
	body: JSON.stringify({ progress: staleProgress, baseVersion: 1, schemaVersion: 2, clientUpdatedAt: 400 }),
}, cookie, 409);
assert.equal(rejected.data.error, "stale_progress");

const afterReject = await request("/api/cloud-save", {}, cookie);
assert.equal(afterReject.data.save.version, 1);
assert.equal(afterReject.data.save.progress.current_level, 12);
assert.deepEqual(afterReject.data.save.progress.observed_objects, richProgress.observed_objects);

const mergedProgress = {
	...richProgress,
	save_revision: 10,
	save_updated_at: 1000,
	current_level: 13,
	completed_levels: [...richProgress.completed_levels, 12],
	observed_objects: [...richProgress.observed_objects, "andromeda"],
};
const mergedUpload = await request("/api/cloud-save", {
	method: "PUT",
	body: JSON.stringify({ progress: mergedProgress, baseVersion: 1, schemaVersion: 2, clientUpdatedAt: 1000 }),
}, cookie);
assert.equal(mergedUpload.data.version, 2);

console.log(JSON.stringify({
	ok: true,
	staleUploadRejected: rejected.data.error,
	cloudLevelAfterReject: afterReject.data.save.progress.current_level,
	mergedVersion: mergedUpload.data.version,
}, null, 2));
