---
title: "Deploying With Yggdrasil"
description: "How a push on GitHub becomes a running container on my server: one catalog file describing systems, applications and environments, a release flow enforced on GitHub, a self-hosted Jenkins that deploys on the host, automatic rollback, on-demand environments and an encrypted store for secrets."
date: 2026-10-21T17:55:00Z
categories: ["Projects"]
tags: ["Infrastructure", "Deployment", "Jenkins", "GitHub", "Docker Compose", "CI/CD"]
series: ["Infrastructure"]
seriesOrder: 4
seriesGroup: "The self-hosted platform"
---

[Yggdrasil](https://github.com/artur-rios/yggdrasil) is the deploy manager I
built for my server. It does one job: take an application from a GitHub
repository to a healthy container in the right environment, and back to the
previous version if the new one does not come up. This part follows a change
from a pull request to production.

## One catalog

Everything yggdrasil knows comes from one file, `catalog.yaml`, in three
layers:

- **Systems**: what a user thinks of as one product, such as Heimdall, for
  identity and access management.
- **Applications**: each deployable part of a system, with its own repository,
  release cycle and container, such as `heimdall-api` and `heimdall-ui`.
- **Environments**: where applications run, each with options for how they are
  exposed and what deploys to them.

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
        host: heimdall-api
        checks: [test, docker]
```

Jenkins' jobs, GitHub's rules, the deploy script, the status API, Prometheus's
targets and the console all read this one file. Adding an application, an
environment or a whole system is a catalog entry, never a change to the
platform.

## Four environments

| Environment | Where | Deployed | Runs | Host names |
| --- | --- | --- | --- | --- |
| Local | My workstation's Docker Desktop | By hand | While deployed | `localhost` ports |
| Development | The VPS | On a push to `develop` | On demand | `heimdall-dev.example.com` |
| Homologation | The VPS | On a push to `release/*` | On demand | `heimdall-hml.example.com` |
| Production | The VPS | When a release pull request passes | Always | `heimdall.example.com` |

Three environments share one server, told apart by the suffix in their host
names, and one wildcard certificate covers them all. Development and
homologation are **on demand**: they stay stopped until someone needs them,
with `ygg env start development`, so the server spends its capacity on
production the rest of the time.

## The release flow

Every repository follows the same branches, and GitHub enforces them through
rulesets that yggdrasil applies from the catalog:

```text
feature/<name> ─┐
fix/<name> ─────┴─▶ develop ──▶ release/x.y.z ──▶ main   (tagged vx.y.z)
```

`develop` and `main` change only through pull requests, which need three kinds
of check: the branch policy, the application's own CI from the catalog's
`checks`, and on `main` one `deploy/<environment>` status for each release
environment. Merging to `main` is therefore impossible until production is
running the release.

## Build and test on GitHub, deploy on the server

The work is split in two:

- **GitHub Actions builds and tests.** Each repository's workflows are its
  checks, and nothing in them deploys.
- **Jenkins deploys.** A self-hosted Jenkins, configured entirely as code, has
  one multibranch job per application in the catalog. A GitHub App sends it a
  webhook on every push and pull request, and a daily rescan catches any it
  missed.

An application joins by adding three files from yggdrasil's templates: a
branch-policy workflow, a `CONTRIBUTING.md`, and a two-line `Jenkinsfile` that
loads the shared pipeline from yggdrasil itself:

```groovy
@Library('yggdrasil') _

yggdrasilPipeline(stack: 'heimdall-api')
```

The pipeline acts on three kinds of event:

1. **A push to a branch** deploys to every environment whose `branches` match:
   `develop` to development, `release/*` to homologation.
2. **A pull request from `release/x.y.z` to `main`** waits for every GitHub
   check, then deploys to each release environment in order, asking for a
   manual approval first where the catalog says so. After each one it sets the
   `deploy/<environment>` status. Once the last succeeds, it merges the pull
   request, tags `vx.y.z`, creates the GitHub release and deletes the branch.
3. **Build with Parameters** deploys any version to a manual environment by
   hand.

Jenkins' controller never builds anything itself. Each server runs a Jenkins
**agent** that dials out to the controller over a WebSocket on port 443, so a
server needs no inbound port for Jenkins, and a second server is one more agent,
not a new Jenkins.

## What a deploy does

The agent runs yggdrasil's deploy script on the server, with the application's
checkout and its version:

1. **Build on the host.** `docker compose build --pull` builds the image from
   the application's own Dockerfile and Compose file, with yggdrasil's overlay
   for the environment on top. There is no container registry: the image is
   built where it runs.
2. **Tag it.** Every image is tagged with the environment, version and commit,
   such as `heimdall-api:production-1.4.0-3f2a9c1`, and every container is
   labelled with the same, plus the time of the deploy.
3. **Start and wait.** `docker compose up --wait` starts the new containers
   and waits, five minutes by default, for their health checks to pass.
4. **Roll back if they do not.** If the new version never becomes healthy, the
   script starts the previous image of the same environment again, and the
   deploy fails.
5. **Prune.** The last three images of each application in each environment
   are kept, for rollbacks; older ones are deleted.

Building on the host means no registry to run or pay for, and a web app's
settings can be compiled into its bundle per environment. The cost is CPU on
the server during a build, which is part of
[Sizing the Server]({{< ref "/projects/infrastructure-sizing" >}}).

### The overlays

An application's repository has its own `docker-compose.yml`, which runs it
anywhere. Yggdrasil adds an overlay per exposure mode, kept in its own
repository under `stacks/`, that changes only how the application is reached:

- **`<app>.proxy.yml`**, for the server: no host ports, the `edge` and
  `telemetry` networks, and Traefik's routing labels, named after the
  environment so several environments can share one Docker engine.
- **`<app>.ports.yml`**, for a workstation: ports published on `127.0.0.1`, no
  Traefik.

Each application runs as its own Compose project per environment, such as
`heimdall-api-production`, reachable by other containers as
`heimdall-api.production`.

## Secrets

An application's settings and secrets come from one env file per application
and environment, in `/etc/yggdrasil`, outside any checkout. They can instead
live in yggdrasil's **variables store**: an encrypted SQLite database on the
server, with layers, so a value shared by several applications or
environments is defined once, plus history and rollback of every change. At
deploy time, the store renders the env file into a private temporary directory
that disappears afterwards.

```bash
# KEY=- asks for the value with echo off, so it stays out of the shell history
ygg vars set heimdall-api@production HEIMDALL_AUTH_TOKEN_SECRET=- --secret
ygg vars history heimdall-api@production
```

Jenkins holds only its own credentials: the GitHub App's key, whose short-lived
installation token reaches the scripts as `GH_TOKEN`, and the agent's secret.

## The `ygg` command

Everything above can be done from the server's terminal too, through `ygg`, a
command-line tool with a full-screen menu:

| Command | Does |
| --- | --- |
| `ygg status` | Every environment on this host, with each application's health, version and deploy time |
| `ygg deploy production heimdall-api` | Builds and deploys from a checkout, with the same rollback |
| `ygg env start development` | Turns an on-demand environment on, or off with `stop` |
| `ygg vars ...` | Reads and changes the variables store |
| `ygg platform up` | Starts the platform stack |
| `ygg check` | Audits the host |
