# Library roadmap — the writing programme

Two tracks: **upgrade** the six existing essays so each reflects the ecosystem's
*current* full scope, and **write** the pieces covering everything built since
they were drafted. One scope per piece, so twelve essays don't say the same thing
six times.

## The full scope every piece should be aware of

Even when an essay is narrow, it should be written by someone who knows the whole
board:

- **The protocol** — NIP-DA scoped data grants (kinds 30440 / 440-in-1059 / 10440),
  and the P-series hardening on top of it.
- **The N-family** — Nvoy (delegation), Nact + Nactor (agentic action, brokered
  credentials), Nontact, Nvelope, Nherit, Notegate, Nscope, Noir, Ntrigue, and
  **Ngage** (the sovereign posting desk).
- **warm.contact** — inbound-first contact collection with its own `wc1` envelope,
  plus **Quill**, the per-user reconnect agent.
- **The control plane** — Cockpit and Console (sovereign-gated), and **Nops**
  (proposed: ops the Nave way).
- **Proposed integrations into Buzz.**

## Track A — upgrade the existing six

| Essay | What the upgrade must add |
|---|---|
| `protocol-as-fuel.md` | The portfolio has grown well past the original seven — bring in warm.contact/Quill, Ngage, the control plane, and the P-series hardening. |
| `scoped-autonomy.md` | Same scope refresh, told through autonomy rather than portfolio: agents on a leash, the broker, agent→sovereign. |
| `quill-per-user-agent.md` | Rewrite against the *shipped* architecture — the Swift grant plane, profile grants, MCP stdio custody. |
| `noir-architecture.md` | Noir as proving ground, now that the protocol it proved has hardened underneath it. |
| `cryptographic-boundary-conditions.md` | Fold in what the P-series changed about what a boundary can honestly promise. |
| `firewall-melted-docker.md` | Lightest touch — a war story stays a war story; add only the aftermath that matters. |

## Track B — the unwritten work (new essays)

| Working title | Scope |
|---|---|
| **Hardening a protocol in public** | The P-series: grant authentication, anti-rollback sequence, incremental inbox, metadata hardening, multi-device consistency, per-field key trees. What each weakness was, what the fix buys — and the honest framing (rollback becomes *detectable*, not impossible). |
| **The zero-knowledge address book** | warm.contact's shipped architecture: the `wc1` envelope implemented twice, the relay that can never read a submission, and the Swift grant plane that made credentials Director-signed grants. |
| **Ngage, or the delegation arrow reversed** | Agents grant *to* the sovereign: drafts arrive as scoped grants, get reviewed, and publish signed by your own key. The steering grant flowing back the other way. |
| **How an agent reaches Nave** | The MCP interface: the pinned two-tool contract, nvoy-mcp, stdio custody on-device, and why an app talks to Nave through a contract instead of the wire format. |
| **Buzz, integrated** | The proposed Buzz integration — what it would take, what the grant model offers it, and what stays unsolved. |
| **The room's control plane** | Cockpit, Console, and the proposed Nops: a sovereign-only gate, and why ops should be signature-authorized rather than bearer-token'd. |

## House style (from the published work)

Structural and argumentative, never announcemental. Open on the claim or the
tension. Name the actual mechanism. **State limits out loud** — honesty about what
something can't do is part of the argument. No launch voice.
