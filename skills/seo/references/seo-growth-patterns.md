# SEO Growth Patterns

Source: Cristina Poncela Cubeiro, "Technical SEO: Localized Pages, Backlinks, Indexing and More", published 2025-11-11 and updated 2026-03-31.
URL: https://www.cristinaponcela.com/posts/Technical-SEO-Localized-Pages,-Backlinks,-Indexing-and-More/

## Article Coverage Map

The source article covers these ideas. Preserve them when using this skill:

- Localized versions of SSR pages improve SEO only when search engines can understand that translated pages are related variants, not unrelated duplicates.
- Middleware can make one SSR page implementation appear as many localized URLs by extracting locale from the URL, setting language state, and internally rewriting to the base route.
- SSR and CSR surfaces have different SEO value: unauthenticated SSR pages are crawlable, while authenticated product pages usually are not.
- Language pickers, navigation, and redirects must keep users and crawlers in the same localized URL structure.
- Google ranking depends on crawlability, content quality, technical structure, authority, UX, and relevance.
- Sitemaps should list indexable localized variants, not only default-language pages.
- Canonical and `hreflang` tags are the duplicate-content safety net for localized pages.
- `noindex, nofollow` is useful for affiliate, referral, discount, or campaign pages that should not cannibalize core landing pages.
- Backlinks and authority are separate from crawlability; internal blog links and cross-product links can reinforce product/topic authority.
- Satellite products can become growth multipliers by ranking for adjacent intent and routing users to the main product.
- LLM recommendation visibility may improve when authoritative keyword-rich pages are linked well, but it should be measured as a hypothesis.
- Attribution should include organic, indexed-page, and AI-recommendation signals when evaluating the impact.

## Search Ranking Mental Model

When diagnosing SEO, use the ranking factors from the article as separate lenses:

- **Content quality**: original, useful, and aligned with search intent.
- **Technical SEO**: crawlable HTML, valid sitemap entries, canonical links, `hreflang`, and consistent internal linking.
- **Authority**: quality backlinks and internal authority flow from relevant pages.
- **User experience**: fast, mobile-friendly, accessible pages.
- **Relevance**: page language, keywords, title/metadata, and page content match the query.

Do not jump straight to backlinks when crawlers cannot discover or interpret the page. Do not focus only on metadata when the content does not satisfy user intent.

## SSR, CSR, Load Balancers, And Proxies

The source article distinguishes between:

- **SSR pages**: typically Next.js public pages such as landing pages and marketing pages. These are the main SEO target because crawlers can access them.
- **CSR pages**: typically authenticated product surfaces such as dashboards. These are usually not crawlable and should not drive indexing work unless they expose public content.
- **Production routing**: often uses load balancer or infrastructure rules to separate SSR and CSR paths.
- **Development routing**: may use a proxy or local routing package instead of production load balancer behavior.

When implementing localized SEO in a mixed SSR/CSR product, place locale URL handling in the request-routing layer that already decides SSR versus CSR. Restrict the localized public-page behavior to SSR routes unless the product has public CSR pages.

## Localized SSR Pages

Prefer implementing localization for public SSR pages first. These are the pages crawlers can see and are usually landing pages, pricing pages, comparison pages, docs, and other unauthenticated content.

Avoid maintaining separate page implementations per language when the existing SSR page can render localized content. A practical pattern is:

1. Accept localized URL prefixes such as `/es-es/pricing`.
2. Validate the prefix against supported locales.
3. Set locale headers and cookies for the SSR renderer.
4. Internally rewrite to the canonical route, such as `/pricing`, instead of redirecting.
5. Render the same page component in the selected language.

This pattern supports a "build once, serve everywhere" model: the URL and language context change, while the underlying page route stays shared.

For Next.js middleware, adapt this shape to local app conventions:

```ts
export function middleware(request: NextRequest) {
  const url = request.nextUrl.clone();
  const match = url.pathname.match(/^\/([a-z]{2})-([a-z]{2})(\/.*)?$/);

  if (!match) return NextResponse.next();

  const [, language, region, rest = "/"] = match;
  if (language !== region || !isSupportedLocale(language)) {
    return NextResponse.next();
  }

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-next-locale", language);
  requestHeaders.set("Accept-Language", language);
  requestHeaders.set("cookie", mergeCookieHeader(request.headers.get("cookie"), {
    language,
    NEXT_LOCALE: language,
  }));

  url.pathname = rest || "/";
  return NextResponse.rewrite(url, { request: { headers: requestHeaders } });
}
```

