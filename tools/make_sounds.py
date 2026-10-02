"""Synthesizes Kül Şehir's glass-break and armoured-vehicle engine sounds (no recordings).

    python tools/make_sounds.py

<<<<<<< Updated upstream
Writes godot/assets/audio/glass_break_1..3.ogg, tank_engine.ogg, footstep_1..6.ogg (boots on
gritty concrete), gear_rattle.ogg (kit jostling while running), tank_cannon.ogg and heavy_mg.ogg.
=======
Writes godot/assets/audio/glass_break_1..3.ogg, tank_engine.ogg, tank_cannon.ogg,
heavy_mg.ogg and the boot steps step_walk_1..4.ogg / step_run_1..4.ogg.
>>>>>>> Stashed changes
Pure Python with fixed seeds; ffmpeg (with libvorbis) turns the WAVs into Ogg, which
stays out of Git LFS (*.wav is LFS-tracked in this repo). Without ffmpeg on the PATH
the copy bundled with the imageio-ffmpeg package is used.
"""
import math
import shutil
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
    subprocess.run([ffmpeg(), "-loglevel", "error", "-y", "-i", str(temporary), "-c:a", "libvorbis", "-q:a", "6", str(OUT / name)], check=True)
    temporary.unlink()


def ffmpeg():
    if shutil.which("ffmpeg"):
        return "ffmpeg"
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


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


<<<<<<< Updated upstream
def footstep(seed):
    """A boot on ash-covered concrete: heel strike, the sole rolling down a few
    centiseconds later, and the grit underfoot crunching between them."""
    rng = random.Random(seed)
    length = int(RATE * 0.32)
    noise = [rng.uniform(-1, 1) for _ in range(length)]
    thud = biquad(biquad(noise, "low", 520, 0.7), "low", 520, 0.7)
    scuff = biquad(biquad(noise, "band", rng.uniform(1600, 2600), 0.8), "high", 700, 0.7)
    out = [0.0] * length
    toe = rng.uniform(0.045, 0.075)
    low = rng.uniform(85, 120)
    for index in range(length):
        t = index / RATE
        heel = math.exp(-t / 0.011) * min(1.0, t / 0.0008)
        out[index] += thud[index] * heel * 2.4 + math.sin(2 * math.pi * low * t) * heel * 0.35
        if t >= toe:
            u = t - toe
            roll = math.exp(-u / 0.014) * min(1.0, u / 0.002)
            out[index] += thud[index] * roll * 1.3
        out[index] += scuff[index] * math.exp(-t / 0.045) * min(1.0, t / 0.004) * 0.32
    # Grit: tiny bright crackles while the weight comes down.
    for _ in range(rng.randint(14, 24)):
        first = int(rng.uniform(0.0, 0.13) * RATE)
        tone = rng.uniform(2500, 7000)
        level = rng.uniform(0.03, 0.12)
        for offset in range(int(0.006 * RATE)):
            index = first + offset
            if index >= length:
                break
            t = offset / RATE
            out[index] += (noise[(index * 7) % length] * 0.6 + math.sin(2 * math.pi * tone * t) * 0.4) * math.exp(-t / 0.0012) * level
=======
def noise(rng, count):
    return [rng.uniform(-1.0, 1.0) for _ in range(count)]


