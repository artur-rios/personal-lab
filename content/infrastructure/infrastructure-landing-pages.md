---
title: "Landing Pages"
description: "How I build and host marketing and product pages: Next.js with shadcn/ui and Tailwind CSS, deployed by Vercel on every push with a preview for every pull request, behind Cloudflare, and kept off my own server on purpose."
date: 2026-10-21T17:55:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-landing-pages/"]
tags: ["Infrastructure", "Next.js", "Vercel", "Cloudflare", "Landing Pages"]
series: ["Infrastructure"]
seriesOrder: 8
seriesGroup: "Off the server"
---

A landing page sells something: a hero section, a grid of features, pricing,
a contact or waiting-list form. It has to look polished, load fast everywhere,
and occasionally do something dynamic, such as accept a form. That last part is
why landing pages are not plain [static sites]({{< ref "/infrastructure/infrastructure-static-sites" >}}).

| Concern | Choice |
| --- | --- |
| Framework | Next.js, with the App Router |
| UI | shadcn/ui and Tailwind CSS |
| Hosting | Vercel, on the free tier |
| DNS | Cloudflare |
| Deploys | Vercel's Git integration |

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
components. A form posts to a route handler or a server action in the same
project, so it needs no separate backend, and sends the lead on by email or
webhook. Personal data never goes into the repository or into a URL.

## Hosting on Vercel

Connecting the GitHub repository in Vercel's dashboard is the whole deployment
setup: every push to `main` goes to production, and every pull request gets a
preview URL of its own, which makes reviewing a design change a matter of
opening a link.

The custom domain stays on Cloudflare's DNS, with a `CNAME` record pointing at
the target Vercel gives. It is set to **DNS only**, not proxied: Vercel runs its
own CDN and issues its own certificate, and proxying through Cloudflare as well
would put two CDNs in a row and get in the way of that certificate.

## Why not my server?

Landing pages get traffic in spikes, from a launch or a link that spreads, and
they are judged on how fast they load from anywhere in the world. A global CDN
with no server to maintain does that better than one VPS, at no cost. Keeping
them off [the server]({{< ref "/infrastructure/infrastructure-server" >}}) also keeps
its capacity for the applications that need it.
