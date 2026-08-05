# Agent-governance refactor — one agent, two planes, N slices

**Status:** spec · **Decided:** 2026-08-05 (AD-12) · **Tracking:** #110
**Baseline:** verified against `origin/main` — nave.pub `e22f5a4` · nvoy `3260a3c` · nact `7087322` · waggle `689b020` · ngage `65c8456`

The rulings are in `nave-architecture-decisions.md` AD-12; the names are in
`architecture/06-glossary.md`. This document is the *why*, the *evidence*, and the
*sequence*.

---

## 0 · The symptom and the cause

The Director reported: **some agents show in Nvoy that do not show in Nact.**

That is not a bug in either app. Both are behaving exactly as built. It is the
visible edge of **seven disjoint stores with no join key** — and the reason it
presented as a display glitch rather than an architecture problem is that a
*missing* row is unobservable. You cannot see an absence.

| # | store | shape | keyed by | written by |
|---|---|---|---|---|
| 1 | `nvoy_agents` on the delegator's `10440` | `{ pub, added_at }` — **the whole record** | pubkey | the Nvoy console, two call sites |
| 2 | Nact's env scan ∪ imported map ∪ `nact-config.json` | `{ key, handle, npub, signer, status, source, activated }` | **lowercased env-var name** | the box's filesystem and environment |
| 3 | `/etc/nvoy/instances/<id>.json` | ~20 fields — service users, four UIDs, worker digest, grantors, carriers | instance id | an on-box tool, by hand |
| 4 | public `440`s carrying `da-cap` | a capability + a salted subject hash | grantee pubkey | any app in the family |
| 5 | `nvoy_derived_children` | parent→child lineage, cascading | scope | the Nvoy MCP server |
| 6 | Ngage's `localStorage` | two flat lists of bare hex | pubkey | the Ngage browser tab |
| 7 | waggle's `config.json` | roster + policy fields | pubkey | the bridge, and unsigned channel replies |

**Nvoy keys on a pubkey. Nact keys on the name of the environment variable that
holds the secret.** There is no join key between them, and no code anywhere performs
a join. `HANDLE_OVERRIDES = { nactjaf: 'nact_jaf@nave.pub' }` in `nactor.mjs` exists
for exactly one reason: to paper over that mismatch for one identity, by hand.

The only registration bridge, `nact/nactor/request-register.mjs`, is
**one-directional** and says so in its own header: an identity publishes an access
request, the Director approves it *in the Nvoy console*, `nvoy_agents` gains a row.
Nothing in Nact changes. So the precise condition for the reported symptom is:

> An agent appears in Nvoy but not in Nact **iff** it has (a) no `<NAME>_NSEC` on the
> Nactor box, (b) no imported role-key credential scope, and (c) no director-path
> registration — three separate manual acts, on a different substrate, from the one
> act that put it in Nvoy.

Nothing detects the divergence, because nothing is looking for it.

---

## 1 · What the model was supposed to be

From the Director:

> Nvoy manages agents and the **data** granted to them. Nact manages agents and the
> ability to grant their **action** — discrete actions, or durable action
> permissions. These are **overarching planes that see ALL agents and delegations**.
> Then **application-specific slices** (waggle, Ngage) manage only the data grants
> and actions specific to that application, and illustrate the app-specific routing
> logic derived from those grants.

The docs already agree with this. `INVENTORY.md`'s spine table has perceive/act as
the two directions of one primitive; `PROJECTS.md` calls Nvoy "the Grant Ledger —
the source of truth for all grants"; `ONBOARDING.md` states plainly that *every*
grant belongs in the Director's `10440` and that apps which issue grants write that
index.

**The model is right. It is almost entirely unbuilt.** Of the seven stores above,
exactly one app writes the index the docs designate as the source of truth for all
grants — Ngage, for one of its two directions.

---

## 2 · Evidence, per surface

Each item below was verified against `origin/main` on 2026-08-05, after a
`git fetch` found every local clone behind.

### 2.1 Nvoy — the grant plane, with an agent-shaped front door that doesn't reconcile

- **An agent is a bare pubkey in a list.** `console/agents.mjs` — `{ pub, added_at }`
  and nothing else. No name, no purpose, no type, no custody, no runtime binding.
  Names come from **live kind-0 lookups, never stored**, which means whoever holds an
  agent's key controls its label in the Director's own console.
- **Two write-only composers.** `Delegations` and `Authority` are forms with no list.
  The Director can issue but not see. The Ledger is the only place any state is
  visible, and it is roughly 4× the code of every other tab combined.
