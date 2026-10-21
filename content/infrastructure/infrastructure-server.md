---
title: "The Server"
description: "The single Ubuntu VPS that runs every self-hosted application: its size, how SSH is locked down, how yggdrasil's installer prepares it, where everything lives on disk, and the PostgreSQL instance installed on the host for all environments."
date: 2026-10-21T17:55:00Z
categories: ["Infrastructure"]
# The pages lived under /projects/ until the section was renamed.
aliases: ["/projects/infrastructure-server/"]
tags: ["Infrastructure", "VPS", "Ubuntu", "Docker", "PostgreSQL", "Security"]
series: ["Infrastructure"]
seriesOrder: 2
seriesGroup: "The self-hosted platform"
---

Everything self-hosted runs on one machine: the platform, the deploy server,
and every application in three environments. This part covers the machine
itself and what is installed on it directly, outside any container.

## The machine

| Resource | Spec |
| --- | --- |
| Provider | Hostinger VPS |
| vCPU | 4 cores |
| RAM | 16 GB |
| Disk | 200 GB NVMe |
| Bandwidth | 16 TB a month |
| OS | Ubuntu LTS |

One machine is a single point of failure, and I accept that knowingly: these
are my own projects, an outage costs me an evening, and one well-understood
server is easier to keep healthy than three. Whether everything fits on it is
the subject of [Sizing the Server]({{< ref "/infrastructure/infrastructure-sizing" >}}).

## Lock down SSH first

A new VPS answers SSH on the open internet with a root password, and is probed
by bots within minutes. Before anything else, I create my own user, copy my key
to it, and turn off both root logins and passwords:

```bash
# As root on a fresh Ubuntu VPS
adduser deploy && usermod -aG sudo deploy
rsync --archive --chown=deploy:deploy ~/.ssh /home/deploy

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# Security updates install themselves
apt update && apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

Keep the first session open until a second one logs in with the key: a typo in
`sshd_config` otherwise locks you out of your own server.

## Let the installer do the rest

From there, yggdrasil prepares the server itself. Its command-line tool, `ygg`,
has an installer for Ubuntu that asks before each step:

```bash
git clone -b main https://github.com/artur-rios/yggdrasil.git /opt/yggdrasil
cd /opt/yggdrasil
scripts/ygg.sh install
```

1. **Packages** the scripts need: Git, curl, OpenSSL, Python with PyYAML and
   cryptography, and `htpasswd` for the dashboards' passwords.
2. **Docker**, from Docker's own apt repository rather than Ubuntu's, with the
   Buildx and Compose plugins. It offers to remove Ubuntu's `docker.io` and
   Podman's Docker shim first, since they conflict.
3. **The `docker` group** for my user, so deploys need no `sudo`.
4. **The secrets directory**, `/etc/yggdrasil`, owned by the `docker` group and
   closed to everyone else, with templates of the environment files.
5. **The firewall**: `ufw` allowing only SSH, HTTP and HTTPS. It asks with "no"
   as the default answer, since on a laptop a firewall change is unwelcome.

`ygg check` audits the same list later, so a server can be checked against what
the installer would have done, and `ygg self-install` puts `ygg` on the path
with tab completion.

## Where everything lives

| Path | What it holds |
| --- | --- |
| `/opt/yggdrasil` | The yggdrasil checkout: the platform's Compose file, scripts and the catalog |
| `/etc/yggdrasil` | Secrets: the platform's settings, the DNS provider's token, one env file per application and environment, the GitHub App's key |
| `~/yggdrasil-apps` | Checkouts of the applications, for deploys started by hand |
| Docker volumes | Prometheus, Loki, Grafana and Jenkins data |

Nothing secret is in a Git repository: the secrets directory is outside every
checkout, and its files are readable only by their owner and the `docker`
group. They can also live in yggdrasil's encrypted variables store instead,
described in [Deploying With Yggdrasil]({{< ref "/infrastructure/infrastructure-deploys" >}}).

## PostgreSQL, on the host

PostgreSQL is the one service installed directly on Ubuntu rather than in a
container. One instance serves every application in every environment, and
each pair gets its own database and its own login, so a bug in development can
never touch production's data:

| Application and environment | Database | Login |
| --- | --- | --- |
| Heimdall in production | `heimdall` | `heimdall_svc` |
| Heimdall in development | `heimdall_development` | `heimdall_development_svc` |

Containers reach it at `host.docker.internal`, which Docker maps to the host.
Three settings keep it reachable from containers and from nowhere else:

```ini
# postgresql.conf: the loopback address, and the Docker bridge's gateway
listen_addresses = 'localhost,172.17.0.1'
```

```text
# pg_hba.conf: each database, from Docker's address range only, with SCRAM passwords
host  heimdall  heimdall_svc  172.16.0.0/12  scram-sha-256
```

```bash
# ufw: port 5432 open to Docker's networks, never to the internet
sudo ufw allow from 172.16.0.0/12 to any port 5432 proto tcp
```

## Not yet in place

Two things I planned for the server are not part of it yet, and I list them
rather than pretend otherwise:

- **Database backups.** The plan is a nightly `pg_dump` of every database,
  compressed and synced to Mega with `rclone`, so a lost server costs at most a
  day of data. Today, only yggdrasil's variables store has a backup command.
- **A message queue.** None of the current applications needs one. When one
  does, RabbitMQ is the default, and Kafka only for real event streaming, which
  needs far more memory.
