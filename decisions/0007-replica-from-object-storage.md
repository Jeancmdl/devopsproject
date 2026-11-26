# ADR 0007: Read-only replica restored from object storage

- **Status:** Accepted
- **Date:** 2026

## Context

A BI team needed a read-only copy of a production database. The primary sat in a network where opening a replication port to the BI side was not acceptable.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| Streaming replication | Lag in seconds | Needs a network path and a port open to the primary; replication slot can fill the primary's disk |
| Nightly dump and restore | Simple | Data up to a day old; hours of restore |
| **Log shipping through S3 with pgBackRest** | No connection between primary and replica; reuses the backup pipeline | Lag of seconds to minutes, depending on `archive_timeout` |

## Decision

The primary pushes WAL and backups to an encrypted S3 bucket with pgBackRest. The replica has read-only credentials to the bucket and restores as a standby with `restore_command = pgbackrest archive-get`. No slot, no open port between them.

## Consequences

- Backup and replica are the same pipeline: if the replica is fresh, the backup works.
- `archive_timeout = 60` keeps lag around one minute. Without it, lag grows at night when there is little write traffic.
- After every restore, `postgresql.auto.conf` comes from the primary with archive push enabled and must be rewritten (see the [runbook](../runbooks/postgres-replica-from-s3.md)).
- BI queries are never cancelled (`max_standby_archive_delay = -1`). Replay waits instead.
