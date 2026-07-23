# Scoped Agent Actions — the ACT-side microstandard

*Draft one-pager + research plan. 2026-07-23. Author: a Nave session, for the
Director's review. Home: `nave.pub/docs/` (this is protocol/spec that drives the
Nave, not `nact`-specific). Not committed; not a spec; not a NIP.*

**Director's calls (2026-07-23):** home = `nave.pub/docs`; name = **Scoped Agent
Actions**; ambition = the **linear path** — an internal actuator abstraction now,
*intending* to become a proposed community microstandard; framing = **NCP is our
MCP** (below). ContextVM: undecided by design — the research decides.

*Extends `nact/docs/ncp.md` (promotes NCP from perceive-only to the read+verb
context protocol) and generalizes `nact/docs/scoped-action-approvals.md` (the
verb/tool half).*

---

## Part I — The one-pager

### The reframe

We do not want *remote drafting*. We want **remote action** — a generic,
sovereign way to ask an agent (anywhere) to *do a scoped thing on my behalf*,
have it come back as a proposal only I can authorize, and enact it under my
signature. **Drafting is one actuator.** Posting is another. `exec` on a box
(Nops) is another. Opening a PR, sending a scoped email, booking a meeting — each
is the same spine with a different actuator swapped in at the end.

This is not a new idea in the estate. It is the **act-side of scoped autonomy**
already named as *Scoped Action Approvals* / *Scoped Agent Actions*, and the
runtime that performs it already exists: **Nactor is a pluggable actuator**
(`publish` for Nact, `exec` for Nops, `connector` for third-party accounts). What
is missing is the recognition that these are one primitive, and a design that can
carry it beyond the fleet.

### The frame: NCP is our sovereign MCP

You already named the umbrella — **NCP (Nostr Context Protocol)** — and `ncp.md`
already says it: *"MCP gives a model context from a vendor's connectors; NCP gives
a runtime context from the nostr grant graph, scoped to an identity and revocable
by rotation."* Its MCP face already exposes *granted data as MCP resources and
brokered calls as tools.* This doc **completes the symmetry**:

- **NCP is the protocol; MCP is one doorway.** The differentiator is not the wire
  — it is that the **source of context is the nostr grant graph** (capability, not
  secret; revoke-by-rotation; the signature *is* the authorization).
- **It spans both quadrants, and the split is MCP's own primitive split:**

  | MCP primitive | NCP supplies it from | half |
  |---|---|---|
  | **Resources** (read context) | **NIP-DA Scoped Data Grants** — "everything this npub may *see*" | perceive |
  | **Tools** (invocable verbs) | **Scoped Agent Actions** — "everything this npub may *do*", each behind propose→approve→sign | act |

- So `ncp.md`'s "perceive-side runtime" is **promoted**: NCP is the **read+verb**
  context protocol; NIP-DA and Scoped Agent Actions are its two grant-families;
  Nactor is its act-side actuator engine. One protocol, two grant-types, the human
  tap on the verbs, the whole thing revocable by rotation.

That is what makes NCP *not* "yet another MCP server": a generic MCP server hands
a model Drive or Slack; **NCP hands a runtime exactly what an identity was granted
to see and to do** — and the *do* half is human-approved and provenance-stamped.
"Our MCP as an NCP" is the whole design in one line.

### The primitive

One exchange, four beats, transport-agnostic:

```
  request  →  propose  →  approve  →  enact
  (a scoped   (actuator   (Director   (the acting key
   ask, gift-  returns an  signs THE   signs; the
   wrapped)    unsigned    exact       broadcast/exec
               template)   template)   carries proof)
```

- **The request is a scoped grant** (NIP-DA, gift-wrapped): "you may act as
  actuator A, within scope S, budget B, until T." The actuator holds *no*
  authority beyond the grant, and *never* the signing key for the final artifact.
- **The proposal is a template, not a signed act.** The actuator produces the
  exact thing that *would* be enacted (a draft post, a shell command, a PR body,
  an email) and returns it for review.
- **Approval is decoupled from signature.** The Director approves *this specific*
  proposal; the acting identity's key (custodial or a NIP-46 bunker) does the
  signing. WYSIWYS: the bytes approved are the bytes signed.
