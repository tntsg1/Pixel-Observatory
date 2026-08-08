# Research Data and Questionnaires Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the old sequential reading/game study with anonymous fixed-assignment research sessions, matched bilingual questionnaire nodes, a pure-text archive arm, and one-time cosmetic reward offers.

**Architecture:** `web/landing/study/research-content.mjs` is the canonical bilingual content module imported by both the browser and Cloudflare Worker. Anonymous responses and assignment live only in a second D1 binding named `RESEARCH_DB`; the existing `DB` account database is not queried by research submission handlers. A fresh `/study/` visit launches the isolated original opening and Level 1, while the in-game overlay handles consent and baseline after Level 1; after assignment, `/study/` renders only the archive-text arm's modules, deferral, withdrawal, and completion from server state. Gameplay-arm delivery is implemented in the next plan.

**Tech Stack:** Cloudflare Workers ES modules, two Cloudflare D1 databases, vanilla JavaScript modules, HTML/CSS, Node.js contract/integration tests.

## Global Constraints

- Assignment is server-side 50:50 between `archive_text` and `field_gameplay`, stored once, never displayed before baseline submission, and never changeable.
- All participants complete the common introduction and Level 1 before the optional invitation and three-question baseline.
- Matched nodes are `baseline`, `A` (Levels 2-6), `B` (7-11), `C` (12-16), `D` (17-21), and `E` (22-24).
- Every node has three equivalent forms, three questions per form, four answer options, stable randomized answer positions, English default, and manually reviewed Chinese.
- Survey completion rewards participation, never correctness; incorrect answers receive neutral instructional feedback.
- Surveys are optional. A participant can defer twice per node, then choose no more reminders for the current browser session; settings can re-enable reminders.
- Late submissions are tagged `late_response`; entering ordinary gameplay before completing the text route is tagged `cross_exposed` and excluded from primary analysis.
- Anonymous research records contain no username, email, account ID, IP address, raw user agent, or device fingerprint.
- The account database receives no answer, score, route-arm, or question-form fields.
- No new runtime dependency is added.

---

### Task 1: Canonical bilingual research content

**Files:**
- Create: `web/landing/study/research-content.mjs`
- Create: `tools/research_content_contract_test.mjs`

**Interfaces:**
- Produces: `RESEARCH_VERSION: string`, `RESEARCH_NODES: readonly ResearchNode[]`, `QUESTION_FORMS: Record<NodeId, readonly QuestionForm[]>`, `TEXT_ARCHIVE_MODULES: Record<"A"|"B"|"C"|"D"|"E", TextModule>`, `COSMETIC_BUNDLES: readonly CosmeticBundle[]`.
- `QuestionForm` is `{ id: string, questions: [{ id: string, prompt: {en,zh}, options: [{id,en,zh}], correctOptionId: string }] }`.
- `ResearchNode` is `{ id, afterLevel, nextLevel, title: {en,zh} }`; values are `baseline/1/2`, `A/6/7`, `B/11/12`, `C/16/17`, `D/21/22`, `E/24/null`.

- [ ] **Step 1: Write the failing content contract test**

```js
// tools/research_content_contract_test.mjs
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
```

- [ ] **Step 2: Run the content contract and confirm the missing module failure**

Run: `node tools/research_content_contract_test.mjs`

Expected: FAIL with `ERR_MODULE_NOT_FOUND` for `research-content.mjs`.

- [ ] **Step 3: Implement the canonical module**

Create the exact six nodes and three forms per node. Use these concept boundaries so the text and gameplay arms test the same knowledge without leaking later content:

```js
export const RESEARCH_VERSION = "po_l1_24_matched_v1";
export const RESEARCH_NODES = Object.freeze([
  { id: "baseline", afterLevel: 1, nextLevel: 2, title: { en: "First Light", zh: "初见星光" } },
  { id: "A", afterLevel: 6, nextLevel: 7, title: { en: "Finding and Focusing", zh: "寻星与调焦" } },
  { id: "B", afterLevel: 11, nextLevel: 12, title: { en: "Magnification and Atmosphere", zh: "倍率与大气" } },
  { id: "C", afterLevel: 16, nextLevel: 17, title: { en: "Reflection and Collimation", zh: "反射与准直" } },
  { id: "D", afterLevel: 21, nextLevel: 22, title: { en: "Tracking and Evidence", zh: "追踪与证据" } },
  { id: "E", afterLevel: 24, nextLevel: null, title: { en: "Instrument Reasoning", zh: "仪器推理" } },
]);
```