- **The `Agents` tab is a dead end.** Clicking an agent does nothing; its delegation
  chips leave the tab. **There is no agent detail view anywhere in the estate.**
- **The Type facet greps display strings.** `console/ledger.mjs` classifies every
  grant with `n.includes('steer')` and `/nactjaf|approval/` — the primary semantic
  filter on the main screen, containing a **hardcoded identity name**. A facet that
  greps a display name lies the moment someone renames an agent.
- **`Grantee` appears twice** in the filter rail, for two different controls. The
  real defect is that "group by" and "filter by" are unlabelled siblings.
- **AD-8's blessed namespace is unimplemented.** `profile:`, `data:` and
  `capability:` appear nowhere in the repo, though AD-8 named this console as the
  consumer. Only `credential:` (soft), `derived:` and `draft:` (both hard) are
  enforced anywhere.
- **Derived-grant lineage is persisted and never read.** `mcp/src/subgrants.ts`
  fully records parent→child derivation and cascades revocation recursively; no code
  path in `console/` reads it. So attenuation — the one mechanism that lets authority
  narrow as it spreads — is invisible.
- **Nvoy is already the action plane's issuance surface, under three names.** The nav
  says `Authority`, the code and confirm dialog say *"the universal Access plane"*,
  the Ledger files the result under type `external`. And
  `console/task-authority-lib.mjs` says in its first two lines that both this screen
  and *"a future Nact operation approval"* use the same event shape. The shared
  primitive shipped; the consumer was never built.

### 2.2 Nact — the act plane, organised around plumbing

- **The tab order encodes the wrong priority.** `Queue · Agent Identities · Channels ·
  Routing · Directors · Deployment · Policy · History` — three of the first six are
  plumbing, the most heavily engineered screen is a wiring matrix, and the Queue (the
  entire point of the product) is a flat list with no grouping and no identity filter.
- **`+ Add identity` fabricates identities.** Two of its three signer options
  generate a random `npub1…` string, push it into local JS state, and never call the
  API — while `nactor/README.md` already admits V1 cannot provision a custodial key.
  `Remove identity` and `Revoke authority (rotate key)` are likewise local-only, with
  no API call behind either. **This is a direct AD-11 violation** — *"a control plane
  never renders fabricated approvals as if real"* — in the most consequential place in
  the fleet.
- **`raised` is fetched and thrown away.** `/api/state` returns the director-path
  drafts sitting on the Director's desk; `app.html` never mentions the field. Every
  director-path proposal is invisible in the plane whose entire purpose is proposals.
- **No hash routing at all.** Tab state is discarded on click, so nothing here is
  deep-linkable and no cross-plane link can land.
- **No durable action object exists** — deliberately. `README.md`, `DESIGN.md` and
  the Naction case page all carry *"No standing 'post whenever' authority — ever."*
  What Nact *does* persist instead is an **activation** (a Director signature in
  box-local JSON — not a grant), an **entitlement** (derived from relay grants every
  five minutes), and **channel coverage** (routing, not authority). Three
  designed-but-unbuilt durable objects sit behind it: a channel-authority grant with a
  schema and no integration, the `capability:*` namespace passing through inert, and
  the Scoped Action Approvals sketch.
- **What is best here should not be touched.** `sign.html` — one artifact, no nav, an
  honest footer — is the best-designed surface in the estate, and it shares the
  ceremony spec with the runtime *so a signing surface can never show a softer picture
  than the review console.* That doctrine is the model for §5's shared components.

### 2.3 waggle — further ahead than the rest, and the reference for two things

An earlier draft of this work described waggle's console as a single scrolling page.
That was ~40 commits stale. Current state:

- **A four-tab slice console**: `Access` · `Following` · `Config` · `Setup`, using a
  **third** tab idiom (`.console-tabs a.active`) alongside nvoy/ngage's `.tab.active`
  and nact's `.tab.on` — none of which is defined in `components/` or `design/`.
- **Signed owner commands, and no host access.** The bridge publishes signed public
  state (kind-30078, `d=waggle-control-state`); the owner issues narrow signed
  commands (`waggle-control`, `waggle-watchlist`) with an approver check, a replay
  watermark and freshness bounds; task routes ride a sealed wrap so *"relays never
  learn the channel, participant, sender, or mention."* Its own framing —
  *"the bridge signs this record so the console can prove what it knows without
  becoming a remote shell"* — **is the invariant AD-12 adopts estate-wide.**
