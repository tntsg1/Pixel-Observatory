const ISOLATION_HEADERS = {
	"Cross-Origin-Embedder-Policy": "require-corp",
	"Cross-Origin-Opener-Policy": "same-origin",
	"Cross-Origin-Resource-Policy": "same-origin",
};

const VISITOR_ID_PATTERN = /^[a-zA-Z0-9_-]{16,96}$/;
const USERNAME_PATTERN = /^[a-zA-Z0-9_.-]{3,24}$/;
const SESSION_COOKIE = "po_session";
const SESSION_SECONDS = 60 * 60 * 24 * 30;
const MAX_SAVE_BYTES = 900_000;
const MAX_FEEDBACK_BYTES = 8_000;
// Cloudflare Workers Web Crypto currently caps PBKDF2 at 100,000 rounds.
const PASSWORD_ITERATIONS = 100_000;
const VISITOR_ALLOWED_ORIGINS = new Set([
	"https://pixelobservatorygame.com",
	"https://tntsg1.github.io",
]);

function json(data, status = 200, extraHeaders = {}) {
	const headers = new Headers({
		"Content-Type": "application/json; charset=utf-8",
		"Cache-Control": "no-store",
		...extraHeaders,
	});
	return new Response(JSON.stringify(data), { status, headers });
}

function apiError(message, status = 400, code = "bad_request") {
	return json({ ok: false, error: code, message }, status);
}

function visitorResponse(response, request) {
	const origin = request.headers.get("Origin");
	if (!origin || !VISITOR_ALLOWED_ORIGINS.has(origin)) return response;
	const headers = new Headers(response.headers);
	headers.set("Access-Control-Allow-Origin", origin);
	headers.set("Vary", "Origin");
	return new Response(response.body, { status: response.status, headers });
}

export class VisitorCounter {
	constructor(state) {
		this.state = state;
	}

	async fetch(request) {
		if (request.method === "OPTIONS") {
			return visitorResponse(new Response(null, {
				status: 204,
				headers: {
					"Access-Control-Allow-Headers": "content-type",
					"Access-Control-Allow-Methods": "GET, POST, OPTIONS",
				},
			}), request);
		}
		if (request.method === "GET") return visitorResponse(this._response(await this._total(), false), request);
		if (request.method !== "POST") return new Response("Method not allowed.", { status: 405 });

		let payload;
		try {
			payload = await request.json();
		} catch {
			return new Response("Invalid visitor payload.", { status: 400 });
		}
		const visitorId = String(payload?.visitorId || "");
		if (!VISITOR_ID_PATTERN.test(visitorId)) return new Response("Invalid visitor id.", { status: 400 });

		const key = `visitor:${visitorId}`;
		const seen = await this.state.storage.get(key);
		let isNew = false;
		if (!seen) {
			isNew = true;
			await this.state.storage.put(key, Date.now());
			await this.state.storage.put("total", (await this._total()) + 1);
		}
		return visitorResponse(this._response(await this._total(), isNew), request);
	}

	async _total() {
		return Number(await this.state.storage.get("total")) || 0;
	}

	_response(total, isNew) {
		return json({ total, isNew });
	}
}

function bytesToBase64(bytes) {
	let binary = "";
	for (const byte of bytes) binary += String.fromCharCode(byte);
	return btoa(binary);
}

