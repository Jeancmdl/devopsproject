# Monitoring patterns (Zabbix)

Patterns I use so that monitoring follows the infrastructure on its own: new apps and certificates are discovered automatically, and security-relevant files are watched without giving the agent root.

| Pattern | Files | Idea |
|---|---|---|
| App discovery over Unix sockets | [`app-sockets/`](app-sockets) | LLD finds every app on the host; one item per app does an HTTP request through the Gunicorn socket |
| Certificate expiry | [`cert-expiry/`](cert-expiry) | LLD finds every certificate; one item per certificate returns days until expiry |
| File integrity | [`file-integrity/`](file-integrity) | A root cron writes hashes of sensitive files; the agent only reads the hash |

## Rules that saved me

- **Numeric items that can return `-1` must be float.** With unsigned integers, `-1` makes the item unsupported, so collection stops exactly when something fails. Changing the type later does not fix it: unlink and relink the template.
- **Alert when the collector stops, not only when the value is bad.** A `diff()` trigger never fires if the cron that writes the hash breaks. Add a `fuzzytime()` / `nodata()` trigger.
- **Security triggers do not close themselves.** File-integrity problems require manual close with a reason, so there is always an audit trail.
- **Discovery keeps lost resources for 7 days.** A removed app or certificate disappears on its own, without manual cleanup.
- After every reboot or change, check `systemctl is-enabled` on the agent **and on the VPN it depends on**. An instance unit like `openvpn-client@x` does not show in `list-unit-files`. A host once went 14 hours unmonitored because of that.
- On SELinux hosts, files read by the agent live in `/var/lib/zabbix/...`, not `/var/tmp`.
