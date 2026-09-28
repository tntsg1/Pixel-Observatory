import assert from "node:assert/strict";
import { resolveLargeGameAsset, serveLargeGameAsset } from "../cloudflare/worker.mjs";

const bytes = new TextEncoder().encode("0123456789");
const metadata = {
	size: bytes.length,
	httpEtag: '"test-etag"',
	writeHttpMetadata() {},
};
const bucket = {
	async head(key) {
		assert.equal(key, "index.pck");
		return metadata;
	},
	async get(key, options = {}) {
		assert.equal(key, "index.pck");
		const offset = options.range?.offset ?? 0;
		const length = options.range?.length ?? bytes.length;
		return { ...metadata, body: bytes.slice(offset, offset + length) };
	},
};
const file = { key: "index.pck", contentType: "application/octet-stream" };

const partial = await serveLargeGameAsset(new Request("https://example.com/game/index.pck", {
	headers: { Range: "bytes=2-5" },
}), bucket, file);
assert.equal(partial.status, 206);
assert.equal(partial.headers.get("accept-ranges"), "bytes");
assert.equal(partial.headers.get("content-range"), "bytes 2-5/10");
assert.equal(partial.headers.get("content-length"), "4");
assert.equal(await partial.text(), "2345");

const suffix = await serveLargeGameAsset(new Request("https://example.com/game/index.pck", {
	headers: { Range: "bytes=-3" },
}), bucket, file);
assert.equal(suffix.status, 206);
assert.equal(suffix.headers.get("content-range"), "bytes 7-9/10");
assert.equal(await suffix.text(), "789");

const invalid = await serveLargeGameAsset(new Request("https://example.com/game/index.pck", {
	headers: { Range: "bytes=99-100" },
}), bucket, file);
assert.equal(invalid.status, 416);
assert.equal(invalid.headers.get("content-range"), "bytes */10");

const head = await serveLargeGameAsset(new Request("https://example.com/game/index.pck", {
	method: "HEAD",
}), bucket, file);
assert.equal(head.status, 200);
assert.equal(head.headers.get("content-length"), "10");
assert.equal(head.headers.get("cache-control"), "public, max-age=31536000, immutable");
assert.equal(head.headers.get("cloudflare-cdn-cache-control"), "public, s-maxage=31536000");
assert.equal(await head.text(), "");

const cached = await serveLargeGameAsset(new Request("https://example.com/game/index.pck", {
	headers: { "If-None-Match": '"test-etag"' },
}), bucket, file);
assert.equal(cached.status, 304);

assert.deepEqual(resolveLargeGameAsset("/game/runtime/cf93a2c/index.pck"), {
	key: "runtime/cf93a2c/index.pck",
	contentType: "application/octet-stream",
});
assert.deepEqual(resolveLargeGameAsset("/game/runtime/cf93a2c/index.wasm"), {
	key: "runtime/cf93a2c/index.wasm",
	contentType: "application/wasm",
});
assert.equal(resolveLargeGameAsset("/game/runtime/../../secret/index.pck"), null);

assert.deepEqual(resolveLargeGameAsset("/media/trailer/20260927/trailer-1080.mp4"), {
	key: "media/trailer/20260927/trailer-1080.mp4",
	contentType: "video/mp4",
});
assert.deepEqual(resolveLargeGameAsset("/media/trailer/20260927/teaser-720.mp4"), {
	key: "media/trailer/20260927/teaser-720.mp4",
	contentType: "video/mp4",
});
assert.equal(resolveLargeGameAsset("/media/trailer/20260927/other.mp4"), null);
assert.equal(resolveLargeGameAsset("/media/trailer/../runtime/x/trailer-720.mp4"), null);
assert.equal(resolveLargeGameAsset("/media/trailer/latest/trailer-720.mp4"), null);

console.log("Large game asset range delivery: PASS");
