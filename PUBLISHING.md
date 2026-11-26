# Publishing rules

This repository is public. It exists to share knowledge, not to document a real environment.

## Never commit

- Real IP addresses, public or private. Use the documentation ranges: `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` (RFC 5737) and `2001:db8::/32`.
- Real hostnames, domains, cloud account IDs, instance IDs, bucket names or ARNs. Use `example.com`, `app-01`, `db-01`, `123456789012`.
- Company, customer, store or people names. Use `acme`, `client-a`, `operator`.
- Usernames from real servers, SSH keys (even public ones), tokens, passwords, password hashes, webhook URLs.
- Screenshots or logs copied from production without review.
- Internal ticket numbers, chat messages or anything a customer wrote.

## Before each commit

1. Read the diff line by line: `git diff --staged`.
2. Run the scanner locally: `gitleaks protect --staged --redact --config .gitleaks.toml` (add your own private rules in a config kept outside the repository).
3. Ask: "could someone find or attack a real system with this?" If yes, generalize it or leave it out.

## When in doubt

Describe the pattern, not the instance. "A read-only replica restored from S3" is useful. The bucket name is not.
