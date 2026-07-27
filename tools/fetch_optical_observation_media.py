"""Download and prepare licensed optical-observation masters.
The source files are kept outside the runtime asset directory. Runtime PNGs
are restrained, square telescope views derived from the credited originals;
focus, seeing, drift, and sky conditions remain real-time Godot effects.
"""

from __future__ import annotations

import io
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "source_assets" / "optical_observation"
OUTPUT_DIR = ROOT / "assets" / "telescope_view" / "official"
USER_AGENT = "PixelObservatoryAssetPipeline/1.0 (educational astronomy game)"
CANVAS_SIZE = 1024

EXTENDED_FIELD_IDS = {
    "moon_crater_copernicus",
    "moon_mare_tranquillitatis",
    "moon_terminator",
    "albireo",
    "dumbbell_nebula",
    "ring_nebula",
    "lagoon_nebula",
    "crab_nebula",
    "sombrero_galaxy",
    "whirlpool_galaxy",
    "needle_galaxy",
    "m13",
    "pleiades",
    "double_cluster",
}

DEEP_SKY_SUBJECT_IDS = EXTENDED_FIELD_IDS - {
    "moon_crater_copernicus",
    "moon_mare_tranquillitatis",
    "moon_terminator",
}


SOURCES = {
    "mercury": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Mercury_in_color_-_Prockter07_centered.jpg/960px-Mercury_in_color_-_Prockter07_centered.jpg",
        "mode": "isolated",
        "mask_shape": "ellipse",
        "target_scale": 0.68,
        "alpha_low": 5,
        "alpha_high": 22,
    },
    "venus": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Venus-real_color.jpg/960px-Venus-real_color.jpg",
        "mode": "crescent",
        "mask_shape": "ellipse",
        "target_scale": 0.64,
        "alpha_low": 5,
        "alpha_high": 24,
    },
    "saturn": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e3/Saturn_from_Cassini_Orbiter_%282004-10-06%29.jpg/960px-Saturn_from_Cassini_Orbiter_%282004-10-06%29.jpg",
        "mode": "isolated",
        "mask_shape": "source",
        "target_scale": 0.72,
        "alpha_low": 3,
        "alpha_high": 18,
    },
    "uranus": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2c/Uranus_-_Voyager_2.jpg/960px-Uranus_-_Voyager_2.jpg",
        "mode": "isolated",
        "mask_shape": "ellipse",
        "target_scale": 0.64,
        "alpha_low": 12,
        "alpha_high": 30,
        "bbox_threshold": 28,
        "bbox_pad": 0.055,
    },
    "neptune": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Neptune_Full.jpg/960px-Neptune_Full.jpg",
        "mode": "isolated",
        "mask_shape": "ellipse",
        "target_scale": 0.64,
        "alpha_low": 5,
        "alpha_high": 24,
    },
    "moon_crater_copernicus": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6b/Copernicus_%28LRO%29.png/960px-Copernicus_%28LRO%29.png",
        "mode": "field",
        "brightness": 0.70,
        "saturation": 0.10,
    },
    "moon_mare_tranquillitatis": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/9/9e/Mare_Tranquillitatis_%28LRO%29.png/960px-Mare_Tranquillitatis_%28LRO%29.png",
        "mode": "field",
        "brightness": 0.66,
        "saturation": 0.05,
    },
    "moon_terminator": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e5/Lunar_Terminator_%28LROC1126_-_content_M1321388053_LRmos_warp_str01_square_crop_1100pix%29.png/960px-Lunar_Terminator_%28LROC1126_-_content_M1321388053_LRmos_warp_str01_square_crop_1100pix%29.png",
        "mode": "field",
        "brightness": 0.68,
        "saturation": 0.05,
    },
    "albireo": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/5/56/Albireo_double_star.jpg/960px-Albireo_double_star.jpg",
        "mode": "field",
        "brightness": 0.76,
        "saturation": 0.72,
    },
    "pleiades": {
        "url": "https://cdn.eso.org/images/screen/b11.jpg",
        "mode": "field",
        "brightness": 0.62,
        "saturation": 0.46,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.94,
        },
    },
    "m13": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Hubble_image_of_globular_cluster_M13_%28opo0840a%29.jpg/960px-Hubble_image_of_globular_cluster_M13_%28opo0840a%29.jpg",
        "mode": "field",
        "brightness": 0.58,
        "saturation": 0.38,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.94,
        },
    },
    "ring_nebula": {
        "url": "https://noirlab.edu/public/media/archives/images/screen/noao-m57.jpg",
        "mode": "field",
        "brightness": 0.60,
        "saturation": 0.55,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.92,
        },
    },
    "lagoon_nebula": {
        "url": "https://cdn.eso.org/images/screen/potw1016a.jpg",
        "mode": "field",
        "brightness": 0.53,
        "saturation": 0.48,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.94,
        },
    },
    "sombrero_galaxy": {
        "url": "https://cdn.eso.org/images/screen/sombrero.jpg",
        "mode": "field",
        "brightness": 0.98,
        "saturation": 0.82,
        "contrast": 1.22,
        "gamma": 0.68,
        "warm_highlights": 0.52,
        "sharpen": 1.0,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.52),
            "scale": 0.92,
        },
    },
    "crab_nebula": {
        "url": "https://cdn.eso.org/images/screen/potw1523a.jpg",
        "mode": "field",
        "brightness": 0.54,
        "saturation": 0.46,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.94,
        },
    },
    "dumbbell_nebula": {
        "url": "https://cdn.eso.org/images/screen/eso9846a.jpg",
        "mode": "field",
        "brightness": 0.57,
        "saturation": 0.50,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.92,
        },
    },
    "double_cluster": {
        "url": "https://cdn.eso.org/images/screen/b02.jpg",
        "mode": "field",
        "brightness": 0.60,
        "saturation": 0.42,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.94,
        },
    },
    "whirlpool_galaxy": {
        "url": "https://assets.science.nasa.gov/dynamicimage/assets/science/missions/hubble/releases/2005/04/STScI-01EVT85S0E93YAFY779MNYA9Y4.tif?w=2000",
        "mode": "field",
        "brightness": 0.58,
        "saturation": 0.46,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.88,
        },
    },
    "needle_galaxy": {
        "url": "https://cdn.eso.org/images/screen/eso0525a.jpg",
        "mode": "field",
        "brightness": 0.55,
        "saturation": 0.30,
        "crop": {
            "fit": "cover",
            "centering": (0.50, 0.50),
            "scale": 0.90,
        },
    },
}


