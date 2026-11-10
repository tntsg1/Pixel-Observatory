# UI Reachability and Visual Consistency Audit (2026-08-22)

## Scope

This audit checks which scene files belong to the current astronomy game, which
files are retained legacy prototypes, and whether the main utility screens use a
consistent visual language with the observatory hall artwork.

## Production routes

`project.godot` starts at `res://scenes/main_menu.tscn`. The production route
table in `GameManager.SCENES` contains 21 reachable screens:

`menu`, `observatory`, `interior`, `parts`, `assembly`, `advanced_assembly`,
`telescope_types`, `world_map`, `optical_tube_assembly`, `collimation`,
`radio_observation`, `multi_observation`, `space_observation`, `constellation`,
`sky`, `telescope`, `journal`, `card`, `story`, `graduation`, and
`study_graduation`.

All 21 route targets exist and load as Godot resources. This contract is covered
by `res://tools/ui_reachability_audit_test.gd`.

## Legacy prototype boundary

The following files belong to the earlier shooter prototype and are not in the
astronomy route table:

- `res://scenes/main.tscn`
- `res://scenes/levels/level1.tscn`
- `res://scenes/ui/main_menu.tscn`
- `res://scenes/ui/pause_menu.tscn`

They are intentionally not deleted in this pass. The legacy level owns the
legacy pause menu, and `res://tools/tutorial_assistance_mode_test.gd` still
instantiates that pause menu for isolated regression coverage. Removing the
files without first migrating that test would trade disk tidiness for a broken
test contract. None of these scenes can be reached from the current production
route table.

The old combat support scenes under `scenes/enemies`, `scenes/bullets`,
`scenes/bosses`, and `scenes/fx` are dependencies of the same isolated prototype
subtree. They should be archived together only in a dedicated cleanup change,
after replacing or removing the remaining regression coverage.

## Visual corrections in this pass

- Added `res://scripts/ui/observatory_ui_style.gd` as the shared source for the
  navy, brass, cyan, warm-text, panel, button, frame-corner, and hall-backdrop
  treatments.
- Replaced the learning journal's procedural star-dot background with the
  observatory hall artwork behind a controlled scrim. The archive now has a
  framed header and consistent record-card hierarchy.
- Replaced the parts cabinet's unrelated star-grid background with the same hall
  context while preserving strong opaque work surfaces and all equipment logic.
- Connected the telescope catalog to the same palette and backdrop without
  changing its successful information architecture or selection behavior.
- Reframed the study-graduation summary over the observatory hall artwork, with
  a dedicated completion header and a single clear continuation action.
- Placed the world map's selected-site details inside a restrained navy/steel
  instrument panel so the data remains readable without competing with the map.
- Corrected the parts-cabinet screenshot harness so it captures after the
  0.34-second entrance animation instead of recording a misleading half-faded
  frame.

## Deliberate non-changes

- No scene was removed, renamed, or rerouted.
- No progression, equipment, observation, or save behavior was changed.
- The already-polished telescope catalog layout was not redesigned; it only
  received shared visual tokens and a subtle environmental backdrop.
- Feature-specific screens such as FAST and the infrared control console retain
  their instrument-era visual identities. Consistency means shared hierarchy and
  framing, not forcing every instrument into one identical skin.

## Acceptance evidence

- `res://tools/ui_reachability_audit_test.gd`
- `res://tools/ui_style_consistency_test.gd`
- `res://tools/capture_parts_cabinet.gd`
- `res://tools/capture_core_flow_states.gd`
- `res://tools/capture_telescope_type_selection_redesign.gd`
- `res://tools/capture_ui_style_followup.gd`
