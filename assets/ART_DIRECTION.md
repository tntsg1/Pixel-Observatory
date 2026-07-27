# Player-Facing Art Direction

## Final visual hierarchy

When a player-facing area exists to show a real object, telescope, celestial
target, location, mechanical structure, observation result, or story image,
use the following sources in order:

1. User-provided or existing approved project art.
2. Legally usable reference imagery with source and license recorded.
3. A generated raster asset imported into `assets/` with its prompt, purpose,
   and crop recorded.

Basic procedural geometry, random point fields, low-detail SVGs, and simple
Canvas line drawings are not final art for these areas. They are reserved for
functional UI, precise data visualization, interaction guides, and temporary
development placeholders.

## Asset handling

- Copy every approved external asset into a semantic, version-controlled path
  under `assets/`; never load final art from Downloads or Temp.
- Preserve aspect ratio. Use `KEEP_ASPECT_CENTERED` behavior and do not stretch.
- Record source, license or generation prompt, purpose, and crop decisions.
- FAST explanatory images must be labeled as data visualization or inferred
  models when they are not direct photographs.
- If suitable art is unavailable, document the missing asset and generation
  brief instead of shipping low-quality procedural art as final.

## FAST blueprint

The approved FAST assembly source and exact crop are documented in
`assets/assembly/FAST_BLUEPRINT_REFERENCE.md`. Do not redraw or replace that
blueprint without explicit approval.
