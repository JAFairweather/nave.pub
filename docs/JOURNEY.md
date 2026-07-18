# The Nave Journey

*The historical record of an ecosystem built in the open — from one protocol
idea to a self-hosted agent, in ten days and counting. Owner: James Fairweather
(GitHub `JAFairweather`; nostr `jaf@dequalsf.com`). Compiled 2026-07-18 from the
git history of eleven repositories, three cross-thread handoff documents, and the
work of the agent-era build sessions.*

---

## The thesis

**Identity = Freedom.** One nostr primitive — the *scoped, revocable data grant* —
turns out to be enough to rebuild contacts, files, secure intake, legacy, games,
and agent delegation, each as a pure client of the same protocol, each where your
data answers to your keys and no one else's. The journey is the working-out of
that single idea across a family of applications, a design system, and finally a
delegated agent that lives on the protocol itself.

The through-line, stated as the creed Luke drafts from:
> *The signature is the authorization; the rotation is the revocation.*

---

## The arc — four movements

The whole ecosystem is **~10 days old** (first commit 2026-07-09) and, as of
2026-07-18, **445 commits across 11 repositories**. It reads in four movements.

### Movement 0 · The seed — warm.contact

Before any repo, the strategic frame: **warm.contact (MakeContact)** — privacy-
preserving contact collection framed not as an address-book product but as *the
self-maintained record + the grant*, with the address book as an **emergent
view**. Every handoff names this as the orbit the work moves around. The core
inversion — *nobody maintains contact data about anyone else* — is the seed that
became the protocol.

### Movement 1 · Protocol & apps sprint (Jul 9–11, ~119 commits)

The idea became infrastructure fast:

- **Jul 9** — NIP-DA drafted with **two independent implementations** (JS +
  Go) that interop live on public relays, plus Nontact as its first client. This
  is the founding commit of the whole ecosystem.
- **Jul 10** — three more apps reach M1 in one day: Nvelope, Notegate, Nvoy.
- **Jul 11** — Nherit (legacy vault) and Noir (the spycraft game) M1.
- The **PR to nostr-protocol/nips (#2411)** opens; James posts the announcement
  on nostr from Notedeck, Alby-signed, live on the protocol with his real key —
  verified opaque from the outside (a relay sees only ciphertext).

One protocol, one app per day, each riding the same primitive.

### Movement 2 · The Nave unification (Jul 13–14, ~143 commits)

The apps became a *system*:

- **Jul 13** — `nave.pub` is born: the hub site, the design language
  (`design/tokens.css`, seals, type), the common footer and cinematic intro.
  The **three essays** are written the same day.
- **Jul 14** — the single biggest day (80 commits): Ntrigue lands, and six repos
  receive the identical closing commit *"Nave design system, seal, Alby sign-in,
  common footer"* — the moment the portfolio became one branded family. It's also
  where the five smaller apps go quiet, finished.

### Movement 3 · The agent & ops era (Jul 16–18, ~124 commits)

Activity narrows to **luke + nact + nave.pub** — the shift from *building
products* to *operating a living system*:

- The deploy pipeline flips from noir to nave.pub (one domain, one VPS, one
  Caddy, cert carry-over).
- Luke is rebuilt: a nostr-delegated agent with a nostr-gated OpenClaw cockpit;
  the twice-daily propose→approve→sign→broadcast posting loop goes live.
- Nact/Nactor formalize the credential-broker runtime.
- The OpenClaw cockpit is cut over from Hostinger-managed hosting to the self-
  hosted nave network, then **upgraded to upstream 2026.7.1** with a repeatable
  playbook.
- Luke's engine is switched on: heartbeat, nightly **dreaming** (memory
  consolidation), a calendar beat, a unified morning brief, draft-only email.
- Jul 17's "night of drift" — a 74-commit spree candidly reviewed in
  `nact/docs/migration-status-2026-07.md` — surfaces that the credential-grant
  migration's *delivery* half stalled while its *consumption* half raced ahead.

nave.pub's own hub doc names the pivot: *"This is no longer a build project; it
is a publishing project."*

---

## The pieces — by layer

Status legend: **LIVE** (shipped + running) · **ALPHA** (feature-complete, draft-
protocol caveat) · **CORE-LIVE** (runtime carrying real traffic; frontier on
paper) · **SPEC** (complete draft) · **CONCEPT** (design/name only).

### Protocol

| piece | what it is | status |
| --- | --- | --- |
| **NIP-DA — Scoped Data Grants** (`nostr-scoped-data-grants`) | The root. Kinds 30440 (Scoped Data Set) / 440 (Data Grant, gift-wrapped rumor) / 441 (revocation) / 10440 (Grant Index). Symmetric scope keys, live-update by republish, revocation-by-rotation, **zero relay changes**. Draft NIP + JS & Go reference libs, interop-verified live. | **SPEC** — PR nostr-protocol/nips#2411 open |

