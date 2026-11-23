---
title: "Deploying With Yggdrasil"
description: "How a push on my Forgejo becomes a running container: one catalog file describing systems, applications, repositories and environments, a release flow enforced by Forgejo's branch rules, a self-hosted Jenkins that runs every check in a container and deploys on the Application Server, automatic rollback, on-demand environments, release builds on an agent of their own, Renovate and an encrypted store for secrets."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-deploys/"]
tags: ["Infrastructure", "Deployment", "Jenkins", "Forgejo", "Docker Compose", "CI/CD"]
series: ["Infrastructure"]
seriesOrder: 4
seriesGroup: "The self-hosted platform"
---

[Yggdrasil](https://github.com/artur-rios/yggdrasil) is the deploy
manager I built for my servers. It does three jobs: check every change before
it can merge, take an application from its repository to a healthy container
in the right environment, and go back to the previous version if the new one
does not come up. This part follows a change from a pull request to
production.

## Forgejo, with GitHub as a mirror

The code lives on **Forgejo**, on the DevOps Server, at
`git.techcraftsmen.net`: every repository, its pull requests, its issues and
its releases. Every repository is push-mirrored to a read-only copy on GitHub,
which is a second home for the git data and the place where the few Windows
and macOS jobs still run, on GitHub Actions. Releases are published on both,
so anything that downloads from GitHub keeps working.

Forgejo is the primary, not GitHub, because the whole pipeline then runs on
machines I control, and GitHub's outages, limits and pricing reach only the
jobs that need Windows or macOS. Registration is closed: the accounts are mine
and a handful of bots, each with a token scoped to what it does.

## One catalog

Everything yggdrasil knows comes from one file, `catalog.yaml`, in four
layers:

- **Systems**: what a user thinks of as one product, such as Heimdall, for
  identity and access management.
- **Applications**: each deployable part of a system, with its own repository,
  release cycle and container, such as `heimdall-api` and `heimdall-ui`. A
  documentation site is an application too.
- **Repositories** that are not applications: the libraries, the apps that
  ship as releases instead of containers, and the ones that only run checks.
  Each gets a Jenkins job and the branch rules, but nothing is deployed from
  it.
- **Environments**: where applications run, each with options for how they
  are exposed and what deploys to them.

```yaml
environments:
  - id: development
    trigger: branch
    branches: develop
    agent: vps
    hostSuffix: -dev
    onDemand: true

  - id: production
    trigger: release
    agent: vps

systems:
  - id: heimdall
    name: Heimdall
    applications:
      - id: heimdall-api
        kind: api
        health: http://heimdall-api:8080/healthcheck
        metrics: heimdall-api:9464
        detailedHealth: http://heimdall-api:9464/internal/health
        integrations: [{ system: hermes, check: Hermes }]
        host: heimdall-api
        checks: [test, docker, check]
        environments:
          development: {}
          homologation: {}
          production: { approval: true }
```

Jenkins' jobs and agents, Forgejo's branch rules, the deploy script, the
status API, Prometheus's targets and the console all read this one file.
Adding an application, an environment or a whole system is a catalog entry,
never a change to the platform.

## Four environments

| Environment | Where | Deployed | Runs | Host names |
| --- | --- | --- | --- | --- |
| Local | My workstation's Docker Desktop | By hand | While deployed | `localhost` ports |
| Development | The Application Server | On a push to `develop` | On demand | `heimdall-dev.techcraftsmen.net` |
| Homologation | The Application Server | On a push to `release/*` | On demand | `heimdall-hml.techcraftsmen.net` |
| Production | The Application Server | When a release pull request passes, after my approval | Always | `heimdall.techcraftsmen.net` |

Three environments share one server, told apart by the suffix in their host
names, and one wildcard certificate covers them all. Development and
homologation are **on demand**: they stay stopped until someone needs them,
with `ygg env start development`, so the server spends its capacity on
production the rest of the time. A push to `develop` still builds the new
version, starts it, waits for it to be healthy and stops it again, so a
broken build is caught even while nobody is using the environment.

Each application can narrow the list. Most sites deploy to production only,
on every push to `main`, and every production deploy of an API, a web app or
a released site waits for me to click **Deploy**.

## The release flow

Every repository follows the same branches, and Forgejo enforces them through
branch and tag protections that yggdrasil applies from the catalog:

```text
feature/<name> ─┐
fix/<name> ─────┴─▶ develop ──▶ release/x.y.z ──▶ main   (tagged vx.y.z)
```

- Into `develop` go only `feature/*`, `fix/*` and Renovate's `renovate/*`
  branches, cut from `develop`.
- Into `main` go only `release/x.y.z` branches that are snapshots of
  `develop`, for a version that has no tag yet.
- Both change only through pull requests, which need the branch policy, the
  repository's checks, and on `main` one `deploy/<environment>` status for
  each release environment. Merging to `main` is therefore impossible until
  production is running the release.
- Version tags of an application are created only by Jenkins. A library's,
  or yggdrasil's own, are pushed by me, which is what releases them.

## Jenkins: checks, releases and deploys

A self-hosted Jenkins, configured entirely as code, does all three. Its
controller runs on the DevOps Server and builds nothing itself: the work runs
on three **agents**, each in the engine of its own user:

| Agent | Server | Runs |
| --- | --- | --- |
| `ci` | DevOps | Every check, each in its own container, at most four at a time |
| `release` | DevOps | Release builds, signing and NuGet pushes, from what I merged only |
| `vps` | Application | Deploys, and the merge, tag and release of an application |

Every agent dials out to the controller over a WebSocket on port 443, so no
server opens a port for Jenkins, and a second Application Server is one more
agent, not a new Jenkins. Forgejo sends a webhook on every push and pull
request, and Jenkins has one job per catalog entry.

### Checks are data, not code

**Jenkins never runs a repository's own pipeline code.** Every job runs the
same short Jenkinsfile, kept inside Jenkins, which loads yggdrasil's pipeline
library at a pinned release. What a repository controls is a data file,
`yggdrasil.yml`, that names its checks: an image pinned by digest, a command,
and the names of the credentials it may use.

```yaml
# yggdrasil.yml of a .NET library, trimmed
checks:
  test:
    image: mcr.microsoft.com/dotnet/sdk:10.0.402@sha256:...
    run: ci/test.sh
    archive: "artifacts/test-results/**"
  coverage:
    image: mcr.microsoft.com/dotnet/sdk:10.0.402@sha256:...
    run: ci/coverage.sh
    credentials:
      REPORTGENERATOR_LICENSE: reportgenerator-license
    archive: "coverage-report/**"
```

The library runs each check in its container on the `ci` agent, reports it as
a commit status on Forgejo, and binds a credential only if the catalog allows
that repository that id. A pull request from Renovate or an AI session can
change what its checks run, but never what the pipeline does or which secrets
it reaches. The commands are scripts under `ci/` in the repository, so the
same check runs on my machine too.

### What each event does

1. **A pull request** into `develop` or `main` runs the branch policy and the
   checks, as statuses on its head commit. For the repositories with Windows
   or macOS jobs, Jenkins also waits for those GitHub Actions results on the
   mirror.
2. **A push to a branch** runs the checks again, then deploys to every
   environment whose `branches` match: `develop` to development, `release/*`
   to homologation, `main` for the sites.
3. **A release pull request** from `release/x.y.z` to `main` waits for every
   check, then deploys to each release environment in order, asking for my
   approval first where the catalog says so, and sets `deploy/<environment>`
   after each. Once the last succeeds, it merges the pull request, tags
   `vx.y.z`, builds and validates the release files on the release agent when
   the repository declares any, publishes the release on Forgejo and then on
   GitHub, and deletes the branch.
4. **An owner's tag** on `main` releases a library or an app that ships as
   files: the release agent builds it from the tag and publishes it, or packs
   and pushes its packages to nuget.org.
5. **Build with Parameters** deploys any branch to an environment by hand.

## What a deploy does

The `vps` agent runs yggdrasil's deploy script on the Application Server, with
the application's checkout and its version:

1. **Build on the server.** `docker compose build --pull` builds the image
   from the application's own Dockerfile, with yggdrasil's overlay for the
   environment on top. There is no container registry: the image is built
   where it runs.
2. **Tag it.** Every image is tagged with the environment, version and commit,
   such as `heimdall-api:production-1.4.0-3f2a9c1`, and every container is
   labelled with the same, plus the time of the deploy.
3. **Start and wait.** `docker compose up --wait` starts the new containers
   and waits, five minutes by default, for their health checks to pass.
4. **Roll back if they do not.** If the new version never becomes healthy, the
   script starts the previous image of the same environment again, and the
   deploy fails. Rollback does not undo database migrations, so every
   migration stays compatible with the previous release.
5. **Prune.** The last three images of each application in each environment
   are kept, for rollbacks; older ones are deleted, and a daily timer trims
   the build cache.

Building on the server means no registry to run, and a web app's settings can
be compiled into its bundle per environment. The cost is CPU on the
Application Server during a deploy, which is part of
[Sizing the Servers]({{< ref "/infrastructure/infrastructure-sizing" >}}).

### The overlays

An application's repository may have its own `docker-compose.yml`, which runs
it anywhere. Yggdrasil adds an overlay per exposure mode, kept in its own
repository under `stacks/`, that changes only how the application is reached:

- **`<app>.proxy.yml`**, for the server: no host ports, the `edge` and
  `telemetry` networks, Traefik's routing labels named after the environment
  so several environments can share one engine, and, for an API, its
  database.
- **`<app>.ports.yml`**, for a workstation: ports published on `127.0.0.1`, no
  Traefik.

A site has no Compose file of its own: yggdrasil's templates give it one,
with a read-only file system, every capability dropped and no privilege
escalation. Each application runs as its own Compose project per environment,
such as `heimdall-api-production`, reachable by other containers as
`heimdall-api.production`.

## Secrets

An application's settings and secrets live in yggdrasil's **variables
store**: an encrypted SQLite database on each server, with layers, so a value
shared by several applications or environments is defined once, plus history
and rollback of every change. At deploy time, the store renders the
application's variables into a private temporary file that disappears
afterwards. The store and its key are in the nightly backup.

```bash
# KEY=- asks for the value with echo off, so it stays out of the shell history
ygg vars set heimdall-api@production HEIMDALL_AUTH_TOKEN_SECRET=- --secret
ygg vars history heimdall-api@production
```

Jenkins' own credentials, the Forgejo tokens, the signing keys and the
nuget.org key, are files on the DevOps Server that Jenkins reads at start.
Each is bound only into the step that needs it: a check gets the credentials
its catalog entry allows, the signing keys reach only the release agent, and
the nuget.org key only the step that pushes, where no repository code runs.

## Renovate

Dependencies are kept current by **Renovate**, which runs once a day as its
own user on the DevOps Server, never inside Jenkins, since it runs package
managers while holding a token that can push. It visits the catalog's
repositories and opens pull requests from `renovate/*` branches into
`develop`, which go through the same checks as mine. The images in the
Dockerfiles and `yggdrasil.yml` files are pinned by version and digest, so an
update is a pull request I read and merge, never a silent change.

## The `ygg` command

Everything above can be done from a server's terminal too, through `ygg`, a
command-line tool with a full-screen menu:

| Command | Does |
| --- | --- |
| `ygg status` | Every environment on this server, with each application's health, version and deploy time |
| `ygg deploy production heimdall-api` | Builds and deploys from a checkout, with the same rollback |
| `ygg config heimdall-api production` | Changes an application's variables, then redeploys it |
| `ygg env start development` | Turns an on-demand environment on, or off with `stop` |
| `ygg vars ...` | Reads and changes the variables store |
| `ygg platform up` | Starts the platform stack |
| `ygg backup run` | Backs this server up to the other one |
| `ygg check` | Audits the server against its role |
