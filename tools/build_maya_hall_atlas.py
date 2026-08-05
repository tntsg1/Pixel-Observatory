from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


# Keep generous transparent room above the character. PixelLab occasionally
# raises an arm or ponytail above the idle silhouette; a 48x64 cell could crop
# that motion even though the standing frame looked correct.
CELL_SIZE = (64, 80)
FOOT_ANCHOR = (32, 74)

WALK_FILES = {
    "south": "Idle_walk_south_left_arm_fixed.gif",
    "south_east": "Idle_walk_south-east (1).gif",
    "east": "Idle_walk_east (1).gif",
    "north_east": "Idle_walk_north-east.gif",
    "north": "Idle_walk_north (1).gif",
    "west": "Idle_walk_west (1).gif",
    "south_west": "Idle_walk_south-west (1).gif",
}

ACTION_FILES = {
    "beckon": "Idle_custom-A_friendly_beckoning_gesture._south.gif",
    "point": "Idle_custom-She_clearly_points_toward_a_ne_south.gif",
    "wave": "Idle_custom-A_warm_casual_greeting._She_sm_south.gif",
    "think": "Idle_custom-A_subtle_thinking_animation._S_south.gif",
    "notice": "Idle_custom-She_suddenly_notices_something_south.gif",
    "nod": "Idle_custom-A_satisfied_acknowledgement_an_south.gif",
    "assembly_work": "Idle_custom-Facing_a_workbench_lean_forwa_north.gif",
}


def chroma_key(frame: Image.Image) -> Image.Image:
    rgba = frame.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if green >= 240 and red <= 20 and blue <= 20:
                pixels[x, y] = (red, green, blue, 0)
            elif alpha > 0:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def load_frames(path: Path, mirror: bool = False) -> list[Image.Image]:
    image = Image.open(path)
    frames: list[Image.Image] = []
    for index in range(image.n_frames):
        image.seek(index)
        frame = chroma_key(image)
        if mirror:
            frame = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        cell = Image.new("RGBA", CELL_SIZE, (0, 0, 0, 0))
        bounds = frame.getbbox()
        if bounds is None:
            frames.append(cell)
            continue
        # PixelLab's individual walk frames differ by one or two source pixels
        # at the feet. Anchoring every frame to its own opaque bounds removes
        # the visible vertical shake after the game scales the sprite up.
        visual_center_x = (bounds[0] + bounds[2]) * 0.5
        visual_bottom = bounds[3]
        offset = (
            round(FOOT_ANCHOR[0] - visual_center_x),
            FOOT_ANCHOR[1] - visual_bottom,
        )
        cell.alpha_composite(frame, offset)
        frames.append(cell)
    return frames


def main() -> None:
    parser = argparse.ArgumentParser(description="Build the Maya hall NPC atlas from PixelLab GIFs.")
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    args = parser.parse_args()

    rows: list[tuple[str, list[Image.Image]]] = []
    for direction, filename in WALK_FILES.items():
        rows.append((f"walk_{direction}", load_frames(args.source / filename)))

    # PixelLab did not provide a north-west source. Mirroring north-east keeps
    # the gait and silhouette coherent until a bespoke north-west GIF exists.
    rows.append(("walk_north_west", load_frames(args.source / WALK_FILES["north_east"], True)))

    for action, filename in ACTION_FILES.items():
        rows.append((action, load_frames(args.source / filename)))

    columns = max(len(frames) for _, frames in rows)
    atlas = Image.new("RGBA", (CELL_SIZE[0] * columns, CELL_SIZE[1] * len(rows)), (0, 0, 0, 0))
    metadata = {
        "cell_size": list(CELL_SIZE),
        "foot_anchor": list(FOOT_ANCHOR),
        "columns": columns,
        "animations": {},
    }
    for row, (name, frames) in enumerate(rows):
        for column, frame in enumerate(frames):
            atlas.alpha_composite(frame, (column * CELL_SIZE[0], row * CELL_SIZE[1]))
        metadata["animations"][name] = {
            "row": row,
            "frames": len(frames),
            "frame_duration": 0.26 if name.startswith("walk_") else 0.2,
            "loop": name.startswith("walk_"),
        }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output, optimize=True)
    args.metadata.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
