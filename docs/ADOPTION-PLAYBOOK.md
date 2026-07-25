# The Adoption Playbook

*2026-07-25. The strategic plan for getting the Nave work adopted — grounded in
the estate as it actually is (see `docs/architecture/`), in the estate's own
playbook (build-first, two implementations, then the PR), and in the honest
diagnosis that building is finished enough and **engagement is the stalled
phase**. House style applies: state limits out loud.*

---

## 0 · The premise

The estate has three separable adoption games. They share assets but have
different audiences, different clocks, and different definitions of "won."
Conflating them is how effort diffuses. Every action below is tagged to one.

| Game | The asset | The audience | "Adopted" means |
|---|---|---|---|
| **A — Provenance** | the `["approval", id, approver]` atom: public, relay-anchored, third-party-checkable proof a human approved an agent action | AI-agent standards people (HDP, A2A, MCP, NIST-adjacent) — **not** nostr people | the nostr-anchored claim format appears in someone else's draft, SDK, or gate |
| **B — Protocol** | NIP-DA / Nscope + the reference deployment | nostr protocol devs + client builders | a client we didn't write renders or issues a grant; #2411 gets substantive review |
| **C — Product** | warm.contact + Quill (the only piece a normal person can want) | people with a reconnect backlog | a stranger uses it weekly without us on the phone |

**Priority order: A > B > C** for the next quarter. A has a live external clock
(below), the broadest audience, and doesn't require anyone to adopt nostr. B
feeds A (the working substrate is the credibility). C runs as a background
track because its feedback loop is slow and its lessons don't transfer to A/B.

**The one-sentence pitch per game:**
- A: *"As agents proliferate, 'was this AI action human-approved, and by whom?'
  needs an answer anyone can verify. Ours is live: a signed approval anchored
  on public relays, checkable by a third party with no registry and no trust
  anchor beyond the key."*
- B: *"Private, live, revocable data over public relays — revocation is a key
  rotation, not a policy. Two interoperating implementations, seven working
  clients, a reference relay you can point any client at."*
- C: *"People reached out; you never replied. Quill drafts each reply in your
  voice; you press send. Nothing is stored anywhere you can't revoke."*

## 1 · The external clock (why now, specifically)

