---
title: "Web Apps"
description: "What a Flutter web app looks like to my server: a Flutter SDK pinned by checksum in the build stage, settings compiled into the bundle per environment, an unprivileged nginx with a read-only file system serving it, a health endpoint, and the cache rule a Flutter build needs behind a CDN."
date: 2026-10-21T17:55:00Z
categories: ["Projects"]
tags: ["Infrastructure", "Flutter", "Docker", "nginx", "Cloudflare"]
series: ["Infrastructure"]
seriesOrder: 7
seriesGroup: "The self-hosted platform"
---

My interactive front ends are Flutter apps, and on the web they are a set of
static files: HTML, JavaScript and WebAssembly. So the container that runs one
is just a web server, small and stateless. Heimdall's web app is the example.

| Concern | Choice |
| --- | --- |
| Framework | Flutter, built for the web |
| Build stage | Debian with a Flutter SDK pinned by version and checksum |
| Runtime | nginx, unprivileged, with a read-only file system |
| Settings | Compiled in at build time, once per environment |
| API | Its own origin's `/api/`, routed to the API by Traefik |
| Health | `/healthz` |
| Checks | Analysis and tests, and generated code checked in GitHub Actions |

## The image

The build stage installs Flutter itself, rather than starting from a community
Flutter image, so the exact SDK version is pinned and its download is checked
against a SHA-256 checksum. It builds as a non-root user, and fetches packages
with `--enforce-lockfile`, so the build uses exactly the versions the
repository was tested with:

```dockerfile
FROM debian:trixie-slim AS build
ARG FLUTTER_VERSION=3.47.7
ARG FLUTTER_SHA256=...
# ... download Flutter, check the checksum, flutter precache --web

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY . .

ARG HEIMDALL_API_BASE_URL
RUN flutter build web --release --no-web-resources-cdn \
      --dart-define=HEIMDALL_API_BASE_URL=${HEIMDALL_API_BASE_URL}

FROM nginxinc/nginx-unprivileged:alpine
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /home/flutter/app/build/web /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
```

`--no-web-resources-cdn` makes the build serve Flutter's own engine files from
the app instead of Google's CDN, so the app works the same behind any network
and loads nothing from a third party.

## Settings are compiled in

A Flutter web build reads its settings through `--dart-define` at **build**
time; they end up inside the JavaScript bundle, and the browser has no
environment variables to read at run time. The API's address therefore has to
be known when the image is built, which is why yggdrasil builds a web app
**once per environment**, with that environment's values as build arguments.
The image refuses to build without the API's address, rather than silently
falling back to the developer's `localhost`.

The address is the app's own origin, such as `https://heimdall.example.com`.
Traefik routes `/api/` on that origin to the API, as described in
[Web APIs]({{< ref "/projects/infrastructure-web-apis" >}}), so the browser
never makes a cross-origin request.

## nginx

The runtime is nginx's unprivileged image, listening on 8080 as a non-root
user, and yggdrasil runs it with a read-only file system and a temporary
directory in memory. Its configuration does three jobs:

```nginx
# docker/nginx.conf, trimmed
server {
    listen 8080;
    root /usr/share/nginx/html;

    # Health, for Docker, yggdrasil and the status API
    location = /healthz {
        return 200 "ok";
    }

    # A single-page app: every client-side route serves index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

The `try_files` fallback is what lets a user reload the page on a route such as
`/settings`, which exists only inside the app, without getting a 404.

## Caching

Flutter names its main script `main.dart.js`, with no hash of its contents in
the name. A cache that keeps it therefore serves the previous release after a
deploy, with a fresh `index.html` loading stale code. With Cloudflare's proxy
in front, the web apps' host names get a cache rule that bypasses the cache, or
the cache is purged after a release.

## Checks before a deploy

The catalog's required checks for a web app are its analysis and tests, and
checks that its generated code is current: Heimdall's web app verifies that its
API client still matches the API's OpenAPI document, so an API change that
breaks the client fails before it is deployed.

## Locally

On a workstation, yggdrasil's `ports` overlay publishes the same image on a
`localhost` port, with no Traefik, and the app is deployed by hand with
`ygg deploy local heimdall-ui`.
