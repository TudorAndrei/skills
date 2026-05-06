---
name: typst
description: Create, edit, migrate, review, debug, and compile Typst (.typ) documents and templates. Use when working with Typst markup, math, citations, bibliography files, figures, tables, page layout, set/show rules, packages, Typst Universe templates, CLI commands such as typst compile/watch/fonts/init/eval, or LaTeX-to-Typst style conversion.
---

# Typst

Use this skill to produce correct, maintainable Typst documents and to diagnose Typst compilation or layout issues.

## Source Priority

1. Check the official Typst documentation first for language, library, export, web app, package, and changelog details: `https://typst.app/docs/`.
2. Use Typst Universe for published packages and templates: `https://typst.app/universe/`.
3. For version-sensitive behavior, verify against the current docs or changelog before making claims.

Query Typst Universe through its search and category pages when a task needs an existing template or utility package. Filter by kind (`Package` or `Template`) and categories such as Office, CV, Presentation, Flyer, Poster, Paper, Thesis, Report, Book, Utility, Visualization, Layout, Text, Scripting, and Integration.

## Workflow

1. Determine the task: author a document, edit existing Typst, debug a compile error, build a reusable template, use a package, export through the CLI, or migrate from another format.
2. Inspect local files before editing: look for `*.typ`, `typst.toml`, bibliography files (`*.bib`, `*.yaml`, `*.yml`), images, and established template modules.
3. Preserve the project's existing style: naming, imports, template function shape, page setup, heading numbering, citation style, and output target.
4. Put reusable styling in a template/module file when a document has more than a few global rules.
5. Validate with the Typst CLI whenever available. Prefer `typst compile input.typ output.pdf` for PDF, `typst watch input.typ output.pdf` while iterating, and `typst fonts` when font availability is in question.
6. If the `typst` binary is unavailable, state that validation was not run and keep syntax conservative.

## Authoring Guidance

- Treat Typst as three modes: markup by default, code after `#`, and math inside `$...$`. Use `[...]` content blocks when passing markup as values.
- Prefer semantic Typst elements (`heading`, `figure`, `table`, `bibliography`, `cite`, `link`) over hand-drawn layout when the document structure matters.
- Use `#set` rules for broad element defaults, and `#show` rules for transformations or scoped style overrides.
- Keep package and template APIs explicit. Prefer named parameters with defaults and a final content parameter such as `doc`.
- Use kebab-case for public Typst identifiers.
- Keep paths relative to the file using them unless the project intentionally relies on a CLI `--root`.
- Pass project assets into packages/templates as already loaded values when a package needs project-specific resources.

## Common Commands

```bash
typst compile main.typ main.pdf
typst watch main.typ main.pdf
typst compile main.typ page-{p}.png --format png
typst compile main.typ main.svg --format svg
typst fonts
typst fonts --variants
typst init @preview/package-name:version project-name
```

For experimental HTML export, verify the current docs and require the feature flag:

```bash
typst compile --features html main.typ main.html
typst watch --features html main.typ main.html
```

## Debugging

- Read the full diagnostic first; Typst errors usually point to the source span and expected type.
- Compile the smallest relevant entrypoint, not every file in a project.
- Check imports, root-relative paths, bibliography file formats, font names, and package versions before changing document structure.
- When a document depends on fonts, run `typst fonts` and either choose an available font or document the missing font requirement.
- Prefer fixing the source of a layout issue with set/show rules, container sizing, page setup, or table/grid parameters instead of inserting arbitrary spacing.

## Reference

Read `references/typst-quick-reference.md` when writing nontrivial Typst, converting from LaTeX/Markdown, building templates, using citations, or debugging syntax/mode issues.