The three questions at each node cover exactly:

| Node | Concepts |
| --- | --- |
| baseline | finder before main scope; focus changes sharpness; larger aperture gathers more light |
| A | field-of-view sequence; focus versus magnification; why alignment matters |
| B | useful magnification ceiling; poor seeing; Earth-rotation drift and tracking |
| C | Newtonian reflection path; collimation; chromatic aberration comparison |
| D | cloud/light-pollution/seeing distinctions; evidence quality; configuration-to-image causality |
| E | choose an instrument for a target; interpret infrared false colour; distinguish radio data from optical images |

`TEXT_ARCHIVE_MODULES.A-E` each contains 250-400 English words plus a manually equivalent Chinese version, two labelled diagrams described in text/HTML-safe data, and a `conceptIds` array matching its three questions. `COSMETIC_BUNDLES` uses the 12 IDs and names from the approved design and defines all seven slots (`avatar`, `frame`, `background`, `nameGlow`, `chatBubble`, `badge`, `title`).

- [ ] **Step 4: Run the content contract**

Run: `node tools/research_content_contract_test.mjs`

Expected: `research content contract: ok`.

- [ ] **Step 5: Commit the content boundary**

```bash
git add web/landing/study/research-content.mjs tools/research_content_contract_test.mjs
git commit -m "feat: define matched research content"
```

### Task 2: Separate research and account migrations

**Files:**
- Create: `research_migrations/0001_research_program.sql`
- Create: `migrations/0012_research_reward_inventory.sql`
- Create: `tools/research_migration_contract_test.mjs`
- Modify: `wrangler.jsonc` D1 bindings

**Interfaces:**
- `RESEARCH_DB` tables: `research_participants`, `research_responses`, `research_events`, `research_reward_offers`, `research_reward_issuances`.
- `DB` tables: `research_reward_claims`, `user_cosmetic_inventory`; add `study_prestige_level` and seven selected cosmetic columns to `user_profiles`. Preserve the legacy integer `avatar_id` column and its 1-8 constraint for existing users.
- No cross-database foreign keys.

- [ ] **Step 1: Write the failing migration contract**

```js
// tools/research_migration_contract_test.mjs
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const research = await readFile(new URL("../research_migrations/0001_research_program.sql", import.meta.url), "utf8");
const account = await readFile(new URL("../migrations/0012_research_reward_inventory.sql", import.meta.url), "utf8");
for (const table of ["research_participants", "research_responses", "research_events", "research_reward_offers", "research_reward_issuances"]) {
  assert.match(research, new RegExp(`CREATE TABLE IF NOT EXISTS ${table}`));
}
assert.match(research, /route_arm TEXT NOT NULL CHECK\(route_arm IN \('archive_text', 'field_gameplay'\)\)/);
assert.doesNotMatch(research, /username|email|user_agent|ip_address|account_id/i);
assert.match(account, /CREATE TABLE IF NOT EXISTS research_reward_claims/);
assert.match(account, /CREATE TABLE IF NOT EXISTS user_cosmetic_inventory/);
assert.doesNotMatch(account, /route_arm|responses_json|score|question_form/i);
console.log("research migrations: ok");
```

- [ ] **Step 2: Run it and confirm both migration files are missing**

Run: `node tools/research_migration_contract_test.mjs`

Expected: FAIL with `ENOENT`.

- [ ] **Step 3: Provision and bind the isolated research database**

Run `npx wrangler d1 create pixel-observatory-research`, then copy the returned real `database_id` into a second `d1_databases` object in `wrangler.jsonc` with binding `RESEARCH_DB` and `migrations_dir` `research_migrations`. Do not commit a fabricated or zero UUID.

- [ ] **Step 4: Implement `research_migrations/0001_research_program.sql`**

