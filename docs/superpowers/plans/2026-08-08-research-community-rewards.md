# Research Community Rewards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn each completed research questionnaire into a lavish, participation-only choice of one of 12 exclusive cosmetic bundles, usable by guests immediately and merged exactly once into an account after login.

**Architecture:** The anonymous research database creates a three-choice offer and an opaque one-time receipt. The account database validates that receipt through a cross-binding Worker handler, stores only the receipt ID and selected bundle, and exposes inventory/equipment through the existing social profile API. Guests keep encrypted-by-origin opaque receipts and local equipment state until authentication; `account.js` triggers idempotent claim/merge after login or registration.

**Tech Stack:** Cloudflare Worker/D1, vanilla JavaScript/CSS, existing social/account/game-loader modules, generated WebP atlases, Canvas/CSS motion, Node integration tests, Playwright visual tests.

## Global Constraints

- Rewards are granted for questionnaire completion, never answer correctness.
- Baseline and nodes A-E each grant one offer, for a maximum of six research prestige levels.
- Each offer contains exactly three unowned bundle choices; the chosen bundle cannot repeat for that participant.
- Each bundle includes avatar, avatar frame, profile background, name glow, chat bubble, badge, and title.
- The 12 bundle IDs and names are fixed: `R01 Solar Crown`, `R02 Lunar Archive`, `R03 Nebula Weaver`, `R04 Aurora Navigator`, `R05 Pulsar Herald`, `R06 Event Horizon`, `R07 Deep Sky Cartographer`, `R08 Infrared Alchemist`, `R09 Radio Sentinel`, `R10 Mirror Master`, `R11 Sidereal Voyager`, `R12 Observatory Laureate`.
- Cosmetics confer no gameplay or leaderboard advantage. Research prestige is visually separate from playtime/community rank.
- Guests can preview, choose, equip, and retain receipts locally. Registration/login merges each receipt exactly once without deleting normal profile data.
- Account storage must not contain route arm, answers, scores, question form, or anonymous participant ID.
- The reveal lasts 6-8 seconds at normal motion, is safely skippable/accelerable, and has a reduced-motion path under 500 ms.
- Use generated bitmap artwork for the 12 portraits and profile backgrounds; do not replace them with programmer-drawn placeholder geometry.

---

### Task 1: Produce and verify the 12 cosmetic art sets

**Files:**
- Create: `source_assets/research_rewards/research_reward_avatars.png`
- Create: `source_assets/research_rewards/research_reward_backgrounds.png`
- Create: `source_assets/research_rewards/research_reward_frames.png`
- Create: `web/landing/assets/research-reward-avatars.webp`
- Create: `web/landing/assets/research-reward-backgrounds.webp`
- Create: `web/landing/assets/research-reward-frames.webp`
- Create: `web/landing/assets/research-reward-atlas.json`
- Create: `tools/research_reward_asset_contract_test.mjs`

**Interfaces:**
- Each atlas is a 4x3 grid in bundle-ID order R01-R12.
- Avatar cells are square, frame cells have alpha, background cells are 16:9.
- `research-reward-atlas.json` exposes `{version, columns:4, rows:3, bundles:{R01:{avatar,frame,background},...}}` with normalized crop rectangles.

- [ ] **Step 1: Write the failing asset contract**

```js
import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
const atlas = JSON.parse(await readFile(new URL("../web/landing/assets/research-reward-atlas.json", import.meta.url), "utf8"));
assert.equal(atlas.columns, 4);
assert.equal(atlas.rows, 3);
assert.deepEqual(Object.keys(atlas.bundles), Array.from({length: 12}, (_, i) => `R${String(i + 1).padStart(2, "0")}`));
for (const file of ["research-reward-avatars.webp", "research-reward-backgrounds.webp", "research-reward-frames.webp"]) {
  const info = await stat(new URL(`../web/landing/assets/${file}`, import.meta.url));
  assert.ok(info.size > 20_000, `${file} contains real artwork`);
  assert.ok(info.size < 2_500_000, `${file} is web-sized`);
}
```

- [ ] **Step 2: Run and confirm the atlas files are absent**

Run: `node tools/research_reward_asset_contract_test.mjs`

Expected: FAIL with `ENOENT`.

- [ ] **Step 3: Generate three coherent source atlases with the image-generation tool**

Use this exact visual brief for all three assets, changing only the final asset-type sentence:

