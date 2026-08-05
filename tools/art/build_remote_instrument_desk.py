#!/usr/bin/env python3
"""Build the lower-right observatory desk and its depth layers.

The supplied source is copied into the repository unchanged. This script then:
1. clears the old baked terminal with a tile-aligned sample of the hall floor;
2. composites the supplied desk at a uniform scale;
3. emits a foreground-only alpha layer for the tabletop/front cabinet.
"""

from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(r"C:\Users\tntsg\Downloads\tw\ChatGPT Image 2026年7月25日 20_35_11.png")
ASSET_DIR = ROOT / "assets" / "reference" / "observatory_furniture"
SOURCE_COPY = ASSET_DIR / "remote_instrument_desk_source.png"
CLEAN_DESK = ASSET_DIR / "remote_instrument_desk_clean.png"
FOREGROUND = ASSET_DIR / "remote_instrument_desk_foreground.png"
HALL_SOURCE = ROOT / "assets" / "reference" / "observatory_room_hall_1024.png"
HALL_OUTPUT = ROOT / "assets" / "reference" / "observatory_room_hall_remote_desk_1024.png"

TARGET_POSITION = (754, 516)
TARGET_WIDTH = 201
OLD_TERMINAL_CLEAR_RECT = (774, 520, 958, 660)
FLOOR_TILE_RECT = (309, 315, 357, 363)
FOREGROUND_SOURCE_Y = 108
FLOOR_BLEND_EDGE = 10


def _require_transparent_source(image: Image.Image) -> None:
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] != 0:
        raise RuntimeError("The supplied desk has no transparent background.")
    corners = (
        image.getpixel((0, 0))[3],
        image.getpixel((image.width - 1, 0))[3],
        image.getpixel((0, image.height - 1))[3],
        image.getpixel((image.width - 1, image.height - 1))[3],
    )
    if max(corners) > 4:
        raise RuntimeError(f"Desk corners are not transparent: {corners}")


def _tile_floor(hall: Image.Image, rect: tuple[int, int, int, int]) -> None:
    tile = hall.crop(FLOOR_TILE_RECT)
    left, top, right, bottom = rect
    source_left, source_top, _source_right, _source_bottom = FLOOR_TILE_RECT
    tile_pixels = tile.load()
    patch = Image.new("RGBA", (right - left, bottom - top))
    patch_pixels = patch.load()
    # Keep the room's global 48 px floor-grid phase. Starting a fresh tile at
    # the clear rectangle edge produces the conspicuous checkerboard seam that
    # this replacement is specifically meant to avoid.
    for y in range(top, bottom):
        tile_y = (y - source_top) % tile.height
        for x in range(left, right):
            tile_x = (x - source_left) % tile.width
            red, green, blue, _alpha = tile_pixels[tile_x, tile_y]
            edge_distance = min(x - left, right - 1 - x, y - top, bottom - 1 - y)
            blend = min(1.0, max(0.0, edge_distance / float(FLOOR_BLEND_EDGE)))
            blend = blend * blend * (3.0 - 2.0 * blend)
            patch_pixels[x - left, y - top] = (red, green, blue, round(255 * blend))
    hall.alpha_composite(patch, (left, top))


def main() -> None:
    if not SOURCE.exists():
        raise FileNotFoundError(SOURCE)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SOURCE, SOURCE_COPY)

    desk = Image.open(SOURCE_COPY).convert("RGBA")
    _require_transparent_source(desk)
    desk.save(CLEAN_DESK, optimize=True)

    foreground = desk.copy()
    pixels = foreground.load()
    for y in range(FOREGROUND_SOURCE_Y):
        for x in range(foreground.width):
            red, green, blue, _alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 0)
    foreground.save(FOREGROUND, optimize=True)

    hall = Image.open(HALL_SOURCE).convert("RGBA")
    _tile_floor(hall, OLD_TERMINAL_CLEAR_RECT)

    scale = TARGET_WIDTH / float(desk.width)
    target_height = round(desk.height * scale)
    resized = desk.resize((TARGET_WIDTH, target_height), Image.Resampling.LANCZOS)
    hall.alpha_composite(resized, TARGET_POSITION)
    hall.save(HALL_OUTPUT, optimize=True)

    print(f"source={SOURCE_COPY.relative_to(ROOT)}")
    print(f"desk={CLEAN_DESK.relative_to(ROOT)} size={desk.size}")
    print(f"foreground={FOREGROUND.relative_to(ROOT)} y>={FOREGROUND_SOURCE_Y}")
    print(f"hall={HALL_OUTPUT.relative_to(ROOT)} target={TARGET_POSITION} size={resized.size}")


if __name__ == "__main__":
    main()