- **The enacted artifact carries verifiable provenance** — the
  `["approval", <approval-id>, <approver-pubkey>]` tag: public, checkable proof
  that an agent action passed a human tap, and whose.

### Positioning: a microstandard, not a marketplace (the load-bearing decision)

Nostr has **already run this experiment twice and backed away from both**:

- **NIP-90 (Data Vending Machines)** — the generic "money in, data out" compute
  marketplace — is now flagged *"unrecommended: this got totally out of control,
  prefer use-case-specific microstandards."*
- **NIP-26 (delegated event signing)** — the generic "sign on my behalf under
  these conditions" token — is **also unrecommended.** Broad delegation proved
  ≈ handing over the root key.

The lesson is precise: **be generic in the runtime, specific on the wire.** We
generalize the *implementation* (one actuator interface, one approval handshake);
we do **not** ship a generic public "agent action" standard. Each actuator's
semantics stay narrow and use-case-specific — exactly as NIP-DA is a
microstandard, not a universal data bus.

And our model *fixes the flaw that sank NIP-26*: NIP-26 let the delegate **sign
as you**. Ours never does — the actuator *proposes*, and only the Director's key
produces the authoritative artifact. "The drafting key cannot post; only the
Director can approve, enforced by encryption, not policy" is the property NIP-26
lacked. We are the corrected version of the thing that was deprecated.

### Borrowed vs uniquely ours

| Layer | Borrow from the field | Our invariant on top |
|---|---|---|
| Permission object (verbs, budget, expiry, revoke) | NWC (NIP-47) / Wallet Auth (NIP-67) | revoke = **key rotation**, not a DB flip |
| Actuator / tool interface | MCP; ContextVM (MCP-over-nostr) | actuator is **pluggable**, egress **pinned by the grant** |
| Private delivery | NIP-59 gift wrap | relay sees **only ciphertext** — no request-metadata leak |
| The signature | NIP-46 remote signing | actuator **proposes**, Director **signs** — never delegated |
| Provenance | (novel) `["approval", id, approver]` | public proof of the human tap |
| Payment (optional) | Cashu / L402 / Routstr | only where an actuator is metered |

### The one standardizable atom

Everything except **the approval handshake + the provenance tag** already rides
existing NIPs and needs no committee. The single thing worth a NIP — the ACT-side
peer to NIP-DA — is: *how an action is proposed for approval, how that approval is
granted, and how the enacted artifact proves it.* The `["approval", …]` tag is
the headline: as agents proliferate, "was this AI action human-approved, and by
whom?" becomes a question worth answering **on-protocol**.

### Non-goals / why-not-a-spec-yet (honesty, per house style)

- It works today as **software over existing standards** — no new wire format.
- A NIP earns its keep only when **multiple clients** want to render and grant
  approvals interoperably. Unproven until there are users.
- The estate's own playbook (Nscope: two implementations, *then* the PR) says
  lead with a working implementation, not a draft. So: **build the generic
  actuator + approval path, gather use, and draft the NIP only if cross-client
  demand actually appears** — with the provenance tag as the reason it's worth it.

---

## Part II — MCP, deep: the community's vs the one you built

### What you have built (grounded in `nact/docs/architecture.md`, `connectors.md`)

Your MCP is **not** "an agent calls tools." It is **MCP-as-scope-dereference**:

- **Nvoy mounts as an MCP server.** It holds the runtime's nsec, live-dereferences
  and decrypts NIP-DA scopes granted to that npub, and exposes them as **MCP
  tools** (`get_config → {identities, channels, routing, tiers}`; credential
  scopes the same way; the warm.contact contract adds `nvoy_scope_read`,
  `nvoy_scope_subscribe`, `nvoy_outbox_write`, `nvoy_grants_list`, `nvoy_whoami`).
  The runtime reads its config/credentials "with zero nostr knowledge" — an MCP
  call returns current JSON; rotate the grant and the tool returns nothing →
  deconfigured. **MCP is the read-surface over the grant plane.**
