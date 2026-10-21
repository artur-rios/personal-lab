---
title: "Libraries"
description: "How I publish reusable .NET packages: package metadata in the project file, a release flow that ends in a version tag on main, and a workflow that packs the library and pushes it to nuget.org and GitHub Packages, for one package per repository or several."
date: 2026-10-21T17:55:00Z
categories: ["Projects"]
tags: ["Infrastructure", ".NET", "NuGet", "GitHub Packages", "GitHub Actions", "Versioning"]
series: ["Infrastructure"]
seriesOrder: 11
seriesGroup: "Off the server"
---

Code that more than one project needs becomes a package. Mine are .NET
libraries, published as NuGet packages to two places: **nuget.org**, where
anyone finds them, and **GitHub Packages**, next to their source.

| Concern | Choice |
| --- | --- |
| Package format | NuGet, or the language's own format elsewhere |
| Primary feed | nuget.org |
| Secondary feed | GitHub Packages |
| Publishing | GitHub Actions, on a version tag |
| Versioning | Semantic versioning |

## Package metadata

The project file describes the package, so `dotnet pack` produces a complete
`.nupkg` with its symbols alongside:

```xml
<PropertyGroup>
  <PackageId>ArturRios.Example</PackageId>
  <Version>1.2.3</Version>
  <Authors>Artur Rios</Authors>
  <Description>What the library does.</Description>
  <RepositoryUrl>https://github.com/artur-rios/dotnet-example</RepositoryUrl>
  <PublishRepositoryUrl>true</PublishRepositoryUrl>
  <IncludeSymbols>true</IncludeSymbols>
  <SymbolPackageFormat>snupkg</SymbolPackageFormat>
</PropertyGroup>
```

## A release is a tag

Libraries follow the same branches as everything else: work lands on
`develop`, a `release/x.y.z` branch is cut, and its pull request is merged into
`main`. Publishing is then one deliberate act, a tag on that merge commit:

```bash
git tag 1.2.3
git push origin 1.2.3
```

The publish workflow refuses a tag that does not match the project's
`<Version>`, or that is not on `main`, so a package can never be published from
an unreviewed branch or under a version that disagrees with its own code.

## One package or several

How the tag names the package depends on how many packages the repository
ships:

- **One package**: the tag is the bare version, `1.2.3`, and publishes the only
  package there is.
- **Several packages**: the tag names the package as well,
  `ArturRios.Example@1.2.3`, and publishes only that one, so packages in the
  same repository keep release cycles of their own. A small script bumps the
  version, tags and pushes in one step, so the tag and the project file cannot
  drift apart.

## The workflow

The workflow packs the library and pushes the same package to both feeds:

```yaml
# .github/workflows/publish-package.yml, trimmed
on:
  push:
    tags: ["*"]
permissions:
  contents: read
  packages: write
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
      # ... check that the tag matches <Version> and is on main
      - run: dotnet pack --configuration Release --output packages
      - run: >
          dotnet nuget push packages/*.nupkg
          --api-key ${{ secrets.NUGET_API_KEY }}
          --source https://api.nuget.org/v3/index.json
          --skip-duplicate
      - run: >
          dotnet nuget push packages/*.nupkg
          --api-key ${{ secrets.GITHUB_TOKEN }}
          --source "https://nuget.pkg.github.com/${{ github.repository_owner }}/index.json"
          --skip-duplicate
```

`--skip-duplicate` makes a rerun safe: if one feed already has the version, the
push skips it instead of failing the job.

## Consuming a package

From nuget.org, a package is one command away:

```bash
dotnet add package ArturRios.Example
```

From GitHub Packages, a `nuget.config` adds the owner's feed as a source, with a
personal access token that has the `read:packages` scope, since GitHub's NuGet
feed requires authentication even for public packages.

## Beyond .NET

The pattern carries over to any language: package metadata in the project, a
release that ends in a tag, and a workflow that packs and pushes to the
language's registry, whether npm, PyPI or crates.io. Only the pack and push
commands change.
