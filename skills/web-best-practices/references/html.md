# HTML and semantics

Sources: https://html.spec.whatwg.org/, https://developer.mozilla.org/en-US/docs/Web/HTML, https://web.dev/learn/html

## Document head

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Page name - Site name</title>
    <meta name="description" content="One sentence that says what this page is for." />
    <link rel="canonical" href="https://example.com/page" />
    <meta name="color-scheme" content="light dark" />
    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
  </head>
</html>
```

- `<meta charset>` goes in the first 1024 bytes. Put it first.
- Do not set `user-scalable=no` or `maximum-scale=1`. They block zoom.
- `lang` is the language of the content. Set it per element when a passage is in a different language.
- The title and description are unique per page. The canonical URL is absolute.
- Add Open Graph tags (`og:title`, `og:description`, `og:image`, `og:url`) on pages that people share.
- Order the head for loading: charset, viewport, title, preconnects, critical styles, then scripts with `defer` or `type="module"`.

## Structure

- One `<h1>` per page. Do not skip heading levels to get a font size; use CSS.
- Use `<main>` once. Use `<nav>` for navigation blocks, and label each one (`aria-label`) when there is more than one.
- Use `<article>` for content that stands alone and `<section>` for a part of the page that has a heading.
- Use lists for lists and `<table>` for tabular data, with `<th scope>` and a `<caption>`.
- Use `<time datetime>` for dates and `<address>` for contact data.

## Interactive elements

| Need                       | Element                                         |
| -------------------------- | ----------------------------------------------- |
| Go to a URL                | `<a href>`                                      |
| Do an action               | `<button type="button">`                        |
| Submit a form              | `<button type="submit">` in a `<form>`          |
| Modal                      | `<dialog>` with `showModal()`                   |
| Disclosure                 | `<details>` and `<summary>`                     |
| Menu, tooltip, toast layer | the `popover` attribute with `popovertarget`    |
| Choice from a list         | `<select>`, or `<input list>` with `<datalist>` |

A link without `href` is not focusable. A button in a form without `type` submits the form. Add ARIA only when no native element has the behavior, and then supply the keyboard handling that the role promises.

## Forms

- Every control has a `<label for>` or sits in a `<label>`. A placeholder is not a label.
- Set `type` (`email`, `tel`, `url`, `number`, `date`), `inputmode`, and `autocomplete` (`name`, `email`, `current-password`, `new-password`, `one-time-code`, `street-address`). They select the keyboard and enable autofill and password managers.
- Group related controls in `<fieldset>` with `<legend>`.
- Use the native constraints (`required`, `pattern`, `min`, `max`, `minlength`) and validate again on the server. Client validation is a convenience.
- Connect an error message to its control with `aria-describedby`, and set `aria-invalid="true"`.
- A form works with a plain submit before script enhances it. Use `method="post"` and a real `action`.
- Do not disable paste on any field.

## Images and media

- `alt` is always present. Describe the content for an informative image; use `alt=""` for decoration.
- Always set `width` and `height`. The browser derives the aspect ratio and reserves the space.
- Serve responsive sources with `srcset` and `sizes`, and modern formats with `<picture>`:

```html
<picture>
  <source type="image/avif" srcset="hero-800.avif 800w, hero-1600.avif 1600w" sizes="100vw" />
  <source type="image/webp" srcset="hero-800.webp 800w, hero-1600.webp 1600w" sizes="100vw" />
  <img src="hero-1600.jpg" alt="..." width="1600" height="900" fetchpriority="high" />
</picture>
```

- Below-the-fold images get `loading="lazy"` and `decoding="async"`. The LCP image gets neither `loading="lazy"` nor a script-set `src`.
- Video has `poster`, captions (`<track kind="captions">`), and `preload="metadata"`. Do not autoplay with sound.
- Give an `<iframe>` a `title`, `loading="lazy"`, and a `sandbox` when the content is not trusted.

## URLs and status codes

- URLs are lowercase, stable, and readable. Choose one trailing-slash form and redirect the other.
- A moved page returns `301` or `308`. A temporary move returns `302` or `307`. Do not chain redirects.
- A missing page returns `404`, a removed page `410`, and a server fault `5xx`. An error page with a `200` status is a soft 404; it stays in indexes and misleads agents.
- A client-rendered app still needs the server to return the correct status for each route.
- Serve `robots.txt` and `sitemap.xml` at the root, and name the sitemap in `robots.txt`.

## Progressive enhancement

- Content and primary navigation are in the HTML response. Script adds behavior on top.
- Check each template with JavaScript disabled, or with `curl`, and confirm that the main content is present. That response is what crawlers and most AI agents receive.
- Use CSS for what CSS can do: `:has()`, container queries, `scroll-snap`, `position: sticky`, and view transitions replace script.
- Respect user preferences: `prefers-reduced-motion`, `prefers-color-scheme`, and `prefers-contrast`.
- Detect features (`@supports`, `if ("x" in y)`), never user agents.
