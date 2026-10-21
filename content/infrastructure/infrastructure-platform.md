---
title: "The Platform: Traefik, Monitoring and the Console"
description: "The shared stack every application on my server sits behind: Traefik with a Let's Encrypt wildcard certificate obtained over DNS, Cloudflare DNS, least-privilege Docker socket proxies, Prometheus, Loki, Alloy and Grafana for monitoring, and yggdrasil's status API and console."
date: 2026-10-21T17:55:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-platform/"]
tags: ["Infrastructure", "Traefik", "Let's Encrypt", "Cloudflare", "Prometheus", "Grafana", "Docker"]
series: ["Infrastructure"]
seriesOrder: 3
seriesGroup: "The self-hosted platform"
---

On top of [the server]({{< ref "/infrastructure/infrastructure-server" >}}) runs one
Compose project, `yggdrasil`, that every application shares: the reverse proxy,
the monitoring, and a status API with its console. It is started once per host,
and serves every environment on that host.

```bash
scripts/platform.sh up
```

| Component | Version | Job |
| --- | --- | --- |
| Traefik | v3.6 | Routes every request, terminates TLS |
| Docker socket proxies | 1.13.1 | Give Traefik, Alloy and the status API read-only access to Docker |
| Status API | .NET 10 | Health, version and deploy time of every application |
| Console | Flutter | Shows the status API, on the web, Windows and Android |
| Prometheus | v3.5 | Metrics, kept 30 days |
| Loki | 3.5 | Logs, kept 31 days |
| Alloy | v1.10 | Ships every container's logs to Loki |
| Grafana | 12.1 | Dashboards over Prometheus and Loki |
| Jenkins | LTS | Deploys, covered in [Deploying With Yggdrasil]({{< ref "/infrastructure/infrastructure-deploys" >}}) |

## Traefik and one wildcard certificate

Traefik is the only container that publishes ports, 80 and 443, and port 80
does nothing but redirect to 443. It watches Docker for containers that opt in
with labels, so a new application is routed the moment it starts, without
touching Traefik's configuration.

Certificates come from Let's Encrypt over the **DNS-01 challenge**: Traefik
proves it controls the domain by writing a TXT record through the DNS
provider's API. That is what makes a **wildcard certificate** possible, one
certificate for `example.com` and `*.example.com`, which covers every
application in every environment. With environments told apart by a suffix,
`heimdall.example.com` in production and `heimdall-dev.example.com` in
development, a new application or environment never waits for a certificate.

```yaml
# Traefik's flags in platform/compose.yml, trimmed
- --providers.docker.exposedbydefault=false
- --providers.docker.network=edge
- --entrypoints.web.http.redirections.entrypoint.to=websecure
- --entrypoints.websecure.http.tls.certresolver=letsencrypt
- --entrypoints.websecure.http.tls.domains[0].main=${DOMAIN}
- --entrypoints.websecure.http.tls.domains[0].sans=*.${DOMAIN}
- --certificatesresolvers.letsencrypt.acme.dnschallenge.provider=${ACME_DNS_PROVIDER}
```

Only Traefik receives the DNS provider's token, from its own env file. A shared
file of middlewares sets the rest: TLS 1.2 as the minimum, strict SNI so a
request for an unknown host gets no certificate, and security headers such as
HSTS. The first certificates are requested from Let's Encrypt's staging server,
whose limits are generous, and switched to production once they work.

## DNS on Cloudflare

The domain's DNS is on Cloudflare, and the whole server needs a single record:
a wildcard `A` record, `*`, pointing at the server's address. Every host name,
in every environment, resolves through it.

The record starts as **DNS only**, so requests reach Traefik directly. Turning
on Cloudflare's proxy adds its CDN and attack protection in front, and then
needs SSL mode **Full (strict)**, since Traefik already serves a valid
certificate. With the proxy on, the web apps' host names also need a cache rule
that bypasses the cache: Flutter's `main.dart.js` has no hash in its name, so a
cached copy would keep serving the previous release after a deploy. For a domain-less start,
DuckDNS works too, as long as Traefik has a DNS-01 provider for it.

## Networks and the Docker socket

Three kinds of Docker network keep traffic apart:

| Network | Who is on it | For |
| --- | --- | --- |
| `edge` | Traefik and every application | Requests routed from the internet |
| `telemetry` | Prometheus and every application | Scraping metrics, on ports no router exposes |
| Internal socket-proxy networks | One per proxy and its client | Reaching Docker's API |

Whoever can talk to Docker's socket controls the server, so no platform
service mounts it. Traefik, Alloy and the status API each get a **socket
proxy** of their own that allows only the read-only calls that service needs,
on a network only the two of them share. The proxies run read-only, with every
Linux capability dropped. The only container that holds the real socket is the
Jenkins agent, which has to, since deploying means starting containers.

## Monitoring

Every application exposes Prometheus metrics on a port reached only over the
`telemetry` network, and every container writes its logs to standard output.

- **Prometheus** finds its targets from the catalog, through the status API,
  so an application added to the catalog is scraped with no change to
  Prometheus. It scrapes every 15 seconds and keeps 30 days.
- **Alloy** reads every container's output through its socket proxy and ships
  it to **Loki**, labelled with the environment, stack, service, container and
  log level, kept for 31 days.
- **Grafana** has both as data sources. Community dashboards cover most of it:
  ASP.NET Core, Traefik and Jenkins each have one ready to import.

Docker keeps each container's own log files small, at five files of 10 MB, so a
noisy container can never fill the disk.

## Status API and console

Monitoring answers "why is it slow?". The status API answers an earlier
question: "is everything up, and what is deployed where?". It reads the
catalog, probes every application's health URL in every environment, and reads
the labels each deploy stamps on its containers: the environment, version,
commit and deploy time.

The console shows it as one card per system, with a status per environment,
expandable to each application's health, version and container state. It runs
on the web at `yggdrasil.example.com`, and as a Windows installer and an Android
app, so checking the server takes a glance at a phone.

## Not yet in place

Grafana has no alert rules yet, so a problem is seen when someone looks. The
first rules to add are the ones that predict an outage rather than report it:
host memory above 85% for five minutes, disk above 80%, a container
restarting, and an API answering more than 1% of requests with a 5xx error.
