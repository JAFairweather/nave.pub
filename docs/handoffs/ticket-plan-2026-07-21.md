# Remaining ticket creation plan (approved by James 2026-07-21)

> **Now executable via CI:** `tickets.yml` (workflow_dispatch) runs
> `deploy/ops/create-tickets.sh` against `docs/handoffs/tickets-2026-07-21.json`
> — the verbatim ticket bodies from this plan, with dedupe + cross-ref
> threading built in. Needs secret `TICKETS_PAT` (fine-grained, Issues:write
> on the 8 target repos). Dry-run by default.
>
> **Transient handoff — delete once executed.** nave.pub #1–#15 are created;
> this file exists so any session (this one or a fresh one with the other
> repos attached) can create the remaining ~33 tickets mechanically. Blocked
> 2026-07-21 on session repo-access approval (add_repo permission gate).

nave.pub #1–#15 already created. This file holds the rest, verbatim-ready.
House rules for every body: NO nsec/secret/API key/IP; no model identifiers;
npubs/names only. Labels: priority (P0..P3) + area. Owner: jafairweather.

## Procedure per repo (once add_repo approved)
1. list_issues (open+closed) → dedupe: known existing refs — nact: #36 mail
   connector, #48 approval delegation, maybe #56 nave-connect; nvoy: #37 #43
   #44 #59 #60; luke: #26 (parked, do NOT touch); noir: check for an M3/AI
   Director issue; warm.contact: check product items before creating batch.
   If an "existing" number is missing/different, search by title keywords.
2. Create in the order below (cross-refs depend on it).
3. After ALL repos: annotate nave.pub docs/INVENTORY.md §5 with a compact
   "Ticket index (2026-07-21)" block listing repo → issue numbers, commit to
   main ("docs: link backlog §5 to the created tickets"), house trailer
   (Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com> + Claude-Session
   URL). Also drop a one-line cross-ref comment on nact#36 (see below) —
   frugal, single comment.

## ORDER 1 — nact (create M2 FIRST; its number back-fills later refs)

### N1 [P0, credential-migration] M2: Nactor credential-scope reader — deliver credentials as Director-signed grants
Context: The credential-grant migration's delivery half is built-but-never-used
(nact/docs/migration-status-2026-07.md — the "night of drift" correction);
consumption (broker, 5 providers) is live. The missing piece is the reader:
Nactor, for each runtime identity, fetches + NIP-44-decrypts credential grants
addressed to it and derives entitlements from grants instead of nave.env.
INVENTORY §3/§5 calls this "the one missing piece"; it unblocks M3–M7 AND
warm.contact/Quill (per-user hierarchy — nave.pub docs/quill.md §5).
AC: reader module + tests; entitlements sourced from grants when present (env
fallback, flagged in logs); grants surfaced in the runtime audit (AD-1);
credential-consumption-policy.md updated; migration-status doc updated.

