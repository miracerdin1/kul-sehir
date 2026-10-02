"""Synthesizes Kül Şehir's glass-break and armoured-vehicle engine sounds (no recordings).

    python tools/make_sounds.py

Writes godot/assets/audio/glass_break_1..3.ogg and godot/assets/audio/tank_engine.ogg.
Pure Python with fixed seeds; ffmpeg (with libvorbis) turns the WAVs into Ogg, which
stays out of Git LFS (*.wav is LFS-tracked in this repo).
"""
import math
import subprocess
import tempfile
import random
import struct
import wave
from pathlib import Path

RATE = 44100
OUT = Path(__file__).resolve().parent.parent / "godot" / "assets" / "audio"


def write(name, samples):
    peak = max(1e-9, max(abs(value) for value in samples))
    gain = 0.89 / peak
    temporary = Path(tempfile.gettempdir()) / name.replace(".ogg", ".wav")
    with wave.open(str(temporary), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(b"".join(struct.pack("<h", int(value * gain * 32767)) for value in samples))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(temporary), "-c:a", "libvorbis", "-q:a", "6", str(OUT / name)], check=True)
    temporary.unlink()


def biquad(samples, kind, frequency, q):
    """RBJ cookbook band-pass / high-pass / low-pass."""
    w = 2.0 * math.pi * frequency / RATE
    alpha = math.sin(w) / (2.0 * q)
    cos = math.cos(w)
    if kind == "band":
        b = (alpha, 0.0, -alpha)
    elif kind == "high":
        b = ((1 + cos) / 2, -(1 + cos), (1 + cos) / 2)
    else:
        b = ((1 - cos) / 2, 1 - cos, (1 - cos) / 2)
    a0, a1, a2 = 1 + alpha, -2 * cos, 1 - alpha
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for x in samples:
        y = (b[0] * x + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2) / a0
        out.append(y)
        x2, x1, y2, y1 = x1, x, y1, y
    return out


def glass(seed):
    """A pane giving way: a sharp crack, the bright crash of the sheet breaking, then
    shards ringing as they break off and land, thinning out over about a second."""
    rng = random.Random(seed)
    length = int(RATE * 1.25)
    out = [0.0] * length
    noise = [rng.uniform(-1, 1) for _ in range(length)]
    crack = biquad(noise, "high", 1800, 0.7)
    body = biquad(biquad(noise, "band", 4200 + rng.uniform(-600, 600), 0.6), "high", 1200, 0.7)
    for index in range(length):
        t = index / RATE
        out[index] += crack[index] * math.exp(-t / 0.005) * 1.4
        attack = min(1.0, t / 0.003)
        out[index] += body[index] * attack * (math.exp(-t / 0.075) * 0.9 + math.exp(-t / 0.35) * 0.12)
        # The sheet flexing just before it fails: a short low knock.
        out[index] += math.sin(2 * math.pi * 160 * t) * math.exp(-t / 0.018) * 0.35
    grains = []
    for _ in range(46):
        grains.append((rng.expovariate(1 / 0.045), rng.uniform(0.12, 0.35)))
    for _ in range(38):
        start = rng.uniform(0.16, 1.0)
        grains.append((start, rng.uniform(0.05, 0.22) * (1.15 - start)))
    # Falling shards often land in little clusters.
    for _ in range(5):
        centre = rng.uniform(0.25, 0.8)
        for _ in range(rng.randint(3, 6)):
            grains.append((centre + rng.uniform(0, 0.04), rng.uniform(0.06, 0.18) * (1.1 - centre)))
    for start, level in grains:
        base = rng.uniform(2300, 7800)
        partials = [(base, 1.0), (base * rng.uniform(2.6, 2.9), 0.55), (base * rng.uniform(4.9, 5.6), 0.3)]
        decay = rng.uniform(0.008, 0.03)
        first = int(start * RATE)
        span = int(decay * 7 * RATE)
        phases = [rng.uniform(0, 2 * math.pi) for _ in partials]
        for offset in range(span):
            index = first + offset
            if index >= length:
                break
            t = offset / RATE
            envelope = math.exp(-t / decay) * min(1.0, t / 0.0004)
            value = sum(amp * math.sin(2 * math.pi * f * t + phase) for (f, amp), phase in zip(partials, phases))
            click = noise[index] * math.exp(-t / 0.0006) * 0.6
            out[index] += (value * 0.5 + click) * envelope * level
    # A small room: two short early reflections.
    for delay, gain in ((0.019, 0.22), (0.031, 0.16), (0.047, 0.1)):
        step = int(delay * RATE)
        for index in range(length - 1, step - 1, -1):
            out[index] += out[index - step] * gain
    fade = int(0.05 * RATE)
    for index in range(fade):
        out[length - 1 - index] *= index / fade
    return out


def engine():
    """A two-second seamless loop: V12 diesel idle rumble with firing pulses, an exhaust
    hiss and track links clanking over the sprockets. Pitch it up with speed in game."""
    rng = random.Random(9)
    length = RATE * 2
    firing = 31.0  # 62 whole cycles in the loop
    out = [0.0] * length
    for harmonic in range(1, 16):
        amp = 1.0 / harmonic ** 0.85 * (1.3 if harmonic in (2, 4, 6) else 1.0)
        phase = rng.uniform(0, 2 * math.pi)
        for index in range(length):
            t = index / RATE
            out[index] += amp * math.sin(2 * math.pi * firing * harmonic * t + phase)
    # Firing pulses: the rumble swells 62 times a loop with a little unevenness.
    jitter = [rng.uniform(0.75, 1.0) for _ in range(62)]
    for index in range(length):
        cycle = index * 62 // length
        within = (index * 62 / length) % 1.0
        out[index] *= 0.55 + 0.45 * jitter[cycle] * math.exp(-within * 3.0)
    # The filtered noise runs past the loop end; that tail is folded into the start,
    # so the end flows straight on into the first sample.
    blend = int(0.05 * RATE)
    noise = [rng.uniform(-1, 1) for _ in range(length + blend)]
    rumble = biquad(biquad(noise, "low", 260, 0.7), "low", 260, 0.7)
    hiss = biquad(noise, "band", 1400, 0.5)
    texture = [rumble[index] * 1.6 + hiss[index] * 0.05 for index in range(length + blend)]
    for index in range(blend):
        weight = index / blend
        texture[index] = texture[index] * weight + texture[length + index] * (1 - weight)
    for index in range(length):
        out[index] = out[index] * 0.18 + texture[index]
    # Track links: 16 metallic clanks per loop.
    for clank in range(16):
        first = int((clank + rng.uniform(-0.12, 0.12)) * length / 16) % length
        tone = rng.uniform(700, 1500)
        for offset in range(int(0.06 * RATE)):
            t = offset / RATE
            value = (math.sin(2 * math.pi * tone * t) + 0.5 * math.sin(2 * math.pi * tone * 2.76 * t)) * math.exp(-t / 0.012)
            out[(first + offset) % length] += value * 0.09
    return out


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for number, seed in enumerate((11, 23, 37), start=1):
        write("glass_break_%d.ogg" % number, glass(seed))
    write("tank_engine.ogg", engine())
    print("Wrote glass_break_1..3.ogg and tank_engine.ogg to " + str(OUT))
