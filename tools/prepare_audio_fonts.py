"""Create original quiet ambience/footsteps and fetch OFL UI fonts."""

import math
from pathlib import Path
import random
import struct
import urllib.request
import wave

ROOT = Path(__file__).resolve().parents[1] / "godot" / "assets"


def write_wave(name, seconds, sample):
    path = ROOT / "audio" / name
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(22050)
        data = bytearray()
        for index in range(round(seconds * 22050)):
            value = max(-1.0, min(1.0, sample(index / 22050)))
            data.extend(struct.pack("<h", round(value * 32767)))
        output.writeframes(data)


def main():
    rng = random.Random(701)
    write_wave("footstep.wav", 0.19, lambda t: (
        rng.uniform(-1, 1) * 0.3 + math.sin(t * 2 * math.pi * 85) * 0.3
    ) * math.exp(-t * 30) * min(1, t * 500))
    # Periodic low harmonics avoid an audible seam when the file loops.
    write_wave("wind.wav", 12.0, lambda t: sum(
        math.sin(2 * math.pi * frequency * t + phase) * amplitude
        for frequency, phase, amplitude in ((41, 0, .025), (57, 1, .015), (73, 2, .012), (109, .2, .008))
    ) * (0.6 + 0.4 * math.sin(t * math.pi / 12) ** 2))
    font_folder = ROOT / "fonts"
    font_folder.mkdir(parents=True, exist_ok=True)
    for name in ("BarlowCondensed-Regular.ttf", "BarlowCondensed-SemiBold.ttf", "OFL.txt"):
        path = font_folder / name
        if not path.exists():
            url = "https://raw.githubusercontent.com/google/fonts/main/ofl/barlowcondensed/" + name
            with urllib.request.urlopen(url, timeout=60) as response:
                path.write_bytes(response.read())
    print("Original audio and OFL fonts ready.")


if __name__ == "__main__":
    main()
