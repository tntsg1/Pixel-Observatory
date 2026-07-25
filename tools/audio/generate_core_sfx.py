"""Generate small original placeholder SFX for Pixel Observatory.

These are deliberately layered, short instrument cues rather than copied or
downloaded samples. Replace individual WAVs with licensed final recordings
without changing the game's event mapping.
"""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


RATE = 48000
ROOT = Path(__file__).resolve().parents[2] / "assets" / "audio" / "sfx"


def env(t: float, attack: float, release: float, length: float) -> float:
    if t < attack:
        return t / attack
    return max(0.0, 1.0 - (t - attack) / max(0.001, length - attack)) ** release


def render(name: str, length: float, layers: list[tuple[float, float, float, float]], noise: float = 0.0) -> None:
    """layers: frequency, gain, decay, detune."""
    rng = random.Random(name)
    samples: list[int] = []
    count = int(length * RATE)
    for index in range(count):
        t = index / RATE
        value = 0.0
        for frequency, gain, decay, detune in layers:
            phase = math.tau * (frequency * t + detune * t * t)
            value += math.sin(phase) * gain * math.exp(-t / decay)
        if noise > 0.0:
            value += rng.uniform(-1.0, 1.0) * noise * math.exp(-t / max(0.015, length * 0.22))
        # Gentle saturation keeps these compact UI cues from clipping harshly.
        value = math.tanh(value * 1.35) * 0.72
        samples.append(int(max(-1.0, min(1.0, value)) * 32767))
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(struct.pack("<%dh" % len(samples), *samples))


def main() -> None:
    render("ui_confirm_01.wav", 0.18, [(880, 0.34, 0.10, 0), (1320, 0.15, 0.08, 0)], 0.015)
    render("ui_confirm_02.wav", 0.20, [(740, 0.30, 0.11, 0), (1110, 0.16, 0.09, 0)], 0.018)
    render("ui_confirm_03.wav", 0.17, [(980, 0.30, 0.09, 0), (1470, 0.13, 0.07, 0)], 0.012)
    render("ui_adjust.wav", 0.10, [(540, 0.24, 0.045, 0), (980, 0.08, 0.035, 0)], 0.025)
    render("ui_error.wav", 0.22, [(190, 0.34, 0.16, -90), (145, 0.18, 0.13, -55)], 0.020)
    render("assembly_snap.wav", 0.38, [(120, 0.38, 0.20, 0), (460, 0.23, 0.16, 0), (1030, 0.10, 0.08, 0)], 0.090)
    render("focus_lock.wav", 0.34, [(420, 0.18, 0.18, 55), (840, 0.18, 0.14, 0), (1260, 0.11, 0.09, 0)], 0.018)
    render("target_lock.wav", 0.46, [(220, 0.22, 0.30, 130), (660, 0.16, 0.22, 42), (980, 0.12, 0.15, 0)], 0.020)
    render("space_lock.wav", 0.64, [(180, 0.24, 0.48, 0), (360, 0.15, 0.30, 0), (920, 0.08, 0.18, 0)], 0.012)
    render("fast_signal.wav", 0.72, [(94, 0.22, 0.50, 0), (376, 0.13, 0.34, 0), (752, 0.08, 0.24, 0)], 0.040)


if __name__ == "__main__":
    main()
