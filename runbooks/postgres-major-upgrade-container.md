# PostgreSQL major upgrade into a container

Used to move store databases from PostgreSQL 9.2 to 18 on hosts whose OS (Amazon Linux 1, no systemd) cannot install PostgreSQL 18 natively. Running it in a container solved the OS limit without migrating the whole server.

## Build the image

- `postgres:18` (Debian trixie) **died without any log** on Docker 20.10 with kernel 4.14. `postgres:18-bookworm` works.
- The databases use LATIN1, so the locale must exist in the image:

  ```bash
  docker run --name pg18-build --security-opt seccomp=unconfined postgres:18-bookworm \
    localedef -i en_US -c -f ISO-8859-1 -A /usr/share/locale/locale.alias en_US.ISO-8859-1
  docker commit -c 'ENV LANG=en_US.iso88591' -c 'CMD ["postgres"]' pg18-build pg18-latin1
  ```

  **Without `-c 'CMD ["postgres"]'`** the image keeps `localedef` as its command: the container exits 0 with an empty log and enters a restart loop.
- Old Docker + old kernel need `seccomp=unconfined` or `initdb` gets `EPERM`.

## Storage

- Data on a dedicated disk mounted by UUID with `nofail`.
- Mount it with `--mount type=bind`, **never `-v`**. If the disk is missing, `--mount` refuses to start. `-v` silently creates an empty "ghost" cluster and the app starts writing to it.
- Config files (`postgresql.conf`, `pg_hba.conf`) bind-mounted from a folder next to the compose file. Edit them there. `sed -i` replaces the inode and the container keeps reading the old file, so recreate the container after it (`up -d --force-recreate`).

## Migrate

1. Dump with the **old** binaries: `pg_dump <db> | gzip > db.sql.gz`.
2. Start the new container on a temporary port (5433).
3. `CREATE DATABASE <db> ENCODING 'LATIN1' LC_COLLATE 'en_US.iso88591' LC_CTYPE 'en_US.iso88591' TEMPLATE template0;`
4. Restore through a pipe, in the background: `gunzip -c db.sql.gz | docker exec -i pg18 psql <db>`. Drop obsolete roles and use `--no-owner` instead of recreating them.
5. Validate: table count source = destination; row counts of the main tables.
6. `vacuumdb -z` (a dump carries no statistics; without it the first days are slow).
7. Switch the port, stop the old service, keep the old binaries installed to read old dumps.

## After

- `show timezone` must return the local zone. A config copied from the image comes with `timezone = 'Etc/UTC'`, which wins over `/etc/localtime`.
- The app connecting to `127.0.0.1` is seen by PostgreSQL as the **bridge gateway**. Clients coming over the VPC are seen with their real IP. Both need a `pg_hba` line.
- Add a `pg_hba` line without downtime: back up the file, append with `>>` (keeps the inode), `SELECT pg_reload_conf();`, and check that `pg_hba_file_rules WHERE error IS NOT NULL` returns nothing.
- Backup scripts must detect the container and use `docker exec pg_dump`.
