# Nave — Master Inventory (2026-07-20)

The complete map of everything built, in flight, and intended across the Nave
family. Compiled from the working task ledger, the architecture-decision record
(`nave-architecture-decisions.md`), the Ecosystem Hub plan (`ECOSYSTEM-HUB.md`),
the Nvoy roadmap, the fleet runbook (`deploy/ops/PLAN.md`), and the last ~8 days
of build sessions. Statuses: ✅ done · 🔶 in flight · ⬜ open/intended ·
💤 parked · 🧭 direction (north star, not yet scheduled).

Known blind spot: this is compiled from session records + repo docs. Anything
that lives only in your head or in an untracked repo may be missing — corrections
welcome; this file is the place to record them.

---

## A. The identity core (sovereignty)

- ✅ **Sovereign key `jaf@dequalsf.com`** is the root Director — everything in
  Nact (delegations) and Nvoy (data) chains up to him.
- ✅ **Bunker (Bunker46, NIP-46 remote signer)** live at `bunker.nave.pub` on the
  relay VPS, holding jaf's key encrypted; **first remote sign-in proven end-to-end
  (Armada, via bunker:// URI)**. Old leaked connection string treated as burned;
  fresh connections minted from the console.
- ✅ **Restricted relay** `wss://relay.nave.pub` (strfry + write-policy
  allowlist; NIP-46 kind-24133 transport open; fleet pubkeys allowed).
- ✅ Bunker sovereignty tier: `.env` (ENCRYPTION_KEY) backed up off-box to
  Bitwarden; `ALLOW_REGISTRATION` flipped off *(reported done by James — verify
  registration is actually closed via the bunker channel)*.
- ⬜ **Permissions hygiene per app connection** — one named bunker connection per
  app (Coracle/Amethyst/Armada/Nact), scoped perms; revoke individually.
- ⬜ **Key consolidation to the Mac** — James's stated intent (separate issue):
  consider consolidating all minted nsec identities' custody back to the Mac
  (or bunker) rather than scattered env files. Pairs with #43/#44 and AD-4.
- 🧭 **Keyless boot (AD-4)** — Director unseals the box over nostr; no secret on
  disk. SOPS-custodial is the accepted interim.

## B. The Nave family (products)

### Nave — the hub (`nave.pub`)
- ✅ Platform flip from noir → nave.pub; cockpit skin; app grid; rebrand
  regression suite; Luke/Nsecret/Nops/Nactor pages; warm.contact stove avatar.
- ⬜ Hub content build-out from ECOSYSTEM-HUB §2: the "Identity = Freedom"
  thesis page, protocol/"why NIP-DA is real" content, James-the-person page.
- ⬜ ECOSYSTEM-HUB §5–6 backlog: iconography system pass, suite navigation,
  analytics, backups, launch & community plan. (§5.3 "Alby as signature sign-on"
  is superseded by the bunker + nave-connect direction.)

### Common sign-in — `nave-connect` (#56) 🔶 *the flagship family item*
- ✅ Module built (`luke/nave-connect.mjs` + tests 10/10): nip07 / local-key /
  nip46 signers + session serialize/parse.
- ✅ Bunker path proven (Armada). Decision locked: **Nvoy keeps local-key/new-key
  onboarding (gated "advanced"); Nact stays signer-only** (James 2026-07-18).
- ⬜ **Wire nave-connect into every app's login UI + unified title bar**
  (Nvoy, Nact, Luke console, hub) — browser-verify-gated. This is the "common
  sign-in" deliverable.
- ⬜ Regenerate/mint per-app bunker connections as each UI lands.

### Nvoy — scoped data grants (the front door)
- ✅ Core primitive, MCP server, console (Ledger, agents registry), delegation
  tests, M4 accept, egress checks.
- ✅ Ledger organization design (AD: group-by agent/type/status + facets).
- 🔶 **Grant migration M1+M2** (#37): re-inventory + first credential-scope
  pilot (`telegram-luke`).
- ⬜ **Phase A2** (#43): credential ciphertext → owning identity (cross-box).
- ⬜ **luke.env → nave.env** migration + nave-owned SOPS (#44); then drop
  aliases + revoke Nactor's redundant credential copies.
- ⬜ **Central-identity fleet console** (#59): scoped Nvoy for sub-grant
  issuance/revocation.
- ⬜ **Re-delegation terms end-to-end** (#60): allow vs no_redelegate across the
  chain.
- 🧭 Roadmap: credentials-as-grants (partially realized by Nactor); **requests
  that are grants *and* enacts** — providers first-class, discoverable via
  NIP-05, chained revocation.

### Nact / Nactor — enactment + credential broker
- ✅ Runtime server (NIP-98 gated), Director activation, credential broker
  (7 credentials; luke/brain/nave/nactjaf identities), env-split, master-grant
  authority (A1), telegram + anthropic + gworkspace + calendar channels,
  approvals via NACT_CHANNEL (Nact_jaf), per-agent comms-bot guide (#63),
  canonical `telegram-nactjaf` re-grant (#62).
- ✅ AD-2 consumer resolver (`nact-resolve.mjs`) — address the runtime by nostr
  identity (kind-31990 advert), wired into luke-brain.
- ⬜ **AD implementation queue**: AD-1 (History → runtime audit), AD-2 remaining
  consumers, AD-5 (Channels/Routing reconcile impl), AD-7 rollout notes.
- ⬜ **Connector pattern build-out** (`nact/docs/connectors.md`): transport
  (http-build × stateful-adapter) × auth (static-key × oauth). First real one:
  **mail connector (#36)** — verb-scoped IMAP, app-password + OAuth/XOAUTH2
  (also unblocks warm.contact's Gmail path).
- 💤 **#48 (signature-gated, James-only)**: delegate approval authority
  James → Nact_jaf.

### Luke — the employee
- ✅ Brain (themes/voice corpus, proposer, cron), poster with approval cards,
  webhook self-registration (fixed the approvals outage), console + heartbeat
  surfaced, calendar beat (7:20am ET briefing), full-employment roadmap,
  brain restored after the Dockerfile COPY crash.
- ✅ OpenClaw engine: self-hosted 2026.7.1-browser, heartbeat 30m, nightly
  dreaming, workspace hygiene, email draft-only (himalaya IMAP).
- ⬜ Other luke-brain clients adopt `nact-resolve` (AD-2).
- 💤 Console authoring pass 2 (#26): ＋New-session → guarded cron.

### warm.contact — first external family product
- ✅ Nave-side integration review; credential grant works E2E via their MCP;
  kind-0 profile + stove avatar published; box folded into the fleet standard
  (rekeyed, hardened, firewalled, CI channel).
- ⬜ Their Gmail path lands when the mail connector (#36) ships.
- ⬜ Fleet-console + re-delegation (#59/#60) become load-bearing as they build.

### Other family repos (in workspace, not in recent context)
`nherit`, `nontact`, `notegate`, `ntrigue`, `nvelope`, `nostr-scoped-data-grants`
(spec), `noir` (superseded by nave.pub). Status not tracked in the last 8 days —
inventory them when they re-enter play.

## C. Nfra + Nops (infrastructure & operations) — mostly landed 2026-07-20

- ✅ **One management key** (`nave_mgmt`, Mac Keychain) opens all 3 boxes; SSH
  key-only everywhere; per-box stray keys pruned (main: +2 `github-deploy` CI
  keys; relay: +`nave-ci-relay`; warm: +`nave-ci-warm`).
- ✅ **Process docs + scripts**: `ssh-standard.md`, `rekey.sh` (verify-before-
  lock), `newbox.sh` (MGMT_PUB), `harden.sh` (firewalld-free), `inventory.sh`,
  `firewall.sh`, `PLAN.md` (living runbook).
- ✅ **firewalld removed fleet-wide** (root cause of the Docker outage:
  INVALID_ZONE + flushed chains — incident documented in PLAN.md).
- ✅ **Docker-safe on-box firewall** on all 3 boxes: nftables INPUT
  (22/80/443 + lo/established/docker-subnet) + DOCKER-USER seal of published
  ports except 80/443. Verified externally: bunker `:8080` sealed, warm `:8484`
  sealed (node still local), all sites 200.
- ✅ **Unified CI ops (Nops)**: `fleet-ops.yml` (full: main + warm),
  `relay-ops.yml` (bunker box: forced-command allowlist — status/restart/logs
  only, can never read the sovereign `.env`), `probe.yml`, `verify.yml` harness
  green, deploy/ops/smoke channels.
- ✅ fail2ban (gentle) + auto-updates on all 3; reboot survival (docker enabled,
  `unless-stopped` everywhere; warm Caddy boot-enabled).
- ⬜ Verify warm's node app (`:8484`) is a boot-enabled systemd unit.
- ⬜ Confirm relay-box **auto-deploy** still works post-Docker-rebuild; sweep all
  workflows for stale firewalld/proxy assumptions.
- ⬜ Break-glass audit: each provider console opens + root password in Bitwarden.
- ⬜ Delete the unused `WARM_SSH_*` secrets from the *warm.contact* repo.
- ⬜ Optional belt-and-suspenders: provider edge firewalls to 22/80/443.

## D. In flight right now 🔶

**Put `relay.nave.pub` under every identity** (7+ Nvoy agents + fleet 4 + jaf):
1. **Roster** — enumerate all Nvoy agent pubkeys (ledger `nvoy_agents`; needs
   James's list or on-box enumeration). ← current blocker
2. **Allowlist** — add every pubkey to `deploy/relay/allowlist.json` (the relay
   rejects writes from unlisted keys — silent failure otherwise) + redeploy.
3. **Config** — add `wss://relay.nave.pub` to `RELAYS`/`LUKE_RELAYS`
   (SOPS env) and Nvoy's `DEFAULT_RELAYS`/`NVOY_RELAYS`
   (`nvoy/mcp/src/identity.ts`).
4. **Refactor** — move relay lists out of SOPS into plain env (relay URLs are
   not secrets) so relay changes become ordinary CI deploys.
5. **NIP-65** — publish kind-10002 relay lists per identity (small
   `publish-relays.mjs`, one-shot via ops channel).

## E. Shortlist — likely next actions in order

1. Nvoy roster → relay allowlist → relay.nave.pub everywhere (D above).
2. Wire **nave-connect** into the app UIs (#56) — the common sign-in.
3. Mail connector (#36) — unblocks Luke email-send and warm.contact Gmail.
4. Grant migration chain: #37 → #43 → #44 (then alias/credential cleanup).
5. AD implementation queue (AD-1 audit, AD-5 routing).
6. Nfra loose ends (C's ⬜ items — small, mostly verification).
