# Nave architecture decisions (running ADR)

Decisions that were "dangling threads" — architecturally undecided, which is its
own risk. Each is recorded here as a **recommended decision with rationale**, so
the thread is closed and implementation can be queued. **James: flag any you'd
override** — these are the Nave-side default, not a fait accompli. Signature-gated
acts (grants, activations, re-grants) still require the Director; nothing here
performs one.

Companion docs: `nact/docs/credential-sovereignty.md` (the credential model),
`nact/docs/keyless-boot.md` (the boot design), `docs/warm-contact-nave-review.md`
(the two consumption modes).

---

## AD-7 — Two channel kinds: **approval** (shared) vs **communications** (per-agent)
*(SHIPPED 2026-07-18)*

**Context.** An agent needs two different telegram surfaces and they were
conflated: the channel that **gates** its proposals vs. the channel it uses for
**normal messaging** (Luke's assistant bot).

**Decision.** Channels carry a `purpose`:
- **`approval`** — where an agent's proposals go to be gated. **Shared** across
  all agents (the web queue + Nact_jaf's telegram bot), reaching every identity.
  Consumed by Nact (it receives the approve/reject taps).
- **`comms`** — an agent's **own** line for normal, non-approval messaging.
  **Per-agent**, covering only its owner; consumed by that agent's own runtime
  (Luke's by the OpenClaw engine).

**The hard constraint that forces the split (verified true):** a Telegram bot
token allows **exactly one update consumer** — `getUpdates` *or* a webhook, and
two pollers on one token get `409 Conflict`. Luke's comms bot is consumed by
OpenClaw; approvals must be consumed by Nact. Same token, two consumers →
conflict. So comms and approval are **separate bots** whenever they are separate
consumers. **Sending is unlimited**, so the shared approvals bot may still send
its own messages, and one bot may carry multiple purposes only when they share a
single consumer.

**Consequences.** Each agent that wants two-way chat needs its **own** comms bot
(its own consumer, like Luke's). The shared approvals bot is one consumer (Nact)
for everyone's gating. Agents without their own bot show "no comms channel yet"
in Nact until one is provisioned and granted to them.

**Status.** **SHIPPED.** `nactor` derives `telegram-luke` as Luke's comms channel
and keeps `telegram-nactjaf`/web as shared approval channels; Nact's Channels tab
splits into Approval vs Communications, Routing lists only approval channels, and
each agent shows its approval route + comms channel (or the gap).

---

## AD-1 — Nact **History** becomes the runtime audit, not just enactment outcomes
*(closes #52)*

**Context.** History renders empty and reads as confusing because it only logs
enact/reject of *queued nostr proposals* — and nothing has flowed through that
queue. James expected the log of grants/revocations. Two logs exist and were
conflated: **Nvoy Ledger** = credential/data grant lifecycle; **Nact History** =
event-signing outcomes.

**Decision.** Nact History becomes the **audit of everything that happened on
this runtime** — Director activations, credential grants the Nactor observes,
routing changes, and enactments — clearly labelled as "this box's activity,"
distinct from Nvoy's grant Ledger (which stays the credential-lifecycle view).
Two lenses, each honestly named; neither empty.

**Rationale.** The box already holds this data (activations in `config`,
entitlements from the grant readers, enactment history). Surfacing it turns a
blank, misleading tab into the runtime's honest record. Keeping the grant
*lifecycle* in Nvoy avoids duplicating the Ledger.

**Status.** **SHIPPED** (2026-07-18). `nactor.runtimeAudit()` merges Director
activations + enactments (newest first); `/api/state` also carries standing
`entitlements`. Nact's History now shows a "Standing credential grants" section
plus the time-ordered activation/enactment audit — no longer blank — clearly
scoped as the runtime log, distinct from Nvoy's Ledger.

---

## AD-2 — Address the runtime by its **nostr identity**, deprecate the HTTP address
*(closes #53)*

**Context.** The Deployment tab couples the app to an HTTP URL
(`https://nact.nave.pub/api`). The sovereign end-state addresses the runtime by
*who it is*, not *where it's hosted*.

**Decision.** The Nave Nactor publishes its **service endpoint + relay list** as a
nostr event (NIP-89 handler-advertisement style); clients discover transport from
the **identity**, not a typed URL. The canonical runtime handle is
**`nactor@nave.pub`** — the *runtime* identity, distinct from `nact_jaf@nave.pub`
(the approvals **carrier**) and from `nave@nave.pub` (the ecosystem **root**). The
HTTP "Nactor Address" field is kept only as a manual override/fallback.

**Rationale.** "Point at a URL" → "point at an npub." Moving the box becomes
republishing an endpoint event, not editing config — the same decoupling as
email. Keeps the runtime addressable across boxes, consistent with credential
sovereignty.

**Domain — RESOLVED (James, 2026-07-18): `nactor@nave.pub`.** The runtime is
shared box infrastructure, kept cleanly separate from the sovereign root
(`jaf@dequalsf.com`). The handle already resolves in
`nave.pub/.well-known/nostr.json`, so it's nip05-verifiable today.

**Status.** **SHIPPED** (2026-07-18). On boot the Nactor publishes, under its
own key, a **kind 10002** (NIP-65) relay list and a **kind 31990** (NIP-89)
handler advertisement naming its NIP-98 API endpoint as a `web` target
(`nactor/endpoint-advert.mjs`, wired into the boot sequence). Both are
replaceable, so relocating the box is a republish — clients discover transport
from the identity, not a typed URL. Endpoint from `NACT_ADDRESS` (fallback
`https://nact.nave.pub/api`). The HTTP field in Nact's Deployment tab remains as
a manual override/fallback.

---

## AD-3 — Boot hierarchy: the box boots under **Nave**; Nave Nactor is subservient
*(closes #50)*

**Context.** The identity hierarchy needed to be made explicit: what is the root
the box runs under, and what does it bootstrap?

**Decision.** **Nave** (`nave@nave.pub`) is the **root** identity the box boots
under. Nave bootstraps the runtimes and agents beneath it — the **Nave Nactor**
(the per-box credential/execution runtime), then Luke, Brain, Noir, Nact_jaf. The
Nave Nactor is **subservient to Nave**: it holds a key to do its job (broker,
control plane) but derives its standing from Nave, and does not sit at the root.

**Rationale.** Matches the published Nave profile ("the root the box runs under,
from which the runtimes and agents beneath it are bootstrapped"). Prevents the
Nactor from being mistaken for the ecosystem root. No runtime change needed today
— Nave is already the root identity; this records the intended ordering that
keyless boot (AD-4) and any future multi-box work build on.

**Status.** Decided · documented · no near-term runtime change.

---

## AD-4 — Keyless boot stays the north star; SOPS-custodial is the interim
*(closes #49)*

**Context.** The aspiration: the box holds **no** long-term secret on disk — the
Director unseals it over nostr at boot into an ephemeral RAM key. Full design in
`nact/docs/keyless-boot.md`.

**Decision.** Keep keyless boot as the **direction**, phased, not a rewrite now.
Near-term the box keeps **SOPS-sealed** keys with the age private key secured
**off-box** (already done, #21). The migration path is tiered: a pre-unseal UI
(nvoy as the boot surface) → Director signs an unseal challenge over nostr →
secrets decrypt into RAM only. The "uptime vs sovereignty" dial (auto-reseal for
availability vs human-in-the-loop for maximal sovereignty) is James's to set per
box.

**Rationale.** Keyless boot is the strongest sovereignty story but trades away
unattended restart. Sequencing it behind the credential-sovereignty work (grants
to identities, off-box age key) means each step is independently safe. No reason
to rush the box into a boot mode that could strand it offline.

**Status.** Decided (direction) · design doc exists · implementation deferred by
choice.

---

## AD-5 — Reconcile Nact **Channels/Routing** with the credential-broker model
*(closes #55; the nip05 half is already shipped)*

**Context.** The Nact app has two parallel notions that never met: **Channels**
(approval-delivery endpoints, e.g. the "Nact app · Web" queue) and the
**credential-broker providers** (the telegram bots as credentials owned by
identities). So the telegram bots don't appear in the Channels list or the
Routing matrix, and `brain` reads "no channel — cannot be approved." Separately,
the `nactjaf@` vs `nact_jaf@` nip05 mismatch — **fixed** (`nactor` commit
`64f8be2`): the plane now shows the canonical `nact_jaf@nave.pub`.

**Decision.** A **channel** is an approval-delivery endpoint; a telegram bot that
carries approvals **is** such a channel, owned by an identity. Surface
**`telegram-nactjaf`** (Nact_jaf's approvals bot) as a first-class Channel and
wire it in Routing (`Nact_jaf → telegram-nactjaf`), so the approvals path is
visible where routing is configured — not only as a hidden broker provider.
`telegram-luke` (Luke's assistant bot) is a **direct-delivery** credential, not an
approval channel, and stays out of the approvals routing matrix (it's messaging,
not gating). The Routing matrix should derive from the identity→channel wiring in
`config.channels`, which is where the gap is today.

**Rationale.** Unifies the two models on their real meaning (channel = where an
approval goes) instead of leaving telegram invisible to routing. Fixes the
"brain: no channel" dead-end by making the routing surface reflect the credentials
that actually deliver approvals.

**Status.** **SHIPPED & verified live** (2026-07-18). nip05 fix + the "credential
that is also a channel" reconciliation: `nactor` idempotently derives an approvals
channel from `telegram-nactjaf` (`ensureCredentialChannels`), the channel card in
`app.html` shows its credential-backed nature, and it appears as a Routing column.
Verified on-box: the derived channel covers `luke,brain,nave,nactjaf`, so brain's
"no channel — cannot be approved" dead-end is gone. The two models are now one
source of truth. (The key insight was James's: telegram-nactjaf is *both* a broker
credential *and* a channel — not a pick-one.)

---

## AD-6 — Credential consumption is **hybrid by sensitivity** (broker + grant-to-app)
*(confirms the credential model; new policy doc)*

**Context.** With grant-to-app blessed for warm.contact (see the review), the
question was how far to push Nave's *own* on-box agents (Luke, Brain) toward
holding their own credentials.

**Decision (James, 2026-07-18): hybrid by sensitivity**, written down as an
understandable policy: `nact/docs/credential-consumption-policy.md`. Two tests
decide every `credential × consumer`: (1) is the request content sensitive to
Nave? (2) is the consumer off-box? **Either yes → grant-to-app; both no →
broker.** Both modes are sovereign — the authority is the grant, not the custody
location. On-box Nave agents stay brokered (tight custody, non-sensitive content);
off-box / ZK consumers (warm.contact) use grant-to-app.

**Rationale.** Sovereign where it matters, tight custody where it's free. Avoids
dogma in both directions: not "broker everything" (would break ZK and off-box),
not "grant-to-app everything" (would needlessly scatter keys the broker can hold
safely). Migrating a credential between modes is just re-addressing the grant — no
secret re-entered.

**Status.** Decided · policy documented · already the de-facto rule (Luke=broker,
warm.contact=grant-to-app).

---

## AD-8 — Naming & scope-namespace reconciliations (warm.contact integration)
*(from the warm.contact agent's 2026-07-21 feedback pass; recommended — override any)*

**Decisions.**
1. **"Director" = the human root authority, ecosystem-wide** (James for the
   fleet; the user for their own Quill estate). Noir's AI game master is always
   written **"Noir's Director"** outside the game — extending the ECOSYSTEM-HUB
   §0.6 pattern that already killed one Director collision. A third synonym
   ("root grantor", used provisionally by the warm.contact agent) is declined:
   new synonyms fragment vocabulary the docs already rely on.
2. **The booking-URL profile field is `coffeeLink`** — the shipped name wins
   over the drafted `calendlyURL`, and it's provider-agnostic on purpose.
   `meetup`-intent surfacing stays tracked in warm.contact#7.
3. **Grant scope names use the namespace** `profile:* · credential:* · data:* ·
   capability:*` (warm.contact's proposal, blessed as the convention). The Nvoy
   ledger/console should render namespaced scopes (folds into nvoy#2);
   `capability:*` remains interim-local to apps until Scoped Action Approvals
   matures (build-first, INVENTORY §1).

**Rationale.** All three have cross-repo blast radius precisely because they are
names: grant keys outlive refactors, and two "Directors" already forced §0.6
once. Deciding in the ADR log now keeps warm.contact unblocked without paying a
doc-drift tax later.

**Status.** Recommended 2026-07-21 · `quill.md` §7 updated · corrective
cross-refs commented on nvoy#1 / nact#1.

---

## AD-9 — Voice is per-identity, structurally isolated, and evidence-only
*(SHIPPED 2026-07-22, luke#15)*

**Context.** One corpus (`brief/voice.md`) described every posting voice and a
single LLM call chose which "hat" to wear per post. Two failure modes followed:
the voices regressed toward one average, and the corpus's claims were *inferred*
— Luke's register was guessed backwards (his box-side charter demands "have a
spine … a yes-man is worthless"; the corpus said "wry, deferring"), and the
dequalsf creed itself was wrong (it is **discipline = freedom**). Separately, an
early voice profile for the Director had been derived from an AI-assisted essay
— a feedback loop that amplifies drift. The Director caught it.

**Decision.** Three rules:
1. **One steering file per identity; one drafting pass per identity.** A pass
   reads `brief/shared.md` (substance + house rules) plus its own voice file and
   **cannot reach another identity's** — the isolation is structural (the file
   is never in the prompt), not an instruction the model could talk itself out
   of. The identity is fixed by the caller and stamped on the result.
2. **Voice files are built from evidence only.** Luke's from his OpenClaw
   `SOUL.md`/`IDENTITY.md` (box-only; only the *public posting register* is
   carried into the public repo). The Director's from twelve hand-written essays
   — measured (em-dash rates, sentence bimodality), not vibes.
3. **AI-assisted output is never a voice source.** The library's essays are
   explicitly marked non-sources in the steering files themselves.

**Consequences.** Engagement and approval-memory scope per identity (nave never
learns from luke's approvals); pre-split ledger entries are shown to *no* voice;
a voice returning **zero posts is a valid run** (Luke's own charter: silent by
default). Adding a voice = adding a file, no prompt surgery.

**Status.** SHIPPED — `voices.mjs` + 16 tests pin the isolation, attribution,
budget fairness, and scoped memory. Verified with a live two-voice run on-box.

---

## AD-10 — Approval happens where the signing key lives
*(decided 2026-07-22; Ngage half live, channel formalization queued)*

**Context.** Luke was drafting under two jobs on one path: posts as *himself*
(and as nave) going to Telegram, and posts *for the Director* — which have no
business near a custodial key, because the Director signs in his own hand. One
agent, two masters, one route: the overloaded-agent condition.

**Decision.** Every identity binds to exactly **one** approval path, chosen by
where its signing key lives:
- **Box-custodied keys** (nave, luke) → Nactor → the shared approval channel
  (Telegram / web queue). The box signs after the Director's tap.
- **Drafts for the Director** (jaf) → **Ngage**: the drafter gift-wraps each
  draft to the Director's npub as a `draft:post/*` scope; he signs with his own
  key. The drafting key *cannot* post; "only the Director can approve" is
  enforced by **encryption, not policy** — nobody else can even read the draft.

Steering flows the opposite direction over the same wire (`steer:draft` grant
from the Director), so tuning a drafter never needs a deploy.

**Consequences.** The overload dissolves: Luke drafts as Luke (Telegram path);
drafting-for-James moves to the scribe and, next, to **James's Quill on the Mac**
(Keychain-held key — completing the principle literally). Ngage becomes a
first-class *channel type* in Nact's model alongside Telegram-bot and
NIP-59-DM; the routing board derives approval wiring from grants, as comms
wiring already derives from credential grants (AD-5's completion).

**Status.** Ngage path LIVE (first sovereign post signed 2026-07-22; steering
round-trip proven). Channel-type formalization + grant-driven routing = the
current frontier (INVENTORY §5, issues-first).

---

## AD-11 — One sign-in across the fleet: promote the best implementation, never level down
*(SHIPPED 2026-07-22→23: luke#16, nvoy#15, ngage#6, nact#27–#29, nave.pub#51)*

**Context.** `nave-connect` (#56) unified sign-in everywhere except Nact — which
had its own overlay, its own NIP-46 plumbing, and its own signer shape. But
Nact's hand-rolled path was in one respect *ahead* of the standard: a
reverse-pairing `nostrconnect://` flow (mint the link, paste into the signer's
"Connect app" — the iPhone path) with a deliberately lenient handshake, because
the stock one hangs on real signers.

**Decision.** Standardize by **promoting** Nact's handshake up into
`nave-connect` (canonical in the luke repo, vendored per-app), then point Nact
at the shared module. Three signer-bugs became pinned tests: accept
`result:"ack"` (stock accepts only the echoed secret), accept NIP-04 acks
(stock is NIP-44-only), and **no `since` filter** (a fast browser clock made
relays drop acks stamped by the signer's clock; `limit:0` is skew-proof).
Corollaries: a control plane's sign-in path uses **local vendored bundles, no
CDN**; app HTML + importmap + modules move as **one versioned unit**
(`?v=` tokens + `Cache-Control: no-cache`) — headers govern new responses, only
a changed URL reaches an already-cached entry; and **disconnected means empty**
— a control plane never renders fabricated approvals as if real (nact#27).

**Consequences.** nvoy and ngage gained the working nsec.app path for free;
Nact gained sign-out (scrubs to indistinguishable-from-never-connected) and
session resume; every app shows the same titlebar and signer badge. Vendored
copies carry a provenance header; ngage's one flagged divergence (nip44 on the
local signer) is re-applied by a sync that asserts the upstream shape first.

**Status.** SHIPPED and verified live on every surface, including the
cache-poisoned-browser case that had twice presented as "the deploy didn't work."

---

## AD-12 — One agent, two planes, N slices: the canonical agent-governance model
*(decided 2026-08-05; tracked in #110)*

**Context.** Four surfaces govern "an agent" — Nvoy, Nact, waggle, Ngage — and none
agree on what an agent *is*. The Director reported the symptom: **some agents show in
Nvoy that do not show in Nact.** That is not a bug in either app. It is the visible
edge of **seven disjoint stores with no join key**:

| store | shape | keyed by |
|---|---|---|
| `nvoy_agents` on the delegator's `10440` | `{ pub, added_at }` — the whole record | pubkey |
| Nact's env scan + imported map + `nact-config.json` | `{ key, handle, npub, signer, status, source, activated }` | **lowercased env-var name** |
| `/etc/nvoy/instances/<id>.json` | ~20 fields (service users, UIDs, worker digest, carriers) | instance id |
| public `440`s carrying `da-cap` | a capability + a salted subject hash | grantee pubkey |
| `nvoy_derived_children` | parent→child lineage | scope |
| Ngage's `localStorage` | two flat lists of bare hex | pubkey |
| waggle's `config.json` | roster + policy fields | pubkey |

The only registration bridge, `nact/nactor/request-register.mjs`, is
**one-directional**: an identity publishes an access request, the Director approves it
*in Nvoy*, `nvoy_agents` gains a row, and nothing in Nact changes. Nact's
`HANDLE_OVERRIDES` exists solely because there is no join key.

**Decisions.**

1. **An Agent is one key.** A named principal, other than the Director, identified by
   **exactly one** nostr public key. It is `key + custody + authority + runtime`, where
   only the key is its identity; custody says where its signing key lives and therefore
   which Approval Path it is on. **Authority is never a property of the Agent** — it is
   the grants it holds, looked up in the Ledger. **The join key is the lowercase
   32-byte hex pubkey, everywhere; `npub` is display only.** Consequence: "Luke is one
   agent, two keys" is retired — `luke` and `brain` are two Agents sharing one voice
   (AD-9).

2. **One object, many slice roles.** agent ≡ identity ≡ role key ≡ pen ≡ deliverer ≡
   granted participant ≡ admitted author. The differences are **roles inside a slice** —
   an attribute of the record, not a type of Agent. One ruling retires the whole
   vocabulary-collision list.

3. **Action Grant = one object, two modes.** **Capability** (`standing`) confers the
   right to *propose* in a class, with a mandatory envelope refused at issuance if
   absent: action class · max risk tier · TTL · rate limit · exactly one bound Approval
   Path · revocable by `441`. **Approval** (`discrete`) is one human tap over frozen
   bytes (WYSIWYS), yielding `["approval", id, approver]`.

   **The doctrine sentence is amended fleet-wide**, replacing "No standing 'post
   whenever' authority — ever" in `nact/README.md`, `nact/DESIGN.md` and
   `naction/index.html`:

   > **No standing authority to sign. Standing authority to propose — always narrow,
   > always short-TTL, always rate-limited, always revocable.**

   This is a **strengthening, not a concession**, and the reason is structural: a
   durable grant *cannot* authorize a signature, because WYSIWYS binds to a fingerprint
   over bytes that do not exist at issuance time. So a durable grant can only ever
   confer queue entry plus the gate tier. The estate already had durable action
   authority — `da-cap: task`/`task+act` issued from Nvoy, waggle's admissions, and
   waggle's unsigned in-channel verbs (ruling 9) — so the choice was never "durable or
   not," it was **durable and named, or durable and hidden.**

4. **`capability:*` and `da-cap` stay two mechanisms, and the seam is formalized.**
   `da-cap` on a public `440` is the **enforcement** tag; a `30440` named
   `capability:<slice>/<verb>` carries the terms. **Enforcement must never require a
   key** — `nvoy/mcp/tools/attention.mjs` and `waggle/src/bridge.mjs` both check
   `da-cap` without decrypting anything, default-closed ("being unable to check is not
   permission"), and folding the capability into a namespaced *scope name* would trade
   that for a key-dependent check. Also, `da-scope` is a salted hash so the subject
   stays private and cannot be replayed to another agent — and a renderable namespace is
   by definition not a hash. **The `da-cap` enum is CLOSED** at
   `admit · admit+read · task · task+act · task-relay · mirror`; new capabilities are
   new `capability:*` scope names, not new tags.

5. **Exactly one new noun: `slice`.** An **Application Slice** manages the Agents,
   grants and routing specific to itself. It **may** define role names, routing
   visualization derived from grants, slice-local policy, and which scope prefixes it is
   slice-of-record for. It **may not** define Agent identity, grant shapes, capability
   enums, approval paths, or a second roster. **Every slice roster row is a projection
   of the registry, never authority.**

   "Universal plane" and "application plane" are **declined.** The estate already owns
   *grant plane* (relay-carried grant traffic) and *control plane* (a per-app admin UI);
   the Director's overarching-vs-application distinction is a **scope of view** over the
   one grant plane, not two further planes. Structurally: *universal = the slice
   component with the trivial predicate.* Same code, different filter — which is what
   makes "shows in one, not the other" impossible rather than fixed once. Declined
   synonyms, recorded so they do not return: *universal plane, application plane, app
   plane, overarching plane*, *root grantor* (already declined in AD-8), and *Scoped
   Action Grants* (`docs/PROJECTS.md` — a fifth name for the act side, in no glossary).
   AD-8's rationale governs: **new synonyms fragment vocabulary the docs already rely
   on.**

6. **The registry lives in the delegator's `10440`**, as the upgraded `nvoy_agents`
   field — not a new kind. It is already single-writer, already encrypted (the roster is
   not public), already relay-replicated, already console-read. The record gains
   `status`, `handle`, `display`, `custody{mode,ref}`, `voice`, `runtime`, `slices{}`.
   **`path` is not stored** — it is derived from custody on read and pinned by a
   conformance test; storing a derived path is how "chosen, not derived" creeps back in.
   **`handle` is authority and kind-0 is a hint**: Nvoy resolves names by live kind-0
   today, which means whoever holds an agent's key controls its label in the Director's
   own console.

   Headless slices (Nactor, the waggle bridge) cannot read the `10440`, so the Director
   publishes a **registry projection** as `data:agents/registry` (a `30440`,
   generation-rotated) and grants read per runtime key. AD-6's two tests force this and
   not the other mode: the roster is content sensitive to Nave, and the bridge is
   off-box — either yes → **grant-to-app**. Revoking a slice's view of the roster is
   then a scope rotation, a mechanism the estate already has.

7. **Nvoy is the front door and the only place an Agent is created.** This extends the
   existing sign-in ruling (Nvoy keeps local-key onboarding; Nact stays signer-only)
   from authentication to registration. `request-register.mjs` stops being a roster
   writer and becomes a request *carrier*. Every other surface reads.

8. **A console never receives host access; authority moves as signed events.** waggle
   has already built this: the bridge publishes signed public state, the owner issues
   narrow signed commands with an approver check, a replay watermark and freshness
   bounds, and anything whose subject must stay private rides a sealed wrap. Its own
   words — *"the bridge signs this record so the console can prove what it knows without
   becoming a remote shell"* — are the invariant, and it generalizes to Nvoy, Nact and
   Ngage.

   This **supersedes an earlier draft ruling that `waggle.nave.pub/console` should
   become read-only.** That framing conflated two orthogonal axes and would have deleted
   working, well-built features for a reason that does not apply. The second axis is
   real but separate: **supply-chain integrity of a signing UI** — whoever serves the
   page chooses the JavaScript that shows you what you are about to sign. waggle's
   loopback `tools/serve-console.mjs` addresses that axis and stays as the hardened
   local option; the concern applies equally to every hosted console in the estate, none
   of which currently discloses it.

   waggle's **sealed task-route lane is the estate's reference implementation for a
   command lane**: wrap-id dedup before any decryption, a decrypt budget charged before
   the first decrypt, the approver check gating the *second* decryption, the rumor id
   recomputed against its own hash, canonical-key checks at every layer, a refusal when
   the participant is not admitted, and legacy plaintext commands hard-refused.

9. **waggle's unsigned in-channel verbs are a path violation.** `approve`/`release`,
   `follow`/`watch` and `mute` mutate routing authority on an unsigned channel message
   and publish no signed event; two of them do not even refresh the signed counter an
   observer would watch. This is **not** an outsider path — the handler gates on the
   approver roster — but it is authority granted **off any signed path**, and it is the
   widest such gap in the estate. Naming it is how it gets closed. Remediation is
   tracked in JAFairweather/waggle#286; the one-line half (refresh the control state)
   should not wait for the rest.

10. **Nact issues and lists durable action grants; Nvoy's Ledger mirrors them
    read-only.** Durable action authority belongs with the plane that executes action.
    Nvoy's `Authority` tab dies, and with it three names for one thing (nav
    `Authority`, code `Access`, Ledger type `external`) — the survivor is **action
    grant**. Nvoy's Ledger keeps showing them as one read-only audit lens, which its
    `capgrants.mjs` reader already does app-agnostically. Note that
    `nvoy/console/task-authority-lib.mjs` already states that both surfaces use the
    same event shape: the shared primitive shipped, the consumer was never built. AD-1
    still holds — **Nvoy Ledger is grant lifecycle, Nact History is this box's
    activity; two lenses, each honestly named, do not merge them.**

**Rationale.** Every ruling above is either a *choice among words the estate already
owns* or a *promotion of an implementation that already works* — AD-11's doctrine
applied to the model rather than to sign-in: **promote the best implementation, never
level down.** Two rulings merely complete specs that were already normative and unbuilt:
waggle's `SPEC_EXTERNAL.md` §4.1 already specifies a **per-identity trust record** as
the admin UI's core object, and already specifies a `10440` index the console never
writes.

**Consequences.**

- The acceptance test is stated so it can fail: register one agent in Nvoy → it appears
  in Nact within one poll with its path **derived from custody**, and in the
  waggle/Ngage slices **only if** it holds a slice-scoped grant. Converse: no agent
  appears in Nact that is absent from the registry; on-box keys without a registry row
  render `unregistered`, never as agents.
- **AD-10 gains its missing third state.** The doctrine and its mechanics are
  already documented — `docs/architecture/03-delegated-actions.md` §2 has "derived
  from custody, never chosen by preference" and the refused wrong-path click — but
  nothing names a transport the runtime *displays and does not deliver to*. That is
  now **`ungoverned`**. Separately, the `nact` repo documents AD-10 nowhere in its own
  `docs/`, so a reader inside that repo finds only code comments; it should carry a
  pointer here.
- **AD-8's namespace gets implemented** in the Nvoy console, replacing a Type facet
  that substring-matches display strings and contains a hardcoded identity name.
- A transport the runtime does not deliver to gains a name, **`ungoverned`**, which
  makes nact#46 unrepresentable rather than merely corrected.
- The glossary gains a definition of **agent**, which it did not have.

**Status.** Decided 2026-08-05 · docs landing under #110 · implementation sequenced in
waves there, waggle first because it is the estate's only fast loop.

---

## Not decisions — just queued builds (for completeness, not dangling)

**Nvoy sign-in (confirmed, James 2026-07-18):** Nvoy **keeps** its local-key /
new-key onboarding (gated "advanced"); Nact stays signer-only. Nvoy is the front
door — signer-only there would wall out newcomers. This is the #56 `nave-connect`
build direction.


These are *unstarted future work*, not undecided architecture, so they carry no
"loose thread" risk — listed so the map is complete:

- **Nmail** — verb-scoped IMAP broker adapter in Nactor (#36); also warm.contact's
  Gmail path.
- **Shared `nave-connect`** — unified sign-in + title bar; Nvoy keeps its
  local-key onboarding, Nact stays signer-only (#56).
- **Central-identity fleet console** + **re-delegation terms end-to-end** (#59,
  #60) — from the warm.contact review; needed when warm.contact starts building.
- **Migration finish-work** — drop the `luke.env` aliases once no consumer
  references them (#44 step 3); revoke Nactor's redundant credential copies after
  cross-box value-sourcing (#43). The current state *works* — these are cleanup,
  sequenced deliberately so a late change can't strand the live box.

Signature-gated, James-only: delegate approval authority James → Nact_jaf (#48).
