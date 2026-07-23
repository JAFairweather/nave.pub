# Nave — Projects Registry

The **single standing list of every project in the Nave ecosystem**: what it is,
where its code lives, where it's served, and its status. This is the metadata of
record — when a project is added, renamed, or changes status, **update this table
in the same PR**. Deep narrative lives in [`INVENTORY.md`](INVENTORY.md); this is
the flat index.

**Status legend:** ✅ live · 🟡 alpha / live-with-gaps · 🟢 core-live (carrying
real traffic) · 📄 spec/draft · 💤 parked · 🧭 concept (named, on paper).

_Last reconciled 2026-07-23._

## The protocol

| Project | What it is | Repo | Served | Status |
|---|---|---|---|---|
| **NIP-DA / Nscope** — Scoped Data Grants | The root primitive: signed, revocable, scoped data grants on nostr (kinds 30440/440/441/10440). PR nostr-protocol/nips#2411. P-series hardened (2026-07-22). | `JAFairweather/nostr-scoped-data-grants` (local clone: `~/Projects/nip-demo`) | `nscope.nave.pub` | 📄 spec + JS & Go reference libs, interop-verified |

## The NIP-DA app family (pure clients of the spec)

| Project | What it is | Repo | Served | Status |
|---|---|---|---|---|
| **Nontact** | The no-maintenance address book — self-maintained records, scoped access | `JAFairweather/nontact` | `nontact.nave.pub` | 🟡 alpha |
| **Nvelope** | Secure document sharing — live folders, real revocation, one-key recovery | `JAFairweather/nvelope` | `nvelope.nave.pub` | 🟡 alpha (v1 feature-complete) |
| **Notegate** | Serverless secure tip line — PoW toll, gift-wrap, timing jitter | `JAFairweather/notegate` | `notegate.nave.pub` | 🟡 alpha (v1 feature-complete) |
| **Nvoy** | Scoped, revocable data delegation to AI agents; MCP server; **the Grant Ledger — the source of truth for all grants** | `JAFairweather/nvoy` (spine: `nave-spine/nvoy`) | `nvoy.nave.pub` | 🟡 alpha; console live |
| **Nherit** | Family legacy / break-glass vault — dead-man's-switch + SLIP-39 paper Shamir | `JAFairweather/nherit` | `nherit.nave.pub` | 🟡 alpha, ~150 tests |
| **Noir** | Nostr spycraft game — clues as grants, a key rotation is a felt "burn notice"; AI Director | `JAFairweather/noir` | `noir.nave.pub` (+ `director.nave.pub` API) | ✅ live (M1; M3 AI Director in progress) |
| **Ntrigue** | Phones-only party game of secrets & blackmail | `JAFairweather/ntrigue` | `ntrigue.nave.pub` | ✅ live v0.1 |

## Runtime, platform & agents

| Project | What it is | Repo | Served | Status |
|---|---|---|---|---|
| **Nact / Nactor** | The act-side: propose → approve → sign → broadcast. Nact is the app/library; Nactor is the on-box runtime + credential broker (NIP-98 gated) | `JAFairweather/nact` (spine: `nave-spine/nact`) | `nact.nave.pub` (`/api` → Nactor) | 🟢 core-live (V1) |
| **Ngage** | The Director's sovereign posting desk — the reversed arrow: an agent drafts, gift-wraps to his npub, he signs in his own hand | `JAFairweather/ngage` (local: `~/Projects/ngage`) | `ngage.nave.pub` | ✅ live (2026-07-22) |
| **Luke** | James's flagship delegated agent + the nostr-gated OpenClaw cockpit; the twice-daily posting loop | `JAFairweather/luke` (local: `~/Projects/luke`) | `luke.nave.pub`, `cockpit.nave.pub`, `console.nave.pub` (gated) | ✅ live |
| **luke-brain** | Private memory snapshots for Luke's OpenClaw workspace (age-encrypted) | `JAFairweather/luke-brain` (private) | — (box-only) | ✅ live |
| **Nave** (the hub) | The hub site + the whole ecosystem's **design system, ops pipeline, deploy config, and docs** (this repo) | `JAFairweather/nave.pub` (spine: `nave-spine/nave.pub`) | `nave.pub`, `www.nave.pub` | ✅ live |

## The native "contacts" cluster (integrate *with* Nave, not built *on* the spec)

| Project | What it is | Repo | Served | Status |
|---|---|---|---|---|
| **warm.contact** | Zero-knowledge, inbound-first contact collection; own `wc1` sealed-box crypto; relay only ever brokers ciphertext | `JAFairweather/warm.contact` (spine: `nave-spine/warm.contact`; also `~/Projects/WarmContact`) | `warm.contact` (own DO box) | 🟡 v0.1 shipped; big backlog |
| ↳ **Quill** | The per-user reconnect agent inside warm.contact — drafts warm replies in your voice, never sends. Also the Director's drafting hand (see `quill.md`) | (in `warm.contact`) | — (Mac / box device) | 🟡 engine shipped; per-user identity in progress |
| **outerjoin** | Native macOS app: consolidate/de-dup/two-way-sync Apple⇄Google contacts, on-device. Independent of nostr | `JAFairweather/outerjoin` (local: `~/Projects/OuterJoin`) | — (native app) | ✅ substantially built, 85 tests |

## Concepts (named, on paper)

| Project | What it is | Home |
|---|---|---|
| **NCP** (Nostr Context Protocol) | The perceive-side runtime; v0 runs as Nactor's egress proxy | `nact/docs/ncp.md` |
| **Scoped Agent Actions** | The act-side microstandard over NCP (draft) | `docs/scoped-agent-actions.md` |
| **Nops** | Nostr-native server ops — operate the box with your key, ops as scoped grants | `nact/docs/nops.md` |
| **Nmail** | Verb-scoped IMAP adapter in Nactor (read+draft-only enforced at the protocol) | `nact/docs/imap-adapter.md` |

## The fleet (infrastructure)

Three boxes — details (by role, no IPs) in [`NOPS.md`](NOPS.md):
**main Nave** (Hostinger/Ubuntu, Docker — nact/luke/nvoy/nactor/caddy/openclaw) ·
**relay + bunker** (Hostinger/Alma, Docker — strfry relay + Bunker46) ·
**warm.contact** (DigitalOcean/Ubuntu, native Caddy + Node).

## Not in scope here (the Director's personal / third-party repos)

Tracked so nobody mistakes them for Nave work: `jamesafairweather.com`,
`dequalsf.com` (personal sites) · `19teamt` (music/19-TET) · `MyGuru`,
`GenesisAI` (third-party) · `buzz` (Block's repo — the Director has an upstream
PR). These are **not** part of the Nave ecosystem and follow their own conventions.

## Adding a project

1. Mint its subdomain in `deploy/caddy/Caddyfile` (usually `import app <name>`) and
   `deploy/sites.sh`.
2. Add a row here (name, what it is, repo, served, status) **in the same PR**.
3. If it publishes to nostr, add its identity to
   [`IDENTITY-REGISTRY.md`](IDENTITY-REGISTRY.md) and the relay `allowlist.json`.
4. Narrative/architecture context goes in [`INVENTORY.md`](INVENTORY.md).
