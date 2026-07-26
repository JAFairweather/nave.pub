# Nscribe — say it in your hand

Paste anything — a rough note, an AI draft, a wall of thoughts — and get it back in
the Director's voice, then hand it to **Ngage** so nothing publishes without his
signature. It is the **front door on the `revoice` actuator** that
`docs/scoped-agent-actions.md` §II·5 already predicted: the drafter's *surface* is a
parameter, not a fork (`reconnect-reply · post · pr · revoice`). Today jaf-quill
drafts *from evidence*; Nscribe adds the missing "here is my text, say it as me"
mode.

```
You ─paste/upload─▶ Nscribe ─build {surface:'revoice', register, content}─▶
   re-voiced against brief/jaf.md (grant-to-app: your credential → Anthropic direct)
   ─▶ draft ─▶ Ngage desk (you sign in your own hand)
```

## What works in v1 (this build)

- **Sign-in** (optional): NIP-07 extension, for convenience. Not required — the draft
  goes to your own Ngage desk regardless.
- **Paste or upload** `.txt` / `.md`, pick a **register** (post · essay · email ·
  reply), add a one-line intent.
- **Re-voice** — a grant-to-app Anthropic call using your real `brief/jaf.md` voice
  spec (vendored verbatim at `voice/jaf-voice.md`) as the system prompt. The register
  deltas obey the *measured* rules in that file — e.g. spaced hyphens are allowed only
  in the **email** register, never in an essay.
- **Preview** — see the exact actuator template + system/user prompt with no
  credential and no call.
- **Send to Ngage** — copies the draft and opens the desk; you paste and sign.

## The credential (grant-to-app)

The re-voicing needs your `credential:anthropic` value, pasted in **Settings**. It is
held **in memory only** — never written to storage, never logged, never sent anywhere
but `api.anthropic.com` (with the `anthropic-dangerous-direct-browser-access` header).
This is the same grant-to-app posture as `warm quill-draft` (AD-6): the prompt carries
your content, so it never transits shared Nave infra. A proxy endpoint (Nactor
`/api/proxy`) can be wired later for the brokered path.

## The two seams that need your infrastructure

Nscribe never holds a signing key or a secret in a file. Two things light up the full
sovereign path, and neither could be verified from the build container:

1. **`credential:anthropic`** — powers the re-voicing (above). You supply it.
2. **jaf-quill bunker connection** (NIP-46, draft kinds `30440/1059/13` only) — pens
   the draft scope so the desk verifies the hand. **Not wired in v1 by design.**

## Tier 2 — auto-seal to Ngage (next increment)

`vendor/nave-connect.mjs` and `vendor/nipxx.mjs` are staged (copied verbatim from
`luke/` and `ngage/lib/`, "do not edit the copy"). The next increment connects your
jaf-quill bunker and publishes the re-voiced draft as a `draft:post/<id8>` scope,
gift-wrapped to your npub and pen-attested (`ngage/drafts.mjs` `pennedDraft`, seal
author = the pen, `direct:true`), so it lands on the desk without a paste.

This is left un-wired **on purpose**: shipping untested relay/bunker gift-wrap crypto
as "working" is exactly the thing this estate refuses to do (SIDE-QUESTS; "a
self-reported done isn't done until it's played"). It gets wired and verified against
your live bunker on your desk, not asserted from a container that can't reach it.

## Honest status

- ✅ **Built and self-consistent**: static app, real voice spec, real Anthropic call
  shape, real actuator template. Preview works with zero setup.
- ⚠️ **Not yet run end-to-end**: no browser/credential/bunker was available here. The
  first real re-voice and the Ngage handoff are a your-desk verification step.
- ⬜ **Not deployed**: `deploy/caddy/Caddyfile` carries `nscribe.nave.pub`; it serves
  once `deploy/sites.sh` clones this path and the deploy runs — your on-box step. When
  it graduates to its own repo (`JAFairweather/nscribe`), update `PROJECTS.md` and
  `sites.sh`.

## Files

```
index.html          the app (no build; inline styles on the Nave ink/gold surface)
nscribe.mjs         v1 logic — dependency-free (fetch + optional window.nostr)
voice/jaf-voice.md  your steering file, vendored verbatim (NOT a voice source itself —
                    the essays in library/ are AI-assisted; this file + jamesafairweather.com are)
vendor/nave-connect.mjs   staged for tier-2 sign-in (from luke/) — do not edit the copy
vendor/nipxx.mjs          staged for tier-2 draft-scope publishing (from ngage/lib/) — do not edit
```
