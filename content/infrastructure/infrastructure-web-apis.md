---
title: "Web APIs"
description: "What an ASP.NET Core API looks like to my server: a multi-stage Docker image running as a non-root user, configuration from the environment, migrations applied on start, a health check, OpenTelemetry metrics on a private port, and Traefik routing it under its own host and under the web app's origin."
date: 2026-10-21T17:55:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-web-apis/"]
tags: ["Infrastructure", ".NET", "ASP.NET Core", "Docker", "PostgreSQL", "OpenTelemetry"]
series: ["Infrastructure"]
seriesOrder: 6
seriesGroup: "The self-hosted platform"
---

My backends are ASP.NET Core APIs, and every one of them meets the platform the
same way. Heimdall's API is the example throughout; Fortuna's follows the same
shape.

| Concern | Choice |
| --- | --- |
| Framework | ASP.NET Core on .NET 10 |
| Image | Multi-stage: the SDK to build, the ASP.NET runtime to run |
| Database | The host's PostgreSQL, one database per environment |
| Configuration | Environment variables, from yggdrasil |
| Health | `/healthcheck`, probed by Docker, yggdrasil and the status API |
| Metrics | OpenTelemetry's Prometheus exporter, on port 9464 |
| Logs | Standard output, shipped to Loki |
| Checks | Tests and a Docker build in GitHub Actions |

## The image

The Dockerfile has two stages. The first restores and publishes with the .NET
10 SDK, copying the project files before the sources so a source-only change
reuses the cached restore. The second copies the output onto the much smaller
ASP.NET runtime image, and runs it as the image's own non-root user:

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /source
COPY Directory.Packages.props ./
COPY src/Presentation/ArturRios.Heimdall.WebApi/*.csproj src/Presentation/ArturRios.Heimdall.WebApi/
# ... the other project files, then dotnet restore, then the sources and dotnet publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app ./
USER $APP_UID
EXPOSE 8080 9464
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
```

The API listens on 8080 and serves metrics on 9464. Neither port is published
on the host: Traefik reaches the first and Prometheus the second, each over its
own Docker network.

## Migrations on start

The entry point applies the database migrations before the API starts, with an
EF Core migrations bundle, a self-contained executable that `dotnet ef
migrations bundle` builds in the SDK stage. A deploy therefore never runs code
against an older schema. If the migrations fail, the container fails, its health check
never passes, and yggdrasil rolls back to the previous version:

```sh
if [ "${HEIMDALL_RUN_MIGRATIONS:-true}" = "true" ]; then
    /app/heimdall-migrate
fi
exec "$@"
```

The migrations can use a connection string of their own, with the rights to
change the schema, which the entry point removes from the environment before
the API starts.

## Configuration

Nothing about an environment is in the image. Connection strings, token
secrets and allowed origins come from environment variables, which yggdrasil
writes from the application's env file or variables store for each
environment. The database host is `host.docker.internal`, the host's
PostgreSQL, with one database and login per environment, as described in
[The Server]({{< ref "/infrastructure/infrastructure-server" >}}).

## Health and metrics

- **`/healthcheck`** answers 2xx when the API can serve. Docker's health check,
  yggdrasil's deploy, which waits for it before declaring success, and the
  status API all use it.
- **Metrics** come from OpenTelemetry with its Prometheus exporter, including
  ASP.NET Core's request metrics and .NET's runtime metrics. The catalog names
  the port, `heimdall-api:9464`, and Prometheus finds it through the status
  API.

## Routing: two doors to one API

Yggdrasil's overlay for the server gives the API two routers in Traefik:

- **Its own host**, `heimdall-api.example.com`, for mobile and desktop clients.
- **The web app's origin**, `heimdall.example.com/api/`, for the browser.

Every API route already starts with `/api/`, so nothing is rewritten. Because
the web app calls its own origin, the browser needs no CORS and sends no
preflight requests.

```yaml
# stacks/heimdall-api.proxy.yml, trimmed
services:
  api:
    ports: !reset []
    networks:
      edge:
        aliases: ["heimdall-api.${YGG_ENVIRONMENT}"]
      telemetry:
        aliases: ["heimdall-api.${YGG_ENVIRONMENT}"]
    labels:
      - traefik.enable=true
      - traefik.http.routers.heimdall-api-${YGG_ENVIRONMENT}.rule=Host(`${PUBLIC_HOST}`)
      - traefik.http.routers.heimdall-api-${YGG_ENVIRONMENT}.entrypoints=websecure
```

`ports: !reset []` removes the host port the repository's own Compose file
publishes for local use, so on the server Traefik is the only way in.

## Behind a proxy

Behind Traefik, every request seems to come from Traefik's address. Rate
limiting and logging need the real client, so the API trusts the forwarded
headers only from the Docker networks' range, `172.16.0.0/12`, and rate limits
per real client inside the API itself.

## Checks before a deploy

The catalog lists the API's GitHub checks, which are required on `develop` and
`main`: the tests, and a Docker build, so an image that does not build never
reaches the server. Fortuna's API adds a check that its OpenAPI document
matches the code, and a dependency audit.