- **Authorization is the grant signature itself.** No OAuth, no bearer token, no
  session. "The signature on the scope *is* the authorization"; the runtime trusts
  config only from a Director npub, anchored by a bootstrap Director constant.
- **The actuator/tool side** (the `/api/broker` + `/api/connector/*` routes) is a
  **2×N connector grid** — transport (`http-build` stateless | `stateful-adapter`
  session) × auth (`static-key` | `oauth`) — **NIP-98-gated**, egress pinned by
  the credential, write-protection *structural* (no write verb exists in code).
  This is your action surface, and it is already tool-shaped.
- **V1 vs target:** V1 is HTTP + NIP-98 with a local config file; the target moves
  config/credentials to NIP-DA grants read via Nvoy MCP. Same endpoints, contained
  swap.

So you already speak MCP — but as a **capability-delivery** layer (decrypted
scopes → tools), with a **separate NIP-98 HTTP surface** for the actions
themselves, and a **grant, not a token,** as the unit of authority.

### What the community built

- **MCP core** — client↔server tool protocol (JSON-RPC), transports: stdio +
  Streamable HTTP. Your `NaveHttpMcpClient` is a hand-rolled Streamable-HTTP
  client, so you're already conformant at the transport layer.
- **MCP authorization spec (2026)** — now **OAuth 2.1**: the MCP server is a
  *Resource Server*, a separate *Authorization Server* issues access tokens,
  clients use Authorization-Code + PKCE, Protected Resource Metadata for
  discovery, audience-bound bearer tokens. This is the *opposite* pole from yours:
  centralized AS, bearer tokens, HTTPS endpoints.
- **ContextVM (was DVMCP)** — **MCP transported over nostr.** `NostrClientTransport`
  / `NostrServerTransport` carry MCP as nostr events; pluggable `NostrSigner`
  (private key, `window.nostr`, remote NIP-46); a `proxy-cli` mounts a remote
  nostr MCP server as a *local* MCP server in any client. This is the maintained
  line for "remote tools over nostr," and the closest external analog to what you
  want.
- **A2A (Agent2Agent)** and the 2026 research layer — capability-based auth
  proposals; papers on *verifiable delegation across MCP and A2A* (AIP) and
  *admission control for agent actions* (ACP) — i.e., the field is now trying to
  *add* the human-approval gate you already have.

### The comparison

| Axis | Your Nvoy-MCP / Nactor | MCP standard (OAuth) | ContextVM (MCP-over-nostr) |
|---|---|---|---|
| **What MCP carries** | decrypted **scopes** as tools (capability delivery) | tool calls (actions) | tool calls (actions), over nostr |
| **Transport** | Streamable-HTTP now; grants-over-relays (target) | HTTPS | nostr events |
| **Auth unit** | **NIP-DA grant** (capability); sig *is* auth | OAuth 2.1 **bearer token** (AS/RS) | nostr signature |
| **Revocation** | **key rotation** (grant dies) | token expiry / AS revoke | key-based |
| **Privacy** | **gift-wrapped** (ciphertext on relays) | TLS in transit, plaintext at RS | depends; not inherently gift-wrapped |
| **Human-in-loop** | **propose → approve → sign → enact** (WYSIWYS) | none (autonomous) | none (autonomous) |
| **Egress control** | pinned by credential; structural write-block | app-defined | app-defined |
| **Discovery** | grant graph / NIP-89 (nactor 31990) | Protected Resource Metadata | nostr / NIP-89 |
| **Payment** | none (could add Cashu) | none | none (DVM lineage had Lightning) |

### The key insight

You are using MCP **one layer lower** than everyone else. The community uses MCP
as *the whole client↔server wire* and then bolts on OAuth for auth. You use MCP as
the *dereference surface for a capability grant* — the grant is the auth, MCP is
just how the decrypted result reaches the runtime. **That is a stronger sovereign
story** (revoke-by-rotation, no bearer token to steal, ciphertext on the wire),
and it's closer to the **capability-token** literature (macaroons/biscuit/UCAN
with attenuation) than to OAuth.

