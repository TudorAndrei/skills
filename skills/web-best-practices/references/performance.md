# Performance

Sources: https://web.dev/articles/vitals, https://web.dev/explore/learn-core-web-vitals, https://developer.mozilla.org/en-US/docs/Web/Performance

## Targets

| Metric | Measures                            | Good     | Poor     |
| ------ | ----------------------------------- | -------- | -------- |
| LCP    | Largest content element is rendered | ≤ 2.5 s  | > 4 s    |
| INP    | Slowest interaction to next paint   | ≤ 200 ms | > 500 ms |
| CLS    | Unexpected layout movement          | ≤ 0.1    | > 0.25   |

A page passes when the 75th percentile of real visits is "good", for mobile and desktop separately. TTFB (aim for 0.8 s or less) and FCP are diagnostic metrics; they explain a bad LCP.

## Measurement loop

1. Read field data first (CrUX through PageSpeed Insights, or your own `web-vitals` beacons). It shows which metric fails and on which device class.
2. Reproduce in the lab with Lighthouse or WebPageTest on a throttled mobile profile. A fast laptop on office Wi-Fi hides the problem.
3. Change one thing. Measure again with the same profile, and run it more than once; lab numbers vary between runs.
4. Confirm in field data after the release. CrUX is a 28-day rolling window, so a fix shows slowly.

State each number as lab or field. A Lighthouse score is not a Core Web Vitals result.

## LCP

Split LCP into its four parts and fix the largest: TTFB, resource load delay, resource load duration, and element render delay.

- **TTFB** - cache HTML at the CDN where the content allows it, remove redirect chains, and stream the response.
- **Load delay** - the LCP resource must be in the initial HTML, where the preload scanner can find it. A CSS `background-image` or a script-inserted `<img>` is found late. Add `fetchpriority="high"` to the LCP `<img>`, or `<link rel="preload" as="image" fetchpriority="high">` when the image cannot be in the markup.
- **Load duration** - right-size the image, use AVIF or WebP, and serve it from the same origin or `preconnect` to its origin.
- **Render delay** - remove render-blocking CSS and synchronous scripts from the head. Do not hide the content until hydration finishes.

Never lazy-load the LCP element. Do not let an A/B testing or consent script block the first render.

## CLS

- Set `width` and `height` on images, video, and iframes, or use CSS `aspect-ratio`.
- Reserve space for ads, embeds, and banners that arrive late (`min-height`).
- Do not insert content above existing content, except in response to a user action.
- Stop font swaps from moving text: use `size-adjust`, `ascent-override`, and `descent-override` on the fallback `@font-face`.
- Animate `transform` and `opacity`, not `top`, `left`, `width`, or `height`.

## INP

- Find long tasks with the Performance panel or the Long Animation Frames API. Any task over 50 ms can delay an interaction.
- Split long work and yield to the main thread: `await scheduler.yield()` where it is available, with a `setTimeout` fallback.
- Give visual feedback first, then do the expensive work.
- Reduce DOM size and avoid layout thrash (read layout values, then write, not interleaved).
- Move heavy computation to a Web Worker.
- Hydrate less: use islands, server components, or partial hydration where the framework has them.

## Images

- Serve the size that is displayed, through `srcset` and `sizes`.
- Prefer AVIF, then WebP, with a JPEG or PNG fallback. Use SVG for icons and logos.
- `loading="lazy"` and `decoding="async"` for everything below the fold.
- Use the framework's image component when it has one; it supplies sizes, formats, and dimensions.

## Fonts

- Self-host WOFF2. Subset to the scripts in use (`unicode-range`).
- `font-display: swap` for body text, or `optional` when a late swap is worse than the fallback.
- Preload at most one or two fonts that the first screen needs: `<link rel="preload" as="font" type="font/woff2" crossorigin>`.
- Prefer a variable font to many static weights. Prefer a system font stack when the brand allows it.

## JavaScript and CSS

- Ship less. Check the bundle analyzer for duplicate packages, whole-library imports, and polyfills for browsers that are out of scope.
- Split by route and import heavy, rarely used code dynamically (`import()`).
- Load scripts with `type="module"` or `defer`. Use `async` only for independent scripts.
- Third-party scripts: load each one after the first render, set a size budget, and remove the ones that have no owner.
- Inline only the critical CSS when the stylesheet is large; otherwise one small cached stylesheet is simpler and fast.
- `content-visibility: auto` with `contain-intrinsic-size` skips rendering of long off-screen sections.

## Network and caching

| Resource                              | `Cache-Control`                       |
| ------------------------------------- | ------------------------------------- |
| Hashed assets (`app.3f9a1c.js`)       | `public, max-age=31536000, immutable` |
| HTML                                  | `no-cache` (revalidate with `ETag`)   |
| Unhashed static files (favicon, etc.) | `public, max-age=86400`               |
| Personal or authenticated responses   | `private, no-store`                   |

- Never give a long `max-age` to a URL whose content can change. Put a content hash in the file name.
- At a CDN, use `s-maxage` and `stale-while-revalidate` for HTML that can be shared.
- Compress text with Brotli (or zstd), with gzip as the fallback.
- Serve over HTTP/2 or HTTP/3.
- `<link rel="preconnect">` to at most a few critical origins. Do not preload what the page does not use in the first seconds.
- Keep pages eligible for the back/forward cache: no `unload` handlers, and no `Cache-Control: no-store` on public HTML.
- For likely next navigations, add Speculation Rules (`<script type="speculationrules">`) to prefetch or prerender. Exclude URLs with side effects, such as logout.

## Budgets

Set budgets in CI and fail on a regression: compressed JavaScript per route, LCP and CLS in Lighthouse CI assertions, and total image weight on the main templates. A budget that only warns will be ignored.
