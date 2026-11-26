# semaphore-platform


[Semaphore UI](https://semaphoreui.com) deployed with **rootless containers** and **configured as code**: one command creates the project, SSH key, Git repository, inventories and task templates that run [ansible-infra](../ansible-infra).

## Problem

Server provisioning depended on running Ansible from an engineer's machine. There was no shared history, no access control, and every new Semaphore install was configured by clicking through the UI.

## Solution

- `compose.yml` runs Semaphore + PostgreSQL 18 (SCRAM-SHA-256), bound to localhost and hardened with `no-new-privileges`.
- `make secrets` generates all passwords and the access-key encryption secret. Nothing sensitive lives in Git.
- `scripts/bootstrap.py` uses the Semaphore REST API (Python stdlib only). It is **idempotent** and supports `--dry-run`.

Why Semaphore and not AWX? See [ADR 0001](../../decisions/0001-semaphore-over-awx.md).
Architecture and guardrails: [docs/architecture.md](docs/architecture.md).

## How to run

```bash
make secrets          # creates .env with random secrets
make up               # docker compose up -d   (or: make up COMPOSE="podman compose")

cp config/semaphore.example.json config/semaphore.json   # adjust repo URL and key path
export SEMAPHORE_USER=admin
export SEMAPHORE_PASSWORD="$(grep SEMAPHORE_ADMIN_PASSWORD .env | cut -d= -f2)"

make bootstrap-dry-run   # shows what would be created
make bootstrap           # creates it
```

Example output:

```text
Connected to http://127.0.0.1:3000
  + project     infrastructure (created, id=1)
  + key         ansible-ssh (created, id=3)
  + repository  ansible-infra (created, id=4)
  + inventory   lab (created, id=6)
  + template    Provision server (created, id=7)
  + template    Provision server (dry run) (created, id=8)
  + template    Onboard client (created, id=9)
  + template    Patch CVE-2021-4034 (created, id=10)
Done.
```

Running it again changes nothing (`= ... exists`).

## AI-assisted operations

This environment is also operated with **AI agent skills**, which call `bootstrap.py` and Semaphore's API to configure projects and provision environments. The guardrails are part of the design:

- The agent runs `--dry-run` / `--check --diff` first, and a human approves before any apply.
- Credentials come from environment variables or Semaphore's key store, never from prompts.
- Every change goes through Git (merge request + CI) or the Semaphore task history, so it stays auditable.

The skills themselves live in the `ai-ops-skills` project (coming soon).

## Roadmap

- [ ] NGINX reverse proxy with TLS in the compose file
- [ ] Backups of the Semaphore database (pg_dump + retention)
- [ ] Semaphore secrets for registry tokens per client
- [ ] `ai-ops-skills` project

---
Author: **Jean Lima**, DevOps Engineer · [LinkedIn](https://www.linkedin.com/in/jcmdl)
