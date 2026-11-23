---
title: "Sizing the Servers"
description: "A sizing model for my two self-hosted servers: a reservation for every service, from Traefik and the monitoring to each API, database, web app and site per environment, a formula with headroom, the numbers worked through on two 8 vCPU, 32 GB servers, the limits that keep the DevOps Server's builds in their lane, and the signals that say it is time to grow."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-sizing/"]
tags: ["Infrastructure", "Capacity Planning", "Docker", "PostgreSQL", "Monitoring"]
series: ["Infrastructure"]
seriesOrder: 5
seriesGroup: "The self-hosted platform"
---

Before an application goes on [the servers]({{< ref "/infrastructure/infrastructure-server" >}}),
it should be clear that it fits. This is the model I size them with: one
figure per service for what it needs, a formula that adds headroom, and the
signals that say the model has stopped being true.

Both servers are the same size, 8 vCPU, 32 GB of RAM and 400 GB of NVMe, but
they are loaded in opposite ways. The Application Server carries a steady load
that grows with every application; the DevOps Server is nearly idle most of
the day and fully busy while checks run.

The figures are **starting estimates** for a small production load, a few
requests a second on each API, not measurements. After a week of real
traffic, Grafana's numbers replace them.

## Two figures per service

- **Reservation**: what the service needs at steady state to stay healthy.
- **Limit**: the ceiling it may burst to. Services rarely burst together, so
  limits can add up to more than the server has; reservations must not.

## The Application Server

### The platform

| Service | CPU | RAM | Disk |
| --- | ---: | ---: | ---: |
| Traefik | 0.25 vCPU | 128 MB | — |
| Docker socket proxies, three | 0.05 vCPU | 48 MB | — |
| Status API | 0.10 vCPU | 128 MB | — |
| Console | 0.05 vCPU | 32 MB | — |
| Prometheus, 30 days | 0.25 vCPU | 768 MB | 10 GB |
| Loki, 31 days | 0.25 vCPU | 384 MB | 15 GB |
| Alloy | 0.10 vCPU | 128 MB | — |
| Grafana | 0.10 vCPU | 192 MB | 1 GB |
| Jenkins deploy agent, idle | 0.10 vCPU | 256 MB | — |
| **Platform total** | **1.25 vCPU** | **2064 MB** | **26 GB** |

That matches yggdrasil's own guidance of about 2 GB for the platform, now that
the Jenkins controller lives on the other server.

### The systems, per environment

Heimdall, Hermes, Fortuna and Chimera run once in each environment that is
on:

| Service | Count | CPU | RAM |
| --- | ---: | ---: | ---: |
| ASP.NET Core API | 3 | 1.50 vCPU | 1152 MB |
| PostgreSQL, one per API that has data | 2 | 0.50 vCPU | 512 MB |
| Flutter web app, on nginx | 3 | 0.30 vCPU | 144 MB |
| **One environment** | | **2.30 vCPU** | **1808 MB** |

The databases are small, about 10 MB of data each, so PostgreSQL's
reservation is mostly its own processes and a modest cache.

### The sites

The sites deploy to production only, with two exceptions that also have
development or homologation:

| Service | Count | CPU | RAM |
| --- | ---: | ---: | ---: |
| Static site on static-web-server | 23 | 0.46 vCPU | 184 MB |
| Node.js server, my page and the readme stats API | 2 | 0.20 vCPU | 384 MB |
| **All sites** | | **0.66 vCPU** | **568 MB** |

A static site is the cheapest thing the server runs: a web server of a few
megabytes serving files, which is why moving every site off Vercel and GitHub
Pages cost almost nothing here.

### The formula

Every dimension is sized the same way:

```text
Required = OS baseline + sum of reservations + headroom
Headroom = at least 30% of (OS baseline + sum of reservations)
```

The OS and the rootless engine take about 1 vCPU, 1 GB of RAM and 20 GB of
disk.

### Worked through

Two cases matter: production alone, which is most of the time, and everything
on at once, while development and homologation are in use.

| Dimension | Production only | +30% | All three environments | +30% | Server |
| --- | ---: | ---: | ---: | ---: | ---: |
| CPU | 5.2 vCPU | 6.8 vCPU | 10.0 vCPU | 13.0 vCPU | 8 vCPU |
| RAM | 5.3 GB | 6.9 GB | 9.3 GB | 12.0 GB | 32 GB |
| Disk | 190 GB | 247 GB | 190 GB | 247 GB | 400 GB |

**RAM fits with a wide margin**, even with every environment on: about 20 GB
stays free beyond the headroom, for PostgreSQL's cache, for bursts and for
the next systems.