def download(url: str, destination: Path) -> None:
	if destination.exists() and destination.stat().st_size > 1024:
		return
	request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
	for attempt in range(4):
		try:
			with urllib.request.urlopen(request, timeout=90) as response:
				destination.write_bytes(response.read())
			return
		except urllib.error.HTTPError as error:
			if error.code != 429 or attempt == 3:
				raise
			time.sleep(12.0 * (attempt + 1))


def source_extension(url: str) -> str:
    suffix = Path(urllib.parse.unquote(url.split("?", 1)[0])).suffix.lower()
    return suffix if suffix in {".jpg", ".jpeg", ".png", ".tif", ".tiff"} else ".img"


def open_rgb(path: Path) -> Image.Image:
    image = Image.open(path)
    image.seek(0)
    image = ImageOps.exif_transpose(image).convert("RGB")
    return image


def _brightest_channel(image: Image.Image) -> Image.Image:
    red, green, blue = image.convert("RGB").split()
    return ImageChops.lighter(ImageChops.lighter(red, green), blue)


def _soft_threshold(image: Image.Image, low: int, high: int) -> Image.Image:
    span = max(1, high - low)
    return image.point(
        lambda value: 0
        if value <= low
        else 255
        if value >= high
        else int((value - low) * 255 / span)
    )


