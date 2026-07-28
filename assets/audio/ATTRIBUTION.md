# Audio Attribution

## Retired remote-observatory audio

The following resources are intentionally absent from distributable builds:

- `music/giant_telescope.mp3` (`uid://b4x44bsg33mdj`)
- `music/space_fast_theme.mp3` (`uid://b1qu5girwevff`, SHA-256
  `3AB3D08CDC7C66E8694C1F0B158C55A89492B0F4419BC552477B78D55E70DDED`)
- `ambient/fast_terminal_hum.ogg` (`uid://c7hv8ifvlw2uf`)

The replacement music was supplied as a local file, but it did not include an
author, title, copyright notice or reusable-license record. The FAST ambience
also lacked a source and license record. Both remote-observatory scenes use an
explicit silent music route until cleared replacements are supplied. The
original user file outside this repository was not moved or deleted.

## `sfx/collimation_adjust_loop.ogg`

- Source: project-owned `sfx/mechanical_adjust.ogg`
- Created: 2026-07-26
- Usage: continuous Newtonian mirror-collimation ratchet while a slider value is changing
- Processing: removed the measured 102 ms leading silence; added a 6 ms fade-in and a short 20 ms tail fade for clean loop stop
- Runtime behavior: one shared loop, stopped after 90 ms without a value change or immediately on drag end / scene exit
- Original source remains unchanged for other one-shot adjustment events
