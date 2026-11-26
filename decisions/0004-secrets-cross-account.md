# ADR 0004: Secrets in a separate cloud account, read through a role

- **Status:** Accepted
- **Date:** 2026

## Context

A payment integration needed a private key and passphrase. They were in a config file next to the application. Anyone with access to the app server, or to the repository history, could read them.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| File on the server | Simple | Copied into backups and images; no audit of reads |
| Secrets Manager in the same account | Encrypted, audited | Admins of the app account can read it |
| **Secrets Manager in a security account, read through `sts:AssumeRole`** | App account admins cannot read it; every read is audited in the security account | More IAM to set up; one more call at startup |

## Decision

The secret lives in a dedicated security account. A reader role there trusts only the application's instance role. The secret's resource policy allows `GetSecretValue` only to that reader role. The application assumes the role with the instance profile (IMDSv2, no keys on disk), reads the secret once and caches it in memory.

## Consequences

- No credentials in code, images or config files.
- Negative test is part of the rollout: without `AssumeRole`, the call must fail with `AccessDeniedException`.
- Old runtimes may need a pinned SDK version (the last `boto3` that still supports Python 2.7, for example).
- Next step: keep the key inside KMS so it never leaves the cloud provider.
