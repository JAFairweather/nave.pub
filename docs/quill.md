# Quill — the warm.contact reconnect agent, and the Director's drafting hand

*Status: 🟡 the drafting **engine** is shipped; the **per-user identity** design
below stands; and as of 2026-07-22→23 Quill has a **second, live role**: James's
Quill is becoming the Director's own drafting agent (§9). Grounded in a full
read of `warm.contact` (`WarmCore/Rekindle.swift`, `Reconnect.swift`,
`ReconnectPriority.swift`, `docs/NAVE-INTEGRATION-REVIEW.md`,
`SPEC-ADDENDUM-v0.5-History.md §10`) and the Nave credential model (AD-6).
2026-07-20; §9 added 2026-07-23.*

**One line:** Quill is a per-user agent — its own nostr identity, minted for that
user — that drafts warm, personal reconnection replies in the user's voice from a
scoped bundle of the user's own credentials and profile, and never sends anything
on its own.

Named to fit the N-family cadence without pretending to be one more nostr app:
warm.contact keeps its own name and its own `wc1` crypto; **Quill** is the drafting
persona that lives inside it. (Prior working names: "Rekindle" for the engine,
"Vocalist" — retired.)

---

## 1 · Why Quill exists (the gap)

warm.contact is inbound-first: people wave at you, their card lands in your address
book, the server only ever brokers ciphertext. The **outbound** half — replying to
the people who reached in — is where a human stalls: dozens of "I should really get
back to them" notes that never get written. Quill writes the first draft of each,
in your voice, so all you do is glance, tweak, and send from your own Messages/Mail.

The engine for this already exists and is tested. What's missing is the part that
makes it *yours in a Nave sense*: a real identity for the agent, and a clean,
revocable way for it to hold the credentials and profile it drafts from — instead of
API keys pasted into a Keychain.

## 2 · What's already built (the engine — ✅)

`WarmCore/Rekindle.swift` + `Reconnect.swift` + `ReconnectPriority.swift`, 59 tests
green:

- **Draft in your voice.** Assembles a prompt from a `ReconnectItem` (the person +
  your per-person flavor) and a shared `ReconnectProfile`, calls Claude
  (`claude-sonnet-5`) **directly Mac → api.anthropic.com**, returns a channel-valid
  structured draft. The relay is never in this path — it runs on already-decrypted
  local data, preserving the zero-knowledge invariant.
- **The voice is a profile, not a prompt.** `ReconnectProfile` already carries
  `narrative` ("what I've been up to"), `signature`, and `homeRegion`. Edited once,
  it flows into every draft. *This is the seed of Quill's profile bundle (§4).*
- **Guardrails are pure and unit-tested.** Use only provided facts, never invent
  shared history; open by acknowledging *their* reaching out; one light CTA matched
  to the follow-up intent (now **Message / Virtual coffee / In person**); channel-correct length; genuine
  "how are you" beat. `flags:["insufficient_context"]` instead of fabricating.
- **Never auto-sends.** Draft → you edit → you approve → it sends from *your own*
  iMessage/Mail (`sms:`/`mailto:`), never a `noreply@`. Then retags the card
  From Warm → Warm-Contacted so the queue drains.
- **Knows who to answer first.** `ReconnectPriority` ranks the queue with a "why now"
  chip (draft ready / new / back-to-you-waited-N-days / overdue / nearby), floating
  the person waiting longest for a reply so nobody falls through.

So the *drafting* is done. Quill is the identity and credential story wrapped around it.

## 3 · The identity model (the new part — 🟡)

Two identities per user, both minted through Nave, plus the user's own root.

```
  user (human)                    Quill (the user's reconnect agent)
  ┌───────────────┐  Director     ┌────────────────────────────────┐
  │ nostr identity │──────grant──▶ │ own nsec/npub, minted per user  │
  │ mint-or-BYO     │              │ holds: profile bundle + scoped   │
  │ = the Director  │◀──approve────│ credentials, drafts, never sends │
  └───────────────┘  (send is     └────────────────────────────────┘
                      human tap)
```

