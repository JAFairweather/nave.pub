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