- **The sealed task-route lane is the reference implementation for a command lane:**
  wrap-id dedup before any decryption, a decrypt budget charged before the first
  decrypt, the approver check gating the *second* decryption, the rumor id recomputed
  against its own hash, canonical-key checks at every layer, a refusal when the
  participant is not admitted, and legacy plaintext commands hard-refused.
- **Its capability→English map is the best copy in the estate** and belongs to the
  whole fleet: `admit → "Post into the channel"`, `task → "Take tasks from you"`,
  `task+act → "Take tasks, and act on them"`.
- **Its failure copy is the register everything else should adopt:** *"No relay
  answered. Nothing is shown because nothing could be verified — this is not the same
  as 'nobody is admitted.'"*

Four gaps remain, and they are the Wave 1 work:

1. **An admission is invisible in the grant plane.** `Admit` publishes a public `440`
   and nothing else. The `10440` kind appears in the tree only as a constant
   declaration and is never written — by the bridge, the console, or the CLI. This is
   not merely a cross-app gap: waggle's own `SPEC_EXTERNAL.md` §4.1 specifies that the
   console signs "440 issue / 441 revoke / **10440 index**", and §4.1.1 says the
   retained-grantee set on rekey is read *"from the live 10440 index."* **With no index
   ever written, the S2 rekey path has no roster to read.**
2. **Three of four documented capabilities cannot be issued here.** The docs now
   describe `admit`, `task`/`task+act`, and `task-relay`. The console's label map knows
   three; the cap is **inferred from the shape of the subject field**; `task+act` has
   a label it can never produce; `task-relay` has neither label nor path.
3. **The trust gradient is invisible.** The bridge computes and names five lanes —
   `mirrored feed`, `granted participant`, `standing follow`, `reply to our note`
   (quarantine), and a silent drop. The console shows none of them, so "why didn't
   this reply show up?" is answerable only by reading source.
4. **The moderation verbs grant authority off any signed path.** Of six in-channel
   verbs, only `mirror|unmirror` has a signed twin. `follow` promotes a stranger from
   quarantine to standing trust — the largest single trust jump the bridge makes — on
   an unsigned channel message; and `follow` and `mute` do not even refresh the signed
   counter an observer would watch, so the one signal that would reveal the change is
   suppressed by omission. Not an outsider path (the handler gates on the approver
   roster), but authority with no signed record.

**waggle's spec already specifies the object this refactor introduces.**
`SPEC_EXTERNAL.md` §4.1: the admin UI's *"core object is a per-identity trust record
with (a) an admission-mode toggle — quarantine ⇄ standing grant — and (b) a
channel-scope selector."* What shipped is a grant ledger: one row per grant, no
per-identity record, no toggle, and a free-text scope field. **This refactor completes
that spec; it does not invent it.**

### 2.4 Ngage — the template, and the half that is invisible

- **`nvoy-index.mjs` is the only cross-plane mirror in the estate.** On a steering
  publish it writes the issued row, the ledger event *and* the agent-registry entry,
  and it reports the outcome honestly, in words, on the row:
  `· recorded in Nvoy` / `· ⚠ not recorded in Nvoy (retry to mirror it)`.
  **That pattern is the template for every cross-plane write in this refactor.**
- **But only one direction.** Every inbound `draft:` grant — each a real NIP-DA grant
  an agent issued to the Director — is recorded **only in `localStorage`**. Half of
  this plane is invisible in the grant console by construction, which is precisely why
  the honest warning pill was doing so much work.
- **Its copy is the register for empty and failure states** and is promoted in §6:
  `an empty desk, by design` · `the desk is clear` · `awaiting your hand` ·
  `✒ unpenned — refused` · `malformed — inert`.
- `Trusted agents — the pens` — the answer to "who may write in my name" — is
  currently a list of bare hex keys inside a settings page.

### 2.5 The shared layer — copy-vendored, and undetectably drifting

- The system is **vendored by rule**: apps inline it because they are no-build static
  clients. **Nothing detects drift**, and the cost is already paid three ways:
  Nvoy and Nact use `--panel2` while `tokens.css` defines `--panel-2` (silently
  separate variables); Nvoy, Nact and Ngage have **no light theme at all** purely
  because their copies are old — `tokens.css` has shipped both light mechanisms for
  some time; and every titlebar provenance stamp in the fleet is **stale while the
  bodies are current**, because the stamp is prose rather than a hash.
- `components/nave-login.mjs` is built, documented, and adopted by **zero** apps. Its
  documented twin `nave-login.html` does not exist.
- The estate has already been bitten by exactly this: the Caddyfile records a waggle
  console copy that drifted, *"rendered perfectly and failed only at the moment
  someone tried to sign in."*
