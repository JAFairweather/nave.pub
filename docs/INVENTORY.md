# Nave — Master Inventory & Handbook (2026-07-20)

The working map of the whole Nave estate, in **five books** plus what's in flight:

1. **Nave** — the products and what's left to build *(inline below)*
2. **Nops** — operations toolkit & ideas → [`NOPS.md`](./NOPS.md)
3. **Identity Book** — every agent + Bitwarden checklist → [`IDENTITY-REGISTRY.md`](./IDENTITY-REGISTRY.md)
4. **SOPs** — server/secret runbooks & links → [`../deploy/ops/`](../deploy/ops/) + [`NOPS.md`](./NOPS.md)
5. **Side-Quest Log** — the detours & hard-won fixes → [`SIDE-QUESTS.md`](./SIDE-QUESTS.md)

Statuses: ✅ done · 🔶 in flight · ⬜ open · 💤 parked · 🧭 direction.
Security rule for this file: **npubs and names only — an nsec never appears in
this repo.** Secrets live in Bitwarden and sealed envs; Book 3 records *where*.
Companion docs: architecture decisions [`nave-architecture-decisions.md`](./nave-architecture-decisions.md),
history [`JOURNEY.md`](./JOURNEY.md), original plan [`ECOSYSTEM-HUB.md`](./ECOSYSTEM-HUB.md).

> Blind spot: compiled from the task ledger, repo docs, and ~8 days of sessions.
> Anything living only in your head or an untracked repo may be missing — this is
> the place to correct it.

---

## Book 1 · NAVE — the family, and what's left to build

### 1.1 Common sign-in — `nave-connect` (#56) — *the flagship item*
- ✅ Module built + tested (`luke/nave-connect.mjs`): nip07 / local-key / nip46
  signers, session serialize/parse.
- ✅ Bunker path proven end-to-end (Armada signed via `bunker.nave.pub`).
- ✅ Decision locked: Nvoy keeps local-key onboarding ("advanced"-gated); Nact
  stays signer-only (James, 2026-07-18).
- ⬜ **Wire into every app's login UI + unified title bar** (Nvoy, Nact, Luke
  console, hub). Browser-verify-gated.
- ⬜ Mint one named bunker connection per app; scoped permissions; revocable.

### 1.2 Per-product to-dos
- **Hub (nave.pub)** — ⬜ "Identity = Freedom" thesis page; protocol/"why NIP-DA
  is real" content; James page; iconography pass; suite nav; analytics; backups;
  launch & community (ECOSYSTEM-HUB §2, §5–6). ("Alby sign-on" superseded by
  bunker + nave-connect.)
- **Nvoy** — 🔶 grant migration M1+M2 (#37); ⬜ Phase A2 credential ciphertext →
  owning identity (#43); ⬜ luke.env → nave.env + nave-owned SOPS (#44), then
  alias/credential-copy cleanup; ⬜ central-identity fleet console (#59);
  ⬜ re-delegation terms end-to-end (#60). 🧭 Roadmap: requests that are grants
  *and* enacts; providers first-class over NIP-05.
- **Nact / Nactor** — ⬜ AD implementation queue (AD-1 History→audit, AD-5
  Channels/Routing, remaining AD-2 consumers); ⬜ **mail connector (#36)**
  (verb-scoped IMAP, app-password + OAuth/XOAUTH2 — also warm.contact's Gmail
  path); connector pattern doc exists (`nact/docs/connectors.md`).
  💤 #48 delegate approval authority James → Nact_jaf (signature-gated).
- **Luke** — ⬜ other brain clients adopt `nact-resolve` (AD-2); 💤 console
  authoring pass 2 (#26).
- **warm.contact** — ✅ integrated (grant works E2E, avatar, box in fleet);
  ⬜ Gmail path lands with #36; #59/#60 become load-bearing as they build.
- **Untracked family repos** — `nherit`, `nontact`, `notegate`, `ntrigue`,
  `nvelope`, `nostr-scoped-data-grants` (spec), `noir` (superseded): inventory
  each when it re-enters play.

### 1.3 Relay adoption — in flight 🔶
Put `wss://relay.nave.pub` under **every** identity (fleet 4 + 7+ Nvoy agents + jaf):
1. **Roster** — enumerate all Nvoy agents (Book 3; **current blocker** — paste
   the npubs or let me pull them via the ops channel).
2. **Allowlist** — every pubkey into `deploy/relay/allowlist.json` + redeploy
   (the relay rejects unlisted writers — silent failure otherwise).
3. **Config** — add to `RELAYS`/`LUKE_RELAYS` (SOPS env) and Nvoy's
   `DEFAULT_RELAYS`/`NVOY_RELAYS` (`nvoy/mcp/src/identity.ts`).
4. **Refactor** — move relay lists out of SOPS into plain env (URLs aren't
   secrets) so relay changes become ordinary CI deploys.
5. **NIP-65** — publish kind-10002 relay lists per identity (one-shot via ops).

---

## Book 2 · NOPS → [`NOPS.md`](./NOPS.md)
Firewalld-free hardening, on-box firewall, unified CI channels, the fleet table,
and ideas floated-but-unbuilt. ✅ 2026-07-20: fleet on one key, all boxes
hardened + firewalled + on CI, bunker restored. Remaining ⬜: verify warm's
`:8484` boot unit, relay auto-deploy check, workflow sweep, break-glass audit,
delete unused `WARM_SSH_*` from the warm.contact repo, optional edge firewalls.

## Book 3 · IDENTITY BOOK → [`IDENTITY-REGISTRY.md`](./IDENTITY-REGISTRY.md)
All 8 known keys (nave, nactor, luke, brain, nact_jaf, noir, operator, sovereign)
with npub + hex + custody, and the Bitwarden checklist. ⬜ Enumerate the full
Nvoy roster and add missing rows (same list Book 1.3 needs).

## Book 4 · SOPs → [`../deploy/ops/`](../deploy/ops/)
`ssh-standard.md` · `rekey.sh` · `newbox.sh` · `harden.sh` · `firewall.sh` ·
`inventory.sh` · `ci-ops-allow.sh` · `PLAN.md`. Secrets: `deploy/secrets/`
(`nave.enc.env`, `nactjaf.age`). Relay: `deploy/relay/`. Bunker: `deploy/bunker/`.
Full annotated list in [`NOPS.md`](./NOPS.md).

## Book 5 · SIDE-QUEST LOG → [`SIDE-QUESTS.md`](./SIDE-QUESTS.md)
firewalld melting Docker, the document.txt scare, SSH self-wounds, the
DOCKER-USER guard bug, zsh comment gotchas, secrets-in-wrong-repo, the bunker
nsec resolution, operator-key churn, Luke's approvals outage — the "why is it
like this" record.

---

## In-flight now & shortlist (next actions, in order)

1. **Relay under every identity** (Book 1.3) — blocked on the Nvoy roster.
2. **`nave-connect` into the app UIs** (#56) — the common sign-in.
3. **Mail connector** (#36) — unblocks Luke email-send + warm.contact Gmail.
4. **Grant migration** chain: #37 → #43 → #44 → cleanup.
5. **AD implementation queue** (AD-1 audit, AD-5 routing).
6. **Nfra loose ends** (Book 2 ⬜ items — small, mostly verification).
