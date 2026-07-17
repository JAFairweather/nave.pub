# OpenClaw cutover — Hostinger-managed → self-hosted on the nave network

Move Luke's cockpit runtime off the Hostinger-managed container (which publishes
`:57419` to the internet, protected only by a shared gateway token) onto our own
compose stack: **on the nave network, no published port, gateway-direct in
trusted-proxy mode** behind Caddy's nostr-signed gate.

Everything below the cutover line is **staged and inert** — a normal deploy never
starts the new instance (it's behind the `cutover` compose profile), and the
config patch only touches the box-local **copy**, never the live instance.

## What's already proven (safe, non-destructive)
- The migrated state copy lives at `deploy/openclaw-state/.openclaw` (~97M),
  refreshed from the live instance by `ops/oc-resync-boot.sh`.
- The **Hostinger image** `ghcr.io/hostinger/hvps-openclaw:latest` (2026.6.9 —
  same version as Luke's state) boots that state **gateway-direct** to a ready
  gateway: `running=true exit=0`, `http server listening (11 plugins…)`.
  (The upstream vanilla image failed: memory-index conflict + missing plugins.)
- All active plugins are **stock** (in the image). No external plugins are
  installed on the live instance, so there is **no functionality to lose**. The
  `nostr`/`codex`/`signal` config entries are pre-existing declared-but-not-
  installed leftovers (present on the live instance too).

## Prerequisites (do once, before cutover)
1. **`deploy/openclaw.env`** (box-local, gitignored) — the new service's env:
   ```
   ANTHROPIC_API_KEY=…      # the agent's model key (same one the live instance uses)
   TZ=America/New_York
   ```
   No `OPENCLAW_GATEWAY_TOKEN` — trusted-proxy mode doesn't use one.
2. Confirm the operator identity Caddy will assert is **`jaf@dequalsf.com`**
   (already wired in the Caddyfile luke block and the config patch).

## Cutover (with the user — involves hPanel actions only they can do)
1. **Retire the old instance in hPanel.** Stop `openclaw-kajk-openclaw-1` and
   remove its `0.0.0.0:57419` port publish. This closes the internet-exposed
   admin surface. (Keep its data dir until the new instance is confirmed.)
2. **Refresh a clean state copy** (old instance stopped = consistent snapshot):
   `ops/run-script oc-resync-boot.sh` → expect `running=true exit=0`.
3. **Patch the config** for trusted-proxy + channels + hardened flags:
   `ops/run-script oc-config-patch.sh`. Review the printed summary.
   - Leaves `channels.telegram.enabled=false` (staged). Flip to `true` in this
     step's follow-up ONLY when you want the new instance to own Telegram —
     exactly one instance may connect the bot at a time.
4. **Verify the bind value.** `--bind all` / `gateway.bind="all"` must bind
   0.0.0.0 inside the container so Caddy can reach it. If the boot rejects the
   value, adjust to the accepted mode (`lan`/`loopback`) and re-test.
5. **Bring up the new service** (only after the old one is down):
   `docker compose --profile cutover up -d openclaw`
   Check: `docker logs deploy-openclaw-1` → `http server listening`.
6. **Repoint Caddy** `luke.nave.pub/cockpit*` from `host.docker.internal:57419`
   to `openclaw:57419` (same nave network), then reload Caddy:
   ```
   # Caddyfile luke block:  reverse_proxy openclaw:57419 { header_up X-Forwarded-User jaf@dequalsf.com }
   ops/reload-caddy
   ```
7. **Prove the gate.** Visit `https://luke.nave.pub/cockpit`, sign with your
   master npub (Alby/NIP-07). The gate passes → Caddy forwards with
   `X-Forwarded-User: jaf@dequalsf.com` → OpenClaw authorizes without a token.
8. **Turn Telegram on** for the new instance (set `channels.telegram.enabled=true`,
   restart) once you've confirmed the cockpit and that the old instance is down.

## Rollback
Any step fails → bring the old instance back up in hPanel (its data dir is
untouched) and leave Caddy pointing at `host.docker.internal:57419`. The new
service is behind the `cutover` profile, so it stops with
`docker compose --profile cutover down openclaw` and never auto-starts.

## Security note
The migration also clears three break-glass flags the boot warns about
(`controlUi.allowInsecureAuth`, `dangerouslyAllowHostHeaderOriginFallback`,
`dangerouslyDisableDeviceAuth`). Caddy's nostr gate + trusted-proxy are the
replacement controls. If the cockpit misbehaves after cutover, re-enable them
one at a time via the config and re-audit with `openclaw security audit`.

## Upgrade playbook (learned 2026-07-17, 2026.6.9 → upstream 2026.7.1)

The service now runs the UPSTREAM image, version-pinned in compose
(`ghcr.io/openclaw/openclaw:<version>-browser`). Upgrades are deliberate: bump
the tag, read the changelog first, then follow this order — it turns a
migration fight into a routine.

1. **Pre-flight** (Ops → custom): `docker pull` the new tag and inspect its
   entrypoint/user; run `ops/brain-backup.sh`; `chown -R 1000:1000
   openclaw-state/.openclaw` (upstream runs as `node`, uid 1000).
2. **Push the tag bump** → auto-deploy recreates the service.
3. **If it crash-loops on migrations** (the engine refuses ready until they
   complete cleanly), work the errors in order, ALWAYS stop-first so the loop
   can't fight you for the migration lock:
   - `docker compose stop openclaw` before every repair attempt.
   - Memory-index conflict ("legacy memory meta rows conflict"): move
     `openclaw-state/.openclaw/memory/main.sqlite` aside — it is a rebuildable
     search index, NOT the memory itself (that's the workspace markdown).
     Rebuild later with `openclaw memory index --force`.
   - Plugin payload missing ("post-core payload smoke check"): run
     `docker compose run --rm --no-deps -T -e npm_config_cache=/tmp/npm-cache
     openclaw node openclaw.mjs update repair` — the cache override matters
     (`/data/.npm` is root-owned and uid 1000 can't create it).
   - A stale migration lock names its own expiry time; wait it out or ensure
     nothing else is starting.
4. **Verify**: health + nave-net reachability, `ops/oc-skin-regression.sh`
   (fix any drifted selectors in luke-skin.mjs — 7.1 removed
   `sidebar-brand__eyebrow`, for instance), `openclaw security audit`
   (expect only the known trusted-proxy findings), and a Telegram smoke test.

Total cost when it goes wrong: ~21 min downtime (2026-07-17). When it goes
right: minutes.
