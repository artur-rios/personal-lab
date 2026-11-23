---
title: "The Platform: Traefik, Monitoring and the Console"
description: "The shared stack on both of my servers: Traefik with Let's Encrypt wildcard certificates for three domains over DNS-01, Cloudflare's proxy in front with the origin locked to it, least-privilege Docker socket proxies, Prometheus, Loki, Alloy and Grafana on each server, and yggdrasil's status API and console with its system map."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-platform/"]
tags: ["Infrastructure", "Traefik", "Let's Encrypt", "Cloudflare", "Prometheus", "Grafana", "Docker"]
series: ["Infrastructure"]
seriesOrder: 3
seriesGroup: "The self-hosted platform"
---

On top of [the servers]({{< ref "/infrastructure/infrastructure-server" >}}) runs
one Compose project, `yggdrasil`, in `ygg`'s rootless engine. Both servers run
the same file; what each starts depends on its **profiles**, set in its
settings:

```bash
scripts/platform.sh up
```

| Profile | Starts | On |
| --- | --- | --- |
| (always) | Traefik, Prometheus, Loki, Alloy, Grafana and the Docker socket proxies | Both servers |
| `forge` | Forgejo | The DevOps Server |
| `jenkins` | The Jenkins controller | The DevOps Server |
| `apps` | The status API and the console | The Application Server |
| `agent` | The Jenkins agent that deploys this server's applications | The Application Server |

| Component | Version | Job |
| --- | --- | --- |
| Traefik | v3.6 | Routes every request, terminates TLS |
| Docker socket proxies | 1.13.1 | Give Traefik, Alloy and the status API read-only access to Docker |
| Forgejo | 16.0.6, rootless image | The git server, covered in [Deploying With Yggdrasil]({{< ref "/infrastructure/infrastructure-deploys" >}}) |
| Jenkins | 2.580 LTS | Checks, releases and deploys, covered in the same part |
| Status API | .NET 10 | Health, version and deploy time of every application |
| Console | Flutter | Shows the status API, on the web, Windows and Android |
| Prometheus | v3.5 | Metrics, kept 30 days |
| Loki | 3.5 | Logs, kept 31 days |
| Alloy | v1.10 | Ships every container's logs to Loki |
| Grafana | 12.1 | Dashboards over Prometheus and Loki |

Every image is pinned to a version, most of them to a digest as well, and
Renovate proposes the updates as pull requests.

## Traefik and wildcard certificates

Traefik is the only container that publishes web ports, 80 and 443, and port
80 does nothing but redirect to 443. It watches Docker through its socket
proxy for containers that opt in with labels, so a new application is routed
the moment it starts, without touching Traefik's configuration.

Certificates come from Let's Encrypt over the **DNS-01 challenge**: Traefik
proves it controls a domain by writing a TXT record through Cloudflare's API.
That is what makes **wildcard certificates** possible: one for `example.com`
and `*.example.com`, which covers every application in every environment
under that domain. DNS-01 never passes through Cloudflare's proxy, so renewals
keep working with the proxy on.

The Application Server serves three domains, and Traefik asks for one
wildcard certificate for each:

| Domain | Serves |
| --- | --- |
| `techcraftsmen.net` | The applications and APIs, the console, Grafana and the Traefik dashboard |
| `artur-rios.tech` | The static and documentation sites |
| `artur-rios.com` | Nothing of its own: a permanent redirect to `www.artur-rios.tech` |

Environments are told apart by a suffix in the host name,
`heimdall.techcraftsmen.net` in production and
`heimdall-dev.techcraftsmen.net` in development, so a new application or
environment never waits for a certificate.

Traefik's static configuration is rendered from the platform's settings by a
small script, so the list of domains, the trusted proxies and the entry points
are always consistent with one another. A shared file of middlewares sets the
rest: TLS 1.2 as the minimum, strict SNI so a request for an unknown host gets
no certificate, and security headers such as HSTS. Redirects that belong to no
application, such as `artur-rios.com` or the retired address of an old docs
site, are Traefik file routers in yggdrasil's repository, which Traefik
reloads on a `git pull`.

## Cloudflare in front

The three domains' DNS is on Cloudflare, with a handful of records each:

| Record | Points to | Proxy |
| --- | --- | --- |
| `*` and the bare domain | The Application Server | Proxied |
| `git`, `jenkins`, `traefik-dev`, `grafana-dev`, on `techcraftsmen.net` | The DevOps Server | DNS only |
| `CAA` on the bare domain | Let's Encrypt, DNS-01 only | n/a |

