# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Render `strudel query` events to a WAV file and a beat-cue JSON file.

strudel-cli checks a pattern and lists its events, but it does not make sound.
This script is the small synth that turns those events into a music bed:

    strudel query song.strudel --from 0 --to 12 > events.json
    uv run strudel_render.py events.json --cps 0.5 -o music.wav --cues cues.json

Drums (`s`): bd, sd, hh, oh, cp, rim. Tones: `note` ("c3", "eb4", 60) or a
numeric `n`, played by `s` = sine, square, sawtooth or triangle (default
triangle). Other controls: gain, velocity, pan (0..1), cutoff (Hz), attack,
release. Other controls are ignored and listed on stderr.
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
DRUMS = {"bd", "sd", "hh", "oh", "cp", "rim"}
WAVES = {"sine", "square", "sawtooth", "saw", "triangle", "tri"}
KNOWN = {"s", "note", "n", "gain", "velocity", "pan", "cutoff", "attack", "release"}
NOTE_STEPS = {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}


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


def drum(name: str, rng: random.Random) -> list[float]:
    if name == "bd":
        n, phase, out = int(0.45 * RATE), 0.0, []
        for i in range(n):
            t = i / RATE
            phase += 2 * math.pi * (45 + 110 * math.exp(-t * 30)) / RATE
            out.append(math.sin(phase) * math.exp(-t * 7))
        return out
    if name == "sd":
        n = int(0.25 * RATE)
        noise = lowpass([rng.uniform(-1, 1) for _ in range(n)], 7000)
        return [
            0.7 * noise[i] * math.exp(-i / RATE * 18)
            + 0.5 * math.sin(2 * math.pi * 185 * i / RATE) * math.exp(-i / RATE * 30)
            for i in range(n)
        ]
    if name in ("hh", "oh"):
        decay = 45 if name == "hh" else 9
        n = int((0.08 if name == "hh" else 0.4) * RATE)
        prev, out = 0.0, []
        for i in range(n):
            x = rng.uniform(-1, 1)
            out.append(0.5 * (x - prev) * math.exp(-i / RATE * decay))
            prev = x
        return out
    if name == "cp":
        n, out = int(0.3 * RATE), []
        for i in range(n):
            t = i / RATE
            bursts = [math.exp(-(t - k * 0.011) * 60) for k in range(3) if t >= k * 0.011]
            env = max(bursts + [0.4 * math.exp(-t * 12)])
            out.append(rng.uniform(-1, 1) * env * 0.7)
        return lowpass(out, 5000)
    n = int(0.05 * RATE)  # rim
    return [math.sin(2 * math.pi * 820 * i / RATE) * math.exp(-i / RATE * 90) for i in range(n)]


def tone(kind: str, midi: float, length: float, attack: float, release: float) -> list[float]:
    freq = 440 * 2 ** ((midi - 69) / 12)
    hold = max(length, attack)
    n = int((hold + release) * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        p = (freq * t) % 1.0
        if kind == "sine":
            x = math.sin(2 * math.pi * p)
        elif kind == "square":
            x = 0.6 if p < 0.5 else -0.6
        elif kind in ("sawtooth", "saw"):
            x = 0.6 * (2 * p - 1)
        else:
            x = 4 * abs(p - 0.5) - 1
        if t < attack:
            env = t / attack
        elif t < hold:
            env = 1.0
        else:
            env = max(0.0, 1 - (t - hold) / release)
        out.append(x * env * 0.5)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("events", type=Path, help="JSON from `strudel query` ('-' for stdin)")
    ap.add_argument("--cps", type=float, default=0.5, help="cycles per second (0.5 = 120 BPM in 4/4)")
    ap.add_argument("-o", "--output", type=Path, required=True, help="WAV file to write")
    ap.add_argument("--cues", type=Path, help="write beat and strong-cue times (seconds) as JSON")
    ap.add_argument("--tail", type=float, default=1.0, help="seconds of decay after the last event")
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
        length = float(Fraction(ev["end"]) - Fraction(ev["begin"])) / args.cps
        events.append((begin, length, ev["value"]))
        ignored |= set(ev["value"]) - KNOWN
    end = max((b + l for b, l, _ in events), default=0.0) + args.tail
    left = array("f", bytes(4 * int(end * RATE + 1)))
    right = array("f", bytes(4 * len(left)))

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
            attack = float(v.get("attack", 0.005))
            release = float(v.get("release", 0.08))
            buf = tone(s, midi, length, max(attack, 1e-3), max(release, 1e-3))
            if "cutoff" in v:
                buf = lowpass(buf, float(v["cutoff"]))
        gain = float(v.get("gain", 1.0)) * float(v.get("velocity", 1.0))
        pan = min(1.0, max(0.0, float(v.get("pan", 0.5))))
        gl, gr = gain * math.cos(pan * math.pi / 2), gain * math.sin(pan * math.pi / 2)
        at = int(begin * RATE)
        for i, x in enumerate(buf[: len(left) - at]):
            left[at + i] += x * gl
            right[at + i] += x * gr
        t = round(begin, 3)
        beats.add(t)
        if abs(begin * args.cps - round(begin * args.cps)) < 1e-6:  # downbeat
            strong.add(t)

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
