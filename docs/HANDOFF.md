# The session handoff — paste this to orient a fresh agent

*The canonical, versioned copy of the onboarding prompt. A prior generation of
this prompt lived only in chat; this one is a committed doc, updated 2026-07-23
after the voice-and-sovereign-hand sessions. Update it whenever the
conventions or the map move — it and the docs it points to ARE the handoff.*

---

You're picking up the Nave project. Before doing anything else, read these
committed docs in nave.pub to get fully oriented — they ARE the handoff (prior
sessions wrote them for exactly this):

- **docs/INVENTORY.md** — the master map: the spine (perceive vs act), the
  protocol (NIP-DA, P-series hardened), both app families (Ngage included),
  the runtimes, Nfra+Nops, and the live backlog + reconciled frontier (§5).
- **deploy/ops/PLAN.md** — the live fleet status board.
- **docs/JOURNEY.md** — the full history and thesis, four movements.
- **docs/quill.md** — the per-user reconnect agent — and, since 07-23, the
  Director's own drafting hand (§9).
- **docs/NOPS.md** — fleet ops (including channel-reliability learnings);
  **docs/IDENTITY-REGISTRY.md** — the identity roster (names/roles/npubs; NO
  nsecs).
- **docs/SIDE-QUESTS.md** — incidents & lessons (read this before touching git
  history, Dockerfiles, or caches); **docs/nave-architecture-decisions.md** —
  AD-1…11. AD-9 (evidence-only per-identity voice), AD-10 (approval happens
  where the signing key lives), and AD-11 (one sign-in, promote-don't-level)
  are the newest doctrine.
- **library/** — the public writing: essays, artifacts, and the revoicing
  programme (`library/ROADMAP.md`).

Then give me a 5-line status: what's shipped, what's in-flight, and the top 3
next actions.

## Who I am

James Fairweather (GitHub `JAFairweather`; nostr `jaf@dequalsf.com` — the
sovereign Director). Building the self-hosted "Nave" ecosystem.

## Thesis

Scoped autonomy — an agent bounded on what it may SEE (Scoped Data Grants /
NIP-DA) and what it may DO (Scoped Action Approvals), my nostr signature the
only root of authority. *"The signature is the authorization; the rotation is
the revocation."* Two corollaries now carry equal weight:

- **Approval happens where the signing key lives** (AD-10). Box-custodied keys
  → Nactor → Telegram. Drafts for ME → Ngage, gift-wrapped to my npub, signed
  in my own hand.
- **Voice is evidence, per identity** (AD-9). One steering file per identity,
  one drafting pass per identity, sources are real writing only — never
  inference, never AI-assisted output (that's a feedback loop).

## Hard constraints

- **Never print nsecs/secrets/keys/IPs** — npubs/names/roles only. Refer to
  boxes by role: **main · relay+bunker · warm.contact**. (IPs for SSH live in
  Bitwarden and local memory, not in chat or artifacts.)
- Any bunker:// connect string ever pasted into a chat is **BURNED** — re-mint
  from the console. Bitwarden is the vault.
- **firewalld is BANNED** on Docker hosts; port control = on-box `firewall.sh`.
- Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>` — plain.
  **No model identifiers** in commits/PRs/artifacts, trailer included.
- Identity env/npub files never enter an app repo — the ignore rules are
  pattern-based (`*.nave.env*`, `*.npub.txt`); sealed envs live with deploy
  secrets.
- `luke/brief/` ships in a **public image** — nothing private goes in it.
  Luke's OpenClaw persona files (SOUL.md etc.) are box-only; only the public
  posting register may be derived from them.
- Public posts never link the gated hosts (Cockpit, Console).

## Conventions

- **Issues-first (restored 2026-07-23).** New work = a discrete GitHub Issue
  per repo, drafted for approval before code; **every commit is bookended by
  the issue(s) it addresses** (open before; reference/close in the commit or
  PR). Check for an existing issue before filing — the fleet queue is real and
  current; duplicates are worse than none.
- Review flows through PRs with my explicit merge; doc-only changes may commit
  to main with an issue reference.
- **Verify the tree, not the PR badge** — and never stack rebase-merges
  (SIDE-QUESTS: the P-series cascade).
- Fleet: **main Nave · relay+bunker · warm.contact**; CI = `fleet-ops` (full) +
  `relay-ops` (restricted allowlist). `ops.yml` custom input is `command`;
  runner SSH to main can time out while the box is healthy — retry, or use the
  direct mgmt path for reads.
- New agent = mint key → relay allowlist → SOPS → Bitwarden note → registry
  row. New box = `newbox.sh` → firewall → prove login → `rekey.sh --lock`.
- The drafting house rules ride every public post: a nave.pub link (+ the
  named app's own link), a card graphic, real hashtags — asked of the model,
  **enforced deterministically** in `post-format.mjs`.
