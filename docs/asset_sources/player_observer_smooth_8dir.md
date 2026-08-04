# Smooth Observatory Player Animation

The runtime atlas `assets/characters/player_observer_smooth_8dir.png` was built
from the eight transparent GIF animations supplied by the project owner in
`C:\Users\tntsg\Downloads\tw\zz` on 2026-08-03.

- Source directions: north, north-east, east, south-east, south, south-west,
  west, north-west.
- Source format: 160x160 RGBA-equivalent canvas, six frames per direction,
  200 ms per frame, looping.
- Runtime layout: six 64x96 columns by eight rows; row order is down,
  down-right, right, up-right, up, up-left, left, down-left.
- Transformation: lossless frame compositing, transparent-margin cropping and
  atlas packing only. Visible pixels, transparency, aspect ratio, and frame
  timing were not resampled.

Rebuild command:

```powershell
python tools/art/build_smooth_player_atlas.py `
  "C:\Users\tntsg\Downloads\tw\zz" `
  assets/characters/player_observer_smooth_8dir.png
```

Source SHA-256 fingerprints:

```text
aa0693b5ad41ae6b8f2cd02c733f3c4c23d830c085ad36a361ab935dd5e88443  Idle_walk_east.gif
3dad631ed1f944a531d91d66b0c01874c4c2416a8b789c88a34477aaf4141705  Idle_walk_north.gif
ed0fad26c13df3bf5e5dc339a4e9785b98df70947ecff27dfee889f84a0e0b19  Idle_walk_north-east.gif
dd001d64100fb611b569aa50c999efa39c157f17a4e1de8b8f0e4e4a35f2dc56  Idle_walk_north-west.gif
fec904e8cf310d97e1123b0f6de1ef85068ab42f6d5e9c9c34a6dae6180331ab  Idle_walk_south.gif
f0b569e942f3e04691ba06cc8bb2e0ba54dfe1dbe23431cfdd9f77c1c25bddeb  Idle_walk_south-east.gif
ff4050baf14812f4769562a8208ef8afc119d9f72e2b5cc9b321a97ee270b9a8  Idle_walk_south-west.gif
576962efb7b7f9fa0710f55bc3aa0f7b6061f19844337494c93e15b2fa20086b  Idle_walk_west.gif
```
