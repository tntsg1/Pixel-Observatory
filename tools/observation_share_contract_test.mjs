import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { normalizeObservationSharePayload } from "../cloudflare/worker.mjs";

const sample = {
  locale: "zh",
  object: { id: "m31\u0000", name: "  仙女座星系  ", type: "星系" },
  telescopeFamily: "space_segmented",
  telescopeName: "太空红外天文台",
  equipment: { primary: "NIRCam", secondary: "近红外", detail: "分段式红外光学系统" },
  parameters: Array.from({ length: 12 }, (_, index) => ({ label: `参数 ${index}`, value: `${index}` })),
  quality: { grade: "Excellent", metrics: { clarity: 108, contrast: -3, detail: 82.5 } },
  discovery: "  暗弱结构\n被分辨出来。  ",
  missionLevel: 31.8,
};

const normalized = normalizeObservationSharePayload(sample);
assert.ok(normalized, "A complete observation payload must normalize.");
assert.equal(normalized.schemaVersion, 1);
assert.equal(normalized.locale, "zh");
assert.equal(normalized.object.id, "m31");
assert.equal(normalized.object.name, "仙女座星系");
assert.equal(normalized.parameters.length, 10, "Only the first ten bounded parameters are archived.");
assert.deepEqual(normalized.quality, { grade: "Excellent", clarity: 100, contrast: 0, detail: 82.5 });
assert.equal(normalized.discovery, "暗弱结构 被分辨出来。");
assert.equal(normalized.missionLevel, 31);
assert.equal(normalizeObservationSharePayload({ object: { id: "m31" } }), null, "Incomplete records must be rejected.");

const [worker, loader, learningCard, overlay, publicPage, messaging] = await Promise.all([
  readFile(new URL("../cloudflare/worker.mjs", import.meta.url), "utf8"),
  readFile(new URL("./patch_web_loader.mjs", import.meta.url), "utf8"),
  readFile(new URL("../scripts/ui/learning_card.gd", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/observation-share.js", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/observation.html", import.meta.url), "utf8"),
  readFile(new URL("../web/landing/messaging.js", import.meta.url), "utf8"),
]);

for (const route of [
  'url.pathname === "/api/observation-shares"',
  'observationShareSendMatch',
  'observationShareMatch',
  'new URL("/observation", url)',
]) assert.ok(worker.includes(route), `Worker contract is missing ${route}`);

assert.ok(loader.includes("observation-share.css"));
assert.ok(loader.includes("observation-share.js"));
assert.ok(learningCard.includes('observatory:observation-complete'));
assert.ok(learningCard.includes('observatory:open-observation-share'));
assert.ok(learningCard.includes('ShareObservationResultButton'));
assert.ok(overlay.includes('data-send-friend'));
assert.ok(overlay.includes('Generate share link'));
assert.ok(publicPage.includes('id="observation-record"'));
assert.ok(messaging.includes("po-observation-link"));
assert.equal(overlay.includes('"<":"&gt;"'), false, "The share dialog must escape opening angle brackets correctly.");

console.log(JSON.stringify({
  ok: true,
  normalizedObject: normalized.object.name,
  parameterLimit: normalized.parameters.length,
  quality: normalized.quality,
  gameEvents: true,
  publicPage: true,
  friendSend: true,
}, null, 2));
