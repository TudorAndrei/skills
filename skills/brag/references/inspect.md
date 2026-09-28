# Step 1: Inspect

First decide what the input is. Only the source changes; the rubric at the end is the same for every input.

| Input   | How to recognize it                                  | Source of material |
| ------- | ---------------------------------------------------- | ------------------ |
| Project | No input, and the current directory is a project     | The code           |
| Website | An `http(s)://` URL or a bare domain (`example.com`) | The live site      |

If the input is neither, ask the user what to brag about.

## Project

Read in this order:

1. The main page (`index.html`, the root route, the app shell): title, hero headline, tagline, section headings, calls to action, testimonials.
2. Styles: `:root` custom properties, `font-family` rules, Google Fonts links, `@font-face`. Record exact values.
3. `README.md` and the package manifest (`package.json`, `Cargo.toml`, `pyproject.toml`): name, one-line description, features, the "how it works" section.
4. The product in use: routes, key feature components (upload form, editor, result view, dashboard), stores and step components, `examples/` or demo folders. Find the 2–3 beats of using it: **entry → key action → result**.
5. `public/`, `assets/`, `static/`: logo, icons, images, font files.

Skip build output (`dist/`, `.next/`, `target/`), lock files, tests, `.git/`, `.env*`, key and credential files, and anything `.gitignore` hides for those reasons.

## Website

A plain download of a JavaScript site can be an empty shell. Then load it with a headless browser (the `agent-browser` skill), dismiss cookie banners, and scroll section by section so that scroll animations render.

- **Copy:** headline, tagline, headings, feature names, calls to action, testimonials, `<title>`, meta description, Open Graph tags.
- **Identity:** exact colors from the CSS and the loaded fonts.
- **Visuals:** logo, product screenshots, hero images. Save the ones you use to `<out>/work/`.
- **Product in use:** demo videos, how-it-works sections, linked docs.

## Assets for fframes

fframes renders SVG, so collect material in forms it can use:

- **Fonts:** find the real font files (`.ttf`, `.otf`; convert `.woff2` with `fonttools` if needed) and copy them to `<out>/video/media/`. If a font is not available, pick the nearest free face from `references/fframes-video/design.md` and record the substitution.
- **Logos and icons:** keep SVG files as SVG. fframes can embed them.
- **Images:** PNG or JPEG in `<out>/video/media/`.
- **UI:** you rebuild the UI in `svgr!` markup. Record the sizes, radii, spacing and colors of the components you will show.

## The rubric

Write the answers down before step 2.

1. **What is it?** One sentence.
2. **Most impressive or funniest claim?** The line that earns a reaction.
3. **Visual hook?** The strongest visual: a palette moment, a UI element, a diagram, a card.
4. **Which real UI to show?** The component or screen with the most video-worthy content.
5. **Shortest satisfying length?** 15, 20 or 25 s.
6. **Tone?** The user's preset or freeform direction, or infer a preset plus a short creative direction (absurd product → `yc-parody`, "fake startup launch").
7. **Audio feel?** Tempo, mood, density, and where the music swells or drops out.
8. **Share caption?** One sentence draft.
9. **User flow?** Entry → key action → result, from the working app. Write "none — landing page only" when there is no app, and rely on question 3.
