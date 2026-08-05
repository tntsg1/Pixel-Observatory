"""Build localized main-menu runtime art without cropping or distortion."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "main_menu" / "main_menu_bg_zh_source.png"
OUTPUT = ROOT / "assets" / "main_menu" / "main_menu_bg_zh_1024.png"
CANVAS_SIZE = (1024, 768)


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    scale = min(CANVAS_SIZE[0] / source.width, CANVAS_SIZE[1] / source.height)
    fitted_size = (
        round(source.width * scale),
        round(source.height * scale),
    )
    fitted = source.resize(fitted_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", CANVAS_SIZE, (0, 0, 0))
    offset = (
        (CANVAS_SIZE[0] - fitted_size[0]) // 2,
        (CANVAS_SIZE[1] - fitted_size[1]) // 2,
    )
    canvas.paste(fitted, offset)
    canvas.save(OUTPUT, optimize=True)
    print(
        f"built {OUTPUT} from {source.size[0]}x{source.size[1]} "
        f"at {fitted_size[0]}x{fitted_size[1]}, offset={offset}"
    )


if __name__ == "__main__":
    main()