A specific record wins over the wildcard, so those four names reach the
DevOps Server and everything else reaches the Application Server. A script in
yggdrasil creates and corrects them through Cloudflare's API, and never
deletes a record it did not make.

The two servers are treated differently on purpose:

- **The Application Server is proxied**, with SSL mode **Full (strict)**, so
  Cloudflare checks Traefik's certificate too. Its firewall accepts 80 and 443
  only from Cloudflare's address ranges, which the installer downloads and
  `ygg check` compares with Cloudflare's current list. Traefik trusts the
  `X-Forwarded-For` header from those ranges only, so it logs and rate-limits
  the real visitor, and nobody can choose the address they are counted as.
- **The DevOps Server is DNS only.** Git over SSH, on port 2222, cannot pass
  Cloudflare's proxy, and a large push over HTTPS would hit the proxy's limit
  on a request's size.

With the proxy on, caching needs one rule: Cloudflare caches static file
extensions by default, so a cache rule bypasses the cache for every path that
starts with `/api/` and for the APIs' own host names. Flutter's
`main.dart.js` has no hash in its name, so after a web app's release the
cache may need a purge, as described in
[Web Apps]({{< ref "/infrastructure/infrastructure-web-apps" >}}).

## Networks and the Docker socket

Two Docker networks connect the platform to the applications:

| Network | Who is on it | For |
| --- | --- | --- |
| `edge` | Traefik, the status API and every application | Requests routed from the internet |
| `telemetry` | Prometheus and every application with metrics | Scraping metrics, on ports no router exposes |

On both, an application is `<application>.<environment>`, such as
`heimdall-api.production`, so the environments of a server never mix. An
API's database is on neither: it sits on its own Compose project's network.

Whoever can talk to Docker's socket controls the engine, so no service that
faces the internet holds it. Traefik, Alloy and the status API each get a
**socket proxy** of their own that allows only the read-only calls that
service makes, on a network only the two of them share. The status API, the
one reachable from the internet behind a token, gets the container list and
nothing else: not the container inspect, which carries every application's
environment and so its secrets. The proxies run read-only, with every Linux
capability dropped. The only container that holds the real socket is the
Jenkins deploy agent, which has to, since deploying means starting
containers.

## Monitoring, on each server

Each server watches itself, with its own Prometheus, Loki, Alloy and Grafana.
The Application Server's Grafana is `grafana.techcraftsmen.net`; the DevOps
Server's is `grafana-dev.techcraftsmen.net`, and its Traefik dashboard
`traefik-dev`, since the wildcard name already belongs to the other server.

- **Prometheus** finds its targets on the Application Server from the
  catalog, through the status API, so an application added to the catalog is
  scraped with no change to Prometheus. The DevOps Server has no status API,
  so it reads a written-out list of the platform's services and Jenkins. Both
  scrape every 15 seconds and keep 30 days.
- **Alloy** reads every container's output through its socket proxy and ships
  it to **Loki**, labelled with the environment, stack, service, container and
  log level, kept for 31 days.
- **Grafana** has both as data sources. Community dashboards cover most of it:
  ASP.NET Core, Traefik and Jenkins each have one ready to import.

Docker keeps each container's own log files small, at five files of 10 MB, so
a noisy container can never fill the disk.

## Status API and console

Monitoring answers "why is it slow?". The status API answers an earlier
question: "is everything up, and what is deployed where?". It reads the
catalog, probes every application's health URL in every environment every 15
seconds, and reads the labels each deploy stamps on its containers: the
environment, version, commit and deploy time.

The console shows it as a **system map**, one per environment: every system
is a node with its status, and every integration between systems, or to an
external service such as Mailgun, is a line, green when it works and red when
it fails. Selecting a system opens its applications, each with its health,
latency, version, commit, deploy time, container state and restarts, and what
the application reports about its own dependencies. An on-demand environment
that is switched off shows as **Stopped**, which is neutral, not a problem.

The console runs on the web at `yggdrasil.techcraftsmen.net`, and as a Windows
installer and an Android app attached to every yggdrasil release, so checking
the servers takes a glance at a phone.

## Not yet in place

Grafana has no alert rules yet, so a problem is seen when someone looks. The
one alert that reaches me without looking is Heimdall's security signal job:
it runs every fifteen minutes, mails what it detects through Hermes, and pings
an outside monitor, healthchecks.io, which mails me if a run fails or stops
arriving. The first Grafana rules to add are the ones that predict an outage
rather than report it: host memory above 85% for five minutes, disk above
80%, a container restarting, and an API answering more than 1% of requests
with a 5xx error.