```text
Create a premium 4 by 3 sprite atlas for Pixel Observatory, a pixel-realistic astronomy education game. Twelve clearly separated cells, no text, no logos, no UI screenshots, no duplicate designs. Dark navy observatory materials, brass and silver instrument details, cyan scientific light, restrained spectral accents, crisp readable silhouettes, consistent camera and lighting. Row-major themes: Solar Crown, Lunar Archive, Nebula Weaver, Aurora Navigator, Pulsar Herald, Event Horizon, Deep Sky Cartographer, Infrared Alchemist, Radio Sentinel, Mirror Master, Sidereal Voyager, Observatory Laureate. The result must feel rare, scholarly, astronomical, and celebratory rather than fantasy armor. [For avatars: one centered observer portrait per square cell.] [For frames: one transparent ornate portrait frame per square cell, empty center.] [For backgrounds: one wide profile-banner environment per 16:9 cell.] No random writing.
```

Visually inspect every atlas before accepting it. Reject any atlas with text, merged cells, clipped faces, repeated themes, or opaque frame centers.

- [ ] **Step 4: Convert, crop-map, and size the atlases**

Use `ffmpeg` or `cwebp` to create visually lossless WebP outputs. Record exact normalized cells in `research-reward-atlas.json`. Preserve sources under `source_assets/research_rewards/`; do not load source PNGs on the website.

- [ ] **Step 5: Run asset contract and inspect individual crops**

```powershell
node tools/research_reward_asset_contract_test.mjs
ffmpeg -i web/landing/assets/research-reward-avatars.webp -vf "crop=iw/4:ih/3:0:0" artifacts/research/reward-r01-avatar.png -y
ffmpeg -i web/landing/assets/research-reward-frames.webp -vf "crop=iw/4:ih/3:3*iw/4:2*ih/3" artifacts/research/reward-r12-frame.png -y
```

Expected: contract passes; R01 and R12 crops are correctly framed and contain no neighboring cell.

- [ ] **Step 6: Commit approved artwork**

```bash
git add source_assets/research_rewards web/landing/assets/research-reward-*.webp web/landing/assets/research-reward-atlas.json tools/research_reward_asset_contract_test.mjs artifacts/research/reward-r01-avatar.png artifacts/research/reward-r12-frame.png
git commit -m "art: add research-exclusive observatory cosmetics"
```

### Task 2: One-time reward claim API

**Files:**
- Modify: `cloudflare/worker.mjs` near social profile handlers `1239-1365` and research routes `1836-2077`
- Modify: `cloudflare/research-program.mjs`
- Create: `tools/research_reward_worker_integration_test.mjs`

**Interfaces:**
- `POST /api/research/reward/claim` requires account session and body `{receiptToken}`; returns `{claimed,bundleId,prestigeLevel,inventory}`.
- `GET /api/social/cosmetics` returns `{inventory,equipped,studyPrestigeLevel}`.
- `PATCH /api/social/cosmetics` accepts `{avatar,frame,background,nameGlow,chatBubble,badge,title}` and rejects unowned bundle parts.
- Receipt lookup uses `RESEARCH_DB`; account claim/inventory writes use `DB`.

- [ ] **Step 1: Write the failing claim integration test**

The test creates a research participant, submits baseline, chooses a bundle, registers an account, claims once, retries the same token, verifies prestige increments only once, attempts to equip an unowned frame and receives `403 cosmetic_not_owned`, equips the earned bundle, and checks `/api/social/profile` contains the equipped appearance but not participant, route, answer, score, or form fields.

```js
const first = await accountPost("/api/research/reward/claim", {receiptToken}, cookie);
assert.equal(first.claimed, true);
const retry = await accountPost("/api/research/reward/claim", {receiptToken}, cookie);
assert.equal(retry.claimed, false);
assert.equal(retry.prestigeLevel, first.prestigeLevel);
const profile = await accountGet("/api/social/profile", cookie);
assert.equal(profile.profile.studyPrestigeLevel, 1);
assert.ok(!JSON.stringify(profile).match(/participant|routeArm|score|answers|questionForm/i));
```

- [ ] **Step 2: Run against local Wrangler and confirm the claim endpoint is absent**

Run: `$env:RESEARCH_TEST_URL='http://127.0.0.1:8791'; node tools/research_reward_worker_integration_test.mjs`

Expected: FAIL with 404 for `/api/research/reward/claim`.

- [ ] **Step 3: Implement idempotent cross-database claiming**

Hash the opaque token, fetch an unclaimed or previously-issued receipt from `RESEARCH_DB`, then insert `research_reward_claims` and `user_cosmetic_inventory` in an account-DB batch with unique constraints. Mark `research_reward_issuances.claimed_at` afterward. On retry, return the existing account claim and attempt the research mark again. Never write account ID into `RESEARCH_DB`. Never include assignment or response metadata in the receipt token.