This is exactly the **NCP** frame. NCP is the protocol; MCP is a doorway; and the
two worlds meet by **exposing the Nactor *actuators* as NCP *tools* (over the MCP
doorway), gated by grant + approval** — while NIP-DA reads stay NCP *resources*.
That gives "any MCP-native client can request an action from my agent" *without*
surrendering the human tap or the gift-wrap. **ContextVM's role is therefore
scoped precisely:** it is a *candidate transport for NCP's MCP doorway* — nothing
more, nothing less — and whether it can carry scoped-access + gift-wrap +
human-signs (its public docs are silent) is the **first thing the research must
settle**. That is what "the research decides" resolves to.

### Recommendation (adopt / diverge)

- **The umbrella is NCP, not ContextVM.** Build the NCP tool/resource surface;
  treat ContextVM as one possible transport under NCP's MCP doorway, adopted only
  if the spike shows it composes with grant+approval+gift-wrap.
- **Diverge hard** from MCP's OAuth auth spec — keep the **grant as the auth
  unit.** Do *not* stand up an Authorization Server. Your capability model is the
  point of difference and the sovereignty argument.
- **Lift** NWC/NIP-67's permission object (`request_methods` / budget / `expires_at`)
  as the **scope schema** for an action grant — generalize "pay_invoice" to
  arbitrary actuator verbs.
- **Keep** NCP's existing shape (`ncp.md`): resources = NIP-DA data grants,
  brokered egress = capability-not-secret; **add** the actuator-as-NCP-tool
  surface (Scoped Agent Actions) as the new act-side half.

### Spike result — ContextVM, from source (2026-07-23, workstream A)

Read against `ContextVM/sdk` v0.13.10 (active; last commit 2026-07-22; LGPL-3.0).
Verdict: **adopt-with-wrapper.** Against the three invariants:

- **(a) scoped access by pubkey/grant — NATIVE.** `allowedPublicKeys` (static) +
  an async `isPubkeyAllowed(pubkey)` callback (query the grant store per call).
  *Open by default if neither is set — must opt in.*
- **(b) gift-wrapped, no metadata leak — NATIVE (opt-in).** `encryptionMode`
  defaults to OPTIONAL/plaintext; set **REQUIRED** → NIP-59 wrap (kind 1059/21059),
  NIP-44 inner, a fresh key per wrap, so relays see only ciphertext + the recipient
  `p`-tag — the requester's pubkey is hidden.
- **(c) propose→approve→sign gate — NOT provided, does NOT conflict.** Execution is
  autonomous; the gate lives in *our tool handler* (return a draft; human signs
  out-of-band). ContextVM is agnostic to handler return values, so it layers on top.

Frictions to plan for: only an in-process `PrivateKeySigner` ships (**no NIP-46** —
keeping the acting key off-box needs a custom NIP-46 signer adapter that also does
`nip44` to decrypt wraps); discovery uses custom kinds **11316–11320**, *not*
NIP-89; transport kind is **25910**; payment is Lightning/NWC (CEP-8), bolt11 only
(no Cashu/L402). **Net:** viable transport for NCP's MCP doorway with a thin wrapper
(our human gate + a NIP-46 adapter). Workstream A is answered; the schema freeze
(B) is now the gating step.

---

## Part II·5 — The director-path actuator contract (the seam the drafting relocation plugs into)

*Grounded in what shipped: `nact` PR #31 (`lib/routing.mjs`) already models the
"Ngage draft-grant" channel type and binds `jaf`/Quill to it exclusively (AD-10).
This pins the contract a Mac-resident drafter must satisfy to fill that path.*

**The uniform actuator.** Every actuator is `actuator(template, grant) → result`.
For drafting, `result` is a **draft**, never a signed post.

**The director path (the one Quill fills):**
1. Read `credential:anthropic` as a **grant-to-app** scope (AD-6 — voice and content
   never transit shared Nave infra); key in Keychain `WhenUnlockedThisDeviceOnly`.
2. Produce a `template` = `{ surface, target, content, context }`, where `surface` ∈
   {reconnect-reply, post, pr, …} is a **parameter, not a fork**.
