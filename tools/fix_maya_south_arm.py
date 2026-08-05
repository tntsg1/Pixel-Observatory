from pathlib import Path

from PIL import Image


SOURCE = Path(r"C:\Users\tntsg\Downloads\Idle_walk_south (1).gif")
OUTPUT = Path(r"E:\godot\ai-game-0628\artifacts\maya_npc_animation\user_gif_review\Idle_walk_south_left_arm_fixed.gif")
DOWNLOAD_COPY = Path(r"C:\Users\tntsg\Downloads\Idle_walk_south_left_arm_fixed.gif")

# Maya's left arm is on the viewer's right in the south-facing animation.
# The two walking extremes move it in opposite directions while the middle
# frames keep the supplied neutral pose.
ARM_BOX = (52, 39, 56, 52)
Y_OFFSETS = (0, -1, -2, 0, 1, 2)


def move_arm(frame: Image.Image, y_offset: int) -> Image.Image:
    if y_offset == 0:
        return frame.copy()

    result = frame.copy()
    background = frame.getpixel((0, 0))
    arm = frame.crop(ARM_BOX)
    mask = Image.new("L", arm.size, 0)
    mask_pixels = mask.load()
    arm_pixels = arm.load()

    for y in range(arm.height):
        for x in range(arm.width):
            if arm_pixels[x, y][:3] != background[:3]:
                mask_pixels[x, y] = 255

    clear = Image.new("RGBA", arm.size, background)
    result.paste(clear, ARM_BOX[:2], mask)
    result.paste(arm, (ARM_BOX[0], ARM_BOX[1] + y_offset), mask)
    return result


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE) as source:
        if source.size != (92, 92) or source.n_frames != 6:
            raise ValueError(f"Unexpected source GIF: {source.size}, {source.n_frames} frames")

        frames = []
        durations = []
        for index, offset in enumerate(Y_OFFSETS):
            source.seek(index)
            frames.append(move_arm(source.convert("RGBA"), offset).convert("RGB"))
            durations.append(source.info.get("duration", 200) or 200)

    frames[0].save(
        OUTPUT,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        disposal=2,
        optimize=False,
    )
    DOWNLOAD_COPY.write_bytes(OUTPUT.read_bytes())
    print(OUTPUT)
    print(DOWNLOAD_COPY)


if __name__ == "__main__":
    main()
