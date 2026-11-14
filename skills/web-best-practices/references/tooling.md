# Toolkit

Run a tool on the built output or the deployed URL, not on the source. For each finding, record the tool and whether the data is lab or field. Check a tool's current documentation for flags before you write a CI step.

## HTML validity

- [html-validate](https://html-validate.org/) - offline validator with rules for structure, accessibility basics, and deprecated markup. `npx html-validate "dist/**/*.html"`.
- [Nu HTML Checker](https://validator.w3.org/nu/) - the reference validator for the HTML standard. Use it for a single page or as a second opinion.

Neither tool sees content that script inserts later. Validate the server response and, for client-rendered routes, the DOM from a real browser.

## Links

- [lychee](https://lychee.cli.rs/) - fast link checker for built files and live pages. `lychee './dist/**/*.html'` or `lychee https://example.com`. The exit code is not 0 when a link fails.

## Performance

- [Lighthouse](https://developer.chrome.com/docs/lighthouse) - lab audit of one page load. `lighthouse https://example.com --output=json --output-path=./lh.json`. Scores vary between runs; take the median of several.
- [Lighthouse CI](https://github.com/GoogleChrome/lighthouse-ci) - runs Lighthouse in the pipeline and fails on assertions. `npx @lhci/cli autorun` with a `lighthouserc` file that sets budgets for LCP, CLS, and total blocking time.
- [WebPageTest](https://www.webpagetest.org/) - real devices and networks, filmstrips, and request waterfalls. Use it to find the cause of a slow LCP.
- [PageSpeed Insights](https://pagespeed.web.dev/) and CrUX - field data from real Chrome users, at the 75th percentile, for an origin or a URL with enough traffic.
- [`web-vitals`](https://github.com/GoogleChrome/web-vitals) - a small library that reports LCP, INP, and CLS from your own users. Use the attribution build to learn which element or interaction caused a bad value.
- [`size-limit`](https://github.com/ai/size-limit) or the bundler's analyzer (`rollup-plugin-visualizer`, `@next/bundle-analyzer`) - a bundle budget that fails the pull request.

Lab tools cannot measure INP for real interactions; they report total blocking time as a proxy. Only field data settles a Core Web Vitals question.

## Security

- [MDN HTTP Observatory](https://developer.mozilla.org/en-US/observatory) - grades the response headers of a public host and explains each test.
- [AgentMarkup security scan](https://agentmarkup.dev/security-scan/) - passive scan of a public site: HTTPS and HSTS, CSP, clickjacking and sniffing protections, cookie flags, mixed content, `security.txt`, and SPF, DMARC, and DNSSEC.
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/) - finds bypasses in a Content Security Policy.
- `curl -sI <url>` - the headers that the host really sends.
- The package manager's audit command, plus Dependabot or Renovate, for known-vulnerable dependencies.

These scans are passive and see only public responses. They do not test authentication, authorization, or injection in the application.

## Machine-readable output

- [AgentMarkup](https://agentmarkup.dev/) - build-time generation and validation of `llms.txt`, `llms-full.txt`, JSON-LD, markdown mirrors, AI-crawler `robots.txt` rules, and Content-Signal headers, for Next.js, Vite, Astro, Nuxt, or any static output.
  - `agentmarkup check ./dist` - validates the built files; exit 1 on an error finding.
  - `npx @agentmarkup/audit <url>` - fetches the live URL as each AI crawler and compares with a browser; exit 1 on an error finding.
  - [Website checker](https://agentmarkup.dev/checker/) - hosted version with a 0-100 score from a published formula.
  - Details: [machine-readable.md](machine-readable.md).
- [Rich Results Test](https://search.google.com/test/rich-results) and [Schema Markup Validator](https://validator.schema.org/) - check JSON-LD against Google's rich-result rules and against schema.org.
- [schema-dts](https://github.com/google/schema-dts) - TypeScript types for schema.org, so a wrong property fails the type check.

`curl` and most fetch tools do not run JavaScript, so they cannot see JSON-LD that script injects. That is also what most crawlers see. Use a real browser to inspect the rendered DOM.

## Browser behavior and accessibility

- [Playwright](https://playwright.dev/) - end-to-end tests in Chromium, Firefox, and WebKit. Test the critical paths, including with JavaScript disabled where the site promises that.
- `agent-browser` - drive a real browser from the terminal to inspect the rendered page, take screenshots, and run `agent-browser a11y <url> --json` for axe-core findings.
- axe-core finds only the violations a machine can decide, roughly a third to a half of WCAG issues. Keyboard order, focus management, and the quality of names need a manual pass; see the `better-accessibility` skill.

## Source checks

- A linter and formatter for script and styles: Biome, or ESLint with Prettier, and Stylelint for CSS. Use what the project already has.
- TypeScript in strict mode.
- [Knip](https://knip.dev/) - finds unused files, exports, and dependencies.

## CI shape

| Stage        | Checks                                                                                          |
| ------------ | ----------------------------------------------------------------------------------------------- |
| Pull request | lint, types, unit tests, build, `html-validate`, bundle budget, `agentmarkup check`             |
| Preview URL  | Lighthouse CI assertions, Playwright, axe                                                       |
| After deploy | `@agentmarkup/audit`, `lychee`, header scan, a smoke test of status codes (`200`, `301`, `404`) |
| Continuous   | `web-vitals` field data with an alert on the 75th percentile                                    |

- Fail the job on a regression. A check that only prints a report is not a gate.
- Keep the budgets in the repository, next to the code they limit.
- Test the preview or production build. A development server has different bundles, headers, and caching.