Use `participant_id` plus a salted `study_token_hash`; store route arm, `current_node`, `completed_nodes_json`, `defer_counts_json`, `late_response_count`, `cross_exposed`, `withdrawn_at`, timestamps, and consent version. `research_responses` has `UNIQUE(participant_id, node_id)`. Reward offers have `UNIQUE(participant_id, node_id)` and store exactly three candidate bundle IDs. Issuances have a unique `receipt_hash`, selected bundle ID, and `claimed_at`, but no account identifier.

- [ ] **Step 5: Implement `migrations/0012_research_reward_inventory.sql`**

Use additive `ALTER TABLE` statements so existing profile rows and the legacy `avatar_id` check remain untouched. Add `study_prestige_level INTEGER NOT NULL DEFAULT 0`, `selected_avatar TEXT NOT NULL DEFAULT 'legacy-1'`, `selected_frame`, `selected_background`, `selected_name_glow`, `selected_chat_bubble`, `selected_badge`, and `selected_research_title`. Create unique inventory and receipt-claim rows keyed by `user_id + bundle_id` and `receipt_id` respectively.

- [ ] **Step 6: Run migration contracts and apply both databases locally**

```powershell
node tools/research_migration_contract_test.mjs
npx wrangler d1 migrations apply pixel-observatory --local
npx wrangler d1 migrations apply pixel-observatory-research --local
```

Expected: contract prints `research migrations: ok`; both migration commands exit 0.

- [ ] **Step 7: Commit the storage split**

```bash
git add research_migrations/0001_research_program.sql migrations/0012_research_reward_inventory.sql tools/research_migration_contract_test.mjs wrangler.jsonc
git commit -m "feat: separate research and reward storage"
```

### Task 3: Pure research-state functions

**Files:**
- Create: `cloudflare/research-program.mjs`
- Create: `tools/research_program_unit_test.mjs`
- Modify: `cloudflare/worker.mjs:18-40` (remove old sequential study constants and import the module)

**Interfaces:**
- Produces: `assignRoute(randomUint32): "archive_text"|"field_gameplay"`.
- Produces: `selectQuestionForm(participantId, nodeId): QuestionForm` and `orderedQuestions(participantId, form): PublicQuestion[]` with no `correctOptionId`.
- Produces: `scoreAnswers(form, answers): {score,maxScore}`.
- Produces: `nextResearchNode(routeArm, completedNodes): NodeId|null`.
- Produces: `buildRewardCandidates(ownedBundleIds, seed): [string,string,string]`.
- Produces: `publicResearchState(row, responseRows, offerRow): ResearchState`.

- [ ] **Step 1: Write deterministic unit tests**

```js
import assert from "node:assert/strict";
import { assignRoute, buildRewardCandidates, orderedQuestions, scoreAnswers, selectQuestionForm } from "../cloudflare/research-program.mjs";
assert.equal(assignRoute(0), "archive_text");
assert.equal(assignRoute(0xffffffff), "field_gameplay");
const form = selectQuestionForm("STUDY-UNITTEST01", "A");
assert.equal(form.questions.length, 3);
assert.deepEqual(selectQuestionForm("STUDY-UNITTEST01", "A"), form);
const publicQuestions = orderedQuestions("STUDY-UNITTEST01", form);
assert.ok(publicQuestions.every(question => !("correctOptionId" in question)));
assert.deepEqual(orderedQuestions("STUDY-UNITTEST01", form), publicQuestions);
assert.deepEqual(scoreAnswers(form, Object.fromEntries(form.questions.map(q => [q.id, q.correctOptionId]))), {score: 3, maxScore: 3});
const candidates = buildRewardCandidates(["R01", "R02"], "STUDY-UNITTEST01:A");
assert.equal(candidates.length, 3);
assert.ok(candidates.every(id => !["R01", "R02"].includes(id)));
assert.equal(new Set(candidates).size, 3);
```

- [ ] **Step 2: Run and confirm module-not-found**

Run: `node tools/research_program_unit_test.mjs`

Expected: FAIL with `ERR_MODULE_NOT_FOUND`.

