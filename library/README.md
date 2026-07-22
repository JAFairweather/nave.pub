# Nave Library — essays & artifacts

The single home for the ecosystem's **public writing and artifacts** — the essays
(the "bigger thoughts"), the decks, the reference pieces. Per-repo `docs/` stays
technical; this is the narrative + artifact library, and the source of truth for
anything cross-posted to Substack.

## Layout

- **`articles/`** — essays and articles (Markdown). Source of truth; cross-post to Substack from here.
- **`artifacts/`** — decks and documents (`.pptx`, `.docx`, `.pdf`).

## Articles

| Title | File | About | Status |
|---|---|---|---|
| **Protocol as Fuel** | [`articles/protocol-as-fuel.md`](articles/protocol-as-fuel.md) | How one small nostr primitive — the scoped, revocable data grant — fuels the whole ecosystem | **Published** — [Substack](https://jafairweather.substack.com/p/protocol-as-fuel) (2026-07-13) |
| **Scoped autonomy: one nostr primitive, a whole ecosystem** | [`articles/scoped-autonomy.md`](articles/scoped-autonomy.md) | How one signed, revocable grant became contacts, files, secure intake, a legacy vault, two games, and an agent runtime | Draft |
| **Quill: giving every person their own agent, not a shared one** | [`articles/quill-per-user-agent.md`](articles/quill-per-user-agent.md) | An agent minted for you, holding only what you gave it, that never presses send | Draft |
| **The day firewalld melted Docker** | [`articles/firewall-melted-docker.md`](articles/firewall-melted-docker.md) | A self-hosting war story: a stale rule, a wedged daemon, and the debugging arc | Draft |
| **Noir: An Architecture** | [`articles/noir-architecture.md`](articles/noir-architecture.md) | How a mystery game became the proving ground for an entire protocol | Draft |
| **Cryptographic Boundary Conditions for World Models** | [`articles/cryptographic-boundary-conditions.md`](articles/cryptographic-boundary-conditions.md) | Letting a language model build worlds without letting it cheat | Draft |
| **Hardening a protocol in public** | [`articles/hardening-a-protocol-in-public.md`](articles/hardening-a-protocol-in-public.md) | The P-series: six weaknesses as the itemized cost of one deliberate bet, and what hardening could and couldn't pay down | Draft |
| **The zero-knowledge address book** | [`articles/zero-knowledge-address-book.md`](articles/zero-knowledge-address-book.md) | warm.contact's shipped architecture: one envelope implemented twice, a relay that structurally cannot read, and the Swift grant plane | Draft |

## Artifacts

| Artifact | File |
|---|---|
| Nave — State of the Ecosystem | [`artifacts/nave-state-of-the-ecosystem.docx`](artifacts/nave-state-of-the-ecosystem.docx) |
| Nave — Protocol, Apps & Infra | [`artifacts/nave-protocol-apps-infra.pptx`](artifacts/nave-protocol-apps-infra.pptx) |

## Provenance & one open duplication

The last three articles above came from **`noir/docs/articles/`**, where they were
originally drafted. That directory *also* holds rendered `.html` copies and a
sibling `docs/figures/` — those were **left in place deliberately**, since removing
them could break anything already linking to the rendered pages. The Markdown here
is now the source of truth; the noir copies are renderings.

> **Open decision for the Director:** consolidate serving too (move/redirect the
> noir `.html` + figures), or leave noir serving its rendered copies. Until then,
> edit the Markdown *here* and re-render, so the two don't drift.

## Related narrative (technical docs, cross-referenced not duplicated)

- [`../docs/JOURNEY.md`](../docs/JOURNEY.md) — the build narrative
- [`../docs/ECOSYSTEM-HUB.md`](../docs/ECOSYSTEM-HUB.md) — the hub & how the pieces fit
- [`../docs/SIDE-QUESTS.md`](../docs/SIDE-QUESTS.md) — incidents (incl. the firewall/Docker one this library also covers as an essay)

## Adding to the library

Drop the Markdown in `articles/` (or the file in `artifacts/`), add a row above,
and note its status. If it gets published, link it in the Status column.
