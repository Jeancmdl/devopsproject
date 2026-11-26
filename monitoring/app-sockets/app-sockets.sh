#!/usr/bin/env bash
# Zabbix helper for apps served by Gunicorn on Unix sockets.
#   app-sockets.sh discovery     LLD JSON with {#APP} for every socket found
#   app-sockets.sh check <app>   HTTP status code through the socket (0 if no answer)
set -euo pipefail

PATTERN="${APP_SOCKET_GLOB:-/srv/apps/*/run/gunicorn.sock}"
PATH_TO_CHECK="${APP_CHECK_PATH:-/}"

app_name() { basename "$(dirname "$(dirname "$1")")"; }

case "${1:-}" in
  discovery)
    first=1
    printf '['
    for sock in $PATTERN; do
      [[ -S "$sock" ]] || continue
      [[ $first -eq 1 ]] || printf ','
      printf '{"{#APP}":"%s"}' "$(app_name "$sock")"
      first=0
    done
    printf ']\n'
    ;;
  check)
    app="${2:?app name}"
    [[ "$app" =~ ^[A-Za-z0-9_-]+$ ]] || { echo 0; exit 0; }
    sock="${PATTERN/\*/$app}"
    [[ -S "$sock" ]] || { echo 0; exit 0; }
    curl -s -o /dev/null -w '%{http_code}' --max-time 10 --unix-socket "$sock" "http://localhost$PATH_TO_CHECK" || echo 0
    ;;
  *)
    sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