- **The user gets a nostr identity — minted lazily.** warm.contact **mints it on
  first Quill-enable**, not at signup (James, 2026-07-21; signup stays
  identity-free — most users never think about nostr). The nostr-native minority
  **bring their own** npub instead. Either way, *the user
  is the Director* of their own little estate — the root the whole thing chains up to,
  exactly as `jaf@dequalsf.com` is for the Nave fleet.
- **Quill gets its own nostr identity, minted *for that user*.** Not a shared "warm"
  agent key — a distinct npub per user's Quill. This is the per-instance identity the
  integration review argues for (`Director → warm.contact central identity → each
  instance's own npub`), specialized: here the *user* is the Director and their Quill
  is the instance.
- **Authority = a grant the user signs, not a server ACL** (AD-6). The user's identity
  issues Quill a scoped grant; revocation is key rotation, not a database flip. Kill a
  Quill and every credential it held is dead with it — one revocable blast radius.
- **Console visibility (James, 2026-07-21).** A minted Quill appears in the **Nvoy
  Ledger at mint** (the grant-lifecycle lens, AD-1); it surfaces in **Nact only via
  the approval plane**, if and when a Quill action routes through it. AD-6 keeps
  Nactor out of Quill's call path, so the runtime audit staying empty of Quill is
  correct by design, not a gap.

This is the through-line to **Luke**: Luke is James's per-person brain that drafts in
his voice from granted credentials. **Quill is that pattern generalized to every
warm.contact user** — a per-person brain, one per human, minted on demand.

## 4 · The profile bundle (what Quill is given)

Everything Quill needs to draft *as you*, delivered as scoped grants to Quill's npub —
extending today's `ReconnectProfile`:

| Field | Today | Under Quill |
|---|---|---|
| `narrative` | ✅ in `ReconnectProfile` | the voice corpus — unchanged |
| `signature` | ✅ in `ReconnectProfile` | the email sign-off — unchanged |
| `homeRegion` | ✅ in `ReconnectProfile` | drives the "nearby → coffee" default — unchanged |
| **Anthropic key** | 🟡 pasted, in Keychain | **grant-to-app** — scoped credential to Quill's npub |
| **Gmail app-password** | 🟡 pasted, in Keychain | **grant-to-app** — scoped, read-only IMAP for history |
| **`coffeeLink`** (booking URL) | ✅ shipped 2026-07-21 | booking URL on the **Virtual coffee** option only (Calendly/Cal.com/any); **In person never carries it** |
| personal briefing | ↳ = `narrative`, extend | freeform "here's what's true about me right now" |

> **The booking link is the one genuinely net-new field** (an earlier note that
> "signature was new" was wrong — `signature` already ships). It shipped 2026-07-21 as
> **`coffeeLink`** — provider-agnostic; this doc previously said `calendlyURL`, and the
> shipped name wins (AD-8). With it in the bundle, a **Virtual coffee** draft closes with
> a real booking link instead of a vague "let's find a time".

## 5 · How the credentials arrive (the decided posture)

**Grant-to-app, applied uniformly** — the decision recorded in
`warm.contact/docs/…v0.5 §10` and the integration review §5.2:

- Quill's identity **decrypts a NIP-44 grant addressed to its own npub**, holds the
  scoped credential locally (Keychain `WhenUnlockedThisDeviceOnly`), and **calls the
  provider directly** (Anthropic, Gmail). Nave sees the *grant issuance*, never the
  content.
- **Why not broker.** The drafting prompt contains contact plaintext (names, the note
  they sent, shared history). Brokering Anthropic through Nactor would put that
  plaintext through shared, multi-tenant Nave infra in transit — breaking
  warm.contact's core zero-knowledge invariant. Grant-to-app keeps every byte of
  contact content off Nave; only Anthropic ever sees the prompt (the disclosed v0.4
  posture). We apply it uniformly for one coherent story rather than a broker/grant
  split per provider.
- **The plumbing is already shaped for this.** `WarmCore/SecretVault.swift` is a
  credential-source indirection ("give me a secret / store / delete") with the Keychain
  as its only implementation today. Quill adds one new implementation — *fetch +
  NIP-44-decrypt the grant for this Quill's npub* — and **no calling code changes.**

