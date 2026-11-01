"""Generates Arrowlock's sound effects and music loop. Deterministic: the same
script always writes the same audio. Everything is synthesised from scratch
(sine/bell/pluck voices, filtered noise, a small reverb), so there is no
third-party audio and no licence to track.

Requires numpy, scipy and ffmpeg (for the OGG music file).
Run from the project root:  python tools/make_audio.py
Outputs: assets/audio/sfx/*.wav and assets/audio/music/calm_loop.ogg
"""
import subprocess
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUSIC_DIR = ROOT / "assets" / "audio" / "music"


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def lowpass(x, cutoff, order=4):
    sos = signal.butter(order, cutoff, "lowpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=4):
    sos = signal.butter(order, cutoff, "highpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def bell(freq, dur, decay=5.0):
    """Inharmonic partials give a glassy bell."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for ratio, amp, d in ((1.0, 1.0, decay), (2.76, 0.35, decay * 1.6), (5.4, 0.15, decay * 2.4)):
        out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * d)
    attack = np.minimum(1.0, t / 0.004)
    return out * attack


def pluck(freq, dur, decay=9.0):
    t = t_axis(dur)
    out = (np.sin(2 * np.pi * freq * t)
           + 0.4 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 6)
           + 0.15 * np.sin(2 * np.pi * freq * 3 * t) * np.exp(-t * 10))
    return out * np.exp(-t * decay) * np.minimum(1.0, t / 0.003)


def place(buf, sound, start):
    i = int(start * SR)
    end = min(len(buf), i + len(sound))
    buf[i:end] += sound[: end - i]


def fade_out(x, ms=8):
    n = int(SR * ms / 1000)
    x = x.copy()
    x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def normalise(x, peak):
    return x / max(1e-9, np.max(np.abs(x))) * peak


def write_wav(name, x):
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    data = (np.clip(fade_out(x), -1, 1) * 32767).astype(np.int16)
    with wave.open(str(SFX_DIR / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def sfx():
    rng = np.random.default_rng(1)

    # A clear arrow slides away: a soft pluck with a short airy sweep.
    t = t_axis(0.24)
    air = lowpass(highpass(rng.standard_normal(len(t)), 1800), 5500) * np.exp(-t * 30) * 0.07
    clear = pluck(hz(76), 0.24, 13.0) * 0.8 + air
    write_wav("tap_clear", normalise(clear, 0.7))

    # A blocked arrow: a dull downward thunk plus a short low buzz.
    t = t_axis(0.3)
    freq = 190 * np.exp(-t * 4.0) + 70
    thunk = np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-t * 11)
    buzz = lowpass(signal.square(2 * np.pi * 96 * t), 520) * np.exp(-t * 20) * 0.35
    knock = lowpass(rng.standard_normal(len(t)), 800) * np.exp(-t * 45) * 0.4
    write_wav("tap_blocked", normalise(thunk + buzz + knock, 0.75))

    # Hint: two soft rising bells.
    buf = np.zeros(int(0.75 * SR))
    place(buf, bell(hz(76), 0.6, 6.5), 0.0)
    place(buf, bell(hz(83), 0.6, 6.5) * 0.9, 0.12)
    write_wav("hint", normalise(buf, 0.6))

    # Coin: the classic bright two-note ding.
    buf = np.zeros(int(0.6 * SR))
    place(buf, bell(hz(83), 0.4, 9.0), 0.0)
    place(buf, bell(hz(88), 0.5, 8.0), 0.07)
    write_wav("coin", normalise(buf, 0.6))

    # Stars pop in rising pitch.
    for i, note in enumerate((84, 88, 91), start=1):
        write_wav(f"star{i}", normalise(bell(hz(note), 0.65, 5.5), 0.6))

    # Win: a bright rising arpeggio that rings out.
    buf = np.zeros(int(1.9 * SR))
    for i, note in enumerate((72, 76, 79, 84)):
        place(buf, bell(hz(note), 1.2, 4.2) * (0.8 + 0.07 * i), i * 0.11)
    for note in (72, 76, 79):
        place(buf, bell(hz(note + 12), 1.4, 3.2) * 0.35, 0.48)
    write_wav("win", normalise(buf, 0.7))

    # Lose: three gentle descending tones, never harsh.
    buf = np.zeros(int(1.3 * SR))
    for i, note in enumerate((64, 60, 57)):
        tone = lowpass(signal.sawtooth(2 * np.pi * hz(note) * t_axis(0.5), 0.5), 1400)
        tone = tone * np.exp(-t_axis(0.5) * 5.0) * np.minimum(1.0, t_axis(0.5) / 0.02)
        place(buf, tone, i * 0.26)
    write_wav("lose", normalise(buf, 0.55))

    # UI tick.
    t = t_axis(0.05)
    tick = np.sin(2 * np.pi * 1700 * t) * np.exp(-t * 110) + highpass(rng.standard_normal(len(t)), 4000) * np.exp(-t * 200) * 0.3
    write_wav("click", normalise(tick, 0.5))


# --- music ---------------------------------------------------------------

BPM = 78
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
LOOP_SECONDS = BARS * BAR
TAIL = 3.5  # reverb and release tails; wrapped onto the start so the loop is seamless

# Am - F - C - G, twice. Pad voicings, bass root, and arpeggio tones (MIDI).
CHORDS = [
    {"pad": (57, 60, 64), "pad7": (57, 60, 64, 67), "bass": 33, "arp": (69, 72, 76, 79)},  # Am
    {"pad": (53, 57, 60), "pad7": (53, 57, 60, 64), "bass": 29, "arp": (65, 69, 72, 76)},  # F
    {"pad": (60, 64, 67), "pad7": (60, 64, 67, 71), "bass": 36, "arp": (72, 76, 79, 83)},  # C
    {"pad": (55, 59, 62), "pad7": (55, 59, 62, 69), "bass": 31, "arp": (67, 71, 74, 79)},  # G
]


def pad_voice(freq, dur, detune):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for cents, amp in ((-detune, 0.5), (0.0, 0.7), (detune, 0.5)):
        f = freq * 2 ** (cents / 1200)
        out += amp * (np.sin(2 * np.pi * f * t) + 0.25 * signal.sawtooth(2 * np.pi * f * t))
    attack = np.minimum(1.0, t / 0.9)
    release = np.minimum(1.0, (dur - t) / 1.1)
    return lowpass(out, 1500, 2) * attack * np.clip(release, 0, 1)


def reverb(stereo, seconds=2.4, seed=7):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-t / 0.75)
        ir = lowpass(ir, 4500, 2)
        ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
        ir /= np.sqrt(np.sum(ir ** 2))
        out.append(signal.fftconvolve(stereo[ch], ir)[: len(stereo[ch])])
    return np.array(out)


def music():
    rng = np.random.default_rng(42)
    total = int((LOOP_SECONDS + TAIL) * SR)
    dry = np.zeros((2, total))
    send = np.zeros((2, total))

    def put(ch_gains, sound, start, wet=0.0):
        i = int(start * SR)
        end = min(total, i + len(sound))
        for ch in range(2):
            dry[ch, i:end] += sound[: end - i] * ch_gains[ch] * (1 - wet)
            send[ch, i:end] += sound[: end - i] * ch_gains[ch] * wet

    for bar in range(BARS):
        chord = CHORDS[(bar // 2) % 4]
        second_round = bar >= 8
        start = bar * BAR

        # Pad: one voicing per two bars, richer in the second round.
        if bar % 2 == 0:
            notes = chord["pad7"] if second_round else chord["pad"]
            dur = 2 * BAR + 1.0
            for k, n in enumerate(notes):
                voice = pad_voice(hz(n), dur, 7) * 0.085
                pan = 0.35 + 0.3 * (k / max(1, len(notes) - 1))
                put((1 - pan + 0.2, pan + 0.2), voice, start, wet=0.25)

        # Bass: root on beat 1, a quiet fifth on beat 3.
        root = pluck(hz(chord["bass"]), BAR * 0.9, 1.6) * 0.30
        put((0.8, 0.8), root, start)
        fifth = pluck(hz(chord["bass"] + 7), BEAT * 1.6, 3.0) * 0.12
        put((0.7, 0.7), fifth, start + 2 * BEAT)

        # Arpeggio: eighth notes, sparse at first and denser later.
        density = 0.7 if second_round else 0.42
        step = BEAT / 2
        last = None
        for s in range(8):
            if rng.random() > density and s % 4 != 0:
                continue
            idx = int(rng.integers(0, 4))
            if idx == last:
                idx = (idx + 1) % 4
            last = idx
            note = chord["arp"][idx]
            voice = pluck(hz(note), 1.4, 5.5) * (0.17 if s % 2 == 0 else 0.12)
            pan = 0.25 + 0.5 * ((s + bar) % 2)
            put((1 - pan + 0.25, pan + 0.25), voice, start + s * step, wet=0.55)

        # Airy hats on the off-beats once the loop is under way.
        if bar >= 4:
            for b in range(4):
                t = t_axis(0.06)
                hat = highpass(rng.standard_normal(len(t)), 5500) * np.exp(-t * 55) * 0.05
                put((0.9, 0.7), hat, start + b * BEAT + BEAT / 2)

    wet = reverb(send)
    mix = dry + wet * 1.1
    # Wrap the tail onto the start so the loop has no seam or gap.
    loop_len = int(LOOP_SECONDS * SR)
    loop = mix[:, :loop_len].copy()
    tail = mix[:, loop_len:]
    loop[:, : tail.shape[1]] += tail
    loop = loop / np.max(np.abs(loop)) * 0.8
    return loop


def write_music(loop):
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    wav_path = MUSIC_DIR / "calm_loop.tmp.wav"
    data = (np.clip(loop.T, -1, 1) * 32767).astype(np.int16)
    with wave.open(str(wav_path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    ogg_path = MUSIC_DIR / "calm_loop.ogg"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "4", str(ogg_path)],
        check=True,
    )
    wav_path.unlink()
    seam = float(np.max(np.abs(loop[:, 0] - loop[:, -1])))
    print(f"music: {LOOP_SECONDS:.1f} s, peak {np.max(np.abs(loop)):.2f}, "
          f"rms {np.sqrt(np.mean(loop ** 2)):.3f}, loop seam jump {seam:.4f}, {ogg_path.stat().st_size // 1024} KiB")


if __name__ == "__main__":
    sfx()
    for f in sorted(SFX_DIR.glob("*.wav")):
        print(f"sfx: {f.name} {f.stat().st_size // 1024} KiB")
    write_music(music())
