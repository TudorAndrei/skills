---
name: seo
description: >-
  Comprehensive SEO and website-quality skill with five workstreams: (1) SEO audit — crawlability,
  indexation, on-page, Core Web Vitals, content quality, hreflang; (2) AI search optimization
  (AEO/GEO/LLMO) — getting cited by ChatGPT, Perplexity, and Google AI Overviews; (3) programmatic
  SEO — templated pages at scale; (4) technical SEO growth — localized SSR routing, canonical/hreflang,
  sitemaps, backlinks; (5) website launch checklist — auditing against The Website Specification
  (accessibility, security, privacy, resilience, well-known URIs, agent readiness, i18n). Use when the
  user mentions SEO, technical/on-page SEO, "why am I not ranking," traffic drops, crawl/indexing
  issues, core web vitals, AI SEO, AEO, GEO, LLMO, answer engine optimization, AI Overviews, getting
  cited by LLMs, llms.txt, programmatic SEO, pSEO, pages at scale, hreflang, localized/international
  SEO, backlink strategy, website launch/readiness checklist, accessibility audit, security headers,
  well-known URIs, or agent readiness.
license: MIT and CC-BY-4.0 sources; local skill instructions MIT-compatible
metadata:
  version: "4.0.0"
  source: https://github.com/coreyhaines31/marketingskills
  source_license: MIT
---

# SEO

Search engine optimization plus website launch-quality auditing, across five workstreams: auditing
what exists, optimizing for AI answer engines, building pages at scale, implementing localized
technical growth, and checking a site against The Website Specification. This file holds the shared
foundations and routes you to the right in-depth reference. **Read the mode reference before doing
non-trivial work in that area** — each is a complete, self-contained guide.

## Before Starting

**Check for product marketing context first.** If `.agents/product-marketing.md` exists (or
`.claude/product-marketing.md`, or the legacy `product-marketing-context.md` in older setups), read
it before asking questions. Use that context and only ask for what it doesn't already cover.

Then establish scope so you pick the right workstream:

- **What's the goal?** Diagnose a problem, get cited by AI, build many pages, or ship localized-SEO code?
- **What's the site?** SaaS, e-commerce, blog, docs, marketplace — and its current organic baseline.
- **What's the surface?** Public SSR pages, auth-gated CSR, campaign/affiliate pages, satellite products/blogs.
- **Access?** Search Console, analytics, and whether the codebase is available to edit.

## Choose Your Workstream

| If the task is…                                                                                     | Use                   | Reference                                                          |
| --------------------------------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------ |
| Diagnose SEO problems, review a site, "why am I not ranking," traffic drop                          | **Audit**             | [references/audit.md](references/audit.md)                         |
| Get cited by ChatGPT / Perplexity / AI Overviews, AEO/GEO/LLMO, llms.txt                            | **AI search**         | [references/ai-search.md](references/ai-search.md)                 |
| Build many templated pages targeting keyword/location patterns at scale                             | **Programmatic**      | [references/programmatic.md](references/programmatic.md)           |
| Implement localized SSR routing, canonical/hreflang, sitemaps, backlink loops                       | **Technical growth**  | [references/technical-growth.md](references/technical-growth.md)   |
| Audit launch/quality readiness — accessibility, security, privacy, agent readiness, well-known URIs | **Website checklist** | [references/website-checklist.md](references/website-checklist.md) |

Workstreams layer. A launch often runs: technical-growth (build indexable localized pages) →
programmatic (generate the page set) → ai-search (make them extractable/citable) → audit (verify it
all actually works) → website-checklist (broader launch-readiness pass beyond SEO). Localization
diagnosis lives in **audit**; localization _implementation_ lives in **technical-growth**; both draw
on the shared [references/international-seo.md](references/international-seo.md). **Website checklist**
is the widest net — accessibility, security, privacy, resilience, and agent readiness alongside SEO —
so use it for whole-site launch reviews and hand off to the SEO modes for depth.

## Shared Foundations

These principles cut across every workstream. The mode references expand each one in context — this
section is the single source of truth so the modes don't repeat it.

### Write for people first

Good traditional SEO is the foundation for everything else, including AI search. Content written to
game an algorithm gets neither cited nor converted. Google's generative features run on its core
Search ranking, so "helpful, reliable, people-first content" is the baseline — layer structure and
authority on top, never in place of it.

### E-E-A-T (Experience, Expertise, Authoritativeness, Trust)

