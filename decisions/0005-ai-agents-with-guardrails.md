# ADR 0005: AI agents operate infrastructure through reviewed scripts

- **Status:** Accepted
- **Date:** 2026

## Context

A small team handles many servers and clients. Repetitive operations (new client, VPN peer for a store terminal, SSH key for a terminal, nightly checks) took a lot of manual steps and depended on the one person who knew them. AI agents (Claude Code) can run these end to end, but an agent improvising in production is a risk.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Keep manual runbooks | No new risk | Slow, error-prone, depends on people |
| Let the agent call APIs and SSH freely | Most flexible | Unpredictable; hard to audit; one bad guess hits production |
| **Agent + skills that call small reviewed scripts, dry run first, one human confirmation** | Predictable, auditable, still saves most of the work | Scripts must be maintained; new operations need a new skill |

## Decision

- Each operation is a **skill**: instructions plus one script that is the only thing allowed to write (for example, Semaphore's API).
- The agent collects input, runs a dry run, shows a short plan and asks for **one** confirmation before applying.
- **Scheduled runs are read-only** unless the task explicitly allows a change, and stop at the first unexpected result.
- Secrets never pass through prompts or task parameters.
- The agent never commits; changes reach servers through Git ([ADR 0003](0003-changes-only-through-git.md)).

## Consequences

- Teammates who do not know Ansible can run provisioning safely.
- Nightly checks report in the morning with a one-line traffic-light summary.
- Every action leaves a trail: Semaphore task history, routine logs, tickets.
- The quality of the knowledge base the agent reads becomes part of operations. It is versioned in Git and reviewed like code.
