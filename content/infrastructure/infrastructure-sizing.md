---
title: "Sizing the Server"
description: "A sizing model for my self-hosted stack: a reservation and a limit for every service, from Traefik and Jenkins to each API and web app per environment, a formula with headroom, the numbers worked through on a 4 vCPU, 16 GB server, and the signals that say it is time to grow."
date: 2026-10-21T17:55:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-sizing/"]
tags: ["Infrastructure", "Capacity Planning", "Docker", "PostgreSQL", "Monitoring"]
series: ["Infrastructure"]
seriesOrder: 5
seriesGroup: "The self-hosted platform"
---

Before an application goes on [the server]({{< ref "/infrastructure/infrastructure-server" >}}),
it should be clear that it fits. This is the model I size the server with: one
figure per service for what it needs, a formula that adds headroom, and the
signals that say the model has stopped being true.

The figures are **starting estimates** for a small production load, a few
requests a second on each API, not measurements. After a week of real traffic,
Grafana's numbers replace them.

## Two figures per service

- **Reservation**: what the service needs at steady state to stay healthy.
- **Limit**: the ceiling it may burst to. Services rarely burst together, so
  limits can add up to more than the server has; reservations must not.

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
| Jenkins controller | 0.25 vCPU | 1024 MB | 5 GB |
| Jenkins agent, idle | 0.10 vCPU | 256 MB | — |
| PostgreSQL, on the host | 0.50 vCPU | 1536 MB | 40 GB |
| **Platform total** | **2.00 vCPU** | **4624 MB** | **71 GB** |

Without PostgreSQL and Jenkins' controller, the platform comes to about 2 GB,
which matches yggdrasil's own guidance for a host: 2 GB for the platform, 4 GB
with the Jenkins controller, plus the applications.

### The applications

Each system is an API and a web app, and runs once per environment that is on:

| Service | CPU | RAM |
| --- | ---: | ---: |
| ASP.NET Core API | 0.50 vCPU | 384 MB |
| Flutter web app, on nginx | 0.10 vCPU | 48 MB |
| **One system in one environment** | **0.60 vCPU** | **432 MB** |

With Heimdall and Fortuna, each environment that is on adds **1.2 vCPU and
864 MB**.

## The formula

Every dimension is sized the same way:

```text
Required = OS baseline + sum of reservations + headroom
Headroom = at least 30% of (OS baseline + sum of reservations)
```

The OS and Docker take about 1 vCPU, 1 GB of RAM and 20 GB of disk. Docker
images take disk of their own: three kept per application and environment for
rollbacks, plus the build cache of the .NET and Flutter SDKs, about 20 GB in
all.

## Worked through on the server

Two cases matter: production alone, which is most of the time, and everything
on at once, while development and homologation are in use.

| Dimension | Production only | +30% | All three environments | +30% | Server |
| --- | ---: | ---: | ---: | ---: | ---: |
| CPU | 4.2 vCPU | 5.5 vCPU | 6.6 vCPU | 8.6 vCPU | 4 vCPU |
| RAM | 6.4 GB | 8.3 GB | 8.0 GB | 10.5 GB | 16 GB |
| Disk | 111 GB | 144 GB | 111 GB | 144 GB | 200 GB |

**RAM and disk fit with room to spare**, even with every environment on: more
than 5 GB of RAM stays free beyond the headroom, for PostgreSQL's cache and
for bursts, and about 55 GB of disk for growth.

**CPU is the tight dimension**, and it is the reason two design choices exist:

- **On-demand environments.** Development and homologation idle at almost no
  CPU when stopped, which they are most of the time. The reservations assume
  load, and only production has load.
- **Builds are bursts.** Building an image on the host, especially a Flutter
  web build, takes several cores for a few minutes. It runs at the moment of a
  deploy, next to production, so deploys at quiet hours cost nothing.

CPU reservations are a planning figure, not a hard split: an idle service
reserves 0.5 vCPU on paper and uses almost none. The model says the server is
fully booked on CPU under real load, which is the signal to watch first.

## Enforcing limits

Compose can cap each container, so one runaway service cannot starve the rest:

```yaml
services:
  api:
    cpus: "1.50"
    mem_limit: 768m
    mem_reservation: 384m
```

PostgreSQL runs on the host, so its limits are its own settings instead:
`shared_buffers` at about a quarter of its memory, and `effective_cache_size`
at what the operating system can cache for it.

## When to grow

| Signal, sustained | Action |
| --- | --- |
| Host CPU above 80% for 15 minutes | Add vCPU, or move PostgreSQL to its own server |
| Free RAM below 2 GB, or swapping | Add RAM, or shorten Prometheus's and Loki's retention |
| Disk above 80% | Grow the disk, shorten retention, or keep fewer rollback images |
| API latency at the 95th percentile climbing | Add a second API replica behind Traefik |
| Builds slowing production down | Build in GitHub Actions and push to a registry, so the server only pulls |
| Development or homologation always on | Give them a server of their own, with its own Jenkins agent |

The order that keeps the most for the least:

1. **Shorten observability retention**: the cheapest win.
2. **Add an API replica**: APIs are stateless, so it is one more container.
3. **Move development and homologation off the box**: yggdrasil already
   supports one agent per host, so it is a catalog change and a second server.
4. **Move PostgreSQL to its own server**: the biggest single reclaim of CPU and
   memory.
