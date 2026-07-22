# Nave — State of the Ecosystem (extracted text)

*Auto-extracted from the .docx for search and for writing against. The .docx remains the artifact.*

NAVE

State of the Ecosystem

A complete status report

James Fairweather

20 July 2026

GitHub: JAFairweather · nostr: jaf@dequalsf.com

“The signature is the authorization; the rotation is the revocation.”

Contents

TOC \h \o &quot;1-3&quot;

Executive Summary

The signature is the authorization; the rotation is the revocation.

Nave is a self-hosted ecosystem built around a single idea: scoped autonomy — an AI agent (or any application) that is bounded on both what it may see and what it may do, with a nostr signature as the sole root of authority and key rotation as the universal act of revocation. There is no central server to trust, no access-control database to compromise, and no token that silently expires — an agent&apos;s permissions exist only as long as the cryptographic key that grants them, and cutting them off is a single, verifiable act.

That one idea — the scoped, revocable data grant — has been worked out across an entire portfolio in a strikingly short window. As of this report the ecosystem is roughly ten days old (first commit 9 July 2026), spans eleven-plus repositories, and has produced: one protocol with two live reference implementations and an open pull request against the nostr NIPs repository; two distinct families of applications — seven apps built directly on that protocol, plus a native “contacts” cluster (warm.contact, its Quill reconnect agent, and outerjoin) that integrates with Nave rather than being built on the spec; two agent runtimes (Nactor for acting, NCP for perceiving); and a hardened, three-box production fleet that survived and recovered from a real infrastructure incident on the very day this report was written.

The headline status, in one line: a protocol, two app families, two runtimes, and a hardened three-box fleet — all live, all answering to one set of keys, all built and operated in the open in about ten days.

What&apos;s actually running today

