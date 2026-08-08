# Godot Research Route Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed optional matched questionnaires into the real Godot Level 1-24 campaign without deleting intros, assembly, navigation, observation, story, or normal-save behavior.

**Architecture:** Godot remains authoritative for level completion and emits narrowly scoped browser events through `JavaScriptBridge`. The existing web game shell listens for those events, opens an accessible overlay, calls the anonymous research API, and returns an explicit continue command to Godot. A separate participant save remains isolated from the normal campaign; the archive-text arm exits the gameplay route after baseline, while the field-gameplay arm proceeds through all original Levels 2-24.

**Tech Stack:** Godot 4.7 GDScript strict mode, JavaScriptBridge custom events, vanilla JS/CSS game shell, Node contract tests, Godot headless runtime tests, Playwright.

## Global Constraints

- Preserve the complete original opening and every required action in Levels 1-24, including assembly, room navigation, targeting, focus, observation, dialogue, and learning cards.
- Do not delete or bypass required installation steps.
- The invitation appears only after Level 1 completion and is optional.
- `archive_text` never enters Levels 2-24 inside the research route; `field_gameplay` continues the original Levels 2-24.
- Survey nodes appear after Levels 6, 11, 16, 21, and 24; baseline appears after Level 1.
- A skipped survey never blocks gameplay. Deferral and session reminder rules come from the research API.
- Normal game saves and research saves remain separate.
- English is the default; the game-shell overlay follows the currently selected game language and supports manual EN/中文 switching.
- GDScript must pass Godot 4.7 strict parsing; no `class_name` is added to autoloads and no float `%` expressions are introduced.
- The browser overlay must be usable at 1920x1080, 1024x768, and 390x844 with keyboard navigation and reduced-motion support.

---

### Task 1: Research route state in GameManager and SaveManager

**Files:**
- Modify: `scripts/systems/game_manager.gd:22-24,185-206,575-612`
- Modify: `scripts/systems/save_manager.gd:7,64-146`
- Modify: `scripts/systems/mission_manager.gd` at `use_campaign_order_subset`
- Modify: `tools/study_campaign_runtime_test.gd:1-end`
- Modify: `tools/study_mini_game_contract_test.mjs:1-end`

**Interfaces:**
- Produces `GameManager.research_route_arm() -> String` returning `""`, `"archive_text"`, or `"field_gameplay"` from query string `research_arm`.
- Produces `GameManager.research_participant_id() -> String`.
- Produces `GameManager.research_node_for_completed_level(level_number: int) -> String` using `1/baseline`, `6/A`, `11/B`, `16/C`, `21/D`, `24/E`.
- Produces `SaveManager.seed_research_level_one_complete() -> bool`, consumed once when `research_seed=l1_complete` is present.
- Preserves `STUDY_CAMPAIGN_ORDER` as all integers 1 through 24.

- [ ] **Step 1: Extend the failing headless contract**

```gdscript
_check(gm.STUDY_CAMPAIGN_ORDER == range(1, 25), "research route contains every level 1-24")
_check(gm.research_node_for_completed_level(1) == "baseline", "L1 maps to baseline")
_check(gm.research_node_for_completed_level(6) == "A", "L6 maps to node A")
_check(gm.research_node_for_completed_level(24) == "E", "L24 maps to node E")
_check(gm.research_node_for_completed_level(5).is_empty(), "non-boundary levels do not open surveys")
```

Add source assertions to `tools/study_mini_game_contract_test.mjs`:

```js
assert.match(gameManager, /func research_route_arm\(\) -> String/);
assert.match(gameManager, /func research_node_for_completed_level\(level_number: int\) -> String/);
assert.match(saveManager, /func seed_research_level_one_complete\(\) -> bool/);
assert.doesNotMatch(gameManager, /\[16,\s*24\]/, "The research route may not skip authored levels.");
```

- [ ] **Step 2: Run and confirm missing-function failures**

