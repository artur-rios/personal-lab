---
title: "How I Host My Projects"
description: "Every kind of project I build runs on my own infrastructure: two self-hosted servers run by yggdrasil, one for the code and the pipeline and one for every API, web app and site, with only the packages published elsewhere. Here is the decision table, the rule behind it and a map of the series."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-overview/"]
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

| I'm building | Stack | Where it runs |
| --- | --- | --- |
| A marketing or product page | Next.js with shadcn/ui and Tailwind CSS | My Application Server, behind Cloudflare |
| A static site | A Next.js static export, Vite, Hugo or plain files, on static-web-server | My Application Server, behind Cloudflare |
| Technical documentation | Hugo with the Docsy theme | My Application Server, under `docs.artur-rios.tech` |
| An interactive web app | Flutter, built for the web, on nginx | My Application Server, in three environments |
| A backend API | ASP.NET Core, with PostgreSQL in its own container | My Application Server, in three environments |
| A desktop or mobile app | Flutter | Releases on my Forgejo, copied to GitHub |
| A reusable package | NuGet | nuget.org, pushed by my Jenkins |

## The rule behind it

**Everything I build runs on infrastructure I control; only the packages are
published elsewhere.**

It was not always so. Until the end of October 2026, anything static, such as
landing pages, documentation and this site, was on Vercel and GitHub Pages,
and only the APIs and web apps ran on my own server. The split was cheap, but
it meant three hosts, three ways of deploying, and settings scattered across
dashboards. Once the platform could deploy a container from a catalog entry,
a static site became the cheapest thing it runs: a web server of a few
megabytes, built and deployed by the same pipeline as everything else. And
with Cloudflare's proxy in front of the server, those sites keep a global
cache without a second host.

Packages are the exception because their registry is the point: a library on
nuget.org is one `dotnet add package` away for anyone. GitHub keeps a role
too, as a read-only mirror of every repository and the place where the few
Windows and macOS jobs run.

## The self-hosted platform

That platform is **yggdrasil**, a deploy manager I built for this. An
application is added to it by describing it in one file, its catalog, not by
setting up anything new on a server. It runs on two machines:

- the **DevOps Server** keeps the code and runs the pipeline: Forgejo, the
  Jenkins controller, the build agents and Renovate;
- the **Application Server** runs every environment of every application and
  site, behind Traefik, with its own monitoring and a status console.

| Concern | Tool |
| --- | --- |
| Servers | Two Ubuntu 26.04 VPS, a DevOps Server and an Application Server |
| Git | Forgejo, with a read-only mirror of every repository on GitHub |
| Containers | Rootless Docker and Docker Compose, one engine per service user |
| Reverse proxy and certificates | Traefik, with Let's Encrypt wildcard certificates over DNS-01 |
| DNS, CDN and origin protection | Cloudflare |
| Databases | PostgreSQL, one container per application and environment |
| Checks, releases and deploys | Jenkins, driven by yggdrasil's catalog |
| Windows and macOS jobs | GitHub Actions, on the mirror |
| Dependency updates | Renovate, once a day |
| Metrics, logs and dashboards | Prometheus, Loki, Alloy and Grafana |
| Backups | Every night, each server to the other |

Three domains share the Application Server: `techcraftsmen.net` for the
applications, the APIs and the platform's own pages, `artur-rios.tech` for the
static and documentation sites, and `artur-rios.com`, which only redirects to
my personal page.

What runs on it today:

| System | What it is | Runs |
| --- | --- | --- |
| Heimdall | Identity and access management | An API, a web app and its docs |
| Hermes | Email delivery for internal services | An API with no public route |
| Fortuna | Personal finance | An API, a web app and its docs |
| Chimera | A local-first developer toolbox | A web app |
| Alexandria, Cerberus, Orpheus | A personal library, an encrypted vault, a music player | Their documentation sites |
| .NET libraries | Twelve NuGet libraries | One documentation site each, and an index |
| Personal sites | My page, blog, this lab, a placeholder page and a file tree generator | Static and Next.js sites |
| Tech Craftsmen | My company's page and public services | A static site and a small API |

## The series

The platform, from the bottom up:

1. [The Servers]({{< ref "/infrastructure/infrastructure-server" >}}): the two
   machines, their users, rootless Docker, the installer and the backups.
2. [The Platform]({{< ref "/infrastructure/infrastructure-platform" >}}):
   Traefik, certificates, Cloudflare, monitoring and the console.
3. [Deploying With Yggdrasil]({{< ref "/infrastructure/infrastructure-deploys" >}}):
   from a push on Forgejo to a container running, and rolling back when it
   does not start.
4. [Sizing the Servers]({{< ref "/infrastructure/infrastructure-sizing" >}}):
   how much of each server every piece takes, and when to grow.

What runs on it, by kind of project:

5. [Web APIs]({{< ref "/infrastructure/infrastructure-web-apis" >}}) and
   [Web Apps]({{< ref "/infrastructure/infrastructure-web-apps" >}}): the
   systems with a backend, in three environments.
6. [Landing Pages]({{< ref "/infrastructure/infrastructure-landing-pages" >}}),
   [Static Sites]({{< ref "/infrastructure/infrastructure-static-sites" >}}) and
   [Documentation Sites]({{< ref "/infrastructure/infrastructure-documentation-sites" >}}):
   the sites, each a small container of its own.
7. [Libraries]({{< ref "/infrastructure/infrastructure-libraries" >}}):
   publishing packages to nuget.org on a version tag.

The way each project starts, before any of this, is in
[How I Start a Project From Scratch]({{< ref "/engineering/starting-a-project-from-scratch" >}}).