- **HDP** ([draft-helixar-hdp-agentic-delegation-00](https://datatracker.ietf.org/doc/draft-helixar-hdp-agentic-delegation/))
  is an *individual submission* that **expires 2026-09-26**. Individual drafts
  get refreshed as `-01` with feedback folded in. A substantive review + bridge
  proposal delivered in August lands exactly in that window, from one of the
  few people with a *working implementation* of the idea. After `-01`, we're
  commenting on someone else's settled shape.
- **A2A #1404** ([SEP: capability-based authorization](https://github.com/a2aproject/A2A/discussions/1404))
  is a draft SEP — pre-decision, the highest-leverage moment to inject the
  "offline-verifiable human-approval record" requirement with a demo.
- NIST's AI Agent Standards Initiative (Feb 2026) means institutional attention
  on exactly this problem class through year-end. The window where a solo
  builder with working code gets read is **now**; it closes as vendors ship.

## 2 · Phase 0 — the two assets everything depends on (by Aug 8)

Nobody engages with eight repos. They engage with a loop they watched and a
page they skimmed. Build these before any outreach; both are days, not weeks.

1. **The Loop — a ≤2:30 screen recording** of the full delegated action:
   scribe drafts (bunker-signed, key never on the host) → draft lands on the
   Ngage desk, pen-verified → the Director signs in his own hand → the post is
   live → **cut to a third party verifying the provenance against the relay**.
   For game A, add the 30-second variant that shows *only* the verification —
   that's the clip standards people forward. Publish on nave.pub + Substack;
   this is also the demo link inside every ask.
2. **The Front Door — nave.pub hub v1**: the Identity=Freedom hero, the app
   grid, the protocol case, prominent #2411 + demo links, /about. Content is
   already written (ECOSYSTEM-HUB §2 says so); this is assembly. The revoicing
   gate applies to *essays*, not to the hub shipping — do not let the gate
   block the door. Ship the hub with the two essays that are ready
   (`hardening-a-protocol-in-public`, `protocol-as-fuel` is published), queue
   the rest.

**Explicit non-gate:** the remaining six essays do NOT block Phase 1. Prose
persuades, but the HDP clock beats the revoicing programme. Essays land in
Phase 2.

## 3 · Phase 1 — five named engagements (Aug 8 – Sep 15)

The next five people are not users; they are five individuals, each with a
bespoke, small, specific ask, each carrying the demo link. **Rule: five asks
sent before any new feature is built.** Track each as a GitHub issue
(issues-first) with: the person, the ask, date sent, response, next step.

| # | Who | Game | The ask (specific, small) | Why they'll answer |
|---|---|---|---|---|
| 1 | **HDP authors (Helixar)** — via the draft's contact + the [GitHub repo](https://github.com/Helixar-AI/HDP) | A | "Your hop-record travels point-to-point; here's a *public, relay-anchored* variant of the same claim, live, with a bridge format both directions (`{"scheme":"nostr","approval_event":…}`). Review before your -01? Happy to be an implementation report." | you're evidence their idea is real, from outside their shop; drafts need implementation reports |
| 2 | **A2A #1404 thread** (@kurt-r2c) | A | one comment: the SEP should require an *offline-verifiable human-approval record*, not just an auth mechanism; here's a working one + the demo clip; offer the bridge tag (`["a2a-task", id]`) | pre-decision SEPs want concrete prior art; nobody else in the thread has running code |
| 3 | **gzuuus (ContextVM)** | B→A | "Read your SDK v0.13 source; verdict adopt-with-wrapper. Two frictions: no NIP-46 signer, discovery kinds diverge from NIP-89. I built the human-approval gate your transport is agnostic to — want the writeup / a PR for the NIP-46 signer adapter?" | maintainers answer people who read their code and arrive with a patch |
| 4 | **One nostr reviewer** (fiatjaf on microstandard framing *or* benthecarman on the NWC-derived permission object) | B | review ONE section — the revocation model or the action-grant schema — not the ecosystem. Lead with the demo + the hardening essay, not the spec | scoped asks get answered; "review my ecosystem" doesn't |
| 5 | **One real warm.contact user** — a known person with an actual backlog | C | "Use it two weeks; I watch you struggle once on a call" | it solves a felt problem; personal ask |

**Plus one application, not an ask: OpenSats.** The grant one-pager forces the
crispest articulation of B, and a yes converts to credibility for 1–4. Submit
in this phase.

**Outreach mechanics.** Every ask: ≤150 words, one link (the demo), one
concrete request, one sentence of proof-of-work about *their* thing. No
"check out my project." Follow up exactly once, after 10–14 days. All five go
out within one week of each other so responses cluster and can be compared.

## 4 · Phase 2 — publish into the warmed channel (Sep – Oct)

Only after Phase 1 responses exist (even silences are data):

- Essays, in leverage order: **"The approval, anchored"** (game A — new,
  ~1,500 words: the provenance atom, the HDP/A2A landscape, the bridge — this
  is the essay strangers will cite) → *Ngage, or the delegation arrow
  reversed* → *the zero-knowledge address book* → the rest of the ROADMAP
  queue through the revoicing programme.
- Cross-post to nostr + Substack; every post carries the demo.
- **Float the provenance tag as a small, isolated proposal** (a spec-repo
  issue + a short page), explicitly *not* a grand agent NIP — positioned as
  "the nostr anchoring for an HDP-style claim," referencing whatever came back
  from asks 1–2. PR only with a second implementation in hand (the playbook's
  own rule).
- Shepherd #2411 with prose: one thread comment linking the hardening essay +
  the live deployment, then stop pushing; its fate is a function of nostr
  maintainer bandwidth, not effort.

## 5 · Phase 3 — convert responses (Oct – Dec)

Branch on what Phase 1 returned:

- **HDP/A2A engaged →** build the bridge for real: emit the nostr approval
  inside their field format; write the joint interop note; ask to be listed as
  an implementation. This becomes the second implementation that justifies the
  provenance-tag proposal.
- **A nostr client engaged →** the cross-client demo (an approval rendered and
  granted in a client we didn't write) — the estate's own bar for a NIP.
- **A warm.contact user stuck →** their friction list becomes C's backlog;
  recruit users 2–3 from *their* circle, not ours.
- **Nothing engaged →** see §7. Do not route around silence with more
  building.

## 6 · Operating cadence

- **WIP limit stands, and outreach occupies a track.** Two tracks: (1)
  engagement (this playbook), (2) one build track — which until further notice
  is *only* items that serve an ask (the demo, the NIP-46 signer adapter PR,
  the bridge). The generic-actuator abstraction, new actuators, new apps,
  console polish: **frozen** unless a response demands them.
- **Weekly**: one review of the five engagement issues — sent / waiting /
  replied / converted. The scribe keeps drafting daily; that pipeline is now
  maintenance, not progress.
- **The metric that counts** is conversations with named humans per week.
  Commits stopped being the metric on 2026-07-25.

## 7 · Kill criteria & honest limits

State the limits out loud:

- **Game A kill test:** if by **Nov 1** — after the HDP review, the #1404
  comment, the essay, and one follow-up each — no standards-side human has
  substantively engaged, the public-provenance edge is a paper edge. Fold it:
  keep the tag in our stack, stop evangelizing it, and reassess whether C is
  the only live game.
- **Game B honest ceiling:** nostr's capability-hungry audience is small.
  Success = respected microstandard + borrowed patterns, not ubiquity. If
  #2411 sits unreviewed through year-end, that is maintainer bandwidth, not a
  verdict on the design — but it also means B cannot be the lead game.
- **Game C kill test:** if two real users each churn inside a month for the
  same reason, the product thesis needs revision before any growth push.
- **The standing risk** (ECOSYSTEM-HUB named it first): losing interest once
  the hard unknown is solved. Outreach is the current hard unknown. The
  failure mode is answering silence with a new subsystem. The counter is §6's
  freeze and the five tracked issues.
- **What this playbook does not claim:** that adoption is likely. It claims
  the *cheapest honest test* of value is five bespoke asks against a live
  demo inside an open standards window — and that until that test runs,
  no amount of building produces information.

## 8 · Asset ↔ ask map (so nothing is built without a customer)

| Asset | Serves | Status |
|---|---|---|
| The Loop video (2:30 + 0:30 cut) | every ask | **build now** |
| nave.pub hub v1 | every ask, OpenSats | assemble now (content exists) |
| "The approval, anchored" essay | asks 1–2, Phase 2 | write in Phase 2 |
| ContextVM NIP-46 signer adapter PR | ask 3 | small; build when sending ask 3 |
| HDP bridge emitter/verifier (~a page of code) | ask 1, Phase 3 | build with ask 1 |
| OpenSats one-pager | funding | write in Phase 1 |
| Architecture doc set (`docs/architecture/`) | onboarding whoever says yes | ✅ shipped 2026-07-25 |
| Anything else | — | frozen |
