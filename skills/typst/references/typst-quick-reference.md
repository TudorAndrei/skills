# Typst Quick Reference

## Documentation Map

- Overview and tutorial: `https://typst.app/docs/`
- Syntax: `https://typst.app/docs/reference/syntax/`
- Styling: `https://typst.app/docs/reference/styling/`
- Scripting: `https://typst.app/docs/reference/scripting/`
- Page setup: `https://typst.app/docs/guides/page-setup/`
- Tables guide: `https://typst.app/docs/guides/tables/`
- Accessibility guide: `https://typst.app/docs/guides/accessibility/`
- Bibliography: `https://typst.app/docs/reference/model/bibliography/`
- HTML export: `https://typst.app/docs/reference/html/`
- Changelog: `https://typst.app/docs/changelog/`
- Universe packages and templates: `https://typst.app/universe/`

## Syntax Essentials

```typst
= Heading
== Subheading

This is _emphasis_ and *strong emphasis*.

- Bullet item
+ Numbered item
/ Term: Description

Inline math: $x^2 + y^2 = z^2$

$ integral_0^1 x^2 dif x $

#let name = "Typst"
#emph[Hello #name]
```

Use `#` to enter code from markup. Use `$...$` for math. Use `[...]` for content values that can be passed to functions or stored in variables.

## Set and Show Rules

```typst
#set document(title: [Report])
#set page(paper: "a4", margin: 2.5cm)
#set text(font: "New Computer Modern", size: 11pt)
#set heading(numbering: "1.")

#show heading.where(level: 1): set text(size: 16pt, weight: "bold")
#show link: underline
```

Use `set` for configurable element properties. Use `show` to select elements and change how they render.

## Templates

Prefer a reusable function in a separate file:

```typst
// template.typ
#let report(title: [], authors: (), doc) = {
  set document(title: title)
  set heading(numbering: "1.")

  align(center)[
    #text(size: 18pt, weight: "bold")[#title]
    #for author in authors [
      #author \
    ]
  ]

  doc
}
```

Apply it from the main file:

```typst
#import "template.typ": report

#show: report.with(
  title: [A Short Report],
  authors: ("Ada Lovelace", "Grace Hopper"),
)

= Introduction
Body text.
```

## Imports and Packages

```typst
#import "template.typ": report
#include "sections/introduction.typ"

#import "@preview/example:0.1.0": add
#add(2, 7)
```

Use `import` for definitions and modules. Use `include` to insert another file's content. For packages, verify exact names and versions on Typst Universe.

## Figures, Tables, and References

```typst
#figure(
  image("chart.png", width: 80%),
  caption: [Measured throughput],
) <fig:throughput>

See @fig:throughput.

#table(
  columns: (1fr, 1fr, 1fr),
  table.header([Name], [Value], [Unit]),
  [Latency], [12], [ms],
  [Rate], [42], [req/s],
)
```

Label important structural elements with `<label>` and refer to them with `@label`.

## Citations

```typst
Prior work showed this effect @smith2024.

#bibliography("works.bib", style: "ieee")
```

Typst supports BibLaTeX `.bib` files and Hayagriva `.yaml`/`.yml` files. Choose a style appropriate to the discipline, such as `"ieee"`, `"apa"`, `"chicago-author-date"`, `"mla"`, or `"american-physics-society"`.

## CLI Validation

```bash
typst compile main.typ main.pdf
typst watch main.typ main.pdf
typst fonts --variants
```

For image export, use an output filename or `--format` matching the target. For multipage PNG/SVG exports, use a page-number pattern such as `page-{p}.png`.

For HTML export, verify current status first. It is experimental and requires `--features html` or `TYPST_FEATURES=html`.

## Common Pitfalls

- A bare `#` starts code; escape a literal hash as `\#`.
- Content blocks use square brackets, while code blocks use braces.
- Top-level set rules affect following content; nested rules are scoped to their block.
- Absolute paths start at the Typst project root, not the filesystem root.
- By default, the CLI project root is the parent directory of the main Typst file unless `--root` is supplied.
- Packages can only load files from their own package directory; pass project assets into templates/packages as parameters.
