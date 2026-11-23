---
title: "Landing Pages"
description: "How I build and host marketing and product pages: Next.js with shadcn/ui and Tailwind CSS, as a Node server when the page needs one and a static export when it does not, deployed by yggdrasil on my Application Server behind Cloudflare, with a contact form that mails through my own Hermes and the bare domain redirecting to www."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-landing-pages/"]
tags: ["Infrastructure", "Next.js", "Docker", "Cloudflare", "Landing Pages"]
series: ["Infrastructure"]
seriesOrder: 8
seriesGroup: "What runs on it"
---

A landing page sells something: a hero section, a grid of features, pricing,
a contact form. It has to look polished, load fast everywhere, and
occasionally do something dynamic, such as accept a form. My two are my
personal page, `www.artur-rios.tech`, and my company's, `www.techcraftsmen.net`.

| Concern | Choice |
| --- | --- |
| Framework | Next.js, with the App Router |
| UI | shadcn/ui and Tailwind CSS |
| Output | A standalone Node server when the page needs one, a static export when it does not |
| Hosting | My Application Server, behind Cloudflare |
| Deploys | Jenkins, released like an application |

Until October 2026 both were on Vercel. They moved to the Application Server
with everything else that was hosted elsewhere, and Vercel's preview URLs were
replaced by the environments the platform already had: a release branch
deploys to homologation, at `www-hml`, before the release pull request
deploys production.

## Building one

```bash
npx create-next-app@latest my-landing --ts --tailwind --app --eslint
cd my-landing
npx shadcn@latest init
npx shadcn@latest add button card input navigation-menu
```

shadcn/ui is not a component library installed as a dependency: it copies each
component's source into the project, built on Radix and Tailwind, so every
component can be changed like my own code.

The page is a set of sections rendered as server components, with
interactivity, such as a menu toggle or a form's state, kept in small client
components. Personal data never goes into the repository or into a URL.

## A server, or a static export

Whether the page needs a server decides which of yggdrasil's two Next.js
templates it starts from:

| Template | Output | Runs | Used by |
| --- | --- | --- | --- |
| Next.js server | `output: 'standalone'` | `node server.js`, as the image's non-root `node` user | My personal page, for its contact form |
| Next.js static export | `output: 'export'` | static-web-server, no shell in the image | The company page |

A server is worth its memory only when something must run on a request. On my
personal page that is the contact form: it posts to a route handler in the
same project, which validates the message and hands it to **Hermes**, my own
email delivery service, over the Docker network. The page needs no separate
backend, and the secrets it uses, Hermes' key among them, are the
application's variables in the variables store, handed to the container when
it runs, never build arguments.

Both templates serve on port 8080 and answer `/healthz`, which the status API
probes. In the server template it is a route the app copies in, static on
purpose: it says the process serves requests, not that its dependencies are
up, so a slow dependency never makes Docker restart the container.

## Build arguments, not Vercel's variables

A site gets two build arguments from the deploy, which replace what Vercel
used to set:

| Argument | Replaces |
| --- | --- |
| `GIT_COMMIT`, the whole SHA being deployed | `VERCEL_GIT_COMMIT_SHA` |
| `YGG_ENVIRONMENT`, such as `production` or `homologation` | `VERCEL_ENV` |

Server code reads them from `process.env`, and browser code from
`NEXT_PUBLIC_GIT_COMMIT` and `NEXT_PUBLIC_YGG_ENVIRONMENT`, inlined at build
time.

## The bare domain

Both pages live on `www.` and answer on the bare domain too. That is one line
in the catalog, `apex: true`, and an overlay of its own,
`site-apex-redirect.proxy.yml`: next to the site's own router, a second one
answers on the bare domain and redirects every request to the same path on
`www.` with a permanent redirect. In development and homologation the bare
name is `apex-dev` or `apex-hml`, so every environment tests the same
redirect without two of them claiming the one bare domain.

My third domain, `artur-rios.com`, serves nothing of its own: a Traefik file
router redirects it and its `www.` to `www.artur-rios.tech`, keeping the path,
so my page keeps one address.

## Releasing one

A landing page is released like an application, not deployed on every push:
the pull request runs its lint and build checks, `release/x.y.z` deploys to
homologation, and the release pull request deploys production after I click
**Deploy**, then Jenkins merges and tags it. Cloudflare's proxy in front gives
it the global cache and the protection against traffic spikes that a CDN
host gave it before, while the page itself costs the server a Node process of
100 to 200 MB, or a static web server of a few megabytes.
