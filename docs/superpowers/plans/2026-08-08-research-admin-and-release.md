# Research Admin and Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the administrator privacy-safe research summaries and analysis-ready CSV export, then independently verify both study arms, reward migration, responsive gameplay, database isolation, and production release.

**Architecture:** Admin endpoints join only tables inside `RESEARCH_DB` and return descriptive aggregates or pseudonymous item-level CSV. The existing account-role middleware protects the UI and endpoints, but account identifiers are never joined into research rows. Release uses a separately provisioned D1 database, applies account and research migrations independently, exports/backups before mutation, builds the existing custom Godot shell, publishes manually through Wrangler, and verifies cold-cache production behavior.

**Tech Stack:** Cloudflare Worker/D1, vanilla admin UI, Node integration tests, Playwright, Godot 4.7 headless/export, Wrangler CLI, Git.

## Global Constraints

- Only authenticated `role = admin` users may access research summary or CSV endpoints.
- Summary and export contain no username, email, account ID, IP address, raw user agent, device fingerprint, receipt token, or session token.
- CSV may contain only a stable anonymous `study_code`, route arm, node/form/question IDs, selected option ID, correctness, duration, late/cross-exposure flags, and timestamps.
- Primary descriptive metrics exclude `late_response = 1`, `cross_exposed = 1`, and withdrawn records; secondary counts show how many rows were excluded and why.
- The dashboard reports observed completion and score distributions. It must not claim that the game caused learning improvement.
- Existing feedback, mailbox, community, cloud saves, friends, moderation, playtime, and leaderboard behavior must remain operational.
- Do not deploy until local migrations, Worker integrations, Godot headless tests, shell verification, Playwright viewports, and privacy scans all pass.
- Commits use the repository's existing `tntsg1 <tntsgxiaodi@outlook.com>` identity with no Codex co-author trailer.
- Never clean, reset, or overwrite `E:\godot\ai-game-0628`; release from the isolated feature worktree only.

---

### Task 1: Privacy-safe research summary and CSV endpoints

**Files:**
- Modify: `cloudflare/worker.mjs:2039-2077` (replace legacy admin study export and add routes)
- Create: `tools/research_admin_worker_integration_test.mjs`

**Interfaces:**
- `GET /api/admin/research/summary` -> `{version,participants,arms,nodes,exclusions,rewards}`.
- `GET /api/admin/research/export.csv` -> UTF-8 CSV with header `study_code,route_arm,node_id,form_id,question_id,selected_option_id,is_correct,duration_seconds,late_response,cross_exposed,submitted_at`.
- Both use the existing authenticated admin guard and query only `env.RESEARCH_DB` after authorization.

- [ ] **Step 1: Write the failing admin integration test**

```js
const unauthenticated = await fetch(`${baseUrl}/api/admin/research/summary`);
assert.equal(unauthenticated.status, 401);
const normalUser = await requestRaw("/api/admin/research/summary", {}, userCookie);
assert.equal(normalUser.status, 403);
const summary = await requestJson("/api/admin/research/summary", {}, adminCookie);
assert.ok(summary.arms.archive_text.participants >= 1);
assert.ok(summary.arms.field_gameplay.participants >= 1);
assert.ok(summary.nodes.every(node => ["baseline", "A", "B", "C", "D", "E"].includes(node.id)));
const csv = await requestText("/api/admin/research/export.csv", {}, adminCookie);
assert.match(csv, /^study_code,route_arm,node_id,form_id,question_id,/);
assert.doesNotMatch(csv, /username|email|account_id|ip_address|user_agent|receipt_token/i);
```

- [ ] **Step 2: Run against local Wrangler and confirm 404**

Run: `$env:RESEARCH_TEST_URL='http://127.0.0.1:8791'; node tools/research_admin_worker_integration_test.mjs`

Expected: FAIL because the new admin endpoints are absent.

- [ ] **Step 3: Implement summary queries**

Return participant counts by arm/status, completion and mean/median score by node and arm, deferral counts, late and cross-exposed exclusions, and reward offer/choice/claim counts. Calculate the primary cohort with SQL predicates for not withdrawn, not cross-exposed, and no late response at the reported node. Label every metric as descriptive.

- [ ] **Step 4: Implement item-level CSV**

