# The Website Specification Checklist

Source: https://specification.website/checklist/

The source content is licensed CC BY 4.0 by Joost de Valk and contributors. This local reference preserves the item titles, status labels, category grouping, and canonical links for audit use.

Status counts from the fetched checklist: 35 required, 64 recommended, 25 optional, 4 avoid.

## Status Contract

- `required`: fix first; these are treated as baseline requirements.
- `recommended`: strong modern-web baseline; schedule after required failures.
- `optional`: apply only when the site context needs the capability.
- `avoid`: harmful or obsolete patterns; flag as defects when present.

## Foundations

- [ ] `required` [The HTML doctype](https://specification.website/spec/foundations/doctype/)
- [ ] `required` [The lang attribute on <html>](https://specification.website/spec/foundations/html-lang/)
- [ ] `required` [<meta charset>](https://specification.website/spec/foundations/meta-charset/)
- [ ] `required` [<meta viewport>](https://specification.website/spec/foundations/meta-viewport/)
- [ ] `required` [The <title> element](https://specification.website/spec/foundations/title/)
- [ ] `recommended` [<meta name="description">](https://specification.website/spec/foundations/meta-description/)
- [ ] `recommended` [Canonical URL (rel="canonical")](https://specification.website/spec/foundations/canonical-url/)
- [ ] `recommended` [Favicons and app icons](https://specification.website/spec/foundations/favicons/)
- [ ] `recommended` [<meta name="theme-color">](https://specification.website/spec/foundations/theme-color/)
- [ ] `recommended` [<meta name="color-scheme">](https://specification.website/spec/foundations/color-scheme/)
- [ ] `recommended` [Open Graph protocol](https://specification.website/spec/foundations/open-graph/)
- [ ] `recommended` [Feed discovery with rel="alternate"](https://specification.website/spec/foundations/feed-discovery/)
- [ ] `recommended` [Feed content hygiene](https://specification.website/spec/foundations/feed-hygiene/)
- [ ] `recommended` [Popover API](https://specification.website/spec/foundations/popover-api/)

## SEO

- [ ] `recommended` [robots.txt](https://specification.website/spec/seo/robots-txt/)
- [ ] `recommended` [XML sitemaps](https://specification.website/spec/seo/xml-sitemaps/)
- [ ] `recommended` [Sitemap index files](https://specification.website/spec/seo/sitemap-index/)
- [ ] `optional` [Image and video sitemap extensions](https://specification.website/spec/seo/image-sitemaps/)
- [ ] `recommended` [URL structure](https://specification.website/spec/seo/url-structure/)
- [ ] `required` [Redirects (301/302/308)](https://specification.website/spec/seo/redirects/)
- [ ] `avoid` [Soft 404s](https://specification.website/spec/seo/soft-404/)
- [ ] `required` [Meta robots and X-Robots-Tag](https://specification.website/spec/seo/meta-robots/)
- [ ] `required` [Heading hierarchy](https://specification.website/spec/seo/heading-hierarchy/)
- [ ] `recommended` [Internal linking](https://specification.website/spec/seo/internal-linking/)
- [ ] `recommended` [Structured data (JSON-LD)](https://specification.website/spec/seo/structured-data/)
- [ ] `recommended` [Breadcrumbs](https://specification.website/spec/seo/breadcrumbs/)
- [ ] `optional` [IndexNow](https://specification.website/spec/seo/indexnow/)

## Accessibility

- [ ] `required` [Colour contrast](https://specification.website/spec/accessibility/color-contrast/)
- [ ] `required` [Image alt text](https://specification.website/spec/accessibility/image-alt-text/)
- [ ] `required` [Form labels](https://specification.website/spec/accessibility/form-labels/)
- [ ] `required` [Keyboard navigation](https://specification.website/spec/accessibility/keyboard-navigation/)
- [ ] `required` [Visible focus indicators](https://specification.website/spec/accessibility/focus-indicators/)
- [ ] `recommended` [Skip links](https://specification.website/spec/accessibility/skip-links/)
- [ ] `required` [Semantic HTML and landmarks](https://specification.website/spec/accessibility/semantic-html/)
- [ ] `recommended` [ARIA - first rule of ARIA](https://specification.website/spec/accessibility/aria-usage/)
- [ ] `required` [Descriptive link text](https://specification.website/spec/accessibility/link-text/)
- [ ] `avoid` [Empty links and buttons](https://specification.website/spec/accessibility/empty-links-buttons/)
- [ ] `required` [Accessible form errors](https://specification.website/spec/accessibility/form-errors/)
- [ ] `required` [Document and parts language](https://specification.website/spec/accessibility/document-language/)
- [ ] `required` [Reduced motion](https://specification.website/spec/accessibility/reduced-motion/)
- [ ] `avoid` [Accessibility overlays](https://specification.website/spec/accessibility/accessibility-overlays/)
- [ ] `required` [Captions and transcripts](https://specification.website/spec/accessibility/captions-and-transcripts/)
- [ ] `required` [Accessible data tables](https://specification.website/spec/accessibility/data-tables/)
- [ ] `required` [Touch target size](https://specification.website/spec/accessibility/touch-target-size/)
- [ ] `recommended` [Hidden until found](https://specification.website/spec/accessibility/hidden-until-found/)
- [ ] `recommended` [Native interactive elements](https://specification.website/spec/accessibility/native-interactive-elements/)
- [ ] `recommended` [CSS state and relational selectors](https://specification.website/spec/accessibility/css-state-selectors/)

## Security

- [ ] `required` [HTTPS and TLS](https://specification.website/spec/security/https-tls/)
- [ ] `required` [HSTS (Strict-Transport-Security)](https://specification.website/spec/security/hsts/)
- [ ] `recommended` [Content Security Policy (CSP)](https://specification.website/spec/security/content-security-policy/)
- [ ] `recommended` [/.well-known/security.txt](https://specification.website/spec/security/security-txt/)
- [ ] `required` [X-Content-Type-Options: nosniff](https://specification.website/spec/security/x-content-type-options/)
- [ ] `required` [Clickjacking protection (frame-ancestors / X-Frame-Options)](https://specification.website/spec/security/frame-ancestors/)
- [ ] `recommended` [Referrer-Policy](https://specification.website/spec/security/referrer-policy/)
- [ ] `recommended` [Permissions-Policy](https://specification.website/spec/security/permissions-policy/)
- [ ] `recommended` [Subresource Integrity (SRI)](https://specification.website/spec/security/subresource-integrity/)
- [ ] `required` [Cookie attributes - Secure, HttpOnly, SameSite](https://specification.website/spec/security/cookie-attributes/)
- [ ] `recommended` [DNS CAA records](https://specification.website/spec/security/caa-records/)
- [ ] `optional` [DNSSEC](https://specification.website/spec/security/dnssec/)

## Well-Known URIs

- [ ] `recommended` [Well-known URIs](https://specification.website/spec/well-known/well-known-overview/)
- [ ] `optional` [/.well-known/change-password](https://specification.website/spec/well-known/change-password/)
- [ ] `optional` [/.well-known/openid-configuration](https://specification.website/spec/well-known/openid-configuration/)
- [ ] `recommended` [/.well-known/api-catalog](https://specification.website/spec/well-known/api-catalog/)
- [ ] `optional` [/.well-known/webfinger](https://specification.website/spec/well-known/webfinger/)
- [ ] `optional` [/.well-known/apple-app-site-association](https://specification.website/spec/well-known/apple-app-site-association/)
- [ ] `optional` [/.well-known/assetlinks.json](https://specification.website/spec/well-known/assetlinks-json/)
- [ ] `optional` [/.well-known/nodeinfo](https://specification.website/spec/well-known/nodeinfo/)
- [ ] `optional` [/.well-known/traffic-advice](https://specification.website/spec/well-known/traffic-advice/)

## Agent Readiness

- [ ] `recommended` [Agent readiness](https://specification.website/spec/agent-readiness/agent-readiness-overview/)
- [ ] `recommended` [/llms.txt](https://specification.website/spec/agent-readiness/llms-txt/)
- [ ] `optional` [/llms-full.txt](https://specification.website/spec/agent-readiness/llms-full-txt/)
- [ ] `recommended` [Per-page Markdown source endpoints](https://specification.website/spec/agent-readiness/markdown-source-endpoints/)
- [ ] `recommended` [robots.txt for AI crawlers](https://specification.website/spec/agent-readiness/robots-for-ai-crawlers/)
- [ ] `optional` [Content Signals in robots.txt](https://specification.website/spec/agent-readiness/content-signals/)
- [ ] `optional` [Web Bot Auth - verifiable bot identity](https://specification.website/spec/agent-readiness/web-bot-auth/)
- [ ] `required` [Stable URLs](https://specification.website/spec/agent-readiness/stable-urls/)
- [ ] `recommended` [Structured data for agents](https://specification.website/spec/agent-readiness/structured-data-for-agents/)
- [ ] `recommended` [Machine-readable formats](https://specification.website/spec/agent-readiness/machine-readable-formats/)
- [ ] `recommended` [HTTP Link headers for discovery](https://specification.website/spec/agent-readiness/link-headers/)
- [ ] `optional` [MCP and tool discovery](https://specification.website/spec/agent-readiness/mcp-and-tool-discovery/)
- [ ] `optional` [A2A agent cards](https://specification.website/spec/agent-readiness/a2a-agent-cards/)
- [ ] `recommended` [Agent Skills discovery](https://specification.website/spec/agent-readiness/agent-skills-discovery/)
- [ ] `optional` [DNS for AI Discovery (DNS-AID)](https://specification.website/spec/agent-readiness/dns-aid/)
- [ ] `optional` [NLWeb - conversational interface discovery](https://specification.website/spec/agent-readiness/nlweb/)
- [ ] `optional` [WebMCP - browser-native tools for agents](https://specification.website/spec/agent-readiness/webmcp/)
- [ ] `optional` [Schemamap - discoverable JSON-LD endpoints per resource](https://specification.website/spec/agent-readiness/schemamap/)

## Performance

- [ ] `required` [Core Web Vitals (LCP, INP, CLS)](https://specification.website/spec/performance/core-web-vitals/)
- [ ] `required` [Image optimisation](https://specification.website/spec/performance/image-optimization/)
- [ ] `recommended` [Lazy loading images, iframes, and video](https://specification.website/spec/performance/lazy-loading/)
- [ ] `recommended` [Preload, prefetch, preconnect](https://specification.website/spec/performance/preload-prefetch-preconnect/)
- [ ] `required` [Cache-Control headers](https://specification.website/spec/performance/cache-control/)
- [ ] `recommended` [No-Vary-Search response header](https://specification.website/spec/performance/no-vary-search/)
- [ ] `required` [Compression (gzip, brotli, zstd)](https://specification.website/spec/performance/compression/)
- [ ] `recommended` [Web font loading](https://specification.website/spec/performance/font-loading/)
- [ ] `recommended` [Critical CSS and render-blocking resources](https://specification.website/spec/performance/critical-css/)
- [ ] `recommended` [Script loading - defer, async, module](https://specification.website/spec/performance/script-loading/)
- [ ] `recommended` [HTTP/2 and HTTP/3](https://specification.website/spec/performance/http3/)
- [ ] `recommended` [Speculation Rules](https://specification.website/spec/performance/speculation-rules/)
- [ ] `recommended` [Resource hints overview](https://specification.website/spec/performance/resource-hints/)
- [ ] `recommended` [View Transitions](https://specification.website/spec/performance/view-transitions/)
- [ ] `recommended` [Back/forward cache (BFCache)](https://specification.website/spec/performance/bfcache/)
- [ ] `recommended` [Visibility-aware rendering](https://specification.website/spec/performance/visibility-aware-rendering/)
- [ ] `optional` [CSS containment](https://specification.website/spec/performance/css-containment/)
- [ ] `optional` [Scroll-driven animations](https://specification.website/spec/performance/scroll-driven-animations/)
- [ ] `recommended` [Scrollbar gutter](https://specification.website/spec/performance/scrollbar-gutter/)

## Privacy

- [ ] `required` [Privacy policy](https://specification.website/spec/privacy/privacy-policy/)
- [ ] `required` [Cookie consent](https://specification.website/spec/privacy/cookie-consent/)
- [ ] `recommended` [Global Privacy Control (GPC)](https://specification.website/spec/privacy/global-privacy-control/)
- [ ] `recommended` [Third-party scripts and privacy](https://specification.website/spec/privacy/third-party-scripts/)
- [ ] `recommended` [Privacy-respecting analytics](https://specification.website/spec/privacy/analytics-privacy/)
- [ ] `recommended` [Data minimisation](https://specification.website/spec/privacy/data-minimization/)

## Resilience

- [ ] `required` [Custom error pages (404, 500)](https://specification.website/spec/resilience/error-pages/)
- [ ] `recommended` [Maintenance pages and 503](https://specification.website/spec/resilience/maintenance-pages/)
- [ ] `optional` [Offline support and service workers](https://specification.website/spec/resilience/offline-support/)
- [ ] `recommended` [Web app manifest](https://specification.website/spec/resilience/pwa-manifest/)
- [ ] `recommended` [Monitoring and uptime](https://specification.website/spec/resilience/monitoring-uptime/)

## Internationalisation

- [ ] `recommended` [International URL structure](https://specification.website/spec/i18n/international-url-structure/)
- [ ] `recommended` [hreflang for language and regional URLs](https://specification.website/spec/i18n/hreflang/)
- [ ] `recommended` [Localised page metadata](https://specification.website/spec/i18n/localised-metadata/)
- [ ] `optional` [hreflang in XML sitemaps](https://specification.website/spec/i18n/sitemap-hreflang/)
- [ ] `avoid` [Avoid automatic IP-based language redirects](https://specification.website/spec/i18n/avoid-auto-geo-redirects/)
- [ ] `required` [lang attribute on inline content](https://specification.website/spec/i18n/lang-attribute/)
- [ ] `recommended` [Language switcher](https://specification.website/spec/i18n/language-switcher/)
- [ ] `recommended` [RTL and bidirectional text](https://specification.website/spec/i18n/rtl-support/)
- [ ] `optional` [Writing modes and CJK line breaking](https://specification.website/spec/i18n/writing-modes/)
- [ ] `recommended` [Locale-aware content](https://specification.website/spec/i18n/locale-content/)
- [ ] `recommended` [Plural rules and grammatical number](https://specification.website/spec/i18n/plural-rules/)
- [ ] `optional` [Internationalised Domain Names (IDN)](https://specification.website/spec/i18n/idn-support/)
