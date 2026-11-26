# ADR 0006: No connection pooler; a connection limit per client instead

- **Status:** Accepted
- **Date:** 2026

## Context

Several clients were moved to a shared PostgreSQL server. The worry was running out of connections, so PgBouncer was added in front of it.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| PgBouncer, session mode | Drop-in | Saves no connections: one client session = one server connection |
| PgBouncer, transaction mode | Real savings | Breaks session features the apps use (session advisory locks, server-side cursors). Needs app changes owned by another team |
| **Direct connections with `CONNECTION LIMIT` per client role** | No extra component; app code unchanged | Must size limits up front |

## Decision

Remove the pooler. Applications connect straight to PostgreSQL. Each client role gets `CONNECTION LIMIT = terminals + 15`. The deploy playbook refuses to add a client if the sum of all limits exceeds `max_connections` minus the reserved slots.

## Consequences

- One component less to run, monitor and secure.
- A misbehaving client hits its own limit instead of exhausting the server.
- The number of terminals becomes a required deploy parameter.
- The pooler config stays in the repository for a future move to transaction mode, once the apps support it.
