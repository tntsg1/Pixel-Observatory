# Maya NPC Animation Sheets

All sheets are 1024 x 1024 RGBA PNGs arranged as a 4 x 4 grid. Each frame is
256 x 256 pixels. Import with nearest-neighbor filtering and no mipmaps.

## maya_walk_4dir.png

- Row 0: walk down
- Row 1: walk left
- Row 2: walk right
- Row 3: walk up
- Columns 0-3: four-frame loop

Recommended playback: 7-9 FPS.

## maya_instrument_actions.png

- Row 0: assemble or tighten a telescope part at the workbench
- Row 1: adjust and observe through the central optical telescope
- Row 2: operate the FAST or space-telescope control console
- Row 3: write in the observation journal
- Columns 0-3: four-frame loop

Recommended playback: 4-6 FPS, with a short hold on the final frame.

## maya_coop_actions.png

- Row 0: brace an optical tube while the player installs it
- Row 1: hand a component to the player
- Row 2: assist with collimation
- Row 3: react to and confirm a successful observation
- Columns 0-3: four-frame sequence

Recommended playback: 5-7 FPS. The handoff and success sequences should play
once; the support and collimation sequences may loop.
