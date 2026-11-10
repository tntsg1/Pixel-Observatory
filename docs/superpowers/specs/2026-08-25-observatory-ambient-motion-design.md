# Observatory Ambient Motion Design

## Goal

Make the observatory hall feel inhabited while the player is standing still.
This is not an entrance cinematic and it does not change any route, collision,
or mission condition.

## Two layers

### Ambient layer

Always active, low contrast, and deliberately asynchronous:

- warm lamps breathe by a few alpha points and shed occasional square motes;
- the lower-right remote console keeps a clipped CRT scan moving;
- the central telescope gets a rare guide-star glint rather than visible random
  rotation;
- the assembly bench receives an occasional blueprint sweep.

### Task-performance layer

The current `GameManager.room_guidance_target` is visually busier than the
rest of the room. This is state indication, not an extra tutorial. The work
surface, telescope, mission board, or remote console shows a compact pulse at
the location the player is already being asked to visit.

## Motion constraints

- No positional motion for furniture or actors.
- No full-screen particles, gradients, or opaque overlays.
- All effects are pixel-aligned and clipped to their owning station.
- Reduced motion keeps a static status light and slows or removes drifting
  motes; it never removes the task-performance indicator.
- Ambient updates are deterministic enough for automated verification and
  remain independent of gameplay progress.

## Verification

`tools/observatory_ambient_motion_test.gd` instantiates the real hall and
checks both layers, all core stations, guidance-target emphasis, and reduced
motion behavior. A separate capture script records a quiet hall and an
assembly-guided hall for visual review.
