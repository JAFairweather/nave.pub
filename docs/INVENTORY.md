# Nave — Master Inventory & Handbook (2026-07-20 · updated 2026-07-23)

The complete map of the Nave estate, grounded in a full read of every repo
(2026-07-20; refreshed 2026-07-23 after the voice-and-sovereign-hand sessions).
Statuses: ✅ built · 🟡 partial/live-with-gaps · ⬜ open/intended ·
💤 parked · 🧭 direction (north star).

**The one-sentence thesis:** *scoped autonomy* — an agent bounded on both what it
may **see** and what it may **do**, with your nostr signature as the only root of
authority and revocation-by-key-rotation throughout.

This file is the master index; deep docs it points to:
`HANDOFF.md` (the session-onboarding prompt, versioned) · `NOPS.md` (ops) ·
`IDENTITY-REGISTRY.md` (keys + Bitwarden) · `SIDE-QUESTS.md` (incidents) ·
`quill.md` (the reconnect agent — and now the Director's drafting agent) ·
`nave-architecture-decisions.md` (AD-1…11) · `JOURNEY.md` · `ECOSYSTEM-HUB.md` ·
`../library/` (the public writing: essays, artifacts, the writing programme).

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
- **P-series hardening ✅ COMPLETE (2026-07-22)** — the external design review's
  six weaknesses, each paid down in the spec: **P1** grant authentication
  (author == publisher) · **P2** anti-rollback `u` sequence + `(v,u)` high-water ·
  **P3** multi-device Lamport `v`, deterministic NIP-01 winner, mergeable index ·
  **P4** incremental inbox (`since` cursor + NIP-59 overlap window) · **P5**
  per-field key trees (experimental kind 31440, HKDF) · **P6** metadata hardening
  (`d` rotation). Landed as **one linear PR (spec repo #17)** after a
  stacked-rebase cascade silently dropped P3–P6 the first time — recovery and
  lesson in `SIDE-QUESTS.md`. The public write-up is
  `../library/articles/hardening-a-protocol-in-public.md`.
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
| **Ngage** | **The sovereign posting desk — the reversed arrow.** An agent drafts *for* the Director and gift-wraps each draft to his npub as a `draft:post/*` scope; he reviews in Ngage and signs **in his own hand** — the drafting key can't post, the posting key never left him. Steering runs the *other* way over the same wire: a `steer:draft` grant from the Director tunes the drafter (topics, register, cadence), editable without a deploy. | ✅ LIVE (`ngage.nave.pub`, 2026-07-22): first sovereign post signed; steering grant round-trip proven end-to-end; 25 tests |

### 2b · Native "contacts" cluster (integrate *with* Nave, not built *on* the spec)
| App | What it is | Status |
|---|---|---|
| **warm.contact** | Zero-knowledge, inbound-first contact collection; own `wc1` sealed-box crypto (P-256 ECDH). Relay only ever brokers ciphertext | 🟡 v0.1 shipped; v0.6/v0.7 implemented; big backlog (§5) |
| ↳ **Quill** (was "Rekindle"/"Vocalist") | The per-user **reconnect agent** — drafts warm replies in your voice, Mac→Anthropic direct, no auto-send | 🟡 engine (`Rekindle.swift`) shipped; per-user-Director identity = new (see `quill.md`) |
| **outerjoin** | Native macOS app: consolidate/de-dup/two-way-sync Apple⇄Google contacts, on-device | ✅ Substantially built, 85 tests green, pushed; fully independent of nostr |

> **Correction on record:** "noir superseded by nave.pub" was wrong — `noir` (the
> game) is active; the noir→nave.pub *flip* was only the website platform.

### 2c · Luke — the flagship agent (James's own)
✅ Brain (proposer, cron), poster + Telegram approval cards, webhook
self-registration, console + heartbeat, calendar beat (7:20am ET), OpenClaw engine
(heartbeat/dreaming/hygiene), email draft-only (himalaya IMAP). Private
`luke-brain` repo holds memory snapshots. **Luke is the pattern Quill generalizes:
a per-person brain that drafts in your voice from granted credentials.**

**Per-identity steering (2026-07-22, luke#15 — replaces the single voice corpus).**
The old `brief/voice.md` described every voice in one file and let the model pick
a hat per post — which is how two voices average into one, and how Luke's register
ended up guessed (and wrong: his own box-side charter says *"have a spine … a
yes-man is worthless"*, not the "wry, deferring" the corpus claimed; it also had
the dequalsf creed itself wrong — it is **discipline = freedom**). Now:
`brief/shared.md` (substance + house rules, every drafter) + one voice file per
identity (`nave.md`, `luke.md`, `jaf.md`), **one LLM pass per identity that
structurally cannot see another identity's file**. Voice files are built from
**evidence only**: Luke's from his OpenClaw `SOUL.md`/`IDENTITY.md` (box-only —
just the public posting register carried over), the Director's from twelve
hand-written essays (measured, not inferred). Engagement and approval-memory are
scoped per identity; **zero posts is a valid run** ("silent by default" is in his
charter). Pure logic in `voices.mjs`, 16 tests. AD-9/AD-10 record the doctrine;
every post still enforces the three house rules (nave.pub link + named-app link,
card graphic, hashtags) deterministically via `post-format.mjs`.

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
  the reviewed `retire-brokered-env.sh`, bundle synced, verified) · **M6 engine
  egress ✅ (2026-07-21)** — the engine holds ZERO real provider keys; every
  model call (the primary included) rides the dummy token through Nactor's
  `/api/proxy`, grant-sourced keys injected from RAM; `credential:google` was
  issued **owner-first (Luke)** and re-granted to Nactor as broker supply;
  organic-verified from the engine's own transport log · **M5 mail
  connector BUILT ✅** (verb-scoped read-only IMAP + wire-audited offline suite;
  cutover = issue `credential:mail-gmail`, run `deploy/ops/m5-mail-verify.sh`,
  repoint the consumer, delete `mail/app-passwd` — tracked in nact#4) · **M7 Nvoy MCP
  transport ✅ CUTOVER COMPLETE (2026-07-21)** — nvoy-mcp custodies the nactor
  key; the runtime env holds no nsec and reads grants via the two
  conformance-pinned MCP tools; direct-relay retained as the flagged fallback.
  **The credential-migration M-series is CLOSED, M1→M7** · **A2 stage 2 SHIPPED ✅** (owner grants
  supply values with strict precedence; revoke Nactor-addressed duplicates from
  the console per credential once the audit shows the owner-tagged load —
  `google` ready first).
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

### Common sign-in — `nave-connect` (#56 → nact#16, CLOSED ✅ 2026-07-21 · extended 2026-07-22→23)
- ✅ Wired fleet-wide and deployed: nvoy, nontact, nherit, nvelope, noir (master
  overlay), notegate (Director-scoped minimal); ntrigue excluded by design
  (burner anonymity is the product). ✅ Unified title bar shipped as a copy-in
  component (`nave.pub/components/nave-titlebar.{html,mjs}` + demo) and adopted
  in all four pill-bearing apps. Nvoy keeps local-key onboarding gated behind
  Advanced; Nact stays signer-only.
- ✅ **nostrconnect promoted, Nact adopted (2026-07-22→23, AD-11).** Nact's
  reverse-pairing `nostrconnect://` handshake — mint the link, paste it into the
  signer's "Connect app"; the iPhone path — was **promoted up into `nave-connect`**
  (luke#16, three real signer bugs pinned as tests: `result:"ack"` tolerance,
  NIP-04 fallback, no-`since` clock-skew fix) and synced to nvoy (#15) and ngage
  (#6, its flagged local-signer nip44 extension re-applied). Nact then adopted
  `nave-connect` + `nave-titlebar` (nact#28) — its bespoke crypto deleted, its
  superior diagnostics overlays kept; **sign-out and session-resume exist there
  for the first time**. Its fabricated demo queue is gone (nact#27 — a control
  plane must never invent approvals), and the stale-cache double-incident is
  closed (nave.pub#51 Cache-Control guard + nact#29 versioned module URLs; the
  four sign-in files now load as one unit, no CDN in the path).

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
- **nostr-scoped-data-grants P-series EPIC ✅ COMPLETE (2026-07-22)** — all six
  spec evolutions landed (P1 grant-author verification · P2 anti-rollback `u` ·
  P3 multi-device consistency · P4 incremental inbox · P5 per-field key trees ·
  P6 metadata hardening) as **one linear PR (repo #17)** after the first pass
  was silently lost to a stacked-rebase cascade (SIDE-QUESTS). Public write-up
  in `../library/articles/hardening-a-protocol-in-public.md`.
- **nostr-scoped-data-grants #1** — shepherd PR nostr-protocol/nips#2411.
- **warm.contact #5–17** — Quill bootstrap/Swift-plumbing/Calendly/lifecycle
  (#5–#8) · Nave integration (#9) · product: People sync, profile-key pull,
  per-device tokens, CAPTCHA, custom domains, billing, launch loop, daily-brief
  (#10–#17).
- **luke #1** — employment-roadmap epic (console pass 2 stays 💤, unticketed).
  **noir #1** — M3 AI Director. **nherit #1** — six-decisions review.
  **ntrigue #19** — Cloudflare MC proxy (optional).

### The current frontier (2026-07-23) — reconciled against a cold fresh read

*A second agent oriented from these docs alone (2026-07-23, pre-refresh) and
derived its own top-3. That cold read is valuable calibration — what the docs
teach unaided — and it surfaced one priority this inventory had under-weighted.
Reconciliation:*

**What the cold read got right, adopted here:**
1. **The act-side gap is the biggest live hole in "the signature is the
   authorization"** (their #1, and correct): Nact hardening Phases 1–5
   (nact#7–#11) — freeze `created_at` at propose, re-verify the event-id
   fingerprint before signing, faithful WYSIWYS render, risk tiers so critical
   kinds can't one-tap. Already ticketed; **now explicitly ranked above new
   feature work on the act side.**
2. **The publishing movement is the active pivot** (their #2) — ECOSYSTEM-HUB
   content (nave.pub#14) + cross-posting. Still true, with one gate the cold
   read couldn't see: **essays now pass through the revoicing programme first**
   (`../library/ROADMAP.md`) so nothing else ships in the averaged AI voice.
3. **The Quill bootstrap** (their #3; warm.contact#5) — still the
   generalization play, now *larger* than the doc they read (see below).

**What a cold read cannot yet see (shipped or decided since 2026-07-21):**
- **P-series done; posting loop rebuilt; Ngage live** (§1, §2a, §2c above).
- **The routing doctrine (AD-10):** every identity binds to exactly ONE approval
  path — box-custodied keys → Nactor → Telegram; agents drafting *for the
  Director* → Ngage draft-grants, signed in his own hand. This dissolved Luke's
  overloaded-agent condition (drafting as himself *and* for James on one path).
- **Quill's role grew:** James's Quill becomes the Director's drafting agent —
  the scribe ports to the Mac against Quill's Keychain-held key (`quill.md` §9).
- **Sign-in is one module fleet-wide** including Nact (AD-11).

**The reconciled top-3 (all ticketed — issues-first):**
1. **Ngage as a first-class channel type + grant-driven routing** — **nact#26**
   (filed 2026-07-22: bind each identity to ONE approval path, split Luke's
   overloaded role). Draft-grant delivery approvable only by the Director's
   npub — enforced by encryption, not policy; approval wiring derived from
   grants the way comms wiring already derives from credential grants.
2. **Port the scribe to the Mac** — James's Quill drafts locally, Keychain key,
   `credential:anthropic` grant, launchd cadence; completes "approval happens
   where the signing key lives" (`quill.md` §9; chains warm.contact#5/#42).
3. **nact#7 (hardening Phase 1)** — promoted per the cold read's correct call:
   the biggest live hole on the act side.

**Plus one infrastructure gap the second cold pass surfaced, adopted here:
nave.pub#37** — `relay.nave.pub`'s write-allowlist rejects NIP-59 gift wraps
(ephemeral authors), so **the whole grant plane — Ngage drafts, steering
grants, credential grants — currently rides public relays only**. The sovereign
relay cannot yet carry the sovereign flow. That belongs ahead of new features.

*Ticket-index live reconcile (2026-07-23):* spec repo #4/#9/#10 **closed** (work
landed in spec PR #17) · nvoy#14 **closed** (shipped as Ngage; formalization →
nact#26) · **ngage has its own tracker** (#1 steering settings, #2 image
sourcing) · warm.contact has grown to ~20 open including the Quill grant
family (#19 capability grants, #20 contact-access grants, #42 steering +
voice-from-own-writing) · nact M-series close-out issues (#3/#4) stay open
pending the quiet week, by design.

**The full backlog is sequenced into phases — order and reasons — in
[`deploy/ops/PLAN.md`](../deploy/ops/PLAN.md) ("The sequenced roadmap").**

## 6 · Going-forward conventions
- **Issues-first, restored (Director, 2026-07-23).** Work = GitHub issues per
  repo, drafted for approval before code; **every commit is bookended by the
  issue(s) it addresses** (open it before, reference/close it in the commit or
  PR). This file is the map; the issues are the tickets. (The 07-21→23 sessions
  ran PR-per-change with per-PR Director approval — that remains the review
  mechanism, with an issue now anchoring each change.)
- **New agent** = mint key → relay allowlist → SOPS → Bitwarden note → registry row.
- **New box** = `newbox.sh` → on-box firewall → prove key login → `rekey.sh --lock`.
- **Secrets** live in Bitwarden + sealed envs; npubs/names only in this repo.
  Identity env/npub files never enter an app repo — the guard is now
  **pattern-based** (`*.nave.env*`, `*.npub.txt`) after a second identity's files
  slipped past a name-based rule (2026-07-23, warm.contact).
- **Never print box IPs, nsecs, or secrets** in chat, commits, or artifacts —
  boxes by role (main / relay+bunker / warm.contact), identities by npub.
- **Commit trailer:** `Co-Authored-By: Claude <noreply@anthropic.com>` — plain,
  no model identifiers anywhere in commits/PRs/artifacts.
- **Voice sources are evidence, never inference and never AI-assisted output**
  (AD-9). `luke/brief/` ships in a public image — nothing private goes in it.