def step(seed, running):
    """One boot on gritty asphalt: the heel's dull thump and the sole slapping down a
    few hundredths later, grit crunching under it; running adds weight and the rattle
    of kit (magazines, buckles) and a cloth swish."""
    rng = random.Random(seed)
    length = int(RATE * (0.34 if running else 0.27))
    out = [0.0] * length
    weight = 1.0 if running else 0.55
    thump = rng.uniform(62.0, 88.0)
    toe = rng.uniform(0.028, 0.045) if running else rng.uniform(0.055, 0.08)
    slap = biquad(noise(rng, length), "band", rng.uniform(450.0, 750.0), 0.8)
    crunch = biquad(noise(rng, length), "high", 2600.0, 0.7)
    for index in range(length):
        t = index / RATE
        value = math.sin(2 * math.pi * thump * t) * math.exp(-t / 0.024) * weight
        value += slap[index] * (math.exp(-t / 0.014) + 0.8 * (math.exp(-(t - toe) / 0.018) if t > toe else 0.0)) * 1.6
        out[index] = value
    # Grit: tiny clicks scattered over the roll of the foot.
    for _ in range(rng.randint(22, 34)):
        start = int(RATE * rng.uniform(0.0, toe + 0.07))
        gain = rng.uniform(0.05, 0.22)
        for offset in range(int(RATE * 0.004)):
            if start + offset < length:
                out[start + offset] += crunch[start + offset] * gain * math.exp(-offset / (RATE * 0.0012))
    if running:
        for _ in range(rng.randint(3, 6)):
            start = int(RATE * rng.uniform(0.02, 0.14))
            tone = rng.uniform(2300.0, 4200.0)
            for offset in range(int(RATE * 0.05)):
                if start + offset < length:
                    t = offset / RATE
                    out[start + offset] += math.sin(2 * math.pi * tone * t) * math.exp(-t / 0.009) * rng.uniform(0.04, 0.08)
        swish = biquad(noise(rng, length), "band", 1800.0, 0.6)
        for index in range(length):
            t = index / RATE
            out[index] += swish[index] * 0.18 * math.sin(math.pi * min(1.0, t / 0.2)) ** 2
    fade = int(0.03 * RATE)
    for index in range(fade):
        out[length - 1 - index] *= index / fade
    return out


def echo(out, taps):
    """City slap-back: delayed, darker copies off the buildings."""
    dry = list(out)
    for delay, gain, cutoff in taps:
        shifted = [0.0] * int(delay * RATE) + biquad(dry, "low", cutoff, 0.7)
        for index in range(min(len(out), len(shifted))):
            out[index] += shifted[index] * gain
    return out


def cannon():
    """The tank's main gun: a hard crack, the blast's punch and a deep falling boom,
    then a long rumble with echoes rolling back off the streets."""
    rng = random.Random(125)
    length = int(RATE * 2.8)
    raw = noise(rng, length)
    crack = biquad(raw, "high", 1800.0, 0.7)
    blast = biquad(biquad(raw, "low", 1400.0, 0.7), "low", 1400.0, 0.7)
    rumble = biquad(biquad(noise(rng, length), "low", 180.0, 0.7), "low", 180.0, 0.7)
    out = [0.0] * length
    phase = 0.0
    for index in range(length):
        t = index / RATE
        phase += 2 * math.pi * (52.0 * math.exp(-t / 0.5) + 26.0) / RATE
        value = crack[index] * math.exp(-t / 0.007) * 1.2
        value += blast[index] * math.exp(-t / 0.08) * 2.4
        value += math.sin(phase) * math.exp(-t / 0.35) * 1.4
        value += rumble[index] * math.exp(-t / 0.9) * 5.0
        out[index] = value
    out = echo(out, [(0.21, 0.32, 1200.0), (0.47, 0.2, 800.0), (0.86, 0.12, 500.0)])
    fade = int(0.2 * RATE)
    for index in range(fade):
        out[length - 1 - index] *= index / fade
    return out


def heavy_mg():
    """One round of a heavy machine gun: a sharp crack, the receiver's bark and a short
    rumble. The game plays it once per round, so a burst sounds like a burst."""
    rng = random.Random(77)
    length = int(RATE * 0.42)
    raw = noise(rng, length)
    crack = biquad(raw, "high", 2400.0, 0.7)
    bark = biquad(raw, "band", 650.0, 0.9)
    tail = biquad(biquad(noise(rng, length), "low", 300.0, 0.7), "low", 300.0, 0.7)
    out = [0.0] * length
    for index in range(length):
        t = index / RATE
        value = crack[index] * math.exp(-t / 0.005) * 1.4
        value += bark[index] * math.exp(-t / 0.03) * 2.2
        value += math.sin(2 * math.pi * 105.0 * t) * math.exp(-t / 0.045) * 0.9
        value += tail[index] * math.exp(-t / 0.13) * 3.0
        out[index] = value
    out = echo(out, [(0.12, 0.22, 1500.0), (0.26, 0.12, 900.0)])
