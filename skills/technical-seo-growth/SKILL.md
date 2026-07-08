---
name: technical-seo-growth
description: Implement and review technical SEO growth work for product sites, especially localized SSR/Next.js pages, URL locale middleware, language pickers, sitemaps, canonical and hreflang tags, robots noindex/nofollow rules, internal and cross-product backlinks, satellite-product SEO loops, LLM recommendation visibility, and attribution measurement. Use when Codex is asked to improve SEO for localized pages, diagnose indexing/cannibalization, add SEO metadata, plan backlink strategy, or convert Cristina Poncela's technical SEO article into actionable site changes.
---

# Technical SEO Growth

## Workflow

Use this skill to turn SEO growth ideas into concrete implementation and review steps. Start by identifying which surface is involved:

- **Public SSR pages**: prioritize crawlability, localization URLs, sitemap entries, canonical/hreflang, and internal links.
- **Authenticated CSR pages**: do not optimize for indexing unless they expose public content; crawlers generally cannot use auth-gated product pages.
- **Campaign, affiliate, or discount pages**: decide whether they should be indexed or protected with `noindex, nofollow`.
- **Satellite products or blogs**: evaluate backlinks, topical authority, and conversion paths back to the main product.

For detailed implementation patterns and the full article-derived topic map, read [references/seo-growth-patterns.md](references/seo-growth-patterns.md). Use it when implementing, auditing, or planning any non-trivial SEO work.

## Implementation Order

1. Map public URL inventory: default-language pages, localized variants, campaign pages, blog/content pages, and satellite-product surfaces.
2. Add or review locale-aware routing for SSR pages before touching metadata. Localized URLs should resolve to localized content without duplicating page implementations.
3. Keep language selection, redirects, and internal navigation locale-aware so users and crawlers stay in the same language path.
4. Update sitemap generation so every intended indexable localized page is listed.
5. Generate canonical and `hreflang` metadata per URL variant. Each localized page should be self-canonical and list alternates, including `x-default`.
6. Add strategic robots rules for pages that should not compete with primary search pages.
7. Strengthen authority with relevant internal links, blog links, and cross-product backlinks where they are natural and useful.
8. Add measurement before or with rollout: Search Console impressions/clicks, indexed URL coverage, organic signups, attribution survey options, and AI-recommendation referral signals where relevant.

## Output Style

When asked to review or plan SEO work, produce an actionable result:

- List missing crawler/indexing signals before growth ideas.
- Separate code changes from content/linking changes.
- Call out whether each page type should be indexed, localized, canonicalized, or noindexed.
- Include validation steps that inspect rendered HTML and production-like URLs, not only source code.
- Include a measurement plan with baseline, expected leading indicators, and cannibalization risks.

## Review Checklist

Check these before finishing SEO work:

- Localized routes preserve path, query string, and hash.
- Unsupported or malformed locale prefixes fall back predictably.
- Default language policy is consistent: either no prefix for default language or a deliberate prefixed default.
- Sitemap URLs match actually routable URLs.
- Canonical URLs do not point all translations to only the default-language page.
- `hreflang` language codes match the URL scheme and supported locales.
- Internal links and redirects do not strip the current locale.
- `noindex` is applied only to pages that should stay out of search results.
- Backlinks are contextually relevant and not spammy.
- SEO impact is measured against cannibalization risk, not just gross clicks.

## Source

This skill is based on Cristina Poncela Cubeiro's article "Technical SEO: Localized Pages, Backlinks, Indexing and More" and adapts its patterns into reusable Codex guidance.
