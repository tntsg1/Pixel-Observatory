"""Extract pixel-identical furniture occluders from the observatory hall art."""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/reference/observatory_room_hall_1024.png"
OUTPUT = ROOT / "assets/reference/observatory_occluders"

# The polygons follow the painted outer brass/wood silhouettes. Only the
# furniture surfaces that can pass in front of the player's lower body are
# retained; the surrounding floor remains transparent.
SPECS = {
    "mission_desk": {
        "box": (681, 214, 886, 303),
        "polygon": [(7, 3), (198, 3), (204, 12), (204, 84), (197, 88), (7, 88), (0, 81), (0, 12)],
    },
    "assembly_table": {
        "box": (718, 323, 980, 464),
        "polygon": [(10, 4), (243, 4), (261, 20), (261, 136), (246, 140), (11, 140), (0, 132), (0, 20)],
    },
    "journal_desk": {
        "box": (67, 457, 272, 549),
        "polygon": [(6, 5), (170, 5), (204, 25), (204, 76), (168, 91), (5, 91), (0, 82), (0, 14)],
    },
    "computer_console": {
        "box": (773, 528, 958, 658),
        "polygon": [(12, 4), (161, 4), (184, 20), (184, 122), (172, 129), (4, 129), (0, 119), (0, 18)],
    },
    # The telescope pedestal is a physical foot blocker. Only the raised tube
    # needs to pass in front of a player walking behind the instrument.
    "central_telescope_tube": {
        "box": (458, 330, 583, 414),
        "polygon": [
            (4, 58), (10, 47), (22, 42), (64, 13), (81, 8),
            (94, 9), (100, 4), (113, 8), (122, 16), (124, 25),
            (119, 31), (111, 31), (101, 25), (92, 29), (49, 61),
            (42, 73), (31, 81), (20, 78), (12, 70),
        ],
    },
}


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, spec in SPECS.items():
        box = spec["box"]
        crop = source.crop(box)
        mask = Image.new("L", crop.size, 0)
        ImageDraw.Draw(mask).polygon(spec["polygon"], fill=255)
        crop.putalpha(mask)
        destination = OUTPUT / f"{name}.png"
        crop.save(destination, optimize=True)
        print(f"{name}: {box} -> {destination.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
