const ISOLATION_HEADERS = {
	"Cross-Origin-Embedder-Policy": "require-corp",
	"Cross-Origin-Opener-Policy": "same-origin",
	"Cross-Origin-Resource-Policy": "same-origin",
};

const VISITOR_ID_PATTERN = /^[a-zA-Z0-9_-]{16,96}$/;
const VISITOR_ALLOWED_ORIGINS = new Set([
	"https://pixelobservatorygame.com",
	"https://tntsg1.github.io",
]);

function visitor_response(response, request) {
	const origin = request.headers.get("Origin");
	if (!origin || !VISITOR_ALLOWED_ORIGINS.has(origin)) {
		return response;
	}
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
			return visitor_response(new Response(null, {
				status: 204,
				headers: { "Access-Control-Allow-Headers": "content-type", "Access-Control-Allow-Methods": "GET, POST, OPTIONS" },
			}), request);
		}
		if (request.method === "GET") {
			return visitor_response(this._response(await this._total(), false), request);
		}
		if (request.method !== "POST") {
			return new Response("Method not allowed.", { status: 405 });
		}

		let payload;
		try {
			payload = await request.json();
		} catch (_) {
			return new Response("Invalid visitor payload.", { status: 400 });
		}
		const visitorId = String(payload?.visitorId || "");
		if (!VISITOR_ID_PATTERN.test(visitorId)) {
			return new Response("Invalid visitor id.", { status: 400 });
		}

		const key = `visitor:${visitorId}`;
		const seen = await this.state.storage.get(key);
		let isNew = false;
		if (!seen) {
			isNew = true;
			await this.state.storage.put(key, Date.now());
			await this.state.storage.put("total", (await this._total()) + 1);
		}
		return visitor_response(this._response(await this._total(), isNew), request);
	}

	async _total() {
		return Number(await this.state.storage.get("total")) || 0;
	}

	_response(total, isNew) {
		return Response.json({ total, isNew }, {
			headers: { "Cache-Control": "no-store" },
		});
	}
}

function with_isolation_headers(response) {
	const headers = new Headers(response.headers);
	for (const [name, value] of Object.entries(ISOLATION_HEADERS)) {
		headers.set(name, value);
	}
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
		const large_game_files = {
			"/index.pck": {
				key: "index.pck",
				content_type: "application/octet-stream",
			},
			"/index.side.wasm": {
				key: "index.side.wasm",
				content_type: "application/wasm",
			},
			"/game/index.pck": {
				key: "index.pck",
				content_type: "application/octet-stream",
			},
			"/game/index.side.wasm": {
				key: "index.side.wasm",
				content_type: "application/wasm",
			},
		};
		if (large_game_files.hasOwnProperty(url.pathname)) {
			const large_file = large_game_files[url.pathname];
			const asset = await env.GAME_ASSETS.get(large_file.key);
			if (!asset) {
				return new Response("Game data is unavailable.", { status: 404 });
			}

			const headers = new Headers();
			asset.writeHttpMetadata(headers);
			headers.set("Content-Type", large_file.content_type);
			headers.set("Content-Length", String(asset.size));
			headers.set("ETag", asset.httpEtag);
			// The pack changes on each game release. Revalidate it so returning
			// players never remain on an old mission/UI build.
			headers.set("Cache-Control", "no-cache");
			return with_isolation_headers(new Response(asset.body, { headers }));
		}

		return with_isolation_headers(await env.ASSETS.fetch(request));
	},
};
