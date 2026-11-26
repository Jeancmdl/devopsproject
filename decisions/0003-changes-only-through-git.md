# ADR 0003: Servers change only through Git and playbooks

- **Status:** Accepted
- **Date:** 2026

## Context

Quick fixes were made with `scp`, `docker cp` or editing files directly on a host. They worked until the next `git pull` erased them, and nobody could tell what was really running on a server.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Manual copy when urgent | Fast | Drift; lost on next deploy; no review, no history |
| **Commit, push, then pull + playbook on the host** | Reviewable, reproducible, auditable | A few minutes slower; needs working Git access on every host |

## Decision

A change reaches a server only by: commit, push, and on the host `git pull` plus the playbook (or the Semaphore template). The only local file per host is the git-ignored `.env`. If `git pull` fails on a server, fix the cause (SSH key, credential), never work around it with a copy.

Commits themselves need explicit human approval. Automation, including AI agents, leaves changes in the working tree and asks.

## Consequences

- Any server can be rebuilt from Git.
- Broken Git access on a host becomes a visible incident instead of a silent workaround.
- Emergency fixes still go through a commit, even a small one.
