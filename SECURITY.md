# Security Policy

## Do not publish secrets

Never commit:

```text
private SSH keys
real Tailscale IPs
real server names
real client names
real logs
credentials
tokens
backups
```

Use `.example` files with placeholders.

## If a secret is committed

Treat it as compromised.

Rotate the secret and clean repository history before making the repository public.