### N2 [P1, credential-migration] M3 pilot: deliver telegram-luke as a real grant; retire its env copy
First credential through the delivery path end-to-end: Director issues the
scoped grant → Nactor reads it (M2) → Luke's comms bot works with the env copy
removed. Rollback documented. Depends: M2 (#ref).

### N3 [P1, credential-migration] M4: migrate remaining credentials to grants (gworkspace, anthropic, approval bots)
Repeat the M3 pattern for the rest of the 7 live credentials; retire env
copies one by one; runtime audit shows each. Depends: M3 (#ref).

### N4 [P2, credential-migration] M6: engine egress → /api/proxy (key leaves the engine env)
OpenClaw engine calls Anthropic via the transparent egress proxy
(/api/proxy/<provider>, credential injected from RAM) instead of holding the
key. INVENTORY §3 (NCP v0 organ exists; this points the engine at it).

### N5 [P2, credential-migration] M7: Nvoy MCP transport for grant delivery
Deliver/receive credential grants over the Nvoy MCP mount so agents and
consoles share one transport. INVENTORY §5 M-series tail.

### N6 [P1, hardening] Threat-model P1: freeze created_at at propose; re-verify event-id fingerprint before signing
From the WYSIWYS threat model (nact/docs/): the event a human approved must be
byte-identical to the event signed. Freeze created_at at propose time;
recompute + compare the event-id fingerprint immediately before signing;
reject on mismatch. AC: tamper test proves a mutated queued event cannot be
signed.

### N7 [P1, hardening] Threat-model P2: faithful render — kind/tags/hidden-character flags in approval surfaces
Approval cards render exactly what will be signed: kind, full tags, and
flags for hidden/bidi/homoglyph characters. AC: adversarial fixtures render
with visible warnings.

### N8 [P1, hardening] Threat-model P3: risk tiers — critical kinds cannot be one-tap approved
Tier the kinds; critical ones (key rotation, grant issuance, profile/relay
list changes) require a stronger ceremony than one tap (hold-to-confirm /
second factor / web-queue-only). AC: tier table documented + enforced.

### N9 [P2, hardening] Threat-model P4: channel binding as a scoped grant (nonce ceremony)
Bind approval channels to identities via a nonce ceremony recorded as a
scoped grant, so a hijacked bot/chat can't impersonate the approver.

### N10 [P2, hardening] Threat-model P5: Mini-App signer at nact.nave.pub/sign
The in-telegram Mini-App signer surface. AC: sign flow behind the nostr gate;
risk tiers (P3) respected.

### N11 [P2, ncp] NCP: per-identity gate on /api/proxy
The v0 egress proxy injects credentials but doesn't yet scope callers per
identity. Add NIP-98 per-identity gating + per-identity provider allowlist
(from entitlements). INVENTORY §3 open item.

### N12 [P2, ncp] NCP: data-grant read path (+ optional MCP-resource front)
The perceive-side "missing quadrant": let an on-box agent read NIP-DA scoped
data sets it holds grants for, via NCP; optionally front as MCP resources.
Design first (nact/docs/ncp.md), then a thin v0.

### N13 [P2, nops] Nops v0 design spike: swap relay-ops' SSH transport for grant + signed approval
Per nact/docs/nops.md + nave.pub docs/NOPS.md: today's restricted relay-ops
allowlist is proto-Nops over the wrong transport. Spec the swap: ops-runner
has its own identity; allowed verbs arrive as a scoped grant; exec happens on
signed approval; no SSH/CI secret. Deliverable: design doc + verb-grant
schema; build gated on James.

### N14 [P1, sign-in] Wire nave-connect into every app login + unified title bar
ONLY IF #56 is not an open issue in this repo (search first; it may live
elsewhere — if found anywhere, comment-link instead of creating). Module is
built+tested; bunker path proven (Armada). Wire into each app's login UI +
the unified title bar. Nvoy keeps local-key onboarding (gated "advanced");
Nact stays signer-only (James 2026-07-18 decision, AD notes).

### N15 — comment on existing #36 (mail connector), single comment:
"Sequenced as M5 in the credential-migration M-series (nave.pub
docs/INVENTORY.md §5). Depends on the M2 scope reader (<N1 ref>). Shape per
the pinned design: stateful-adapter × {app-password | OAuth}, verb-scoped
READ-ONLY IMAP enforced at the protocol, POST /api/connector/mail. First real
connector; also unblocks warm.contact's Gmail path (grant-to-app)."
(#48 exists → leave untouched. If #36 missing, create it with the above as
body, title "M5: mail connector — verb-scoped read-only IMAP (Nmail)",
[P1, credential-migration].)

## ORDER 2 — nvoy

