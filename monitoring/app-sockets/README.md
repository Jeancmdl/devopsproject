# App discovery over Gunicorn Unix sockets

Each client app on a host runs Gunicorn behind nginx on a Unix socket. New apps appear every week, and nobody remembered to add them to monitoring. With discovery, a new app is monitored within an hour of being deployed.

## Agent

```ini
# /etc/zabbix/zabbix_agentd.d/apps.conf
UserParameter=app.discovery,/usr/local/bin/app-sockets.sh discovery
UserParameter=app.http[*],/usr/local/bin/app-sockets.sh check "$1"
```

[`app-sockets.sh`](app-sockets.sh) finds sockets matching `/srv/apps/*/run/gunicorn.sock` and returns the HTTP status code of a request sent straight to the socket, bypassing nginx. A 200 there and a 502 in the browser points to nginx; no answer points to Gunicorn.

## Template

| Object | Key | Interval |
|---|---|---|
| Discovery rule | `app.discovery` | 1h, keep lost resources 7d |
| Item prototype | `app.http[{#APP}]` | 1m |
| Trigger prototypes | `last() <> 200` High · `nodata(3m) = 1` High | close on their own |

The agent and the scripts are installed by Ansible, so every new server gets them.
