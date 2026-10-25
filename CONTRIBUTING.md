# Contributing

This repository lives at <https://git.techcraftsmen.net/artur-rios/personal-lab>; the GitHub repository is a
read-only mirror of it. Open pull requests on the git server.

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

Jenkins runs the **branch policy** on every pull request into `develop` or
`main`: into `develop` only from `feature/` or `fix/` branches (or Renovate's)
cut from `develop`, into `main` only from a `release/<major>.<minor>.<patch>`
branch whose every commit is already on `develop` and whose version has no tag
yet. It also runs the `build` check on every pull request
([`yggdrasil.yml`](yggdrasil.yml)): the site's image, which is Hugo building the
whole site, so a broken page or a theme that no longer installs is caught before
it reaches a release.

## Publishing

Merging a `feature/` or `fix/` branch into `develop` publishes nothing: the site
is deployed from `main`. Merging a `release/x.y.z` pull request into `main`
makes Jenkins build the site's image from that commit and deploy it to
<https://lab.artur-rios.tech/>.

## Releasing

The owner tags the releases; nothing tags them automatically. To release:

1. Cut `release/x.y.z` from `develop` and open the pull request into `main`.
2. The owner merges it (merge commit) once the checks pass: on this repository only the owner can merge into `main`.
3. The same day, the owner pushes an annotated `vx.y.z` tag on the merge commit
   on `main`:

   ```sh
   git switch main && git pull
   git tag -a vx.y.z -m "vx.y.z"
   git push origin vx.y.z
   ```

Only the owner can create `v*` tags. The tag is what marks the release: the
branch policy refuses a release branch whose version already has one, so
`x.y.z` is never released twice.

## Running it locally

The theme is not part of the repository: the image fetches it, pinned by
commit (`NUNO_COMMIT` in the [`Dockerfile`](Dockerfile)). To preview with Hugo, put the same commit in
`themes/nuno` (git ignores it):

```sh
git clone https://git.techcraftsmen.net/artur-rios/personal-lab.git
cd personal-lab
git clone https://github.com/artur-rios/hugo-theme-nuno.git themes/nuno
git -C themes/nuno checkout 8d00966c1d46e468281969431a9463c1fff14af9
hugo server
```

To bump the theme, set `NUNO_COMMIT` in the `Dockerfile` and check out the new
commit in `themes/nuno`.

To build what is deployed: `docker build -t personal-lab-site .`
