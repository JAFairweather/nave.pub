# Nave — Master Inventory & Handbook (2026-07-20)

The complete map of the Nave estate, grounded in a full read of every repo
(2026-07-20). Statuses: ✅ built · 🟡 partial/live-with-gaps · ⬜ open/intended ·
💤 parked · 🧭 direction (north star).

**The one-sentence thesis:** *scoped autonomy* — an agent bounded on both what it
may **see** and what it may **do**, with your nostr signature as the only root of
authority and revocation-by-key-rotation throughout.

This file is the master index; deep docs it points to:
`NOPS.md` (ops) · `IDENTITY-REGISTRY.md` (keys + Bitwarden) · `SIDE-QUESTS.md`
(incidents) · `quill.md` (the warm.contact reconnect agent) ·
`nave-architecture-decisions.md` (AD-1…7) · `JOURNEY.md` · `ECOSYSTEM-HUB.md`.

---

## 0 · THE SPINE — one protocol, two directions

```
                 PERCEIVE (data-in)          ACT (actions-out)
   protocol      Scoped Data Grants          Scoped Action Approvals
                 (NIP-DA · real draft NIP,   (sketch · not yet a NIP)
                  built + JS↔Go interop)
   runtime       NCP (concept; v0 egress)    Nactor (built · V1 HTTP/NIP-98)
   instances     Nvoy, Nvelope, Nontact,     Nact (social), Nops (server ops)
                 Notegate
   mechanism     grant (kind 30440/440/      approval (propose→approve→sign→
                 441/10440)                   enact; NIP-59/46 today)
```

- **Nvoy is the connective tissue both ways** — it feeds ordinary agents their
  data *and* feeds Nactor its own config as a scoped grant.
- 🧭 **The frontier** (`FUTURE.md`, `DESIGN.md`): *a request that is a grant **and**
  an enact* — perceive and act collapse into one signed exchange; providers become
  first-class over NIP-05; revocation chains across providers.

## 1 · THE PROTOCOL (the foundation)

