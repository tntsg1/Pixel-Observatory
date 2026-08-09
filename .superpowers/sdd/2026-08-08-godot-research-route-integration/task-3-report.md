# Task 3 Report: In-Game Invitation and Survey Overlay

Status: DONE

## Delivered

- Added the isolated `po-research-*` liquid-glass stylesheet for the existing overlay controller.
- Injected the stylesheet and controller into the generated Godot shell; the controller is loaded before the engine script so checkpoint listeners are ready at startup.
- Added build-time publication checks and generated-shell verification for both overlay assets.
- Strengthened the existing overlay contract with CSS accessibility, responsive-breakpoint, scrollability, and build-publication assertions without removing any assertion.

## TDD Evidence

`node tools/research_overlay_contract_test.mjs` initially failed with the expected missing `web/landing/research-overlay.css` error.

After the CSS was added, the pre-existing endpoint and progress assertions produced false negatives because the controller composes each URL from the shared `API` constant and its `request()` path argument, and writes the progress attribute through `dataset.researchProgress`. The assertions now check those concrete code paths; no controller code changed.

## Verification

- `node --check web/landing/research-overlay.js`
- `node --check tools/build_web_shell.mjs`
- `node --check tools/patch_web_loader.mjs`
- `node --check tools/verify_web_game_shell.mjs`
- `node --check tools/research_overlay_contract_test.mjs`
- `node tools/research_overlay_contract_test.mjs`

The full builder/verifier remains contingent on a staged Godot web export at `build/web/.godot-export`.
