# Architecture

```mermaid
flowchart TB
  subgraph GitLab
    repo[ansible-infra repo]
    ci[CI: ansible-lint, yamllint, gitleaks]
    repo --> ci
  end

  subgraph "Semaphore host (rootless containers)"
    nginx[NGINX TLS reverse proxy] --> sem[Semaphore UI :3000 localhost]
    sem --> pg[(PostgreSQL 18, SCRAM-SHA-256)]
  end

  ai[AI skill / engineer] -->|REST API: bootstrap.py| sem
  sem -->|git clone| repo
  sem -->|SSH + become| fleet[RHEL / AlmaLinux / Rocky servers]
```

## Guardrails

1. **Dry run first:** every playbook has a `--check --diff` template, and that runs before the apply.
2. **Secrets stay in Semaphore's key store.** They are encrypted with `SEMAPHORE_ACCESS_KEY_ENCRYPTION` and never written to Git or passed to AI prompts.
3. **Semaphore binds to localhost.** Only the TLS reverse proxy is exposed.
4. **The containers run rootless** with `no-new-privileges`.
