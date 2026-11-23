---
title: "The Servers"
description: "The two Ubuntu VPS that run everything I self-host: a DevOps Server for the code and the pipeline and an Application Server for every environment, the users and rootless Docker engines that keep them apart, how yggdrasil's installer prepares them, PostgreSQL in a container per application, and the nightly backups each sends to the other."
date: 2026-10-21T17:55:00Z
lastmod: 2026-11-22T12:00:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-server/"]
tags: ["Infrastructure", "VPS", "Ubuntu", "Docker", "PostgreSQL", "Security"]
series: ["Infrastructure"]
seriesOrder: 2
seriesGroup: "The self-hosted platform"
---

Everything self-hosted runs on two machines with two jobs: one keeps the code
and runs the pipeline, the other runs what the pipeline deploys. This part
covers the machines themselves, who may do what on them, and what is
installed on them outside the platform's containers.

## The two machines

| | DevOps Server | Application Server |
| --- | --- | --- |
| Job | Git server, checks, releases, AI development | Every environment of every application and site |
| Runs | Forgejo, the Jenkins controller, the build agents, Renovate | The applications, the status API and console, the deploy agent |
| Both run | Traefik, Prometheus, Loki, Alloy and Grafana | Traefik, Prometheus, Loki, Alloy and Grafana |
| vCPU | 8 | 8 |
| RAM | 32 GB | 32 GB |
| Disk | 400 GB NVMe | 400 GB NVMe |
| OS | Ubuntu 26.04 LTS | Ubuntu 26.04 LTS |
| Cloudflare | DNS only | Proxied |
| Open ports | 22, 80, 443, and 2222 for git over SSH | 22, and 80 and 443 from Cloudflare only |

Until October 2026 there was one server, which ran the platform, Jenkins and
every environment, and deployed from GitHub. On 2026-10-26 it was converted in
place into the Application Server, and the DevOps Server was added next to it.
Two reasons made the split worth a second bill:

- **Checks run code I did not review.** A pull request from Renovate or from
  an AI session builds and tests whatever it contains. On the server that runs
  production, a bad check is a step away from production's data; on another
  machine, it is not.
- **Builds compete for CPU.** A Flutter web build or a .NET test run with
  Testcontainers takes several cores for minutes. On their own machine they
  slow nothing that a visitor sees.

