# Observation UI Acceptance Report

## Latest source mapping

- Source directory: `C:/Users/tntsg/Downloads/tw/suc`
- Untouched project copies: `assets/ui/observation/suc/source/`
- Runtime assets: `assets/ui/observation/suc/processed/`
- Full SHA-256, source dimensions, alpha state, crop rectangle, runtime dimensions, and filename mapping: `assets/ui/observation/suc/asset_manifest.json`
- Latest reticle mapping:
  - `1.2.png` -> `processed/1.png` (Eye), SHA-256 `e4eb046e...7500f0`
  - `2.png` -> `processed/2.png` (Finder), SHA-256 `8910587b...8b72ed`
  - `3.1.png` -> `processed/3.png` (Scope), SHA-256 `8d57d2c9...e932a`

`1.2.png` is a 1024x1024 RGBA image with native transparency, which is preserved directly. `2.png` and `3.1.png` are 1254x1254 RGB images with a baked checkerboard, so the importer reconstructs alpha for those two without modifying the originals. Every runtime texture uses nearest-neighbor filtering.

## Reticle processing

| Mode | Source crop | Runtime size | Screen rect |
| --- | --- | --- | --- |
| Eye | `(10, 0, 1007, 1016)` | `550x560` | `(198, 178, 410, 410)` |
| Finder | `(82, 66, 1172, 1143)` | `560x553` | `(198, 178, 410, 410)` |
| Scope | `(43, 0, 1209, 1208)` | `541x560` | `(198, 178, 410, 410)` |

The screen rect is `VIEW_RECT (88, 103, 630, 560)` plus local `AIM_RETICLE_RECT (110, 75, 410, 410)`. Its center is `(403, 383)`, exactly matching the celestial projection center. All three centers are transparent; Scope also has no gray/black square or opaque optical disk. The reticles stop above the guidance band.

Final mode variants:

- Eye uses `eye_precise_reticle.png` (`410x410`), drawn in the supplied brass/cyan observatory style and displayed one-to-one. Its `196 px` outer boundary maximizes the naked-eye field, while its `64 px` center ring is the exact screen-space lock radius.
- Finder uses `finder_second_ring.png` (`560x560`): only the second circle remains; the outer circle, center gold circle, crosshair, ticks, dots, and ornaments are transparent.
- Scope uses `scope_center_tolerance.png`, derived from `3.png` without overwriting it. Its center frame is a true circle with a `184 px` source inner diameter, displayed at approximately `135 px` inside the `410 px` reticle. This contains every projected `0.5 degree` lock position and is more than one third wider than the `52 px` Scope Moon. The moving target marker is independent and target-sized: `target diameter + max(12 px, 25%)`, with readable but compact mode minimums of `40/44/48 px` for Eye/Finder/Scope. Its visible frame and pointer detection rectangle are identical. Approach markers use a subtle `0.72..0.92` alpha pulse; locked markers remain high-contrast gold. The detailed `Telescope View` deliberately has no barrel/reticle overlay, crosshair, or center circle.

Latest native-alpha replacements copied without modifying the download originals:

- `azimuth_pointer-removebg-preview.png` -> `processed/azimuth_pointer.png`
- `altitude_pointer-removebg-preview.png` -> `processed/altitude_pointer.png`
- `mode_eye_icon-removebg-preview.png` -> `processed/mode_eye_icon.png`
- `target_approach_ring-removebg-preview (1).png` -> `processed/target_approach_ring.png`
- `target_lock_ring-removebg-preview.png` -> `processed/target_lock_ring.png`
- `tracking_rate_knob-removebg-preview (1).png` -> `processed/tracking_rate_knob.png`

## Scales and pointers

- Top shell: screen `Rect2(80, 33, 630, 66)`.
- Live azimuth band: screen `Rect2(94, 42, 602, 42)`.
- Azimuth pointer center range: screen X `94..696` for `0..359.999` degrees; tip faces down.
- Left shell: screen `Rect2(8, 103, 76, 560)`.
- Live altitude band: screen `Rect2(23, 120, 44, 530)`.
- Altitude pointer center range: screen Y `650..120` for `0..90` degrees; tip faces right.
- Azimuth values span current aim `+/- FOV/2` and wrap continuously through 359/0.
- Altitude values span current aim `+/- FOV/2` and are clipped to `0..90`.

The supplied bars are used as source art. Their fixed decorative ticks are removed for the runtime shells; major/minor tick glyphs are cropped from the same art and placed at live angle positions. The scale textures, labels, pointers, Az/Alt values, and knobs therefore move from the same current aim data. Only one independent pointer exists per axis.

## Runtime assets

All 17 individual controls are integrated: three reticles; azimuth/altitude bars, pointers, and knobs; three mode icons; approach/lock rings; focus knob; tracking knob; and tracking-enabled icon. All were transparent-trimmed and size-limited with nearest-neighbor resizing. Exact values are in the manifest.

The `ChatGPT Image 2026...png` reference composites remain archive-only because they contain baked coordinates, instructions, values, or fixed reticles. No supplied cloud/seeing overlay exists, so the existing project cloud textures and turbulence shader remain in use; no placeholder was generated.

## Modes and state logic

- Eye FOV: `120x70` degrees; smallest/dimmest target; no focus control.
- Finder FOV: `28x18` degrees; medium locating mark; installation and IJKL calibration gates retained.
- Scope FOV: `6x4` degrees; largest target; focus, seeing, cloud, drift, tracking, light-pollution, and identification systems retained.
- Target outside view: direction guidance, no strong target ring, Observe disabled.
- Target near center: cyan approach ring follows the projected target, Observe disabled.
- Target centered: approach ring is replaced by the gold lock ring, Observe enabled.
- Approach and lock rings share one target-derived size. Their diameter is always larger than the rendered celestial texture, with mode-specific padding.
- Tracking: Off, Matched 1x, Too slow, and Too fast are distinct; rates below/above 1x preserve forward/reverse residual drift.
- Focus: target blur/ghosting and the focus knob use the same `focus_error` and tolerance used by quality evaluation.

Layer order inside the clipped sky viewport is: sky -> celestial objects -> cloud/seeing effects -> target feedback ring -> one mode reticle -> dynamic readouts -> guidance. Mission/Selected panels and action buttons remain outside that viewport.

## Screenshots

- `01_mode_naked_eye.png`
- `01_mode_finder.png`
- `01_mode_telescope.png`
- `02_target_outside_view.png`
- `03_target_approach.png`
- `04_target_locked.png`
- `05_azimuth_000.png`, `090`, `180`, `270`
- `06_altitude_00.png`, `30`, `60`, `90`
- `07_tracking_off.png`
- `08_tracking_matched.png`
- `09_tracking_too_fast.png`
- `10_focus_defocused.png`
- `11_focus_sharp.png`
- `1280x720/sky_finder_1280x720.png`

## Verification

- Godot 4.7 headless editor/import: pass, exit 0.
- Observation UI acceptance: pass.
- L25 reticle regression: pass.
- Newtonian reticle regression: pass.
- Identification quiz and scope layering: pass.
- Coordinate approach/lock feedback: pass.
- Animation feedback and reduced-motion behavior: pass.
- Environmental focus effects: pass.
- Nebula focus consistency: pass.
- Telescope modal layering: pass.
- Newtonian observation parity: pass.
- Sky guidance: pass.
- Story flow: pass.
- Teaching flow: pass.
- 1280x720 aspect-preserving window capture: pass; 1024x768 canvas is centered at 960x720 with 160px side bars.

No core level order, observation calculation, story condition, or save schema was changed. No additional observation UI asset is required for this integration.
