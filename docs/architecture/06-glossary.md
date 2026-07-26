# 06 · Glossary — every name, one line

## The protocol

- **NIP-DA / Nscope / Scoped Data Grants** — the root primitive: encrypt data
  under a scope key, gift-wrap the key to a grantee, revoke by rotating.
  Kinds 30440/440/441/10440. PR nostr-protocol/nips#2411.
- **Scoped Action Approvals** — the act-side spec name: how an action is
  proposed and approved (propose → approve → sign → enact). Not yet a NIP, on
  purpose.
- **Scoped Agent Actions** — the umbrella/concept name for the act side; the
  generic-actuator design (`docs/scoped-agent-actions.md`).
- **NCP (Nostr Context Protocol)** — "our MCP": context from the nostr grant
  graph. Resources = data grants; tools = agent actions.
- **The P-series (P1–P6)** — the 2026-07-22 spec hardening: grant-author
  verification, anti-rollback, multi-device, incremental inbox, per-field
  attenuation, metadata hardening.
- **Scope / scope key** — the random 32-byte key a dataset is encrypted under;
  possession = access; rotation = revocation.
- **Gift wrap** — NIP-59 (seal kind 13 + wrap kind 1059): how every grant and
  draft travels; relays see only ciphertext.
- **WYSIWYS** — what you see is what you sign: approval binds to the frozen
  bytes' fingerprint, per actuator.
- **`["approval", id, approver]`** — the provenance tag: public proof an agent
  action passed a human tap. The one NIP-worthy atom.
- **Attenuation** — a sub-grant strictly narrower than its parent (fields,
  verbs, budget, TTL), enforced by derivation, not policy.

## Scope-name namespaces (AD-8)

`profile:*` · `credential:*` (e.g. `credential:anthropic`) · `data:*` ·
`capability:*` (action grants) — plus the working scopes `draft:post/<id8>`
(a draft offered to the Director), `steer:draft` (the Director's steering to
his pens), `channel:bind` (approver-channel authority).

## Apps (the N-family)

- **Nave** — the hub (`nave.pub`), the design system, deploy config, and docs
  (this repo). Also the fleet-root identity the box boots under.
- **Nontact** — address book as emergent view. **Nvelope** — live documents.
  **Notegate** — serverless tip line. **Nherit** — break-glass legacy vault.
  **Noir** — spycraft game (rotation = burn notice) + its AI "Noir's
  Director". **Ntrigue** — party game. All pure NIP-DA clients.
- **Nvoy** — scoped delegation to agents; the **Grant Ledger** (source of truth
  for all grants); mounts as the MCP server `nvoy-mcp`, which also custodies
  the runtime key.
- **Nact** — the act-side control plane (approve/enact UI). **Nactor** — the
  per-box act runtime (queue, role keys, actuators). A role, not a singleton.
- **Ngage** — the Director's sovereign posting desk: drafts arrive as grants
  only he can read; he signs in his own hand. The "reversed arrow."
- **Nops** — nostr-native server ops (concept; today's GitHub-Actions+SSH
  channel is the "proto over the wrong transport").
- **Nfra** — the sovereign substrate: boxes, keys, relay, bunker, CI.
- **warm.contact** — the zero-knowledge inbound contact app; own `wc1` sealed
  box crypto; partner, not a NIP-DA client.
- **outerjoin** — native macOS contacts sync; no nostr at all.

## People, agents, keys

- **The Director** — the human root authority (James for the fleet; each
  warm.contact user for their own Quill estate). Signature-gated acts are his
  alone.
- **sovereign** (`jaf@dequalsf.com`) — the root key. Custody: Bunker46,
  invoked by hand.
- **operator** — the delegated day-to-day login signer in the bunker (iPhone
  path).
- **nave / nactor / luke / brain / nact_jaf / noir** — the SOPS-custodied fleet
  identities: fleet root · runtime · acting agent · proposer ("Luke is one
  agent, two keys") · approvals carrier · legacy hub.
- **Luke** — James's flagship agent (posts as himself, box path, Telegram
  approval). **brain** — Luke's proposer identity; thinks, never acts.
- **Quill (canonical)** — warm.contact's reference reconnect-agent instance.
- **James's Quill / jaf-quill** — the Director's own drafting hand. ONE key,
  sole custody Bunker46 (2026-07-24), NIP-46-scoped to draft kinds only;
  every drafter (Mac `warm quill-draft`, box bunker-mode scribe) borrows its
  signatures.
- **jaf-scribe** — the drafting *program* (in `luke/`) that signs as
  jaf-quill; box entrypoint sealed to bunker-mode/break-glass.
- **The Buzz nest** — `mydude` (proving hand), `kerouac` (drafting hand, Buzz
  side), `dennis` (foraging hand): agent-held keys on the Buzz relay; the
  Director holds grants over them, not keys.
- **Pen / deliverer** (Ngage) — a pen is a drafting hand whose signature the
  desk verifies and who receives steering; a deliverer (e.g. the Nactor) is a
  courier — admitted, never steered.

## Mechanisms & doctrine

- **AD-1…AD-11** — the architecture-decision log
  (`docs/nave-architecture-decisions.md`). The load-bearing ones: **AD-2**
  identity-not-server · **AD-6** broker vs grant-to-app by sensitivity ·
  **AD-9** evidence-only per-identity voice · **AD-10** approval happens where
  the signing key lives · **AD-11** one sign-in, promote never level down.
- **Box path / director path** — the two approval routes (AD-10), forced by
  key custody.
- **Broker vs grant-to-app** — Nactor holds and injects (on-box,
  non-sensitive) vs the identity holds its own scoped credential (off-box or
  content-sensitive).
- **Actuator** — `actuator(template, grant) → result`; publish / exec /
  connector / draft. Structurally incapable of enacting.
- **Risk tiers** — low (one-tap) / elevated (full render first) / critical
  (sign-on-device only).
- **Bunker mode** — a drafter signing over a scoped NIP-46 connection to
  Bunker46; the key never touches the host.
- **Keyless boot** — the north star: no persistent secret on disk; the
  Director unseals over nostr at boot (AD-4, deferred by choice).
- **Issues-first** — work = a GitHub issue before code; every commit bookended
  by its issue (Director, 2026-07-23).
- **The adversarial-observer test** — house law: every flow ends by asserting
  what a hostile relay operator cannot see.
- **nave-connect / nave-titlebar** — the shared sign-in module (NIP-07 /
  NIP-46 / local) and unified title bar, vendored per app.
- **The library** (`library/`) — the narrative/essay layer; the revoicing
  programme gates publishing ("nothing else ships in the averaged AI voice").

## Kind numbers seen in the wild here

30440 scoped data set · 440 grant · 441 revocation · 10440 grant index ·
31440/442 v2 attenuable pair · 1059 wrap · 13 seal · 24133 NIP-46 RPC ·
27235 NIP-98 auth · 24140 pen attestation · 24440 nvoy app messages ·
10002 relay list · 31990 handler advert · 5 tombstone · 1 the post itself.