A draft NIP (nostr-scoped-data-grants, PR nostr-protocol/nips #2411) with independent JavaScript and Go reference implementations that interoperate live on public relays.

Seven applications built as pure clients of that protocol (Nvoy, Nvelope, Nherit, Nontact, Notegate, Ntrigue, Noir), ranging from alpha to shipped.

A native contacts cluster — warm.contact (zero-knowledge inbound contact collection), its in-progress Quill reconnect agent, and the independent outerjoin contact-sync app.

Luke, James&apos;s own flagship delegated agent, running a live twice-daily propose → approve → sign → broadcast posting loop under a nostr-signed approval gate.

Nactor, the act-side runtime (V1 built, five credential providers brokered live) and NCP, the perceive-side runtime (concept, with a working v0 egress proxy).

A three-box production fleet (main Nave, relay/bunker, warm.contact) rekeyed to a single management key, hardened firewalld-free after a same-day outage, and verified externally.

The Spine: One Protocol, Two Directions

Everything in Nave organizes around a single spine: one underlying protocol idea, expressed in two directions. The first direction is perceiving — what data an agent is allowed to see (data-in). The second is acting — what an agent is allowed to do (actions-out). Both directions share the same authority model: a cryptographically signed, scoped, revocable grant.

PERCEIVE (data-in)

ACT (actions-out)

Protocol

Scoped Data Grants — NIP-DA. Real draft NIP, built, with JS↔Go interop.

Scoped Action Approvals. Sketch only, deliberately not yet a NIP.

Runtime

NCP — concept, with a v0 egress organ live.

Nactor — built, V1, HTTP + NIP-98.

Instances

Nvoy, Nvelope, Nontact, Notegate.

Nact (social actions), Nops (server operations).

Mechanism

Grant: kinds 30440 / 440 / 441 / 10440.

Approval: propose → approve → sign → enact (NIP-59/46 today).

Table 1 — The spine: the same authority model applied to what an agent may see versus what it may do.

Nvoy is the connective tissue that runs both ways at once: it feeds ordinary agents their data as scoped grants, and it feeds Nactor its own operating configuration as a scoped grant too — the same primitive serving as both a data pipe and a control plane.

The frontier beyond today&apos;s build (recorded in the protocol&apos;s own FUTURE.md and DESIGN.md) is a request that is simultaneously a grant and an enact — perceiving and acting collapsing into a single signed exchange, with providers becoming first-class over NIP-05 and revocation chaining across providers. That is direction, not yet build.

The Protocol: The Foundation

Scoped Data Grants — NIP-DA

The root of the whole ecosystem is nostr-scoped-data-grants (submitted as PR nostr-protocol/nips #2411). Status: spec complete as a draft, with kind numbers still placeholders pending review. It defines four event kinds:

Kind 30440 — Scoped Data Set: the data itself, encrypted with NIP-44 under a random 32-byte scope key.

Kind 440 — Data Grant: a gift-wrapped event that hands a recipient the scope key needed to decrypt a given data set.

Kind 441 — Revocation: the act of cutting off a grant.

Kind 10440 — Grant Index: a recoverable index of a user&apos;s own grants, derivable from their nsec alone — no separate backup needed.

The defining design choice is that revocation is key rotation, not token expiry: there is no server-side flag to flip and no bearer token that simply times out. Rotating the scope key and republishing makes every previously issued grant permanently unreadable, with no cooperation required from any relay. Two independent reference implementations exist — a roughly 200-line JavaScript library (nipxx.mjs) and a Go CLI — and interop between them has been verified live against public relays. Critically, the design requires zero relay changes: any existing nostr relay can carry this traffic today.

Scoped Action Approvals

The act-side peer of NIP-DA is Scoped Action Approvals — deliberately still just an exploratory sketch, not a submitted NIP. The build-first philosophy here is explicit: ship working software, and only formalize a NIP once cross-client demand actually appears. The one piece of this considered ready to standardize is small but load-bearing: a verifiable [&quot;approval&quot;, id, approver] tag that stands as public, checkable proof that a given agent action passed an explicit human tap before it happened.

The Apps: Two Families

Nave&apos;s applications split cleanly into two families: apps built directly on the NIP-DA spec, and a native “contacts” cluster that integrates with Nave&apos;s credential model without being a client of the data-grant protocol itself. A third entry, Luke, is James&apos;s own flagship agent and the pattern the rest of the ecosystem generalizes from.

2a · The NIP-DA nostr family

Seven applications, each a pure client of the scoped-data-grant protocol:

App

What it is

Status

Nvoy

Scoped, revocable data delegation to AI agents; mounts as an MCP server with 7 tools.

v0.1 working client + console “Ledger”; not npm-published while the protocol is still a draft.

Nvelope

Secure document sharing — live folders, real revocation, one-key recovery. Uses Blossom for large blobs.

v1 feature-complete alpha (milestones M1–M5).

Nherit

Family estate / legacy break-glass vault — dead-man&apos;s-switch escrow plus SLIP-39 paper Shamir secret sharing.

Alpha, ~150 tests; reuses Nvelope&apos;s manifest pattern.

Nontact

The no-maintenance address book — self-maintained records with scoped access instead of copied contact data.

Alpha prototype.

Notegate

Serverless secure tip line for journalism — proof-of-work toll, gift-wrapping, timing jitter against traffic analysis.

Alpha, v1 feature-complete (M1–M4).

Ntrigue

A phones-only party game of secrets and blackmail — “revoke a secret, but you can&apos;t un-tell it.”

Built v0.1 (MIT license); v1 stage-mode and AI game-master unbuilt.

Noir

Nostr spycraft game — grants are earned intel, and a key rotation is a felt “burn notice.” The in-game Director is itself an Nvoy agent.

Active, milestone 1 of 6; M3 (AI Director) in progress.

Table 2 — The NIP-DA app family, built directly on the scoped-data-grant protocol.

A correction worth recording on the public record: an earlier note that “noir was superseded by nave.pub” was wrong. Noir the game is active and shipping; the only thing that moved was the website platform (the noir→nave.pub domain flip), not the game itself.

2b · The native “contacts” cluster

These apps integrate with Nave&apos;s credential and identity model but are not built on the NIP-DA spec — they predate it strategically and keep their own crypto.

App

What it is

Status

warm.contact

Zero-knowledge, inbound-first contact collection with its own wc1 sealed-box crypto (P-256 ECDH). The relay only ever brokers ciphertext — it never sees who is contacting whom.

v0.1 shipped; v0.6/v0.7 implemented; large backlog remains.

↳ Quill

warm.contact&apos;s per-user reconnect agent (formerly “Rekindle” / “Vocalist”) — drafts warm replies in the user&apos;s own voice, Mac→Anthropic direct, never auto-sends.

Drafting engine (Rekindle.swift) shipped; per-user Director identity is new design (see below).

outerjoin

Native macOS app that consolidates, de-duplicates, and two-way syncs Apple and Google contacts entirely on-device.

Substantially built, 85 tests green, pushed; fully independent of nostr.

Table 3 — The native contacts cluster: apps that integrate with Nave without being NIP-DA clients.

Quill, in detail

warm.contact is inbound-first: people reach out, their card lands in the address book, and the server only ever brokers ciphertext. The unsolved half has always been outbound — replying to the people who reached in is exactly where a human stalls, leaving a long list of “I should really get back to them” notes that never get written. Quill exists to write the first draft of each one, in the user&apos;s own voice, so all the human does is glance, tweak, and send.

The drafting engine itself is already built and tested (WarmCore/Rekindle.swift, Reconnect.swift, ReconnectPriority.swift — 59 tests green). It assembles a prompt from the specific person plus a shared ReconnectProfile (narrative, signature, home region), calls Claude directly from the Mac to api.anthropic.com, and returns a structured, channel-valid draft. Guardrails are pure and unit-tested: use only the facts provided, never invent shared history, acknowledge that the other person reached out first, one light call-to-action matched to intent, and correct length for the channel. Quill never auto-sends — the human edits, approves, and sends from their own iMessage or Mail, and the card is retagged from Warm to Warm-Contacted so the reply queue drains.

What is genuinely new is the identity and credential story wrapped around that engine. Under the Quill design, each user gets their own nostr identity (either minted by warm.contact at signup, or bring-your-own for the nostr-native minority) and becomes the Director of their own small estate. Quill itself gets a separate nostr identity, minted specifically for that user — not a shared agent key. Authority flows as a grant the user signs, not a server access-control flag, so revoking a Quill kills every credential it held in one act. Credentials are delivered grant-to-app (Quill decrypts its own NIP-44 grant and calls providers directly) rather than brokered, because the drafting prompt contains real contact plaintext and routing it through shared Nave infrastructure would break warm.contact&apos;s zero-knowledge invariant. This is explicitly the same pattern Luke embodies for James, generalized to every warm.contact user — “it&apos;s Luke, for everyone.” The open build queue includes confirming a per-user hierarchical re-grant capability on the Nave side, adding client-side NIP-44/NIP-98 crypto to the Swift agent, per-user identity bootstrap at signup, and adding a Calendly link to the profile bundle so a coffee/meetup draft can close with a real booking link.

2c · Luke — the flagship agent

Luke is James&apos;s own agent and the proof of concept the rest of the ecosystem builds toward. It is built out with a brain (voice corpus, proposer, cron scheduling), a poster with Telegram approval cards, webhook self-registration, a console with heartbeat, a calendar beat at 7:20am ET, an OpenClaw engine (heartbeat, nightly “dreaming” memory consolidation, hygiene), and draft-only email via himalaya IMAP. A private luke-brain repository holds memory snapshots. Luke is, in the ecosystem&apos;s own words, the pattern Quill generalizes: a per-person brain that drafts in the owner&apos;s voice from credentials that were explicitly granted to it.

The Runtimes

Two runtimes carry out the spine&apos;s two directions, plus a credential model that decides how each one is allowed to hold secrets.

Nactor — the act-side runtime

Nactor is the on-box runtime for acting: V1 is built, running over HTTP with NIP-98 authentication. It holds the proposal queue and role keys, and the same nact library that is Nact runs as Nactor with a pluggable actuator — publish, for Nact&apos;s social actions, or exec, for Nops&apos;s server operations. Today it carries four live identities (luke, brain, nave, nactjaf) and seven credentials.

NCP — the perceive-side runtime

NCP (Nostr Context Protocol) is the “missing quadrant” — still a concept overall, but with a genuinely built v0 egress organ already running: a transparent proxy at /api/proxy/&lt;provider&gt; that injects the real credential from RAM so the calling engine reaches a provider like Anthropic without ever holding the key itself. Open work: a per-identity gate, a data-grant read path, and an optional MCP-resource front.

The credential model — AD-6

Architecture decision AD-6 settles how credentials are held: authority is always a Director-signed grant carried by the identity itself, never a box-level access-control list. There are two consumption modes per credential×consumer pair — broker (the credential lives in RAM, on-box) and grant-to-app (the identity holds its own key, used off-box or for content-sensitive work). The rule is hybrid by sensitivity: if the request content is sensitive to Nave, or the consumer is off-box, use grant-to-app; if neither is true, broker it. Today the broker path is live and carrying real traffic (five providers), while grant delivery itself is built but not yet used in production — the missing piece is a Nactor credential-scope reader, tracked as migration milestone M2.

The identity roster

Every agent and runtime in the fleet is a distinct nostr identity, chaining up to a single root Director. The roster below is grounded in the ecosystem&apos;s identity registry — names and roles only, deliberately without npubs or key material, since a readable roster of who&apos;s who is more useful here than a wall of hex.

Identity

Role

Secret custody

sovereign (jaf@dequalsf.com)

Root Director — the whole identity chain signs up to him.

Bunker (encrypted)

nave

The hub / top fleet identity; the root the box boots under.

SOPS

nactor

The runtime / credential broker identity.

SOPS

luke

The employee agent.

SOPS

brain

Luke&apos;s proposer identity.

SOPS

nact_jaf

Approvals owner (the Nact approval channel).

SOPS

noir

Legacy hub identity; superseded only as a website, not as a game.

SOPS

operator

Relay operator / bunker signer.

Bunker (encrypted)

Table 5 — The identity roster: names and roles only. No nsec, npub, or key material appears in this report.

Infrastructure &amp; Operations — Nfra + Nops

Nfra is the sovereign substrate — the boxes, keys, relay, and bunker. Nops is the discipline of operating it, and it exists today in two forms: the interim control plane actually running (SSH + GitHub Actions), and “Nops proper,” a north-star concept where the box itself is operated over nostr.

The three-box fleet

Box

Provider

Runtime

CI channel

main Nave

Hostinger, Ubuntu 24.04

Docker: nact, luke, nvoy, nactor, caddy, openclaw

full (fleet-ops)

relay / bunker

Hostinger, AlmaLinux 10

Docker: strfry relay + Bunker46

restricted (relay-ops)

warm.contact

DigitalOcean, Ubuntu, 1 GB

native Caddy + Node on :8484

full (fleet-ops)

Table 4 — The live three-box fleet. IP addresses and secrets are deliberately kept out of this and all source documents.

The fleet runs on one management standard: a single nave_mgmt SSH key opens all three boxes, password authentication is off everywhere, and stray keys have been pruned. The sovereign nostr key itself lives only in the bunker (Bunker46, encrypted); every application borrows a signature over NIP-46 rather than the key ever leaving the box.

The firewalld incident and the hardening that followed

On 20 July 2026 a stale firewalld rule wedged the service into a failed state on the relay/bunker box; a reload flushed Docker&apos;s own iptables chains, taking down the bunker (502 errors) and eventually preventing the Docker daemon itself from starting (INVALID_ZONE: docker). The fix was decisive: disable firewalld permanently, flush the stale nftables ruleset, restart Docker, and rebuild the container networks. The standing lesson recorded from this incident is unambiguous — firewalld is never run on a Docker host again.

In its place, every box now runs a firewalld-free hardening baseline: an on-box nftables firewall (INPUT chain plus a DOCKER-USER seal) that needs no cooperation from a hosting provider&apos;s control panel, fail2ban, automatic updates, and confirmed reboot survival. This has been verified externally — sites return correct responses from outside the fleet, and previously exposed ports have been sealed. A companion set of smaller incidents from the same period — SELinux mislabeling a fresh authorized_keys file, fail2ban briefly banning the operator&apos;s own IP, a cloud-init drop-in silently re-enabling password authentication — are documented as lessons learned rather than left to recur.

Unified CI operations

Day-to-day fleet operations run through GitHub Actions workflows in the nave.pub repository: fleet-ops for full-access commands on the main and warm.contact boxes, and a deliberately restricted relay-ops channel for the sovereign relay/bunker box, whose CI key is forced-command-locked to a fixed allowlist (status, process list, inventory, restart, logs) and explicitly cannot read the box&apos;s own encrypted environment file. Supporting workflows handle read-only external probing, post-deploy verification, and smoke testing. Both bunker.nave.pub and relay.nave.pub are live.

The north star: Nops proper

The SSH-and-CI control plane running today is explicitly named, in its own documentation, as “the proto over the wrong transport.” The intended end state — Nops proper — operates each box with a nostr key instead: every operation becomes a signed, scoped, human-approved, revocable action; the ops-runner holds its own identity and receives its allowed verbs as a scoped data grant; execution happens on a signed approval rather than an SSH session or a CI secret. Today&apos;s restricted relay-ops allowlist is the closest thing that exists to this today — swap its SSH transport for a scoped grant and signed approval, and it becomes Nops.

What&apos;s Next

The backlog below is drawn directly from the ecosystem&apos;s own inventory and the live fleet runbook — grounded work, not aspiration.

Credential migration (nact) — the live frontier

A seven-milestone migration (M1–M7) is moving credentials from environment-file copies to Director-signed scoped grants. M1 (re-inventory) is done. The single missing piece blocking everything downstream is M2 — the Nactor credential-scope reader: the broker consumption path is live, but grant-delivery is built and simply not yet wired up. After that: M3 pilots the migration on the telegram-luke credential, M4 migrates the rest (Google Workspace, Anthropic, approvals), M5 is the mail connector (GitHub issue #36) — a verb-scoped, read-only IMAP adapter that is also what unblocks warm.contact&apos;s own Gmail integration — M6 routes engine egress through the /api/proxy path, and M7 adds an Nvoy MCP transport.

Nact hardening

A five-phase threat-model hardening pass is queued: freezing an event&apos;s created_at at proposal time and re-verifying its event-id fingerprint before signing, a faithful render of exactly what will be signed (kind, tags, hidden-character flags), risk tiers so critical action kinds can&apos;t be approved with a single careless tap, channel binding delivered as a scoped grant via a nonce ceremony, and a dedicated Mini-App signer at nact.nave.pub/sign.

Common sign-in — nave-connect

The nave-connect module (GitHub issue #56) is built and tested, with the bunker sign-in path already proven end-to-end. What remains is wiring it into every app&apos;s login screen and a unified title bar. Nvoy will keep its own local-key onboarding as the front door for newcomers; Nact stays signer-only.

Quill and warm.contact

Nave-side integration for warm.contact is decided in principle — grant-to-app via an Nvoy MCP transport, with a central identity minted for the product. What remains open: a live Director grant flowing to warm.contact&apos;s own npub, a real Swift MCP transport, and per-instance topology decisions. Quill&apos;s own evolution needs a per-user human nostr identity (mint-or-bring-your-own), the user standing as their own Director, and adding Calendly to the profile bundle. Separately, warm.contact carries its own product backlog: Google People sync behind a brand-verification gate, a living-contacts profile-key pull, multi-device per-device tokens, CAPTCHA, custom domains, billing, a launch loop, and a daily-brief agent — none of it built yet.

Nave hub and documentation

ECOSYSTEM-HUB content: the Identity = Freedom thesis, the protocol case, a James page, iconography, and launch.

The remaining architecture-decision implementation queue (AD-1 audit follow-through, AD-5 routing).

The keyless-boot daemon — still a north-star direction, not queued for near-term build.

Two lower-priority, parked items: a second console-authoring pass for Luke, and delegating James&apos;s own approval authority to Nact_jaf.

Appendix: The Journey &amp; Lessons Learned

The thesis behind all of it: “Identity = Freedom.” One nostr primitive — the scoped, revocable data grant — turned out to be enough to rebuild contacts, file sharing, secure intake, legacy planning, games, and agent delegation, each as a pure client of the same protocol, each answering to the owner&apos;s keys and no one else&apos;s.

A condensed timeline

Movement 0 — the seed. Before any repository existed, warm.contact (originally MakeContact) set the strategic frame: contact data as a self-maintained record plus a grant, with the address book itself an emergent view. “Nobody maintains contact data about anyone else” is the inversion that became the protocol.

Movement 1 — protocol &amp; apps sprint (Jul 9–11, ~119 commits). NIP-DA was drafted on 9 July with two independent implementations (JS and Go) interoperating live on public relays the same day — the founding commit of the whole ecosystem. Nvelope, Notegate, and Nvoy each reached their first milestone on 10 July; Nherit and Noir followed on 11 July. The PR to nostr-protocol/nips (#2411) opened, and James posted the announcement live on the protocol, signed with his real key.

Movement 2 — the Nave unification (Jul 13–14, ~143 commits). nave.pub was born as the hub site with a shared design language, and three essays were written the same day. 14 July was the single biggest day (80 commits): Ntrigue shipped, and six repositories received an identical closing commit bringing the shared design system, seal, and Alby sign-in — the moment the portfolio became one branded family.

Movement 3 — the agent &amp; ops era (Jul 16–18, ~124 commits). Activity narrowed to luke, nact, and nave.pub — the shift from building products to operating a living system. Luke was rebuilt as a nostr-delegated agent with a nostr-gated cockpit and a live posting loop; Nact/Nactor formalized the credential-broker runtime; the cockpit was cut over to self-hosted infrastructure and upgraded to a pinned upstream release. A 74-commit “night of drift” on 17 July surfaced, on candid review, that the credential-grant migration&apos;s delivery half had stalled while its consumption half raced ahead — directly motivating the M-series migration plan above.

Key incidents and lessons

firewalld melted Docker. A stale firewall rule wedged firewalld into a failed state; a reload flushed Docker&apos;s own iptables chains, taking the bunker down and then preventing Docker itself from starting. Lesson, now standing policy: never run firewalld on a Docker host.

The “document.txt” bunker scare. A broken proxy hop made bunker.nave.pub hand a phone a text-file download instead of the app. Investigation showed this was a flapping Caddy error body misread by the browser, not a leaked key — resolved by the same firewalld purge.

A false “sealed” reading. An early port probe reported a port as firewalled when the container was simply down — a reminder that “container down” and “firewalled” read identically from outside and must be checked separately.

SSH self-inflicted wounds. An SELinux mislabel on a freshly written authorized_keys file, fail2ban briefly banning the operator&apos;s own IP before the retry threshold was loosened, and a cloud-init drop-in silently re-enabling password authentication after a lockdown — all now checked for explicitly during box hardening.

A leaked bunker connection string. A bunker:// URL was accidentally pasted mid-debugging session; it was immediately treated as burned and the connection was re-minted from the console rather than assumed safe.

Luke&apos;s approvals silently stopped posting. Root cause was a chain of three separate issues — a missing file in a Docker COPY step causing a crash-loop, a token limit truncating JSON output, and a webhook that was never re-registered after a bot-token change. Each is now guarded against explicitly (explicit COPY of the missing file, a higher token limit with tolerant parsing, and boot-time webhook registration with retry).

Secrets filed against the wrong repository. warm.contact&apos;s SSH secrets were briefly stored in the warm.contact repository while the workflow that needed them lived in nave.pub — GitHub Actions secrets are per-repository, so the workflow silently read empty values until this was caught and corrected.

Where it all stands, in one breath: a draft NIP with two live implementations and an open pull request; seven applications — two of them games — shipped as pure clients of it; a branded platform and design system unifying them; a self-hosted, upgradable, dreaming agent running a live posting loop and daily briefs under a nostr-signed gate; a credential runtime holding secrets in RAM and handing them out by signature; and a three-box fleet that has already weathered a real infrastructure incident and come out hardened — all in about ten days, all in the open, all answering to one set of keys.
