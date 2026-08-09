import assert from "node:assert/strict";
import { COSMETIC_BUNDLES, QUESTION_FORMS, RESEARCH_NODES, TEXT_ARCHIVE_MODULES } from "../web/landing/study/research-content.mjs";

assert.deepEqual(RESEARCH_NODES.map(node => [node.id, node.afterLevel]), [
  ["baseline", 1], ["A", 6], ["B", 11], ["C", 16], ["D", 21], ["E", 24],
]);
for (const node of RESEARCH_NODES) {
  assert.equal(QUESTION_FORMS[node.id].length, 3, `${node.id} has three equivalent forms`);
  for (const form of QUESTION_FORMS[node.id]) {
    assert.equal(form.questions.length, 3);
    for (const question of form.questions) {
      assert.equal(question.options.length, 4);
      assert.ok(question.prompt.en && question.prompt.zh);
      assert.ok(question.options.every(option => option.en && option.zh));
      assert.ok(question.options.some(option => option.id === question.correctOptionId));
    }
  }
}
assert.deepEqual(Object.keys(TEXT_ARCHIVE_MODULES), ["A", "B", "C", "D", "E"]);
assert.equal(COSMETIC_BUNDLES.length, 12);
assert.equal(new Set(COSMETIC_BUNDLES.map(bundle => bundle.id)).size, 12);
console.log("research content contract: ok");