def _padded_bbox(
    mask: Image.Image, threshold: int, pad_ratio: float
) -> tuple[int, int, int, int]:
    hard_mask = mask.point(lambda value: 255 if value >= threshold else 0)
    bbox = hard_mask.getbbox() or (0, 0, mask.width, mask.height)
    left, top, right, bottom = bbox
    pad = int(max(right - left, bottom - top) * pad_ratio)
    return (
        max(0, left - pad),
        max(0, top - pad),
        min(mask.width, right + pad),
        min(mask.height, bottom + pad),
    )


def _square_bbox(
    bbox: tuple[int, int, int, int], image_size: tuple[int, int]
) -> tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    image_width, image_height = image_size
    side = min(max(right - left, bottom - top), image_width, image_height)
    center_x = (left + right) * 0.5
    center_y = (top + bottom) * 0.5
    square_left = int(round(center_x - side * 0.5))
    square_top = int(round(center_y - side * 0.5))
    square_left = max(0, min(square_left, image_width - side))
    square_top = max(0, min(square_top, image_height - side))
    return (
        square_left,
        square_top,
        square_left + side,
        square_top + side,
    )


def _ellipse_alpha(size: tuple[int, int], feather: float = 1.5) -> Image.Image:
    mask = Image.new("L", size, 0)
    inset = max(1, int(feather * 2.0))
    ImageDraw.Draw(mask).ellipse(
        (inset, inset, size[0] - inset - 1, size[1] - inset - 1),
        fill=255,
    )
    return mask.filter(ImageFilter.GaussianBlur(feather))


def isolated_target(image: Image.Image, config: dict) -> Image.Image:
    signal = _brightest_channel(image)
    alpha = _soft_threshold(
        signal,
        int(config.get("alpha_low", 5)),
        int(config.get("alpha_high", 22)),
    )
    bbox = _padded_bbox(
        alpha,
        int(config.get("bbox_threshold", 20)),
        float(config.get("bbox_pad", 0.045)),
    )
    if config.get("mask_shape", "source") == "ellipse":
        bbox = _square_bbox(bbox, image.size)
    subject = image.crop(bbox).convert("RGBA")
    source_alpha = alpha.crop(bbox)
    if config.get("mask_shape", "source") == "ellipse":
        source_alpha = _ellipse_alpha(subject.size, 1.5)
    else:
        source_alpha = source_alpha.filter(ImageFilter.GaussianBlur(0.8))
    subject.putalpha(source_alpha)

    side = int(CANVAS_SIZE * float(config.get("target_scale", 0.68)))
    subject.thumbnail((side, side), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(
        subject,
        ((CANVAS_SIZE - subject.width) // 2, (CANVAS_SIZE - subject.height) // 2),
    )
    return canvas


def crescent_target(image: Image.Image, config: dict) -> Image.Image:
    disk = isolated_target(image, config)
    alpha = disk.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        return disk
    left, top, right, bottom = bbox
    width = right - left
    occluder = Image.new("L", disk.size, 0)
    ImageDraw.Draw(occluder).ellipse(
        (
            left + int(width * 0.27),
            top,
            right + int(width * 0.27),
            bottom,
        ),
        fill=255,
    )
    occluder = occluder.filter(ImageFilter.GaussianBlur(1.4))
    # A phase shadow removes reflected light, not the planet's physical
    # silhouette. Keep the full disk opaque so background stars cannot shine
    # through the night side, and darken only the RGB channels.
    shadow = Image.new("RGBA", disk.size, (2, 3, 7, 255))
    phased = Image.composite(shadow, disk, occluder)
    phased.putalpha(alpha)
    return phased


def field_target(image: Image.Image, crop: dict | None = None) -> Image.Image:
    crop = crop or {}
    centering = tuple(crop.get("centering", (0.5, 0.5)))
    return ImageOps.fit(
        image.convert("RGBA"),
        (CANVAS_SIZE, CANVAS_SIZE),
        method=Image.Resampling.LANCZOS,
        centering=(float(centering[0]), float(centering[1])),
    )


def deep_sky_subject(image: Image.Image, config: dict) -> Image.Image:
    """Separate real astronomical structure from the photo's rectangular sky.

    This is deliberately not an edge feather or eyepiece mask. Alpha follows
    measured source luminance across the whole frame, so stars, galaxy arms,
    and nebular gas remain while the rectangular photograph background does
    not exist at runtime. The one circular field stop remains in Godot.
    """

    rgba = image.convert("RGBA")
    signal = _brightest_channel(rgba.convert("RGB"))
    histogram = signal.histogram()
    pixel_count = max(1, signal.width * signal.height)

    def percentile(fraction: float) -> int:
        threshold = int(pixel_count * fraction)
        running = 0
        for value, count in enumerate(histogram):
            running += count
            if running >= threshold:
                return value
        return 255

    low = int(config.get("field_alpha_low", percentile(0.16)))
    high = int(config.get("field_alpha_high", percentile(0.78)))
    high = max(low + 18, high)
    alpha = _soft_threshold(signal, low, high)
    # A sub-linear curve preserves genuinely faint outer arms and gas while
    # keeping measured background pixels at zero.
    alpha = alpha.point(lambda value: int(255.0 * (value / 255.0) ** 0.72))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.55))
    rgba.putalpha(alpha)
    return rgba