>>>>>>> Stashed changes
    fade = int(0.04 * RATE)
    for index in range(fade):
        out[length - 1 - index] *= index / fade
    return out


<<<<<<< Updated upstream
def gear_rattle(seed):
    """Webbing, magazines and a canteen jostling: a few soft knocks and metal ticks."""
    rng = random.Random(seed)
    length = int(RATE * 0.25)
    out = [0.0] * length
    noise = [rng.uniform(-1, 1) for _ in range(length)]
    cloth = biquad(noise, "band", 900, 0.6)
    for index in range(length):
        t = index / RATE
        out[index] += cloth[index] * math.exp(-t / 0.06) * min(1.0, t / 0.01) * 0.25
    for _ in range(rng.randint(3, 6)):
        first = int(rng.uniform(0.0, 0.12) * RATE)
        tone = rng.uniform(1800, 4200)
        for offset in range(int(0.03 * RATE)):
            index = first + offset
            if index >= length:
                break
            t = offset / RATE
            out[index] += (math.sin(2 * math.pi * tone * t) + 0.4 * math.sin(2 * math.pi * tone * 2.4 * t)) * math.exp(-t / 0.006) * rng.uniform(0.08, 0.2)
    return out


def cannon():
    """A tank gun: a hard supersonic crack, a deep boom and the report rolling off
    the buildings for a second and a half."""
    rng = random.Random(77)
    length = int(RATE * 2.2)
    noise = [rng.uniform(-1, 1) for _ in range(length)]
    low = biquad(biquad(noise, "low", 180, 0.7), "low", 180, 0.7)
    mid = biquad(noise, "low", 1400, 0.7)
    out = [0.0] * length
    for index in range(length):
        t = index / RATE
        out[index] += noise[index] * math.exp(-t / 0.004) * 1.2
        out[index] += mid[index] * math.exp(-t / 0.06) * 1.6
        out[index] += low[index] * math.exp(-t / 0.35) * min(1.0, t / 0.004) * 9.0
        out[index] += math.sin(2 * math.pi * 48 * t) * math.exp(-t / 0.18) * 0.8
    for delay, gain in ((0.09, 0.35), (0.21, 0.25), (0.38, 0.18), (0.62, 0.12)):
        step = int(delay * RATE)
        for index in range(length - 1, step - 1, -1):
            out[index] += low[index - step] * math.exp(-(index - step) / RATE / 0.3) * gain * 6.0
    fade = int(0.3 * RATE)
    for index in range(fade):
        out[length - 1 - index] *= index / fade
    return out



def machine_gun():
    """One round from a heavy machine gun: sharp crack, short boom, quick tail."""
    rng = random.Random(31)
    length = int(RATE * 0.45)
    noise = [rng.uniform(-1, 1) for _ in range(length)]
    low = biquad(noise, "low", 300, 0.7)
    out = [0.0] * length
    for index in range(length):
        t = index / RATE
        out[index] = noise[index] * math.exp(-t / 0.003) + low[index] * math.exp(-t / 0.07) * 4.0 * min(1.0, t / 0.002)
    return out


=======
>>>>>>> Stashed changes
if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for number, seed in enumerate((11, 23, 37), start=1):
        write("glass_break_%d.ogg" % number, glass(seed))
    write("tank_engine.ogg", engine())
<<<<<<< Updated upstream
    for number in range(1, 7):
        write("footstep_%d.ogg" % number, footstep(100 + number))
    write("gear_rattle.ogg", gear_rattle(5))
    write("tank_cannon.ogg", cannon())
    write("heavy_mg.ogg", machine_gun())
    print("Wrote glass_break_1..3, tank_engine, footstep_1..6, gear_rattle, tank_cannon and heavy_mg (.ogg) to " + str(OUT))
=======
    write("tank_cannon.ogg", cannon())
    write("heavy_mg.ogg", heavy_mg())
    for number in range(1, 5):
        write("step_walk_%d.ogg" % number, step(300 + number, False))
        write("step_run_%d.ogg" % number, step(400 + number, True))
    print("Wrote glass, engine, cannon, machine-gun and footstep sounds to " + str(OUT))
>>>>>>> Stashed changes