**The build-order linchpin** (integration review §6, still open on the Nave side):
can a per-user identity, itself a grantee, **re-issue scoped sub-grants** the way the
fleet's central-identity model assumes? For Quill the hierarchy is
`user (Director) → their Quill (instance)`, which is the simplest one-hop case — but it
needs the same grant-delivery reader that Nave's own M2 (Nactor credential-scope reader)
is blocked on. **Quill and the Nave credential-migration M-series unblock each other.**

## 6 · What's decided vs open

**Decided**
- Name: **Quill** (engine was "Rekindle"; "Vocalist" retired).
- Drafting engine ships as-is (Mac → Anthropic direct, `claude-sonnet-5`, no auto-send).
- Credential posture: **grant-to-app, uniform** (never broker contact plaintext).
- Two identities per user (the human = Director; their Quill = instance), both minted
  through Nave; mint-or-BYO for the human.
- Profile bundle = `ReconnectProfile` + Anthropic key + Gmail app-password + **`coffeeLink`** (shipped).

**Open (the build queue)**
- ⬜ Nave-side: confirm per-user hierarchical re-grant; the M2 grant-scope reader.
- ⬜ Client crypto: NIP-44 decrypt + NIP-98 sign in the Swift agent (`swift-secp256k1`)
  — added to a lean, notarized app.
- ⬜ Per-user identity bootstrap: mint-or-BYO **on first Quill-enable** (lazy mint —
  James 2026-07-21); register Quill's npub; issue the scoped grant.
- ✅ ~~Add the booking link to `ReconnectProfile`~~ — shipped as `coffeeLink`; the
  follow-up model is finalized as **Message / Virtual coffee / In person**, the link
  riding Virtual coffee only (warm.contact#7 **closed**).
- ⬜ Lifecycle: how a Quill npub is registered, scoped, and revoked at scale (many users).

## 7 · 2026-07-21 addendum — warm.contact feedback absorbed

Reconciliations from the warm.contact agent's integration pass (naming recorded
as **AD-8** in `nave-architecture-decisions.md`; James can override):

