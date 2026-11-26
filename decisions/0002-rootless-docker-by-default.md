# ADR 0002: Rootless Docker as the default for every service

- **Status:** Accepted
- **Date:** 2026

## Context

Applications for many clients share the same servers. With the classic Docker daemon, anyone who can talk to the socket is effectively root, and a container escape lands as root on the host. Several legacy apps also ran directly on the host with broad permissions.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Rootful Docker | Familiar, every guide assumes it | Socket = root; one client's breach reaches all others |
| Podman | Rootless by design, no daemon | Compose compatibility gaps with the existing stacks; team not used to it |
| **Rootless Docker, one Linux user per client** | Same CLI and Compose files; isolation by Unix user; a breach stays in that user | Ports below 1024 need a proxy; data moves to `~/.local/share/docker`; needs systemd user sessions |

## Decision

Every client or service gets its own Linux user running rootless Docker, with lingering enabled and the rootful daemon disabled. Provisioning is done by the `docker_rootless` Ansible role.

## Consequences

- A compromised container reaches one unprivileged user, not the host.
- `userland-proxy: false` is required, or the backend sees the proxy address instead of the real client IP (this broke IP-based licensing and logs until fixed).
- Hosts without systemd (old Amazon Linux 1) cannot run it; those stay rootful until migrated.
- Weekly `docker image prune` runs as a systemd **user** timer, with absolute paths (systemd does not use the shell `PATH`).
- Never create shared config in `/etc` for these users: one global file once broke every rootless service at boot. Per-user config lives in `~/.config`.