### Applications (pure NIP-DA clients)

| app | one-liner | status |
| --- | --- | --- |
| **Nontact** | the no-maintenance address book (sharing as a contacts×scopes matrix) | **LIVE** |
| **Nvelope** | live folders + real revocation for encrypted docs (Blossom blobs, bearer invites) | **ALPHA** (v1 feature-complete) |
| **Notegate** | serverless secure tip intake — no server ever holds plaintext (PoW-gated, gift-wrapped) | **ALPHA** (v1 feature-complete) |
| **Nvoy** | scoped, revocable *data* delegation to AI agents, mounted as an MCP server; the Ledger; the 90-second revoke-mid-conversation demo | **ALPHA** |
| **Nherit** | family break-glass legacy vault: three tiers (live grants / escrow dead-man's-switch daemon / SLIP-39 paper shares); recover the whole estate from one paper QR | **ALPHA** (6 autonomous decisions await review) |
| **Noir** | *"A spycraft mystery game where information is the board."* AI game master, clues as NIP-DA scopes, mistakes burn assets by key rotation. Flagship demo of the stack. | **LIVE** (M1; M3 Director in progress) |
| **Ntrigue** | *"A phones-only party game of secrets, dilemmas, and blackmail."* Host-authoritative reducer, commit-reveal, robot guests, TV stage. Play-tested. | **LIVE** (v0.1) |

### Platform

| piece | what it is | status |
| --- | --- | --- |
| **Nave** (`nave.pub`) | the hub site, the design language (tokens, seals, type), reusable components — *and* the ops pipeline for the entire ecosystem (compose, Caddy, ops scripts, the migration + cutover runbooks). The operational center of gravity. | **LIVE** |

### Agent

| piece | what it is | status |
| --- | --- | --- |
| **Luke** (`luke`) | a nostr-delegated agent at `luke.nave.pub` + the nostr-signed gate to a private OpenClaw cockpit. Services: brain (proposer), poster (signer), calendar, morning brief, console, reveal, skin. Runs the live posting loop + daily briefs. | **LIVE** |
| **Luke's OpenClaw engine** | self-hosted cockpit on the nave network, upstream **2026.7.1-browser** (pinned); heartbeat on, nightly dreaming on, Nave-skinned. | **LIVE** |

### Runtime & safety

| piece | what it is | status |
| --- | --- | --- |
| **Nact** (`nact`) | *"Give an AI agent the ability to act on nostr — it drafts, you enact with a signature, your keys never move."* The propose→approve→sign→broadcast safety layer, extracted from Luke. | **CORE-LIVE** |
| **Nactor** | the on-box runtime + credential broker: NIP-98-gated `/api/broker`, RAM-only credential custody, OAuth minting, egress proxy. Five providers brokered live (anthropic, telegram×2, gcal, gmail). | **CORE-LIVE** |
| **Nsecret** (luke-reveal) | one-time, nostr-gated secret handoff (used to secure the box's SOPS age key off-box). | **LIVE** |

### Concepts (named, on paper)

| piece | what it is | status |
| --- | --- | --- |
| **Nmail** | verb-scoped IMAP protocol adapter in Nactor — read+draft-only *enforced at the protocol*, app password → RAM. Design pinned. | **CONCEPT** (design done; build queued) |
| **Nops** | a UI + runtime for server administration/ops — the `exec` actuator toward whole-box config. | **CONCEPT** |
| **NCP** (Nostr Context Protocol) | v0 running as Nactor's egress proxy; the broader concept on paper. | **CONCEPT** (v0 live) |

---

## The artifacts

### Essays (in `noir/docs/articles/`, finished, HTML-rendered, 8 figures)

1. **"Protocol as Fuel"** (~973 words) — how one small nostr primitive fueled a
   whole portfolio.
2. **"Cryptographic Boundary Conditions for World Models"** (~1,019 words) — how
   to let a language model build worlds without letting it cheat.
3. **"Noir: An Architecture"** (~1,348 words) — how a mystery game became the
   proving ground for an entire protocol stack.

**"Protocol as Fuel" is published** to the Substack (`jafairweather.substack.com`);
the other two are written and publication-ready. `ECOSYSTEM-HUB.md`: *"The three
articles and eight figures are written. Publish them on the Substack, cross-post
to nostr."*

### Key design records

- `noir/docs/STACK.md` — "The N-Stack," the biggest single doc (5,705 words);
  explicitly source material for the articles.
- `nact/docs/` — architecture, threat-model (WYSIWYS), migration, the
  credential-grant migration status review, scoped-action-approvals, ncp, nops,
  imap-adapter.
- `luke/brief/voice.md` — the voice-and-themes corpus (the two voices: Nave the
  project, Luke the agent; the creed; the content menu).
- `nostr-scoped-data-grants/SPEC.md` + `FUTURE.md` — the NIP and the
  request-is-a-grant-and-enact symmetry.

---

## The strategic threads

The through-lines that explain *why*, and where each stands:

1. **Sovereignty — "Identity = Freedom."** Your data answers to your keys.
   *Realized* across every app.
2. **The inversion.** Self-maintained record + grant; the view is emergent; N
   records, not N² copies. *The protocol's founding move.*
3. **Grants over everything.** Data → credentials → config → authority, all as
   scoped grants. *Data & credentials shipped; config/authority = the Nact
   architecture target (in progress).*
4. **Revocation as key rotation.** Honest physics: you can't un-tell a secret,
   but you can cut off every future update. *Consistent everywhere, stated
   plainly in every SECURITY.md.*
5. **Approve-before-act (WYSIWYS).** Agentic, but on a leash — the agent drafts,
   the human signs. *Live in Luke's posting loop; formalized as Nact.*
6. **Agent residency — box-bound → protocol-native.** v1 (keys SOPS-on-box) →
   v2 (keys to enclave/NIP-46) → v3 (identity + grants + mandate all as events;
   any box boots the agent). *v1 live; v2/v3 designed.*
7. **Zero servers to attack.** Zero relay changes; static clients; headless
   nostr peers. *The deployment invariant — protected in every redesign.*
8. **Build in public, quietly.** *The publishing pivot — the current movement.*

---

## The method (itself an artifact)

The *how* is as distinctive as the *what*, and repeats across every repo:

- **Spec → autonomous milestone subagents.** Specs authored in Google Docs, then
  built by background agents chained one-per-milestone, each committing + pushing
  per unit — so a killed session resumes cleanly from committed state.
- **Adversarial observer tests as house law.** Every flow ends by asserting what
  a hostile relay operator *cannot* see (no plaintext, no names, no grant graph).
- **Browser E2E on live public relays**, not just unit tests — real flows, cross-
  implementation read-back (browser edit → Go CLI reads it; console action →
  real MCP binary reads it).
- **Context-handoff documents** relaying full state between isolated threads —
  the very documents this journey is compiled from.
- **Per-unit commits + gitignored CLAUDE.md** decision logs for cross-session
  continuity.

---

## The open ledger

*What's genuinely outstanding, gathered across all threads — so nothing is
mystery-meat.*

**Protocol**
- Shepherd **PR #2411**: concede bikesheds, defend invariants; consider
  commenting on the complementary PR #2258; attach the Nvoy demo when the thread
  warms. *(The announcement drew no reply worth chasing.)*
- **"Protocol as Fuel" is live** on the Substack; publish the remaining two
  essays + cross-post to nostr.

**Apps**
- **Nherit** — six autonomous design decisions (§5 of its handoff) await review;
  legal/brand language review before wider release.
- **Ntrigue** — the Cloudflare MC proxy is built but not deployed (optional;
  keyless mode works).
- A footnote of destiny: Ntrigue briefly began life in **`19teamt`** — the music-
  site repo this very session runs from — before being moved to its own home.

**Publishing**
- Publish the essay set on the Substack + cross-post to nostr (one published so
  far). This is the headline of the current movement.

**Agent & runtime** (this thread's frontier)
- **Credential-grant migration (M1–M7)** — the honest correction from the night
  of drift: deliver credentials as Director-signed scoped grants and retire the
  env copies. Consumption half live; delivery half built-but-unused. First real
  grant (telegram-luke) is the pilot. *(nact/docs/migration-status-2026-07.md)*
- **Nmail** verb-scoped IMAP adapter — takes the Gmail app password off disk.
- **Luke's employment roadmap** — the CRM loop (Epiq/HG/Generation/Insulet prep
  briefs + reconnection cadence), phone-node pairing, WhatsApp for family +
  Esterones, the tour watcher, world-models digest, BJJ log, the Nostr channel.
- Console authoring pass 2 — parked (native cron covers scheduling for now).

---

## Where it stands, in one breath

A draft NIP with two live implementations and an open PR; seven applications
(two of them games) shipped as pure clients of it; a branded platform and design
system unifying them; a self-hosted, upgradable, dreaming agent running a live
posting loop and daily briefs under a nostr-signed gate; a credential runtime
holding secrets in RAM and handing them out by signature; three essays written
and a publishing runway ahead — all in ten days, all in the open, all answering
to one set of keys.
