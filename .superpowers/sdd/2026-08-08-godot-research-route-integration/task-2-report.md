# Task 2 Report: Godot-to-browser checkpoint bridge

## Changed files

- `scripts/systems/research_bridge.gd`: Adds the checkpoint bridge, browser callbacks, and archive exit handling.
- `project.godot`: Registers `ResearchBridge` as an autoload.
- `scripts/ui/learning_card.gd`: Offers checkpoints before its existing continue logic.
- `scripts/ui/study_graduation.gd`: Offers the Level 24 checkpoint before notifying the parent page.
- `tools/research_bridge_contract_test.gd`: Pre-existing untracked contract test retained and included.

## Verification

The path named in the plan, `C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`, was absent. The installed console executable was found at `E:\godot\godot47\Godot_v4.7-stable_win64_console.exe`.

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/research_bridge_contract_test.gd
```

Output: exit `0`; all 14 assertions passed, including all checkpoint mappings and native/non-checkpoint fallthrough.

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --quit
```

Output: exit `0` in 1.4 seconds with no `SCRIPT ERROR`. Godot reported its existing shutdown resource/ObjectDB warnings only.

Static inspection confirms `offer_after_level` returns `false` before dispatching outside Web, at non-checkpoint levels, and when the browser does not report an active invitation/session. The learning-card and graduation handlers return only when it returns `true`; otherwise their existing paths run unchanged.

## Known limitations

The headless contract test exercises the native fallthrough path. Browser event dispatch, callback invocation, and top-level archive navigation require the browser overlay work from Task 3 and were not exercised here.
