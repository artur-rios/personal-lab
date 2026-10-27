#!/bin/sh
# The `build` check: the site's image (the Dockerfile) can still be produced, which is Hugo building the whole site
# with the theme fetched and verified. The old Pages workflow built the site on every pull request; this is that.
# Build only, no push and no run: how the image answers is the deploy's. yggdrasil.yml runs it in the pinned docker
# CLI image (an Alpine one: no bash, hence sh) with the CI engine's socket (`docker: true`), from the repository's
# root. The image has a tag of its own for each run and is removed when the script ends, so builds in parallel never
# share one and none is left behind.
set -eu

# The repository's root, wherever this is run from.
cd "$(dirname "$0")/.."

# A tag of its own for each run: the shell is PID 1 in its container, so the process id alone would not be one.
image="personal-lab-site-check:$(date +%s)-$(tr -dc a-z0-9 </dev/urandom | head -c 8)"
trap 'docker rmi --force "$image" >/dev/null 2>&1 || true' EXIT

docker build --file Dockerfile --tag "$image" .
