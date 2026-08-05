from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "assets" / "characters" / "maya" / "npc"
OUTPUT_DIR = ROOT / "artifacts" / "maya_npc_animation" / "previews"
CELL = 256
SCALE = 2
BACKGROUND = (5, 12, 22, 255)

SHEETS = {
    "maya_walk_4dir.png": [
        ("walk_down", 0, 130),
        ("walk_left", 1, 130),
        ("walk_right", 2, 130),
        ("walk_up", 3, 130),
    ],
    "maya_instrument_actions.png": [
        ("instrument_assembly", 0, 190),
        ("instrument_telescope", 1, 210),
        ("instrument_console", 2, 180),
        ("instrument_journal", 3, 210),
    ],
    "maya_coop_actions.png": [
        ("coop_support_tube", 0, 190),
        ("coop_hand_over_part", 1, 200),
        ("coop_collimation", 2, 200),
        ("coop_success", 3, 230),
    ],
}


def frame_on_dark(sheet: Image.Image, column: int, row: int) -> Image.Image:
    frame = sheet.crop((column * CELL, row * CELL, (column + 1) * CELL, (row + 1) * CELL))
    canvas = Image.new("RGBA", (CELL, CELL), BACKGROUND)
    canvas.alpha_composite(frame)
    return canvas.resize((CELL * SCALE, CELL * SCALE), Image.Resampling.NEAREST).convert("RGB")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    written = []
    for sheet_name, animations in SHEETS.items():
        with Image.open(SOURCE_DIR / sheet_name).convert("RGBA") as sheet:
            if sheet.size != (CELL * 4, CELL * 4):
                raise ValueError(f"Unexpected sheet dimensions for {sheet_name}: {sheet.size}")
            for name, row, duration in animations:
                frames = [frame_on_dark(sheet, column, row) for column in range(4)]
                output = OUTPUT_DIR / f"{name}.gif"
                frames[0].save(
                    output,
                    save_all=True,
                    append_images=frames[1:],
                    duration=[duration, duration, duration, duration + 80],
                    loop=0,
                    disposal=2,
                    optimize=False,
                )
                written.append(output)
    print(f"Wrote {len(written)} Maya animation previews to {OUTPUT_DIR}")
    for output in written:
        print(output)


if __name__ == "__main__":
    main()