function base64ToBytes(value) {
	const binary = atob(value);
	return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

function randomToken(byteCount = 32) {
	const bytes = new Uint8Array(byteCount);
	crypto.getRandomValues(bytes);
	return bytesToBase64(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function sha256(value) {
	const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
	return bytesToBase64(new Uint8Array(digest));
}

async function passwordHash(password, saltBytes, iterations = PASSWORD_ITERATIONS) {
	const material = await crypto.subtle.importKey(
		"raw",
		new TextEncoder().encode(password),
		"PBKDF2",
		false,
		["deriveBits"],
	);
	const bits = await crypto.subtle.deriveBits(
		{ name: "PBKDF2", hash: "SHA-256", salt: saltBytes, iterations },
		material,
		256,
	);
	return bytesToBase64(new Uint8Array(bits));
}

function constantTimeEqual(left, right) {
	if (left.length !== right.length) return false;
	let difference = 0;
	for (let i = 0; i < left.length; i += 1) difference |= left.charCodeAt(i) ^ right.charCodeAt(i);
	return difference === 0;
}

function parseCookies(request) {
	const values = {};
	for (const part of (request.headers.get("Cookie") || "").split(";")) {
		const index = part.indexOf("=");
		if (index > 0) values[part.slice(0, index).trim()] = decodeURIComponent(part.slice(index + 1).trim());
	}
	return values;
}

function sessionCookie(token) {
	return `${SESSION_COOKIE}=${encodeURIComponent(token)}; Path=/; Max-Age=${SESSION_SECONDS}; HttpOnly; Secure; SameSite=Lax`;
}

function clearSessionCookie() {
	return `${SESSION_COOKIE}=; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax`;
}

function requestOriginAllowed(request) {
	const origin = request.headers.get("Origin");
	if (!origin) return true;
	const url = new URL(request.url);
	return origin === url.origin;
}

async function readJson(request, maxBytes = 32_000) {
	const length = Number(request.headers.get("Content-Length") || 0);
	if (length > maxBytes) throw new Error("payload_too_large");
	const text = await request.text();
	if (new TextEncoder().encode(text).length > maxBytes) throw new Error("payload_too_large");
	return JSON.parse(text || "{}");
}

function clientAddress(request) {
	return request.headers.get("CF-Connecting-IP") || "unknown";
}

async function rateLimit(env, request, bucket, limit, windowSeconds) {
	const windowStart = Math.floor(Date.now() / 1000 / windowSeconds) * windowSeconds;
	const subject = await sha256(`${env.RATE_LIMIT_SECRET || "local"}:${clientAddress(request)}:${bucket}`);
	await env.DB.prepare(
		`INSERT INTO rate_limits (bucket, subject_hash, window_start, count)
		 VALUES (?, ?, ?, 1)
		 ON CONFLICT(bucket, subject_hash, window_start) DO UPDATE SET count = count + 1`,
	).bind(bucket, subject, windowStart).run();
	const row = await env.DB.prepare(
		"SELECT count FROM rate_limits WHERE bucket = ? AND subject_hash = ? AND window_start = ?",
	).bind(bucket, subject, windowStart).first();
	return Number(row?.count || 0) <= limit;
}

async function verifyTurnstile(env, request, token) {
	if (env.TURNSTILE_BYPASS === "local-test") return true;
	if (!token || !env.TURNSTILE_SECRET) return false;
	const body = new FormData();
	body.append("secret", env.TURNSTILE_SECRET);
	body.append("response", token);
	body.append("remoteip", clientAddress(request));
	const response = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
		method: "POST",
		body,
	});
	if (!response.ok) return false;
	const result = await response.json();
	return result.success === true;
}

async function sessionForRequest(env, request) {
	const token = parseCookies(request)[SESSION_COOKIE];
	if (!token) return null;
	const tokenHash = await sha256(token);
	const now = Math.floor(Date.now() / 1000);
	const row = await env.DB.prepare(
		`SELECT users.id, users.username, users.role, sessions.token_hash
		 FROM sessions JOIN users ON users.id = sessions.user_id
		 WHERE sessions.token_hash = ? AND sessions.expires_at > ?`,
	).bind(tokenHash, now).first();
	if (!row) return null;
	env.DB.prepare("UPDATE sessions SET last_seen_at = ? WHERE token_hash = ?").bind(now, tokenHash).run();
	return row;
}

async function createSession(env, request, userId) {
	const token = randomToken();
	const tokenHash = await sha256(token);
	const now = Math.floor(Date.now() / 1000);
	const agentHash = await sha256(request.headers.get("User-Agent") || "");
	await env.DB.prepare(
		`INSERT INTO sessions (token_hash, user_id, created_at, expires_at, last_seen_at, user_agent_hash)
		 VALUES (?, ?, ?, ?, ?, ?)`,
	).bind(tokenHash, userId, now, now + SESSION_SECONDS, now, agentHash).run();
	return token;
}

function publicUser(user) {
	return { id: user.id, username: user.username, role: user.role };
}

async function handleRegister(request, env) {
	if (!(await rateLimit(env, request, "register", 6, 3600))) return apiError("Too many registration attempts. Please wait.", 429, "rate_limited");
	let body;
	try {
		body = await readJson(request);
	} catch {
		return apiError("Invalid registration request.");
	}
	if (String(body.website || "").trim()) return apiError("Verification failed.", 400, "verification_failed");
	const username = String(body.username || "").trim();
	const password = String(body.password || "");
	if (!USERNAME_PATTERN.test(username)) return apiError("Use 3-24 letters, numbers, dots, dashes, or underscores.", 400, "invalid_username");
	if (password.length < 8 || password.length > 128) return apiError("Password must be 8-128 characters.", 400, "invalid_password");
	if (!(await verifyTurnstile(env, request, body.turnstileToken))) return apiError("Please complete the human check again.", 400, "verification_failed");

	const existing = await env.DB.prepare("SELECT id FROM users WHERE username_key = ?").bind(username.toLowerCase()).first();
	if (existing) return apiError("That observer name is already in use.", 409, "username_taken");
	const salt = new Uint8Array(16);
	crypto.getRandomValues(salt);
	const user = {
		id: crypto.randomUUID(),
		username,
		role: "user",
	};
	const now = Math.floor(Date.now() / 1000);
	const hash = await passwordHash(password, salt);
	await env.DB.prepare(
		`INSERT INTO users (id, username, username_key, password_hash, password_salt, password_iterations, role, created_at, last_login_at)
		 VALUES (?, ?, ?, ?, ?, ?, 'user', ?, ?)`,
	).bind(user.id, username, username.toLowerCase(), hash, bytesToBase64(salt), PASSWORD_ITERATIONS, now, now).run();
	const token = await createSession(env, request, user.id);
	return json({ ok: true, user: publicUser(user) }, 201, { "Set-Cookie": sessionCookie(token) });
}

async function handleLogin(request, env) {
	if (!(await rateLimit(env, request, "login", 12, 900))) return apiError("Too many login attempts. Please wait.", 429, "rate_limited");
	let body;
	try {
		body = await readJson(request);
	} catch {
		return apiError("Invalid login request.");
	}
	const usernameKey = String(body.username || "").trim().toLowerCase();
	const password = String(body.password || "");
	const user = await env.DB.prepare(
		"SELECT id, username, role, password_hash, password_salt, password_iterations FROM users WHERE username_key = ?",
	).bind(usernameKey).first();
	if (!user) return apiError("Observer name or password is incorrect.", 401, "invalid_credentials");
	const candidate = await passwordHash(password, base64ToBytes(user.password_salt), Number(user.password_iterations));
	if (!constantTimeEqual(candidate, user.password_hash)) return apiError("Observer name or password is incorrect.", 401, "invalid_credentials");
	const now = Math.floor(Date.now() / 1000);
	await env.DB.prepare("UPDATE users SET last_login_at = ? WHERE id = ?").bind(now, user.id).run();
	const token = await createSession(env, request, user.id);
	return json({ ok: true, user: publicUser(user) }, 200, { "Set-Cookie": sessionCookie(token) });
}

async function handleLogout(request, env) {
	const token = parseCookies(request)[SESSION_COOKIE];
	if (token) await env.DB.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(await sha256(token)).run();
	return json({ ok: true }, 200, { "Set-Cookie": clearSessionCookie() });
}

async function handlePasswordChange(request, env) {
	const session = await sessionForRequest(env, request);
	if (!session) return apiError("Sign in first.", 401, "unauthorized");
	if (!(await rateLimit(env, request, "password-change", 6, 3600))) return apiError("Too many password changes. Please wait.", 429, "rate_limited");
	let body;
	try {
		body = await readJson(request);
	} catch {
		return apiError("Invalid password request.");
	}
	const currentPassword = String(body.currentPassword || "");
	const newPassword = String(body.newPassword || "");
	if (newPassword.length < 8 || newPassword.length > 128) return apiError("New password must be 8-128 characters.", 400, "invalid_password");
	const user = await env.DB.prepare(
		"SELECT password_hash, password_salt, password_iterations FROM users WHERE id = ?",
	).bind(session.id).first();
	const candidate = await passwordHash(currentPassword, base64ToBytes(user.password_salt), Number(user.password_iterations));
	if (!constantTimeEqual(candidate, user.password_hash)) return apiError("Current password is incorrect.", 401, "invalid_credentials");
	const salt = new Uint8Array(16);
	crypto.getRandomValues(salt);
	const hash = await passwordHash(newPassword, salt);
	await env.DB.prepare(
		"UPDATE users SET password_hash = ?, password_salt = ?, password_iterations = ? WHERE id = ?",
	).bind(hash, bytesToBase64(salt), PASSWORD_ITERATIONS, session.id).run();
	return json({ ok: true });
}

async function handleSaveGet(request, env) {
	const user = await sessionForRequest(env, request);
	if (!user) return apiError("Sign in to use cloud saves.", 401, "unauthorized");
	const row = await env.DB.prepare(
		"SELECT version, progress_json, schema_version, updated_at, client_updated_at FROM cloud_saves WHERE user_id = ?",
	).bind(user.id).first();
	if (!row) return json({ ok: true, save: null });
	return json({
		ok: true,
		save: {
			version: Number(row.version),
			progress: JSON.parse(row.progress_json),
			schemaVersion: Number(row.schema_version),
			updatedAt: Number(row.updated_at),
			clientUpdatedAt: Number(row.client_updated_at || 0),
		},
	});
}

async function handleSavePut(request, env) {
	const user = await sessionForRequest(env, request);
	if (!user) return apiError("Sign in to use cloud saves.", 401, "unauthorized");
	if (!(await rateLimit(env, request, "cloud-save", 180, 3600))) return apiError("Cloud sync is cooling down. Try again shortly.", 429, "rate_limited");
	let body;
	try {
		body = await readJson(request, MAX_SAVE_BYTES);
	} catch {
		return apiError("The save is too large or invalid.", 413, "invalid_save");
	}
	if (!body.progress || typeof body.progress !== "object" || Array.isArray(body.progress)) return apiError("Invalid save data.", 400, "invalid_save");
	const progressJson = JSON.stringify(body.progress);
	if (new TextEncoder().encode(progressJson).length > MAX_SAVE_BYTES) return apiError("The save is too large.", 413, "invalid_save");
	const existing = await env.DB.prepare("SELECT version FROM cloud_saves WHERE user_id = ?").bind(user.id).first();
	const currentVersion = Number(existing?.version || 0);
	const baseVersion = Number(body.baseVersion || 0);
	if (existing && baseVersion !== currentVersion) return json({ ok: false, error: "version_conflict", currentVersion }, 409);
	const version = currentVersion + 1;
	const now = Math.floor(Date.now() / 1000);
	await env.DB.prepare(
		`INSERT INTO cloud_saves (user_id, version, progress_json, schema_version, updated_at, client_updated_at)
		 VALUES (?, ?, ?, ?, ?, ?)
		 ON CONFLICT(user_id) DO UPDATE SET version = excluded.version, progress_json = excluded.progress_json,
		   schema_version = excluded.schema_version, updated_at = excluded.updated_at, client_updated_at = excluded.client_updated_at`,
	).bind(user.id, version, progressJson, Number(body.schemaVersion || 1), now, Number(body.clientUpdatedAt || now)).run();
	return json({ ok: true, version, updatedAt: now });
}

async function handleFeedbackPost(request, env) {
	if (!(await rateLimit(env, request, "feedback", 8, 3600))) return apiError("The feedback channel is resting. Please try later.", 429, "rate_limited");
	let body;
	try {
		body = await readJson(request, MAX_FEEDBACK_BYTES);
	} catch {
		return apiError("That feedback is too large.", 413, "invalid_feedback");
	}
	if (String(body.website || "").trim()) return apiError("Verification failed.", 400, "verification_failed");
	if (!(await verifyTurnstile(env, request, body.turnstileToken))) return apiError("Please complete the human check again.", 400, "verification_failed");
	const message = String(body.message || "").trim();
	const allowedCategories = new Set(["bug", "idea", "visual", "audio", "story", "other"]);
	const category = allowedCategories.has(body.category) ? body.category : "other";
	if (message.length < 8 || message.length > 4000) return apiError("Please write between 8 and 4000 characters.", 400, "invalid_feedback");
	const user = await sessionForRequest(env, request);
	const id = `FB-${Date.now().toString(36).toUpperCase()}-${randomToken(3).toUpperCase()}`;
	const now = Math.floor(Date.now() / 1000);
	const page = String(body.page || "").slice(0, 300);
	const contextJson = JSON.stringify(body.context && typeof body.context === "object" ? body.context : {});
	await env.DB.prepare(
		`INSERT INTO feedback (id, user_id, username_snapshot, category, message, page, context_json, status, admin_note, created_at, updated_at)
		 VALUES (?, ?, ?, ?, ?, ?, ?, 'new', '', ?, ?)`,
	).bind(id, user?.id || null, user?.username || "Guest observer", category, message, page, contextJson, now, now).run();
	return json({ ok: true, receipt: id, message: "Signal received. Thank you for helping the observatory see more clearly." }, 201);
}

async function requireAdmin(env, request) {
	const user = await sessionForRequest(env, request);
	return user?.role === "admin" ? user : null;
}

async function handleAdminList(request, env) {
	if (!(await requireAdmin(env, request))) return apiError("Administrator access required.", 403, "forbidden");
	const url = new URL(request.url);
	const status = url.searchParams.get("status") || "";
	const category = url.searchParams.get("category") || "";
	const conditions = [];
	const values = [];
	if (status) {
		conditions.push("status = ?");
		values.push(status);
	}
	if (category) {
		conditions.push("category = ?");
		values.push(category);
	}
	const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
	const result = await env.DB.prepare(
		`SELECT id, username_snapshot, category, message, page, context_json, status, admin_note, created_at, updated_at
		 FROM feedback ${where} ORDER BY created_at DESC LIMIT 250`,
	).bind(...values).all();
	return json({ ok: true, feedback: result.results || [] });
}

async function handleAdminUpdate(request, env, id) {
	if (!(await requireAdmin(env, request))) return apiError("Administrator access required.", 403, "forbidden");
	let body;
	try {
		body = await readJson(request, 12_000);
	} catch {
		return apiError("Invalid update.");
	}
	const allowed = new Set(["new", "reviewing", "planned", "resolved", "closed"]);
	const status = allowed.has(body.status) ? body.status : "new";
	const note = String(body.adminNote || "").slice(0, 4000);
	const now = Math.floor(Date.now() / 1000);
	const result = await env.DB.prepare(
		"UPDATE feedback SET status = ?, admin_note = ?, updated_at = ? WHERE id = ?",
	).bind(status, note, now, id).run();
	if (!result.meta?.changes) return apiError("Feedback entry not found.", 404, "not_found");
	return json({ ok: true });
}

async function handleApi(request, env, url) {
	if (request.method !== "GET" && !requestOriginAllowed(request)) return apiError("Request origin rejected.", 403, "origin_rejected");
	if (url.pathname === "/api/config" && request.method === "GET") {
		const siteKey = env.TURNSTILE_BYPASS === "local-test"
			? "1x00000000000000000000AA"
			: (env.TURNSTILE_SITE_KEY || "");
		return json({ turnstileSiteKey: siteKey, cloudSync: true, feedback: true });
	}
	if (url.pathname === "/api/auth/register" && request.method === "POST") return handleRegister(request, env);
	if (url.pathname === "/api/auth/login" && request.method === "POST") return handleLogin(request, env);
	if (url.pathname === "/api/auth/logout" && request.method === "POST") return handleLogout(request, env);
	if (url.pathname === "/api/auth/password" && request.method === "POST") return handlePasswordChange(request, env);
	if (url.pathname === "/api/auth/session" && request.method === "GET") {
		const user = await sessionForRequest(env, request);
		return json({ ok: true, user: user ? publicUser(user) : null });
	}
	if (url.pathname === "/api/cloud-save" && request.method === "GET") return handleSaveGet(request, env);
	if (url.pathname === "/api/cloud-save" && request.method === "PUT") return handleSavePut(request, env);
	if (url.pathname === "/api/feedback" && request.method === "POST") return handleFeedbackPost(request, env);
	if (url.pathname === "/api/admin/feedback" && request.method === "GET") return handleAdminList(request, env);
	const adminMatch = url.pathname.match(/^\/api\/admin\/feedback\/([^/]+)$/);
	if (adminMatch && request.method === "PATCH") return handleAdminUpdate(request, env, decodeURIComponent(adminMatch[1]));
	return apiError("API route not found.", 404, "not_found");
}

function withIsolationHeaders(response) {
	const headers = new Headers(response.headers);
	for (const [name, value] of Object.entries(ISOLATION_HEADERS)) headers.set(name, value);
	headers.set("X-Content-Type-Options", "nosniff");
	headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
	return new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers,
	});
}

