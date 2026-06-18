# C4 Notation Guidance

Use notation to make the diagram self-explanatory. The exact shapes and colors can vary, but the meaning must be explicit and consistent.

## Titles

- Include a short title on every diagram.
- Include the diagram type and scope, for example `System Context diagram for Payments Platform` or `[Container] Internet Banking System`.
- Number diagrams or otherwise indicate reading order when a set should be consumed sequentially.

## Legends And Keys

Add a legend whenever meaning is encoded in:

- Shapes.
- Line styles.
- Colors.
- Borders.
- Icons.
- Acronyms.
- Special markers such as shared, external, deprecated, risky, or changed.

Even obvious notation can be misread by people with different backgrounds. Prefer a small legend over a verbal explanation that will be lost later.

## Elements

For C4 elements, include:

- Person: name and short description.
- Software system: name and short responsibility.
- Container: name, technology, and short responsibility.
- Component: name, technology when useful, and short responsibility.

Avoid boxes with names only. Names are ambiguous; responsibility text removes much of that ambiguity. A short sentence or compact bullet list is enough.

## Color

Use color to supplement a diagram that already makes sense in text and structure. Good uses include:

- Existing vs new.
- Custom build vs off-the-shelf.
- Technology/platform grouping.
- Ownership.
- Internal vs external.
- Risk or complexity.
- Modified/removed/unchanged in a release.

Always explain color in the legend. Make the diagram still usable for color-blind readers and grayscale printouts.

## Shapes And Borders

- Start from simple boxes-and-lines if in doubt.
- Use shapes to improve scanability, not as the only carrier of meaning.
- Use borders or enclosing boxes for boundaries such as enterprise, system, container, trust, network, or deployment boundaries.
- Label boundaries directly or explain them in the legend.
- Keep element sizes broadly consistent unless size intentionally communicates scale, complexity, or importance.

## Lines

Every important relationship should be labelled. Good labels read as a sentence when combined with source, arrow, and target.

Prefer:

- `Web Application -> Database: reads from and writes to`
- `API Application -> Email System: sends email using SMTP`
- `Mobile App -> API Application: makes JSON/HTTPS API calls to`

Avoid:

- Unlabelled lines.
- Labels that do not match arrow direction.
- Vague labels such as `uses` when a more specific phrase would clarify the interaction.

Choose relationship direction deliberately. A common default is dependency or initiator-to-receiver direction. Data-flow direction is also valid if the label makes that clear. Be consistent within a diagram set.

Use line style and color for additional information such as synchronous vs asynchronous, internal vs external, encrypted vs unencrypted, or request/response vs event stream. Explain those styles in the legend.

## Layout

- Put the most important element near the center and arrange other elements around it.
- Keep placement consistent across related diagrams; for example, users at the top and external dependencies at the bottom.
- Minimize line crossings and long diagonal lines.
- Keep diagrams scoped so a reader can understand the main story quickly.
- When a diagram is too busy, split by feature, bounded context, business process, use case, user interaction, or component entry point instead of enlarging the canvas.

## Acronyms

Avoid domain acronyms where possible. When acronyms are necessary, expand them in the legend, glossary, or nearby text. Widely understood technology acronyms may not need expansion, but decide based on the intended audience.

## Quality Attributes

Do not force all quality attribute detail onto static C4 diagrams. Add lightweight text when it clarifies:

- Expected users or concurrency.
- Data volumes.
- Latency targets.
- Availability or replication.
- Security-critical boundaries or trust zones.

Use Deployment, runtime, or supplementary documentation for details that would clutter System Context, Container, or Component diagrams.