Expand each stored response into three rows in JavaScript using its canonical form. Quote every field with a CSV helper and prefix the UTF-8 response with BOM for Excel. `study_code` is a one-way SHA-256 prefix of participant ID plus an admin-only export salt, not the raw participant ID.

- [ ] **Step 5: Run admin and privacy integration tests**

```powershell
$env:RESEARCH_TEST_URL='http://127.0.0.1:8791'; node tools/research_admin_worker_integration_test.mjs
$env:RESEARCH_TEST_URL='http://127.0.0.1:8791'; node tools/research_worker_integration_test.mjs
```

Expected: both pass.

- [ ] **Step 6: Commit admin APIs**

```bash
git add cloudflare/worker.mjs tools/research_admin_worker_integration_test.mjs
git commit -m "feat: export anonymous research metrics"
```

### Task 2: Administrator research dashboard

**Files:**
- Modify: `web/landing/admin/index.html`
- Modify: `web/landing/admin/admin.js`
- Modify: `web/landing/admin/admin.css`
- Create: `tools/playwright_research_admin.mjs`

**Interfaces:**
- Adds a `Research` tab beside existing feedback/moderation tools.
- Consumes `/api/admin/research/summary` and `/api/admin/research/export.csv`.
- Produces filter controls for arm, node, and cohort (`primary` or `all observed`).

- [ ] **Step 1: Write the Playwright admin test**

Stub admin session and summary. Verify a non-admin sees no research tab, an admin sees both arm counts, node completion, score distribution, exclusion warning, reward completion, and an enabled CSV download. Test EN/中文 labels and 1024x768/mobile horizontal overflow.

- [ ] **Step 2: Run and confirm the research tab is absent**

Run: `node tools/playwright_research_admin.mjs`

Expected: FAIL on missing `[data-admin-tab="research"]`.

- [ ] **Step 3: Implement the research tab**

Use compact data tables and restrained bars, not marketing cards. The first line reads `Descriptive research summary` / `描述性研究汇总`. Show `Primary cohort` and exclusion counts together so the user cannot mistake all-observed data for the clean comparison. Keep the CSV action in the sticky tab header.

- [ ] **Step 4: Run and capture desktop/mobile evidence**

Run: `node tools/playwright_research_admin.mjs`

Expected: exit 0 and screenshots `artifacts/research/admin-desktop.png` and `admin-mobile.png` show readable labels and no overlap.

- [ ] **Step 5: Commit dashboard**

```bash
git add web/landing/admin/index.html web/landing/admin/admin.js web/landing/admin/admin.css tools/playwright_research_admin.mjs artifacts/research/admin-*.png
git commit -m "feat: add anonymous research dashboard"
```

### Task 3: Full local end-to-end research matrix

**Files:**
- Create: `tools/research_e2e_matrix.mjs`
- Create: `tools/research_privacy_scan.mjs`
- Create: `docs/research/ANALYSIS_CODEBOOK.md`
- Modify: `.gitignore` to exclude local D1 state exports and receipt fixtures if not already covered

**Interfaces:**
- `research_e2e_matrix.mjs` drives real local Worker APIs and built pages for both arms.
- `research_privacy_scan.mjs` scans migrations, Worker responses, CSV headers, localStorage keys, and built static output for prohibited joins/fields.
- Codebook defines every exported column and primary-cohort rule without interpreting outcomes.

- [ ] **Step 1: Write the matrix assertions**

The matrix creates at least four participants per arm, completes baseline plus A-E, varies deferral, late response, withdrawal, and cross exposure, claims rewards as guest then account, retries every submit/choose/claim request, and asserts:

```js
assert.equal(primary.archiveText.completed, 1);
assert.equal(primary.fieldGameplay.completed, 1);
assert.equal(exclusions.withdrawn, 1);
assert.equal(exclusions.crossExposed, 1);
assert.equal(exclusions.lateResponse, 1);
assert.equal(accountClaims.duplicatePrestigeGain, 0);
assert.equal(normalGameSaveChanged, false);
```

- [ ] **Step 2: Write the privacy scan**

Fail if research migrations or API payload snapshots contain `username`, `email`, `account_id`, `ip_address`, `user_agent`, or `device_fingerprint`; fail if account migration/API payload snapshots contain `route_arm`, `responses_json`, `score`, `question_form`, or `participant_id`.