- **Nothing about the design system was binding** until this refactor: `DESIGN.md` was
  the only normative UI text and `STANDARDS.md` never cited it. Now §7a does.

---

## 3 · The model

The rulings are AD-12. In brief, and in the order they matter:

**An Agent is one key.** `key + custody + authority + runtime`, where only the key is
its identity. Custody decides the Approval Path. **Authority is never a property of
the Agent** — it is the grants it holds, looked up in the Ledger. The join key is the
lowercase hex pubkey, everywhere.

**agent ≡ identity ≡ role key ≡ pen ≡ deliverer ≡ granted participant ≡ admitted
author.** One object; the differences are roles inside a slice. This single ruling
retires the entire vocabulary-collision list, which spanned four apps and five names
for the act side alone.

**An Action Grant has two modes, not two types.** Capability (`standing`) confers the
right to *propose* in a class, with a mandatory envelope. Approval (`discrete`) is one
tap over frozen bytes. The doctrine is amended to *"no standing authority to sign;
standing authority to propose — always narrow, always short-TTL, always rate-limited,
always revocable,"* and the reason is structural rather than a matter of taste: **a
durable grant cannot authorize a signature**, because WYSIWYS binds to a fingerprint
over bytes that do not exist at issuance. It can only ever confer queue entry plus the
gate tier. The estate already had durable authority in three places, so the real choice
was *durable and named* versus *durable and hidden*.

**`da-cap` enforces; `capability:*` describes.** Two mechanisms, kept apart on
purpose. The `da-cap` check on a public `440` works **without any key**, default-closed
— fold it into a namespaced scope name and the enforcer suddenly needs a scope key.
And `da-scope` is a salted hash precisely so the subject stays private; a renderable
namespace is by definition not a hash. Enum closed at six values.

**A slice is a filter, not a fork.** Universal = the slice component with the trivial
predicate. Same code, different predicate — which is what makes "shows in one, not the
other" *impossible* rather than fixed once. Slices may define roles, routing views and
local policy; they may not define identity, grant shapes, capability enums, approval
paths, or a second roster.

**One registry, in the delegator's `10440`**, projected to headless slices as a data
grant. AD-6's two tests force grant-to-app and not the broker: the roster is content
sensitive to Nave, and the bridge is off-box. So revoking a slice's view of the roster
is a scope rotation — a mechanism that already exists.

### The fate of all seven stores

| # | store | becomes | migration |
|---|---|---|---|
| 1 | `nvoy_agents` | **AUTHORITY** (upgraded schema) | additive; legacy rows read as `custody: foreign`, handle from kind-0 marked unverified. No rewrite pass |
| 2 | Nact's env ∪ imported ∪ config | **PROJECTION** — except `activations`, which stays authority, **re-keyed by pubkey** | the env scan becomes *custody discovery*: derive the pubkey, join. `identitiesMeta` and `HANDLE_OVERRIDES` deleted. An on-box key with no registry row renders `unregistered key on box` |
| 3 | instance manifests | **AUTHORITY for runtime facts — does not merge** | gains one field, `agent_pub`. Different lifetime, different secrecy class (service users and UIDs must never reach a UI), different writer. Two objects, one join key |
| 4 | public `da-cap` `440`s | **AUTHORITY — the signed evidence** | none. `capgrants.mjs` is already app-agnostic and becomes the estate-wide reader |
| 5 | `nvoy_derived_children` | **AUTHORITY for lineage — and finally read** | none to the data; the console gains the reader |
| 6 | Ngage's two lists | **DELETED** | first load maps each key into `slices.ngage.roles`, then stops writing |
| 7 | waggle's roster fields | **PROJECTION** for roles; policy fields stay | every roster mutation must publish a signed event; the `grantors`-defaults-to-`approvers` collapse is removed |

### The acceptance test, stated so it can fail

> Register one agent in Nvoy → it appears in Nact within one poll, with its approval
> path **derived from custody**, and in the waggle/Ngage slices **only if** it holds a
> slice-scoped grant.
>
> Converse: no agent appears in Nact that is absent from the registry; on-box keys
> without a registry row render `unregistered`, never as agents.

---

## 4 · The user experience

### 4.1 The decision inventory

Twelve decisions the Director actually makes. **Eight of them need the same five
facts** — identity, custody, approval path, what is held, liveness. That is not eight
screens; it is one screen referenced eight ways, and it does not exist.

