# Machine-readable surface with AgentMarkup

Sources: https://agentmarkup.dev/, https://agentmarkup.dev/llms.txt, https://agentmarkup.dev/docs/audit/, https://github.com/agentmarkup/agentmarkup (MIT)

AgentMarkup is an open-source package family that generates and validates the files that crawlers and AI agents read. It runs at build time or after the build, and adds no browser JavaScript. Check the current documentation before you write config; the packages are young and change.

## What a machine reads

| Surface          | Purpose                                                                 |
| ---------------- | ----------------------------------------------------------------------- |
| Raw HTML         | The content itself. Most crawlers do not run JavaScript.                |
| Page metadata    | Title, description, and canonical link, used to attribute the page.     |
| JSON-LD          | schema.org data that says what the page is (Product, Article, FAQPage). |
| `robots.txt`     | Access rules for each crawler, and the sitemap location.                |
| `sitemap.xml`    | The list of indexable URLs.                                             |
| `llms.txt`       | A short manifest for LLMs: what the site is and which pages matter.     |
| Markdown mirrors | A clean `.md` version of a page for agents that fetch.                  |
| Content-Signal   | A header or `robots.txt` line that states usage preferences.            |

`llms.txt` is a proposal from llmstxt.org, not a standard. JSON-LD, valid HTML, and correct `robots.txt` are useful without it. Markdown mirrors help most when the raw HTML is thin, noisy, or client-rendered; when the HTML already has the content, keep HTML as the primary target.

## Packages

| Package              | Use                                                                          |
| -------------------- | ---------------------------------------------------------------------------- |
| `@agentmarkup/next`  | Next.js. Strongest where Next emits build-time HTML.                         |
| `@agentmarkup/vite`  | Vite applications and static sites.                                          |
| `@agentmarkup/astro` | Astro builds.                                                                |
| `@agentmarkup/nuxt`  | Prerendered Nuxt output (`nuxt generate`).                                   |
| `@agentmarkup/cli`   | Any built static directory (Eleventy, Hugo, Jekyll, Docusaurus, plain HTML). |
| `@agentmarkup/audit` | Fetches a deployed URL as each AI crawler and compares with a browser.       |
| `@agentmarkup/core`  | Generators and validators for a custom pipeline or a dynamic SSR route.      |

Install the adapter as a development dependency, for example `pnpm add -D @agentmarkup/astro`. Use the project's own package manager.

## Shared config

All adapters and the CLI take the same config object. Fill it from what the repository already declares; do not invent pages, prices, or organization data.

```js
const agentmarkupConfig = {
  site: "https://example.com",
  name: "Example",
  description: "One sentence that says what the site is.",
  llmsTxt: {
    whenToUse: ["The visitor asks what the plans cost or which plan fits a use case."],
    sections: [
      {
        title: "Pages",
        entries: [{ title: "Pricing", url: "/pricing", description: "Plans and prices" }],
      },
    ],
  },
  llmsFullTxt: { enabled: true },
  markdownPages: { enabled: true, exclude: ["/404"] },
  globalSchemas: [
    { preset: "webSite", name: "Example", url: "https://example.com" },
    { preset: "organization", name: "Example", url: "https://example.com", logo: "/logo.png" },
  ],
  pages: [
    {
      path: "/faq",
      schemas: [
        {
          preset: "faqPage",
          url: "https://example.com/faq",
          questions: [{ question: "Do you ship internationally?", answer: "Yes." }],
        },
      ],
    },
  ],
  aiCrawlers: { GPTBot: "allow", ClaudeBot: "allow", PerplexityBot: "allow", CCBot: "disallow" },
};
```

Wire it into the adapter:

```js
// Vite
export default defineConfig({ plugins: [agentmarkup(agentmarkupConfig)] }); // from "@agentmarkup/vite"

// Astro
export default defineConfig({ integrations: [agentmarkup(agentmarkupConfig)] }); // from "@agentmarkup/astro"

// Next.js
export default withAgentmarkup(agentmarkupConfig, nextConfig); // from "@agentmarkup/next"

// Nuxt
export default defineNuxtConfig({ modules: ["@agentmarkup/nuxt"], agentmarkup: agentmarkupConfig });
```

The Next.js adapter does not cover fully dynamic SSR routes that have no build-time HTML file. Use the `@agentmarkup/core` helpers in those routes.

## CLI for any static output

Put the same object in `agentmarkup.config.mjs` (default export) in the project root.

```bash
agentmarkup generate ./dist            # inject and write the files
agentmarkup generate ./dist --dry-run  # report planned writes, change nothing
agentmarkup check ./dist               # validate what is on disk; exit 1 on an error finding
agentmarkup check ./dist --strict      # also fail on warnings
```

