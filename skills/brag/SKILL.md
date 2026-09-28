---
name: brag
description: Turn the current project, or a website URL, into a short launch video with an fframes (Rust + SVG) render, a Strudel soundtrack, and share copy. Use when the user says "/brag", "brag about this", "make a launch video", or wants to show off what they built.
metadata:
  tools:
    - source: mise
      command: cargo
      spec: rust@1.98.1
    - source: mise
      command: cargo-fframes
      spec: cargo:cargo-fframes@1.0.0
    - source: mise
      command: strudel
      spec: github:TudorAndrei/strudel-cli@0.2.0
    - source: mise
      command: uv
      spec: uv@0.12.19
---

# /brag

You built it. Now brag. Make a 15–25 s launch video for this exact project: the story is yours, the frames come from [fframes](https://fframes.studio/), and the music is a Strudel pattern you write, check with `strudel`, and render to a WAV.

Based on [latent-spaces/brag](https://github.com/latent-spaces/brag) (MIT). Hyperframes and the bundled audio are replaced by fframes and Strudel.

`<skill-dir>` is the folder of this file. The official fframes skill is copied in [references/fframes-video/](references/fframes-video/guide.md): it is the authority on fframes code, commands and design.

## Options

Flags or plain language:

| Option                                 | Default                                                            |
| -------------------------------------- | ------------------------------------------------------------------ |
| `--tone <preset or freeform>`          | inferred; `default` if nothing fits                                |
| `--format landscape\|vertical\|square` | landscape 1920×1080 (vertical 1080×1920, square 1080×1080), 30 fps |
| `--duration <s>`                       | about 20 s                                                         |
| `--no-music`, `--no-sfx`               | music and SFX on                                                   |
| `--title <string>`                     | from the project                                                   |

Write everything to `brag-output/`, or to `brag-output-YYYY-MM-DD-HHmmss/` when `brag-output/` exists. Below, `<out>` is that folder.

## Setup (start first, it is slow once)

1. Check the tools: `cargo --version`, `cargo fframes --version`, `strudel describe`, `uv --version`. If one is missing, tell the user to run `mise run install-skill-tools` in the skills repo, or `mise use -g <spec>` with the spec from this file's frontmatter.
2. Check the ffmpeg system libraries from [guide.md § Install](references/fframes-video/guide.md) (`brew install pkg-config ffmpeg x264 x265 opus nasm ninja` on macOS).
3. Create the project and start the first release build in the background. It compiles Skia and ffmpeg, about 20 minutes:

   ```bash
   cargo fframes new <out>/video --format <landscape|portrait|square> --fps 30 --template multi-scene --yes
   (cd <out>/video && cargo build --release)   # background
   ```

   `multi-scene` accepts only `landscape`; use the default `single-scene` template for `vertical` (fframes calls it `portrait`) and `square`, and add scenes yourself.

**Gate:** the build runs in the background, and every tool answers.

## 1. Inspect

Read [references/inspect.md](references/inspect.md). Collect copy, colors, fonts, assets and the product flow from the project or the site.

**Gate:** you can answer all nine rubric questions, and no secret or personal data is in your notes.

## 2. Plan

Read [references/plan.md](references/plan.md). Write `<out>/brag-plan.md` with the angle, hook, storyboard and audio direction.

**Gate:** scene durations sum to 15–25 s, and every line of text has its reading time.

## 3. Soundtrack

Skip when `--no-music`. Read [references/soundtrack.md](references/soundtrack.md). Write `<out>/music/song.strudel`, check it, and render it to `<out>/video/media/music.wav` plus `<out>/music/cues.json`.

**Gate:** `strudel check` exits 0, the WAV length covers the video, and `cues.json` exists.

## 4. Compose

Read [references/compose.md](references/compose.md), then [guide.md](references/fframes-video/guide.md), [design.md](references/fframes-video/design.md), [api.md](references/fframes-video/api.md) and [audio.md](references/fframes-video/audio.md). Build the scenes in `<out>/video/src/`, and run the fframes review loop.

**Gate:** `cargo run --release -- inspect --fail-on warning` passes (or only entrance warnings stay), you looked at a `strip` of every scene, and `audio analyze` gives about -14 LUFS with a true peak at or below -1 dBTP.

## 5. Deliver

Read [references/deliver.md](references/deliver.md). Render `<out>/brag.mp4`, pick and bake the poster `<out>/brag.jpg`, and write `<out>/share-copy.txt`.

**Gate:** the three files exist, `ffprobe` shows the planned size, duration and an audio stream, and frame 0 is the poster.

## Creative laws

These apply to every tone.

- **Short.** 15–25 s; 18–22 s is best.
- **Hook.** The first 2 s decide if anyone keeps watching. Plan the hook first. The first frame already shows something.
- **Clear to a stranger.** After one view, a stranger knows what it does, who it is for, and how to get it.
- **Show the thing.** At least one scene shows real UI, copy or a key visual from the product, rebuilt in SVG from the real colors, fonts, copy and images. Prefer the product in use (entry → key action → result) to the landing page that describes it.
- **Specific.** Use the project's own copy and claims. Generic SaaS phrases ("streamline your workflow") are banned.
- **Readable.** Speed comes from motion and cuts. Text that the viewer must read stays settled for about 0.3 s per word, at least 0.8 s for a short label. Fast in, then hold.
- **Alive.** Items that appear one by one, simulated clicks, swipes and typing beat static slides.
- **Funny earns its place.** Humor comes from the project's own absurdity.
- **Every frame postable.** Any frozen frame is worth sharing.

Pattern: Hook (2–3 s) → Reveal (2–4 s) → 2–3 highlights → Punchline/outro (2–4 s). A starting shape, not a template.

## Tones

Presets set pacing and structure; freeform direction ("fake Series A launch from 2016") refines or overrides them. Full definitions with example copy: [references/tones.md](references/tones.md).

| Tone        | Feel                                    | Scenes / transitions                     | Strudel feel                        |
| ----------- | --------------------------------------- | ---------------------------------------- | ----------------------------------- |
| `default`   | Playful, clean, postable                | 4–5; crossfade, clean slide              | 110–120 BPM, bright triangle lead   |
| `polished`  | Serious, elegant, restrained            | 3–4, long holds; soft 0.6–0.8 s fades    | 90–100 BPM, sine pads, sparse hats  |
| `yc-parody` | Deadpan startup launch, played straight | 4–5, one claim each; hard cuts           | 100 BPM corporate four-on-the-floor |
| `chaotic`   | FAST, LOUD, ALL CAPS                    | 6–8, some under 2 s; flash and zoom cuts | 140+ BPM, dense hats, square bass   |
| `deadpan`   | Calm, dry, nothing is a joke            | 3–4, big empty space; slow fades         | 70–80 BPM, one sine note per bar    |
| `cinematic` | Trailer-scale, epic claims              | 4–5, big type; dramatic wipes            | 80–90 BPM, low saw drones, big hits |
| `app-store` | Clean feature cards                     | 4–6; smooth slides                       | 110 BPM, light pluck arpeggio       |

## Rule: nothing secret leaves the project

Everything you read can end up in a public video. Keep secrets, keys, tokens, internal URLs, real customer names, emails and other personal data out of the plan, the video and the share copy. When the real UI shows such data, use fictional stand-ins and say so in the plan.
