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

**Status.** Decided (confirmed by James, 2026-07-18) · implementation queued
(Nact `app.html` History view + `/api/state` history payload).

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
`nave.pub/.well-known/nostr.json`, so it's nip05-verifiable today; only the
endpoint-advertisement event remains to build.

**Status.** Decided · handle resolves · endpoint-event implementation queued.

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

**Status.** nip05 fix shipped · channels/routing surfacing decided · implementation
queued (Nact `config.channels` + the Channels/Routing views in `app.html`).

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