- [ ] **Step 3: Implement deterministic hashing and state transitions**

Use Web Crypto SHA-256 for participant/form/order seeds. `assignRoute` must be the only nondeterministic operation and receives four bytes from `crypto.getRandomValues`. Do not accept a route arm from any request body. Strip answers and scoring keys from public state.

- [ ] **Step 4: Run unit and content tests**

Run: `node tools/research_program_unit_test.mjs && node tools/research_content_contract_test.mjs`

Expected: both print `ok`.

- [ ] **Step 5: Commit the research domain module**

```bash
git add cloudflare/research-program.mjs cloudflare/worker.mjs tools/research_program_unit_test.mjs
git commit -m "feat: add anonymous research state model"
```

### Task 4: Anonymous research API

**Files:**
- Modify: `cloudflare/worker.mjs:1836-2077` (replace legacy study handlers and routes)
- Create: `tools/research_worker_integration_test.mjs`

**Interfaces:**
- `POST /api/research/enroll` `{consent:true,language}` -> `{participantId,token,state}`; `state.routeArm` is omitted until baseline submission.
- `POST /api/research/session` `{participantId,token}` -> `{state}`.
- `POST /api/research/submit` `{participantId,token,nodeId,answers,durationSeconds,lateResponse}` -> `{state,feedback,rewardOffer}`.
- `POST /api/research/defer` `{participantId,token,nodeId}` -> `{state,deferCount}`.
- `POST /api/research/exposure` `{participantId,token,kind:"ordinary_game"}` -> `{state}`.
- `POST /api/research/withdraw` authenticates the anonymous session and marks it withdrawn.
- `POST /api/research/reward/choose` `{participantId,token,offerId,bundleId}` -> `{receiptToken,bundleId,prestigeLevel}`.

- [ ] **Step 1: Write the worker integration test**

The test must enroll 40 new participants, verify route arm is hidden before baseline, verify a forged `routeArm` body is ignored, submit baseline for all participants, verify both server arms are represented, reject duplicate submission, defer node A twice, tag a late A submission, mark a text participant cross-exposed, choose one of three offered bundles, reject a non-offered bundle, and prove the same deterministic opaque receipt can be returned on a retry but claimed only once.

```js
const enrolled = await Promise.all(Array.from({length: 40}, () => post("/api/research/enroll", {consent: true, language: "en", routeArm: "field_gameplay"})));
const sample = enrolled[0];
assert.equal(sample.state.currentNode, "baseline");
assert.equal(sample.state.routeArm, undefined);
assert.equal(sample.state.questions.length, 3);
assert.ok(sample.state.questions.every(question => question.options.length === 4));
const assigned = await Promise.all(enrolled.map(row => submitFirstOptions(row, "baseline")));
assert.ok(assigned.some(row => row.state.routeArm === "archive_text"));
assert.ok(assigned.some(row => row.state.routeArm === "field_gameplay"));
```

- [ ] **Step 2: Run against local Wrangler and confirm 404 responses**

Terminal 1: `npx wrangler dev --local --port 8791`

Terminal 2: `$env:RESEARCH_TEST_URL='http://127.0.0.1:8791'; node tools/research_worker_integration_test.mjs`

Expected: FAIL because `/api/research/enroll` does not exist.

- [ ] **Step 3: Replace legacy handlers with the exact API above**

Use `env.RESEARCH_DB` for every participant, response, event, offer, and issuance query. Keep the existing account `env.DB` out of these handlers. Wrap duplicate-sensitive inserts with D1 uniqueness constraints and return stable `409` codes: `research_node_submitted`, `reward_offer_consumed`, and `bundle_not_offered`. Rate-limit enroll, submit, defer, and choose with the existing `rateLimit` helper but record rate-limit counters only in the operational account DB; its subject hash must not contain participant answers or route arm.

- [ ] **Step 4: Run integration and legacy worker tests**

```powershell
$env:RESEARCH_TEST_URL='http://127.0.0.1:8791'; node tools/research_worker_integration_test.mjs
$env:PLAYTIME_TEST_URL='http://127.0.0.1:8791'; node tools/playtime_worker_integration_test.mjs
```