**Disk fits**, and most of it is not the applications. The figure counts:

| What | Disk |
| --- | ---: |
| The OS and the platform | 46 GB |
| Images: three kept per application and environment, for rollbacks | 30 GB |
| Build cache, trimmed to 20 GB every night | 20 GB |
| Volumes and this server's own seven nights of backups | 10 GB |
| The DevOps Server's seven nights of backups | 84 GB |

The last row is the largest, because a Forgejo dump carries every release's
files, and releases with installers made it about 12 GB a night in November
2026. Leaving the attachments out of the dump, which the GitHub mirror also
holds, would cut it to a fraction.

**CPU is the tight dimension**, as it was on one server, and it is the reason
two design choices exist:

- **On-demand environments.** Development and homologation use almost no CPU
  when stopped, which they are most of the time. The reservations assume
  load, and only production has load.
- **Builds are bursts.** A deploy builds its image on this server, and a
  Flutter web build takes several cores for a few minutes, next to
  production. The checks no longer run here: they moved to the DevOps
  Server, so only deploys build on the Application Server.

CPU reservations are a planning figure, not a hard split: an idle API reserves
0.5 vCPU on paper and uses almost none. The model says that with production
alone, the server has room under real load; with every environment busy at
once, it does not, which is the signal to watch first.

## The DevOps Server

The DevOps Server is sized for its peak, four checks at once next to an AI
session:

| What | CPU | RAM, at peak |
| --- | ---: | ---: |
| Forgejo | 0.25 vCPU | 1 GB |
| Jenkins controller | 0.50 vCPU | 2 GB |
| Traefik, monitoring and the OS | 1.00 vCPU | 3 GB |
| The `ci` agent, four checks at once | 6 vCPU, capped | 16 GB, capped at 20 GB |
| AI development sessions and what they run | 6 vCPU, capped | 8 GB, capped |
| The `release` agent and Renovate | Bursts | A few GB |

The two big consumers are capped **on their user's systemd slice**, so the
cap covers the user's whole engine, every container in it included, not one
container:

```ini
# /etc/systemd/system/user-<uid>.slice.d/limits.conf, for ci
[Slice]
CPUQuota=600%
MemoryMax=20G
```

Six of the eight CPUs each means a build can never take the CPUs Forgejo,
Jenkins and an AI session need, and an AI session's runaway test suite is
killed inside its own 8 GB, never one of `ygg`'s processes. The two caps
together add up to more memory than the server has only if both are at their
peak at once. Within its cap, the `ci` agent runs at most four checks at a
time, about 1.5 CPUs and 5 GB each: a .NET test run with coverage, a Flutter
build or a Testcontainers check needs one to two CPUs and several GB at its
peak.

Disk is the other thing builds consume, and Docker never frees it by itself.
Daily timers keep each engine bounded: the build agents' engines drop
anything unused for a week and trim their build cache to 40 GB, and `ygg`'s
and `dev`'s keep only 20 GB of cache. The same timer runs on the Application
Server, whose engine had grown 139 GB of build cache from deploys alone
before it existed.

## Enforcing limits per container

Compose can also cap each container, so one runaway service cannot starve the
rest:

```yaml
services:
  api:
    cpus: "1.50"
    mem_limit: 768m
    mem_reservation: 384m
```

No stack sets one today. The rootless engines can apply them, since the
installer delegates CPU and memory control to users' systemd, so they are a
stack file away when Grafana shows a service that needs one.

## When to grow

| Signal, sustained | Action |
| --- | --- |
| Application Server CPU above 80% for 15 minutes | Add vCPU, or move the databases to a server of their own |
| Free RAM below 4 GB, or swapping | Add RAM, or shorten Prometheus's and Loki's retention |
| Disk above 80% | Leave attachments out of the Forgejo dump, shorten retention, or keep fewer rollback images |
| API latency at the 95th percentile climbing | Add a second API replica behind Traefik |
| Deploy builds slowing production down | Build images on the DevOps Server and push them to a registry, so the Application Server only pulls |
| Checks waiting in Jenkins' queue | Grow the DevOps Server, then raise the `ci` slice and the number of checks with it |
| Development or homologation always on | Give them an Application Server of their own, with its own deploy agent |

The order that keeps the most for the least:

1. **Shorten observability retention**: the cheapest win.
2. **Add an API replica**: APIs are stateless, so it is one more container.
3. **Move development and homologation off the box**: yggdrasil already
   supports one deploy agent per server, so it is a catalog change and a
   second Application Server.
4. **Move the databases to their own server**: the biggest single reclaim of
   CPU and memory on the Application Server.
