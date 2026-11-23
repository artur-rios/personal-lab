---
title: "Static Sites"
description: "How I build and host sites with no code running on a server, such as a blog, a placeholder page or a small tool: built in a pinned image from one of yggdrasil's templates, for plain files, Vite, a Next.js static export or Hugo, and served by static-web-server in a locked-down container on my Application Server, behind Cloudflare."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-static-sites/"]
tags: ["Infrastructure", "Static Sites", "Vite", "Next.js", "Hugo", "Docker"]
series: ["Infrastructure"]
seriesOrder: 9
seriesGroup: "What runs on it"
---

A static site is rendered to HTML, CSS and JavaScript when it is built, and
served as files from then on: a blog, a placeholder page, a small tool that
runs entirely in the browser. With no code running on a request, the
container that serves it is the cheapest thing the server runs, and the
safest.

| Concern | Choice |
| --- | --- |
| Generator | Whatever suits the site: plain files, Vite, a Next.js static export or Hugo |
| Image | Built in a pinned image, served by static-web-server |
| Hosting | My Application Server, behind Cloudflare |
| Domain | `artur-rios.tech`, one host per site |
| Deploys | Jenkins, on every push to the default branch |

Its neighbours in this series draw the line: a page that needs a server
function is a [landing page]({{< ref "/infrastructure/infrastructure-landing-pages" >}}),
and reference documentation is a
[documentation site]({{< ref "/infrastructure/infrastructure-documentation-sites" >}}),
under one shared host.

## One template per generator

Static sites used to be on GitHub Pages and Vercel, each with its own build
settings in a workflow or a dashboard. Now every site starts from one of
yggdrasil's templates, which gives it a `Dockerfile` and a `yggdrasil.yml`
with its checks:

| Template | Builds with | Used by |
| --- | --- | --- |
| Static | Nothing: the files in `public/` are the site | Plain HTML and CSS repositories |
| Vite | `npm ci && npm run build` in a pinned Node image | The placeholder page, `placeholder.artur-rios.tech` |
| Next.js static export | `next build` with `output: 'export'` | The company page |
| Hugo | Hugo extended in a pinned `hugomods/hugo` image | The blog, `blog.artur-rios.tech`, and this site |

A site that does not fit one, such as the file tree generator, a Create React
App fork, keeps its own two-stage `Dockerfile` that ends the same way.

## The image

Every template ends in the same final stage: **static-web-server**, pinned by
version and digest, and nothing else. The image has no shell, so nothing can
be run inside it, even by someone who gets in:

```dockerfile
# The final stage of every site template, trimmed
FROM joseluisq/static-web-server:2.44.1@sha256:...

COPY --from=build /out/ /public${PUBLIC_PATH}/
COPY <<EOF /public/healthz
ok
EOF

ENV SERVER_PORT=8080 \
    SERVER_ROOT=/public \
    SERVER_ERROR_PAGE_404=/public${PUBLIC_PATH}/404.html

USER 65532:65532
EXPOSE 8080
```

It serves on port 8080 as a numeric non-root user, and answers `/healthz` from
a file of its own, which the status API probes. A missing page is the site's
own `404.html`.

The site's Compose file comes from yggdrasil's template too, and locks the
container down further: a read-only file system with a temporary directory in
memory, every Linux capability dropped, and no privilege escalation.

## The address is a build argument

The deploy hands every site its address, from the catalog's `host`, `domain`
and `path`, as build arguments: `PUBLIC_HOST`, such as `blog.artur-rios.tech`,
and `PUBLIC_PATH`, empty for a site at its host's root. A generator that needs
its base URL, such as Hugo, builds with it, so the address is written in one
place, the catalog, and never in the site's own settings:

```yaml
# catalog.yaml
- id: personal-blog
  kind: web
  health: http://personal-blog:8080/healthz
  domain: artur-rios.tech
  host: blog
  checks: [lint, build]
  environments:
    production: { trigger: branch, branches: main }
```

Build arguments are public: they end up in the image. A secret is the
application's variable in the variables store, read when the container runs.

## Routing

Each site gets one of three Traefik overlays:

- **`site.proxy.yml`**: the site has a host of its own, such as
  `blog.artur-rios.tech`.
- **`site-path.proxy.yml`**: the site lives under a path of a shared host,
  such as `docs.artur-rios.tech/<repository>`. The proxy does not strip the
  path; the image puts the files under it.
- **`site-apex-redirect.proxy.yml`**: the site is on `www.`, and the bare
  domain redirects to it.

The wildcard certificate of `artur-rios.tech` covers every one of them, so a
new site is a catalog entry, two stack files copied from the templates and a
push.

## Checks and deploys

A site's checks build it on every pull request, usually a lint and the
`Dockerfile`'s own build, so a broken page is caught before it merges. Most
sites deploy to production only, on every push to their default branch, and
need no release. A site whose repository has only a default branch gets the
basic branch rules, under which its checks run and report on every pull
request without being required.