Use the repository's existing cookie helper instead of manually joining cookie strings when one exists.

Implementation cautions:

- Prefer internal rewrites over external redirects for localized SSR rendering so the visible localized URL remains stable.
- Validate locale prefixes against supported languages; do not let arbitrary two-letter prefixes create crawlable pages.
- Decide whether the locale format is language-only (`/es/...`) or language-region (`/es-es/...`) and apply it consistently.
- Avoid setting cookies in ways that erase unrelated cookies from the incoming request.
- Make sure the localized rendered content actually changes language; a localized URL serving English content can be a weak or harmful signal.

## Language Picker And Redirects

Language pickers need to update both persistent preference and the URL. When users switch language:

- Remove any existing locale prefix from the path.
- Preserve path, query, and hash.
- Use the unprefixed route for the default language if that is the site's policy.
- Redirect or replace the browser location with the localized route.

Internal redirects and navigation should preserve the active locale:

```ts
function localizePath(to: string, locale: string) {
  return locale === "en" ? to : `/${locale}-${locale}${to}`;
}
```

Apply this to route components, nav links, CTA buttons, and post-auth or signup redirects reachable from localized pages.

Validate real flows from localized pages:

- `/es-es/` to pricing should stay under `/es-es/pricing`.
- `/es-es/pricing` to signup should stay under `/es-es/signup` if signup is a public localized page.
- Switching from Spanish to English should remove the prefix if English is the default unprefixed language.
- Query parameters and hash fragments should survive language changes.

## Sitemap Generation

Localized sites need sitemap entries for every indexable language variant. Generate URLs from a single inventory of public paths:

```ts
function sitemapUrls(paths: string[], locales: string[]) {
  return paths.flatMap((path) => [
    `https://example.com${path}`,
    ...locales.map((locale) => `https://example.com/${locale}-${locale}${path}`),
  ]);
}
```

Do not include private, auth-gated, affiliate-only, temporary campaign, or intentionally noindexed pages. After rollout, compare sitemap URLs against routable URLs and Search Console coverage.

Use sitemap changes to teach crawlers the full localized structure. For a public path such as `/pricing`, the sitemap should include the default URL plus every supported localized URL that should appear in search results. Missing localized entries can delay or prevent discovery even when the URLs technically work.

## Canonical And Hreflang

Use canonical and `hreflang` tags to distinguish translations from duplicate content:

- Each localized page should generally be self-canonical.
- The default page should be canonical to its default-language URL.
- Include alternates for all supported languages.
- Include `x-default` pointing to the default-language fallback.

Example metadata shape:

```ts
function buildSeoLinks(baseUrl: string, path: string, locale: string, locales: string[]) {
  const cleanPath = path.startsWith("/") ? path : `/${path}`;
  const canonical = locale === "en"
    ? `${baseUrl}${cleanPath}`
    : `${baseUrl}/${locale}-${locale}${cleanPath}`;

  const alternates = [
    { hreflang: "x-default", href: `${baseUrl}${cleanPath}` },
    { hreflang: "en", href: `${baseUrl}${cleanPath}` },
    ...locales.map((lang) => ({
      hreflang: lang,
      href: `${baseUrl}/${lang}-${lang}${cleanPath}`,
    })),
  ];

  return { canonical, alternates };
}
```

Validate rendered pages in the final HTML, not only component source. Search for `canonical` and `hreflang` in browser dev tools or fetched HTML.

Common mistakes:

- Pointing every localized page canonical to the default-language URL. This can tell crawlers to ignore translations.
- Adding `hreflang` alternates that 404 or redirect unexpectedly.
- Generating alternates for unsupported locales.
- Forgetting `x-default`.
- Letting canonical URLs disagree with the sitemap.

## Strategic Noindex

Index only pages that should compete in search. Add robots controls to pages that should be reachable by users but invisible to search results, such as referral, affiliate, discount, duplicate campaign, or tracking-specific pages.

```ts
const robots = isAffiliateOrCampaignPage(pathname)
  ? "noindex, nofollow"
  : "index, follow";
