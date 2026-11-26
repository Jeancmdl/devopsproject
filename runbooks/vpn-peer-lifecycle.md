# VPN peer lifecycle (WireGuard on pfSense)

Design and trade-offs: [ADR 0008](../decisions/0008-vpn-one-tunnel-per-profile.md). About 10 minutes per person.

## Create

1. **Name:** first name, lowercase, no accents. On a collision in any profile, add the initial of the last name. The peer description and the file name must match.
2. **Generate:** a script on the firewall finds the tunnel by port, picks the next free IP (`.11` onward; `.2`–`.10` reserved), creates keys and PSK, and prints three blocks: peer fields, alias entry, client `.conf`. It does not write the firewall config. **The private key is shown once:** copy the `.conf` before closing.
3. **Add the peer:** right tunnel, dynamic endpoint, keepalive 25, public key and PSK, Allowed IPs = the **/32** (the GUI defaults to /128; change it).
4. **Grant access:** add the /32 to the profile's allow-list alias. **This is the step that gives access.** No new rule is needed.

## Deliver

- Through a channel with no permanent copy (in person or a password manager), never email or group chat.
- Windows/macOS/phone: import the file in the WireGuard app. Linux: `nmcli connection import type wireguard file <name>.conf`. Do not configure field by field: that is where `/24` and empty AllowedIPs errors come from.

## Validate

- Firewall status: latest handshake and traffic both ways.
- Ping the firewall's LAN address and open an internal web page. The page load is what catches MTU problems.
- Do not ping the tunnel address `.1`: it is not in the client's AllowedIPs, so it fails by design.
- Delete temporary files and ask the person to delete their copy of the `.conf`. A lost file means a new peer, and the old one gets deleted.

## Revoke (in this order)

1. Remove the /32 from the alias and apply. Access stops immediately.
2. Delete the peer and apply. Without this it can still handshake: WireGuard has no revocation list.
3. Record who, when and why, and download a fresh config backup.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Handshake never happens | Wrong port for the profile, or WAN rule missing |
| Handshake ok, nothing works | /32 missing from the profile alias |
| Handshake ok, no traffic | Allowed IPs left as /128 |
| Ping works, web pages do not load | Path MTU: MTU 1380 / MSS 1340 on the tunnel interface |
| Everything correct, still unreachable | Another VPN client is taking the route: `ip route get <firewall LAN IP>` |
| Two peers drop alternately | Same IP on two peers |
| A peer reaches another peer | The block rule to the VPN range is below the pass rules |

## Server-side gotcha

`wg syncconf wg0 <(wg-quick strip wg0)` wipes the interface's private key when the key is loaded from a separate file in `PostUp` instead of the `.conf`. Every peer drops. Inject the key through the pipe only:

```bash
wg syncconf wg0 <(wg-quick strip wg0 | sed "/^\[Interface\]/a PrivateKey = $(cat /etc/wireguard/wg0.key)")
wg show wg0 public-key   # compare before and after
```