- [ ] **Step 3: Run and confirm gaps before the matrix is implemented**

Run: `node tools/research_e2e_matrix.mjs && node tools/research_privacy_scan.mjs`

Expected: first command fails until the matrix helpers/fixtures are complete.

- [ ] **Step 4: Implement the matrix and codebook**

Use fixed local test accounts and disposable local D1 state. The codebook lists `study_code`, `route_arm`, `node_id`, `form_id`, `question_id`, `selected_option_id`, `is_correct`, `duration_seconds`, `late_response`, `cross_exposed`, and `submitted_at`, plus explicit exclusions and missing-data treatment.

- [ ] **Step 5: Run the local quality gate**

```powershell
node tools/research_e2e_matrix.mjs
node tools/research_privacy_scan.mjs
node tools/research_content_contract_test.mjs
node tools/research_program_unit_test.mjs
node tools/research_study_page_contract_test.mjs
node tools/research_overlay_contract_test.mjs
node tools/research_guest_reward_contract_test.mjs
& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --quit
```

Expected: every command exits 0; no `SCRIPT ERROR`.

- [ ] **Step 6: Commit E2E and documentation**

```bash
git add tools/research_e2e_matrix.mjs tools/research_privacy_scan.mjs docs/research/ANALYSIS_CODEBOOK.md .gitignore
git commit -m "test: verify research cohorts and privacy"
```

### Task 4: Automate the two-database migration workflow

**Files:**
- Create: `tools/apply_research_migrations.mjs`
- Modify: `README.md` deployment section

**Interfaces:**
- Production binding name: `RESEARCH_DB`.
- Production database name: `pixel-observatory-research`.
- Migration directory: `research_migrations`.
- `node tools/apply_research_migrations.mjs --local|--remote` applies account migrations first, research migrations second, and stops on any failure.

- [ ] **Step 1: Add the binding contract to the migration test**

```js
const wrangler = await readFile(new URL("../wrangler.jsonc", import.meta.url), "utf8");
assert.match(wrangler, /"binding": "RESEARCH_DB"/);
assert.match(wrangler, /"database_name": "pixel-observatory-research"/);
assert.match(wrangler, /"migrations_dir": "research_migrations"/);
```

- [ ] **Step 2: Run and confirm the provisioned `RESEARCH_DB` binding from Plan 1 is valid**

Run: `node tools/research_migration_contract_test.mjs`

Expected: PASS and the binding contains the real database ID created in Plan 1.

- [ ] **Step 3: Implement the two-database migration runner**

The script accepts exactly one flag. For `--local`, run both `wrangler d1 migrations apply ... --local`; for `--remote`, first export the account DB and research DB to timestamped files under `build/d1-backups/`, then apply both with `--remote`. Use `spawnSync` argument arrays; never interpolate a shell command string.

- [ ] **Step 4: Apply and verify locally**

```powershell
node tools/apply_research_migrations.mjs --local
npx wrangler d1 execute pixel-observatory-research --local --command "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
```

Expected: output includes all five research tables and no `users` table.

- [ ] **Step 5: Commit the migration workflow**

```bash
git add tools/apply_research_migrations.mjs README.md tools/research_migration_contract_test.mjs
git commit -m "ops: provision isolated research database"
```

### Task 5: Build and regression verification

**Files:**
- Modify: `tools/build_cloudflare_release.mjs` only if new assets are not copied by the existing recursive rule
- Modify: `tools/web_shell_contract_test.mjs`
- Modify: `.github/workflows/deploy-web.yml`
- Create: `docs/research/RELEASE_CHECKLIST.md`

**Interfaces:**
- Release checklist records commit SHA, migration results, all test commands, screenshot paths, deployed URL, and cold-cache headers.

- [ ] **Step 1: Run all existing high-risk regressions before changing release scripts**

```powershell
node tools/web_friend_messaging_test.mjs
node tools/playtime_accounting_test.mjs
node tools/playtime_client_contract_test.mjs
node tools/cloud_save_worker_integration_test.mjs
node tools/study_mini_game_contract_test.mjs
```

