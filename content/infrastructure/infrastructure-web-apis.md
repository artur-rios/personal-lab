---
title: "Web APIs"
description: "What an ASP.NET Core API looks like to my servers: a multi-stage Docker image pinned by digest and running as a non-root user, PostgreSQL in a container of its own per environment, migrations applied on start, configuration from the variables store, health and detailed health, OpenTelemetry metrics on a private port, and Traefik routing it under its own host and under the web app's origin, with a rate limit at the edge."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-web-apis/"]
tags: ["Infrastructure", ".NET", "ASP.NET Core", "Docker", "PostgreSQL", "OpenTelemetry"]
series: ["Infrastructure"]
seriesOrder: 6
seriesGroup: "What runs on it"
---

My backends are ASP.NET Core APIs, and every one of them meets the platform the
same way. Heimdall's API is the example throughout; Fortuna's and Hermes'
follow the same shape.

| Concern | Choice |
| --- | --- |
| Framework | ASP.NET Core on .NET 10 |
| Image | Multi-stage: the SDK to build, the ASP.NET runtime to run, both pinned by digest |
| Database | PostgreSQL 18, a container of its own per environment |
| Configuration | Environment variables, from yggdrasil's variables store |
| Health | `/healthcheck`, and a detailed report on the private port |
| Metrics | OpenTelemetry's Prometheus exporter, on port 9464 |
| Logs | Standard output, shipped to Loki |
| Checks | Tests, a Docker build and the OpenAPI document, run by Jenkins |

## The image