```powershell
node tools/study_mini_game_contract_test.mjs
& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://tools/study_campaign_runtime_test.gd
```

Expected: contract fails on `research_route_arm`; Godot test fails on the missing method.

- [ ] **Step 3: Implement the minimal route and seed methods**

Parse URL parameters only on web builds. A seed creates an isolated study save with Level 1 in `completed_levels`, unlocked equipment/rewards exactly matching legitimate L1 completion, and `current_level = 2`; it must not copy the normal save wholesale and must remove `research_seed` from the URL after use. An existing participant save wins over the seed so refresh cannot reset progress.

- [ ] **Step 4: Run headless and contract tests**

Run the two Step 2 commands again.

Expected: both exit 0; no `SCRIPT ERROR`.

- [ ] **Step 5: Commit route state**

```bash
git add scripts/systems/game_manager.gd scripts/systems/save_manager.gd scripts/systems/mission_manager.gd tools/study_campaign_runtime_test.gd tools/study_mini_game_contract_test.mjs
git commit -m "feat: preserve full campaign in research mode"
```

### Task 2: Godot-to-browser survey checkpoint bridge

**Files:**
- Create: `scripts/systems/research_bridge.gd`
- Modify: `project.godot` autoload section
- Modify: `scripts/ui/learning_card.gd:807-866`
- Modify: `scripts/ui/study_graduation.gd:1-end`
- Create: `tools/research_bridge_contract_test.gd`

**Interfaces:**
- Autoload name: `ResearchBridge` at `res://scripts/systems/research_bridge.gd`.
- Produces `ResearchBridge.offer_after_level(level_number: int, continue_scene: String) -> bool`.
- Browser event `observatory:research-checkpoint` detail: `{nodeId, completedLevel, continueScene, language, participantId, routeArm}`.
- Browser callbacks installed on `window`: `__poResearchContinue(payloadJson)` and `__poResearchExitToArchive(payloadJson)`.
- Signal: `checkpoint_resolved(action: String, node_id: String)`.

- [ ] **Step 1: Write the failing GDScript bridge test**

```gdscript
extends SceneTree
var failures := 0
func _init() -> void:
  var bridge_script = load("res://scripts/systems/research_bridge.gd")
  _check(bridge_script != null, "research bridge loads")
  var bridge = bridge_script.new()
  _check(bridge.node_for_level(1) == "baseline", "bridge exposes baseline")
  _check(bridge.node_for_level(6) == "A", "bridge exposes node A")
  _check(bridge.node_for_level(5).is_empty(), "bridge ignores non-checkpoints")
  quit(1 if failures else 0)
func _check(value: bool, label: String) -> void:
  if not value:
    failures += 1
    push_error(label)
```

- [ ] **Step 2: Run and confirm the script is missing**

Run: `& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://tools/research_bridge_contract_test.gd`

Expected: FAIL because `research_bridge.gd` does not exist.

- [ ] **Step 3: Implement `ResearchBridge` and learning-card interception**

`offer_after_level` returns false outside web, outside levels `1/6/11/16/21/24`, or when the browser reports no active research invitation/session. It dispatches the checkpoint event and pauses only the learning-card continue action, not the whole SceneTree. The browser callback resumes the exact `continue_scene`; archive exit navigates the top page to `/study/` after saving. `learning_card.gd` calls the bridge before its existing story/continue logic and falls through unchanged when the bridge returns false.

- [ ] **Step 4: Run bridge and full parse checks**

```powershell
& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://tools/research_bridge_contract_test.gd
& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --quit
```

Expected: bridge test exits 0 and parse check contains no `SCRIPT ERROR`.

- [ ] **Step 5: Commit the browser bridge**

```bash
git add scripts/systems/research_bridge.gd project.godot scripts/ui/learning_card.gd scripts/ui/study_graduation.gd tools/research_bridge_contract_test.gd
git commit -m "feat: emit research checkpoints from Godot"
```