Expected: all pass. If one fails before release changes, fix only behavior broken by this feature; record unrelated pre-existing failures without deleting tests.

- [ ] **Step 2: Export Godot and build the custom web shell**

```powershell
node tools/prepare_web_export.mjs
New-Item -ItemType Directory -Force build/web/.godot-export | Out-Null
& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --import
& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --export-release Web build/web/.godot-export/index.html
node tools/build_web_shell.mjs build/web build/web/.godot-export
node tools/verify_web_game_shell.mjs build/web
node tools/build_cloudflare_release.mjs build/web build/cloudflare-public
```

Expected: no default Godot logo/gray shell; `/study/`, research modules, reward atlases, admin assets, PCK route, and WASM route are present as designed.

- [ ] **Step 3: Run all new browser viewports and existing social viewports**

```powershell
node tools/playwright_research_text_route.mjs
node tools/playwright_research_gameplay_route.mjs --viewport=1920x1080
node tools/playwright_research_gameplay_route.mjs --viewport=1024x768
node tools/playwright_research_gameplay_route.mjs --viewport=390x844
node tools/playwright_research_reward_reveal.mjs
node tools/playwright_research_admin.mjs
node tools/playwright_friend_direct_route.js
node tools/playwright_game_social_rail.js
```

Expected: all pass; visual review confirms no overlap, text clipping, unreadable glass blur, blank canvas, or stretched image.

- [ ] **Step 4: Add stable non-Playwright tests to CI**

Add content, migration source, pure-domain, study page, overlay, guest reward, privacy scan, and Godot checkpoint tests to `.github/workflows/deploy-web.yml`. Do not add remote D1 migrations to GitHub Actions; deployment credentials and the user's previously disabled Actions status make migrations an explicit release step.

- [ ] **Step 5: Fill and commit the release checklist**

Record the actual results and artifact paths in `docs/research/RELEASE_CHECKLIST.md`; do not write `pass` before running a command.

```bash
git add tools/build_cloudflare_release.mjs tools/web_shell_contract_test.mjs .github/workflows/deploy-web.yml docs/research/RELEASE_CHECKLIST.md
git commit -m "build: gate in-game research release"
```

### Task 6: Independent review, merge, deploy, and production verification

**Files:**
- No planned source edits; any review fix gets its own focused commit.

**Interfaces:**
- Production URLs: `https://pixelobservatorygame.com/`, `/game/`, `/study/`, `/admin/`.

- [ ] **Step 1: Run the complete local gate from a clean feature worktree**

Run `git status --short` first. It must show no unexplained files. Run every command in Tasks 3 and 5, plus local Worker reward/admin integrations.

- [ ] **Step 2: Request two-stage code review**

Use `superpowers:requesting-code-review`: first verify spec compliance, then code quality. Resolve only concrete findings and rerun the affected test plus the full privacy scan.

- [ ] **Step 3: Back up and migrate production D1 databases**

```powershell
node tools/apply_research_migrations.mjs --remote
```

Expected: timestamped backups exist under `build/d1-backups/`; both migration sets exit 0.

- [ ] **Step 4: Publish static assets, R2 runtime, and Worker**

```powershell
node tools/publish_cloudflare_release.mjs build/web build/cloudflare-public
```

Expected: R2 PCK/WASM uploads and `wrangler deploy` exit 0.

- [ ] **Step 5: Verify production with cache-busting requests**

Open each production URL with `?verify=<current-commit-sha>`. Confirm: custom loading shell (no Godot logo/gray screen); optional invitation after L1; both assigned arms through disposable sessions; survey defer/re-enable; guest reward then account merge; admin summary/CSV access only as admin; ordinary community/playtime still work. Capture screenshots and response headers in `artifacts/research/production/`.

- [ ] **Step 6: Merge and push with user attribution**

Use `superpowers:finishing-a-development-branch`. Preserve the existing author identity, do not add `Co-authored-by`, and push the reviewed commits to `main` only after the production verification commit is ready.

- [ ] **Step 7: Final production audit**

Run the production-safe read-only checks for `/api/research/session` rejection without a token, admin rejection without an admin session, asset 200s, and no-cache HTML SHA. Update `docs/research/RELEASE_CHECKLIST.md` with the deployed commit SHA and commit that evidence if the repository tracks release records.
