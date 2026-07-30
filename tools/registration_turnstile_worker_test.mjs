import assert from "node:assert/strict";
import fs from "node:fs";

const worker = fs.readFileSync(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8");
const accountClient = fs.readFileSync(new URL("../web/landing/account.js", import.meta.url), "utf8");
assert.doesNotMatch(
	accountClient,
	/The observatory returned an unreadable response\./,
	"Registration must not expose the old opaque unreadable-response message.",
);
assert.match(accountClient, /The observatory service was interrupted\. Please try again\./);


assert.match(
	worker,
	/body\.append\("remoteip", clientAddress\(request, env\)\);/,
	"Turnstile verification must pass env when resolving the client address.",
);
assert.doesNotMatch(
	worker,
	/body\.append\("remoteip", clientAddress\(request\)\);/,
	"The production Turnstile path must not call clientAddress without env.",
);
assert.match(
	worker,
	/if \(url\.pathname\.startsWith\("\/api\/"\)\) \{\s*try \{/,
	"Every API route must be protected by a JSON error boundary.",
);
assert.match(
	worker,
	/"internal_error"/,
	"The API error boundary must return a stable machine-readable error code.",
);

const { default: workerModule } = await import(new URL("../cloudflare/worker.mjs", import.meta.url));

class RegistrationProbeDb {
	prepare(sql) {
		return {
			bind() {
				return {
					async run() {
						return { success: true };
					},
					async first() {
						return sql.includes("SELECT count FROM rate_limits") ? { count: 1 } : null;
					},
				};
			},
		};
	}
}

const originalFetch = globalThis.fetch;
let forwardedAddress = "";
globalThis.fetch = async (input, init = {}) => {
	assert.equal(String(input), "https://challenges.cloudflare.com/turnstile/v0/siteverify");
	forwardedAddress = String(init.body.get("remoteip") || "");
	return new Response(JSON.stringify({ success: false }), {
		status: 200,
		headers: { "content-type": "application/json" },
	});
};

try {
	const response = await workerModule.fetch(new Request("https://pixelobservatorygame.com/api/auth/register", {
		method: "POST",
		headers: {
			"content-type": "application/json",
			"CF-Connecting-IP": "203.0.113.5",
		},
		body: JSON.stringify({
			username: "registration_probe",
			password: "test-password-only",
			website: "",
			turnstileToken: "test-token",
		}),
	}), {
		DB: new RegistrationProbeDb(),
		RATE_LIMIT_SECRET: "test-rate-secret",
		TURNSTILE_SECRET: "test-turnstile-secret",
	});
	assert.equal(response.status, 400);
	assert.match(response.headers.get("content-type") || "", /^application\/json/);
	assert.equal((await response.json()).error, "verification_failed");
	assert.equal(forwardedAddress, "203.0.113.5");
} finally {
	globalThis.fetch = originalFetch;
}

const originalConsoleError = console.error;
console.error = () => {};
const boundaryResponse = await workerModule.fetch(new Request("https://pixelobservatorygame.com/api/auth/register", {
	method: "POST",
	body: JSON.stringify({}),
}), {
	DB: { prepare() { throw new Error("test database failure"); } },
	RATE_LIMIT_SECRET: "test-rate-secret",
});
console.error = originalConsoleError;
assert.equal(boundaryResponse.status, 500);
assert.match(boundaryResponse.headers.get("content-type") || "", /^application\/json/);
assert.equal((await boundaryResponse.json()).error, "internal_error");

console.log("PASS registration Turnstile worker: production client address and JSON error boundary");