### V1 [P0, protocol] Hierarchical re-grant: confirm a grantee identity can re-issue scoped sub-grants
The Quill linchpin (nave.pub docs/quill.md §5: user→Quill is the simplest
one-hop case) and the assumption under the central-identity fleet model
(warm.contact integration review §6). Determine whether kinds 30440/440/441/
10440 as specced support a grantee re-issuing a narrower grant today; decide
revocation-cascade semantics (rotating the mid-key kills descendants?);
prototype one-hop user→instance re-grant; feed conclusions to SPEC FUTURE.md
(attenuation/macaroon north star, SPEC §10) and to the warm.contact bootstrap
ticket (link after created). Refs: nact M2 (<N1 ref>).
(Existing #37 #43 #44 #59 #60: verify present; leave as-is; no comments.)

## ORDER 3 — nostr-scoped-data-grants

### S1 [P1, protocol] Shepherd PR nostr-protocol/nips#2411
Standing ticket: respond to review as it comes; concede bikesheds (kind
numbers, tag names), defend invariants (revocation-by-rotation, zero relay
changes, gift-wrapped grants, one-key recovery); consider a constructive
comment on the complementary PR #2258; attach the Nvoy 90-second
revoke-mid-conversation demo when the thread warms. Log activity here.

## ORDER 4 — warm.contact (dedupe product items against tracker first)

### W1 [P1, quill] Quill: per-user identity bootstrap — mint-or-BYO Director; mint Quill npub; issue the scoped grant
quill.md §3/§6: at signup mint the user a nostr identity (or accept BYO npub);
user = Director. Mint that user's Quill npub; register it; Director issues the
scoped grant (profile bundle + credentials). Depends: nact M2 (<N1 ref>) +
nvoy V1 (<ref>). AC: a fresh user ends with two identities + one revocable
grant, no nostr knowledge required.

### W2 [P1, quill] Quill: Swift grant plumbing — NIP-44 decrypt + NIP-98 sign; grant-backed SecretVault source
quill.md §5: add swift-secp256k1-based NIP-44 decrypt + NIP-98 signing to the
notarized app; new SecretVault implementation "fetch + decrypt the grant for
this Quill's npub" — zero calling-code changes (SecretVault is already the
indirection). Keychain custody WhenUnlockedThisDeviceOnly.

### W3 [P1, quill] Quill: add calendlyURL to ReconnectProfile; surface in coffee/meetup CTA
The one net-new profile field (quill.md §4): a booking link so coffee/meetup
drafts close with a real time instead of "let's find a time". Small,
shippable now, no dependencies. AC: profile field + editor; CTA uses it only
for coffee/meetup intents; guardrail tests extended.

### W4 [P2, quill] Quill: per-user npub lifecycle at scale — register / scope / revoke (design)
quill.md §6 open item: how many per-user Quill npubs are registered, scoped,
rate-limited, and revoked at scale (relay allowlisting policy, abuse, cleanup
on account deletion). Design doc.

### W5 [P2, nave-integration] Live Director grant → warm.contact npub; real Swift MCP transport (D-N1/D-N2)
The decided v0.5 §10 integration (grant-to-app via Nvoy MCP; central identity
minted): stand up the real path — live Director-signed grant to the
warm.contact identity; real MCP transport in Swift; per-instance topology per
D-N1/D-N2.

### W6–W13 [P2, product] (create individually IF absent from tracker)
- Google People sync (behind the brand-verification gate)
- Living-contacts profile-key pull
- Multi-device: per-device tokens
- CAPTCHA on the wave-in flow
- Custom domains
- Billing
- Launch loop
- Daily-brief agent
Each: 2–4 line body citing the warm.contact backlog (INVENTORY §5) + one AC
line. Keep zero-knowledge invariant note where relevant (relay brokers
ciphertext only).

## ORDER 5 — luke

### L1 [P2, roadmap] Employment roadmap (epic)
JOURNEY open ledger: checklist epic — CRM loop (Epiq / HG / Generation /
Insulet prep briefs + reconnection cadence), phone-node pairing, WhatsApp
(family + Esterones), tour watcher, world-models digest, BJJ log, the Nostr
channel. Split into child issues on demand. (#26 console pass 2 stays parked
— do not touch.)

## ORDER 6 — noir

### R1 [P1, game] M3: the AI Director (IF not already tracked)
INVENTORY §2a: Noir is 🟡 M1 of 6, M3 (AI Director) in progress — the
Director is itself an nvoy agent (grants as earned intel; key rotation as a
felt burn notice). If an M3 issue exists, skip.

## ORDER 7 — nherit

### H1 [P1, review] Review the six autonomous design decisions + legal/brand language pass
JOURNEY/INVENTORY: six autonomous decisions from the build handoff (§5 of its
handoff doc) await James's review; plus legal/brand language review before
wider release. AC: each decision accepted/reversed with a note; language pass
done; SECURITY.md revocation-physics wording confirmed.

## ORDER 8 — ntrigue

### T1 [P3, deploy] Deploy the Cloudflare MC proxy (optional)
Built but not deployed; keyless mode works today, so optional by design.
Deploy + document, or explicitly close as won't-do.

## After all creations
1. INVENTORY §5 ticket-index commit (see Procedure 3).
2. Reply to James: full table of repo → created numbers, dedupe outcomes
   (which existing issues were found and left alone), and the M2→…→Quill
   dependency spine with live links.