- [ ] **Step 4: Implement inventory reads and ownership-checked equipment writes**

Expand `publicProfile` to expose the seven selected cosmetic IDs and `studyPrestigeLevel` while preserving `rankForSeconds` unchanged. Legacy avatars map to `legacy-1` through `legacy-8`; users without research inventory see the current profile unchanged.

- [ ] **Step 5: Run reward, profile, and playtime integrations**

```powershell
$env:RESEARCH_TEST_URL='http://127.0.0.1:8791'; node tools/research_reward_worker_integration_test.mjs
$env:PLAYTIME_TEST_URL='http://127.0.0.1:8791'; node tools/playtime_worker_integration_test.mjs
```

Expected: both pass; playtime rank remains based only on `play_seconds`.

- [ ] **Step 6: Commit the claim API**

```bash
git add cloudflare/worker.mjs cloudflare/research-program.mjs tools/research_reward_worker_integration_test.mjs
git commit -m "feat: claim research cosmetics idempotently"
```

### Task 3: Guest reward vault and login merge

**Files:**
- Create: `web/landing/research-rewards.js`
- Modify: `web/landing/account.js:130-210`
- Modify: `web/landing/game-loader.js:800-990`
- Modify: `web/landing/social.js:73-83,459-617`
- Create: `tools/research_guest_reward_contract_test.mjs`

**Interfaces:**
- Local keys: `pixel-observatory:research-receipts:v1` stores opaque receipt strings; `pixel-observatory:research-equipped:v1` stores seven selected cosmetic IDs.
- `window.PixelObservatoryRewards.present(offer)` opens the choice/reveal flow.
- `window.PixelObservatoryRewards.claimPending()` runs after `po:session-changed` and returns `{claimed,remaining}`.
- Emits `po:research-cosmetics-changed` after local or server equipment changes.

- [ ] **Step 1: Write the failing guest contract**

```js
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const rewards = await readFile(new URL("../web/landing/research-rewards.js", import.meta.url), "utf8");
const account = await readFile(new URL("../web/landing/account.js", import.meta.url), "utf8");
assert.match(rewards, /research-receipts:v1/);
assert.match(rewards, /research-equipped:v1/);
assert.match(rewards, /claimPending/);
assert.match(rewards, /po:research-cosmetics-changed/);
assert.match(account, /PixelObservatoryRewards.*claimPending/);
```

- [ ] **Step 2: Run and confirm the guest module is absent**

Run: `node tools/research_guest_reward_contract_test.mjs`

Expected: FAIL with `ENOENT`.

- [ ] **Step 3: Implement guest storage and merge**

After a choice, store the receipt before playing any animation, immediately equip the bundle locally, and show a non-blocking note that creating/signing into an account will preserve it across devices. On session change, claim pending receipts sequentially, remove only acknowledged receipts, preserve failed receipts for retry, fetch canonical inventory, and resolve local/server equipment by keeping the newest explicitly selected owned part.

- [ ] **Step 4: Update avatar and profile rendering**

Keep the existing 8-avatar sprite sheet for legacy users. For `R01-R12`, use atlas crop CSS variables from `research-reward-atlas.json`, layer the generated frame over the avatar, apply selected profile background to the header only, and apply glow/chat/title styles without changing card dimensions. Add a small `Research Prestige · N` line separate from playtime rank.

- [ ] **Step 5: Run contract and existing social tests**

```powershell
node tools/research_guest_reward_contract_test.mjs
node tools/web_friend_messaging_test.mjs
```

Expected: both pass.

- [ ] **Step 6: Commit guest migration**

```bash
git add web/landing/research-rewards.js web/landing/account.js web/landing/game-loader.js web/landing/social.js tools/research_guest_reward_contract_test.mjs
git commit -m "feat: preserve guest research rewards on login"
```

### Task 4: Seven-second reward reveal and equipment UI

**Files:**
- Create: `web/landing/research-rewards.css`
- Modify: `web/landing/research-rewards.js`
- Modify: `web/landing/social.css:294-332,495-499`
- Modify: `web/landing/social.js:550-604`
- Modify: `web/landing/study/index.html` stylesheet/script includes
- Modify: `tools/build_web_shell.mjs` stylesheet/script injection
- Create: `tools/playwright_research_reward_reveal.mjs`