def restrained_telescope_tone(
    image: Image.Image, config: dict
) -> Image.Image:
    source = image.convert("RGBA")
    alpha = source.getchannel("A")
    rgb = source.convert("RGB")
    rgb = ImageEnhance.Contrast(rgb).enhance(float(config.get("contrast", 0.92)))
    rgb = ImageEnhance.Color(rgb).enhance(float(config.get("saturation", 0.72)))
    gamma = float(config.get("gamma", 1.0))
    if abs(gamma - 1.0) > 0.001:
        lut = [
            int(max(0.0, min(1.0, (value / 255.0) ** gamma)) * 255)
            for value in range(256)
        ]
        rgb = rgb.point(lut * 3)
    rgb = ImageEnhance.Brightness(rgb).enhance(float(config.get("brightness", 0.82)))
    if float(config.get("warm_highlights", 0.0)) > 0.0:
        gray = ImageOps.grayscale(rgb)
        warm = ImageOps.colorize(
            gray,
            black=(1, 3, 8),
            mid=(132, 104, 78),
            white=(255, 218, 170),
            midpoint=112,
        )
        rgb = Image.blend(rgb, warm, float(config["warm_highlights"]))
    if float(config.get("sharpen", 0.0)) > 0.0:
        rgb = rgb.filter(ImageFilter.UnsharpMask(radius=2.0, percent=115, threshold=3))
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def main() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for index, (object_id, config) in enumerate(SOURCES.items()):
        url = config["url"]
        source_path = SOURCE_DIR / f"{object_id}{source_extension(url)}"
        print(f"[{index + 1:02d}/{len(SOURCES):02d}] {object_id}")
        download(url, source_path)
        image = open_rgb(source_path)
        mode = config["mode"]
        if mode == "isolated":
            prepared = isolated_target(image, config)
        elif mode == "crescent":
            prepared = crescent_target(image, config)
        else:
            crop = dict(config.get("crop") or {})
            if object_id in EXTENDED_FIELD_IDS:
                # Keep the science master sharp and cover-cropped. Godot owns
                # the one radial eyepiece mask; baking a rectangular feather
                # here only creates a soft-edged box.
                crop["fit"] = "cover"
            prepared = field_target(image, crop)
        prepared = restrained_telescope_tone(prepared, config)
        if object_id in DEEP_SKY_SUBJECT_IDS:
            prepared = deep_sky_subject(prepared, config)
        prepared.save(OUTPUT_DIR / f"{object_id}.png", optimize=True)
        time.sleep(0.2)


if __name__ == "__main__":
    main()
