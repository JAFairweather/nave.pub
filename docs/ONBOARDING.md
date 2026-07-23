# Onboarding — becoming a productive Nave developer

Everything you need to be read into the Nave ecosystem and start shipping. Read
this top-to-bottom once; it points you at the deep docs for each area. If you're
an agent picking up a session, start with [`HANDOFF.md`](HANDOFF.md) instead —
this doc is the human-scale tour.

_Maintained 2026-07-23. When something here goes stale, fix it in the same PR
as the change that made it stale._

---

## 1 · What Nave is (the one-paragraph thesis)

**Scoped autonomy.** An agent bounded on what it may **see** (Scoped Data Grants
/ NIP-DA) and what it may **do** (Scoped Action Approvals), with one person's
nostr signature as the only root of authority. The creed: *the signature is the
authorization; the rotation is the revocation.* Everything — contacts, files,
secure intake, a legacy vault, two games, an agent runtime, a posting desk — is
a pure client of that one primitive. Full history and thesis:
[`JOURNEY.md`](JOURNEY.md).

Two corollaries carry equal weight and you'll hit them constantly:
- **Approval happens where the signing key lives** (AD-10). Box-custodied keys →
  Nactor → Telegram. Drafts *for the Director* → Ngage, gift-wrapped to his npub,
  signed in his own hand.
- **Voice is evidence, per identity** (AD-9). One steering file per posting
  identity; sources are real writing only — never inference, never AI output.

## 2 · The map — spine, repos, and where code lives

- **The workspace** is `~/Projects/nave-spine/` — a container holding the four
  "spine" repos as sub-clones: **`nact`**, **`nave.pub`**, **`nvoy`**,
  **`warm.contact`**. Workspace instructions file: **`spineCLAUDE.md`** at the
  root (not `CLAUDE.md`).
- **Sibling repos** live beside it under `~/Projects/`: **`luke`**, **`ngage`**,
  the app repos (`nontact`, `nvelope`, `notegate`, `nherit`), `nip-demo`
  (→ `nostr-scoped-data-grants`), and the native ones (`OuterJoin`, a second
  `WarmContact` clone).
- **Every project, its repo, its subdomain, and its status** is the standing
  registry: **[`PROJECTS.md`](PROJECTS.md)**. Start there to see the whole
  estate at a glance. The deep, narrative version is
  **[`INVENTORY.md`](INVENTORY.md)** (§0 the spine, §1 protocol, §2 apps, §3
  runtimes, §4 infra, §5 the live backlog).

