# Read-only PostgreSQL replica from S3 (pgBackRest)

Decision and trade-offs: [ADR 0007](../decisions/0007-replica-from-object-storage.md).

## Prerequisites

- The same stanza, bucket and cipher in the replica's `pgbackrest.conf`, with **read-only** S3 credentials.
- The database locale installed **before** restoring. Without it, PostgreSQL does not start.
- Disk ≥ database size plus margin.
- On the primary, `archive_timeout = 60` for lag around one minute.

## Restore as standby

```bash
pgbackrest --stanza=main --type=standby --process-max=4 --log-level-console=info restore
# re-restore: add --delta to reuse files already on disk
```

Never set a `recovery_target`: it promotes the replica.

**Critical trap:** the restore brings the primary's `postgresql.auto.conf`, with `archive_mode = on` and the push command. Rewrite it before starting:

```ini
archive_mode = 'off'
archive_command = ''
restore_command = 'pgbackrest --stanza=main archive-get %f "%p"'
hot_standby = 'on'
default_transaction_read_only = 'on'
max_standby_archive_delay = -1      # BI queries are never cancelled
max_standby_streaming_delay = -1
```

Check that `standby.signal` exists, then start. During the initial recovery, `FATAL: the database system is not yet accepting connections` is normal.

## Validate

```sql
SELECT pg_is_in_recovery();                         -- t
SELECT now() - pg_last_xact_replay_timestamp();     -- lag
CREATE TABLE t(x int);                              -- must fail
```

## Read-only user

Create it **on the primary**: it arrives through the backup. The replica's `pg_hba.conf` is overwritten on every re-restore, so the read-only user's lines go into the primary's `pg_hba.conf` too, plus a `reject` line so this user can never log in to production:

```
host all bi_reader 0.0.0.0/0 reject
```

Keep the `pg_hba` backup **outside** the data directory: an extra file there breaks pgBackRest.

## Monitoring

A collector writes lag in seconds (`-1` if `psql` fails) and `in_recovery` (1/0) every minute. Triggers: lag above warn/high thresholds, `in_recovery = 0` (it was promoted), `-1` (collector failing), no data for 10 minutes. The item type must be **float** (see [monitoring](../monitoring/README.md)).

## Replay stuck

If `pg_last_wal_replay_lsn()` does not move between two reads and the `startup` process uses almost no CPU while waiting on an LWLock, it can be a bug in that minor release. Check for a newer minor and upgrade before re-restoring. The stuck process ignores SIGTERM: `pg_ctl -m immediate stop`.

## Container variant

- The official image removes `ca-certificates`, and pgBackRest then fails TLS to S3. Build one derived image for primary and replica, and tag every upgrade (never `latest`).
- `postgres` as PID 1 with `archive-async = y` leaves orphan processes: use `init: true`, or async off on the primary.
- On EC2 with no keys on disk: instance role with **IMDSv2 required** (IMDSv1 ignores the hop limit).