Each machine is still a single point of failure for its own job, and I accept
that knowingly: these are my own projects, an outage costs me an evening, and
each server holds a copy of the other's data, as described under
[backups](#backups-each-server-to-the-other).

## Users: one per job

Neither machine has a login that can do everything. On both:

- **`root` cannot log in**, and SSH accepts keys only, for the listed users.
- **One admin user** has `sudo`, with a password, for the operating system
  only: updates, packages, users and the firewall. It runs no services and has
  no Docker engine.
- **Every service runs as a user of its own**, with no `sudo`, and with a home
  directory the other users cannot read.

| User | Server | Runs |
| --- | --- | --- |
| `ygg` | Both | The platform; on the Application Server, every application too |
| `ci` | DevOps | The CI agent and every check container |
| `release` | DevOps | The release agent: release builds, signing and package publishing |
| `renovate` | DevOps | Renovate's daily run |
| `dev` | DevOps | AI development sessions and the containers they start |

`ci`, `release` and `renovate` have no shell at all. The `release` user exists
because release files ship to users, through the apps' own updaters and to
nuget.org: if they were built in the same engine as the checks, a check from a
pull request could reach a release build's containers while it ran. The
release agent only ever builds what the owner merged.

The users that run code I have not reviewed, `ci`, `release`, `renovate` and
`dev`, are also refused every port below 1024, so a check cannot take ports 80
and 443 while Traefik restarts, and `ci` and `dev` are capped at six of the
eight CPUs, so neither a build nor an AI session can starve Forgejo or Jenkins.

## Rootless Docker

There is no rootful Docker on either machine and no `docker` group: the system
engine is disabled and masked, so not even a package upgrade can start it
again. Instead, **each service user runs its own Docker engine**, as itself,
started at boot by its own systemd.

That changes what a compromised container can do. Root inside a container is
the service user on the host, so it reaches only what that user can: a check
in `ci`'s engine cannot see `ygg`'s socket, `ygg`'s secrets or the release
agent's engine, and the installer's audit proves it on every run rather than
assuming it.

Two side effects matter. Rootless engines publish ports as ordinary
processes, so the firewall finally applies to containers; rootful Docker
writes its own rules and bypasses `ufw`. And the engines use `slirp4netns` as
their network and port driver, which keeps the real source address of a
connection, so Traefik and the APIs see real clients, not one internal
address.

## The installer

yggdrasil prepares both machines. Its command-line tool, `ygg`, has an
installer for Ubuntu that takes the machine's role and asks before each step:

```bash
# As the admin, on a fresh Ubuntu 24.04 or 26.04 server
sudo apt update && sudo apt install -y git python3 python3-yaml
sudo install -d -o "$USER" /opt/yggdrasil
git clone -b main https://git.techcraftsmen.net/artur-rios/yggdrasil.git /opt/yggdrasil
cd /opt/yggdrasil
scripts/ygg.sh install --role apps      # or --role dev
```

It refuses to start if the admin has no SSH key, since it is about to turn
passwords off, then goes through:

1. **Packages**: Git, Python, OpenSSL, `rsync`, `ufw`, unattended upgrades, and
   Docker from Docker's own apt repository with its rootless extras, Buildx and
   Compose. Ubuntu's `docker.io` and its kin are removed first, if I agree.
2. **The rootful engine, switched off**, and the `docker` group emptied.
3. **System settings**: unprivileged processes may bind ports 80 and 443,
   AppArmor lets `rootlesskit` create its user namespace, and users' systemd
   may apply CPU and memory limits.
4. **SSH**: no root login, no passwords, and only the admin and the roles'
   SSH users allowed. The file is named `00-yggdrasil.conf` so it wins over
   the cloud image's own settings, and it is checked with `sshd -T` before SSH
   reloads.
5. **The users and their engines**, each with its own secrets directory.
6. **The firewall**: on the Application Server, ports 80 and 443 accept only
   Cloudflare's published address ranges, so nobody reaches the server around
   Cloudflare.
7. **Security updates** that install themselves, and the daily timers: the
   backups, the image prunes and, on the DevOps Server, Renovate.

`ygg check` audits the same list later, one row per piece, so a server can be
checked against what the installer would have done.

## Where everything lives

| Path | What it holds |
| --- | --- |
| `/opt/yggdrasil` | The yggdrasil checkout, owned by `ygg`: the platform's Compose file, the scripts, the catalog and the stacks |
| `/etc/yggdrasil` | `ygg`'s secrets: the encrypted variables store, the DNS provider's token, the Jenkins credentials on the DevOps Server |
| `/etc/yggdrasil-<user>` | The other service users' own settings, such as a build agent's secret |
| `~ygg/.local/share/docker` | `ygg`'s engine: images and volumes of the platform and, on the Application Server, of every application |
| `~ygg/backups`, `~ygg/received` | This machine's nightly backups, and the other machine's |

Nothing secret is in a Git repository, and every directory of secrets is
readable only by its own user.

## PostgreSQL, in a container per application

PostgreSQL used to be installed on the host, one instance for every
application and environment. A rootless engine's containers cannot reach the
host's services, so the move to two servers moved the databases too: **each
API that needs one has its own PostgreSQL container in each environment**,
defined in yggdrasil's overlay for that API.

```yaml
# stacks/heimdall-api.proxy.yml, trimmed
services:
  api:
    depends_on:
      db:
        condition: service_healthy
  db:
    image: postgres:18.6@sha256:...
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${DB_SUPERUSER_PASSWORD}
    volumes:
      - db:/var/lib/postgresql
```

The API reaches it as `db` on its own Compose project's network, which no
other project joins: the database is on neither of the shared networks and
publishes no port. A bug in development can never touch production's data,
because production's database is a different container with a different
volume. The image is pinned to the major version its data was written by, so
moving to the next major version is a dump and a restore, never an accidental
image update.

## Backups: each server to the other

GitHub's mirror receives git data only, not pull requests, issues or release
files, so it is not a backup on its own. Every night at 03:30, each server
dumps its own data and sends it to the other with `rsync` over SSH:

| Server | What it dumps |
| --- | --- |
| DevOps Server | Forgejo, with every repository, pull request and issue; Jenkins' home; its variables store and key |
| Application Server | Every API database, with `pg_dumpall` in its container; the volumes that hold data; its variables store and key |

Seven days are kept on both sides. The SSH key that sends them can run nothing
but `rsync`, in one directory, so a stolen key reaches no shell and no other
file. A database is never backed up as the files of a running server: an
on-demand environment's database is started just for its dump and stopped
again. `ygg check` warns when the newest backup is more than 36 hours old.

## Not yet in place

- **A third copy.** Every backup lives on one of the two servers, so anything
  that reaches both at once, such as losing access to the hosting account,
  takes every copy with it. There is no copy anywhere else yet.
- **A message queue.** None of the current applications needs one. When one
  does, RabbitMQ is the default, and Kafka only for real event streaming,
  which needs far more memory.
