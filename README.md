# nave.pub

The **Nave system** — the hub site, the design language, and the reusable
components — kept separate from the individual apps. The apps (Noir, Nontact,
Nvelope, Nherit, Ntrigue, Notegate, Nvoy) live in their own repos and depend
on what's defined here.

> **Identity = Freedom.** A growing family of applications and a protocol on
> nostr, built so your data answers to your keys and no one else's.

## What's here

```
index.html            the hub — the main nave.pub site
favicon.svg           the compass-rose mark
assets/favicons/      the seal set — one per app, generated from the hub glyphs
components/
  nave-footer.html    the common "a nave.pub project" footer (utility apps)
  nave-intro.html     the cinematic game entrance (the compass-rose long screen)
design/
  tokens.css          canonical design tokens — the source of truth
  DESIGN.md           the design system: palette, seals, type, components
scripts/
  gen-favicons.mjs        generate the seal set from one source
  propagate-favicons.mjs  push the seals out to each app repo
docs/
  ECOSYSTEM-HUB.md    the hub plan
  NAVE-GOLIVE.md      the deploy runbook (self-hosted, one box, one Caddy)
```

## The family

Noir · Nontact · Nvelope · Nherit · Ntrigue · Notegate · Nvoy — each a proof of
the same primitive (**NIP-DA / Nscope — scoped data grants**): private, live,
revocable data over public relays. Revocation isn't a policy; it's a key
rotation.

See [`design/DESIGN.md`](design/DESIGN.md) to work with the system.
