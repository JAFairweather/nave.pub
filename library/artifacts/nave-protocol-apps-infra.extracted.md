# Nave — Protocol, Apps & Infra (extracted text)

*Auto-extracted from the .pptx, slide by slide. The deck remains the artifact.*


## Slide 1

- NAVE
- One protocol for scoped autonomy
- PROTOCOL · APPS · INFRASTRUCTURE
- James Fairweather
- 2026-07-20

## Slide 2

- Identity = Freedom
- THE THESIS
- “The signature is the authorization; the rotation is the revocation.”
- One nostr primitive — the scoped, revocable data grant — turns out to be enough to rebuild contacts, files, secure intake, legacy, games, and agent delegation, each as a pure client of the same protocol, each where your data answers to your keys and no one else’s.
- SEE
- Scoped data grants bound what an agent may perceive — the perceive side of the protocol.
- DO
- Scoped action approvals bound what an agent may act on — the act side of the protocol.
- NAVE
- 01
- The thesis

## Slide 3

- Built in the open, ten days and counting
- HOW WE GOT HERE
- 10
- days
- first commit 2026-07-09
- 445
- commits
- across the estate
- 11
- repositories
- as of 2026-07-18
- 0 · The seed
- warm.contact — the self-maintained record + the grant; the address book as an emergent view.
- 1 · Protocol &amp; apps sprint
- Jul 9–11, ~119 commits. NIP-DA drafted with JS + Go interop; four apps reach M1; PR #2411 opens.
- 2 · The Nave unification
- Jul 13–14, ~143 commits. nave.pub born; shared design system, seal, and Alby sign-in across six repos.
- 3 · The agent &amp; ops era
- Jul 16–18, ~124 commits. Luke rebuilt; Nact/Nactor formalize the credential broker; “a publishing project.”
- “This is no longer a build project; it is a publishing project.” — nave.pub hub doc
- NAVE
- 02
- How we got here

## Slide 4

- One protocol, two directions
- THE SPINE
- PERCEIVE · data-in
- ACT · actions-out
- protocol
- Scoped Data Grants (NIP-DA) — real draft NIP, built, JS↔Go interop
- Scoped Action Approvals — sketch, not yet a NIP
- runtime
- NCP — concept; v0 egress organ built
- Nactor — built, V1 HTTP + NIP-98
- instances
- Nvoy, Nvelope, Nontact, Notegate
- Nact (social), Nops (server ops)
- mechanism
- grant (kind 30440 / 440 / 441 / 10440)
- approval (propose → approve → sign → enact; NIP-59/46 today)
- Nvoy is the connective tissue both ways —
- it feeds ordinary agents their data and feeds Nactor its own config as a scoped grant.
- NAVE
- 03
- The spine

## Slide 5

- Scoped Data Grants — NIP-DA
- THE PROTOCOL, PART I
- SPEC · PR OPEN
- nostr-scoped-data-grants — PR nostr-protocol/nips #2411
- 30440
- Scoped Data Set
- NIP-44 encrypted under a random 32-byte scope key
- 440
- Data Grant
- gift-wrapped delivery of a scope key to a recipient
- 441
- Revocation
- publishes the cut; revocation is key rotation, not token expiry
- 10440
- Grant Index
- recoverable from your nsec alone
- Four kinds cover the full lifecycle: publish, grant, revoke, and recover the index from your key alone.
- Two independent reference implementations — JS (nipxx.mjs, ~200 LoC) and a Go CLI — interop verified live on public relays.
- Zero relay changes required; live-update by republish.
- NAVE
- 04
- The protocol, part I

## Slide 6

- Scoped Action Approvals
- THE PROTOCOL, PART II
- SKETCH
- The act-side peer to NIP-DA — deliberately not yet a NIP.
- 1
- Propose
- →
- 2
- Approve
- →
- 3
- Sign
- →
- 4
- Enact
- The one standardizable primitive:
- [&quot;approval&quot;, id, approver]
- — a public, verifiable proof that an agent action passed a human tap.
- Built-first: exploratory sketch only, deliberately not yet a NIP — a PR opens when cross-client demand appears.
- Today&apos;s transport is NIP-59/46; Nactor is the built V1 runtime (HTTP + NIP-98) that carries it.
- NAVE
- 05
- The protocol, part II