| decision | owns today | should own |
|---|---|---|
| should this stranger get in | split Nvoy / waggle — genuinely dual-surfaced | **both, each saying which it can act on** |
| what may this agent see | Nvoy (write-only) | **Nvoy** |
| may it do this one thing now | Nact + Ngage; Nact drops `raised` | **where the key lives (AD-10)**; visibility is universal |
| may it keep doing this | Nvoy `Authority` — cannot list or revoke | **Nact `Actions`** |
| where does its approval go | scattered across three Nact tabs | **one field on the agent** |
| who is this and what does it hold | **nobody** | **shared agent page, both planes** |
| is it alive | buried three levels deep in a collapsed Ledger card | **agent page, top level** |
| cut it off | Nvoy Ledger (the only real revoke); Nact's is theatre | Ledger + slice; agent page as entry |
| did my words go out in my hand | Ngage | **Ngage — best in estate, do not touch** |
| why didn't this reply show up | **nobody** | **waggle `Routing`** |
| what did it actually do | Nact History + Nvoy Ledger | **keep both, source-stamp every row** |
| bring a new agent into existence | Nact — **fabricates npubs** | **Nact, honestly gated** |

### 4.2 Navigation

- **Plane switcher in the shared titlebar** — additive `{planes, activePlane}`; absent
  the option, every app renders exactly as today. Taglines become the two verbs, which
  are the Director's own words rather than new nouns: Nvoy *"what your agents may
  see"*, Nact *"what your agents may do."*
- **`#agent/<npub>` resolves on all four surfaces** — the join key becomes the deep
  link. On a plane it opens the agent page; on a slice it highlights that row, because
  a slice must never pretend to a full agent view it cannot populate.
- **Badge law:** a count badge means *a human decision is waiting*. Nothing else may
  carry one. Exactly four in the estate.
- **Vocabulary is settled by subtraction:** `Authority`, `Access` as a plane name,
  `external` as a Ledger type, and `Naction` as a code-level word (it appears in one
  HTML comment) all die. One survivor: **action grant**.

### 4.3 The agent page — the missing screen

`components/nave-agent-detail.mjs`, vendored into all four surfaces.

**The honesty contract is the load-bearing decision.** The view assembles from up to
six stores, most unreachable from any one plane. So every section carries a
**three-state source stamp**:

1. `from your Grant Index · 4 rows`
2. `nothing here` — an affirmative empty, shown only when the store answered
3. *"Nact did not answer. Nothing is shown because nothing could be verified — this is
   not the same as 'nothing granted.'"*

State 3 is a **skeleton with a reason**, never a zero and never a blank. A zero is a
lie; a blank is a shrug. This is AD-11's "disconnected means empty" made visual —
empty of *claims*, not empty of *pixels* — and turning it into a component is the only
way the rule holds across four apps.

Sections: identity (with kind-0 marked an unverified hint) · key custody · **approval
path, derived, with the custody reason** · voice · runtime (read-only) · slices and
roles · data granted · actions granted · granted onward (the lineage, rendered for the
first time) · **running now** (promoted from three levels deep in a collapsed Ledger
card) · recent activity, every row source-stamped. `Revoke everything…` **enumerates
before confirming** and states its limits — what it does not rotate, and which stores
did not answer.

### 4.4 Nvoy — five tabs to four

`Agents` (default) · `Requests ②` · `Ledger` · `Settings`

**Rule: no composer is a destination.** Both `Delegations` and `Authority` are forms
with no list — the estate's most consistent UX failure. Every composer becomes a
drawer over the list of the things it makes, and closing it returns you to your new
row, highlighted. The stepped progress messages are excellent and move in verbatim,
because they belong *over* the list, so the last step lands visibly on the row it
created.

`Requests` is promoted from a buried card to a badged tab, and gains waggle's
`asked by <npub…>, not the key being admitted` pill — the single best anti-phishing
control in the estate, which this console lacks. The Ledger keeps its name (AD-1) and
gains: named rail sections (dissolving the duplicate `Grantee` rather than renaming
around it), a **tag-based** Type facet, `Expand all`, auto-open for groups that need
attention, and the hard-expiry honesty banner moved **above** the countdowns it
qualifies.

### 4.5 Nact — decisions first, plumbing behind a divider

`Queue ②  Agents  Actions  Routing  History │ Channels  Policy  Deployment`

The divider is not cosmetic: it encodes that five of these screens answer questions
about agents and three answer questions about a machine, and the machine questions get
asked once a month.

