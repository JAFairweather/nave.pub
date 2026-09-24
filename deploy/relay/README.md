# Nave relay (relay.nave.pub) — restricted strfry

A private nostr relay for the Nave fleet, on its own small VPS. Writes are
restricted to fleet identities (`allowlist.json`); NIP-59 gift wraps (1059)
are admitted **by recipient** — accepted only when a `p` tag names a fleet
key, because wraps are authored by single-use ephemeral keys by design
(nave.pub#37 — this is what lets the grant plane ride this relay: draft
grants, steering grants, credential grants). A wrap addressed to a stranger is
still rejected. This removes the fleet's dependency on public relays for
grants, entitlements, endpoint adverts, and profiles.

**Reads are not authenticated.** strfry doesn't speak NIP-42 and there is no
read gate configured — anyone with a websocket can pull the whole store. The
NIP-11 `description` says so. Content is encrypted/hash-scoped by design
(nave.pub#130), but don't assume more privacy than that buys you.

**The NIP-46 transport lives on a separate relay, transport.nave.pub** (see
`../../deploy/relay/SPLIT_RUNBOOK.md`), not here — it used to be an open
24133 carve-out on this relay, which was both an anonymous write channel and
a metadata firehose for the bunker's signer round-trips (nave.pub#130). If
you're looking at a box that predates the split, that carve-out and
`../../docs/sovereign-signing.md`'s original NIP-46 gotcha section describe
the old, colocated state.

Tests: `python3 write-policy.test.py` (offline; drives the plugin over the
exact strfry line protocol). Transport relay tests:
`python3 write-policy-transport.test.py`.

See `../../docs/sovereign-signing.md` for the why.

## What's here

| file | role |
|---|---|
| `docker-compose.yml` | strfry + strfry-transport + Caddy (auto-TLS) |
| `Dockerfile` | strfry image + python3, both write-policy plugins baked in |
| `strfry.conf` | relay.nave.pub config; points `writePolicy.plugin` at the gate |
| `write-policy.py` | relay.nave.pub's allow-list gate (strfry write-policy protocol) |
| `allowlist.json` | fleet pubkeys (hex) permitted to write; `allowKinds` also gates the (now normally empty, post-split) 24133 carve-out |
| `strfry-transport.conf` | transport.nave.pub config (nave.pub#130 split) |
| `write-policy-transport.py` | transport.nave.pub's gate — 24133 only, rate-limited, no allow-list |
| `Caddyfile` | `relay.nave.pub` → strfry:7777, `transport.nave.pub` → strfry-transport:7777 |
| `split-0*.sh`, `SPLIT_RUNBOOK.md` | the one-time migration from colocated to split (nave.pub#130) |

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
  agents publish/read on once it's verified — keep 1–2 public relays alongside
  so a single relay failing never locks out signing. The bunker's own relay
  set points at `wss://transport.nave.pub` instead (see `SPLIT_RUNBOOK.md`).
- **Retention:** ephemeral events self-expire (see `events` in `strfry.conf`);
  replaceable events (grants, adverts, profiles) keep only the latest. Disk stays small.
