# Website Checklist

Use The Website Specification as the audit contract for modern website quality.

## Workflow

1. Clarify the audit scope from the user request: full site, one page, launch readiness, agent readiness, accessibility, security, or another category.
2. Load [checklist.md](checklist.md) when you need the complete checklist or category/status filters.
3. Prioritize statuses in this order:
   - `required`: platform, accessibility, security, or discoverability expectations that should be fixed first.
   - `avoid`: harmful or obsolete patterns; flag these as defects, not missing enhancements.
   - `recommended`: modern baseline items after required failures are handled.
   - `optional`: context-dependent items; mark `N/A` when the site has no applicable feature.
4. Do not silently upgrade `recommended` or `optional` items to `required`. Preserve the source status labels.
5. When the scope includes accessibility or agent readiness, run the matching machine pass below before judging those items by eye.
6. For current details, source rationale, or implementation specifics, fetch the linked specification page or its Markdown variant at `https://specification.website/spec/<category>/<slug>.md`.
7. When the environment has MCP access, prefer the live server at `https://mcp.specification.website/mcp` using `get_checklist`, `list_topics`, or `get_topic`.

## Accessibility Machine Pass

`agent-browser a11y` runs a vendored axe-core audit against a rendered page and returns WCAG violations with the CSS selector of each offending node and a link to the rule's fix guidance — evidence you can paste straight into the checklist output.

```bash
agent-browser a11y https://example.com --json          # structured violations + incomplete results
agent-browser a11y https://example.com --tags wcag2a,wcag2aa   # scope to a conformance level
agent-browser a11y --selector "#main"                  # scope to a subtree of the current page
```

Node targets are axe selector paths: nested arrays cross a shadow-DOM boundary, multiple path entries cross a frame boundary. Requires a CDP browser session (unavailable on Safari/iOS WebDriver). Run it per template rather than per URL — one product page, one article, one form — since violations repeat across a template.

Axe settles the static-markup items on its own: colour contrast, image alt text, form labels, document language, ARIA usage, empty links and buttons, data tables, descriptive link text. It reports `incomplete` results it cannot decide — treat those as manual checks, not passes. The rest of the accessibility category is behavioural and stays hands-on: keyboard navigation, visible focus indicators, focus order, skip links, touch target size, reduced motion, captions and transcripts, hidden-until-found, and accessibility overlays.

## Agent Readiness Machine Pass

`is-agentic` scans a domain for the properties agents depend on and returns a score plus the evidence behind each check — run it before judging the Agent Readiness category by hand.

```bash
npx is-agentic example.com            # human-readable report
npx is-agentic example.com --json     # structured output for the checklist
```

It settles the discoverable items: server-rendered content, HTTP and error-response behaviour, page structure, `robots.txt` rules for AI crawlers, stable URLs, and machine-readable formats. It also detects the optional interfaces the site exposes — API, OAuth, GraphQL, MCP server — which maps onto the `optional` rows in the checklist: a detection means the row applies, no detection means `N/A`, not FAIL. Reported friction from its agent journey is the evidence to paste against a failing row.

What it does not decide stays manual: `/llms.txt` and `/llms-full.txt` content quality, per-page markdown source endpoints, Content Signals, Web Bot Auth, A2A agent cards, Agent Skills discovery, DNS-AID, NLWeb, WebMCP, and Schemamap. Reports live at a stable public URL, also reachable via the JSON API at `https://is-agentic.com/api/v1/report` or the project's MCP server. For the underlying recommendations, see the Agentic Experiences section in [ai-search.md](ai-search.md).

## Output Pattern

For audits, report results as a grouped checklist with evidence:

```markdown
## Accessibility

- [ ] `required` Image alt text - FAIL: product gallery images have empty `alt` values.
- [x] `required` Keyboard navigation - PASS: primary nav and checkout can be completed by keyboard.
- [ ] `avoid` Accessibility overlays - PASS: no overlay script found.
```

For planning, return a scoped task list. Keep required and avoid items above recommended work.

The SEO category here is a lightweight checklist (robots.txt, sitemaps, structured data, breadcrumbs). When it surfaces deeper SEO work, move to the audit, ai-search, programmatic, or technical-growth guides in this skill.
