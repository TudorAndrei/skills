# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Render `strudel query` events to a WAV file and a beat-cue JSON file.

strudel-cli checks a pattern and lists its events, but it does not make sound.
This script is the small synth that turns those events into a music bed:

    strudel query song.strudel --from 0 --to 12 > events.json
    uv run strudel_render.py events.json --cps 0.5 -o music.wav --cues cues.json

Drums (`s`): bd, sd, hh, oh, cp, rim, cr (crash), lt, mt, ht (toms).
Tones: `note` ("c3", "eb4", 60) or a numeric `n`, played by `s` = sine,
square, sawtooth, triangle (default) or supersaw.
Controls: gain, velocity, pan (0..1, also from `jux`), cutoff (`lpf`),
hcutoff (`hpf`), attack, decay, sustain, release, room (reverb send),
delay (echo send), delaytime, delayfeedback. Other controls are ignored and
listed on stderr.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
import wave
from array import array
from fractions import Fraction
from pathlib import Path

RATE = 44100
DRUMS = {"bd", "sd", "hh", "oh", "cp", "rim", "cr", "lt", "mt", "ht"}
WAVES = {"sine", "square", "sawtooth", "saw", "triangle", "tri", "supersaw"}
KNOWN = {
    "s", "note", "n", "gain", "velocity", "pan", "cutoff", "hcutoff", "attack", "decay",
    "sustain", "release", "room", "delay", "delaytime", "delayfeedback",
}
NOTE_STEPS = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}
SUPERSAW_DETUNE = (-0.19, -0.11, -0.04, 0.0, 0.04, 0.11, 0.19)  # semitones


def midi_of(value: object) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    if not isinstance(value, str) or not value:
        return None
    text = value.strip().lower()
    if text[0] not in NOTE_STEPS:
        return None
    step, rest = NOTE_STEPS[text[0]], text[1:]
    while rest[:1] in ("#", "s", "b", "f"):
        step += 1 if rest[0] in "#s" else -1
        rest = rest[1:]
    octave = int(rest) if rest.lstrip("-").isdigit() else 3
    return 12 * (octave + 1) + step


def lowpass(buf: list[float], cutoff: float) -> list[float]:
    alpha = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in buf:
        y += alpha * (x - y)
        out.append(y)
    return out


def highpass(buf: list[float], cutoff: float) -> list[float]:
    low = lowpass(buf, cutoff)
    return [x - y for x, y in zip(buf, low)]


def noise(n: int, rng: random.Random) -> list[float]:
    return [rng.uniform(-1, 1) for _ in range(n)]


def drum(name: str, rng: random.Random) -> list[float]:
    if name == "bd":
        n, phase, out = int(0.45 * RATE), 0.0, []
        for i in range(n):
            t = i / RATE
            phase += 2 * math.pi * (45 + 110 * math.exp(-t * 30)) / RATE
            click = 0.3 * math.exp(-t * 400)
            out.append(math.sin(phase) * math.exp(-t * 7) + click)
        return out
    if name == "sd":
        n = int(0.25 * RATE)
        body = lowpass(noise(n, rng), 7000)
        return [
            0.7 * body[i] * math.exp(-i / RATE * 18)
            + 0.5 * math.sin(2 * math.pi * 185 * i / RATE) * math.exp(-i / RATE * 30)
            for i in range(n)
        ]
    if name in ("hh", "oh", "cr"):
        decay, length, cut = {"hh": (45, 0.08, 7000), "oh": (9, 0.4, 7000), "cr": (2.2, 1.8, 4000)}[name]
        n = int(length * RATE)
        hiss = highpass(noise(n, rng), cut)
        return [0.6 * hiss[i] * math.exp(-i / RATE * decay) for i in range(n)]
    if name == "cp":
        n, out = int(0.3 * RATE), []
        for i in range(n):
            t = i / RATE
            bursts = [math.exp(-(t - k * 0.011) * 60) for k in range(3) if t >= k * 0.011]
            env = max(bursts + [0.4 * math.exp(-t * 12)])
            out.append(rng.uniform(-1, 1) * env * 0.7)
        return lowpass(out, 5000)
    if name in ("lt", "mt", "ht"):
        base = {"lt": 90, "mt": 130, "ht": 180}[name]
        n, phase, out = int(0.4 * RATE), 0.0, []
        for i in range(n):
            t = i / RATE
            phase += 2 * math.pi * base * (1 + 0.6 * math.exp(-t * 25)) / RATE
            out.append(0.8 * math.sin(phase) * math.exp(-t * 9))
        return out
    n = int(0.05 * RATE)  # rim
    return [math.sin(2 * math.pi * 820 * i / RATE) * math.exp(-i / RATE * 90) for i in range(n)]


