# Alert format

Every message from a routine or alert starts the same way, so the reader knows in one glance whether to act. The details come after and stay complete.

```
*<Routine name>* DD/MM HH:MM
*Overall:* <signal> <one sentence>

<details, in the format the task defines>
```

- **Signal:** 🟢 nothing to do · 🟡 keep an eye on it, not urgent · 🔴 act today. The worst item in the message sets it. Each routine defines what is red and what is yellow.
- **One sentence, up to about 160 characters:** first the overall state, then what to do first.
  - "🟡 Nothing new; 3 issues still open since 11/13, the most urgent is the NF-e server disk at 81%."
  - "🟢 All 9 servers normal, nothing to do."
- Whoever reads only that line must know whether to act and where to start. Do not repeat the title, do not list everything, do not write "here is the report".
- If the routine fails: "*Overall:* 🔴 The routine did not finish: <what stopped it and at which step>."

## Example routine

```bash
routine create disk-check "Mon..Fri 07:30" "$(cat <<'EOF'
Check disk usage on every host in group 'app' of the Ansible inventory (read only: df -h, du on /var/lib/docker and the backup folder).
Red: any filesystem >= 90% or a backup folder older than 26h. Yellow: >= 80%.
Send the result to the team chat in the alert format, one line per host that is not green.
If a host does not answer over SSH, report it as red and continue with the others.
EOF
)"
```