The quality bar Google applies to both Search and AI features, and the biggest lever on AI citation
rate:

- **Experience** — first-hand use, original data, real examples and case studies.
- **Expertise** — named authors with visible credentials; accurate, sourced claims.
- **Authoritativeness** — recognized in the space; cited by others; strong third-party presence.
- **Trust** — accurate info, transparent business details, contact info, HTTPS, privacy/terms.

### Crawlability & indexation come first

Nothing else matters if search engines (and AI crawlers) can't find, render, and index the page:
clean `robots.txt`, accurate XML sitemaps of canonical/indexable URLs only, no accidental `noindex`,
correct canonicals, meaningful content rendered without heavy JS gymnastics. The audit reference
covers the full diagnostic order.

### Structured data

Schema (`Article`, `FAQPage`, `HowTo`, `Product`, `Organization`, `ItemList`, `Review`) gives search
engines and AI systems machine-readable context and lifts AI visibility on non-Google engines.
Google treats it as recommended, not required, for generative search. **Validation caveat:**
`web_fetch`/`curl` strip `<script>` tags and cannot see JS-injected JSON-LD — use the browser tool,
the Rich Results Test, or a Screaming Frog render instead (details in [references/audit.md](references/audit.md)).

### What NOT to do (all workstreams)

- **Keyword stuffing** — ineffective for traditional SEO and _actively_ reduces AI visibility (~-10%).
- **Thin / duplicate / doorway content** — swapping a variable in an identical template earns penalties, not rankings.
- **Keyword cannibalization** — multiple pages fighting over one keyword; map keywords to pages instead.
- **Writing separate content "for AI"** — risks Google's scaled-content-abuse policy; the same content should serve people and machines.
- **Blocking the crawlers you want to be cited by** — blocking GPTBot/PerplexityBot/ClaudeBot/Google-Extended means those engines literally cannot cite you.
- **Gating or JS-hiding your best content** — AI can't cite, and agents can't read, what they can't access.

## Reference Map

**Mode guides** (start here for any real work):

- [references/audit.md](references/audit.md) — technical, on-page, and content SEO audit workflow + output format.
- [references/ai-search.md](references/ai-search.md) — AEO/GEO/LLMO: how AI search works, the three pillars, machine-readable files, monitoring.
- [references/programmatic.md](references/programmatic.md) — the 12 playbooks, uniqueness, internal linking, indexation strategy.
- [references/technical-growth.md](references/technical-growth.md) — localized SSR implementation order, robots rules, backlink loops, measurement.
- [references/website-checklist.md](references/website-checklist.md) — auditing a site against The Website Specification: workflow, status priority (`required`/`avoid`/`recommended`/`optional`), output pattern.

**Deep references** (loaded on demand by the mode guides):

- [references/international-seo.md](references/international-seo.md) — hreflang, canonical + i18n, sitemaps, URL structure, cross-locale content quality, with evidence and source URLs. Shared by audit + technical-growth.
- [references/platform-ranking-factors.md](references/platform-ranking-factors.md) — per-platform source selection and full robots.txt config for AI crawlers.
- [references/content-patterns.md](references/content-patterns.md) — extractable content-block templates (definition, how-to, comparison, FAQ, stats).
- [references/content-types.md](references/content-types.md) — AI-search tactics by content type (SaaS, blog, comparison, docs, local/ecom).
- [references/okf.md](references/okf.md) — Open Knowledge Format bundle: what it is, implementation paths, when to skip.
- [references/playbooks.md](references/playbooks.md) — detailed implementation of each programmatic-SEO playbook.
- [references/ai-writing-detection.md](references/ai-writing-detection.md) — AI writing patterns to avoid (em dashes, filler, overused phrases).
- [references/seo-growth-patterns.md](references/seo-growth-patterns.md) — implementation patterns and the article-derived topic map for technical growth.
- [references/checklist.md](references/checklist.md) — the full Website Specification checklist with category/status filters.

## Attribution

- **Audit, AI-search, programmatic** — adapted from Corey Haines' [marketingskills](https://github.com/coreyhaines31/marketingskills) repository (MIT).
- **Technical growth** — adapts Cristina Poncela Cubeiro's article "Technical SEO: Localized Pages, Backlinks, Indexing and More" into reusable guidance.
- **Website checklist** — adapted from [The Website Specification](https://specification.website/checklist/) checklist, content licensed CC BY 4.0.