3. Emit the draft as a **`draft:post/*` scope, gift-wrapped (NIP-59) to the
   Director's npub.** Only he can decrypt it → *"only the Director may approve" is
   enforced by encryption, not policy.* This is exactly the "Ngage draft-grant"
   channel type the routing board renders — a type that **carries no on-box secret**
   (the approver npub *is* the config; `routing.mjs` `needs-secret = false`).
4. The Director signs **in his own hand** (NIP-46 / local). The **drafting key
   cannot post.**
5. Steering returns over the same wire as a **`steer:draft` grant** (per-identity),
   editable with no deploy.

**Provenance — the one asymmetry between paths.** On the *box* path an agent drafts
and a human approves, so the enacted event carries `["approval", <id>, <approver>]`
— public proof of the tap. On the *director* path the Director is *both* approver
and signer, so his own signature is the proof; no separate approval tag is needed.
The provenance atom matters where signer and approver differ; here they don't.

**Conformance checklist for the drafting-relocation track:** emit `draft:post/*`
gift-wrapped to `jaf`'s npub; never sign a post; read `credential:anthropic`
grant-to-app; surface as a `template` parameter; one persona, per-device Keychain
keys. (The full build brief lives with that track; this is only the protocol seam.)

---

## Part II·6 — The action-grant scope schema (workstream B — draft to freeze)

The **standing authorization** for a class of actions, distinct from a single
invocation. NWC's parallel is exact: a *connection* carries permissions + budget;
a *request* is one `pay_invoice` under it. Here a **`capability:<actuator>` scope
grant** (AD-8 namespace) carries the standing authority; an **Action Proposal**
(`scoped-action-approvals.md`) is one invocation under it. Freeze the grant shape
first — the actuator contract (II·5) and the relocation track both bind to it.

The grant is a NIP-DA scope, gift-wrapped to the agent's npub, revocable by
rotation:

```jsonc
{
  "cap": "draft",                    // actuator: draft | publish | exec | connector:mail | …
  "verbs": ["reply", "post", "pr"],  // allow-listed verbs within it (NWC request_methods, generalized)
  "pin": { "surface": ["reconnect","post"], "approver": "<jaf-npub>" },
                                      // target fixed BY THE GRANT, never the request body
                                      // (connectors.md invariant); approver = who signs
  "budget": { "max": 20, "per": "daily" },   // rate/spend cap (NWC max_amount + budget_renewal)
  "expires": 1793000000,             // NIP-40 expiration (NWC expires_at) — always time-boxed
  "tier": "normal"                   // risk tier; "critical" ⇒ no one-tap (threat-model, nact#9)
}
```

