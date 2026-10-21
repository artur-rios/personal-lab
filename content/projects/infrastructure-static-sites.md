---
title: "Static Sites"
description: "How I build and host sites with no server at all, such as portfolios and brochure sites: Astro, or Next.js with a static export, published on Cloudflare Pages, or on GitHub Pages through GitHub Actions."
date: 2026-10-21T17:55:00Z
categories: ["Projects"]
tags: ["Infrastructure", "Static Sites", "Astro", "Next.js", "Cloudflare Pages", "GitHub Pages"]
series: ["Infrastructure"]
seriesOrder: 9
seriesGroup: "Off the server"
---

A static site is rendered to HTML, CSS and JavaScript when it is built, and
served as files from then on: portfolios, brochure sites, event pages and small
blogs. With no code running on a server, it can be hosted for free on a CDN and
will never go down for want of a patch.

| Concern | Choice |
| --- | --- |
| Generator | Astro for content-first sites, or Next.js with a static export |
| Styling | Tailwind CSS |
| Hosting | Cloudflare Pages, or GitHub Pages |
| Deploys | The host's Git integration, or GitHub Actions |

Its neighbours in this series draw the line: a page that needs a form or a
server function is a [landing page]({{< ref "/projects/infrastructure-landing-pages" >}}),
on Vercel, and reference documentation is a
[documentation site]({{< ref "/projects/infrastructure-documentation-sites" >}}),
in Hugo.

## Building one

Astro sends no JavaScript to the browser unless a component asks for it,
which suits sites that are mostly content:

```bash
npm create astro@latest my-site
cd my-site
npx astro add tailwind
npm run build        # static files in ./dist
```

When a site starts from Next.js, for its components or because it may grow
into a landing page later, a static export gives the same kind of output:

```ts
// next.config.ts
const nextConfig = { output: "export" };
export default nextConfig;
```

`next build` then writes plain HTML to `out/`, at the cost of the features that
need a server, such as route handlers and image optimisation at request time.

## Cloudflare Pages

Cloudflare Pages is the default host, because my domains' DNS is already on
Cloudflare: the CDN, the certificate and the DNS record come wired together,
and the free tier has no bandwidth limit.

1. In Cloudflare's dashboard, create a Pages project connected to the GitHub
   repository.
2. Set the build command, `npm run build`, and the output directory, `dist`
   for Astro or `out` for Next.js.
3. Add the custom domain. Every push to `main` deploys, and every pull request
   gets a preview URL.

## GitHub Pages

For a site that belongs with its repository, GitHub Pages works as well, with
a workflow that builds the site and hands it to Pages:

```yaml
# .github/workflows/pages.yml
name: Deploy static site
on: { push: { branches: [main] } }
permissions: { pages: write, id-token: write, contents: read }
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 24 }
      - run: npm ci && npm run build
      - uses: actions/upload-pages-artifact@v3
        with: { path: dist }
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: github-pages
    steps:
      - uses: actions/deploy-pages@v4
```

In the repository's settings, Pages' source must be set to **GitHub Actions**
for the deploy job to publish.
