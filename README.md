# Artur Rios Lab

My lab notebook, kept in the open: study notes, brainstorms, how I build
software and how I host it. It is a [Hugo](https://gohugo.io) site published at
**<https://lab.artur-rios.tech/>**.

> **Where this lives:** the repository is at
> <https://git.techcraftsmen.net/artur-rios/personal-lab>. The GitHub
> repository is a read-only mirror of it.

## What lives here

| Kind | What it is |
| --- | --- |
| **Study notes** | What I learn, written up properly, with references. [Fundamentals](content/fundamentals/) covers the core ideas of computing and programming; [Front-end](content/front-end/) covers the frameworks behind web and mobile interfaces; [.NET](content/dotnet/) covers how C# and .NET work, data access, test coverage, the libraries I recommend and how I develop APIs; [Concepts](content/concepts/) covers the design principles and patterns that decide how software is put together; [Security](content/security/) covers how vulnerabilities and weaknesses are named, tracked and prevented; [Git](content/git/) covers my Git setup, everyday commands and features such as submodules and tags. All six sit under one *Study notes* dropdown in the nav. |
| **Brainstorms** | Ideas while they are still rough: questions, sketches and options before anything is decided. They live in [Brainstorms](content/brainstorms/). |
| **Engineering** | How I take software from an idea to a working system: the documents, the backlog and the order things are built and tested in. It lives in [Engineering](content/engineering/). |
| **Infrastructure** | How I host and ship what I build: the self-hosted server, its platform and deploys, and the free hosting for everything static. It lives in [Infrastructure](content/infrastructure/). |

Everything is plain Markdown under [`content/`](content/), one folder per
section.

## Repository layout

```txt
content/          site content, one folder per section
  fundamentals/   study notes on the fundamentals of computing
  front-end/      study notes on front-end frameworks: Angular, React, Flutter
  dotnet/         study notes on .NET and C#: compilation, collections, delegates, data access, coverage, libraries, APIs
  concepts/       study notes on software design concepts: SOLID, inversion of control
  security/       study notes on software security: CVE and CWE
  git/            study notes on Git: config and commands, submodules, tags
  brainstorms/    rough ideas, questions and options before anything is decided
  engineering/    how software goes from an idea to a working system
  infrastructure/ how everything is hosted and shipped
  series/         one page per multi-part series, with its description
data/             site data (the lines the home page masthead cycles through)
layouts/          the diagram shortcode, and overrides of the theme's nav and footer
archetypes/       front matter templates for new pages
themes/nuno/      the nuno theme, fetched by the Dockerfile (git-ignored; see below)
hugo.toml         site configuration
Dockerfile        builds the site and serves it (what is deployed)
ci/               the build check's script
yggdrasil.yml     what Jenkins checks
```

## Running it locally

Requires Hugo **extended** 0.158 or later.

The nuno theme is not a submodule: the image fetches it, pinned by commit and
checksum in the [`Dockerfile`](Dockerfile). To run Hugo on your machine, clone
it into `themes/nuno` at that commit (the folder is git-ignored). Without the
theme Hugo builds an empty site.

```sh
git clone https://git.techcraftsmen.net/artur-rios/personal-lab.git
cd personal-lab
git clone https://github.com/artur-rios/hugo-theme-nuno.git themes/nuno
git -C themes/nuno checkout 8d00966c1d46e468281969431a9463c1fff14af9
hugo server
```

## Writing a new page

```sh
hugo new content fundamentals/my-topic.md
```

New pages start as drafts (`draft = true`). `hugo server -D` shows them
locally; remove the flag when the page is ready to publish. Use the front
matter of
[`what-is-programming.md`](content/fundamentals/what-is-programming.md) as a
model: a `description`, a `categories` entry (shown as the kicker above the
title) and a few `tags`.

Brainstorms, engineering and infrastructure pages have their own archetypes,
so `hugo new content brainstorms/my-idea.md`,
`hugo new content engineering/my-topic.md` and
`hugo new content infrastructure/my-topic.md` start with the right category
already filled in, and a brainstorm with a few section headings too. Pages
that moved keep their old address working through an `aliases` entry in their
front matter.

Articles that belong together form a series: give each part the same
`series` name, a `seriesOrder` number (all parts or none, otherwise they are
ordered by date) and optionally a `seriesGroup` heading, and the theme links
the parts from the aside. A page at `content/series/<name>/_index.md` gives the
series its own description. The SOLID articles under
[Concepts](content/concepts/) are the model.

## Publishing

Work lands on `develop` through `feature/` and `fix/` branches. A
`release/x.y.z` branch cut from `develop` and merged into `main` publishes the
site, and the owner tags the release `vx.y.z` on `main`.
[CONTRIBUTING.md](CONTRIBUTING.md) has the full branching model and what
Jenkins checks.
