# ADR 0001: Semaphore UI instead of AWX

- **Status:** Accepted
- **Date:** 2026

## Context

The team needed a web UI to run Ansible playbooks with access control, history and secrets management, so that provisioning would not depend on one engineer's laptop.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| **AWX** | Feature-rich, Red Hat upstream | Requires a Kubernetes cluster and an operator. Heavy for a small team with no existing cluster |
| **Semaphore UI** | Single container + PostgreSQL, low footprint, REST API, native Git integration | Fewer enterprise features (no workflow visualizer) |
| **CLI + CI only** | No extra service | No self-service, no run history for non-engineers |

## Decision

Use **Semaphore UI**, deployed with Docker Compose (rootless) and PostgreSQL, configured as code through its REST API (`scripts/bootstrap.py`).

## Consequences

- Runs on one small VM, with no Kubernetes to operate.
- The configuration is reproducible: the server can be rebuilt from Git in minutes.
- If workflow orchestration becomes necessary, AWX can be reconsidered. Playbooks stay portable either way.
