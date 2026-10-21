---
title: "Documentation Sites"
description: "How I build and publish documentation: Hugo with the Docsy theme as a Hugo module, built and checked by GitHub Actions, and published on GitHub Pages, the same way this site is."
date: 2026-10-21T17:55:00Z
categories: ["Projects"]
tags: ["Infrastructure", "Documentation", "Hugo", "Docsy", "GitHub Pages", "GitHub Actions"]
series: ["Infrastructure"]
seriesOrder: 10
seriesGroup: "Off the server"
---

Every project with users gets a documentation site: what it is, how to install
and use it, and its reference. Heimdall's documentation is one, and so is the
documentation of my .NET libraries. They are all built the same way.

| Concern | Choice |
| --- | --- |
| Generator | Hugo, extended edition |
| Theme | Docsy, as a Hugo module |
| Hosting | GitHub Pages |
| Deploys | GitHub Actions |
| DNS | Cloudflare, optional |

## Why Hugo

Hugo is a single binary that builds thousands of pages in about a second, and
documentation is Markdown in a folder, next to the code it describes, reviewed
in the same pull requests. Docsy is a documentation theme from Google with
navigation, search and versioned sections built in.

Docsy is imported as a **Hugo module** rather than copied into the repository
or added as a Git submodule, so its version is pinned in `go.mod` like any other
dependency:

```toml
# hugo.toml
[module]
  [[module.imports]]
    path = "github.com/google/docsy"
```

Hugo modules are Go modules underneath, so building needs Go, and Docsy's
styles need Node for PostCSS.

## The workflow

The deploy workflow runs on every push to `main`. It sets up Go, Hugo and Node,
builds the site with the base URL GitHub Pages gives it, checks the result, and
publishes:

```yaml
# .github/workflows/deploy.yml, trimmed
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: stable }
      - uses: peaceiris/actions-hugo@v3
        with: { hugo-version: ${{ env.HUGO_VERSION }}, extended: true }
      - uses: actions/setup-node@v4
        with: { node-version: 24 }
      - id: pages
        uses: actions/configure-pages@v5
      - run: hugo --minify --baseURL "${{ steps.pages.outputs.base_url }}/" 2>&1 | tee hugo.log
      - run: python3 scripts/check_site.py --public public --build-log hugo.log
      - uses: actions/upload-pages-artifact@v3
        with: { path: public }
  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: github-pages
    steps:
      - uses: actions/deploy-pages@v4
```

The check step is what makes the site trustworthy. Before anything is
published, a small script reads the generated site and Hugo's build log, and
fails the deploy when:

- a page the site must have was not built;
- an internal link or asset does not resolve, or names an anchor its target
  page does not have;
- Hugo's log holds a warning or an error;
- the content still holds placeholder text, such as `TODO` or lorem ipsum.

A broken link stops the deploy instead of reaching readers.

Hugo's version is pinned in the workflow, never `latest`, so a new Hugo release
cannot change the site without a commit that says so.

## This site

This site, the one you are reading, is built the same way: Hugo, published on
GitHub Pages by GitHub Actions. It differs in one respect, its release flow:
every pull request and every push to `develop` builds the site, so a broken
build is caught early, but only a merge of a `release/x.y.z` branch into `main`
publishes it, and the published commit is tagged `vx.y.z`.

## A custom domain

A documentation site can keep its `github.io` address or move to a domain of
its own. For `docs.example.com`, the repository's Pages settings get the custom
domain, and Cloudflare's DNS a `CNAME` record from `docs` to the owner's
`github.io` host. GitHub issues the certificate itself.