- **`coffeeLink`** is the shipped booking-URL field name (`calendlyURL` in this
  doc superseded). Follow-up model finalized: **Message / Virtual coffee /
  In person** — the link rides Virtual coffee only, never In person
  (warm.contact#7 closed).
- **"Director"** stays the *human root authority* ecosystem-wide (James for the
  fleet; the user for their Quill). Noir's AI game master is always qualified
  **"Noir's Director"** outside the game — the ECOSYSTEM-HUB §0.6 pattern.
- **Scope-name namespace** `profile:* · credential:* · data:* · capability:*`
  blessed as the grant-scope convention (their `profile:voice`/`profile:policy`
  fit); Nvoy ledger/console should render it (folds into nvoy#2).
- **`capability:*`, sharpened (2026-07-21):** the **management layer** — issuing,
  holding, rotating a capability grant — is itself a NIP-DA scoped grant and
  expressible **today**; only the **per-action approval handshake** is the
  not-yet-a-NIP sketch. warm.contact's interim-local policy object covers exactly
  that handshake half and converges when Scoped Action Approvals lands
  (build-first, INVENTORY §1).
- **Lazy mint (James, 2026-07-21):** the user's identity is minted on **first
  Quill-enable**, not at signup — §3/§6 updated.
- **Console visibility (James, 2026-07-21):** Quill-on-mint → **Nvoy Ledger**;
  **Nact via the approval plane only** (AD-6 keeps Nactor out of the call path).
- **§5's linchpin, corrected state:** hierarchical re-grant is design-CONFIRMED
  (`warm-contact-nave-review.md` Q1; the console's "＋ grant to another identity"
  is the mechanism). What still gates the Quill bootstrap (warm.contact#5): the
  live one-hop user→Quill **prototype** + revocation-cascade semantics (nvoy#1)
  and the M2 delivery reader (nact#1).

## 9 · 2026-07-22→23 addendum — James's Quill, the Director's drafting hand

The architecture revisit that followed Ngage going live settled Quill's second
role, and it is the same pattern pointed the other way.

**The problem it solves.** Luke was carrying two jobs on one approval path:
drafting as *himself* (Telegram approval, box-signed) and drafting *for James*
(who signs in his own hand). An agent that is sometimes a persona and sometimes
a ghostwriter, on one route, is the overloaded-agent condition — and Luke's own
charter draws the line already: *"never speak as him or post for him."*

**The decision (AD-10).** Drafting-for-the-Director is **Quill's job**, not
Luke's. Each identity binds to one approval path chosen by where its signing
key lives: box-custodied keys → Nactor → Telegram; the Director's drafts →
**Ngage**, delivered as `draft:post/*` gift-wrapped grants only his npub can
read, signed by his own hand. Steering comes back the other way as a
`steer:draft` grant — editable per identity, no deploy.

**Why Quill and not a second box agent.** Two keys wearing one name are not one
agent. Quill already *is* the per-person drafting pattern with a Keychain-held
key that never leaves the device — running the Director's drafting there makes
"approval happens where the signing key lives" literal: the drafts are prepared
on the same machine that holds the key that signs them.

**Build Quill's drafter as an *actuator*, not a Mac script.** Under NCP
(`nact/docs/ncp.md`) reads are data grants (MCP resources) and verbs are Scoped
Action Approvals (`nact/docs/scoped-action-approvals.md`, MCP tools). Drafting is
one such verb: `actuator(template, grant) → draft`, a sibling of
`publish`/`exec`/`connector`. Factor it so the **surface** — a reconnect reply, a
social post, a PR body — is a *parameter, not a fork*. That boundary is what makes
Quill portable beyond reconnect replies and keeps this from being a one-off; a
second stubbed surface ("draft a post") is the cheapest proof it holds.

**State of the port (the build queue, issues-first):**
- ✅ The interim scribe runs the flow end-to-end from the box (drafts → Ngage →
  first sovereign post signed 2026-07-22; steering grant honored, with
  `brief/jaf.md` — the evidence-based voice file — as the standing default).
- ✅ **`canonical-quill` identity minted** (npub in `IDENTITY-REGISTRY.md`);
  its sealed env lives with the deploy secrets, **never in the app repo** — the
  repo's ignore rule is now pattern-based so no future identity slips past it.
- ✅ **Ngage is a first-class approval path in Nact** (nact#31, 2026-07-22): the
  routing board binds each identity to exactly one path and shows Quill's as
  ✋ Ngage — the Director's own hand — beside the box gate (AD-10, `lib/routing.mjs`).
- ⬜ **Mac-side port (warm.contact#43)** — Quill drafts locally under launchd;
  Anthropic access via a `credential:anthropic` scoped grant (not a pasted key);
  key in the Keychain (`WhenUnlockedThisDeviceOnly`), nsec never surfaced;
  draft-grants (`draft:post/*`) to the Director's npub. **Held for the Director's
  explicit go — it runs on his machine and holds his key material.**
- ⬜ **Swift grant plumbing (warm.contact#6)** — NIP-44 decrypt + NIP-98 sign
  (`swift-secp256k1`); a grant-backed `SecretVault` source ("fetch + decrypt the
  grant for this Quill's npub") with **zero calling-code change** — SecretVault
  is already the indirection. Prove revocation-by-rotation and adversarial-observer
  (Nave learns nothing of the prompt) in tests.
- One persona, **per-device keys** — Mac-when-awake and box-when-not both draft,
  each device holding its own Keychain key; no key is ever copied.

**The through-line, updated.** Luke is the pattern Quill generalizes — and the
Director is now Quill user #1: the reconnect agent that drafts *your* replies in
*your* voice under *your* revocable grant is the exact machinery that drafts his
public posts. One design, both directions, no new trust anywhere.

## 8 · The one-paragraph pitch

Everyone has a list of people they mean to get back to and never do. warm.contact
already collects the people who reached in to you without any server ever seeing who
they are. Quill closes the loop: a small agent, minted just for you, that knows your
voice and holds — under a grant you can revoke with a keystroke — just the credentials
it needs to write the first draft of each reply and offer a real time to meet. You stay
the Director. It never sends. You glance, tweak, and hit send from your own phone. It's
Luke, for everyone.