`Queue` splits into `Awaiting your key here` and **`On your Ngage desk`**, finally
rendering `raised`. AD-10 forbids Nact from *signing* those; both constraints hold at
once, because **a queue may show what it cannot sign, as long as it says so and hands
you the door.** `Actions` is new and receives the durable action surface, list first.
`Directors` dies — a Director is an approval path, not a peer of an agent.
`+ Add agent` stops fabricating: custodial is **disabled with the workaround stated**,
using the routing board's own `○ ◌ ✕` legend, because a greyed option with a reason
teaches while a missing option confuses. `Remove identity` becomes
**`Forget on this device`** — local-only actions must be *named* local-only.

### 4.6 The slice pattern

Five slots: Lede · Waiting for you · Access list · **How this app routes** · What this
desk never does. Two non-negotiables: **the mirror pill on every cross-plane write**,
and the failure prefix **`nothing changed: …`**.

For waggle, the new `Routing` view is **a ladder, not a graph** — the lanes are
ordered by trust, and the interesting facts are which lane someone is in and what moves
them up. Two rules govern it:

- **A visualization must import the thing it visualizes.** The lane labels come from
  the module that classifies, exported the way the ceremony spec is already shared
  between runtime, console and signing page. That doctrine — *so a signing surface can
  never show a softer picture than the review console* — is the best structural idea in
  the codebase and is currently used once.
- **`(—)`, never `(0)`.** A silent drop leaves no record by design, so a zero would
  claim knowledge of an unrecorded event.

**What the panel can honestly source today** (verified against the signed state):
lane 1 is fully enumerable with per-author consent; every gate and cap is exact; lanes
3 and 4 and mutes are **counts only**; lane 5 is the residual. **Not** sourceable:
membership for lanes 2–4, and whether quarantine *delivers* or silently *holds* — with
no staging channel configured, lane 4 holds undelivered and nothing in signed state
says which. Four new public-safe fields close it, and there are two traps: the
console's top-level validator is exact, so a **new top-level key silently kills the
panel on the deployed page** (add fields *inside* `operations`), and the bridge's own
validator is closed, so it will reject its own new field until extended. Ship both
together. And do not build the five lanes from `operations.lanes` — those four booleans
are *transport* lanes, a different axis.

---

## 5 · Shared components

Build order, cheapest and safest first: `nave-tabs.mjs` (three idioms across five
surfaces, none defined anywhere; bundles the hash routing Nact lacks) · `nave-cap.mjs`
· `nave-source-note.mjs` · `nave-agent-card.mjs` · `nave-grant-row.mjs` ·
`nave-agent-detail.mjs` · the titlebar plane switcher · adopt `nave-login.mjs`.

**Token cleanup is mostly a re-vendor, not a feature** — three apps lack a light theme
purely because their copies are stale. Alias, then remove one deploy later; never
re-vendor and re-selector in one commit. Nact's tier colours **derive** rather than get
replaced, because the tier *spec* is already shared for the reason that a signing
surface must not show a softer picture — and a softer colour is a softer picture.

**Drift detection** is the piece with no prior art in the estate: a `VENDOR.json`
manifest, **hash** provenance stamps, a `bin/nave-drift` reporting
`ok` / `stale` / **`diverged`** / `not adopted` / `missing`, and the gate placed in
`deploy/sites.sh` **after the clone/reset loop and before secrets or build**, reading the
trees Caddy actually mounts.

**It is a diagnostic, not an atomicity guarantee**, and the distinction is a required
release property rather than a nicety. `./sites` is a live bind mount and the loop promotes
thirteen trees *in place*, so production has already served a mixed snapshot by the time the
gate runs; a mid-loop failure leaves it half-promoted. The gate can report that the serving
state disagrees with itself — it cannot prevent that state having been served. Atomic
promotion is tracked separately as **#115** (stage outside the mounted tree, swap the
serving root after a successful stage, roll back a failed activation), and nothing in the
gate may be read as a claim that a deploy is atomic.

---

## 6 · Copy promoted fleet-wide

All existing strings. Nothing here is newly written prose; this is a decision about
which surface's voice wins.

