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

### 🟡 Tier 1 — stability / could bite on reboot
- [x] **`harden.sh` on main + warm.contact** (via CI) — fail2ban active,
      auto-updates on, Docker-on-boot confirmed (main), `.env` → 600. Stale
      `openclaw-kajk` container pruned on main.
- [x] **`harden.sh` on the relay/bunker box** — DONE; fail2ban **active**,
      verified 2026-07-21 via `relay-ops` inventory. Loose end: the inventory's
      auto-updates check prints `not-found` on Alma (Debian-ism in
      `inventory.sh`?) — confirm dnf-automatic and make the check Alma-aware.
- [x] **On-box Docker-safe firewall** (`firewall.sh`, called by harden.sh):
      nftables INPUT (allow lo/established/docker-subnet/icmp + 22/80/443, drop
      rest — seals host-bound ports) + DOCKER-USER seal (published ports except
      80/443). Applied on main (DOCKER-USER 3 rules) + warm.contact (`:8484`
      sealed, node still local-reachable). Main sites verified 200 externally.
      **Relay/bunker: SEALED, verified 2026-07-21 ✓** — `inet nave_fw` table
      live on-box; external probe times out on `:8080` **while** `bunker46-web-1`
      is Up and publishing it, so this is a true firewall seal (not the
      container-down false positive that fooled the earlier probe).
- [ ] Provider edge firewall (22/80/443) is still worthwhile as belt-and-
      suspenders, but the on-box firewall is now the primary — no panel required.
- [x] **Reboot survival: main + relay** — Docker enabled on boot, all containers
      `restart: unless-stopped`. warm.contact: Caddy confirmed enabled-on-boot;
      still verify the Node app (`:8484`) is a boot-enabled systemd unit.

### ⬜ Tier 2 — bunker sovereignty
- [x] **Off-box backup of `/root/bunker46/.env`** — VERIFIED 2026-07-21: the
      Director confirmed the Bitwarden note holds the JWT + ENCRYPTION_KEY and
      matches the live file (nave.pub#2 closed; registry custody map agrees). — it holds the `ENCRYPTION_KEY`
      that decrypts the sovereign nsec. Lose the box without it and the key is
      unrecoverable. Copy to the Mac vault; store encrypted.
- [x] **`ALLOW_REGISTRATION=true` → `false`** — DONE 2026-07-21 by the Director
      via nave_mgmt (nave.pub#3); registration closed, compose restarted. The
      NIP-46 re-prove path is the fleet consoles' new bunker sign-in. in the bunker `.env`, then
      `docker compose up -d` — you're registered; close the door so no one else can
      create a bunker account.
- [x] Confirm bunker containers are all `restart: unless-stopped` — verified
      2026-07-21: all six (relay strfry/caddy + bunker46 web/server/db/redis).

### 🟢 Tier 3 — runners / remote hands (DONE — unified fleet ops / proto-Nops)
<!-- This SSH+CI control plane is the INTERIM. Nops proper (nact/docs/nops.md)
is the same shape made nostr-native: ops-runner has its own identity, receives
allowed verbs as a scoped grant, executes on signed approval — no SSH/CI. -->

- [x] **Unified CI ops channels, all 3 boxes.** `fleet-ops.yml` = full channel for
      main + warmcontact (per-box secrets). `relay-ops.yml` = RESTRICTED channel for
      the bunker box: its CI key is forced-command-locked to `ci-ops-allow.sh` (a
      fixed allowlist: status/ps/inventory/bunker-ps/restart-relay/restart-bunker/
      logs) — never a root shell, never reads the `.env`. All three inventoried
      hands-free to prove it.
- [ ] Confirm the relay box's **auto-deploy** still works after the Docker rebuild.
- [ ] Sweep the other workflows (deploy / verify / ops / smoke / brain-cron /
      probe) for anything still assuming firewalld or the old proxy path.

### ⬜ Tier 4 — docs / hygiene
- [x] `ssh-standard.md`, `rekey.sh`, `newbox.sh`, `harden.sh` reflect the real
      (firewalld-free) process.
- [ ] Note the firewalld decision in `nave.pub/docs/sovereign-signing.md`.
- [x] Prune stray keys — **main** already clean (`github-deploy` ×2 + `nave-mgmt`);
      **warm.contact** pruned to `nave-mgmt` + `nave-ci-warm` (old Mac key + two
      expired `dotty_ssh` keys removed). **relay/bunker** DONE — verified
      2026-07-21: exactly `nave-mgmt` + forced-command `nave-ci-relay` remain.

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
