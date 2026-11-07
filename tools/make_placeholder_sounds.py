"""
Placeholder sounds, synthesized: the hull hit, the guns, the engine loop, the two threat notices
and the danger and combat music, until real ones are made. Writes them under assets/audio/
(placeholders/ and music/danger, music/combat); the sound bank and the main scene's AmbientMusic
point at them. Effects are .wav (they must not loop), loops and music .ogg (oggenc), every loop
seamless. Run it again to remake them (same seed, same sounds), then import them (open the editor,
or `godot --no-window -e --quit`).

    python3 tools/make_placeholder_sounds.py
"""

import os
import subprocess
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(ROOT, "assets", "audio", "placeholders")
MUSIC = os.path.join(ROOT, "assets", "audio", "music")
RATE = 22050
rng = np.random.default_rng(7)


def t_of(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def envelope(t, attack, decay):
    return np.minimum(1.0, t / max(attack, 1e-4)) * np.exp(-t / decay)


def lowpass(x, cutoff):
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1.0 - a) * v + a * acc
        y[i] = acc
    return y


def normal(x, peak=0.8):
    return x / max(1e-9, np.max(np.abs(x))) * peak


def write_wav(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(x, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    print(os.path.relpath(path, ROOT))


def write_ogg(path, x):
    tmp = path[:-4] + ".tmp.wav"
    write_wav(tmp, x)
    subprocess.check_call(["oggenc", "-Q", "-q", "4", "-o", path, tmp])
    os.remove(tmp)
    print(os.path.relpath(path, ROOT))


def seamless_noise(seconds, cutoff):
    """Low-passed noise that loops: the tail crossfaded into the head."""
    fade = int(0.25 * RATE)
    n = int(seconds * RATE)
    x = lowpass(rng.standard_normal(n + fade), cutoff)
    head, tail = x[:fade], x[n:n + fade]
    ramp = np.linspace(0.0, 1.0, fade)
    x = x[:n].copy()
    x[:fade] = head * ramp + tail * (1.0 - ramp)
    return x


def tone(freq, t):
    return np.sin(2.0 * np.pi * freq * t)


def looped(freq, seconds):
    """`freq` nudged to fit a whole number of cycles in `seconds` (so a loop has no seam)."""
    return max(1, round(freq * seconds)) / seconds


# --- Effects ---

def hull_hit():
    t = t_of(0.4)
    clank = tone(180, t) * 0.6 + tone(437, t) * 0.4 + tone(913, t) * 0.25
    noise = lowpass(rng.standard_normal(t.size), 3000) * envelope(t, 0.001, 0.03)
    return normal(clank * envelope(t, 0.002, 0.09) + noise * 1.5, 0.85)


def laser_fire():
    t = t_of(0.28)
    freq = 1400.0 * np.exp(-t * 4.0) + 380.0
    phase = 2.0 * np.pi * np.cumsum(freq) / RATE
    x = np.sin(phase + 0.6 * np.sin(phase * 0.5))
    return normal(x * envelope(t, 0.003, 0.09), 0.6)


def cannon_fire():
    t = t_of(0.45)
    freq = 90.0 * np.exp(-t * 6.0) + 45.0
    body = np.sin(2.0 * np.pi * np.cumsum(freq) / RATE) * envelope(t, 0.002, 0.14)
    crack = lowpass(rng.standard_normal(t.size), 2500) * envelope(t, 0.0005, 0.02)
    return normal(body + crack * 0.8, 0.9)


def missile_launch():
    t = t_of(0.9)
    noise = rng.standard_normal(t.size)
    swell = np.minimum(1.0, t / 0.15) * np.exp(-np.maximum(0.0, t - 0.15) / 0.3)
    bright = lowpass(noise, 1800) - lowpass(noise, 300)
    return normal(bright * swell + tone(220 + 120 * t, t) * swell * 0.15, 0.7)


def engine_loop():
    seconds = 2.0
    t = t_of(seconds)
    # Low and dull: a deep hum with no bright partials, rumble low-passed hard, a slow gentle swell.
    hum = tone(looped(36, seconds), t) * 0.55 + tone(looped(54, seconds), t) * 0.2 + tone(looped(72, seconds), t) * 0.05
    rumble = seamless_noise(seconds, 90) * 4.0  # A third of the hum's level: the hum carries it
    wobble = 1.0 + 0.08 * tone(looped(1, seconds), t)
    return normal((hum + rumble) * wobble, 0.6)


def notice(freqs, beep, gap, peak):
    out = []
    for freq in freqs:
        t = t_of(beep)
        out.append((tone(freq, t) + 0.3 * tone(freq * 2, t)) * envelope(t, 0.005, beep * 0.5))
        out.append(np.zeros(int(gap * RATE)))
    return normal(np.concatenate(out), peak)


# --- Music (loops) ---

def danger_music():
    seconds = 32.0
    t = t_of(seconds)
    drone = sum(tone(looped(f, seconds), t) * a for f, a in [(73.4, 0.5), (110.0, 0.35), (146.8, 0.2), (155.6, 0.08)])
    pulse = 0.65 + 0.35 * tone(looped(0.5, seconds), t)
    air = seamless_noise(seconds, 300) * 0.15 * (0.5 + 0.5 * tone(looped(0.125, seconds), t))  # A faint breath only: louder, it read as a steady hiss
    return normal(drone * pulse + air, 0.31)  # As loud as it was with the hiss


def combat_music():
    seconds = 16.0  # 32 beats at 120 bpm
    t = t_of(seconds)
    drone = sum(tone(looped(f, seconds), t) * a for f, a in [(73.4, 0.4), (110.0, 0.3), (116.5, 0.12)])
    beat = 0.5
    kick = np.zeros(t.size)
    tick = np.zeros(t.size)
    k = t_of(0.3)
    kick_one = np.sin(2.0 * np.pi * np.cumsum(60.0 * np.exp(-k * 12.0) + 40.0) / RATE) * envelope(k, 0.002, 0.08)
    h = t_of(0.05)
    tick_one = lowpass(rng.standard_normal(h.size), 6000) * envelope(h, 0.0005, 0.01)
    for i in range(int(seconds / beat)):
        at = int(i * beat * RATE)
        kick[at:at + kick_one.size] += kick_one[:max(0, min(kick_one.size, t.size - at))]
        for half in (0, 1):
            at2 = int((i + half * 0.5) * beat * RATE)
            tick[at2:at2 + tick_one.size] += tick_one[:max(0, min(tick_one.size, t.size - at2))] * (0.6 if half else 0.3)
    return normal(drone * 0.8 + kick * 1.2 + tick * 0.5, 0.6)


def main():
    write_wav(os.path.join(SFX, "hull_hit.wav"), hull_hit())
    write_wav(os.path.join(SFX, "laser_fire.wav"), laser_fire())
    write_wav(os.path.join(SFX, "cannon_fire.wav"), cannon_fire())
    write_wav(os.path.join(SFX, "missile_launch.wav"), missile_launch())
    write_wav(os.path.join(SFX, "hostile_detected.wav"), notice([880.0, 659.3], 0.12, 0.05, 0.5))
    write_wav(os.path.join(SFX, "hostile_aware.wav"), notice([1318.5, 1318.5, 1318.5], 0.08, 0.05, 0.55))
    write_ogg(os.path.join(SFX, "engine.ogg"), engine_loop())
    write_ogg(os.path.join(MUSIC, "danger", "placeholder_danger.ogg"), danger_music())
    write_ogg(os.path.join(MUSIC, "combat", "placeholder_combat.ogg"), combat_music())


if __name__ == "__main__":
    main()
