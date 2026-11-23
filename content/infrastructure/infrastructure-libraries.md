---
title: "Libraries"
description: "How I publish reusable .NET packages: package metadata in the project file, a release flow that ends in an annotated version tag on main, and a Jenkins release agent that packs the library with no credential and pushes it to nuget.org in a step where none of its code runs, for one package per repository or several, with a documentation site and coverage report for each."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-libraries/"]
tags: ["Infrastructure", ".NET", "NuGet", "Jenkins", "Versioning"]
series: ["Infrastructure"]
seriesOrder: 11
seriesGroup: "What runs on it"
---

Code that more than one project needs becomes a package. Mine are twelve .NET
libraries, published as NuGet packages to **nuget.org**, where anyone finds
them. They are the one thing I build that is not served from my own servers:
a package's registry is the point of it.

| Concern | Choice |
| --- | --- |
| Package format | NuGet, or the language's own format elsewhere |
| Feed | nuget.org |
| Publishing | Jenkins' release agent, on my version tag |
| Versioning | Semantic versioning |
| Documentation | A site per library, with its coverage report |

Until October 2026 each library had a GitHub Actions workflow that pushed to
nuget.org and to GitHub Packages. The libraries moved to Forgejo and Jenkins
with everything else, and GitHub Packages was dropped, so nuget.org is now the
only feed.

## Package metadata

The project file describes the package, so `dotnet pack` produces a complete
`.nupkg`, and its project URL points at the library's documentation:

```xml
<PropertyGroup>
  <PackageId>ArturRios.Util</PackageId>
  <Version>2.2.1</Version>
  <Authors>Artur Rios</Authors>
  <Description>What the library does.</Description>
  <PackageProjectUrl>https://docs.artur-rios.tech/dotnet-util</PackageProjectUrl>
  <RepositoryUrl>https://github.com/artur-rios/dotnet-util</RepositoryUrl>
</PropertyGroup>
```

## The checks

A library is a `repositories` entry in yggdrasil's catalog: it gets a Jenkins
job and the branch rules, and nothing is deployed from it. Its
`yggdrasil.yml` declares two checks, each run in a pinned .NET SDK image on
every pull request:

- **`test`**: restore, `dotnet format --verify-no-changes`, build, a check
  that every test has a `Unit` or `Functional` category, then the tests of
  each category.
- **`coverage`**: the tests with coverage collected, and ReportGenerator's HTML
  report, its pro edition with a licence only this check may bind.

## A release is a tag

Libraries follow the same branches as everything else: work lands on
`develop`, a `release/x.y.z` branch is cut, and its pull request is merged into
`main`. Publishing is then one deliberate act, an **annotated** tag on that
merge commit:

```bash
git switch main && git pull
git tag -a 1.2.3 -m 1.2.3
git push origin 1.2.3
```

Annotated, because Jenkins builds only tags at most a day old, so that a new
job's first scan does not release every old tag again, and it dates a
lightweight tag by its commit rather than by when it was pushed. On a library,
only I can create version tags.

The tag build runs on the release agent. It checks that the tag's commit is on
`main`, then packs, and refuses a package whose version is not the tag's: a
package can never be published from an unreviewed branch, or under a version
that disagrees with its own code.

## One package or several

How the tag names the package depends on how many packages the repository
ships:

- **One package**: the tag is the bare version, `1.2.3`, and publishes the only
  package there is.
- **Several packages**: the tag names the package as well,
  `ArturRios.Data.Sqlite@3.1.0`, and publishes only that one, so packages in
  the same repository keep release cycles of their own. The catalog says
  which pattern a repository's tags follow.

## Packing and pushing, apart

The publish section of the library's `yggdrasil.yml` names the image and the
script that packs:

```yaml
publish:
  nuget:
    image: mcr.microsoft.com/dotnet/sdk:10.0.402@sha256:...
    run: ci/pack.sh
    packages: "artifacts/*.nupkg"
```

Jenkins runs it in two steps on the release agent:

1. **The packing**: `ci/pack.sh` in that image, with **no credential at all**,
   and the packages put aside.
2. **The push**: in a fresh workspace that holds only yggdrasil's scripts and
   the packages, `dotnet nuget push --skip-duplicate` in a pinned SDK image,
   with the nuget.org key bound for this step alone.

The library's own code, its build scripts and its tests never run where the
key is. And `--skip-duplicate` makes a rerun safe: a version the feed already
has is skipped instead of failing the job.

## Its documentation site

Each library also has a documentation site, `docs.artur-rios.tech/<library>/`,
deployed from the same repository on every push to `main`: one repository,
two catalog entries, the library and its site. The site serves the library's
coverage report next to its documentation, built from the archive of the
`coverage` check, as described in
[Documentation Sites]({{< ref "/infrastructure/infrastructure-documentation-sites" >}}).
An index of all twelve, `docs.artur-rios.tech/dotnet-libraries/`, is the
host's front page.

## Consuming a package

From nuget.org, a package is one command away:

```bash
dotnet add package ArturRios.Util
```

## Beyond .NET

The pattern carries over to any language: package metadata in the project, a
release that ends in a tag, packing with no secret, and a push step that holds
the registry's key and nothing else, whether to npm, PyPI or crates.io. Only
the pack and push commands change.
