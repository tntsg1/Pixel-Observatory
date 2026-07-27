# Audio Attribution

## `music/space_fast_theme.mp3`

- Source filename: `7月26日.mp3`
- Source: user-provided local audio
- Imported: 2026-07-26
- Usage: shared background theme for Space Infrared Observatory and FAST Radio Observation
- Processing: copied byte-for-byte; no edit, trim, or normalization
- SHA-256: `3AB3D08CDC7C66E8694C1F0B158C55A89492B0F4419BC552477B78D55E70DDED`

## `sfx/collimation_adjust_loop.ogg`

- Source: project-owned `sfx/mechanical_adjust.ogg`
- Created: 2026-07-26
- Usage: continuous Newtonian mirror-collimation ratchet while a slider value is changing
- Processing: removed the measured 102 ms leading silence; added a 6 ms fade-in and a short 20 ms tail fade for clean loop stop
- Runtime behavior: one shared loop, stopped after 90 ms without a value change or immediately on drag end / scene exit
- Original source remains unchanged for other one-shot adjustment events
