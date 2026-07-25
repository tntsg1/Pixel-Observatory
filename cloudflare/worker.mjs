const ISOLATION_HEADERS = {
	"Cross-Origin-Embedder-Policy": "require-corp",
	"Cross-Origin-Opener-Policy": "same-origin",
	"Cross-Origin-Resource-Policy": "same-origin",
};

const VISITOR_ID_PATTERN = /^[a-zA-Z0-9_-]{16,96}$/;

export class VisitorCounter {
	constructor(state) {
		this.state = state;
	}

	async fetch(request) {
		if (request.method === "GET") {
			return this._response(await this._total(), false);
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
		return this._response(await this._total(), isNew);
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
			"/index.pck": "application/octet-stream",
			"/index.side.wasm": "application/wasm",
		};
		if (large_game_files.hasOwnProperty(url.pathname)) {
			const key = url.pathname.slice(1);
			const asset = await env.GAME_ASSETS.get(key);
			if (!asset) {
				return new Response("Game data is unavailable.", { status: 404 });
			}

			const headers = new Headers();
			asset.writeHttpMetadata(headers);
			headers.set("Content-Type", large_game_files[url.pathname]);
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