```

Use `nofollow` when crawler link discovery from that page would dilute or distort ranking signals. Be careful not to place `noindex` on canonical public pages through shared metadata helpers.

Frame this as cannibalization control: some pages are useful for users or campaigns but harmful if they compete with the main landing page in search results. The goal is not to hide broken pages; it is to keep search authority concentrated on the right public URLs.

## Backlinks, Blogs, And Satellite Products

Technical SEO helps crawlers understand the site. Authority comes from relevant links.

Use backlink work in three layers, matching the article's examples:

- Footer or brand links from adjacent/satellite products back to relevant main-product pages or content.
- Internal links from landing pages to high-intent blog posts and back to product pages.
- Educational content that captures long-tail keywords and routes readers toward product value.

Evaluate links for relevance, anchor text, crawlability, and user value. Avoid creating boilerplate links that look manipulative or unrelated.

The article's backlink loop is:

1. Product landing pages link to useful blog posts with strong topical authority.
2. Blog posts rank for long-tail queries and AI-visible keyword clusters.
3. Blog posts link readers back to product pages.
4. Satellite or adjacent products contribute relevant authority via natural cross-product links.

When proposing backlinks, include the source page, destination page, anchor text, user value, and expected authority or conversion role.

## Satellite Product Growth

Satellite products can support SEO when they solve an adjacent lightweight problem, rank for related keywords, and create a natural path to the main product. Track whether users move from the satellite surface to the main product.

The article uses Streamable as the motivating example: a quick video-sharing product can reach users who are not ready for full live streaming, while still creating awareness and eventual upsell paths to a main live-streaming product.

Assess satellite-product ideas with:

- Audience adjacency: the satellite attracts users with a related but lighter-weight job.
- Brand awareness: users can discover the main product naturally.
- Upsell path: the main product solves the larger workflow once users need more capability.
- SEO synergy: each product ranks for different but related keyword families.
- Low paid-acquisition dependency: conversions can come from organic search and product discovery.

## LLM Recommendation Visibility

Authority pages with clear topical language can influence AI assistant recommendations. Treat this as a measurement hypothesis, not a guaranteed ranking lever.

Practical checks:

- Ensure blog and educational pages use the product's target keywords naturally.
- Link between authoritative content and product pages.
- Add attribution options such as "recommended by AI" if the product can support it without biasing survey results too heavily.
- Periodically test common recommendation prompts and record exact date, model, prompt, and response summary.

Keep prompt tests reproducible. Record:

- The model or assistant used.
- The exact prompt.
- Date and locale.
- Whether the product appears.
- Which keywords or claims appear near the recommendation.
- Whether the answer cites or resembles indexed content.

## Measurement

Before rollout, record baselines:

- Search Console indexed pages, impressions, clicks, CTR, and queries.
- Organic signups and conversion rates from public pages.
- Locale-specific traffic and indexed URL coverage.
- Cannibalization risk between default, localized, campaign, and blog pages.

After rollout, separate leading indicators from outcomes:

- Leading: sitemap discovered, URLs indexed, metadata valid, localized SERP snippets visible.
- Outcome: clicks, impressions, signups, lower paid acquisition dependency, or higher assisted conversions.

Attribute improvements cautiously when multiple SEO, content, backlink, and product changes shipped close together.

## Implementation Audit Template

Use this checklist when asked to audit an existing site:

1. Public URL inventory: list SSR, CSR, blog, campaign, affiliate, and satellite-product pages.
2. Indexing intent: mark each URL family as `index`, `localized index`, or `noindex`.
3. Locale routing: verify URL prefix parsing, supported-locale validation, cookie/header behavior, rewrites, and fallback behavior.
4. Navigation continuity: test language picker, nav links, CTAs, redirects, signup flow, query strings, and hashes.
5. Sitemap: verify default and localized public URLs are present and noindexed/private URLs are absent.
6. Rendered metadata: inspect final HTML for title, description, canonical, `hreflang`, robots, and language attributes.
7. Authority flow: map internal links from landing pages to blogs, blogs back to product pages, and satellite products to relevant destinations.
8. Cannibalization: identify pages competing for the same query and decide canonical, noindex, or content differentiation.
9. Measurement: define baseline metrics, launch checks, Search Console follow-up, signup attribution, and AI-recommendation tracking.
