# Nave fleet — ops hardening & runner plan

A living runbook. Born out of the 2026-07-20 incident (firewalld melted Docker on
the relay/bunker box) + the fleet SSH rekey. Check items off as they land. No IPs
or secrets in this file — it's a public repo; keep addresses in your password
manager.

## Guiding decisions (the "why", so we don't relitigate)

1. **One SSH key for the fleet.** A single `nave-mgmt` ed25519 key in the Mac
   Keychain opens every box; passwords off; no per-box keys. Process:
   `deploy/ops/ssh-standard.md` + `rekey.sh` / `newbox.sh`.
2. **No firewalld, ever.** It fights Docker on these hosts (owns the `docker`
   zone, flushes Docker's iptables chains on reload) and caused a full outage.
   Removed, not reconfigured.
3. **The provider edge firewall is the real seal.** Hostinger hPanel /
   DigitalOcean cloud firewall = the only inbound gate: **22 / 80 / 443**. This is
   what keeps Docker-published ports (e.g. the bunker's `:8080`) off the internet.
4. **Sovereign key lives in the bunker,** encrypted (Bunker46). Apps borrow
   signatures over NIP-46; the key never leaves the box.

## Status board

### ✅ Done (2026-07-20)
- [x] Fleet rekeyed to the single `nave-mgmt` key — all 3 boxes, passwords off,
      each proven before locking, CI deploy key preserved on main.
- [x] Main-box CI runner validated post-lock (deploy/verify/ops SSH with the
      `github-deploy` key → unaffected by the password lock).
- [x] Bunker restored & firewalld removed from the relay box (root-caused the
      Docker `INVALID_ZONE` outage).
- [x] First bunker sign-in proven end-to-end (remote app → NIP-46 → signature).
- [x] Hardening scripts made firewalld-free: `harden.sh` (canonical, new),
      `newbox.sh` (rewritten), `deploy/relay/harden.sh` (now a thin wrapper —
      landmine defused).

### ⬜ Tier 1 — stability / could bite on reboot
- [ ] **Run `deploy/ops/harden.sh` on each box** — removes firewalld, installs a
      gentle fail2ban, auto-updates, enables Docker on boot. (relay box: firewalld
      already removed by hand; still run it for fail2ban + updates.)
- [ ] **Confirm the provider edge firewall on all 3 boxes** = 22/80/443 only.
      Especially: the bunker's `:8080` must stay blocked (probe already shows it
      sealed on the relay box — verify main + warm.contact).
- [ ] **Reboot survival check** — every compose service is `restart: unless-stopped`
      and `systemctl is-enabled docker` = enabled, so a reboot brings the whole
      fleet back unattended. (Today, after the daemon crash, nothing auto-started.)

### ⬜ Tier 2 — bunker sovereignty
- [ ] **Off-box backup of `/root/bunker46/.env`** — it holds the `ENCRYPTION_KEY`
      that decrypts the sovereign nsec. Lose the box without it and the key is
      unrecoverable. Copy to the Mac vault; store encrypted.
- [ ] **`ALLOW_REGISTRATION=true` → `false`** in the bunker `.env`, then
      `docker compose up -d` — you're registered; close the door so no one else can
      create a bunker account.
- [ ] Confirm bunker containers are all `restart: unless-stopped` (so a reboot
      brings the signer back).

### ⬜ Tier 3 — runners / remote hands (so an incident never needs an hour of console-paste)
- [ ] **Wire the `relay-ops` CI channel.** Add a *dedicated* CI key to the relay
      box's `authorized_keys` (NOT the mgmt key — that stays on your Mac), put its
      private half in repo secrets `RELAY_SSH_HOST` / `RELAY_SSH_USER` /
      `RELAY_SSH_KEY`. Then `relay-ops.yml` lets the assistant run a command on the
      relay box and read the result — e.g. restart the bunker — without you at the
      console. (The workflow already exists; it just has no secrets.)
- [ ] Confirm the relay box's **auto-deploy** still works after the Docker rebuild.
- [ ] Sweep the other workflows (deploy / verify / ops / smoke / brain-cron /
      probe) for anything still assuming firewalld or the old proxy path.

### ⬜ Tier 4 — docs / hygiene
- [x] `ssh-standard.md`, `rekey.sh`, `newbox.sh`, `harden.sh` reflect the real
      (firewalld-free) process.
- [ ] Note the firewalld decision in `nave.pub/docs/sovereign-signing.md`.
- [ ] Prune stray old keys from each box's `authorized_keys` down to
      `nave-mgmt` (+ the two `github-deploy` keys on main), once the mgmt key is
      trusted everywhere. Do it carefully, re-proving after each removal.

## Standing up a NEW box (the unified path)

1. Create the box. Open the **provider console**.
2. `MGMT_PUB='ssh-ed25519 AAAA...nave-mgmt' sh newbox.sh` (or clone the repo and
   run `deploy/ops/newbox.sh`) — installs the mgmt key + Docker-safe baseline.
3. **Provider edge firewall → 22/80/443 only.**
4. From your Mac: prove `ssh -i ~/.ssh/nave_mgmt root@<ip> 'echo KEY_OK'`.
5. `sh deploy/ops/rekey.sh root@<ip> --lock` — passwords off, key-only.
6. Re-prove from a fresh terminal. The box is now under the one keychain.

## Incident reference — firewalld vs Docker (2026-07-20)

Symptom chain: firewalld corrupted → flushed Docker's iptables chains
(`iptables: No chain/target/match by that name` on `DOCKER-FORWARD`) → Docker
networking broke (bunker 502 / `document.txt`) → Docker daemon wouldn't even boot
(`Error initializing network controller … INVALID_ZONE: docker`). Fix:
`systemctl disable --now firewalld` → `nft flush ruleset` → `systemctl start
docker` → `docker compose down/up` to rebuild the stale networks. Root fix: never
run firewalld on a Docker host; use the edge firewall.