- **`cap` + `verbs`** — the actuator and its allowed verbs. Verbs are *structural*:
  an actuator exposes only what it implements (`connectors.md` — "no write verb
  exists in the code"); the grant narrows within that.
- **`pin`** — the grant, not the caller, fixes the target (host / mailbox / relay /
  approver npub); a caller can never repoint egress. On the director path
  `pin.approver` is the Director's npub, and *that is the whole security of the
  path* — the draft is gift-wrapped to it, so only he can approve, by encryption.
- **`budget`** — a rate cap for unmetered actuators (posts/day), a spend cap for
  metered ones (the Cashu/402 path). One field, two readings.
- **`expires`** — NIP-40 TTL. An action grant is *always* bounded — the NIP-26
  lesson (never an unbounded delegation).
- **`tier`** — from the threat model; `critical` verbs (key rotation, grant
  issuance) can't be one-tap-approved (nact#9). The grant declares the tier so the
  approval surface enforces it.

**Revocation = rotation.** Rotate the scope key → the grant and every verb it
authorized die at once (NIP-DA 441). One blast radius.

**Attenuation / re-grant.** A grantee may issue an **attenuated** sub-grant
(nvoy#1 cascade): `verbs ⊆ parent`, `budget ≤ parent`, `expires ≤ parent`, `pin`
only narrowed — never widened; root rotation cascades. This is the capability-token
attenuation property (biscuit/macaroon) expressed as a NIP-DA re-grant — POLA by
construction.

**Standardizable vs app-interim.** Only the **proposal/approval handshake** and the
`["approval"]` provenance tag are NIP candidates. The scope *schema* stays
**`capability:*` app-interim** (AD-8) until cross-client demand appears — freeze it
in our runtime now, propose later.

---

## Part II·7 — Threat model for the generic actuator (workstream C)

`nact/docs/threat-model.md` develops WYSIWYS deeply — but **for one actuator**
(`publish`: the bytes you sign are a NIP-01 event id). Generalizing to
`exec`/`connector`/`draft`/`pr` does **not** inherit that guarantee; it must be
re-established per actuator.

**1. WYSIWYS is actuator-specific — the headline.** "Render the action, freeze it,
bind approval to its hash" (threat-model Rules 0–1) is sound, but the *hash* is a
NIP-01 id only for nostr events. Each actuator must define its own **faithful
render** and **fingerprint**:

| actuator | the "action" | faithful render must show | fingerprint |
|---|---|---|---|
| `publish` | a nostr event | kind + all tags + hidden/bidi flags (as today) | NIP-01 event id |
| `exec` (Nops) | a shell command | the **exact** argv; arg-injection & hidden-char flags | sha256 of the argv |
| `connector:*` | verb + params | verb, pinned host/mailbox, params; that it's read-only | sha256 of {verb,params,pin} |
| `draft` / `pr` | text to send/commit | the exact text; target (recipient/branch); that it's a *draft* | sha256 of the rendered artifact |

**Rule:** an actuator without a defined WYSIWYS render + frozen fingerprint cannot
be granted. No actuator reuses another's hash.

**2. Confused deputy / egress repoint.** The actuator holds real capability (a
credential, box `exec`, a relay). The template must never widen the grant — egress
is pinned by the grant's `pin`, verbs by its `verbs` (both structural,
`connectors.md`); a template naming a different host/mailbox/branch is refused.

**3. Cross-actuator approval replay.** The proposal MUST commit to `{cap, verbs,
fingerprint}` so an approval for a `draft` can't be replayed to authorize an
`exec`. The `["approval", id, approver]` tag references that specific proposal.

**4. Request-metadata leak — gift-wrap the *request*, not just the reply.** The
request contains *what you're about to do* (a shell command; a draft prompt with
private content). Stock DVM/ContextVM default to plaintext (spike); our invariant
sets `encryptionMode: REQUIRED`. The adversarial-observer test applies to the
request, not just the result.

**5. The autonomous-execution footgun (spike).** ContextVM runs a tool handler
autonomously — the propose→approve→sign gate is **not** transport-enforced. Rule:
**an actuator is structurally incapable of enacting** — it returns a proposal and
holds no signing/enact capability; the gate is a property of the code, not a
discipline.

**6. Supply chain of actuator code.** An actuator acts with real capability, so a
compromised implementation is a confused deputy at the source. First-party +
reviewed + verb-structural today; any third-party actuator needs sandboxing *and*
the grant/approval gate before it touches a credential.

**7. Off-box key on a portable device (director path).** Portability spreads a
signing key across surfaces. Keychain `WhenUnlockedThisDeviceOnly` + per-device
keys (no key copied) bound the blast radius; the ContextVM NIP-46 adapter (spike
delta) keeps the *acting* key off a shared box entirely.

This *extends* `threat-model.md`: its approver-binding ceremony (channel authority
as a scoped grant) covers *who* approves; this covers *what* is enacted once
actuators are plural.

---

## Part III — The research plan (all aspects, to a robust design)

Organized as workstreams. Each names concrete targets and the decision it feeds.

### A. Prior-art deep dives
- **Nostr, act/capability side:** the NIP-90 postmortem (*why* "out of control" —
  read the maintainer threads); NIP-26 deprecation rationale; NIP-46/59/44/40/17
  (the primitives the handshake composes); NIP-89 handler ads (discovery);
  NIP-47 + NIP-67 permission model in full.
- **MCP-over-nostr:** ContextVM `sdk` + `proxy-cli` **source** — **DONE 2026-07-23
  (see Part II spike result): adopt-with-wrapper.** Remaining threads: the archived
  DVMCP for its lessons; any DVM encrypted-params / gift-wrapped-request work; and
  ContextVM's CEP spec repo for the discovery-kind divergence.
