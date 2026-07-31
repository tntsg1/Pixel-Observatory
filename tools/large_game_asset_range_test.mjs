import assert from "node:assert/strict";
import { serveLargeGameAsset } from "../cloudflare/worker.mjs";

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
assert.equal(await head.text(), "");

const cached = await serveLargeGameAsset(new Request("https://example.com/game/index.pck", {
	headers: { "If-None-Match": '"test-etag"' },
}), bucket, file);
assert.equal(cached.status, 304);

console.log("Large game asset range delivery: PASS");
