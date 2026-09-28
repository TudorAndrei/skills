# Step 4: Compose in fframes

The fframes project is `<out>/video/`, made in setup. `fframes-video/guide.md` owns the fframes API and the review loop; this file adds what is specific to a brag.

Define the alias once: `R="cargo run --release --"`, run from `<out>/video/`.

## 1. Constants first

Put every time in one `timing.rs` module, in seconds, taken from the storyboard and `cues.json`:

```rust
// 120 BPM, from <out>/music/cues.json
pub const BEAT: f32 = 0.5;
pub const HOOK: f32 = 0.0;
pub const REVEAL: f32 = 2.0;        // strongCue: drums enter
pub const CARD_1: f32 = 6.0;        // beat grid, every second beat (text)
pub const CARD_2: f32 = CARD_1 + 2.0 * BEAT;
pub const OUTRO: f32 = 18.0;        // strongCue: drums drop out
```

The scene durations, the animation `timeline!`s and the SFX `AudioTrack`s all read these constants. Change a time in one place, and picture and sound move together.

- Put 1–3 major moments (scene cuts, the hero reveal, the logo) on `strongCues`, within 0.15 s.
- Put sequential items on consecutive `beats`, within 0.10 s. For text the viewer reads, use every second beat or reveal fast and hold the set (see the reading time in `plan.md`).
- Readability and the story come before the grid. Mark a locked time with a comment: `// strongCue 2.0s`.

## 2. Scenes

One scene struct per storyboard scene, in the storyboard order. From the `multi-scene` template, replace the example scenes; keep the shared chrome only if the plan uses it.

- **Canvas:** the plan format. Set `WIDTH`, `HEIGHT`, `FPS` on the video.
- **Identity:** background, text and accent colors are constants copied from the project CSS. Fonts are files in `media/`, named by exact family.
- **Real UI:** rebuild the product components in `svgr!` with their real radii, spacing, colors and copy. Embed real SVG logos and PNG screenshots with `<image href=..>`.
- **Transitions:** `Overlap::Previous(s)` for crossfades, from the tone table in `plan.md`. Two busy layouts crossfaded make a muddy double exposure: move the old content out first, or dip through the background.
- **Interaction:** a cursor is an SVG arrow on a spring path; a click is a 0.1 s scale of the button to 0.96 plus a ripple; typing reveals the string by character count over time, about 12–18 characters per second.
- **Life on holds:** a slow drift of the background or a light glow keeps a hold from looking frozen.
- **Audio-reactive (optional):** `frame.visualize_audio_frame(..)` gives the spectrum of the music at a frame. Use it for small changes in glow or depth, not for equalizer bars.

## 3. Audio map

```rust
fn audio(&self) -> AudioMap<'_> {
    AudioMap::from([
        AudioTrack::new("music.wav", Second(0.)..Eof).gain_db(-10.).fade_out(1.5),
        AudioTrack::new("whoosh.wav", Second(timing::REVEAL - 0.15)..Eof).gain_db(-12.),
        AudioTrack::new("pop.wav", Second(timing::CARD_1 + 0.02)..Eof).gain_db(-14.),
    ])
}
```

Music alone sits at -8 to -12 dB. A whoosh starts about 0.15 s before the movement peak; a pop lands on the frame the element appears. Omit the music track for `--no-music` and SFX tracks for `--no-sfx`.

## 4. Review loop

Run the loop in `fframes-video/guide.md § The loop` after every change: `timeline`, `inspect`, `strip` of every scene, `frame` for detail, `onion` for motion. Look at the PNGs before you say that a scene looks right. Check stills mid-transition too.

For sound, run `$R audio analyze --waveform <out>/work/wave.png` and read the image: cue ticks sit under their visual events, about -14 LUFS integrated, true peak at or below -1 dBTP, silence only where intended. Use `$R audio at <time>` to check one event.

Offer `$R preview` to the user when they want to watch; it blocks, so run it in the background.

## 5. Brag checks

Before step 5, each item is true or recorded in the plan:

- The hook lands in the first 2 s, and frame 0 shows something.
- At least one scene shows real UI, copy or visuals from the project.
- Every line of readable text is settled for its reading time (check with `frame` at the start and end of the hold).
- Total length is 15–25 s (`$R timeline`).
- 1–3 moments are on strong cues, and sequential items follow the beat grid, or natural timing was chosen for readability.
- No secret or personal data is on screen.
