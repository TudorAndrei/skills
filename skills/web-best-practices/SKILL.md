---
name: web-best-practices
description: Website engineering best practices - semantic HTML, Core Web Vitals and loading performance, caching, security headers, a machine-readable surface for crawlers and AI agents, and the toolkit that checks each of them in CI. Use when setting up, auditing, building, hardening, or reviewing a website or web app front end; fixing LCP, INP, or CLS; choosing image, font, or script loading; setting Cache-Control, CSP, HSTS, cookie flags, or CORS; writing the document head, forms, or native HTML controls; adding llms.txt, JSON-LD, markdown mirrors, or AI-crawler robots.txt rules (AgentMarkup); checking what AI crawlers receive from a deployed URL; or wiring Lighthouse CI, HTML validation, bundle budgets, or header scans into a pipeline. For rankings and content strategy use seo; for WCAG use better-accessibility.
---

# Web Best Practices

Pick the sections that match the request. Inspect the project before editing: the framework and its rendering mode (static, SSR, client-only), the build output directory, the host and its header or redirect config, the document head template, `robots.txt`, `sitemap.xml`, and the checks already in CI.

Measure before and after. A change to performance, headers, or machine-readable output is done when a tool reports it on the built or deployed site, not when the source looks right.

## HTML and semantics

Use the element that has the behavior. A `<button>` gives focus, keyboard activation, and a role for free; a `<div>` with a click handler gives none of them.

- Every document has `<!doctype html>`, `<html lang>`, `<meta charset="utf-8">` first in `<head>`, a viewport meta that does not disable zoom, a unique `<title>`, a meta description, and a canonical link.
- Links navigate (`<a href>`), buttons act (`<button type="button">`). Never swap them.
- One `<h1>`, headings in order, landmarks (`<header>`, `<nav>`, `<main>`, `<footer>`) used once each where they apply.
- Prefer native `<dialog>`, `<details>`, the `popover` attribute, and form validation to script-built copies.
- Missing pages return a real `404` status. A `200` page that says "not found" is a soft 404.

Read [references/html.md](references/html.md) for the head template, forms, images, native controls, status codes, and progressive enhancement.

## Performance

Target the Core Web Vitals at the 75th percentile of field data: LCP at or below 2.5 s, INP at or below 200 ms, CLS at or below 0.1. Lab tools find causes; only field data confirms a fix.

1. Find the LCP element. Make it discoverable in the HTML, give it `fetchpriority="high"`, and never lazy-load it.
2. Give every image and embed `width` and `height` (or `aspect-ratio`) so the layout does not shift.
3. Load scripts with `type="module"` or `defer`. Audit each third-party script for what it costs.
4. Serve hashed assets with `Cache-Control: public, max-age=31536000, immutable` and HTML with `no-cache`.

Read [references/performance.md](references/performance.md) for the metric-by-metric fixes, images, fonts, JavaScript, caching, and the measurement loop.

## Security

Set the response headers on the host, not in `<meta>` tags, and verify them on the deployed URL.

- HTTPS only, with `Strict-Transport-Security`.
- A nonce- or hash-based Content Security Policy with `object-src 'none'` and `base-uri 'none'`. Start in `Content-Security-Policy-Report-Only`.
- `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, and `frame-ancestors` in the CSP.
- Session cookies with `Secure; HttpOnly; SameSite=Lax` and the `__Host-` prefix.
- Never put untrusted data into `innerHTML`, `href`, or an inline script.

Read [references/security.md](references/security.md) for the header set, CSP rollout, cookies, CORS, third-party code, and injection rules.

## Machine-readable surface

Crawlers and AI agents read the raw HTML response, usually without running JavaScript. The content, the metadata, and the structured data must be in that response.

Use [AgentMarkup](https://agentmarkup.dev/) to generate and validate this surface at build time: `llms.txt`, optional `llms-full.txt`, JSON-LD, markdown mirrors, AI-crawler `robots.txt` rules, and Content-Signal headers. It adds no browser JavaScript.

1. Install the adapter that owns the final build output: `@agentmarkup/next`, `@agentmarkup/vite`, `@agentmarkup/astro`, `@agentmarkup/nuxt`, or `@agentmarkup/cli` for any other static output.
2. Write one shared config from what the repository already declares (site URL, name, pages, schema types).
3. Gate CI with `agentmarkup check ./dist` on the build and `npx @agentmarkup/audit <url>` on the deployed site.

Whether to allow or block a crawler is a business decision; ask the user. Read [references/machine-readable.md](references/machine-readable.md) for the config, each generated file, the crawler list, and how to read audit findings.

This section overlaps with the `seo` skill. Use this skill to implement and gate the files; use `seo` for content, rankings, and AI-search strategy.

## Toolkit

Let a tool decide everything a tool can decide. Run the checks on the built output or the deployed URL, and fail the pipeline on regressions.

| Question                                      | Tool                                                        |
| --------------------------------------------- | ----------------------------------------------------------- |
| Is the HTML valid?                            | `html-validate`, Nu HTML Checker                            |
| Is the page fast in the lab?                  | Lighthouse, Lighthouse CI, WebPageTest                      |
| Is the page fast for real users?              | CrUX, PageSpeed Insights, the `web-vitals` library          |
| Did the bundle grow?                          | `size-limit`, the bundler's analyzer                        |
| Are the security headers correct?             | MDN HTTP Observatory, AgentMarkup security scan             |
| Can crawlers and agents read the site?        | AgentMarkup (`check`, `audit`, website checker)             |
| Does it work in a real browser?               | Playwright, `agent-browser`                                 |
| Are there WCAG violations a machine can find? | axe-core (`agent-browser a11y`), see `better-accessibility` |

Read [references/tooling.md](references/tooling.md) for commands, what each tool can and cannot decide, and the CI shape.

## Related skills

- `seo` - rankings, content, crawl and indexing strategy, AI-search visibility.
- `better-accessibility` - keyboard, focus, ARIA, and WCAG 2.2.
- `better-layout`, `better-typography`, `better-colors`, `better-ui`, `better-writing` - visual and copy quality.
- `frontend-design` - aesthetic direction for new UI.

## Report

End an audit or a hardening task with:

- **Measured** - each number or finding, the tool that produced it, and whether it is lab or field data.
- **Changed** - the files and host settings changed, with before and after values.
- **Deferred** - the findings left open and why.
- **Decisions for the user** - crawler access, third-party scripts, and any CSP exception.
