# Task 2 Report: Godot-to-browser checkpoint bridge

## Changed files

- `scripts/systems/research_bridge.gd`: Adds the checkpoint bridge, one-time checkpoint resolution, browser callbacks, and archive exit handling. L1 can offer only when `window.PixelObservatoryResearch.canOfferBaseline() === true`; L6+ can offer only when `hasVerifiedGameplaySession() === true`. Missing hooks fall through, and URL/localStorage values do not authorize a checkpoint.
- `project.godot`: Registers `ResearchBridge` as an autoload.
- `scripts/ui/learning_card.gd`: Offers checkpoints before its existing continue logic and restores that exact continuation from the browser callback.
- `scripts/ui/study_graduation.gd`: Consumes a resolved Level 24 checkpoint on scene restoration so `_ready()` does not reopen the questionnaire.
- `tools/research_bridge_contract_test.gd`: Covers the controlled baseline hook, missing-hook and forged-query fallthrough, verified later-session gating, single L24 consumption by an instantiated graduation scene, and the bridge's saved original learning-card continuation.

## Verification

The path named in the plan, `C:\Users\tntsg\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe`, was absent. The installed console executable was found at `E:\godot\godot47\Godot_v4.7-stable_win64_console.exe`.

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tools/research_bridge_contract_test.gd
```

Output: exit `0`; all assertions passed, including the participant/token-free L1 baseline permission, forged-query fallthrough, server-verified later-session permission, single L24 consumption by `study_graduation`, and callback restoration of the original learning-card continuation without manually emitting the bridge signal.

```powershell
& 'E:\godot\godot47\Godot_v4.7-stable_win64_console.exe' --headless --path . --quit
```

Output: exit `0` in 1.4 seconds with no `SCRIPT ERROR`. Godot reported its existing shutdown resource/ObjectDB warnings only.

Static inspection confirms `offer_after_level` returns `false` before dispatching outside Web, at non-checkpoint levels, after a resolved checkpoint, without `canOfferBaseline()` at L1, and without `hasVerifiedGameplaySession()` at L6+. The bridge reads neither URL query parameters nor localStorage for authorization. The learning-card callback invokes its original continuation, preserving pending mission setup, teaching, and story-epilogue handling. The instantiated graduation scene consumes its resolved E checkpoint before `_ready()` can offer it again.

## Known limitations

The headless contract test exercises the native fallthrough path. Browser event dispatch, callback invocation, and top-level archive navigation require the browser overlay work from Task 3 and were not exercised here.
