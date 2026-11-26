# Certificate expiry with discovery

Digital certificates for invoice signing expire once a year, one per branch. Forgetting one stops sales at that branch. This check finds every certificate on the host and alerts 90, 30 and 0 days before expiry.

## Agent

```ini
# /etc/zabbix/zabbix_agentd.d/certs.conf
UserParameter=cert.discovery,sudo /usr/local/bin/check_certs.py --discovery
UserParameter=cert.days[*],sudo /usr/local/bin/check_certs.py --days $1
```

The agent cannot read the certificates, so it gets exactly one command through sudo:

```
# visudo -f /etc/sudoers.d/zabbix-certs
zabbix ALL=(root) NOPASSWD: /usr/local/bin/check_certs.py *
```

## Template

| Object | Key | Interval |
|---|---|---|
| Discovery rule | `cert.discovery` | 1h, keep lost resources 7d |
| Item prototype | `cert.days[{#CERT}]` (numeric float, unit `d`) | 6h |
| Trigger prototypes | `< 0` Disaster · `< 30` High · `< 90` Average | |

Test from the server: `zabbix_get -s <host> -k cert.discovery` and `zabbix_get -s <host> -k "cert.days[branch-01]"`.
