#!/usr/bin/env bash
# Run Semaphore UI task templates through the REST API.
#
#   semaphore-run.sh check                              token, project and API reachable
#   semaphore-run.sh templates                          list templates (id and name)
#   semaphore-run.sh run "<template>" [--dry-run] [--vars '<json>']
#                                                       run a template, wait and print the result
#
# Configuration (environment or ~/.config/semaphore-run.env):
#   SEMAPHORE_URL       e.g. https://semaphore.example.com
#   SEMAPHORE_TOKEN     API token (User -> API tokens)
#   SEMAPHORE_PROJECT   project ID
set -euo pipefail

conf="${SEMAPHORE_RUN_ENV:-$HOME/.config/semaphore-run.env}"
# shellcheck disable=SC1090
[[ -f "$conf" ]] && source "$conf"
: "${SEMAPHORE_URL:?set SEMAPHORE_URL}" "${SEMAPHORE_TOKEN:?set SEMAPHORE_TOKEN}" "${SEMAPHORE_PROJECT:?set SEMAPHORE_PROJECT}"
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

api() { # api <method> <path> [json]
  local args=(-sS --fail-with-body -X "$1" -H "Authorization: Bearer $SEMAPHORE_TOKEN"
              -H "Content-Type: application/json" "$SEMAPHORE_URL/api$2")
  [[ $# -ge 3 ]] && args+=(--data "$3")
  curl "${args[@]}"
}
base="/project/$SEMAPHORE_PROJECT"

template_id() {
  api GET "$base/templates" | jq -r --arg n "$1" '[.[] | select(.name == $n)] | if length == 1 then .[0].id else empty end'
}

cmd="${1:-}"; shift || true
case "$cmd" in
  check)
    api GET "$base" | jq -r '"OK project: \(.name)"'
    ;;

  templates)
    api GET "$base/templates" | jq -r '.[] | "\(.id)\t\(.name)"'
    ;;

  run)
    name="${1:?template name}"; shift
    dry=false; vars='{}'
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --dry-run) dry=true; shift ;;
        --vars) vars="$2"; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 1 ;;
      esac
    done
    jq -e . >/dev/null <<<"$vars" || { echo "--vars must be valid JSON" >&2; exit 1; }
    tid="$(template_id "$name")"
    [[ -n "$tid" ]] || { echo "template not found (or not unique): $name" >&2; exit 1; }

    body="$(jq -n --argjson t "$tid" --arg env "$vars" --argjson dry "$dry" \
      '{template_id: $t, environment: $env, dry_run: $dry, diff: $dry}')"
    task="$(api POST "$base/tasks" "$body" | jq -r .id)"
    echo "task $task started ($([[ $dry == true ]] && echo 'dry run' || echo apply)): $SEMAPHORE_URL/project/$SEMAPHORE_PROJECT/history?t=$task"

    status=waiting
    while [[ "$status" =~ ^(waiting|starting|running|stopping)$ ]]; do
      sleep 5
      status="$(api GET "$base/tasks/$task" | jq -r .status)"
    done

    # Short summary: the PLAY RECAP and any failed task.
    api GET "$base/tasks/$task/output" | jq -r '.[].output' \
      | grep -E 'PLAY RECAP|ok=|fatal:|FAILED!|changed:' | tail -40 || true
    echo "status: $status"
    [[ "$status" == success ]]
    ;;

  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
