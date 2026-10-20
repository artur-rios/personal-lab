# Contributing

## Branching model

```txt
feature/<name> ─┐
fix/<name> ─────┴─▶ develop ──▶ release/x.y.z ──▶ main  (published, tag vx.y.z)
```

| Branch | Cut from | Merges into | How |
| --- | --- | --- | --- |
| `feature/<name>`, `fix/<name>` | `develop` | `develop` | Pull request, merge commit or squash. The branch is deleted on merge. |
| `release/x.y.z` | `develop` | `main` | Pull request, merge commit only. |
| `develop`, `main` | — | — | Protected: no direct pushes, no force pushes, no deletion. |

`develop` is where all work lands; `main` holds only what has been published.
Branch names are lowercase: letters, digits, `.`, `_` and `-`. A `release/`
branch is a snapshot of `develop` and carries no commits of its own: a fix for a
release lands on `develop` through a `fix/` branch and a new release branch is
cut.

The **Branch Policy** workflow
([`branch-policy.yml`](.github/workflows/branch-policy.yml)) enforces the model
on every pull request into `develop` or `main`.

## Publishing

The **Deploy** workflow ([`deploy.yml`](.github/workflows/deploy.yml)) builds
the site on every pull request and every push to `develop`, so a broken build is
caught before it reaches a release. Merging a `release/x.y.z` pull request into
`main` publishes the site to GitHub Pages, then tags the published commit
`vx.y.z` and creates a GitHub release of that name.

To preview locally:

```sh
git submodule update --init --recursive
hugo server
```