The Dockerfile has two stages. The first restores and publishes with the .NET
10 SDK, copying the project files before the sources so a source-only change
reuses the cached restore. The second copies the output onto the much smaller
ASP.NET runtime image, and runs it as the image's own non-root user. Both
images are pinned to a version and a digest, which Renovate updates through
pull requests:

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0.402@sha256:... AS build
WORKDIR /source
COPY Directory.Packages.props ./
COPY src/Presentation/ArturRios.Heimdall.WebApi/*.csproj src/Presentation/ArturRios.Heimdall.WebApi/
# ... the other project files, then dotnet restore, then the sources,
# dotnet publish, and the migrations bundle

FROM mcr.microsoft.com/dotnet/aspnet:10.0.13@sha256:... AS final
WORKDIR /app
COPY --from=build /app .
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
USER $APP_UID
ENV ASPNETCORE_HTTP_PORTS=8080;9464
EXPOSE 8080 9464
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["dotnet", "ArturRios.Heimdall.WebApi.dll"]
```

The API listens on 8080 and serves metrics on 9464, and `/metrics` answers
only on a connection that arrived on 9464, decided by the socket's port rather
than a header a caller could set. Neither port is published on the host:
Traefik reaches the first and Prometheus the second, each over its own Docker
network.

## The database

Each API that keeps data has its own PostgreSQL in each environment, a `db`
service that yggdrasil's overlay adds next to the API, with its data in a
volume of that environment's project. The API reaches it as `db` on the
project's own network, which no other project joins, so the database is on
neither of the shared networks and publishes no port. Compose starts the API
only once the database answers its health check.

Two roles keep the rights apart: one owns the schema, and the one the API runs
as owns nothing. Every night, the backup dumps each database with
`pg_dumpall` inside its container and sends it to the other server, as
described in [The Servers]({{< ref "/infrastructure/infrastructure-server" >}}).

## Migrations on start

The entry point applies the database migrations before the API starts, with an
EF Core migrations bundle, a self-contained executable that `dotnet ef
migrations bundle` builds in the SDK stage. A deploy therefore never runs code
against an older schema. If the migrations fail, the container fails, its
health check never passes, and yggdrasil rolls back to the previous version:

```sh
if [ "${HEIMDALL_RUN_MIGRATIONS:-true}" = "true" ]; then
    HEIMDALL_DATA_CONNECTIONSTRING="$migrations_connection" /app/heimdall-migrate
fi
unset HEIMDALL_MIGRATIONS_CONNECTIONSTRING
exec "$@"
```

The migrations use a connection string of their own, as the schema's owner,
which reaches the bundle through its environment, never its command line, and
is removed before the API starts. A rollback does not undo a migration, so
each one stays compatible with the previous release.

## Configuration

Nothing about an environment is in the image. Connection strings, token
secrets and allowed origins are environment variables, which yggdrasil renders
from the variables store for each environment at deploy time. A value shared
by every environment, or by several applications, is defined once in a layer
of its own.

## Health and metrics

- **`/healthcheck`** answers 2xx when the API can serve. Docker's health check,
  yggdrasil's deploy, which waits for it before declaring success, and the
  status API, every 15 seconds, all use it.
- **`/internal/health`**, on the private port, is the detailed report: one
  entry per dependency, such as the database or Hermes for Heimdall's mail.
  The status API fetches it when the console asks, and the console draws each
  integration as a line on its system map.
- **Metrics** come from OpenTelemetry with its Prometheus exporter, including
  ASP.NET Core's request metrics and .NET's runtime metrics. The catalog names
  the port, `heimdall-api:9464`, and Prometheus finds it through the status
  API.

## Routing: two doors to one API

Yggdrasil's overlay for the server gives the API two routers in Traefik:

- **Its own host**, `heimdall-api.techcraftsmen.net`, for mobile and desktop
  clients.
- **The web app's origin**, `heimdall.techcraftsmen.net/api/`, for the
  browser.

Every API route already starts with `/api/`, so nothing is rewritten. Because
the web app calls its own origin, the browser needs no CORS and sends no
preflight requests.

```yaml
# stacks/heimdall-api.proxy.yml, trimmed
services:
  api:
    ports: !reset []
    networks:
      default: {}
      edge:
        aliases: ["heimdall-api.${YGG_ENVIRONMENT}"]
      telemetry:
        aliases: ["heimdall-api.${YGG_ENVIRONMENT}"]
    labels:
      - traefik.enable=true
      - traefik.http.routers.heimdall-api-${YGG_ENVIRONMENT}.rule=Host(`${PUBLIC_HOST}`)
      - traefik.http.routers.heimdall-api-${YGG_ENVIRONMENT}-same-origin.rule=Host(`${UI_HOST}`) && PathPrefix(`/api/`)
```

`ports: !reset []` removes the host port the repository's own Compose file
publishes for local use, so on the server Traefik is the only way in.

Not every API is public. Hermes, which delivers email for the other services,
has no host and no router at all: Heimdall and Prometheus reach it over its
aliases on the Docker networks, and nothing on the internet can.

## Behind Cloudflare and Traefik

Behind the proxies, every request seems to come from Traefik's address, and
Traefik's from Cloudflare's. Traefik trusts the forwarded headers only from
Cloudflare's ranges, and the API trusts them only from the proxy addresses its
`HEIMDALL_TRUSTED_PROXIES` setting lists. With
`HEIMDALL_CLOUDFLARE_PROXIED=true`, it reads the entry Cloudflare added rather
than Cloudflare's own address, so the client it sees is the visitor.

That matters for the sign-in rate limit, which runs in two places:

- **At the edge**, a third router catches every request to `/api/auth/` that
  is not a `GET`, `HEAD` or `OPTIONS`, and Traefik limits it to 10 a minute
  per visitor, an IPv6 caller counted by its `/56`. A refused request costs
  nothing and never reaches the API.
- **In the API itself**, with its own per-client limit, as a second line.

## Checks before a deploy

The API's checks are declared in its `yggdrasil.yml` and run by Jenkins on
every pull request and push, each in its own pinned container: the tests,
including the migrations and a vulnerability scan of the packages, a Docker
build, so an image that does not build never reaches the server, and a check
that the OpenAPI document matches the code. Fortuna's API adds a dependency
audit and the build of its native core.
