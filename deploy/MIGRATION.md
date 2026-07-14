# The platform flip — move the deploy from noir to nave.pub

The whole stack currently runs from `/root/noir/deploy` on the box. This
moves it to `/root/nave.pub/deploy` — its proper home — with **no change to
what visitors see**. Both dirs share the compose project name `deploy`, so
the `deploy_caddy_data` volume (your Let's Encrypt certs) is the SAME volume
either way — **certs carry over**, no re-issuance.

Do this at a keyboard, unhurried, watching each step. It's a ~2-minute flip
with seconds of downtime while Caddy hands over ports 80/443.

## Prereqs (do these first)
1. **`secrets.enc.env` must be committed to the `luke` repo.** The flip does
   a FRESH clone of every repo, so Luke's encrypted secrets have to be in git
   (they're ciphertext — safe). From the current box copy:
   ```bash
   cd /root/noir/deploy/sites/luke
   git add secrets.enc.env && git commit -m "Commit encrypted secrets" && git push
   ```
   (If the box lacks push auth, commit it from your laptop, or copy the file
   into the new clone after step 3.)
2. **age key + sops already on the box** — yes (you set these up). The new
   `sites.sh` decrypts `sites/luke/secrets.enc.env` → `./luke.env`.
3. **Merge `platform-move` → `main`** on the nave.pub repo, so `deploy/` is on
   main. (Open the PR, or merge locally and push.)

## The flip (on the box)
```bash
# 1. Clone the hub repo to its ops home
git clone https://github.com/JAFairweather/nave.pub /root/nave.pub
cd /root/nave.pub/deploy

# 2. Bring over the Director's secrets (.env — ANTHROPIC_API_KEY, director
#    nsec, ACME_EMAIL). Same file, new home.
cp /root/noir/deploy/.env .env

# 3. Sync every repo + decrypt Luke's env
bash sites.sh                       # clones nave, noir, apps, luke; writes luke.env

# 4. Validate the Caddyfile BEFORE touching the running stack
docker run --rm -e ACME_EMAIL=deploy@nave.pub \
  -v "$PWD/Caddyfile":/etc/caddy/Caddyfile:ro \
  caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile

# 5. Stop the OLD stack (keeps volumes → certs survive). Ports free up.
cd /root/noir/deploy && docker compose down          # NO -v — keep the certs

# 6. Start the NEW stack from its new home
cd /root/nave.pub/deploy && docker compose up -d --build
docker compose ps
```

## Verify
- `https://nave.pub`, `https://noir.nave.pub`, an app subdomain, `https://luke.nave.pub/health`
- `https://nave.pub/.well-known/nostr.json` (NIP-05) and an avatar
  (`https://nave.pub/assets/avatars/nave.png`)
- Certs should NOT re-issue (they're in the shared volume). If a name briefly
  serves a staging/self-signed cert, give Caddy a minute.

## Last step — repoint the deploy button
Edit `.github/workflows/deploy.yml` on the nave.pub repo: change
`cd /root/noir` → `cd /root/nave.pub`. Commit. From now on the deploy button
drives the new home. (Do this AFTER the flip verifies, so a mid-flip auto-run
can't fight you.)

## Rollback
If anything's wrong, the old tree is untouched:
```bash
cd /root/nave.pub/deploy && docker compose down
cd /root/noir/deploy && docker compose up -d
```
Certs are shared, so the rollback is clean too.

## After it's proven
Once the new home is happy for a day, `/root/noir/deploy/` is dead weight —
you can delete the old compose/Caddy files there (keep the noir repo itself;
its Dockerfile still builds the Director from `sites/noir`).
