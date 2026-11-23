---
title: "Documentation Sites"
description: "How I build and publish documentation: Hugo with the Docsy theme, built in a pinned image that checks every link before it is served, deployed by yggdrasil under one shared host, docs.artur-rios.tech, with each .NET library's coverage report built into its site, the same way this site is."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-documentation-sites/"]
tags: ["Infrastructure", "Documentation", "Hugo", "Docsy", "Docker"]
series: ["Infrastructure"]
seriesOrder: 10
seriesGroup: "What runs on it"
---

Every project with users gets a documentation site: what it is, how to install
and use it, and its reference. Heimdall's documentation is one, and so is the
documentation of each of my .NET libraries. They are all built the same way,
and all live under one host, `docs.artur-rios.tech`.

| Concern | Choice |
| --- | --- |
| Generator | Hugo extended, 0.165 |
| Theme | Docsy |
| Image | Built in a pinned Hugo image, served by static-web-server |
| Hosting | My Application Server, behind Cloudflare |
| Address | `docs.artur-rios.tech/<repository>/` |
| Deploys | Jenkins, on every push to `main` |

Until October 2026 each of these sites was on GitHub Pages, at its own
`github.io` address, published by a workflow in its repository. They moved to
the Application Server with the other sites, and each became an application
of its own in yggdrasil's catalog.

## Why Hugo

Hugo is a single binary that builds thousands of pages in about a second, and
documentation is Markdown in a folder, next to the code it describes, reviewed
in the same pull requests. Docsy is a documentation theme with navigation,
search and versioned sections built in.

How Docsy gets into the build depends on the site:

- **A library's site** installs it as an npm package, `@docsy/theme`, with
  `themesDir = 'node_modules'`. The lock file pins and hashes it, and the build
  image needs no Go.
- **A system's site**, such as Heimdall's, imports it as a Hugo module, pinned
  in `go.mod`, so its build stage copies Go in from a pinned Go image.

Either way, Docsy 0.17 and newer compile their styles with Dart Sass, which
the Hugo image lacks, so every site adds `sass-embedded` to its `package.json`
and puts `node_modules/.bin` on the `PATH`.

## The image checks the site

The documentation of Heimdall, Fortuna and Cerberus has a stage in its
`Dockerfile` that other sites do not: between building the site and serving
it, a small script reads the generated site and Hugo's build log, and fails
the build when:

- a page the site must have was not built;
- an internal link or asset does not resolve, or names an anchor its target
  page does not have;
- Hugo's log holds a warning or an error;
- the content still holds placeholder text, such as `TODO` or lorem ipsum.

```dockerfile
# heimdall-docs' Dockerfile, trimmed
FROM hugomods/hugo:debian-node-lts-0.165.0@sha256:... AS build
# ... npm ci, then hugo --minify --baseURL "$base", logging to /tmp/hugo.log

FROM python:3.14.9-slim-bookworm@sha256:... AS verify
COPY --from=build /out/ public/
RUN python scripts/check_site.py --public public --build-log /tmp/hugo.log

FROM joseluisq/static-web-server:2.44.1@sha256:...
COPY --from=verify /src/public/ /public${PUBLIC_PATH}/
```

The final stage copies the site from the `verify` stage, not from `build`, so
an image that serves the site cannot exist unless the check passed. The site's
`build` check builds that image on every pull request, so a broken link stops
the merge, and the deploy builds it again, so it can never reach readers.

## One host, one path per site

Every site lives under a path of `docs.artur-rios.tech`, named after its
repository: `/heimdall-docs/`, `/dotnet-util/`, `/orpheus/`. The catalog gives
the application a `path`, the deploy passes it as a build argument, and Hugo
builds with `--baseURL https://docs.artur-rios.tech/<path>/`, so `baseURL` in
`hugo.toml` is only what a plain local `hugo` uses. The proxy does not strip
the path: the image puts the files under it.

The index of the .NET libraries, `/dotnet-libraries/`, is the host's front
door: its stack has one more router, which answers `docs.artur-rios.tech/`
with a permanent redirect to it. A site that was retired keeps its links
working: Heimdall API's old documentation, `/heimdall-api`, redirects page by
page to the same content in Heimdall's, through a Traefik file router.

## A library's coverage report

Each .NET library's site serves its test coverage report next to its
documentation, at `/<library>/coverage-report/`. The report is not in the
repository: it is the archive of the library's `coverage` check. The docs
site's `yggdrasil.yml` names it as an input of the deploy:

```yaml
deploy:
  inputs: [coverage]
```

so the pipeline runs that check when it deploys, and copies its archive into
the build context, where Hugo mounts it as static files. A deploy that did
not get the report fails rather than publishing a site without it.

## This site

This site, the one you are reading, is built the same way: Hugo, in the same
pinned image, served by static-web-server at `lab.artur-rios.tech`, a host of
its own. It differs in its release flow: every pull request runs its `build`
check, the site's image, so a broken build is caught early, but only a merge
of a `release/x.y.z` branch into `main` deploys it, and I tag the published
commit `vx.y.z` myself.
