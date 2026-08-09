# Task 1 Report: Research Route State in GameManager and SaveManager

## Status

Implementation complete. The Task 1 Node contract and bounded Godot research-route runtime test pass. The full-project Godot parse command exits 0 but still reports pre-existing missing generated import artifacts for the main-menu images and lobby audio; this is recorded under concerns and was not changed by Task 1.

## Commits

- `ecf7c96 feat: preserve full campaign in research mode`
- `7d9ea0a test: bound study campaign runtime test`

## Changed Files

- `scripts/systems/game_manager.gd`
  - Added web-only `research_route_arm()`, `research_participant_id()`, and completed-level-to-node mapping.
  - Added a Level 1 research seed state based on a fresh study default, not the normal save.
  - Reloads the isolated study save after a successful one-time seed.
- `scripts/systems/save_manager.gd`
  - Added `seed_research_level_one_complete()`.
  - Keeps participant saves isolated, lets an existing participant save win, and removes `research_seed` after consumption.
- `scripts/systems/mission_manager.gd`
  - Rejects research campaign subsets that do not begin at L1 or are not sequential.
- `tools/study_campaign_runtime_test.gd`
  - Covers the complete L1-L24 route and all six research checkpoints.
  - Adds an internal 20-second watchdog and idempotent exit path.
- `tools/study_mini_game_contract_test.mjs`
  - Requires the three GameManager interfaces and SaveManager seed interface.
  - Rejects the retired `[16, 24]` shortcut.
  - Removes stale page and worker assertions already superseded by the dedicated current research-page/program contracts.

## Initial Failing Evidence

After adding the new contract assertions and before production changes:

- `node tools/study_mini_game_contract_test.mjs` failed on the missing `func research_route_arm() -> String` interface.
- The study runtime test, run in study context, reached `Invalid call. Nonexistent function 'research_node_for_completed_level' in base 'Node (game_manager.gd)'`.

The first Node run also exposed stale mini-game page assertions that had not been updated after the committed text-route rebuild. The current `tools/research_study_page_contract_test.mjs` passed and owns that page coverage, so the Task 1 contract was narrowed to the Godot campaign state it is responsible for.

## Final Test Evidence

Passed:

```powershell
node tools/study_mini_game_contract_test.mjs
# Research route state and complete L1-L24 main-game campaign contract passed.
```

This is the actual final Node contract result: it exited successfully and printed the line above.

## Runtime Process Incident

Before the watchdog fix, three separately launched headless `study_campaign_runtime_test.gd` processes remained hung for approximately 8, 7, and 7 minutes. They were explicitly terminated externally by the user. No further unbounded runtime launches were made. The subsequent bounded one-process run below completed successfully.

Passed with one process, an internal 20-second test watchdog, and an external 25-second `WaitForExit` bound:

```powershell
Start-Process E:\godot\godot47\Godot_v4.7-stable_win64.exe \
  --headless --path . --script res://tools/study_campaign_runtime_test.gd -- --study
# STUDY CAMPAIGN RUNTIME TEST PASS
```

The required full parse command was also run:

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64.exe' --headless --path . --quit
```

It exited 0 but emitted existing missing-import errors for `main_menu_bg_1024.png`, `main_menu_bg_zh_1024.png`, and `lobby.ogg`. A standard headless editor import was run once before repeating the command; it did not restore those ignored artifacts.

## Self-Review

- URL reads for research arm, participant ID, and seed are behind `OS.has_feature("web")` and `JavaScriptBridge` availability checks.
- Only `archive_text` and `field_gameplay` are accepted route-arm values.
- The seed begins from `default_progress()`, writes only through the study save path, applies L1 credits, parts, badge, concept card, and equipment-stage rewards, and starts at L2.
- Existing participant save files prevent reseeding on refresh.
- No normal-save data is copied, no autoload gains `class_name`, and no float modulo expression was added.
- The mission guard keeps the research subset anchored at L1 and sequential.
- The diff is limited to Task 1 files plus this required report; `git diff --check` passed before the commits.

## Concerns

- The runtime test requires `--study` in its user arguments to exercise the study route. The brief's literal runtime command omits that context, so the bounded verification added `-- --study` while preserving the specified executable, path, and script.
- Full-project parse output is not clean because this isolated worktree lacks ignored Godot import products for unrelated main-menu images/audio. The bounded study runtime test parses and executes the modified Task 1 scripts successfully.
- Web-only seed behavior cannot be exercised by the native headless runtime; its public interface is covered by the Node contract. Browser bridge/end-to-end route coverage remains in later approved tasks.
