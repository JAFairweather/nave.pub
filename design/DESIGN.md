# The Nave design system

One visual language across the whole family — the hub, the games, and every
utility app read as siblings. This is the reference; the apps **vendor**
(inline) it, because they're no-build static clients with no shared runtime.

## Palette

Shared ink/gold surfaces (`design/tokens.css`), plus **one accent per app** —
its seal colour. Only `--accent` / `--accent-bright` / `--accent-ink` change
per app; everything else is constant.

| App | Accent | Seal |
|---|---|---|
| Noir | `#c39a56` gold | fedora |
| Nontact | `#8fae6a` green | overlapping circles |
| Nvelope | `#9a83c0` violet | envelope |
| Nherit | `#c0705a` terracotta | key |
| Ntrigue | `#c07a9a` rose | twin diamonds |
| Notegate | `#7f95ad` slate | lock |
| Nvoy | `#6fa8a0` teal | arrow |
| Nscope (NIP-DA) | `#d8c690` pale gold | scope + keyhole |

Gold (`--gold`) is the through-line: the Nave rose, the footer, the intro
watermark, and the "a Nave project" tag are always gold regardless of the
host app's accent.

## Type

Sans-serif throughout. `--sans` (system proportional) for wordmarks, UI, and
prose; `--mono` (a clean sans monospace — SF Mono / Menlo, **not** Courier)
only for keys, npubs, and code.

## Components (`components/`)

- **The seal** — each app's glyph on an ink rounded square in its accent.
  The favicon, the header logo, and the app-grid icon are all the same seal.
  Generated from `scripts/gen-favicons.mjs`; the full set is in
  `assets/favicons/`.
- **`nave-footer.html`** — the common footer: "A nave.pub project," the family
  cross-links, `help@nave.pub`, the master npub. Fixed Nave colours so it's
  identical on every app. Drop in before `</body>`; mark the current app's
  link with `class="here"`. Used on the utility apps.
- **`nave-intro.html`** — the cinematic entrance for the games: the compass
  rose spins in bigger than the screen, tumbles, resolves upright, and fades
  to a faint gold watermark; the Nostr manifesto quote, a sovereignty blurb,
  and the family seals rise on top. Click a seal → that app; click the rose /
  any key → into the game. Shows once per session. Used in place of the footer
  on Noir and Ntrigue.
- **The Alby sign-in bar** — a NIP-07 (`window.nostr`) login dressed in Alby's
  yellow + bee mark. For apps that authenticate a personal nostr identity.
  (Not for anonymous flows or intake-key logins.)

## How apps consume it

Each app inlines the token block and the components it needs. When the system
changes here, `scripts/propagate-favicons.mjs` re-pushes the seals across the
app repos; the footer/intro are copied from `components/`. There's no runtime
dependency — every app stays a self-contained static client.