### Task 3: In-game invitation and survey overlay

**Files:**
- Create: `web/landing/research-overlay.js`
- Create: `web/landing/research-overlay.css`
- Modify: `web/landing/game/index.html` shell source if present; otherwise modify the injection template in `tools/build_web_shell.mjs`
- Modify: `tools/build_web_shell.mjs` at stylesheet/script injection
- Modify: `tools/verify_web_game_shell.mjs`
- Create: `tools/research_overlay_contract_test.mjs`

**Interfaces:**
- Consumes `observatory:research-checkpoint` and Plan 1 endpoints.
- Calls `window.__poResearchContinue(JSON.stringify({nodeId}))` after completion/skip.
- Calls `window.__poResearchExitToArchive(JSON.stringify({participantId,token}))` for `archive_text` after baseline assignment.
- Persists the same `pixel-observatory:research-session:v2` object as `/study/`.
- Exposes `window.PixelObservatoryResearch.openSettings()` so reminders can be re-enabled.

- [ ] **Step 1: Write the failing shell contract**

```js
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const overlay = await readFile(new URL("../web/landing/research-overlay.js", import.meta.url), "utf8");
const builder = await readFile(new URL("./build_web_shell.mjs", import.meta.url), "utf8");
assert.match(overlay, /observatory:research-checkpoint/);
assert.match(overlay, /__poResearchContinue/);
assert.match(overlay, /__poResearchExitToArchive/);
assert.match(overlay, /PixelObservatoryResearch/);
assert.match(builder, /research-overlay\.css/);
assert.match(builder, /research-overlay\.js/);
```

- [ ] **Step 2: Run and confirm missing overlay files**

Run: `node tools/research_overlay_contract_test.mjs`

Expected: FAIL with `ENOENT`.

- [ ] **Step 3: Implement the L1 invitation and checkpoint modal**

After L1, show a concise optional invitation with `Join the study`, `Not now`, privacy summary, and withdrawal link. Join opens consent and the easy baseline. Server assignment is revealed only after baseline. `archive_text` exits to `/study/`; `field_gameplay` reloads `/game/` with `mode=study`, participant token, `research_arm=field_gameplay`, and `research_seed=l1_complete`. Later checkpoints display three questions, a visible progress `1 of 3`, `Answer and continue`, `Later`, and after two deferrals `Do not remind me again this session`. Completion and skip both return control safely to Godot.

- [ ] **Step 4: Implement focus, motion, and failure behavior**

Use a native `<dialog>` or an equivalent focus trap. Escape invokes `Later`, never loses progress. Network failure preserves selected answers, offers retry, and never advances the checkpoint as completed. Reduced-motion removes entrance travel and particle motion. No overlay animation exceeds 320 ms; reward animation belongs to Plan 3.

- [ ] **Step 5: Run shell contracts**

```powershell
node tools/research_overlay_contract_test.mjs
node tools/verify_web_game_shell.mjs build/web
```

Expected: both exit 0 after a local web export exists.

- [ ] **Step 6: Commit the overlay**

```bash
git add web/landing/research-overlay.js web/landing/research-overlay.css tools/build_web_shell.mjs tools/verify_web_game_shell.mjs tools/research_overlay_contract_test.mjs
git commit -m "feat: embed optional surveys in the game shell"
```

### Task 4: Route enforcement, deferral, and cross-exposure

**Files:**
- Modify: `web/landing/research-overlay.js`
- Modify: `web/landing/game-loader.js:320-378`
- Modify: `scripts/systems/game_manager.gd:588-612`
- Create: `tools/research_route_enforcement_test.mjs`

**Interfaces:**
- `archive_text` receives no Godot launch URL after baseline.
- `field_gameplay` may launch only the original Level 2-24 path for its participant save.
- `ordinary game` navigation while an unfinished text session exists calls `/api/research/exposure` and sets `crossExposed` before navigation.