**Serving:** all `*.nave.pub` subdomains + `nave.pub` are served from the **main
box** via Caddy (`nave.pub/deploy/caddy/Caddyfile`); each app is a repo synced
into `deploy/sites/<name>` by `deploy/sites.sh`. `warm.contact` runs on its own
DigitalOcean box. `cockpit`/`console` are **gated** (Luke's OpenClaw) — never
link them from public posts.

## 3 · Architecture in five minutes

```
            PERCEIVE (data-in)              ACT (actions-out)
protocol    Scoped Data Grants (NIP-DA)     Scoped Action Approvals (sketch)
runtime     NCP (concept; v0 egress)        Nactor (built · V1 HTTP/NIP-98)
instances   Nvoy, Nvelope, Nontact,         Nact (social), Ngage (Director),
            Notegate                        Nops (server ops, concept)
mechanism   grant (30440/440/441/10440)     approve → sign → enact
```

- **Nvoy is the source of truth for all grants.** Every grant — data,
  credential, steering — belongs in the Director's kind-10440 Grant Index that
  Nvoy renders. Apps that issue grants (e.g. Ngage steering) write that index.
- **Nact/Nactor** is the act side. Nactor holds role keys + a credential broker
  in RAM; the app proposes, a human enacts by signing (WYSIWYS: the exact bytes
  shown are the bytes signed — re-verified before the signer is even called).
- **Credentials are grants** (AD-6): authority is a Director-signed grant carried
  by the *identity*, not a box ACL. On-box agents use the broker; off-box /
  content-sensitive consumers hold their own key (grant-to-app).
- The decisions that shaped all this are the **ADRs**:
  [`nave-architecture-decisions.md`](nave-architecture-decisions.md), AD-1…11.

## 4 · The identities (agents + keys)

Every key — who it is, its npub, where its secret is custodied — is the roster:
**[`IDENTITY-REGISTRY.md`](IDENTITY-REGISTRY.md)** (npubs/names only; **no nsecs**
ever in any repo). The shape you'll meet most:

- **sovereign** (`jaf@dequalsf.com`) — the root Director; everything chains to
  him. Key in the **bunker** (Bunker46, encrypted).
- **nave** — the hub / top fleet identity · **nactor** — the runtime · **luke**,
  **brain**, **nact_jaf** — the agent + its helpers · **noir**, **operator**.
- **Quill** / **James's Quill** — the Director's reconnect + drafting agent
  (per-user; see [`quill.md`](quill.md)). Its key is the Director's, never minted
  by a Nave script.

Posting identities each draft in their own **evidence-built voice** from
`luke/brief/<name>.md` (`nave.md`, `luke.md`, `jaf.md`) + the shared
`brief/shared.md`. `luke/brief/` ships in a **public image** — nothing private
in it.

## 5 · Where the secrets are (and are not)

- **Never in a repo.** npubs and hex pubkeys are public and safe; nsecs, tokens,
  and box IPs are not — they never go in code, commits, chat, or artifacts.
- **SOPS** — fleet agent nsecs, sealed in `deploy/secrets/nave.enc.env`
  (age-encrypted). The age key is on the Director's Mac (`~/.config/sops/age/
  keys.txt`).
- **Bunker** (Bunker46, `bunker.nave.pub`) — the sovereign + operator keys,
  encrypted with an `ENCRYPTION_KEY` backed up to Bitwarden.
- **Bitwarden** is the vault of record for everything (SOPS age key, bunker env,
  the `nave_mgmt` SSH key, per-box root passwords, CI keys).
- **Identity env/npub files** never enter an app repo — ignored by pattern
  (`*.nave.env*`, `*.npub.txt`); sealed envs live with the deploy secrets.
- A `bunker://…secret=…` string ever pasted into a chat is **BURNED** — re-mint.

## 6 · How we work (coding standards & conventions)

- **Issues-first.** New work = a GitHub issue per repo, drafted for approval
  before code; every commit is bookended by the issue(s) it addresses. Check for
  an existing ticket before filing.
- **Branch → PR → the Director's explicit merge.** Never push/merge a default
  branch without per-PR approval. Merge = merge-commit (preserving the structured
  commits), delete the branch.
- **Commit trailer:** `Co-Authored-By: Claude <noreply@anthropic.com>` — plain,
  **no model identifiers** anywhere. **PR-body footer:** `Drafted with assistance
  from [Claude Code](https://claude.com/claude-code)` (the `🤖 Generated with…`
  style is retired). Subject prefixes: `nactor:` / `nact:` / `docs:` / etc.;
  reference issues as `(#N)`.
- **Verify the tree, not the badge.** After a deploy, grep a **new-only** marker
  on the served file — not a string that also exists in the old version. Never
  stack rebase-merges (see the P-series cascade in
  [`SIDE-QUESTS.md`](SIDE-QUESTS.md)).
- **Tests are evidence.** Pure logic goes in a testable module with a test that
  pins the property that matters; browser apps are verified in the browser
  (load, drive, assert, check the console). A file must ship everywhere its
  importer ships — grep the Dockerfile **and** the workflow mounts on every new
  module.
- **Frontend cache discipline:** app HTML/modules are served `no-cache`; a
  changed module still needs a real reload — Ngage carries a stale-tab reload
  prompt, Nact versions its module URLs. Don't trust a soft refresh.
- **Voice sources are evidence only** (AD-9) — never inference, never the
  AI-assisted library essays.
- **Public posts** always carry a nave.pub link (+ the named app's link), a card
  graphic, hashtags, and the standing AI-assistance disclosure — all enforced
  deterministically in `luke/post-format.mjs`.

## 7 · Ops & deploys

- **One SSH key** (`nave_mgmt`, Mac Keychain) opens every box. **firewalld is
  BANNED** on Docker hosts — port control is the on-box `firewall.sh` (+ optional
  provider edge). The full runbook + the sequenced roadmap:
  **[`deploy/ops/PLAN.md`](../deploy/ops/PLAN.md)**; the ops toolkit:
  **[`NOPS.md`](NOPS.md)**.
- **Deploy the fleet:** the `Deploy the Nave` GitHub Action (or a push to
  `nave.pub` main). It SSHes to the main box, pulls every app via `sites.sh`,
  validates Caddy, and `compose up`. The relay box deploys separately (strfry
  rebuild). Runner→box SSH occasionally times out while the box is healthy —
  retry, and re-verify a red deploy before treating it as an outage.
- **Box commands:** `ops.yml` dispatch (`-f task=custom -f command='…'`) or the
  direct `nave_mgmt` SSH for reads.

## 8 · What's shipped, and what's next

- **Shipped:** the P-series-hardened NIP-DA + PR #2411; the app family; Nactor's
  credential-migration M-series (grants are every credential's only durable
  home); Ngage and the sovereign-hand flow; per-identity steering; one shared
  sign-in fleet-wide; the fleet hardened.
- **What's next**, sequenced with reasons: **[`deploy/ops/PLAN.md`](../deploy/ops/PLAN.md)**
  "The sequenced roadmap." The live per-repo ticket index is `INVENTORY.md` §5;
  the GitHub issues are the tickets.

## 9 · The doc set (your reference shelf)

| Doc | What it's for |
|---|---|
| [`PROJECTS.md`](PROJECTS.md) | the flat registry — every project, repo, subdomain, status |
| [`INVENTORY.md`](INVENTORY.md) | the deep handbook + live backlog (§5) |
| [`HANDOFF.md`](HANDOFF.md) | the session-start prompt (for agents) |
| [`JOURNEY.md`](JOURNEY.md) | history & thesis |
| [`nave-architecture-decisions.md`](nave-architecture-decisions.md) | AD-1…11, the "why it's built this way" |
| [`IDENTITY-REGISTRY.md`](IDENTITY-REGISTRY.md) | the key roster (no nsecs) |
| [`NOPS.md`](NOPS.md) · [`deploy/ops/PLAN.md`](../deploy/ops/PLAN.md) | fleet ops + the sequenced roadmap |
| [`SIDE-QUESTS.md`](SIDE-QUESTS.md) | incidents & hard-won lessons |
| [`quill.md`](quill.md) | the reconnect / Director-drafting agent |
| [`scoped-agent-actions.md`](scoped-agent-actions.md) | the act-side microstandard (draft) |
| [`../library/`](../library) | the public writing (essays, artifacts, the revoicing programme) |