- The output directory comes from the argument, then config `outDir`, then `dist`, `build`, `out`, or `_site`. `public/` is never guessed.
- Existing `llms.txt`, `robots.txt` rules, and page JSON-LD are kept by default. Replacement is opt-in per feature (`llmsTxt.replaceExisting`, `markdownPages.replaceExisting`, `jsonLd.replaceExistingTypes`).

## Generated files

- **`llms.txt`** - an H1 with the site name, a blockquote description, optional instructions, then H2 sections of Markdown links. Links must use `- [Label](https://example.com/page)`; bare URLs are flagged. `whenToUse` lists the concrete jobs the site answers, written as tasks, and what the site is not for.
- **`llms-full.txt`** - the same manifest with the same-site markdown mirror content inlined.
- **Markdown mirrors** - a `.md` companion for each page, with a canonical relationship to the HTML. Exclude pages that are not content, such as `/404`; a mirrored 404 page answers `200` with "not found" text. With mirrors on, `llms.txt` entries point to the `.md` URLs; set `llmsTxt.preferMarkdownMirrors: false` to keep HTML routes.
- **JSON-LD** - presets `webSite`, `organization`, `article`, `faqPage`, `product`, and `offer`, or any object with an `@type`. The tool adds `@context` and escapes `<`, `>`, `&`, and `'`. A missing required field is an error; a missing recommended field is a warning.
- **`robots.txt`** - the tool writes only the block between `# BEGIN agentmarkup AI crawlers` and `# END agentmarkup AI crawlers`, and leaves other rules alone. It warns when a `User-agent: *` `Disallow: /` rule conflicts with a crawler that the config allows.
- **Headers** - Content-Signal headers and an optional A2A Agent Card, written as static files or host header rules.

## AI crawlers

`robots.txt` rules apply per user agent, so training crawlers can be blocked while search and user-triggered fetchers stay allowed.

| Intent               | User agents                                                                                       |
| -------------------- | ------------------------------------------------------------------------------------------------- |
| Model training       | `GPTBot`, `ClaudeBot`, `Google-Extended`, `CCBot`, `Applebot-Extended`, `Amazonbot` (also search) |
| AI search, retrieval | `OAI-SearchBot`, `PerplexityBot`, `Claude-SearchBot`, `DuckAssistBot`                             |
| User-triggered fetch | `ChatGPT-User`, `Claude-User`, `Perplexity-User`                                                  |

- Configure only the crawlers that the user has decided on. The allow or block choice is a business decision; ask.
- `robots.txt` is voluntary. It is not access control, and some crawlers ignore it. Put private content behind authentication.
- A site that blocks the search and user-triggered agents cannot be cited by them.

## Audit a deployed URL

```bash
npx @agentmarkup/audit https://example.com          # exit 1 on an error finding, 2 on a usage error
npx @agentmarkup/audit https://example.com --json   # machine output for CI
```

The audit fetches the URL with each AI crawler's user agent and compares the result with a browser fetch. It checks crawler access, JavaScript dependence, `robots.txt`, `llms.txt`, JSON-LD, markdown mirrors, the sitemap, and page metadata. Findings are pass, warn, or error.

Read the findings with care:

- The audit sends a crawler's user agent from an ordinary IP address. A `403` for that request can be a user-agent rule in a WAF, which also blocks the real crawler, or IP allowlisting, which lets the real crawler through. The audit reports it as a warning. Do not tell the user "the site blocks AI" from one blocked request; check the WAF or CDN bot settings.
- Error findings are provable from the response: a `robots.txt` that disallows the crawler, an empty JavaScript shell, or invalid `llms.txt` or JSON-LD.
- An `llms.txt` URL that returns HTML with a `200` status is a soft 404, not a manifest.

The hosted website checker (https://agentmarkup.dev/checker/) runs the same idea in the browser and gives a 0-100 score from a published formula. The score is not a ranking, traffic, or citation guarantee. Do not make up a readiness score. Point the checker, the audit, and the security scan only at sites the user owns or is authorized to test.

## CI shape

```yaml
- run: pnpm build
- run: pnpm exec agentmarkup check ./dist # the built files
# after deploy
- run: npx @agentmarkup/audit https://example.com # the live response
```

The build check finds a broken or missing file before release. The live audit finds what the host, CDN, or WAF changes after release. Use both.

## When not to add it

- An application behind a login has no public surface to describe. Set `robots.txt` and stop.
- A site that already generates these files from its own framework features (a sitemap and metadata API, typed JSON-LD) can keep them; use `agentmarkup check` or the audit as the gate only.
