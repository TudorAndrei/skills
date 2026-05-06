---
name: pandoc
description: Create, convert, template, review, and debug Pandoc-based business documents and presentation workflows. Use when working with Pandoc, Markdown-to-PDF, LaTeX PDF output, Beamer slide decks, official documents, DOCX/HTML/EPUB outputs, citations, CSL files, bibliography files, reference DOCX files, Pandoc defaults YAML, Pandoc templates, filters, or CLI commands such as pandoc --defaults, --pdf-engine, -t beamer, --citeproc, -D, and -o.
---

# Pandoc

Use this skill to produce polished business outputs from source documents: PDF reports, official letters, Beamer presentations, DOCX handoffs, HTML pages, EPUBs, and reusable Pandoc project templates.

## Source Priority

1. Prefer local project conventions first: existing `*.md`, `defaults/*.yaml`, templates, `reference.docx`, `*.bib`, CSL files, assets, and build scripts.
2. Verify version-sensitive CLI details against official Pandoc documentation before relying on rarely used flags: `https://pandoc.org/MANUAL.html`.
3. Use `pandoc --version`, `pandoc --list-output-formats`, `pandoc --list-input-formats`, and `pandoc -D FORMAT` when the installed Pandoc behavior matters.

## Workflow

1. Identify the target output: `pdf`, `beamer`, `docx`, `html`, `epub`, `pptx`, or another Pandoc writer.
2. Inspect the source folder before editing. Look for defaults files, templates, citation assets, images, fonts, and prior output naming.
3. Choose the smallest reliable build path:
   - For business PDFs, start from Markdown plus `assets/defaults/business-pdf.yaml`.
   - For presentations, start from Markdown plus `assets/defaults/beamer.yaml`.
   - For DOCX handoffs, use a project `reference.docx` when available; otherwise keep formatting conservative.
   - For repeatable builds, prefer a defaults YAML file over long one-off command lines.
4. Keep source documents semantic. Use headings, fenced code blocks, tables, figure captions, citations, and metadata instead of hard-coded layout where possible.
5. Validate by running Pandoc when available. If PDF output is requested, also confirm that the selected PDF engine and required fonts are installed.
6. State clearly when validation could not run because `pandoc`, LaTeX, a PDF engine, fonts, images, or citation files are missing.

## Common Commands

Use direct commands for quick work:

```bash
pandoc source.md -o report.pdf --pdf-engine=xelatex
pandoc -t beamer slides.md -o slides.pdf --pdf-engine=xelatex
pandoc source.md -o handoff.docx
pandoc source.md -s -o page.html
pandoc slides.md -o handoff.pptx
pandoc source.md -o publication.epub
pandoc source.md --citeproc --bibliography refs.bib --csl style.csl -o report.pdf
```

Use bundled defaults for repeatable business outputs:

```bash
scripts/pandoc_build.sh pdf report.md report.pdf
scripts/pandoc_build.sh beamer deck.md deck.pdf
scripts/pandoc_build.sh docx report.md report.docx
scripts/pandoc_build.sh html report.md report.html
scripts/pandoc_build.sh pptx deck.md deck.pptx
scripts/pandoc_build.sh epub report.md report.epub
```

Pass additional Pandoc flags after the output path:

```bash
scripts/pandoc_build.sh pdf report.md report.pdf --metadata title="Q2 Board Memo"
```

## Business PDF Guidance

- Use YAML metadata for title, subtitle, author, date, subject, keywords, confidentiality, and document version.
- Prefer `xelatex` or `lualatex` for business PDFs that need modern fonts; fall back to `pdflatex` only when portability matters more than typography.
- For official documents, include explicit revision/date metadata and avoid unreviewed generated boilerplate in legal, financial, HR, or compliance text.
- Use `--toc`, `--number-sections`, and consistent heading depth for reports, policies, proposals, and board materials.
- Use citations through `--citeproc`, `--bibliography`, and `--csl` rather than manually formatted references.

Read `references/business-workflows.md` for structure patterns, metadata examples, and quality checks.

## Beamer Guidance

- Use `#` for section slides and `##` for actual slides when `slide-level: 2`.
- Keep slide prose short; move speaker notes and detail into appendix or handout PDFs.
- Prefer Pandoc Beamer variables and defaults YAML for theme, aspect ratio, logo, institute, and navigation settings.
- Verify LaTeX theme availability before choosing nonstandard themes such as Metropolis.
- Use images with relative paths and keep them under a project-local `assets/` or `images/` directory.

Start from `assets/templates/beamer-deck.md` when no deck exists. Read `references/business-workflows.md` for deck structure guidance.

## Templates And Defaults

- Use `pandoc -D latex`, `pandoc -D beamer`, or `pandoc -D html` to inspect the installed default template before customizing.
- Put reusable build options in a defaults file. Pandoc defaults support YAML configuration, variables, metadata, resource paths, and reusable option sets.
- Keep custom templates small and project-specific. Avoid copying the full default template unless a complete fork is genuinely needed.
- For DOCX output, prefer `--reference-doc=reference.docx` when exact corporate styles are required.

Bundled starters:

- `assets/defaults/business-pdf.yaml`: conservative PDF defaults for business reports.
- `assets/defaults/beamer.yaml`: Beamer PDF defaults for 16:9 presentations.
- `assets/defaults/docx.yaml`: DOCX handoff defaults.
- `assets/defaults/html.yaml`: standalone HTML defaults.
- `assets/defaults/pptx.yaml`: editable slide handoff defaults.
- `assets/defaults/epub.yaml`: EPUB publication defaults.
- `assets/templates/business-report.md`: report/proposal/policy starter.
- `assets/templates/official-letter.md`: formal letter or memo starter.
- `assets/templates/beamer-deck.md`: Beamer deck starter.

## Debugging

- Read the full Pandoc error first. Most failures are missing files, unsupported output format, YAML syntax, missing LaTeX packages, unavailable fonts, or invalid citation data.
- Run a minimal build before changing document structure.
- Use `--verbose` for unclear conversion failures.
- For PDF failures, isolate whether the issue is Pandoc, the generated LaTeX, the PDF engine, or a missing package/font.
- For image failures, check paths relative to the source file and `resource-path`.
- For citation failures, validate the bibliography file and CSL path.
