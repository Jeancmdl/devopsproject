# File integrity without giving the agent root

Goal: be alerted when `/etc/shadow` or an `authorized_keys` file changes on any server. The Zabbix agent must not be able to read those files.

## How

1. A root cron (installed by Ansible) writes only the **hash** of each file to a file the agent can read:

   ```cron
   # /etc/cron.d/integrity-hashes
   * * * * * root sha256sum /etc/shadow | cut -d' ' -f1 > /var/lib/zabbix/integrity/shadow
   * * * * * root sha256sum /root/.ssh/authorized_keys | cut -d' ' -f1 > /var/lib/zabbix/integrity/authorized_root
   ```

   Directory `/var/lib/zabbix/integrity` owned by `root:zabbix`, mode `0750`. Files `0640`.

2. The template watches the hash and the age of each file:

   | Item | Trigger | Severity | Closes |
   |---|---|---|---|
   | `vfs.file.cksum[/var/lib/zabbix/integrity/shadow]` (2m) | `diff() = 1` | High | Manually, with a reason |
   | `vfs.file.time[/var/lib/zabbix/integrity/shadow,modify]` (2m) | `fuzzytime(600) = 0` ("hash monitor stopped") | Average | On its own |

## Why both triggers

The `diff()` trigger catches a change. But if the cron breaks, the hash file freezes and `diff()` stays silent forever. The age trigger catches that.

## Response

Open the problem, check on the host what changed (`passwd -S <user>`, the `authorized_keys` content, `last`, `journalctl`), then acknowledge and close with the reason. A planned password rotation also fires it, and that is expected: the close message records it.

**Known gap:** a host where the hash file does not exist leaves the item unsupported and raises nothing. Check unsupported items regularly.
