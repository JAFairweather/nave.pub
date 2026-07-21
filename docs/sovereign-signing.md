# Sovereign signing + own relay (bunker for iPhone, restricted relay, `nave-connect`)

**Status:** design, build‑ready. Nothing here provisions infra or touches the
sovereign key — it's the plan to execute deliberately. Two things need James's
hands and his offline key (buy the VPS; mint the delegated operator key); the
rest is config + a client module I can build.

Companions: `nave-architecture-decisions.md` (AD‑2 identity‑not‑server, which
this completes on the client side), `credential-sovereignty.md` (the grant
model), `../nact/docs/connectors.md` (the connector pattern).

---

## The decisions (agreed)

1. **iPhone signs via NIP‑46 (bunker)** — a remote signer, so a no‑extension
   browser can sign the NIP‑98 challenge without the key in Safari.
2. **The bunker holds a *delegated operator key*, never the sovereign key**, and
   runs on a **separate cheap VPS** — off the agent box.
3. **The sovereign key (jaf@dequalsf.com) stays offline** on the Mac, used only
   to mint/revoke delegations. *(Future, separate issue: consolidate all the
   minted nsec identities back to the Mac under one custody scheme.)*
4. **`nave-connect` grows a NIP‑46 transport** so the same shared sign‑in works
   on desktop (NIP‑07) and iPhone (NIP‑46).
5. **Stand up our own relay, restricted to our identities** — so the grant
   fabric (and the bunker) stop depending on public relays.

## Identity model — why the bunker never sees the sovereign key

```
  jaf@dequalsf.com  (SOVEREIGN)         offline on the Mac, SOPS-sealed
        │                               comes out only to mint/revoke delegations
        │  delegates (NIP-26 / a Nscope grant of signing authority)
        ▼
  operator-mobile   (DELEGATED)         lives in the bunker (NIP-49 encrypted),
        │                               signs day-to-day logins on request
        ▼
  bunker (NIP-46)  ◄──relays──►  iPhone Safari → Nvoy / Nact / Luke console
```

The bunker is an **always‑on signer**: it signs whenever a valid request
arrives. So the key it holds must be one you can **revoke and re‑mint** — a
delegated operator key — not the root. A box compromise then costs you a
rotation, not your identity. This is the same owner→delegate shape the grant
fabric already runs on; we're just applying it to *signing authority* for
interactive logins.

> Decision to make when you mint it: **NIP‑26 delegation** (the operator key
> signs "on behalf of" sovereign, verifiable by clients that check the
> delegation tag) vs **a distinct operator identity** that simply *holds grants*
> in its own name. For logging into your own apps, a distinct operator identity
> is simpler and enough — the apps authorize by "is this pubkey in my fleet,"
> not "is this literally the sovereign." I recommend the distinct operator
> identity; keep NIP‑26 in reserve for cases that must read as the sovereign.

## The bunker — separate VPS, as cheap as possible

- **Box:** the smallest tier anywhere — **1 vCPU / 1 GB / ~$4–5/mo** (Hetzner
  CX22 is the value pick; a $4 Vultr/Linode also works). It does almost nothing
  but hold a key and answer sign requests.
- **Software:** **Bunker46** or **Signet**, both docker‑compose, both modern
  NIP‑46 signers. Pick on one axis: **Bunker46** if you want **WebAuthn/2FA** on
  the dashboard (AES‑256‑GCM at rest) — good for a phone‑centric flow; **Signet**
  if you want the JWT‑authed API + the more extensive nsecbunkerd lineage. Either
  is fine; I lean **Bunker46** for the 2FA.