Expected: research test prints `ok`; playtime integration still passes.

- [ ] **Step 5: Commit the API**

```bash
git add cloudflare/worker.mjs tools/research_worker_integration_test.mjs
git commit -m "feat: expose anonymous matched-study api"
```

### Task 5: Rebuild `/study/` as the text-arm and session controller

**Files:**
- Modify: `web/landing/study/index.html:1-end`
- Modify: `web/landing/study/study.js:1-end`
- Modify: `web/landing/study/study.css:1-end`
- Create: `tools/research_study_page_contract_test.mjs`
- Create: `tools/playwright_research_text_route.mjs`

**Interfaces:**
- Consumes the Task 4 endpoints and `TEXT_ARCHIVE_MODULES` from `research-content.mjs`.
- Produces local session key `pixel-observatory:research-session:v2` with only `{participantId,token,language,noRemindSessionNodes}`.
- A fresh `/study/` visit creates a local pre-study ID and launches the isolated full Godot introduction plus Level 1; it does not show consent or baseline before Level 1 is complete.
- Emits `po:research-reward-offer` with `{offerId,nodeId,candidates}`; reward rendering is added in Plan 3.

- [ ] **Step 1: Write the page contract test**

```js
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const source = await readFile(new URL("../web/landing/study/study.js", import.meta.url), "utf8");
assert.match(source, /pixel-observatory:research-session:v2/);
assert.match(source, /TEXT_ARCHIVE_MODULES/);
assert.match(source, /\/api\/research\/submit/);
assert.match(source, /\/api\/research\/defer/);
assert.match(source, /noRemindSessionNodes/);
assert.doesNotMatch(source, /renderMiniGame|miniState|reading_posttest|STUDY_MIN_GAME_SECONDS/);
```

- [ ] **Step 2: Run it and confirm it fails on the old study page**

Run: `node tools/research_study_page_contract_test.mjs`

Expected: FAIL on the new session key or `TEXT_ARCHIVE_MODULES` assertion.

- [ ] **Step 3: Replace the old sequential and mini-game code**

Render: a fresh-entry explanation with `Start from the opening`; restored assigned session; five text modules; three-question node survey; defer; no-more-reminders-for-session; settings re-enable; completion; withdrawal. The fresh-entry action opens `/game/?mode=study&research_intro=1&participant=<local-prestudy-id>&study_reset=<timestamp>` so the original opening and Level 1 run before the in-game invitation. Consent, baseline, and route reveal are rendered by the game overlay in Plan 2. Do not render the corresponding playable simulation in `archive_text`. If a text participant follows a normal `/game/` link before E is complete, call `/api/research/exposure` first and show a concise notice that their record remains usable but is excluded from the primary comparison.

- [ ] **Step 4: Implement the Playwright route test**

Test a fresh visit and an assigned `archive_text` participant. Verify English default, Chinese toggle, fresh entry launches the Godot opening at Level 1, no consent/baseline is rendered before that level, module A text appears only after assigned session restoration, exactly three questions, defer count, session no-remind setting, settings re-enable, keyboard focus, mobile 390x844 layout, and withdrawal confirmation.

- [ ] **Step 5: Run page tests**

```powershell
node tools/research_study_page_contract_test.mjs
node tools/playwright_research_text_route.mjs
```

Expected: both exit 0 and write screenshots to `artifacts/research/text-route-desktop.png` and `artifacts/research/text-route-mobile.png`.

- [ ] **Step 6: Run the complete plan test set**

```powershell
node tools/research_content_contract_test.mjs
node tools/research_migration_contract_test.mjs
node tools/research_program_unit_test.mjs
node tools/research_study_page_contract_test.mjs
node tools/playwright_research_text_route.mjs
```

Expected: all commands exit 0.

- [ ] **Step 7: Commit the text route**

```bash
git add web/landing/study/index.html web/landing/study/study.js web/landing/study/study.css tools/research_study_page_contract_test.mjs tools/playwright_research_text_route.mjs artifacts/research/text-route-desktop.png artifacts/research/text-route-mobile.png
git commit -m "feat: add optional text-only research route"
```