def osc(kind: str, p: float) -> float:
    if kind == "sine":
        return math.sin(2 * math.pi * p)
    if kind == "square":
        return 0.6 if p < 0.5 else -0.6
    if kind in ("sawtooth", "saw", "supersaw"):
        return 0.6 * (2 * p - 1)
    return 4 * abs(p - 0.5) - 1


def tone(kind: str, midi: float, length: float, v: dict) -> list[float]:
    attack = max(float(v.get("attack", 0.005)), 1e-3)
    decay = max(float(v.get("decay", 0.0)), 0.0)
    sustain = float(v.get("sustain", 1.0 if decay == 0 else 0.0))
    release = max(float(v.get("release", 0.08)), 1e-3)
    hold = max(length, attack)
    freqs = [440 * 2 ** ((midi + d - 69) / 12) for d in (SUPERSAW_DETUNE if kind == "supersaw" else (0.0,))]
    phases = [random.Random(int(midi * 100) + k).random() for k in range(len(freqs))]
    level = 0.5 / math.sqrt(len(freqs))
    out, env = [], 0.0
    for i in range(int((hold + release) * RATE)):
        t = i / RATE
        if t < attack:
            env = t / attack
        elif t < hold:
            env = sustain + (1 - sustain) * math.exp(-(t - attack) / decay) if decay > 0 else 1.0
        else:
            held = sustain + (1 - sustain) * math.exp(-(hold - attack) / decay) if decay > 0 else 1.0
            env = held * max(0.0, 1 - (t - hold) / release)
        x = sum(osc(kind, (f * t + ph) % 1.0) for f, ph in zip(freqs, phases))
        out.append(x * env * level)
    return out


def reverb(buf: array, offset: int) -> array:
    """A small Schroeder reverb: four damped combs, then two allpasses."""
    out = array("f", bytes(4 * len(buf)))
    for delay in (1557, 1617, 1491, 1422):
        d = delay + offset
        line, store, idx = [0.0] * d, 0.0, 0
        for i, x in enumerate(buf):
            y = line[idx]
            store = y * 0.8 + store * 0.2
            line[idx] = x + store * 0.84
            idx = (idx + 1) % d
            out[i] += y * 0.25
    for delay in (556, 225):
        d = delay + offset
        line, idx = [0.0] * d, 0
        for i, x in enumerate(out):
            y = line[idx]
            line[idx] = x + y * 0.5
            out[i] = y - x
            idx = (idx + 1) % d
    return out


