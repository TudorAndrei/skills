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
5. For current details, source rationale, or implementation specifics, fetch the linked specification page or its Markdown variant at `https://specification.website/spec/<category>/<slug>.md`.
6. When the environment has MCP access, prefer the live server at `https://mcp.specification.website/mcp` using `get_checklist`, `list_topics`, or `get_topic`.

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
