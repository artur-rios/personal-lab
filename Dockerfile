# The site, built in a pinned Hugo image and served by static-web-server. It starts from yggdrasil's
# templates/site-hugo/Dockerfile; the build arguments are the stack file's (stacks/personal-lab-site.yml in yggdrasil):
#   PUBLIC_HOST, PUBLIC_PATH   the address the site is served at: Hugo's baseURL is https://<host><path>/ (just
#                    <path>/ when there is no host). The baseURL of hugo.toml is only what a plain `hugo` uses.
#   GIT_COMMIT, YGG_ENVIRONMENT   the commit and the environment this image is built for.
#
# The nuno theme was a git submodule, and the pipeline checks out without submodules, so the first stage fetches the
# theme's commit as a tarball and verifies it before anything is built from it.
FROM curlimages/curl:8.23.0@sha256:11e64e28c5f58c8d93ee95fcf22ac055f48b0bc440e0ce7d8013bbb5ad6aa8ac AS theme

# https://github.com/artur-rios/hugo-theme-nuno at this commit. Nothing tracks a git commit, so it is bumped by hand:
# set NUNO_COMMIT to the new commit, then NUNO_SHA256 to the checksum of
# https://codeload.github.com/artur-rios/hugo-theme-nuno/tar.gz/<commit> (curl it and run sha256sum on the file).
ARG NUNO_COMMIT=8d00966c1d46e468281969431a9463c1fff14af9
ARG NUNO_SHA256=5fbb521535cd5953a3645b9f30b0ccd98639b66ff860fde1a3ec645ba73164c4

RUN set -eu; \
    curl --fail --retry 3 --silent --show-error --location \
      --output /tmp/nuno.tar.gz \
      "https://codeload.github.com/artur-rios/hugo-theme-nuno/tar.gz/${NUNO_COMMIT}"; \
    echo "${NUNO_SHA256}  /tmp/nuno.tar.gz" | sha256sum -c -; \
    mkdir /tmp/nuno; \
    tar -xzf /tmp/nuno.tar.gz --strip-components=1 -C /tmp/nuno

FROM hugomods/hugo:debian-node-lts-0.165.0@sha256:eef6a12572c8cf3fea72fb034606f3e6a0821368682139378608eabc94e67c87 AS build

WORKDIR /src
COPY . .
COPY --from=theme /tmp/nuno/ themes/nuno/

ARG HUGO_DIR=.
ARG PUBLIC_HOST=
ARG PUBLIC_PATH=
ARG GIT_COMMIT=
ARG YGG_ENVIRONMENT=
ENV HUGO_GIT_COMMIT=${GIT_COMMIT} \
    HUGO_YGG_ENVIRONMENT=${YGG_ENVIRONMENT}

# A missing theme makes Hugo warn and write an empty site rather than fail, so the build checks it wrote one.
RUN set -eu; \
    cd "$HUGO_DIR"; \
    if [ -f package-lock.json ]; then npm ci; fi; \
    if [ -n "$PUBLIC_HOST" ]; then base="https://$PUBLIC_HOST$PUBLIC_PATH/"; else base="$PUBLIC_PATH/"; fi; \
    hugo --environment production --minify --gc --baseURL "$base" --destination /out; \
    test -s /out/index.html

FROM joseluisq/static-web-server:2.44.1@sha256:94618e3d17802265a21926217e6f9e7832b311b6fbf5933684001739fafed06a

# Declared again: an argument lives in the stage that declares it.
ARG PUBLIC_PATH=
ARG GIT_COMMIT=
ARG YGG_ENVIRONMENT=

# The server has no shell, so nothing is run here: the site is copied under its path, and /healthz is a file of
# its own at the root. Port 8080, a numeric non-root user.
COPY --from=build /out/ /public${PUBLIC_PATH}/
COPY <<EOT /public/healthz
ok
EOT

# Hugo writes 404.html at the site's root (under the path): an address the site does not have is a 404.
ENV SERVER_PORT=8080 \
    SERVER_ROOT=/public \
    SERVER_ERROR_PAGE_404=/public${PUBLIC_PATH}/404.html

LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      yggdrasil.built-for="${YGG_ENVIRONMENT}"

USER 65532:65532
EXPOSE 8080
