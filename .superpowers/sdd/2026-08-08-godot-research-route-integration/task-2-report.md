# Task 2 Report: Godot-to-browser checkpoint bridge

## Changed files

- `scripts/systems/research_bridge.gd`: Adds the checkpoint bridge, verified research-session gate, one-time checkpoint resolution, browser callbacks, and archive exit handling.
- `project.godot`: Registers `ResearchBridge` as an autoload.
- `scripts/ui/learning_card.gd`: Offers checkpoints before its existing continue logic and restores that exact continuation from the browser callback.
- `scripts/ui/study_graduation.gd`: Consumes a resolved Level 24 checkpoint on scene restoration so `_ready()` does not reopen the questionnaire.
- `tools/research_bridge_contract_test.gd`: Covers verified research gating, single L24 consumption, and learning-card continuation through the teaching intercept.

## Verification

The path named in the plan, `C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`, was absent. The installed console executable was found at `E:\godot\godot47\Godot_v4.7-stable_win64_console.exe`.

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/research_bridge_contract_test.gd
```

Output: exit `0`; all assertions passed, including verified research gating, local-prestudy fallthrough, single L24 resolution, and callback restoration of the original learning-card continuation.

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --quit
```

Output: exit `0` in 1.4 seconds with no `SCRIPT ERROR`. Godot reported its existing shutdown resource/ObjectDB warnings only.

Static inspection confirms `offer_after_level` returns `false` before dispatching outside Web, at non-checkpoint levels, after a resolved checkpoint, and without a verified participant/token/`field_gameplay` context. The learning-card callback invokes its original continuation, preserving pending mission setup, teaching, and story-epilogue handling. The graduation scene consumes its resolved checkpoint before `_ready()` can offer it again.

## Known limitations

The headless contract test exercises the native fallthrough path. Browser event dispatch, callback invocation, and top-level archive navigation require the browser overlay work from Task 3 and were not exercised here.
