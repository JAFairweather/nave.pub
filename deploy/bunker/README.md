# Bunker (bunker.nave.pub) — Bunker46 NIP-46 remote signer

The remote signer that lets iPhone (and any no-extension browser) sign into the
Nave apps. It holds the **delegated operator key** (never the sovereign),
encrypted at rest (AES-256-GCM), and signs on request over NIP-46. Runs on the
same VPS as the relay. See `../../docs/sovereign-signing.md` for the why.

Upstream: [dsbaars/bunker46](https://github.com/dsbaars/bunker46) — we run its
tested compose with a generated `.env`, behind the relay's Caddy for TLS.

## Prereqs (only you can do these)

1. **DNS:** point `bunker.nave.pub` → this box (`145.79.6.80`).
2. **The operator nsec**, decryptable from your Mac vault when you reach the
   dashboard step (`sops -d … | grep OPERATOR_NSEC`). It is imported once, in the
   browser; it never goes in a file on the box.

## Bring-up (once DNS resolves)

```bash
cd /root/nave.pub && git pull
sh deploy/bunker/setup.sh          # clones bunker46, generates a STABLE .env, compose up
```

The `.env` is generated **once** and never overwritten — the `ENCRYPTION_KEY`
must stay stable or every stored key becomes undecryptable. Back it up:
`cp /root/bunker46/.env /root/bunker46/.env.bak` and keep it safe.

## Expose it via the relay's Caddy

Add this vhost to `deploy/relay/Caddyfile`, then the auto-deploy (or
`docker compose -f deploy/relay/docker-compose.yml up -d`) picks it up. **Only add
it after DNS resolves** — otherwise Caddy burns Let's Encrypt attempts on a name
it can't validate.

```
bunker.nave.pub {
	reverse_proxy host.docker.internal:8080
}
```

(The relay's Caddy service already has `host.docker.internal:host-gateway` mapped,
so it can reach Bunker46's `:8080` on the host. If Bunker46 binds `:8080` to
`127.0.0.1` only, tell me and we'll switch to a shared docker network instead.)

## First-run in the dashboard (from your Mac browser)

1. Open `https://bunker.nave.pub` → **register your admin account** (email +
   password). `ALLOW_REGISTRATION=true` is set for this first account.
2. Add a **passkey / TOTP** (WebAuthn) — this is the 2FA that guards the signer.
3. **Import the operator nsec**: decrypt it on your Mac and paste it into the
   "add key" flow. Bunker46 encrypts it at rest immediately.
   ```bash
   sops -d --input-type dotenv --output-type dotenv ~/Projects/Nave/nave-operator.env.sops | grep OPERATOR_NSEC
   ```
4. **Set the signer's relays** to `wss://relay.nave.pub`, `wss://relay.damus.io`,
   `wss://nos.lol` (own relay + 2 public fallback — no single-relay lockout).
5. **Lock it down:** set `ALLOW_REGISTRATION=false` in `/root/bunker46/.env` and
   `docker compose -f /root/bunker46/docker-compose.yml up -d` so no one else can
   sign up.

## Connect the iPhone

Create a **connection** (a `bunker://` string / QR) in the dashboard, scoped to
the event kinds the Nave apps need (login challenges + app kinds — not "sign
anything"). In `nave-connect` (the app side, #56) you'll paste/scan that to pair;
from then on the phone signs every NIP-98 challenge through the bunker, key never
in Safari.

## Notes

- **Scope the signer**, don't grant blanket signing: per-connection kind limits +
  the approval prompt for anything sensitive.
- **Backups:** the encrypted key store (Postgres volume) + `.env`. Losing the
  `.env` (its `ENCRYPTION_KEY`) means re-importing the operator nsec from your Mac
  — recoverable, since the Mac vault is the source of truth.
