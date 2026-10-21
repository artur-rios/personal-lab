---
title: "How I Host My Projects"
description: "Each kind of project I build has one place it lives: anything with a backend runs in containers on a self-hosted server deployed by yggdrasil, and everything static is published on free hosting. Here is the decision table, the rule behind it and a map of the series."
date: 2026-10-21T17:55:00Z
categories: ["Projects"]
tags: ["Infrastructure", "Hosting", "Self-Hosting", "Docker", "Deployment"]
series: ["Infrastructure"]
seriesOrder: 1
seriesGroup: "The big picture"
---

Every project eventually has to run somewhere, and deciding where for each one
separately is how a hobby turns into a pile of accounts, bills and half-
remembered setups. So I decided once, by kind of project, and every new project
inherits the answer. This series describes that setup, as it runs today.

## The decision table

| I'm building | Stack | Hosting |
| --- | --- | --- |
| A marketing or product page | Next.js with shadcn/ui | Vercel, behind Cloudflare |
| A static portfolio or brochure site | Astro, or a Next.js static export | Cloudflare Pages or GitHub Pages |
| Technical documentation | Hugo with the Docsy theme | GitHub Pages |
| An interactive web app | Flutter, built for the web | My server: Docker, Traefik, yggdrasil |
| A backend API | ASP.NET Core | My server: Docker, Traefik, yggdrasil |
| A reusable package | NuGet, or the language's own format | nuget.org and GitHub Packages |

## The rule behind it

**Anything with a running backend is self-hosted; everything else is not.**

Static pages, documentation and packages are files. Free content delivery
networks serve files better than any single server I could rent: closer to the
reader, with no machine to patch, and at no cost. Putting them on my own server
would only spend its capacity on work others do for free.

APIs and the web apps that call them are different. They need a process that
keeps running, a database, secrets, logs and a way to roll back a bad release.
Free tiers for that come with sleeping containers, cold starts and limits that
change. One server I control, sized for the whole stack, is cheaper than a
managed platform after the first two or three applications, and teaches far
more.

## The self-hosted half

The server runs a small platform that every application shares, and an
application is added to it by describing it in one file, not by setting up
anything new on the server. That platform is **yggdrasil**, a deploy manager I
built for this: a self-hosted Jenkins that deploys from GitHub, Traefik in front
with wildcard certificates, Prometheus and Loki for monitoring, and a console to
see it all.

| Concern | Tool |
| --- | --- |
| Server | One Ubuntu VPS |
| Containers | Docker and Docker Compose |
| Reverse proxy and certificates | Traefik, with Let's Encrypt wildcard certificates |
| Database | PostgreSQL, installed on the host |
| Build and test | GitHub Actions |
| Deploy | Jenkins, driven by yggdrasil's catalog |
| Metrics, logs and dashboards | Prometheus, Loki, Alloy and Grafana |
| DNS, and optionally a CDN in front | Cloudflare |

Two systems run on it today, each an API and its web front end:
**Heimdall**, for identity and access management, and **Fortuna**, for personal
finance.

## The series

The self-hosted platform, from the bottom up:

1. [The Server]({{< ref "/projects/infrastructure-server" >}}): the VPS, how it
   is prepared, and PostgreSQL.
2. [The Platform]({{< ref "/projects/infrastructure-platform" >}}): Traefik,
   certificates, DNS, monitoring and the console.
3. [Deploying With Yggdrasil]({{< ref "/projects/infrastructure-deploys" >}}):
   from a push on GitHub to a container running, and rolling back when it does
   not start.
4. [Sizing the Server]({{< ref "/projects/infrastructure-sizing" >}}): how much
   of the server each piece takes, and when to grow.
5. [Web APIs]({{< ref "/projects/infrastructure-web-apis" >}}) and
   [Web Apps]({{< ref "/projects/infrastructure-web-apps" >}}): what an
   application looks like to the platform.

The projects that need no server:

6. [Landing Pages]({{< ref "/projects/infrastructure-landing-pages" >}}),
   [Static Sites]({{< ref "/projects/infrastructure-static-sites" >}}) and
   [Documentation Sites]({{< ref "/projects/infrastructure-documentation-sites" >}}).
7. [Libraries]({{< ref "/projects/infrastructure-libraries" >}}): publishing
   packages on a version tag.

The way each project starts, before any of this, is in
[How I Start a Project From Scratch]({{< ref "/projects/starting-a-project-from-scratch" >}}).
