# Security

Sources: https://cheatsheetseries.owasp.org/, https://developer.mozilla.org/en-US/docs/Web/Security, https://web.dev/articles/strict-csp

This file covers the browser-facing layer. Authentication, authorization, and server-side input handling belong to the application's own threat model.

## Response headers

| Header                         | Value to start from                                                              |
| ------------------------------ | -------------------------------------------------------------------------------- |
| `Strict-Transport-Security`    | `max-age=63072000; includeSubDomains; preload`                                   |
| `Content-Security-Policy`      | see below                                                                        |
| `X-Content-Type-Options`       | `nosniff`                                                                        |
| `Referrer-Policy`              | `strict-origin-when-cross-origin`                                                |
| `Permissions-Policy`           | deny what the site does not use, e.g. `camera=(), microphone=(), geolocation=()` |
| `Cross-Origin-Opener-Policy`   | `same-origin` (use `same-origin-allow-popups` for OAuth popups)                  |
| `Cross-Origin-Resource-Policy` | `same-origin` or `same-site` on resources that other sites must not embed        |

- Set headers in the host or CDN configuration (`_headers`, `vercel.json`, `netlify.toml`, the reverse proxy, or middleware). A `<meta http-equiv>` CSP cannot set `frame-ancestors` or reporting.
- `includeSubDomains` and `preload` are hard to reverse. Confirm that every subdomain serves HTTPS before you add them, and start with a short `max-age`.
- `X-Frame-Options: DENY` is superseded by `frame-ancestors`; send it only for old browsers.
- Do not send `X-XSS-Protection`. Remove `Server` and `X-Powered-By` version details.
- Verify on the deployed URL (`curl -sI https://example.com`). A header in the config is not a header in the response.

## Content Security Policy

Use a strict policy built on nonces or hashes, not on a host allowlist:

```text
Content-Security-Policy:
  script-src 'nonce-{RANDOM}' 'strict-dynamic';
  object-src 'none';
  base-uri 'none';
  frame-ancestors 'none';
  form-action 'self';
  report-to csp
```

- The nonce is random and new for each response. Static sites that cannot make a nonce use hashes of the inline scripts.
- `'strict-dynamic'` lets a trusted script load its own dependencies, so the host allowlist is not needed.
- Roll out in `Content-Security-Policy-Report-Only`, read the reports, fix the violations, then enforce.
- `'unsafe-inline'` in `script-src` removes most of the protection. Move inline handlers (`onclick=`) into script files.
- Add `require-trusted-types-for 'script'` when the code base can adopt Trusted Types; it stops DOM XSS sinks at the source.
- Set `frame-ancestors` to the origins that may embed the site, or `'none'`.

## Cookies

```text
Set-Cookie: __Host-session=...; Path=/; Secure; HttpOnly; SameSite=Lax
```

- `Secure` and `HttpOnly` on every session cookie. Script must not be able to read it.
- `SameSite=Lax` is the default to keep. Use `Strict` for high-value actions and `None; Secure` only for a real cross-site need.
- The `__Host-` prefix forces `Secure`, `Path=/`, and no `Domain`, so a subdomain cannot overwrite the cookie.
- Do not keep session tokens in `localStorage`; any injected script can read them.

## Cross-site requests

- State-changing requests use `POST`, `PUT`, `PATCH`, or `DELETE`, never `GET`.
- Defend against CSRF with `SameSite` cookies and a second check: a CSRF token, or a server check of `Sec-Fetch-Site` and `Origin`.
- CORS: list the allowed origins exactly. Never reflect the `Origin` header, and never combine `Access-Control-Allow-Origin: *` with credentials. Send `Vary: Origin` when the value depends on the request.

## Injection

- Insert text with `textContent`, and let the framework escape. Treat `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, `dangerouslySetInnerHTML`, and `v-html` as review points.
- When HTML from a user must be rendered, sanitize it with a maintained sanitizer such as DOMPurify. Do not write a sanitizer with regular expressions.
- Validate URL schemes before you put a value into `href` or `src`; reject `javascript:`.
- Serialize JSON into HTML safely. `</script>` and `<!--` inside a JSON string end the script block; escape `<`, `>`, and `&` as Unicode escapes. This applies to JSON-LD and to hydration state.
- Server-side validation is the control. Client-side validation is not.

## Third-party code

- Each third-party script runs with the full rights of the page. Keep a list with an owner for each one.
- Add Subresource Integrity (`integrity` and `crossorigin="anonymous"`) to scripts and styles from a CDN, with a pinned version. Prefer self-hosting.
- Put untrusted embeds in an `<iframe sandbox>` on a different origin.
- Keep dependencies current and audit them in CI (`npm audit`, `pnpm audit`, or the package manager's equivalent). Commit the lockfile. Review install scripts.
- Do not ship secrets to the browser. Every value in the bundle is public, including `NEXT_PUBLIC_*` and `VITE_*` variables. Do not publish source maps that contain private code.

## Disclosure

Publish `/.well-known/security.txt` with a `Contact` and an `Expires` field (RFC 9116).

## Email and DNS

For a domain that sends mail, publish SPF, DKIM, and a DMARC policy; for a domain that sends none, publish `v=spf1 -all` and `p=reject`. Enable DNSSEC where the registrar supports it. The AgentMarkup security scan reports SPF, DMARC, and DNSSEC with the HTTP checks.
