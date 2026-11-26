#!/usr/bin/env bash
# Scheduled routines for the ops agent (Claude Code headless + systemd user timer).
#
#   routine create <name> "<when>" "<task>"   create and schedule (task may also come from stdin)
#   routine list                              routines and next run
#   routine show <name>                       task and schedule
#   routine log <name>                        last log
#   routine run <name>                        run now (this is what the timer calls)
#   routine remove <name>                     cancel the timer and delete the routine
#
# <when> is a systemd OnCalendar expression:
#   "2026-11-12 22:00"      once
#   "*-*-* 07:30"           every day
#   "Mon..Fri 08:00"        weekdays
set -euo pipefail

BASE="$HOME/routines"
UNITS="$HOME/.config/systemd/user"
AGENT="${ROUTINE_AGENT:-ops-assistant}"
SELF="$(readlink -f "$0")"

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }
valid_name() {
  [[ "${1:-}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "invalid name: use lowercase, digits and hyphens" >&2; exit 1; }
}
exists() { [[ -d "$BASE/$1" ]] || { echo "routine '$1' does not exist" >&2; exit 1; }; }

cmd="${1:-}"; shift || true
case "$cmd" in
  create)
    name="${1:-}"; when="${2:-}"; task="${3:-}"
    valid_name "$name"
    [[ -n "$when" ]] || usage
    [[ -n "$task" ]] || task="$(cat)"
    [[ -n "$task" ]] || { echo "empty task" >&2; exit 1; }
    systemd-analyze calendar "$when" >/dev/null || { echo "invalid schedule: $when" >&2; exit 1; }
    [[ ! -e "$BASE/$name" ]] || { echo "routine '$name' already exists (remove it first)" >&2; exit 1; }

    mkdir -p "$BASE/$name/logs" "$UNITS"
    printf '%s\n' "$task" > "$BASE/$name/task.md"
    printf '%s\n' "$when" > "$BASE/$name/when"

    cat > "$UNITS/routine-$name.service" <<EOF
[Unit]
Description=Ops agent routine: $name

[Service]
Type=oneshot
ExecStart=$SELF run $name
TimeoutStartSec=2h
EOF
    cat > "$UNITS/routine-$name.timer" <<EOF
[Unit]
Description=Schedule for routine: $name

[Timer]
OnCalendar=$when
Persistent=true

[Install]
WantedBy=timers.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now "routine-$name.timer" >/dev/null
    echo "routine '$name' scheduled. Next run:"
    systemctl --user list-timers "routine-$name.timer" --no-pager | sed -n '2p'
    ;;

  list)
    shopt -s nullglob
    dirs=("$BASE"/*/)
    [[ ${#dirs[@]} -gt 0 ]] || { echo "no routines"; exit 0; }
    for d in "${dirs[@]}"; do
      n="$(basename "$d")"
      next="$(systemctl --user show "routine-$n.timer" -p NextElapseUSecRealtime --value 2>/dev/null || true)"
      last="$(find "$d/logs" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort | tail -1)"
      printf '%-28s when: %-22s next: %-30s last log: %s\n' \
        "$n" "$(cat "$d/when")" "${next:-done / none}" "${last:--}"
    done
    ;;

  show)
    valid_name "${1:-}"; exists "$1"
    echo "when: $(cat "$BASE/$1/when")"; echo "--- task"; cat "$BASE/$1/task.md"
    ;;

  log)
    valid_name "${1:-}"; exists "$1"
    last="$(find "$BASE/$1/logs" -maxdepth 1 -type f -printf '%f\n' | sort | tail -1)"
    [[ -n "$last" ]] || { echo "no runs yet"; exit 0; }
    echo "== $BASE/$1/logs/$last"; cat "$BASE/$1/logs/$last"
    ;;

  run)
    valid_name "${1:-}"; exists "$1"
    log="$BASE/$1/logs/$(date +%Y-%m-%d_%H%M%S).log"
    cd "$HOME"
    prompt="Scheduled run of routine '$1' at $(date '+%Y-%m-%d %H:%M'). Nobody is watching: follow the 'Scheduled run' section of your instructions.

Task:
$(cat "$BASE/$1/task.md")"
    rc=0
    claude -p --agent "$AGENT" "$prompt" > "$log" 2>&1 < /dev/null || rc=$?
    echo "[routine] end $(date '+%Y-%m-%d %H:%M:%S') rc=$rc" >> "$log"
    exit "$rc"
    ;;

  remove)
    valid_name "${1:-}"; exists "$1"
    systemctl --user disable --now "routine-$1.timer" >/dev/null 2>&1 || true
    rm -f "$UNITS/routine-$1.service" "$UNITS/routine-$1.timer"
    systemctl --user daemon-reload
    rm -rf "${BASE:?}/$1"
    echo "routine '$1' removed"
    ;;

  -h|--help|help) usage 0 ;;
  *) usage ;;
esac
