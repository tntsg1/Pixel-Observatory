"""Build the observatory player's deterministic eight-direction walk atlas.

The supplied source animations are six-frame, 160x160 transparent GIFs.  The
runtime atlas keeps every source pixel untouched and only lays the frames out
in the row order consumed by ``observatory_room.gd``.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageSequence


SOURCE_FRAME_SIZE = (160, 160)
# The source character occupies x=58..101 and y=48..124 across every frame.
# Crop only transparent margin so the runtime frame retains the old player's
# 54 px presentation width without resampling any artwork.
FRAME_CROP = (48, 36, 112, 132)
FRAME_SIZE = (FRAME_CROP[2] - FRAME_CROP[0], FRAME_CROP[3] - FRAME_CROP[1])
FRAME_COUNT = 6
DIRECTIONS = (
    ("down", "Idle_walk_south.gif"),
    ("down_right", "Idle_walk_south-east.gif"),
    ("right", "Idle_walk_east.gif"),
    ("up_right", "Idle_walk_north-east.gif"),
    ("up", "Idle_walk_north.gif"),
    ("up_left", "Idle_walk_north-west.gif"),
    ("left", "Idle_walk_west.gif"),
    ("down_left", "Idle_walk_south-west.gif"),
)


def read_frames(path: Path) -> list[Image.Image]:
    with Image.open(path) as image:
        if image.size != SOURCE_FRAME_SIZE:
            raise ValueError(f"{path.name}: expected {SOURCE_FRAME_SIZE}, got {image.size}")
        frames = [frame.convert("RGBA").crop(FRAME_CROP) for frame in ImageSequence.Iterator(image)]
        durations = [int(frame.info.get("duration", image.info.get("duration", 0))) for frame in ImageSequence.Iterator(image)]
    if len(frames) != FRAME_COUNT:
        raise ValueError(f"{path.name}: expected {FRAME_COUNT} frames, got {len(frames)}")
    if durations != [200] * FRAME_COUNT:
        raise ValueError(f"{path.name}: expected six 200 ms frames, got {durations}")
    return frames


def build(source_dir: Path, output_path: Path) -> None:
    atlas = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * FRAME_COUNT, FRAME_SIZE[1] * len(DIRECTIONS)),
        (0, 0, 0, 0),
    )
    for row, (direction, filename) in enumerate(DIRECTIONS):
        source_path = source_dir / filename
        if not source_path.is_file():
            raise FileNotFoundError(f"Missing {direction} source: {source_path}")
        for column, frame in enumerate(read_frames(source_path)):
            atlas.alpha_composite(frame, (column * FRAME_SIZE[0], row * FRAME_SIZE[1]))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(output_path, format="PNG", optimize=True)
    print(f"Built {output_path} ({atlas.width}x{atlas.height}, {FRAME_COUNT} frames x {len(DIRECTIONS)} directions)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source_dir", type=Path)
    parser.add_argument("output_path", type=Path)
    args = parser.parse_args()
    build(args.source_dir, args.output_path)


if __name__ == "__main__":
    main()