def echo(buf: array, seconds: float, feedback: float) -> array:
    d = max(1, int(seconds * RATE))
    out = array("f", bytes(4 * len(buf)))
    for i, x in enumerate(buf):
        out[i] = x + (out[i - d] * feedback if i >= d else 0.0)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("events", type=Path, help="JSON from `strudel query` ('-' for stdin)")
    ap.add_argument("--cps", type=float, default=0.5, help="cycles per second (0.5 = 120 BPM in 4/4)")
    ap.add_argument("-o", "--output", type=Path, required=True, help="WAV file to write")
    ap.add_argument("--cues", type=Path, help="write beat and strong-cue times (seconds) as JSON")
    ap.add_argument("--tail", type=float, default=1.5, help="seconds of decay after the last event")
    args = ap.parse_args()

    raw = sys.stdin.read() if str(args.events) == "-" else args.events.read_text()
    data = json.loads(raw)
    if not data.get("valid"):
        print(f"strudel query failed: {data.get('error')}", file=sys.stderr)
        return 1
    if data.get("truncated"):
        print("events are truncated: run `strudel query` without --limit", file=sys.stderr)
        return 1

    start = Fraction(str(data["range"][0]))
    rng = random.Random(7)
    events, ignored = [], set()
    for ev in data["events"]:
        begin = float((Fraction(ev["begin"]) - start)) / args.cps
        if begin < 0:  # a hap that started before the queried range (e.g. from `off`)
            continue
        length = float(Fraction(ev["end"]) - Fraction(ev["begin"])) / args.cps
        events.append((begin, length, ev["value"]))
        ignored |= set(ev["value"]) - KNOWN
    end = max((b + l for b, l, _ in events), default=0.0) + args.tail
    size = int(end * RATE + 1)
    dry = [array("f", bytes(4 * size)), array("f", bytes(4 * size))]
    room = [array("f", bytes(4 * size)), array("f", bytes(4 * size))]
    delay = [array("f", bytes(4 * size)), array("f", bytes(4 * size))]
    delay_time, delay_fb = None, 0.5

    cache: dict[str, list[float]] = {}
    beats, strong, skipped = set(), set(), set()
    for begin, length, v in events:
        s = str(v.get("s", "triangle")).lower()
        if s in DRUMS:
            buf = cache.setdefault(s, drum(s, rng))
        else:
            midi = midi_of(v.get("note", v.get("n")))
            if midi is None or s not in WAVES:
                skipped.add(s)
                continue
            buf = tone(s, midi, length, v)
        if "cutoff" in v:
            buf = lowpass(buf, float(v["cutoff"]))
        if "hcutoff" in v:
            buf = highpass(buf, float(v["hcutoff"]))
        gain = float(v.get("gain", 1.0)) * float(v.get("velocity", 1.0))
        pan = min(1.0, max(0.0, float(v.get("pan", 0.5))))
        gains = (gain * math.cos(pan * math.pi / 2), gain * math.sin(pan * math.pi / 2))
        sends = [(dry, 1.0), (room, float(v.get("room", 0.0))), (delay, float(v.get("delay", 0.0)))]
        if "delay" in v and delay_time is None:
            delay_time = float(v.get("delaytime", 0.75 / (args.cps * 4)))  # dotted 8th
            delay_fb = min(0.9, float(v.get("delayfeedback", 0.45)))
        at = int(begin * RATE)
        for bus, amount in sends:
            if amount <= 0:
                continue
            for ch in (0, 1):
                g = gains[ch] * amount
                target = bus[ch]
                for i, x in enumerate(buf[: size - at]):
                    target[at + i] += x * g
        t = round(begin, 3)
        beats.add(t)
        if abs(begin * args.cps - round(begin * args.cps)) < 1e-6:  # downbeat
            strong.add(t)

    left, right = dry
    if any(room[0]) or any(room[1]):
        wet = (reverb(room[0], 0), reverb(room[1], 23))
        for i in range(size):
            left[i] += wet[0][i] * 0.35
            right[i] += wet[1][i] * 0.35
    if delay_time and (any(delay[0]) or any(delay[1])):
        # Ping-pong feel: the right side is a little later.
        wet = (echo(delay[0], delay_time, delay_fb), echo(delay[1], delay_time * 1.02, delay_fb))
        for i in range(size):
            left[i] += wet[0][i] * 0.5
            right[i] += wet[1][i] * 0.5

    peak = max(max(map(abs, left), default=0), max(map(abs, right), default=0)) or 1.0
    scale = 10 ** (-1 / 20) / peak  # peak at -1 dBFS; set loudness later with fframes gain_db
    frames = array("h")
    for a, b in zip(left, right):
        frames.append(int(a * scale * 32767))
        frames.append(int(b * scale * 32767))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(args.output), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames.tobytes())

    if args.cues:
        bar = 1 / args.cps
        cues = {
            "cps": args.cps,
            "bpm": round(args.cps * 240, 2),
            "duration": round(end, 3),
            "cycles": [round(i * bar, 3) for i in range(int((end - args.tail) / bar) + 1)],
            "beats": sorted(beats),
            "strongCues": sorted(strong),
        }
        args.cues.write_text(json.dumps(cues, indent=2) + "\n")

    if ignored:
        print(f"ignored controls: {', '.join(sorted(ignored))}", file=sys.stderr)
    if skipped:
        print(f"skipped sounds (no synth voice): {', '.join(sorted(skipped))}", file=sys.stderr)
    print(f"wrote {args.output} ({end:.2f}s, {len(events)} events)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
