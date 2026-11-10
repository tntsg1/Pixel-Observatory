import assert from "node:assert/strict";
import { COSMETIC_BUNDLES, QUESTION_FORMS, RESEARCH_NODES, TEXT_ARCHIVE_MODULES } from "../web/landing/study/research-content.mjs";

const correctOptionPositionCounts = [0, 0, 0, 0];

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
      correctOptionPositionCounts[question.options.findIndex(option => option.id === question.correctOptionId)] += 1;
    }
  }
}
assert.ok(
  Math.max(...correctOptionPositionCounts) - Math.min(...correctOptionPositionCounts) <= 2,
  `correct answers are near-balanced across source positions: ${correctOptionPositionCounts}`,
);
assert.ok(
  correctOptionPositionCounts.every(count => count > 0),
  `correct answers use all four source positions: ${correctOptionPositionCounts}`,
);
assert.deepEqual(Object.keys(TEXT_ARCHIVE_MODULES), ["baseline", "A", "B", "C", "D", "E"]);
assert.equal(Object.keys(TEXT_ARCHIVE_MODULES).length * 3, 18, "The text route presents six matched learning sections for 18 questions.");
assert.equal(COSMETIC_BUNDLES.length, 12);
assert.equal(new Set(COSMETIC_BUNDLES.map(bundle => bundle.id)).size, 12);
console.log("research content contract: ok");