**Interfaces:**
- Reveal phases: `choice` -> `seal` (0.8 s) -> `constellation` (1.6 s) -> `portrait` (1.8 s) -> `bundle` (1.6 s) -> `prestige` (1.2 s), total 7.0 s.
- `Skip reveal` jumps to committed `bundle`; pressing Enter accelerates to 2.0x without issuing a second receipt.
- `prefers-reduced-motion: reduce` renders the final bundle in under 500 ms.

- [ ] **Step 1: Write the Playwright state test**

Stub reward choose/claim endpoints. Verify exactly three cards, only one can be selected, receipt request fires once on repeated clicks, the selected art appears, seven slots are listed, prestige increments, skip lands on final state, Enter acceleration does not duplicate claim, reduced motion finishes under 500 ms, and a 390x844 viewport has no clipped action.

- [ ] **Step 2: Run and capture the plain/absent reveal failure**

Run: `node tools/playwright_research_reward_reveal.mjs`

Expected: FAIL because `PixelObservatoryRewards.present` or reveal DOM is absent.

- [ ] **Step 3: Implement the liquid-glass choice stage**

Use the project `apple-design` skill principles: a translucent backdrop that preserves readable contrast, one continuous highlight tracking pointer position, spring easing only on direct interaction, 8 px-or-less card radius unless the existing community modal requires 12 px, and no blur over body copy. Three bundle cards share stable dimensions and use generated bitmap artwork as their first signal.

- [ ] **Step 4: Implement the committed reveal timeline**

After the server confirms choice, animate a compact observatory seal, a real Canvas star/constellation field, the portrait+frame, then seven slot labels and prestige. Use Web Audio only for an original synthesized two-note observatory chime; no copyrighted audio file. Make the final screen persistent until dismissed.

- [ ] **Step 5: Add profile equipment controls**

Replace the old 8-item avatar-only picker with owned-slot tabs: Portrait, Frame, Background, Glow, Bubble, Badge, Title. Keep unowned research bundles visible only as silhouettes labelled `Research reward`, never purchasable. Save with `PATCH /api/social/cosmetics` and update all open profile/friend/message views from the emitted event.

- [ ] **Step 6: Run visual and regression tests**

```powershell
node tools/playwright_research_reward_reveal.mjs
node tools/playwright_friend_direct_route.js
node tools/playwright_game_social_rail.js
```

Expected: all exit 0; screenshots at `artifacts/research/reward-choice.png`, `reward-reveal.png`, `reward-mobile.png`, and `reward-reduced-motion.png` show no overlap or unreadable blur.

- [ ] **Step 7: Commit reveal and equipment UI**

```bash
git add web/landing/research-rewards.css web/landing/research-rewards.js web/landing/social.css web/landing/social.js web/landing/study/index.html tools/build_web_shell.mjs tools/playwright_research_reward_reveal.mjs artifacts/research/reward-*.png
git commit -m "feat: celebrate and equip research rewards"
```

### Task 5: Complete reward regression gate

**Files:**
- Modify: `.github/workflows/deploy-web.yml` test step
- Modify: `tools/web_shell_contract_test.mjs`

**Interfaces:**
- CI runs asset, guest, and Worker source contracts; local release gate runs Worker integration and Playwright.

- [ ] **Step 1: Add build-shell assertions**

```js
assert.match(indexHtml, /research-rewards\.css/);
assert.match(indexHtml, /research-rewards\.js/);
assert.ok(await exists(join(webRoot, "assets/research-reward-avatars.webp")));
assert.ok(await exists(join(webRoot, "assets/research-reward-backgrounds.webp")));
assert.ok(await exists(join(webRoot, "assets/research-reward-frames.webp")));
```

- [ ] **Step 2: Run and confirm the current web build omits reward assets**

Run: `node tools/web_shell_contract_test.mjs`

Expected: FAIL on one new reward assertion before rebuilding.

- [ ] **Step 3: Add stable contracts to CI and rebuild**

Add `research_reward_asset_contract_test.mjs` and `research_guest_reward_contract_test.mjs` to the existing web-shell test block, then run the normal export/shell build so the three WebP atlases and two reward modules are present.

- [ ] **Step 4: Run the plan-wide gate**

```powershell
node tools/research_reward_asset_contract_test.mjs
node tools/research_guest_reward_contract_test.mjs
node tools/web_shell_contract_test.mjs
$env:RESEARCH_TEST_URL='http://127.0.0.1:8791'; node tools/research_reward_worker_integration_test.mjs
node tools/playwright_research_reward_reveal.mjs
```

Expected: every command exits 0.

- [ ] **Step 5: Commit the regression gate**

```bash
git add .github/workflows/deploy-web.yml tools/web_shell_contract_test.mjs
git commit -m "test: gate research reward delivery"
```
