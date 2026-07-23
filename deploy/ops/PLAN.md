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

### 🟡 Addendum 2026-07-23 — channel + serving learnings (the voice sessions)

- [x] **nact vhost cache guard** (nave.pub#51) — `nact.nave.pub` had NO
      Cache-Control (it can't `import app nact`; needs its own handle blocks for
      `/api`), so browsers held stale pages "after" green deploys, twice.
      Guard added inline + module URLs versioned app-side (nact#29). **Rule:
      any vhost that can't use the `(app)` snippet must carry the guard
      inline — check this on every new special-cased vhost.**
- [x] **Brain workflow mounts complete** (nave.pub#50) — `luke-brain.yml`
      mounts the brain's source over the image; its imports (`voices.mjs`,
      `post-format.mjs`) are now mounted too, so a between-deploys run can't
      pair new code with stale modules.
- [ ] **Runner→main-box SSH flakiness** — intermittent dial timeouts while the
      box is provably healthy; the action's single retry usually covers it.
      If it recurs at higher frequency, consider a self-hosted runner or
      moving ops dispatch to the Nops grant path (the real fix).
- [ ] **nave.pub#37 — the relay write-allowlist rejects NIP-59 gift wraps**
      (ephemeral authors). The grant plane — Ngage drafts, steering grants,
      credential grants — rides public relays only until this lands. Ranked
      ahead of new feature work (INVENTORY §5 frontier).

## The sequenced roadmap (2026-07-23) — what's next, in order, with reasons

*The fleet backlog (~63 open issues across the repos) sequenced into phases.
The organizing rule: **close the gaps under what's already live before adding
anything new** — the thesis is trust, and every place where the system's claims
exceed its implementation is thesis debt. Skeleton in `docs/INVENTORY.md` §5;
this is the ordering. Check items off as they land; every item is
issue-bookended (issues-first, Director 2026-07-23).*

### Phase 1 — Trust debt (all small; do first) — ✅ COMPLETE 2026-07-23
- [x] **nave.pub#37 — relay accepts the grant plane.** Recipient-based
      admission: kind 1059 accepted when a `p` tag names a fleet key (the
      narrow option). Deployed to the relay box; live-verified (fleet wrap
      accepted, stranger rejected, plain kind-1 still rejected, read-back
      holds). 15 offline tests. PR #54.
- [x] **nact#7 — hardening P1.** The fingerprint is now re-verified BEFORE the
      signer sees the bytes (a bunker signing tampered bytes leaves a real
      signature in the world even if broadcast is refused). `created_at` freeze
      pinned by test; tamper test proves the signer is never invoked. 5 tests.
      nact PR #30, deployed.
- [x] **nvoy#9 — console bug.** Root-caused to both theorized mechanisms:
      un-paginated inbox query vs relay newest-N caps (a back-fuzzed fresh
      wrap fell off the window) → paginate with `until`; and silent bulk-
      decrypt failures → counted and surfaced ("N wraps could not be opened").
      4 tests incl. the exact burial repro. nvoy PR #16.
- [x] **warm.contact#23 — verify the Apple id_token.** Full JWKS verify
      (RS256 signature, iss, aud, exp; rejects alg none/non-RS256). Old
      decode-only helper deleted. 6 tests, suite 51/51. warm.contact PR #44.

### Phase 2 — Finish AD-10 (the architecture is half-migrated)
*Doctrine: approval happens where the signing key lives. Currently true for
approval, false for drafting — the interim scribe still runs under a box key.*
- [x] **nact#26, the nact-repo half — SHIPPED 2026-07-23 (nact PR #31,
      deployed + live-verified).** Ngage is a first-class approval path:
      `lib/routing.mjs` (the tested AD-10 model, 8 tests), the board split into
      🛡 box gate vs ✋ Ngage with a per-identity path badge, EXCLUSIVE binding
      (a cell click MOVES the identity's single path), and an
      "Ngage draft-grant" channel type that carries no on-box secret. #26 stays
      open for the coupled remainder: the scribe signing as Quill (luke repo,
      tied to #43) and the steering UI (ngage#1).
- [ ] **warm.contact#43** — port the scribe to the Mac: James's Quill drafts
      locally, Keychain key, `credential:anthropic` grant, launchd cadence.
      *The Director's build brief is attached to the issue (2026-07-23),
      reframing it as the NCP drafting ACTUATOR — actuator(template, grant) →
      draft, surface as a parameter — per docs/scoped-agent-actions.md (landed
      via #56). Held for his explicit go: it runs on his machine, holds his key.*
- [ ] **ngage#1** — the steering settings UI ("the voice drafter"): per-identity
      steering editable where the approving happens; later extends to
      nave/luke steering over the same wire.

### Phase 3 — Publish (the declared movement; the voice work was done FOR this)
- [ ] Finish the revoicing programme (`library/ROADMAP.md`: 5 upgrades + 4 new
      pieces remain) — nothing else ships in the averaged AI voice.
- [ ] **nave.pub#15** — publish essays 2+3; cross-post the set to nostr.
- [ ] **nave.pub#14** — ECOSYSTEM-HUB build-out.
- [ ] **spec#1** — shepherd nostr-protocol/nips#2411 *with* the published
      material: the P-series and Ngage's reversed arrow are the novel content,
      and a PR thread is more persuadable with prose than with commits.

### Phase 4 — warm.contact runway (the product bet: "Luke, for everyone")
- [ ] Quill grant family — **#19 #20 #42** (converges with Phase 2's Mac port;
      same machinery, build once).
- [ ] Security-before-launch — **#22** (gate SMS explicitly) · **#25** (rate
      limiter → shared store) · **#31** (pin/SRI the page bundle) · **#32**
      (reserved names / brand gating).
- [ ] Launch ops — **#33 #34 #35** — only when the security basket is green:
      launching before it is how you earn the wrong launch story.

### Parked, with reasons (so they don't nag)
- **noir#1 (M3 AI Director)** — a creative epic; deserves a dedicated block,
  not interleaving.
- **nact#12/#13/#14 (NCP gate, read path, Nops spike)** — Nops rides exactly
  the grant machinery Phase 2 finishes; build it after nact#26, once.
- **nact#15 (James→Nact_jaf delegation)** — signature-gated, Director-only;
  widen delegated approval only after hardening #7–#9.
- **nact#3/#4 (M-series close-out)** — on the quiet-week timer by design.
- **Hygiene basket** — nave.pub#6–#13 small verifications, warm.contact#27
  (commit the v0.4 spec doc), nherit#1 (mostly the Director's 30 minutes) —
  fit in the cracks between phases.
- **Keyless boot (AD-4)** — north star; unchanged.

### Process rules (from the incident ledger)
- **WIP limit: two tracks** — one Phase-1 item + one Phase-2 item in flight,
  nothing else. The 07-21→23 failure modes (stacked-merge cascade, silent
  pushes) all correlate with parallelism.
- **Issues-first** — every commit bookended by its issue(s); check for an
  existing ticket before filing (the queue is real; duplicates are worse than
  none). Verify the tree, not the PR badge.

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