| promoted | from | to |
|---|---|---|
| the capability→English map | waggle | `nave-cap.mjs` — four surfaces, one wording |
| *"No relay answered. Nothing is shown because nothing could be verified — this is not the same as…"* | waggle | `nave-source-note.mjs` — AD-11 as a component |
| `asked by <npub…>, not the key being admitted` | waggle | Nvoy `Requests`, which lacks it |
| `· recorded in Nvoy` / `· ⚠ not recorded in Nvoy (retry to mirror it)` | Ngage | every cross-plane write |
| `an empty desk, by design` / `the desk is clear` | Ngage | the register for all empty states — affirmative, never apologetic |
| *"The agent proposes; you enact it by signing. Your key never enters this page."* | `sign.html` | every signing surface |
| *"Wiring a ◌ cell records intent, but changes nothing at runtime."* | Nact Routing | all inert config, including a default-off consent gate |
| `nothing changed: …` | Nvoy | every failed write |
| read-back verification before claiming success | Nvoy | every commit path |
| `Where: Hidden` + *"Why 'Where' often says Hidden."* | waggle | kept verbatim — the model for privacy-by-construction disclosure |
| the `✓ ✕ ◌ ○ ·` legend | Nact Routing | reused wherever availability must be shown honestly |

One note on wording: waggle's brief re-cut its own vocabulary on 2026-08-04 — the inbox
is partitioned by **authority** (not "trust"), `Actionable` became **`Scoped
instruction`**, and *"Listening is not authority."* Any copy promoted from there must
use the post-`04c77da` wording.

---

## 7 · Sequence

Two constraints point in opposite directions, and the sequence falls out of them.

`deploy/sites.sh` hard-resets **all thirteen app clones to `origin/main` on every hub
deploy**. So nothing ships from a branch, and a merged app PR is live on the *next* hub
deploy whoever triggers it. Cadence: merge hub → hub deploy → merge app PRs → next hub
deploy. Docs are free — `**.md` is in `paths-ignore`.

**A deploy is not fleet-atomic, and this spec previously claimed the opposite.** An
earlier revision said *"you cannot ship one coupled app in isolation"*, which reads as a
guarantee that the fleet moves as one set. It does not, and the inversion matters:
`sites.sh` resets the clones **sequentially under `set -e`**, and
`deploy/docker-compose.yml` bind-mounts `./sites` into Caddy, which serves those trees
directly. So if reset N succeeds and reset N+1 — or any post-loop gate — fails,
production is **already serving clones 1…N new and N+1…13 old.** No later check can roll
that back, because the promotion happened when the tree changed, not when the build
finished. The true constraint is therefore the stronger one: you cannot *prevent* a
partial set from shipping.

**So every wave gate carries a prefix/abort compatibility requirement, not an atomicity
assumption:**

> A wave is shippable only if it is correct after **every prefix and every abort point**
> of the thirteen-repo reset order — not merely after the complete set lands.

Read as an obligation on each wave, that means: no wave may depend on two repos landing
together; a new emitter ships at least one wave before its receiver requires it, and
degrades when the receiver is old; a new consumer tolerates the absent primitive rather
than assuming Wave 0 already propagated. Wave 0's *strictly additive* rule is one
instance of this discipline and is **necessary but not sufficient** for Waves 2–5, which
change existing surfaces.

**nave.pub#115 is the release gate that retires the requirement.** Until `sites.sh`
fetches and validates outside the mounted tree and then swaps the complete snapshot —
with defined rollback for a failed activation — the in-place loop remains a known
production risk, and **no release may describe a deploy as atomic.** The drift gate
(§ Making drift detectable) *detects* a mixed snapshot; it does not prevent one, and
must never be cited as though it did.

waggle is the exception. It self-deploys in about three minutes, and its console now
*also* syncs on a five-minute cron independent of the hub. **It is the estate's only
fast feedback loop.**

| wave | repo | content | prefix/abort gate — what must hold if the reset loop stops mid-fleet |
|---|---|---|---|
| **0** | nave.pub | AD-12 · glossary · this spec · mockups · the shared primitives · `VENDOR.json` + `nave-drift`. **Strictly additive**: between Wave 0 and Wave 2 the fleet is half-propagated *by design*, and that state must render identically to today | Nothing consumes the new primitives, so any prefix renders as today. The only new failure mode is the gate itself, which is why it is **report-only** until Wave 5 |
| **1** | **waggle alone** | routing view · index row on admit · the missing capability paths · shared signer session · signed moderation lanes | waggle self-deploys outside `sites.sh` entirely, so it has no prefix to be correct after. It **copy-vendors** the Wave 0 primitives rather than importing from the hub, so a hub that has not deployed cannot break it |
| **2** | nvoy | the IA refactor · **agent page v1** · re-vendor tokens | Agent page v1 must render with **Nact absent** — every Nact-owned section in the did-not-answer state, never a zero. The re-vendored tokens ship with the transitional alias, so an nvoy-new/hub-old prefix keeps its styling |
| **3** | nact | the join key · roster with divergence rows · render `raised` · `Actions` · hash routing | The deep-link **emitter** ships here degrading to the plain Ngage root URL, so a prefix carrying nact-new/ngage-old still navigates. Divergence rows must render against an nvoy that has *not* yet published the registry projection — an unreadable registry is `did not answer`, not `no agents` |
| **4** | ngage + cross-plane | slice pattern · plane switcher live · routing derived from grants | The plane switcher flips **only because** every surface became navigable in Waves 1–3; if a prefix leaves one surface old, the switcher must still resolve to its current root. The `#draft/<scopeId>` receiver lands here, one wave after its emitter |
| **5** | — | runtime-manifest read panel · remove the aliases · CI drift gate | The alias removal is the one step that is **not** prefix-safe on its own — it requires a clean drift report against the same reset `sites/*` snapshot first, and therefore lands behind #115 |

