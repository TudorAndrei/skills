# Pandoc Business Workflows

## Output Selection

Choose the target based on how the document will be used:

| Need | Output | Notes |
| --- | --- | --- |
| Executive memo, report, policy, proposal | PDF | Use a defaults YAML, TOC when useful, numbered headings for long documents. |
| Board or client presentation | Beamer PDF | Use concise Markdown slides and keep the theme conservative unless branding exists. |
| Editable handoff | DOCX | Use `reference.docx` for corporate styles when provided. |
| Intranet or email-compatible page | HTML | Use standalone HTML for simple sharing; use a full site generator for multi-page docs. |
| Reusable publication | EPUB | Check images, metadata, heading order, and accessibility. |
| Slide handoff to Office users | PPTX | Prefer a `reference.pptx` if the team needs branded layouts. |

## Recommended Project Layout

```text
project/
├── source.md
├── defaults/
│   ├── pdf.yaml
│   └── beamer.yaml
├── assets/
│   ├── logo.png
│   └── figures/
├── refs.bib
├── style.csl
└── output/
```

Keep all referenced images and bibliography files project-local. Use relative paths so the build works in another workspace.

## Metadata Patterns

Business PDF starter:

```yaml
---
title: "Quarterly Business Review"
subtitle: "Executive summary and operating plan"
author: "Strategy Office"
date: "2026-05-06"
subject: "Business review"
keywords: ["business", "strategy", "operations"]
confidentiality: "Internal"
version: "1.0"
---
```

Beamer starter:

```yaml
---
title: "Client Strategy Review"
subtitle: "Decision points and next steps"
author: "Commercial Team"
institute: "Company Name"
date: "2026-05-06"
---
```

## Beamer Authoring Pattern

With `slide-level: 2`, use this shape:

```markdown
# Section Name

## Slide Title

- One idea per bullet
- Keep lines short
- Use figures where they explain more than prose

## Decision

**Recommendation:** Approve the phased rollout.

**Rationale:** Lower delivery risk and earlier customer feedback.
```

Use appendix slides for details that matter but should not interrupt the presentation.

## Official Document Pattern

Use plain, reviewable structure:

```markdown
# Purpose

# Scope

# Background

# Policy / Proposal / Recommendation

# Responsibilities

# Timeline

# Risks And Controls

# Approval
```

For legal, financial, HR, compliance, or regulated documents, mark AI-generated text as draft content until reviewed by the appropriate owner.

## Citation Workflow

Use Pandoc citeproc for formal references:

```bash
pandoc report.md --citeproc --bibliography refs.bib --csl style.csl -o report.pdf
```

In Markdown, cite with keys from the bibliography:

```markdown
Market growth remains concentrated in the top segment [@source2026].
```

## Quality Checks

- Confirm the output opens and has the expected page/slide count.
- Check title, author, date, confidentiality, and version metadata.
- Check heading levels and slide breaks.
- Check tables for overflow in PDF and Beamer.
- Check images render at usable resolution.
- Check citations and bibliography formatting.
- Check fonts and brand assets are available in the environment.
- Re-run the exact build command after edits.
