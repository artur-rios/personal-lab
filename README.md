# Artur Rios Lab

[![Deploy](https://github.com/artur-rios/personal-lab/actions/workflows/deploy.yml/badge.svg?branch=main)](https://github.com/artur-rios/personal-lab/actions/workflows/deploy.yml)

My lab notebook, kept in the open: study notes, brainstorms, and a record of the
projects I am working on. It is a [Hugo](https://gohugo.io) site published to
GitHub Pages at **<https://artur-rios.github.io/personal-lab/>**.

## What lives here

| Kind | What it is |
| --- | --- |
| **Study notes** | What I learn, written up properly, with references. [Fundamentals](content/fundamentals/) covers the core ideas of computing and programming; [Front-end](content/front-end/) covers the frameworks behind web and mobile interfaces; [Concepts](content/concepts/) covers the design principles and patterns that decide how software is put together. |
| **Brainstorms** | Ideas while they are still rough: questions, sketches and options before anything is decided. They live in [Brainstorms](content/brainstorms/). |
| **Projects** | The things I am building: what each one is, where it stands and what comes next. They live in [Projects](content/projects/). |

Everything is plain Markdown under [`content/`](content/), one folder per
section.

## Repository layout

```txt
content/          site content, one folder per section
  fundamentals/   study notes on the fundamentals of computing
  front-end/      study notes on front-end frameworks: Angular, React, Flutter
  concepts/       study notes on software design concepts: SOLID, inversion of control
  brainstorms/    rough ideas, questions and options before anything is decided
  projects/       the things being built: what, status and what comes next
  series/         one page per multi-part series, with its description
data/             site data (the lines the home page masthead cycles through)
archetypes/       front matter templates for new pages
themes/nuno/      the nuno theme, as a git submodule
hugo.toml         site configuration
.github/          the Deploy and Branch Policy workflows
```

## Running it locally

Requires Hugo **extended** 0.158 or later.

```sh
git clone --recurse-submodules https://github.com/artur-rios/personal-lab.git
cd personal-lab
hugo server
```

If you cloned without `--recurse-submodules`, fetch the theme with
`git submodule update --init --recursive`. Without it Hugo builds an empty site.

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

Brainstorms and projects have their own archetypes, so
`hugo new content brainstorms/my-idea.md` and
`hugo new content projects/my-project.md` start with the category and a few
section headings already filled in. A project also gets a `status` (idea,
active, paused or done); the theme does not show it, so say the status in the
text too.

Articles that belong together form a series: give each part the same
`series` name, a `seriesOrder` number (all parts or none, otherwise they are
ordered by date) and optionally a `seriesGroup` heading, and the theme links
the parts from the aside. A page at `content/series/<name>/_index.md` gives the
series its own description. The SOLID articles under
[Concepts](content/concepts/) are the model.

## Publishing

Work lands on `develop` through `feature/` and `fix/` branches. A
`release/x.y.z` branch cut from `develop` and merged into `main` publishes the
site and tags the release `vx.y.z`. [CONTRIBUTING.md](CONTRIBUTING.md) has the
full branching model and what the workflows check.
