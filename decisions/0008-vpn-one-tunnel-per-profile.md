# ADR 0008: One VPN tunnel per access profile, access granted by allow-list

- **Status:** Accepted
- **Date:** 2026

## Context

Remote access ran on a single OpenVPN server where everyone reached everything. Infra, developers, sales, management and external consultants needed different access, and logs could not tell who did what.

## Options considered

| Option | Pros | Cons |
|---|---|---|
| One shared tunnel with per-user rules | One interface | Rules get mixed; one mistake opens everything to everyone |
| **One WireGuard tunnel per profile** | Each profile has its own interface and rule tab; peers isolated from each other | More interfaces and ports to manage |

## Decision

On the firewall, one WireGuard tunnel per profile, each with its own port and subnet. Access is granted by an **allow-list alias of /32 addresses** per profile. Broad aliases are used only in block rules.

- Creating a peer alone gives no access: the handshake completes but traffic is dropped until the /32 is in the profile alias.
- A block rule to the whole VPN range sits above the pass rules, so peers never reach each other.
- No outbound NAT for the VPN range toward internal networks, so logs show each person's address.
- Split tunnel only.

## Consequences

- Revoking access is instant: remove the /32 from the alias, then delete the peer (WireGuard has no revocation list).
- Path MTU problems ("ping works, web does not load") were solved with MTU 1380 and MSS clamping 1340 on the tunnel interfaces.
- Peer creation is scripted (keys, PSK, next free IP), and the private key is shown once and never stored.