## Slide 7

- The apps — the NIP-DA family
- APPS BUILT ON THE SPEC
- App
- What it is
- Status
- Nvoy
- Scoped, revocable data delegation to AI agents; mounts as an MCP server (7 tools)
- ALPHA · v0.1 working client + console “Ledger”
- Nvelope
- Secure document sharing — live folders, real revocation, one-key recovery
- ALPHA · v1 feature-complete
- Nherit
- Family estate / legacy break-glass vault — dead-man’s-switch escrow + SLIP-39 paper Shamir
- ALPHA · ~150 tests
- Nontact
- The no-maintenance address book — self-maintained records, scoped access
- LIVE · alpha prototype
- Notegate
- Serverless secure tip line for journalism — PoW toll, gift-wrap, timing jitter
- ALPHA · v1 feature-complete
- Ntrigue
- Phones-only party game of secrets &amp; blackmail — revoke a secret, can’t un-tell it
- LIVE · v0.1 (MIT)
- Noir
- Nostr spycraft game — grants are earned intel; a key rotation is a felt “burn notice”
- ACTIVE · M1 of 6
- NAVE
- 06
- Apps built on the spec

## Slide 8

- Nvoy — the connective tissue
- SPOTLIGHT
- ALPHA
- Scoped, revocable data delegation to AI agents — mounted as an MCP server so any agent can consume it.
- 7
- MCP tools exposed
- v0.1
- working client + console “Ledger”
- 90s
- revoke-mid-conversation demo
- The double duty:
- Nvoy feeds ordinary agents their data as scoped grants — and feeds Nactor its own config the same way. It is the one instance that sits on both sides of the spine (perceive and act).
- Not yet npm-published — the underlying protocol is still a draft.
- NAVE
- 07
- Spotlight · Nvoy

## Slide 9

- Noir — the flagship demo
- SPOTLIGHT
- ACTIVE · M1/6
- “A spycraft mystery game where information is the board.”
- Clues
- modeled as NIP-DA scopes — what you can see is what you’ve earned
- Mistakes
- burn assets by key rotation — a felt “burn notice,” not an abstract token expiry
- The Director
- is itself an nvoy agent — the AI game master runs on the same protocol as the game
- Proving ground
- for the entire protocol stack — the subject of its own architecture essay
- NAVE
- 08
- Spotlight · Noir

## Slide 10

- The native cluster
- APPS THAT INTEGRATE WITH NAVE
- Apps that integrate with Nave, rather than being built on the spec itself.
- App
- What it is
- Status
- warm.contact
- Zero-knowledge, inbound-first contact collection; own wc1 sealed-box crypto (P-256 ECDH). The relay only ever brokers ciphertext.
- v0.1 shipped · v0.6/v0.7 implemented
- Quill
- The per-user reconnect agent (was “Rekindle”) — drafts warm replies in your voice, Mac→Anthropic direct, no auto-send.
- Engine shipped · per-user identity new
- outerjoin
- Native macOS app: consolidate, de-dup, and two-way-sync Apple↔Google contacts, on-device.
- Substantially built · 85 tests green
- Correction on record: “noir superseded by nave.pub” was wrong — noir (the game) is active; only the website platform flipped to nave.pub.
- NAVE
- 09
- The native cluster

## Slide 11

- Quill — the reconnect agent
- SPOTLIGHT
- ENGINE LIVE
- A per-user agent — its own nostr identity, minted for that user — that drafts warm, personal reconnection replies in the user’s voice, and never sends anything on its own.
- USER (human)
- The Director — nostr identity, mint-or-BYO, the root of the estate
- grant →
- ← approve (send is a human tap)
- QUILL (the agent)
- Own nsec/npub, minted per user — holds profile + scoped credentials, drafts, never sends
- Engine ships as-is: Rekindle.swift + Reconnect.swift, 59 tests green; Mac → Anthropic direct, claude-sonnet-5, relay never sees plaintext.
- Credential posture: grant-to-app, uniform — never brokers contact plaintext through shared Nave infra.
- Profile bundle: narrative, signature, home region, Anthropic key, Gmail app-password, and Calendly (the one genuinely new field).
- “It’s Luke, for everyone.”
- NAVE
- 10
- Spotlight · Quill

