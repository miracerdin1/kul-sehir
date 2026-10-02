"""Synthesize the game's glass and armoured-vehicle sounds into godot/assets/audio/.

Original project sounds, no recordings used:
- glass_break.wav: a sharp crack and frame thump, the pane's short ring, a dense
  burst of shard "tinks" that thins out as pieces land, debris rattle, a small room.
- tank_engine.wav: a seamless loop of a big diesel at fast idle, firing pulses
  over a low rumble with some exhaust hiss. The game raises its pitch with load.
- tank_tracks.wav: a seamless loop of steel tracks: link clanks on the sprocket,
  idler squeal and loose rattle. The game fades it in with speed.
Run: python tools/make_sounds.py   (needs numpy)
"""

from pathlib import Path
import wave

import numpy as np

RATE = 44100
AUDIO = Path(__file__).resolve().parents[1] / "godot" / "assets" / "audio"


def write(name, samples):
    samples = samples * (0.92 / np.max(np.abs(samples)))
    AUDIO.mkdir(parents=True, exist_ok=True)
    with wave.open(str(AUDIO / name), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes((samples * 32767).astype("<i2").tobytes())
    print("Wrote", AUDIO / name)


def bright_noise(rng, count):
    # Differencing white noise tilts it towards the top end.
    return np.diff(np.diff(rng.uniform(-1.0, 1.0, count + 2)))


def low_pass(signal, amount):
    out = np.copy(signal)
    for index in range(1, len(out)):
        out[index] = out[index - 1] + amount * (out[index] - out[index - 1])
    return out


def seamless(signal, overlap):
    """Cross-fade the tail into the head so the file loops without a click."""
    head = signal[:overlap]
    tail = signal[-overlap:]
    ramp = np.linspace(0.0, 1.0, overlap)
    looped = np.copy(signal[:-overlap])
    looped[:overlap] = tail * (1.0 - ramp) + head * ramp
    return looped


def tink(out, rng, start, gain):
    """One glass shard: two or three high inharmonic partials with a tiny click."""
    begin = int(start * RATE)
    end = min(len(out), begin + int(RATE * 0.12))
    if begin >= end:
        return
    t = np.arange(end - begin) / RATE
    sound = np.zeros_like(t)
    for _ in range(rng.integers(2, 4)):
        frequency = np.exp(rng.uniform(np.log(2600.0), np.log(11500.0)))
        sound += np.sin(2 * np.pi * frequency * t + rng.uniform(0, 2 * np.pi)) * np.exp(-t * rng.uniform(35.0, 110.0)) * rng.uniform(0.4, 1.0)
    click = bright_noise(rng, len(t)) * np.exp(-t * 900.0) * 0.6
    out[begin:end] += (sound * np.minimum(1.0, t / 0.0004) + click) * gain


def room(signal):
    """A short, dull tail from four feedback combs, as in a bare concrete room."""
    tail = np.zeros_like(signal)
    for delay, feedback in ((1116, 0.55), (1188, 0.53), (1277, 0.5), (1356, 0.48)):
        line = signal.copy()
        for index in range(delay, len(line)):
            line[index] += line[index - delay] * feedback
        tail += line
    return low_pass(tail / 4.0, 0.35)


def glass():
    rng = np.random.default_rng(4410)
    length = 1.35
    t = np.arange(int(RATE * length)) / RATE
    out = bright_noise(rng, len(t)) * np.exp(-t * 85.0) * 0.55
    out += np.sin(2 * np.pi * (170.0 * t - 40.0 * t * t)) * np.exp(-t * 32.0) * 0.45
    for frequency in (1180.0, 1745.0, 2530.0, 3390.0, 4720.0):
        out += np.sin(2 * np.pi * frequency * rng.uniform(0.98, 1.02) * t) * np.exp(-t * rng.uniform(22.0, 45.0)) * 0.09
    for _ in range(70):
        tink(out, rng, rng.exponential(0.035), 0.32 * rng.uniform(0.5, 1.0))
    for _ in range(55):
        tink(out, rng, rng.uniform(0.08, 0.55), rng.uniform(0.08, 0.22))
    for _ in range(28):
        tink(out, rng, rng.uniform(0.45, 1.1), rng.uniform(0.03, 0.09))
    envelope = np.exp(-((t - 0.28) / 0.17) ** 2) + 0.4 * np.exp(-((t - 0.62) / 0.12) ** 2)
    out += bright_noise(rng, len(t)) * 0.06 * envelope
    out += room(out) * 0.22
    out *= np.clip((length - t) / 0.2, 0.0, 1.0)
    write("glass_break.wav", out)


def engine():
    rng = np.random.default_rng(72)
    length = 2.0
    overlap = int(RATE * 0.25)
    t = np.arange(int(RATE * length) + overlap) / RATE
    # Twelve cylinders at about 750 rpm: 75 firing pulses a second, each one a
    # short decaying knock, slightly uneven from cylinder to cylinder.
    firing = 37.5
    out = np.zeros_like(t)
    pulse_length = int(RATE * 0.03)
    pulse_t = np.arange(pulse_length) / RATE
    pulse = np.sin(2 * np.pi * 95.0 * pulse_t) * np.exp(-pulse_t * 140.0)
    beat = 1.0 / (firing * 2.0)
    time = 0.0
    cylinder = 0
    while time < t[-1]:
        start = int((time + rng.normal(0, 0.0004)) * RATE)
        if 0 <= start < len(out) - pulse_length:
            out[start:start + pulse_length] += pulse * (0.75 + 0.25 * np.sin(cylinder * 2.4)) * rng.uniform(0.85, 1.0)
        time += beat
        cylinder += 1
    out = low_pass(out, 0.25) * 1.4
    # Crankshaft and gearbox hum, and a deep body rumble.
    for frequency, amplitude in ((37.5, 0.5), (75.0, 0.35), (112.5, 0.18), (150.0, 0.1), (18.75, 0.25)):
        out += np.sin(2 * np.pi * frequency * t) * amplitude
    rumble = low_pass(rng.uniform(-1.0, 1.0, len(t)), 0.02) * 6.0
    out += rumble * (0.8 + 0.2 * np.sin(2 * np.pi * 0.5 * t))
    # Exhaust and turbo hiss on top.
    out += low_pass(bright_noise(rng, len(t)), 0.5) * 0.05
    write("tank_engine.wav", seamless(out, overlap))


def tracks():
    rng = np.random.default_rng(91)
    length = 2.0
    overlap = int(RATE * 0.2)
    t = np.arange(int(RATE * length) + overlap) / RATE
    out = np.zeros_like(t)
    # Links dropping onto the sprocket: metallic clanks about twelve a second.
    clank_t = np.arange(int(RATE * 0.06)) / RATE
    time = 0.0
    while time < t[-1]:
        start = int(time * RATE)
        if start < len(out) - len(clank_t):
            clank = np.zeros_like(clank_t)
            for frequency in rng.uniform(700.0, 2600.0, 3):
                clank += np.sin(2 * np.pi * frequency * clank_t) * np.exp(-clank_t * rng.uniform(60.0, 120.0))
            clank += bright_noise(rng, len(clank_t)) * np.exp(-clank_t * 300.0) * 0.8
            out[start:start + len(clank_t)] += clank * rng.uniform(0.5, 1.0)
        time += 1.0 / 12.0 + rng.normal(0, 0.006)
    # Idler squeal that wavers, and the loose clatter of the whole run.
    squeal = np.sin(2 * np.pi * (1650.0 * t + 25.0 * np.sin(2 * np.pi * 1.5 * t) / (2 * np.pi * 1.5)))
    out += squeal * 0.05 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t) ** 2)
    out += low_pass(rng.uniform(-1.0, 1.0, len(t)), 0.3) * 0.25
    out += low_pass(rng.uniform(-1.0, 1.0, len(t)), 0.03) * 1.2
    write("tank_tracks.wav", seamless(out, overlap))


if __name__ == "__main__":
    glass()
    engine()
    tracks()
