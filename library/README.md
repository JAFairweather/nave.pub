# Nave Library — essays & artifacts

The single home for the ecosystem's **public writing and artifacts** — the essays
(the "bigger thoughts"), the decks, the reference pieces. Per-repo `docs/` stays
technical; this is the narrative + artifact library, and the source of truth for
anything cross-posted to Substack.

## Layout

- **`articles/`** — essays and articles (Markdown). Source of truth; cross-post to Substack from here.
- **`artifacts/`** — decks and documents (`.pptx`, `.docx`, `.pdf`).

## Published

- **Protocol as Fuel** — <https://jafairweather.substack.com/p/protocol-as-fuel> · 2026-07-13

## Articles

_(the five most recent drafts — pending import, see **Importing** below)_

| Title | File | Source draft |
|---|---|---|
| Scoped Autonomy | `articles/scoped-autonomy.md` | `article1scopedautonomy.md` |
| The Firewall That Melted Docker | `articles/firewall-melted-docker.md` | `article2firewalldmelteddocker.md` |
| Quill — the Per-User Agent | `articles/quill-per-user-agent.md` | `article3quillperuseragent.md` |

> There are **earlier drafts too** (the Director recalls "a bunch before this").
> As they surface, add them here the same way and list them above.

## Artifacts

| Artifact | File | Source |
|---|---|---|
| Nave — State of the Ecosystem | `artifacts/nave-state-of-the-ecosystem.docx` | `NaveStateoftheEcosystem.docx` |
| Nave — Protocol, Apps & Infra | `artifacts/nave-protocol-apps-infra.pptx` | `NaveProtocolAppsInfra.pptx` |

## Related narrative (technical docs, cross-referenced not duplicated)

- [`../docs/JOURNEY.md`](../docs/JOURNEY.md) — the build narrative
- [`../docs/ECOSYSTEM-HUB.md`](../docs/ECOSYSTEM-HUB.md) — the hub & how the pieces fit
- [`../docs/SIDE-QUESTS.md`](../docs/SIDE-QUESTS.md) — incidents (incl. the firewall/Docker one)

## Importing

The recent drafts live on the Director's Desktop (`~/Desktop/Recents/`), which
automation can't read (macOS privacy protection). From a terminal **with Desktop
access**, copy them into place, then commit:

```bash
cd /Users/fairwja/Projects/nave-spine/nave.pub/library
cp ~/Desktop/Recents/article1scopedautonomy.md      articles/scoped-autonomy.md
cp ~/Desktop/Recents/article2firewalldmelteddocker.md articles/firewall-melted-docker.md
cp ~/Desktop/Recents/article3quillperuseragent.md   articles/quill-per-user-agent.md
cp ~/Desktop/Recents/NaveStateoftheEcosystem.docx   artifacts/nave-state-of-the-ecosystem.docx
cp ~/Desktop/Recents/NaveProtocolAppsInfra.pptx     artifacts/nave-protocol-apps-infra.pptx
```

Once they're in this folder, they're readable — hand it back and the titles/index
get finalized and committed.
