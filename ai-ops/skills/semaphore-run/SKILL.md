---
name: semaphore-run
description: Runs Ansible task templates in Semaphore UI through its API - lists templates, runs a dry run with diff, asks for one confirmation, applies and reports the result. Use when asked to provision a server, onboard a client, or run any "Semaphore task".
---

# Run a Semaphore template

The only thing that talks to Semaphore is `${CLAUDE_SKILL_DIR}/semaphore-run.sh`. You collect the
input, confirm and report. Never call the API another way and never edit existing inventories or
templates.

## Talking to the operator

The operator needs to see four things: the **form**, the **pending items** (only if any), the
**summary to confirm** and the **result**. In between, one line per step
(`[2/4] Provision server ... ok`). No logs unless something fails.

## Flow

1. `semaphore-run.sh check` - token, project and templates are reachable. If it fails, show what the
   script printed and stop.
2. Show the form as a code block for the operator to fill in:

   ```
   Client ........: acme
   Server ........: app-01
   Template ......: Onboard client
   ```

3. `semaphore-run.sh templates` to confirm the template exists. Never guess an ID.
4. Dry run: `semaphore-run.sh run "<template>" --dry-run --vars '{"client_name": "acme"}'`.
   Summarize what would change (tasks with `changed`), not the full log.
5. Ask for **one** confirmation with a short table: client, server, template, changes.
6. Apply: `semaphore-run.sh run "<template>" --vars '{...}'`. Warn first if it takes long.
7. Report: final status, the task URL in Semaphore and the list of what is still manual.

## Rules

- One task at a time. Stop at the first error and show it with the next step to fix it.
- Never run a destructive template (disable, remove client) without an explicit request, repeating
  client and server before running.
- Extra vars stay in Semaphore's task history: never put a secret in `--vars`. Passwords are
  generated on the server by the playbook.