**Why waggle goes first**, out of dependency order: it delivers the two things the
Director asked for by name — the routing illustration, and an end to
invisible-in-Nvoy approvals — in the one repo with a fast loop, and it battle-tests
four shared primitives in production before the coupled fleet inherits them. It already
vendors current tokens and has a light theme, so it is also the cleanest consumer.

**Agent page v1 is deliberately half-populated.** It fills the sections its own plane
owns and puts everything else in the did-not-answer state. That version is useful on
day one *and* honest on day one, so it ships before Nact can answer.

Wave 3 and Wave 4 both touch the Ngage↔Nact boundary: merge the deep-link **emitter**
in Wave 3 degrading to the plain Ngage root URL, and the **receiver** in Wave 4, so a
deploy carrying only Wave 3 still works.

---

## 8 · Verification

**Deploy proof, every wave** — cache-busted, on a marker that is **new by
construction** (a component version banner, a new nav label, a vendor-hash attribute),
never a string that might pre-exist:

```bash
curl "https://<host>/<file>?cb=$(date +%s)" -H 'Cache-Control: no-cache' | grep -c '<new-only marker>'
```

**Check the four hand-mirrored Caddy hosts explicitly.** `nact`, `naction`, `nscribe`
and `waggle` copy the `(app)` snippet instead of importing it, so a change to `(app)`
silently skips them. Per-host curl, never an inference. **Verify the tree, not the PR
badge.**

- **`nvoy/test/mcp-conformance.mjs`** is the authoritative wire contract. Add:
  namespaced scope names survive `nvoy_grants_list`; a `capability:` read **fails
  closed** without a matching `da-cap`; the registry scope is grantee-only and a
  generation rotation revokes it; `nvoy_whoami` reports the registry handle when
  granted and **`null` when not — never a fabricated handle**.
- **`nact/lib/routing.test.mjs`**: the path derived for every custody mode including a
  foreign key; an undelivered transport classifies **`ungoverned`**; an on-box key
  absent from the registry classifies `unregistered` and **cannot be bound to a path**.
- **waggle**: an approval produces the public `440` **and** the index row; a moderation
  verb either produces a signed event or is refused.
- **Drift**: CI asserts each app's vendored token hash equals the hub's, and each
  vendored module's provenance hash matches. Nothing checks this today, which is why
  two token generations and three missing light themes went unnoticed.

**Pre-flight, every wave.** On 2026-08-05 every local clone was **behind**
`origin/main`. Since a hub deploy is a fleet-wide `reset --hard origin/main`, an
ahead-of-origin clone is **silently reverted, not skipped**. Assert that every
canonical clone equals its `origin/main` before starting, and `git fetch` before
asserting anything is missing — a stale local `main` makes a grep lie. Two clones need
care and should be read via `git show origin/main:<path>` rather than checked out:
`nact` sits on a detached HEAD, `waggle` on a dirty feature branch.

---

## 9 · What this refactor does not do

- **It does not merge the two audit lenses.** AD-1 holds: Nvoy Ledger is grant
  lifecycle, Nact History is this box's activity. Two lenses, each honestly named.
- **It does not merge the runtime manifest into the registry.** Different lifetime,
  different writer, different secrecy class — service users and UIDs must never reach a
  UI. Two objects, one join key, one direction of truth each.
- **It does not touch `sign.html`.** It is the reference, not a target.
- **It does not relax the human tap.** The doctrine amendment *narrows* what a durable
  grant can mean; nothing here lets an agent's chosen bytes reach a relay without a
  signature over exactly those bytes.
- **It does not coin a vocabulary.** One new noun, `slice`. Everything else is a choice
  among words the estate already owns, and the declined synonyms are recorded in AD-12
  so they do not return.
