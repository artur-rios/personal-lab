---
title: "Web Apps"
description: "What a Flutter web app looks like to my servers: a Flutter SDK pinned by checksum in the build stage, settings compiled into the bundle per environment, an unprivileged nginx pinned by digest with a read-only file system serving it, a health endpoint, the cache rules a Flutter build needs behind Cloudflare, and release builds for Android and Windows next to the web."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-web-apps/"]
tags: ["Infrastructure", "Flutter", "Docker", "nginx", "Cloudflare"]
series: ["Infrastructure"]
seriesOrder: 7
seriesGroup: "What runs on it"
---

My interactive front ends are Flutter apps, and on the web they are a set of
static files: HTML, JavaScript and WebAssembly. So the container that runs one
is just a web server, small and stateless. Heimdall's web app is the example;
Fortuna's and Chimera's are built the same way.

| Concern | Choice |
| --- | --- |
| Framework | Flutter 3.50, built for the web |
| Build stage | Debian with a Flutter SDK pinned by version and checksum |
| Runtime | nginx, unprivileged, pinned by digest, with a read-only file system |
| Settings | Compiled in at build time, once per environment |
| API | Its own origin's `/api/`, routed to the API by Traefik |
| Health | `/healthz` |
| Checks | Analysis and tests, the web build, and generated code, run by Jenkins |

## The image

The build stage installs Flutter itself, rather than starting from a community
Flutter image, so the exact SDK version is pinned and its download is checked
against a SHA-256 checksum. It builds as a non-root user, and fetches packages
with `--enforce-lockfile`, so the build uses exactly the versions the
repository was tested with:

```dockerfile
FROM --platform=linux/amd64 debian:13.7-slim@sha256:... AS build
ARG FLUTTER_VERSION=3.50.0
ARG FLUTTER_SHA256=...
# ... download Flutter, check the checksum, flutter precache --web

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY . .

ARG HEIMDALL_API_BASE_URL
RUN flutter build web --release --no-web-resources-cdn \
      --dart-define=HEIMDALL_API_BASE_URL=${HEIMDALL_API_BASE_URL}

FROM nginxinc/nginx-unprivileged:1.31.7-alpine@sha256:...
COPY --from=build /home/flutter/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /home/flutter/app/build/web /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK CMD wget -qO- http://127.0.0.1:8080/healthz || exit 1
```

`--no-web-resources-cdn` makes the build serve Flutter's own engine files and
fonts from the app instead of Google's CDN, so the app works the same behind
any network and loads nothing from a third party.

## Settings are compiled in

A Flutter web build reads its settings through `--dart-define` at **build**
time; they end up inside the JavaScript bundle, and the browser has no
environment variables to read at run time. The API's address therefore has to
be known when the image is built, which is why yggdrasil builds a web app
**once per environment**, with that environment's values as build arguments.
The image refuses to build without the API's address, rather than silently
falling back to the developer's `localhost`, and it writes that address into
nginx's Content Security Policy too, so the page may call its API and nothing
else.

The address is the app's own origin, such as `https://heimdall.techcraftsmen.net`.
Traefik routes `/api/` on that origin to the API, as described in
[Web APIs]({{< ref "/infrastructure/infrastructure-web-apis" >}}), so the browser
never makes a cross-origin request.

## nginx

The runtime is nginx's unprivileged image, listening on 8080 as a non-root
user, and yggdrasil's stack runs it with a read-only file system and a
temporary directory in memory. Its configuration does three jobs:

```nginx
# docker/nginx.conf, trimmed
server {
    listen 8080;
    root /usr/share/nginx/html;

    # Health, for Docker, yggdrasil and the status API
    location = /healthz {
        add_header Cache-Control "no-store" always;
        return 200 "ok\n";
    }

    # A single-page app: every client-side route serves index.html
    location / {
        try_files $uri $uri/ /index.html;
        add_header Cache-Control "no-cache" always;
        add_header Content-Security-Policy "default-src 'self'; ..." always;
        add_header X-Frame-Options "DENY" always;
    }
}
```

The `try_files` fallback is what lets a user reload the page on a route such as
`/settings`, which exists only inside the app, without getting a 404.

## Caching

The web apps sit behind Cloudflare's proxy, like everything on the
Application Server. Flutter names its main script `main.dart.js`, with no
hash of its contents in the name, so a cache that keeps it would serve the
previous release after a deploy, with a fresh `index.html` loading stale
code. Three things keep that from happening:

- nginx sends `Cache-Control: no-cache`, so browsers revalidate on every load;
- the zone's cache rule bypasses Cloudflare's cache for every `/api/` path, so
  the app's calls always reach the API;
- after a release, I load the app and check that the new version is the one
  I see, and purge Cloudflare's cache if it is not.

## Checks before a deploy

The web app's checks are declared in its `yggdrasil.yml` and run by Jenkins on
every pull request and push: formatting, analysis and tests with coverage, a
web build, and a check that its generated code is current. Heimdall's web app
verifies that its API client still matches the API's OpenAPI document, so an
API change that breaks the client fails before it is deployed. Fortuna's also
checks that its native core's headers and bindings are current.

## More than the web

The same Flutter code ships to more than browsers. A release of Heimdall's web
app also builds Linux and Android packages on the release agent, where the
Android package is signed with a key only that agent can reach, and a Windows
build on GitHub Actions, on the mirror. Jenkins gathers them all, validates
them, and attaches them to the release on Forgejo and on GitHub.

## Locally

On a workstation, yggdrasil's `ports` overlay publishes the same image on a
`localhost` port, with no Traefik, and the app is deployed by hand with
`ygg deploy local heimdall-ui`.
