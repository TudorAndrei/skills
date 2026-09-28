# Step 3: Soundtrack with Strudel

You compose the music as a [Strudel](https://strudel.cc/) pattern, check it with `strudel` (strudel-cli), and render its events to a WAV with `<skill-dir>/scripts/strudel_render.py`. The same events give the beat cues for step 4, so the cuts and the music come from one source.

`strudel` evaluates and queries a pattern; it makes no sound. The render script is a small synth for the events. Run `strudel describe` for the current command contract.

## 1. Tempo and length

- A cycle is one bar of 4 beats. `cps = BPM / 240` (120 BPM → `--cps 0.5`, 1 cycle = 2 s).
- Cycles needed = video seconds × cps, rounded up, plus one cycle for the tail.
- `setcps` is not available in strudel-cli. Record the tempo as a comment at the top of the file and pass it with `--cps`.

## 2. Write `<out>/music/song.strudel`

The last expression returns the pattern. Use `arrange([cycles, pattern], ...)` so that the music follows the storyboard:

```js
// 120 BPM, cps 0.5, 11 cycles = 22 s
const hats = s("hh*8").gain(0.3);
const drums = stack(s("bd*4"), s("~ sd ~ sd").gain(0.8), hats);
const bass = note("<c2 a1 f1 g1>").s("sawtooth").cutoff(600).gain(0.5);
const lead = n("0 2 4 <7 9>").scale("C4:major").s("triangle").gain(0.35);
const pad = note("<[c3,e3,g3] [a2,c3,e3] [f2,a2,c3] [g2,b2,d3]>")
  .s("sine")
  .attack(0.3)
  .release(0.8)
  .gain(0.3);

arrange(
  [1, stack(pad, hats)], // hook: 0–2 s, quiet
  [8, stack(drums, bass, lead)], // reveal + highlights: 2–18 s
  [2, pad], // outro: 18–22 s, drums drop out
);
```

The synth voices in the render script:

| Control                                             | Effect                                                         |
| --------------------------------------------------- | -------------------------------------------------------------- |
| `s("bd sd hh oh cp rim")`                           | synthesized kick, snare, closed hat, open hat, clap, rim click |
| `s("sine square sawtooth triangle")`                | tone for `note` or numeric `n`                                 |
| `note("c3")`, `note(48)`, `n(..).scale("C4:major")` | pitch (c4 = MIDI 60)                                           |
| `gain`, `velocity`                                  | level                                                          |
| `pan`                                               | 0 = left, 1 = right                                            |
| `cutoff` (`.lpf()`)                                 | one-pole low-pass in Hz                                        |
| `attack`, `release`                                 | tone envelope in seconds                                       |

Other controls (`room`, `delay`, `vowel`, sample banks such as `piano`) are ignored or skipped, and the script lists them on stderr. Write the pattern with the controls above.

Match the tone table in `SKILL.md`. Keep it modern and clean: a steady groove, one lead idea, and room for the SFX. Change the arrangement at scene boundaries so the music marks the cuts.

## 3. Check

```bash
strudel check <out>/music/song.strudel --json --from 0 --to <cycles> --limit 0
```

Exit code 0 and `valid: true` mean the whole range evaluates. On exit code 1, read `error`, fix the source, and check again. To see what a section plays, query a small window: `strudel query <out>/music/song.strudel --from 2 --to 3 --limit 16`.

## 4. Render

Query the full range without `--limit` (the script refuses truncated input):

```bash
strudel query <out>/music/song.strudel --from 0 --to <cycles> > <out>/music/events.json
uv run <skill-dir>/scripts/strudel_render.py <out>/music/events.json --cps <cps> \
  -o <out>/video/media/music.wav --cues <out>/music/cues.json
```

The WAV is 44.1 kHz stereo, peak at -1 dBFS. Set its loudness in fframes with `gain_db` (step 4). Files in `media/` are decoded to mono; for stereo, load a runtime folder with `MediaDirectory` (see `fframes-video/audio.md`).

`cues.json`:

| Field        | Meaning                                                          |
| ------------ | ---------------------------------------------------------------- |
| `bpm`, `cps` | tempo                                                            |
| `cycles`     | the start of each bar, in seconds                                |
| `beats`      | every event onset, in seconds: the grid for sequential reveals   |
| `strongCues` | downbeats that have an event: targets for cuts and major reveals |

## SFX

fframes has no SFX library here. Two sources:

- **The same pattern.** Put a one-shot at the exact moment in a separate pattern (`s("~ ~ cp ~")` in the reveal bar) and render it into the music, so the SFX is in key and in time.
- **Separate one-shots** with ffmpeg or sox, placed with their own `AudioTrack` in fframes:

  ```bash
  ffmpeg -f lavfi -i "sine=frequency=1320:duration=0.06" -af "afade=t=out:st=0:d=0.06,volume=0.5" <out>/video/media/pop.wav
  ffmpeg -f lavfi -i "anoisesrc=d=0.35:c=pink,highpass=f=800,afade=t=in:d=0.2,afade=t=out:st=0.2:d=0.15" <out>/video/media/whoosh.wav
  ```

Keep repeated small sounds in the background (-12 to -16 dB), and one sound per event type.