export default {
	async fetch(request, env) {
		const url = new URL(request.url);
		if (url.pathname === "/api/visits") {
			const counter = env.VISITOR_COUNTER.get(env.VISITOR_COUNTER.idFromName("global"));
			return counter.fetch(request);
		}
		if (url.pathname.startsWith("/api/")) return withIsolationHeaders(await handleApi(request, env, url));

		const largeGameFiles = {
			"/index.pck": { key: "index.pck", contentType: "application/octet-stream" },
			"/index.side.wasm": { key: "index.side.wasm", contentType: "application/wasm" },
			"/game/index.pck": { key: "index.pck", contentType: "application/octet-stream" },
			"/game/index.side.wasm": { key: "index.side.wasm", contentType: "application/wasm" },
		};
		if (Object.hasOwn(largeGameFiles, url.pathname)) {
			const largeFile = largeGameFiles[url.pathname];
			const asset = await env.GAME_ASSETS.get(largeFile.key);
			if (!asset) return new Response("Game data is unavailable.", { status: 404 });
			const headers = new Headers();
			asset.writeHttpMetadata(headers);
			headers.set("Content-Type", largeFile.contentType);
			headers.set("Content-Length", String(asset.size));
			headers.set("ETag", asset.httpEtag);
			headers.set("Cache-Control", "no-cache");
			return withIsolationHeaders(new Response(asset.body, { headers }));
		}
		return withIsolationHeaders(await env.ASSETS.fetch(request));
	},
};