- [ ] **Step 1: Write route-enforcement assertions**

```js
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const overlay = await readFile(new URL("../web/landing/research-overlay.js", import.meta.url), "utf8");
const loader = await readFile(new URL("../web/landing/game-loader.js", import.meta.url), "utf8");
assert.match(overlay, /routeArm === "archive_text"/);
assert.match(overlay, /research_seed.*l1_complete/);
assert.match(loader, /\/api\/research\/exposure/);
assert.match(loader, /ordinary_game/);
assert.doesNotMatch(overlay, /routeArm\s*:/, "The client must not request its assignment.");
```

- [ ] **Step 2: Run and confirm cross-exposure handling is absent**

Run: `node tools/research_route_enforcement_test.mjs`

Expected: FAIL on `/api/research/exposure`.

- [ ] **Step 3: Implement route gates and exposure marking**

Do not trust query parameters alone: refresh `/api/research/session` before continuing at every checkpoint and when the game shell boots in research mode. If the server arm and query arm disagree, stop with a recoverable message and return to `/study/`. Ordinary play remains available, but an unfinished text participant is marked cross-exposed before entry.

- [ ] **Step 4: Run contract and Godot tests**

```powershell
node tools/research_route_enforcement_test.mjs
node tools/research_overlay_contract_test.mjs
& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://tools/study_campaign_runtime_test.gd
```

Expected: all exit 0.

- [ ] **Step 5: Commit enforcement**

```bash
git add web/landing/research-overlay.js web/landing/game-loader.js scripts/systems/game_manager.gd tools/research_route_enforcement_test.mjs
git commit -m "fix: enforce assigned research route"
```

### Task 5: End-to-end gameplay-arm verification

**Files:**
- Create: `tools/playwright_research_gameplay_route.mjs`
- Create: `tools/research_checkpoint_smoke_test.gd`
- Modify: `.github/workflows/deploy-web.yml` test step

**Interfaces:**
- Verifies the Plan 1 API plus Tasks 1-4 as a single flow.

- [ ] **Step 1: Add a deterministic Godot checkpoint smoke test**

The script marks levels 1, 6, 11, 16, 21, and 24 completed in an isolated test progress dictionary and asserts the emitted node sequence is `baseline,A,B,C,D,E`; it also asserts levels 2-5, 7-10, 12-15, 17-20, and 22-23 do not produce checkpoints.

- [ ] **Step 2: Add Playwright API stubs and gameplay assertions**

The test opens a built `/game/`, dispatches the Level 1 checkpoint event, joins, submits baseline, receives `field_gameplay`, and verifies the reload URL contains `mode=study`, `research_arm=field_gameplay`, `research_seed=l1_complete`, participant, and token. It then dispatches node A, chooses `Later` twice, selects session silence, re-enables it through settings, submits A, and checks that `__poResearchContinue` receives `{nodeId:"A"}`.

- [ ] **Step 3: Run at all target viewports**

```powershell
& 'C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe' --headless --path . --script res://tools/research_checkpoint_smoke_test.gd
node tools/playwright_research_gameplay_route.mjs --viewport=1920x1080
node tools/playwright_research_gameplay_route.mjs --viewport=1024x768
node tools/playwright_research_gameplay_route.mjs --viewport=390x844
```

Expected: all exit 0; screenshots exist under `artifacts/research/gameplay-*.png`; no modal text or button is clipped.

- [ ] **Step 4: Add the stable contracts to CI**

Add Node contract tests and Godot headless smoke tests to the existing `Add Pixel Observatory web shell` step. Keep Playwright screenshot tests local because the repository currently has no Playwright installation step.

- [ ] **Step 5: Commit gameplay verification**

```bash
git add tools/playwright_research_gameplay_route.mjs tools/research_checkpoint_smoke_test.gd .github/workflows/deploy-web.yml artifacts/research/gameplay-*.png
git commit -m "test: verify embedded gameplay research route"
```
