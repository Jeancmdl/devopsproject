# Decisions

Architecture Decision Records: what was decided, what else was on the table and what it cost. Each one is short on purpose.

| # | Decision | Status |
|---|---|---|
| [0001](0001-semaphore-over-awx.md) | Semaphore UI instead of AWX to run Ansible | Accepted |
| [0002](0002-rootless-docker-by-default.md) | Rootless Docker as the default for every service | Accepted |
| [0003](0003-changes-only-through-git.md) | Servers change only through Git and playbooks, never by hand copy | Accepted |
| [0004](0004-secrets-cross-account.md) | Secrets in a separate cloud account, read through a role | Accepted |
| [0005](0005-ai-agents-with-guardrails.md) | AI agents operate infrastructure through reviewed scripts, with dry run and human approval | Accepted |
| [0006](0006-no-connection-pooler.md) | No connection pooler; a connection limit per client instead | Accepted |
| [0007](0007-replica-from-object-storage.md) | Read-only PostgreSQL replica restored from object storage, with no link to the primary | Accepted |
| [0008](0008-vpn-one-tunnel-per-profile.md) | One VPN tunnel per access profile, access granted by allow-list | Accepted |

Template: [template.md](template.md).
