# Step 5: Render and deliver

Run from `<out>/video/`, with `R="cargo run --release --"`.

## Render

```bash
$R render --draft                   # half resolution, fast, for a last look
$R render -o ../brag.mp4            # final
ffprobe -v error -show_entries stream=codec_type,width,height,nb_frames,duration ../brag.mp4
```

Confirm the planned size, a duration of 15–25 s, and an audio stream (unless `--no-music` and `--no-sfx`).

## Poster

The poster is the idle image of the video. Pick the strongest settled frame: text fully in, not mid-transition, postable on its own. Usually it is the hook line, the hero reveal or the final logo. Take its time from `timing.rs` and export it:

```bash
$R frame <time> -o ../work/poster
ffmpeg -y -i ../work/poster/<file>.png -q:v 2 ../brag.jpg
```

Open `brag.jpg` and look at it. If it lands on motion, move the time by a few tenths of a second.

### Bake it as frame 0

Most players and platforms (Slack, X, Discord) use frame 0 as the thumbnail. Replace only the pixels of frame 0 with the poster, and keep the duration, frame count and audio. From `<out>`:

```bash
ffmpeg -y -i brag.mp4 -i brag.jpg \
  -filter_complex "[0:v][1:v]overlay=0:0:enable='eq(n,0)'[v]" \
  -map "[v]" -map 0:a? -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p \
  -c:a copy -movflags +faststart brag.poster.mp4 \
  && mv brag.poster.mp4 brag.mp4
```

Keep `brag.jpg` for platforms that accept a custom thumbnail and for `<video poster>`.

## Share copy

Write `<out>/share-copy.txt`: 1–3 sentences, postable as-is, specific to the project, in the video's tone. Open with the product or its claim. Put variants, if useful, in `share-copy-variants.md`.

| Tone        | Shape                                                           |
| ----------- | --------------------------------------------------------------- |
| `default`   | Made <App>. It <does the thing, in its own terms>. <best line>. |
| `polished`  | Introducing <App>: <clean one-liner>.                           |
| `yc-parody` | We built <App> to solve <problem, stated seriously>. <stat>.    |
| `chaotic`   | <ALL CAPS CLAIM>. <App> is <overstated description>.            |
| `deadpan`   | I made <App>. It <does the thing>.                              |
| `cinematic` | <App>. <tagline>.                                               |
| `app-store` | <App> is now live. <feature>, <feature> and <feature>.          |

## Output

```
<out>/
  brag.mp4          the video, poster at frame 0
  brag.jpg          the poster
  brag-plan.md      plan and storyboard
  share-copy.txt    the caption
  music/            song.strudel, events.json, cues.json
  video/            the fframes project
  work/             strips, frames, waveform
```

## Tell the user

- Where `brag.mp4`, `brag.jpg` and `share-copy.txt` are.
- One sentence on the creative angle.
- The path of a strip image and the `preview` command to watch it with sound.
- An offer: re-roll a scene, change the tone, or rewrite the music pattern.
