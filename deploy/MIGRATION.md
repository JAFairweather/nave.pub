# Platform move — flipping the box to `nave.pub/deploy`

The deploy stack (Caddy + Director + Luke + static serving) is moving out of
`noir/deploy` into here, `nave.pub/deploy`. This is a **one-time, watched
migration** — do it at a keyboard, not a phone. Nothing on `main` changes the
running box until you do these steps.

**Good news on certs:** both the old (`/root/noir/deploy`) and new
(`/root/nave.pub/deploy`) stacks use the same Docker Compose project name
(`deploy`) and the same named volume, so **your Let's Encrypt certs carry
over** — no re-issuance, no rate-limit risk.

## 0. Merge the branch

Merge `platform-move` → `main` on this repo (I can do it, or via GitHub), so
`sites.sh` / `docker-compose.yml` / `Caddyfile` are on `main`. Then, on the box:

## 1. Clone the platform repo to its ops home

```bash
git clone https://github.com/JAFairweather/nave.pub /root/nave.pub
cd /root/nave.pub/deploy
```

## 2. Bring the secrets over

The `.env` files stay on the box only (gitignored). Copy them from the old
location:

```bash
cp /root/noir/deploy/.env  /root/nave.pub/deploy/.env       # director + ACME email
cp /root/noir/luke/.env    /root/nave.pub/deploy/luke.env   # Luke's key + master npub
```

## 3. Sync the app/service repos, then validate the Caddyfile

```bash
bash sites.sh
docker run --rm -e ACME_EMAIL=deploy@nave.pub \
  -v "$PWD/Caddyfile":/etc/caddy/Caddyfile:ro \
  caddy:2-alpine caddy validate --config /etc/caddy/Caddyfile
```

Only proceed if that prints **`Valid configuration`**.

## 4. Flip

```bash
docker compose up -d --build
```

Because the project name is `deploy` in both locations, this **recreates the
same containers** with the new config and reuses the cert volume. (If ports
80/443 look stuck, stop the old stack explicitly first:
`docker compose -f /root/noir/deploy/docker-compose.yml down`, then re-run the
`up` above.)

## 5. Verify

```bash
curl -s https://director.nave.pub/health | head -c 200; echo
```
Then load `https://nave.pub`, `https://noir.nave.pub`, an app subdomain, and
`https://luke.nave.pub`. All should be green.

## 6. The deploy button

Add the three secrets to **this repo** (`nave.pub`) → Settings → Secrets →
Actions: `VPS_HOST` = `187.77.13.232`, `VPS_USER` = `root`, `VPS_SSH_KEY` =
your deploy key. From then on, **Actions → Deploy the Nave → Run workflow**
does everything above in one tap.

## 7. Cleanup (after it's confirmed green)

`noir/deploy` still holds the Director's build recipe (`Dockerfile`), which
the platform builds from `sites/noir/deploy/Dockerfile` — **keep that**. The
rest of `noir/deploy` (Caddyfile, docker-compose.yml, sites.sh, DEPLOY.md,
recon.sh, .env.example) is now dead weight; a follow-up commit removes it,
leaving `noir` as just the game (plus its one Dockerfile). Don't remove it
until step 5 is green.
