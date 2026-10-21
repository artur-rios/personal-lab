---
title: "The Conventions I Follow"
description: "The small rules I apply to every project so I never have to decide them twice: the technologies I build with, how I name repositories, namespaces and projects, how I order code and name fields in C#, and how I write commit messages with Conventional Commits and the 50/72 rule."
date: 2026-10-21T18:00:00Z
categories: ["Engineering"]
tags: ["Conventions", "Naming", "Code Style", "C#", "Git", "Conventional Commits", "Technology Stack"]
---

A convention is a decision made once. Without them, every new repository,
class and commit reopens the same small questions: what to call it, where to
put it, how to phrase it. None of those questions is hard, but answering them
again every time is slow, and answering them differently every time leaves a
codebase that reads like it was written by several people who never met.

This page collects the conventions I follow in my own projects. Where a style
guide already covers something, I follow it; the
[Google Style Guides](https://google.github.io/styleguide/) are my default
reference for the languages they cover. What is written here is either what
those guides leave open, or a choice I have made on top of them.

## Technology stack

The first convention is which tools to reach for. A short, stable list means
the knowledge from one project carries straight into the next, and a new
project starts from what I already know works.

| Area | Technologies |
| --- | --- |
| Databases | PostgreSQL, SQLite |
| Back-end | .NET, Rust |
| Front-end | React with [shadcn/ui](https://ui.shadcn.com/), Flutter |

PostgreSQL and SQLite are both relational and both speak SQL, so the same
modelling habits apply whether the data lives on a server or in a single file
next to the application. On the back end, .NET is where most of my APIs and
libraries live; [How I Develop APIs]({{< ref "/dotnet/how-i-develop-apis" >}})
describes how one is put together. On the front end, React with shadcn/ui
covers the web, and Flutter covers applications that run from one codebase
on several platforms. The front-end section has an article on how each works:
[React]({{< ref "/front-end/react" >}}) and
[Flutter]({{< ref "/front-end/flutter" >}}).

## Repositories

Repository names are in kebab case: lowercase words joined by hyphens. A name
is built from up to two parts, in this order:

1. **What the repository is about.** A name for the idea behind it, the
   product or the subject, such as `heimdall` or `dotnet`.
2. **How that idea is implemented.** Which part of the project this
   repository covers: an `api`, a `ui`, the `docs`, a library for a single
   concern.

Put together, a project split across repositories reads as a family:

| Repository | Idea | Part |
| --- | --- | --- |
| `heimdall-api` | Heimdall | The web API |
| `heimdall-ui` | Heimdall | The user interface |
| `heimdall-docs` | Heimdall | The documentation site |
| `dotnet-mediator` | .NET | The mediator library |

When one repository holds everything a project has, the second part adds
length and no information, so the name is only the first part:
`personal-lab`, not `personal-lab-site`.

## Namespaces and projects

.NET namespaces and project names follow one pattern:

```txt
<Company>.(<Product>|<Technology>)[.<Feature>][.<Subnamespace>]
```

The company comes first, then either the product or, for a reusable library,
the technology it belongs to. The optional parts narrow it down from there.
Every project in a solution starts with the same prefix, so the name alone
says where a type comes from, and the project name and its root namespace are
always the same string. From Heimdall:

```txt
ArturRios.Heimdall.Command
ArturRios.Heimdall.WebApi
ArturRios.Heimdall.WebApi.Tests
```

A test project takes the name of the project it tests, followed by `.Tests`.

## Code

### Order

When nothing else decides the order of a list, it is alphabetical: `using`
directives, package references, enum members without a meaningful sequence,
entries in a configuration file. Alphabetical order is not the most useful
order, but it is one nobody has to argue about, and it makes a missing or
duplicated entry easy to spot.

Inside a class, members are grouped by kind and visibility, in this order:

1. Public properties and fields
2. Private properties and fields
3. Constructors
4. Public methods
5. Private methods

The public surface comes first because it is what a reader opening the file
usually wants: what the class exposes and how it is created. The private
helpers come last, after the public methods that call them.

### C\#

- **Private fields start with an underscore**, followed by camel case:
  `_protector`, `_permits`. The underscore makes a field stand out from a
  local variable or a parameter at every point it is used, without needing
  `this.`.
- **Fields with the same modifiers are grouped together**, so all the
  `readonly` fields sit side by side, and so do the mutable ones.

```csharp
public sealed class ReportExporter
{
    public string Format { get; }

    private readonly IReportRepository _repository;
    private readonly ILogger<ReportExporter> _logger;

    private int _exportedCount;

    public ReportExporter(IReportRepository repository, ILogger<ReportExporter> logger, string format)
    {
        _repository = repository;
        _logger = logger;
        Format = format;
    }

    public async Task ExportAsync(int reportId) => await WriteAsync(await _repository.GetAsync(reportId));

    private Task WriteAsync(Report report) { /* ... */ }
}
```

## Commits

Commit messages follow
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), and
three formatting rules on top of it:

- **Everything is lowercase**, the type and the summary alike.
- **The 50/72 rule.** The first line is a summary of at most 50 characters
  with no period at the end. The second line is blank. The body, when there
  is one, is wrapped at 72 characters per line.
- **The imperative mood.** A commit says what applying it will do: `fix
  token refresh`, not `fixed token refresh` or `fixes token refresh`.

```txt
feat: add totp enrolment endpoint

Let a signed-in user register an authenticator app. The secret is
encrypted with the data protection api before it is stored, and the
endpoint returns the provisioning uri the app scans as a qr code.
```

The 50-character limit keeps the summary readable in a one-line log and in
the places that truncate it, such as a pull request list. The 72-character
body wraps cleanly in a terminal even after Git indents it for `git log`.

### Types

The type in front of the summary says what kind of change the commit is.
Conventional Commits itself defines only `feat` and `fix`; the others are the
common set that grew out of the Angular project's commit guidelines:

| Type | Used for |
| --- | --- |
| `build` | Changes to the build system or external dependencies, such as a package upgrade or a project file change |
| `chore` | Maintenance that changes no production code and fits no other type |
| `ci` | Changes to continuous integration configuration and scripts |
| `docs` | Documentation only |
| `feat` | A new feature |
| `fix` | A bug fix |
| `perf` | A change that improves performance |
| `refactor` | A change that neither fixes a bug nor adds a feature |
| `style` | Changes that do not affect what the code means: whitespace, formatting, missing semicolons |
| `test` | Adding missing tests or correcting existing ones |

A type is a promise about the commit's content. A `refactor` that changes
behaviour, or a `docs` commit that touches code, breaks it, and makes the
history harder to search. When a change is two kinds of thing at once, it is
usually two commits.