## Slide 12

- Luke — the flagship agent
- THE AGENT
- LIVE
- A nostr-delegated agent at luke.nave.pub, plus the nostr-signed gate to a private OpenClaw cockpit.
- Brain —
- voice corpus, proposer, cron
- Poster —
- signer for the propose→approve→sign→broadcast loop
- Approval cards —
- Telegram, webhook self-registration
- Console + heartbeat —
- live status and control
- Calendar beat —
- 7:20am ET daily rhythm
- OpenClaw engine —
- heartbeat, nightly dreaming, hygiene
- Email —
- draft-only, via himalaya IMAP
- Memory —
- private luke-brain repo holds snapshots
- Luke is the pattern Quill generalizes: a per-person brain that drafts in your voice from granted credentials.
- NAVE
- 11
- The agent

## Slide 13

- Nactor &amp; NCP — the two runtimes
- THE RUNTIMES
- Nactor
- BUILT · V1
- the act-side runtime
- HTTP + NIP-98; holds the proposal queue and role keys.
- The same nact library that is Nact runs as Nactor with a pluggable actuator — publish for Nact, exec for Nops.
- 4 identities live (luke / brain / nave / nactjaf), 7 credentials.
- NCP
- CONCEPT · v0
- the perceive-side runtime — “the missing quadrant”
- Built v0 egress organ: transparent proxy /api/proxy/&lt;provider&gt; injects the real credential from RAM.
- The engine calls Anthropic; it never holds the key.
- Open: per-identity gate, data-grant read path, optional MCP-resource front.
- NAVE
- 12
- The runtimes

## Slide 14

- Credential model — hybrid by sensitivity
- AD-6
- Authority is a Director-signed grant carried by the identity — never a box ACL.
- Broker
- On-box, RAM custody. Tight custody, non-sensitive content. Live today across 5 providers (anthropic, telegram ×2, gcal, gmail).
- Luke, Brain — on-box Nave agents
- Grant-to-app
- The identity holds its own key, off-box or content-sensitive. Built, but delivery is not yet consumed anywhere live.
- warm.contact, Quill — off-box / zero-knowledge consumers
- The decision rule (two tests):
- is the request content sensitive to Nave? Is the consumer off-box? Either yes → grant-to-app; both no → broker.
- THE GAP
- Nactor credential-scope reader (M2)
- NAVE
- 13
- AD-6 · credential model

## Slide 15

- Nfra — the sovereign substrate
- INFRASTRUCTURE
- Box
- Provider
- Runtime
- CI channel
- main Nave
- Hostinger · Ubuntu 24.04
- Docker: nact / luke / nvoy / nactor / caddy / openclaw
- full (fleet-ops)
- relay / bunker
- Hostinger · AlmaLinux 10
- Docker: strfry + Bunker46
- restricted (relay-ops)
- warm.contact
- DigitalOcean · Ubuntu, 1 GB
- native Caddy + Node :8484
- full (fleet-ops)
- One key opens all three:
- nave_mgmt — SSH key-only, stray keys pruned, each box proven before locking.
- New box = newbox.sh → on-box firewall → prove key login → rekey.sh --lock
- Sovereign key lives in the bunker, encrypted (Bunker46); apps borrow signatures over NIP-46 — the key never leaves the box
- NAVE
- 14
- Infrastructure · the fleet

## Slide 16

- Docker-safe hardening
- INFRASTRUCTURE · THE INCIDENT
- THE INCIDENT — 2026-07-20
- firewalld flushed Docker’s iptables chains on the relay/bunker box — Docker networking broke, then the Docker daemon itself wouldn’t boot. Root fix: never run firewalld on a Docker host.
- firewalld purged, not reconfigured — banned on every Docker host going forward
- nftables INPUT + DOCKER-USER seal — an on-box firewall with no provider-panel dependency
- fail2ban, auto-updates, and reboot survival — verified externally on main + warm.contact
- Standing rule: “firewalld is banned on Docker hosts.”
- NAVE
- 15
- Infrastructure · the incident

