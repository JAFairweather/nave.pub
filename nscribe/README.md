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
- **Send to Ngage** — with your **jaf-quill bunker** connected and your npub set, it **auto-seals**
  the draft as a `draft:post/<id8>` scope gift-wrapped to your npub (pen-attested) so it lands on the
  desk to sign. Without the bunker it falls back to copy-and-open.

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

## Auto-seal to Ngage — wired, and round-trip proven

Connect your jaf-quill bunker (`bunker://`, scoped to draft kinds) in settings and **Send
to Ngage** publishes the re-voiced draft as a `draft:post/<id8>` scope, gift-wrapped to
your npub and penned by jaf-quill (`ngage/drafts.mjs` `pennedDraft`: seal author = the
pen, `direct:true`) — no paste. The emit ceremony
(`publishScopeWithSigner` / `grantWithSigner` / `giftWrapWithSigner`) is lifted **verbatim**
from `ngage/steering.mjs`; only the `draft:post` payload glue is new.

**Proven, not asserted** — `node nscribe/emit.test.mjs`: a draft published with a local
signer reads back through nipxx's own `receiveGrants` → `fetchScope` exactly as the
Director would — the exact text round-trips, the grant author is the pen, and a stranger
key finds nothing. NIP-46 is a custody swap over the same signer interface, so the only
thing left is confirming the **live bunker + real relays** on your desk — which no build
container can reach.

## Honest status

- ✅ **Built + the emit path is round-trip proven** (`emit.test.mjs` PASS): the draft
  seals and reads back through nipxx's own reader as the Director; a stranger gets nothing.
  Static app, real voice spec, real Anthropic call shape, real actuator template; preview
  works with zero setup.
- ⚠️ **Confirm on your desk**: the re-voice needs your credential, and the live NIP-46
  bunker connect + real relays weren't reachable from the build container. First live
  re-voice and first live auto-seal are a your-desk step.
- ⬜ **Not deployed**: `deploy/caddy/Caddyfile` carries `nscribe.nave.pub`; it serves
  once `deploy/sites.sh` clones this path and the deploy runs — your on-box step. When
  it graduates to its own repo (`JAFairweather/nscribe`), update `PROJECTS.md` and
  `sites.sh`.

## Files

```
index.html          the app (no build; inline styles on the Nave ink/gold surface) + importmap
nscribe.mjs         UI logic — the v1 path is dependency-free; auto-seal lazy-loads the heavy modules
emit.mjs            draft:post publisher (verbatim ceremony from ngage/steering.mjs + the payload glue)
emit.test.mjs       round-trip proof (node): publish → read back as the Director → stranger gets 0
voice/jaf-voice.md  your steering file, vendored verbatim (NOT a voice source itself —
                    the essays in library/ are AI-assisted; this file + jamesafairweather.com are)
vendor/nave-connect.mjs   sign-in + NIP-46 bunker signer (from luke/) — do not edit the copy
vendor/nipxx.mjs          scope publish/read (from ngage/lib/) — do not edit
vendor/liverelay.mjs      relay-pool publish adapter (from ngage/lib/) — do not edit
vendor/nostr-tools*.mjs   vendored bundles (from ngage/vendor/) — resolved via the importmap
```
