# Step 2: Plan

Write `<out>/brag-plan.md`. It is the creative contract for steps 3–5. It says what the video must communicate and which project material it uses; step 4 decides the Rust code.

If the user points at one part (a new version, a feature, one angle), make it the focus.

## Template

```markdown
# Brag plan: <App>

## What is it?

<one sentence>

## Angle

<the premise: the joke, the claim, why this is specific to this project>

## Hook (first 2–3 s)

## Highlights

- <2–3 specific moments: "the altitude meter counts up", not "feature callouts">

## Outro / punchline

## User flow shown

<entry → key action → result, or "none — landing page only">

## Tone

- Preset: <preset>
- Direction: <freeform phrase>
- Interpretation: <how it changes pacing, writing, motion and restraint>

## Format: <landscape|vertical|square> <W>x<H> @ 30 fps

## Duration: <s>

## Visual identity

- Background / text / accent: <exact values>
- Display font / body font: <names, files, substitutions>
- Strongest visual element: <what>

## Audio

- Tempo: <BPM> (cps = BPM / 240 for 4 beats per cycle)
- Arc: <for example "hats only in the hook, drums enter on the reveal, drop to pad for the outro">
- SFX: <off, or moment types: key ticks on typing, a pop per card, one whoosh per cut>

## Storyboard

### Scene 1 — <name> — <s> s (<start>–<end> s)

On screen: <what, with the exact copy>
Sequence / interaction: <what appears one by one, what is clicked, swiped or typed; or none>
Reading holds: <each line and its settled time>
Music: <what the pattern does here>
Transition: <kind, duration> → Scene 2

## Share copy (draft)
```

## Scene counts and transitions

| Tone        | Scenes | Transitions                      |
| ----------- | ------ | -------------------------------- |
| `default`   | 4–5    | crossfade, clean wipe            |
| `polished`  | 3–4    | soft crossfade, slide            |
| `yc-parody` | 4–5    | hard cut, 0.2 s crossfade        |
| `chaotic`   | 6–8    | hard cut, flash, zoom            |
| `deadpan`   | 3–4    | 0.8–1.0 s crossfade, long hold   |
| `cinematic` | 4–5    | dramatic wipe, crossfade + scale |
| `app-store` | 4–6    | slide, smooth wipe (0.35–0.45 s) |

In fframes a crossfade is `Overlap::Previous(seconds)` on the incoming scene; a hard cut is no overlap.

## Reading time

- Short label (1–3 words): about 0.8 s settled.
- Sentence: about 0.3 s per word, at least 1.2 s. The hook line gets the most.
- A 4 s scene holds 2–3 short reads. When a scene has more text than its length allows, cut copy or split the scene.
- Sequential text on the beat: at 120 BPM a beat is 0.5 s, too fast for new lines. Reveal text on every second beat, or reveal the set fast and hold it.

## What to show, in order of preference

1. **The working app in use:** upload screen with a file dropping in, a result view filling up, an inbox row getting a badge. Rebuild it from the real components' colors, sizes and copy.
2. **One UI element:** hero card, swipe card, progress meter, stat block.
3. **The core concept animated:** "taxis for taxis" → one taxi inside another.
4. **Text only:** when the product is its copy, giant display type and little chrome.

Stat cards and the landing hero get at most one scene, as a frame around the flow. Abstract color washes and generic particles belong to any video, so they do not belong in this one.

## Sequences and interaction

Before the storyboard, ask: what can appear one by one, and what action can be simulated? Commit to it in the scene: "3 horse profiles slide in one by one, each on a beat with a pop", "a cursor right-swipes Thunder's card", "the hook types out with key ticks".