## Slide 17

- From SSH + CI to Nops
- INFRASTRUCTURE · OPS
- Today — unified CI ops
- INTERIM
- fleet-ops — full channel for main + warmcontact
- relay-ops — RESTRICTED channel for the bunker box: forced-command allowlist, cannot read the sovereign .env
- probe, verify, deploy — rounding out the toolkit
- Bunker and relay both live
- Nops proper — the north star
- CONCEPT
- Operate the box with your nostr key — no SSH, no CI secret
- Ops-runner holds its own identity
- Receives its allowed verbs as a scoped grant
- Executes on signed, human approval — exec on a nostr-gated tap
- “We already built the proto over the wrong transport” — today&apos;s SSH + CI channels are Nops, running before nostr carried it.
- NAVE
- 16
- Infrastructure · ops

## Slide 18

- Closing the dangling threads — the ADRs
- DESIGN DISCIPLINE
- AD-2
- SHIPPED
- Address the runtime by identity
- The runtime publishes its own relay list (kind 10002) and handler advert (kind 31990). Canonical handle: nactor@nave.pub — clients discover transport from who it is, not a URL.
- AD-4
- DEFERRED BY CHOICE
- Keyless boot is the north star
- The box holds no long-term secret on disk, unsealed by the Director over nostr at boot. Interim: SOPS-sealed keys, age key kept off-box.
- AD-6
- DECIDED
- Credential consumption is hybrid
- Broker vs grant-to-app, decided by sensitivity and box locality — already the de-facto rule in production.
- AD-7
- SHIPPED
- Two channel kinds
- approval (shared, gates proposals) vs comms (per-agent, normal messaging) — forced by a hard Telegram constraint: one bot token, one update consumer.
- NAVE
- 17
- Design discipline · ADRs

## Slide 19

- Where we are
- STATUS SNAPSHOT
- SHIPPED
- NIP-DA spec complete, PR #2411 open
- 7 NIP-DA apps at live/alpha
- Nact / Nactor — core-live runtime
- Luke — live posting loop + briefs
- Fleet hardened, rekeyed to one key
- AD-1, AD-2, AD-5, AD-7 shipped
- IN-FLIGHT
- Noir M3 — AI Director in progress
- Credential migration M2 — the one missing piece
- Quill — per-user identity design
- warm.contact — large product backlog
- nave-connect module built, not yet wired in
- INTENDED
- Scoped Action Approvals as a NIP
- Nops proper — nostr-native ops
- Keyless boot
- Nmail — verb-scoped IMAP adapter
- Request-is-a-grant-and-enact
- NAVE
- 18
- Status snapshot

## Slide 20

- What&apos;s next — the backlog
- ROADMAP
- Credential migration (M2–M7)
- The live frontier. Nactor credential-scope reader is “the one missing piece” (2b broker is live, grant delivery is built-but-unused); the mail connector (#36/M5) is next up.
- Nact hardening
- Freeze created_at at propose and re-verify the fingerprint before signing; faithful render; risk tiers for critical kinds; channel binding as a scoped grant; a Mini-App signer.
- nave-connect (#56)
- Module built and tested, bunker path proven — wire it into every app&apos;s login UI and a unified title bar.
- Nvoy
- Grant migration, credential ciphertext to owning identity, a fleet console, re-delegation terms, and eventually macaroon-style sub-delegation.
- warm.contact + Quill
- Live Director grant to a warm.contact npub, a real Swift MCP transport, per-instance topology, and the Quill lifecycle build queue.
- Publishing
- “Protocol as Fuel” is live on the Substack; two more essays are written and ready to cross-post to nostr.
- NAVE
- 19
- Roadmap

## Slide 21

- THE FRONTIER
- A request that is a grant AND an enact.
- Perceive and act collapse into one signed exchange; providers become first-class over NIP-05; revocation chains across providers.
- “The signature is the authorization; the rotation is the revocation.”
- nave.pub
- NAVE
- 20
- The frontier