- **Key at rest:** NIP‑49‑encrypted (or the tool's AES‑GCM) — the operator nsec
  is never on disk in the clear.
- **Relays:** point it at **3** — our own relay (below) **+ two public**
  (relay.damus.io, nos.lol) as fallback, so no single relay failing locks you
  out of signing.
- **Scope the signer:** per‑app connection tokens; restrict which **event kinds**
  it will sign (login challenges + the app kinds you actually use — not "sign
  anything"); enable the approval prompt / 2FA for anything sensitive; rate‑limit.

## The relay — strfry, restricted to our identities

The real prize: **own the grant fabric's transport.** Today grants, entitlement
reads, endpoint adverts (AD‑2), and kind‑0 profiles all ride public relays. Our
own relay removes that dependency and keeps the metadata (who's granting what to
whom, and when) off third‑party infra.

- **Box:** **1 vCPU / 1 GB / 20–50 GB SSD, ~$5/mo.** Events are tiny; our
  fleet's volume is dozens–thousands/day. Can be its own VPS, or share the
  bunker box (they're both near‑idle) — though a separate box keeps blast radii
  apart. Recommend: **relay and bunker on the same small VPS to start** (cheapest,
  both trivial load), split later if you want stricter isolation.
- **Software:** **strfry** (C++/LMDB, the efficient default), behind the existing
  Caddy as `relay.nave.pub` (WSS).
- **Write policy — restricted (this is the point):** a strfry write‑policy plugin
  that **accepts events only from our fleet pubkeys**, with one carve‑out for the
  NIP‑46 transport kind (see the gotcha below):

  | Rule | Effect |
  |---|---|
  | author ∈ **fleet allow‑list** | accept (all kinds) |
  | kind **24133** (NIP‑46) from anyone | accept, rate‑limited (E2E‑encrypted transport; the bunker itself authorizes) |
  | everything else | reject |

  **Fleet allow‑list (hex):**
  ```
  nave      d8de5184a096e49b3f79730258c05f8ffb56cdf138c08b3c7b0b0685a0fb963e
  luke      f938026f5e12f026f8dc9f032cb672e946fa1b631a197dc06e635d46f014665a
  brain     d206ea7b366307c6c17bd267eb3798a21e26468f951f4f4a73833abd617530f5
  nactor    20d4f68158d7a633fff5166f36e23ee62b3135b01567bb20114f288e92857df6
  nact_jaf  bb4ff7defbcdb189ae36ea2dad8e2402b81f00ee5c478e834606dcf4e6b6f97f
  noir      61c360eff984c56adce1c4a0735326b2a67e7f6dd65c17cd9dcdb9e18afbfc6a
  sovereign <jaf@dequalsf.com hex — fill in>
  operator  <delegated mobile key hex — fill in once minted>
  ```
  *(warm.contact and other partners are deliberately **not** on this list — they
  use public relays; this relay is ours.)*

- **The NIP‑46 gotcha (don't skip this):** a NIP‑46 client (your iPhone app)
  talks to the bunker using a **fresh ephemeral key** it generates locally — a
  pubkey we can't know in advance. A naïve "allow‑list of known pubkeys" would
  **block your own phone from reaching the bunker.** Two clean ways out: (a) the
  kind‑24133 carve‑out above (simplest — those messages are encrypted, so an open
  transport kind leaks nothing but timing), or (b) require **NIP‑42 AUTH** and
  have the bunker use a `nostrconnect://` flow it initiates, so the allowed
  operator key is the publisher. Start with (a); it's the least fragile.

- **Retention:** replaceable events (grants, adverts, profiles) self‑prune to
  latest; cap ephemeral/24133 retention short (minutes–hours). Disk stays tiny.

## `nave-connect` — the shared sign‑in module (#56)

One module every Nave app imports; it abstracts *"get me a signer"* so the apps
stop hard‑coding a login path:

```
getSigner() → picks a transport:
  • NIP-07   — window.nostr present (desktop extension)         → sign locally
  • NIP-46   — a saved bunker:// connection (iPhone / no ext)   → sign via bunker
  • none     — read-only mode + a "connect" affordance (paste bunker:// / scan QR)
```

- **iPhone path:** the app shows a QR / `nostrconnect://` link; you approve once
  in the bunker; the app stores the connection and signs every subsequent
  NIP‑98 challenge through it. No key in Safari, ever.
- Also unifies the **title bar** (identity pill, connect/disconnect) across Nvoy,
  Nact, and the Luke console — the second half of #56.
- Ships as a single vendored ES module (no build step), same posture as the rest
  of the apps.

### The unified title bar — `nave-titlebar` (built)

The title-bar half now has a source of truth in this repo:
`components/nave-titlebar.html` (static markup + styles, fleet ids included)
and `components/nave-titlebar.mjs`
(`renderTitlebar(el, { appName, npub, kind, onRefresh, onLogout, onSignIn })` +
`updateTitlebar(el, patch)`). One bar everywhere: seal + wordmark; signed in —
the **signer-kind badge** (`extension` / `bunker` / `local key`), the
**click-to-copy npub pill** (truncated middle), **Refresh**, **Log out**;
signed out — a single **Sign in** slot. Token-driven, so each app's `--accent`
carries through (per the harmonized Nvoy/Nact header), with dark-canonical
fallbacks baked in; demo/verification page: `components/titlebar-demo.html`.

**Adoption (per app, tracked in nact#16):** vendor a copy — the same no-build
copy-in as `nave-footer.html` and nave-connect ("do not edit the copy") — and
wire it to nave-connect's signer: on login,
`renderTitlebar(el, { appName, npub, kind: signer.kind, onRefresh, onLogout })`;
on boot/logout, `npub: null` + `onSignIn`. The badge mapping (`nip07 →
extension`, `nip46 → bunker`, `local → local key`) is exactly what the Nvoy
console shipped as the pattern-setter. Nvoy, Nvelope, Nontact, and Nherit each
hand-roll a near-identical `<div id="me">` today; adoption replaces those with
the vendored component — the static block keeps the fleet's `#me` / `#me-kind`
/ `#my-npub` / `#refresh` / `#logout` ids, so existing by-id wiring survives,
while the `.mjs` path wires by callback.

## Risks (condensed)

**Bunker:** always‑on signer = always‑on attack surface (→ scoped tokens,
kind‑limits, 2FA, rate‑limit); key exposed if host owned (→ delegated key only,
NIP‑49 at rest, sovereign offline); relays down = can't sign (→ 3 relays); young
software (→ pin versions, small blast radius); lost keystore (→ encrypted backup,
re‑mint from sovereign).

**Relay:** another 24/7 service to patch/monitor (→ never its sole use for
signing; keep 2 public fallbacks); open relay = spam/DDoS (→ restricted write
policy, behind Caddy); metadata in logs (→ it's ours, and that's the point).

## Buildout — who does what

**James (needs the sovereign key / a purchase):**
1. Spin up the **$4–5 VPS**.
2. **Mint the delegated operator key** from the sovereign on the Mac; hand its
   **npub** back here for the allow‑list (never the nsec).
3. Point **DNS**: `relay.nave.pub` → the VPS.

**Me (config + code, no secrets):**
4. strfry compose + Caddy vhost + the **write‑policy plugin** wired to the
   allow‑list above.
5. Bunker46/Signet compose with the 3‑relay config and scoped‑signer settings
   (you paste the encrypted operator key in on the box).
6. Build the **`nave-connect` NIP‑46 transport** + unified title bar (#56).
7. **AD‑2 client resolver** (separate, in progress): make callers address Nact by
   `nactor@nave.pub` and resolve the endpoint from its published advert — so
   "Nact is an identity, not a server" is true end‑to‑end.

## Relation to AD‑2 (identity, not a server)

The endpoint‑advertisement *producer* already ships (Nactor publishes kind
10002 + 31990 under its key on boot). This plan completes the *consumer* side —
`nave-connect` and the Nact clients resolve *where* from *who*. Same decoupling,
now applied to both **the apps' signer** (bunker) and **the runtime's endpoint**
(resolver): moving any box becomes "republish," never "reconfigure every client."
