# Nave relay (relay.nave.pub) — restricted strfry

A private nostr relay for the Nave fleet, on its own small VPS. Writes are
restricted to fleet identities (`allowlist.json`); the NIP-46 transport kind
(24133) is open so the bunker's ephemeral client keys get through. This removes
the fleet's dependency on public relays for grants, entitlements, endpoint
adverts, and profiles — and hosts the bunker's signing transport.

See `../../docs/sovereign-signing.md` for the why.

## What's here

| file | role |
|---|---|
| `docker-compose.yml` | strfry + Caddy (auto-TLS) |
| `Dockerfile` | strfry image + python3 for the plugin |
| `strfry.conf` | relay config; points `writePolicy.plugin` at the gate |
| `write-policy.py` | the allow-list gate (strfry write-policy protocol) |
| `allowlist.json` | fleet pubkeys (hex) permitted to write |
| `Caddyfile` | `relay.nave.pub` → strfry:7777 (WSS) |

## Bring-up (on the relay VPS)

Prereqs: Docker + compose, DNS `relay.nave.pub` → this box (done), ports 80/443 open.

```bash
# clone/pull nave.pub, then:
cd deploy/relay
ACME_EMAIL=you@example.com docker compose up -d --build
docker compose logs -f caddy    # watch the cert issue for relay.nave.pub
```

It comes up **immediately** with the 6 fleet keys allowed — the `REPLACE_…`
placeholders in `allowlist.json` are skipped by the plugin, so you don't need the
operator/sovereign keys to start.

## Add the operator + sovereign keys (after minting)

Edit `allowlist.json`, replace the two placeholders with the hex pubkeys, then:

```bash
docker compose up -d --build   # rebuild bakes the new allowlist into the image
# (or, since allowlist.json is bind-mounted read-only, just: docker compose restart strfry)
```

## Verify

```bash
# health / relay info (NIP-11)
curl -s https://relay.nave.pub -H 'Accept: application/nostr+json' | head

# a write from a NON-fleet key should be rejected; a fleet key accepted.
# with `nak` (https://github.com/fiatjaf/nak):
nak event -c 'hello from a fleet key' --sec <a-fleet-nsec> relay.nave.pub   # accepted
nak event -c 'nope' relay.nave.pub                                          # rejected (random key)
```

## Notes

- **Base image:** `dockurr/strfry` (Alpine). The `Dockerfile` installs python3
  via `apk`, with an `apt` fallback if you swap to a Debian-based strfry image.
- **Point the fleet at it:** add `wss://relay.nave.pub` to the relay lists the
  agents publish/read on (and the bunker's relay set) once it's verified — keep
  1–2 public relays alongside so a single relay failing never locks out signing.
- **Retention:** ephemeral/24133 events self-expire (see `events` in `strfry.conf`);
  replaceable events (grants, adverts, profiles) keep only the latest. Disk stays small.