- **MCP standard:** the authorization spec (OAuth 2.1, PRM, resource indicators)
  — to argue the divergence deliberately, not by omission.
- **Broader agent interop:** A2A capability-based auth (a2aproject discussion
  #1404); the 2026 papers — **AIP** (verifiable delegation across MCP & A2A),
  **ACP** (admission control for agent actions), **Vouchsafe** (zero-infra
  capability graph), the agentic-skills supply-chain analysis.
- **Capability tokens:** macaroons (caveats, but shared-secret forgeable),
  **biscuit** (Ed25519 + Datalog, offline verify, attenuation — the closest
  cryptographic cousin to a NIP-DA re-grant cascade), UCAN (DID + nested JWT,
  quadratic bloat), GNAP (the OAuth successor). Map each onto our re-grant model.
- **Payment/metering:** Cashu ecash, L402 / HTTP-402, Routstr — for metered or
  agent-to-agent actuators.

### B. Design questions to resolve (the open decisions)
1. **Scope schema** — the action-grant object: `{ cap, verbs, pin, budget,
   expires, tier }`. **Drafted in Part II·6 (freeze pending review).**
2. **Event kinds** — proposal / approval inner kinds (the sketch's placeholders);
   coordinate ranges with the DVM/registry to avoid collisions.
3. **Attenuation & re-grant cascade** — reconcile with nvoy#1's pinned cascade
   semantics (derived-scope sub-grants attenuate; root rotation cascades). Is the
   action grant attenuable per-verb the way NIP-DA P5 makes data per-field?
4. **Revocation semantics** — rotation vs expiry vs explicit 441; cascade across
   actuators; what a mid-flight approval sees when the grant dies.
5. **Multi-approver / quorum** — the architecture already supports a Director
   *set*; define quorum, and how the provenance tag represents N-of-M.
6. **Replay / anti-rollback** — approval binds to one proposal id (have); add the
   `(v,u)` sequence lesson from P2/P3 if actions can supersede.
7. **Actuator interface** — a normative `actuator(template, grant) → result`
   contract so drafting/publish/exec/PR/email are uniform; where the WYSIWYS
   fingerprint is computed and re-checked (per nact#7).
8. **Transport choice** — MCP-over-nostr (ContextVM) vs your HTTP+NIP-98 vs
   grants-over-relays; likely all three behind one actuator contract.
9. **Discovery** — advertise *capability types* via NIP-89 without leaking the
   private wiring.

### C. Threat model & formal analysis
- **Worked in Part II·7** (WYSIWYS-per-actuator + the new cross-actuator threats).
  Remaining: extend `nact/docs/threat-model.md` to the generic actuator: **confused-deputy**
  (actuator tricked into acting outside scope), **egress repointing**, **approval
  replay / substitution**, **template/rendered mismatch** (WYSIWYS across
  actuators, not just nostr events — a shell command and a PR body each need a
  faithful render), **metadata leakage** (gift-wrap the request, not just the
  reply), **supply-chain** of actuator code (the agentic-skills paper).
- Consider a **formal treatment** of the attenuation + approval invariants (biscuit's
  Datalog, or a small TLA+/Alloy model of "no enact without a live grant *and* a
  bound approval").

### D. Interop strategy
- Can the `["approval", …]` provenance tag **travel** into MCP/A2A land — e.g.,
  as an admission-control record an ACP-style gate recognizes? Prototype a bridge:
  an A2A/MCP action that carries a nostr approval proof.
- Decide whether Nave *consumes* external MCP tools (via ContextVM) under the same
  approval gate — i.e., the gate wraps *any* actuator, local or remote.

### E. Payment / metering (optional, later)
- If an actuator is metered (external inference, a paid API), spec the Cashu/402
  path as a *fifth* connector auth-strategy alongside `static-key`/`oauth`.

### F. Community engagement (leverage others' experience)
- **Who:** the nostr-protocol/nips maintainers (fiatjaf et al.) for the
  microstandard framing; **gzuuus** (DVMCP/ContextVM) on MCP-over-nostr auth;
  **benthecarman** (NIP-47/67) on the permission object; the **A2A** and **MCP**
  auth working groups for cross-ecosystem interop; **OpenSats** (nostr grants) for
  funding/socialization; the biscuit/UCAN communities on attenuation.
- **How (the estate's playbook):** build the generic actuator + approval path as
  working software first; publish the **hardening-in-public** essay and an
  Ngage/Quill demo; float the `["approval"]` provenance tag as a small, isolated
  proposal (not a grand agent NIP); open the spec-repo issue and gather review;
  PR only with two implementations in hand (the Nscope pattern).
- **Where it plugs into #2411:** the P-series + reversed-arrow are the novel
  content; the ACT-side approval provenance is the natural companion PR.

### G. Validation
- **Reference implementations** (≥2, per playbook) — the Nactor actuator +
  approval path, and one independent client that renders + grants an approval.
- **Conformance tests** — extend the `nvoy/test/mcp-conformance.mjs` pattern to
  the actuator contract and the approval handshake.
- **Cross-client demo** — an approval rendered + granted in a *second* nostr
  client, and the enacted artifact's provenance verified by a third party.
- **Adversarial-observer test** (house law) — a hostile relay learns nothing about
  what was requested, by whom, or what was approved.

### H. Sequencing / decision gates
1. **Spike ContextVM — DONE (2026-07-23, Part II):** adopt-with-wrapper; the human
   gate (our handler) + a NIP-46 signer adapter are the known deltas. Transport
   candidate settled.
2. **Freeze the scope schema** (from NWC/NIP-67) → unblocks the actuator contract.
   **Drafted (Part II·6); freeze pending Director review.**
3. **Generalize the actuator interface** in Nactor (publish/exec/connector →
   `actuator(template, grant)`), drafting as the newest instance.
4. **Threat-model + WYSIWYS-per-actuator** (chains nact#7–#11).
5. **Two implementations + conformance** → *then* consider the NIP.
- **WIP limit still applies** (two tracks); this is a design track, not a licence
  to fan out.

---

## Director's calls — resolved (2026-07-23)

1. **Home + issue** → `nave.pub/docs/`; tracking issue in **nave.pub** (this is
   protocol/spec that drives the Nave, not `nact`-internal).
2. **Ambition** → the **linear path**: an internal actuator abstraction first,
   *intending* to become a proposed community microstandard. Build-first, per the
   Nscope playbook; the NIP is a later gate, not the goal.
3. **Framing** → **NCP is our MCP.** NIP-DA = the read/resource half, Scoped Agent
   Actions = the verb/tool half; Nactor is NCP's act-side actuator engine.
4. **Name** → **Scoped Agent Actions** (the verb/tool half of NCP).
5. **ContextVM** → *research decides.* Scoped to "candidate transport for NCP's
   MCP doorway"; workstream A/H settles it.

**Still the Director's to weigh in on as the research reports back:** whether NCP
absorbs `ncp.md` wholesale (rename/merge) or this doc sits beside it; how far to
push the microstandard before a NIP; and the ContextVM adopt/reject call.

## References
- NIP-90 (unrecommended / microstandards): https://nips.nostr.com/90 · registry https://github.com/nostr-protocol/data-vending-machines
- NIP-26 (unrecommended): https://nips.nostr.com/26
- NIP-47 NWC: https://nips.nostr.com/47 · NIP-67 Wallet Auth PR: https://github.com/nostr-protocol/nips/pull/851
- ContextVM: https://github.com/ContextVM · docs https://docs.contextvm.org/ · archived DVMCP https://github.com/gzuuus/dvmcp
- MCP authorization spec: https://modelcontextprotocol.io/specification/draft/basic/authorization
- A2A capability auth: https://github.com/a2aproject/A2A/discussions/1404
- AIP (delegation across MCP/A2A): https://arxiv.org/abs/2603.24775 · ACP (admission control): https://arxiv.org/pdf/2603.18829 · Vouchsafe: https://arxiv.org/pdf/2601.02254
- Routstr / Cashu: https://docs.routstr.com/overview/
- Your artifacts: nact/docs/{scoped-action-approvals,architecture,connectors,nops,threat-model}.md