- **Scoped Data Grants / NIP-DA** — `nostr-scoped-data-grants` (PR nostr-protocol/nips#2411).
  ✅ Spec complete (draft; kind numbers placeholders). Four kinds: **30440** scoped
  data set (NIP-44 under a random 32-byte scope key), **440** grant (gift-wrapped),
  **441** revocation, **10440** grant index (recoverable from your nsec alone).
  Revocation = key rotation, not token expiry. Two reference impls (JS `nipxx.mjs`
  ~200 LoC + Go CLI), interop verified live.
- **Scoped Action Approvals** — the act-side peer. ⬜ Exploratory sketch only,
  *deliberately* not yet a NIP (build-first, PR when cross-client demand appears).
  The one standardizable thing: a verifiable `["approval", id, approver]` tag =
  public proof an agent action passed a human tap.

## 2 · THE APPS (two families)

### 2a · NIP-DA nostr family (built on the spec)
| App | What it is | Status |
|---|---|---|
| **Nvoy** | Scoped, revocable data delegation to AI agents; mounts as an **MCP server** (7 tools) | ✅ v0.1 working client + console "Ledger"; not npm-published (draft protocol) |
| **Nvelope** | Secure document sharing — live folders, real revocation, one-key recovery | ✅ v1 feature-complete alpha (M1–M5); Blossom for large blobs |
| **Nherit** | Family estate / legacy break-glass vault — dead-man's-switch escrow + SLIP-39 paper Shamir | ✅ Alpha, ~150 tests; reuses Nvelope's manifest pattern |
| **Nontact** | The no-maintenance address book (self-maintained records, scoped access) | ✅ Alpha prototype |
| **Notegate** | Serverless secure tip line (journalism) — PoW toll, gift-wrap, timing jitter | ✅ Alpha, v1 feature-complete (M1–M4) |
| **Ntrigue** | Phones-only party game of secrets & blackmail ("revoke a secret, can't un-tell it") | ✅ Built v0.1 (MIT); v1 stage-mode + AI-MC unbuilt |
| **Noir** | Nostr spycraft game — grants are earned intel, a key rotation is a felt "burn notice"; the Director is itself an nvoy agent | 🟡 Active, M1 of 6; M3 (AI Director) in progress |

### 2b · Native "contacts" cluster (integrate *with* Nave, not built *on* the spec)
| App | What it is | Status |
|---|---|---|
| **warm.contact** | Zero-knowledge, inbound-first contact collection; own `wc1` sealed-box crypto (P-256 ECDH). Relay only ever brokers ciphertext | 🟡 v0.1 shipped; v0.6/v0.7 implemented; big backlog (§5) |
| ↳ **Quill** (was "Rekindle"/"Vocalist") | The per-user **reconnect agent** — drafts warm replies in your voice, Mac→Anthropic direct, no auto-send | 🟡 engine (`Rekindle.swift`) shipped; per-user-Director identity = new (see `quill.md`) |
| **outerjoin** | Native macOS app: consolidate/de-dup/two-way-sync Apple⇄Google contacts, on-device | ✅ Substantially built, 85 tests green, pushed; fully independent of nostr |

> **Correction on record:** "noir superseded by nave.pub" was wrong — `noir` (the
> game) is active; the noir→nave.pub *flip* was only the website platform.

### 2c · Luke — the flagship agent (James's own)
✅ Brain (voice corpus, proposer, cron), poster + Telegram approval cards, webhook
self-registration, console + heartbeat, calendar beat (7:20am ET), OpenClaw engine
(heartbeat/dreaming/hygiene), email draft-only (himalaya IMAP). Private
`luke-brain` repo holds memory snapshots. **Luke is the pattern Quill generalizes:
a per-person brain that drafts in your voice from granted credentials.**

## 3 · THE RUNTIMES

- **Nactor** — the act-side on-box runtime. ✅ V1 built (HTTP + NIP-98). Holds the
  proposal queue + role keys; the same `nact` library that *is* Nact runs as Nactor
  with a pluggable actuator (publish for Nact, `exec` for Nops). 4 identities live
  (luke/brain/nave/nactjaf), 7 credentials.
- **NCP (Nostr Context Protocol)** — the perceive-side runtime, the "missing
  quadrant." 🟡 Concept with a **built v0 egress organ**: transparent proxy
  `/api/proxy/<provider>` injects the real credential from RAM (engine calls
  Anthropic, never holds the key). ⬜ Open: per-identity gate, data-grant read path,
  optional MCP-resource front.
- **Credential model (AD-6):** authority = a Director-signed grant carried by the
  *identity*, never a box ACL. Two consumption modes per (credential × consumer):
  **broker** (on-box, RAM) vs **grant-to-app** (identity holds its own key, off-box
  / content-sensitive). Broker is **live**; grant delivery is **LIVE end-to-end
  (2026-07-21)** — the M2 reader shipped hardened (Director-only trust, AD-1 audit
  events, env-fallback provenance; nact#1 closed), all seven provider credentials
  arrive as relay scopes, ownership enforcement is ON, and the last two bootstrap
  env lines (`ANTHROPIC_API_KEY`, approvals `TELEGRAM_BOT_TOKEN`) were deleted at
  source via the reviewed `deploy/ops/retire-brokered-env.sh` run — **grants are
  every live credential's only durable home**. Engine-held keys (google/Gemini —
  the PRIMARY engine model — in the gateway's `google:default` profile, plus
  anthropic in openclaw.env) remain E-tier by design until M6.

## 4 · Nfra + Nops (infrastructure & operations)

**Nfra** = the sovereign substrate; **Nops** = operating it.
- ✅ **Fleet on one key** — `nave_mgmt` opens all 3 boxes; SSH key-only; stray keys pruned.
- ✅ **Docker-safe hardening** — firewalld purged (it caused the 07-20 outage);
  nftables INPUT + DOCKER-USER on-box firewall (no provider-panel dependency);
  fail2ban; auto-updates; reboot survival. Verified externally.
- ✅ **Unified CI ops** — `fleet-ops` (main+warm, full), `relay-ops` (bunker box,
  **restricted forced-command allowlist** — can't read the sovereign `.env`), probe,
  verify, deploy. Bunker (`bunker.nave.pub`) live; relay (`relay.nave.pub`) live.
- 🧭 **Nops proper** (`nact/docs/nops.md`) — operate the box with your nostr key;
  ops-runner has its own identity, receives allowed verbs as a scoped grant, `exec`
  on signed approval. Today's SSH+CI channels are the *proto over the wrong transport*.
- Boxes: **main Nave** (Hostinger/Ubuntu, Docker), **relay/bunker** (Hostinger/Alma,
  Docker), **warm.contact** (DO/Ubuntu 1 GB, native Caddy+Node). Details: `NOPS.md`.

## 5 · THE BACKLOG (what's next, grounded from the docs)

### Credential migration (nact) — M-series, *delivery complete 2026-07-21*
- 🟢 M1 re-inventory ✅ · **M2 reader ✅ (nact#1 merged: Director-only trust,
  entitlement revocation fix, AD-1 grant/entitlement audit events, per-credential
  `source` provenance)** · **M3 `telegram-luke` pilot ✅** (issued 2026-07-18 via
  request→Issue; verified read-live 2026-07-21; env line gone; rollback path in
  nact `docs/migration-status-2026-07.md` §5) · **M4 the rest ✅** (gworkspace ✓
  anthropic ✓ approvals `telegram`→`telegram-nactjaf` flip to @navenactorbot ✓,
  plus beyond-plan `telegram-brain`/`telegram-nave`; final env deletions ran via
  the reviewed `retire-brokered-env.sh`, bundle synced, verified) · remaining:
  **M5 mail connector (#36)** · **M6 engine egress** → `/api/proxy` — now covers
  BOTH engine-held keys: google/Gemini (**the primary engine model**,
  `google/gemini-3.1-pro-preview`, key in the gateway's `google:default` profile)
  and anthropic (openclaw.env) · M7 Nvoy MCP transport · A2 ciphertext
  re-addressing, per-credential.
- **nvoy#1 hierarchical re-grant ✅ (2026-07-21)** — one-hop chain proven against
  the conforming MCP receiver (`nvoy test/regrant.mjs`); cascade semantics pinned
  (derived-scope sub-grants attenuate + revoke per-leaf; root revocation cascades
  via the sub-issuer's rotation obligation; key re-wrap rejected by conforming
  receivers) and fed to SPEC FUTURE.md. Both shared gates down → warm.contact
  #5/#6/#9/#18 unblocked.
- **Mail connector (#36 / M5)** — `stateful-adapter` × {app-password | OAuth},
  verb-scoped **read-only** IMAP, `POST /api/connector/mail`; first connector, also
  unblocks warm.contact's Gmail. Unbuilt.

### Nact hardening (threat-model Phases 1–5)
- ⬜ Freeze `created_at` at propose + re-verify event-id fingerprint before signing;
  faithful render (kind/tags/hidden-char flags); risk tiers (critical kinds can't
  one-tap); **channel binding as a scoped grant** (nonce ceremony); Mini-App signer
  (`nact.nave.pub/sign`).

### Common sign-in — `nave-connect` (#56)
- ✅ Module built + tested; bunker path proven (Armada). ⬜ Wire into every app's
  login UI + unified title bar. Nvoy keeps local-key onboarding; Nact signer-only.

### Nvoy
- 🟡 grant migration M1+M2 (#37) · ⬜ A2 credential ciphertext → owning identity
  (#43) · ⬜ luke.env→nave.env (#44) · ⬜ fleet console (#59) · ⬜ re-delegation
  terms (#60) · 🧭 attenuable/macaroon-style sub-delegation (SPEC §10); credentials-
  as-grants; request-is-a-grant-and-enact.

### warm.contact + Quill
- 🟡 Nave integration decided (v0.5 §10: grant-to-app via Nvoy MCP; central identity
  minted); ⬜ live Director grant → warm.contact npub, real Swift MCP transport,
  per-instance topology (D-N1/D-N2). ⬜ **Quill evolution** (`quill.md`): per-user
  *human* nostr identity (mint-or-BYO), user-as-Director, add Calendly to profile.
- warm.contact product backlog: Google People sync (brand-verification gate),
  living-contacts profile-key pull, multi-device per-device tokens, CAPTCHA,
  custom domains, billing, launch loop, daily-brief agent (unbuilt).

### Nave hub + docs
- ⬜ ECOSYSTEM-HUB content (Identity=Freedom thesis, protocol case, James page,
  iconography, launch). ⬜ AD impl queue (AD-1 audit, AD-5 routing). ⬜ keyless-boot
  daemon (🧭). 💤 Luke console pass 2 (#26); James→Nact_jaf approval delegation (#48).

### Ticket index (created 2026-07-21)

The backlog above is now tracked as GitHub issues — the inventory stays the map;
the issues are the tickets. **The old #NN references sprinkled above (#26/#36/
#37/#43/#44/#48/#56/#59/#60) predate these trackers; the numbers below
supersede them.**

- **nave.pub #1–15** — nsec identity map (#1) · bunker `.env` backup reconcile
  (#2) · registration-off (#3) · Bitwarden sweep (#4) · probe-IP fix (#5) ·
  workflow sweep (#6) · relay auto-deploy check (#7) · warm `:8484` boot check
  (#8) · Alma auto-updates (#9) · fleet heartbeat (#10) · relay lists out of
  SOPS (#11) · edge firewalls (#12) · firewalld doc note (#13) · ECOSYSTEM-HUB
  (#14) · essays 2+3 (#15).
- **nact #1–16** — the M-series: M2 reader (#1 ✅ 2026-07-21) → M3 pilot
  (#2 ✅ 2026-07-21) → M4 (#3 — env retirement ran 2026-07-21; close pending a
  quiet week of grant-only operation) → M5 mail connector (#4) → M6 egress
  (#5, *now the frontier* — both engine keys incl. the primary Gemini) → M7 MCP
  (#6); hardening P1–P5 (#7–#11); NCP gate/read-path (#12/#13); Nops design
  spike (#14); James→Nact_jaf delegation (#15); nave-connect wiring (#16).
- **nvoy #1–6** — hierarchical re-grant (#1 ✅ 2026-07-21, *the Quill linchpin*
  — proven + cascade semantics pinned) · grant migration M1+M2 (#2) · A2
  ciphertext (#3) · luke.env→nave.env (#4) · fleet console (#5) ·
  re-delegation terms (#6).
- **nostr-scoped-data-grants #1** — shepherd PR nostr-protocol/nips#2411.
- **warm.contact #5–17** — Quill bootstrap/Swift-plumbing/Calendly/lifecycle
  (#5–#8) · Nave integration (#9) · product: People sync, profile-key pull,
  per-device tokens, CAPTCHA, custom domains, billing, launch loop, daily-brief
  (#10–#17).
- **luke #1** — employment-roadmap epic (console pass 2 stays 💤, unticketed).
  **noir #1** — M3 AI Director. **nherit #1** — six-decisions review.
  **ntrigue #19** — Cloudflare MC proxy (optional).

## 6 · Going-forward conventions
- **Work = GitHub issues** per repo (this file is the map; issues are the tickets).
- **New agent** = mint key → relay allowlist → SOPS → Bitwarden note → registry row.
- **New box** = `newbox.sh` → on-box firewall → prove key login → `rekey.sh --lock`.
- **Secrets** live in Bitwarden + sealed envs; npubs/names only in this repo.
