"""Build compact, transparent sky-acquisition thumbnails from source art.

The telescope-view images remain untouched. This script only prepares a
small target signature whose real morphology survives a 40 px finder view.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "assets" / "celestial_icons" / "deep_sky"
SIZE = 128


def smoothstep(edge0: float, edge1: float, value: np.ndarray) -> np.ndarray:
    amount = np.clip((value - edge0) / max(edge1 - edge0, 1e-6), 0.0, 1.0)
    return amount * amount * (3.0 - 2.0 * amount)


def object_index() -> dict[str, dict]:
    result: dict[str, dict] = {}
    for relative in (
        "data/celestial_objects.json",
        "data/expansion/celestial_objects.json",
    ):
        for item in json.loads((ROOT / relative).read_text(encoding="utf-8")):
            result[item["id"]] = item
    return result


def crop_source(source: Image.Image, focus: tuple[float, float], zoom: float) -> Image.Image:
    width, height = source.size
    side = max(8, int(min(width, height) / max(zoom, 1.0)))
    center_x = int(width * focus[0])
    center_y = int(height * focus[1])
    left = center_x - side // 2
    top = center_y - side // 2
    return source.crop((left, top, left + side, top + side))


def build_thumbnail(item: dict) -> Path:
    source_uri = item.get("sky_icon_source_path", item["sky_icon_path"])
    source_path = ROOT / source_uri.removeprefix("res://")
    source = Image.open(source_path).convert("RGBA")
    focus_values = item.get("sky_icon_focus", [0.5, 0.5])
    focus = (float(focus_values[0]), float(focus_values[1]))
    zoom = float(item.get("sky_icon_zoom", 1.0))
    crop = crop_source(source, focus, zoom).resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    pixels = np.asarray(crop, dtype=np.float32) / 255.0
    rgb = pixels[..., :3]
    source_alpha = pixels[..., 3]
    peak = rgb.max(axis=2)
    luminance = np.sum(rgb * np.array([0.2126, 0.7152, 0.0722]), axis=2)
    saturation = float(item.get("sky_icon_saturation", 0.58))
    exposure = float(item.get("sky_icon_exposure", 1.45))
    neutral = np.repeat(luminance[..., None], 3, axis=2)
    rgb = np.clip((neutral * (1.0 - saturation) + rgb * saturation) * exposure, 0.0, 1.0)

    black_point = float(item.get("sky_icon_black_point", 0.018))
    soft_edge = float(item.get("sky_icon_soft_edge", 0.16))
    alpha = smoothstep(black_point, black_point + soft_edge, peak) * source_alpha

    axis = np.linspace(-1.0, 1.0, SIZE, dtype=np.float32)
    x_grid = axis[None, :].repeat(SIZE, axis=0)
    y_grid = axis[:, None].repeat(SIZE, axis=1)
    radius = np.sqrt(x_grid * x_grid + y_grid * y_grid)
    alpha *= 1.0 - smoothstep(0.72, 1.0, radius)

    result = np.dstack((rgb, np.clip(alpha, 0.0, 1.0)))
    output = OUTPUT_DIR / f"{item['id']}.png"
    Image.fromarray(np.uint8(np.round(result * 255.0)), "RGBA").save(output, optimize=True)
    return output


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    objects = object_index()
    targets = [item for item in objects.values() if "sky_icon_path" in item]
    for item in targets:
        output = build_thumbnail(item)
        print(output.relative_to(ROOT).as_posix())
    print(f"built {len(targets)} target thumbnails")


if __name__ == "__main__":
    main()
