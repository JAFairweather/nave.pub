# Nave-side review — warm.contact integration

**Audience:** the warm.contact engineer(s). **From:** the Nave side. **Answers:**
the seven questions in `NAVEINTEGRATIONREVIEW.md §6`, plus the reframing that
makes them all fall out cleanly. Read alongside
[`warm-contact-integration.md`](./warm-contact-integration.md) — this review
**amends** that spec where the broker-first framing is too narrow for your
zero-knowledge invariant.

---

## 0. The one reframe that answers most of this

Your instinct is right, and it isn't a divergence from Nave — it's the *purer*
form of the Nave model. Nave has **two sanctioned consumption modes** for a
credential, and both are sovereign (the authority is always in a Director-signed
grant, never a box ACL):

| | **Broker** (Phase A) | **Grant-to-app** (Phase B) |
|---|---|---|
| Who holds the secret | Nactor, in RAM | the **owning instance**, decrypted from its own grant |
| Who makes the provider call | Nactor | the **instance, directly** |
| What Nave sees at call time | the request **content** (it proxies it) | **nothing** — the call never touches Nave |
| Key ever at rest in the app | no | yes (a scoped, revocable grant) |
| Needs `nactor:8791` reachable | yes (on the private `nave` net) | **no** — works from anywhere |
| Right when… | request content isn't sensitive to Nave **and** the app is on-box | request content **is** sensitive, or the app is **off-box** |

The broker was Phase A ("broker-as-vault") — the transition. **Grant-to-app is
Phase B ("agent-owned")** — the credential ciphertext is delivered to the
owning identity, which decrypts and uses it itself. warm.contact is simply the
**first consumer of Phase B**, and your two constraints *force* it:

1. **Zero-knowledge.** Your drafting prompt contains contact plaintext. Brokering
   Anthropic through Nactor would transit that plaintext through shared Nave in
   the clear — breaking *your* invariant, and violating *Nave's own* posture
   ("hold nothing you don't need"). Nave does **not** want to see it either.
2. **Off-box.** The macOS agent can't reach `nactor:8791` — that service is
   `expose`-only on the private `nave` network, never public. A native client is
   simply not on the broker's network. Grant-to-app is transport-agnostic: the
   grant is a Nostr event on relays; the instance is a Nostr client that fetches
   and NIP-44-decrypts it. No Nactor in the path at all.

So for warm.contact: **grant-to-app, uniformly (Anthropic, Gmail, SMTP), with
Nactor not involved at call time.** That is blessed. The rest is detail.

---

## 1. Answers to the seven questions

**Q1 — Hierarchical re-grant (your linchpin): YES, supported.**
`Director → warm central identity → per-instance npub` is a NIP-DA **delegation
chain**, which is exactly what the grant model is for. The mechanism already
exists in the Nvoy console as **"＋ grant to another identity"** (it re-grants a
scope you hold to another grantee, reusing the scope key). One hard rule:
**re-delegation is governed by the grant's terms.** The Director's grant to the
central identity must be issued **with re-delegation allowed** (i.e. *not*
`no_redelegate`); each leaf grant to an instance can then be `no_redelegate` so
the tree stops there. Revocation cascades: Director revokes central → the whole
fleet's grants die with the chain; central revokes one instance → just that
instance. The central identity is thus both a **grantee** (of the Director) and a
**sub-issuer** (to its fleet) — it needs its own key to sign the sub-grants.

**Q2 — Grant-to-app vs broker-only: grant-to-app is a first-class path.**
A grant *can* deliver the actual credential **value** (`value:{…}`, NIP-44 to the
grantee npub) for local decryption and a direct provider call. The broker is one
consumption path, not the only one. The spec's "the app never holds the key" is
the Phase-A default, not a prohibition — see §0. For your case, grant-to-app is
correct.

**Q3 — Anthropic specifically: grant-to-app, blessed.**
Do **not** broker Anthropic. The prompt carries contact plaintext; brokering it
transits that through multi-tenant Nave. The instance holds a scoped Anthropic
credential (from its grant) and calls `api.anthropic.com` directly. Nave sees the
grant issuance, never the prompt. This is the disclosed v0.4 posture and it's the
right one. (See §2 for the "shared underlying key" caveat — it's the real
tradeoff, and it's on the credential design, not the pattern.)

**Q4 — Per-instance lifecycle.**
- *Register:* each install generates its own npub and **self-requests** to the
  central identity (the same access-request flow Nvoy already runs; here the
  **central identity** approves, not the Director directly).
- *Scope:* central issues a leaf grant (`no_redelegate`, tight scope, short TTL).
- *Revoke:* central revokes that instance's grant (one action), or rotates the
  scope. No box ACL to touch.
- *Volume:* grants are just Nostr events — cheap to issue and revoke at fleet
  scale. The real cost is **operational**: the central identity's key must sign
  each sub-grant, so a large fleet wants a *fleet console* (a scoped Nvoy for the
  central identity) and a policy on human-approve vs auto-approve issuance. That
  console is a build, not a protocol gap.

**Q5 — Metadata exposure (disclose this accurately).**
- **Relays** see: grant/revocation **events** — issuer npub, grantee npub, the
  scope *label* (e.g. `credential:anthropic`), terms, and timing. This is a
  real relationship-graph signal (which instances exist, what they're scoped to,
  when). It does **not** include the credential value (NIP-44 encrypted) or any
  contact content.
- **Nactor**, in grant-to-app, sees and logs **nothing at call time** — the calls
  don't go through it. (Only the broker path would log caller npub + provider +
  verb + timing.)
- So the honest user-facing line: *"Nave/relays can see that your instance exists
  and which providers it's authorized for, and when authorizations change — never
  your contacts, messages, or the content of any provider call."*

**Q6 — Two components, how many identities?**
Per-instance is the axis, not per-component. **Every deployment gets its own
npub** — the server-side data-entry app is one instance identity; **each Mac
install is its own instance identity**. All are leaves under the **one central
`warm.contact` identity**, which is the Director's grantee. So: **1 central + N
instances**, where N grows with installs. Don't share one npub across installs —
that would make a single leaked device un-revocable without cutting everyone.

**Q7 — Client crypto for Swift: expected, and standard primitives.**
Grant-to-app off-box needs NIP-44 decrypt + NIP-98 sign in the client. There's no
blessed Swift SDK, but the primitives are standard and small:
- **NIP-44 v2:** secp256k1 ECDH → HKDF-SHA256 → ChaCha20 + HMAC-SHA256 (base64
  payload). Get the EC bits from **`swift-secp256k1`** (the same libsecp256k1
  nostr uses); ChaCha20/HKDF/HMAC come from **CryptoKit**.
- **NIP-98:** a kind-`27235` event with tags `['u', url]`, `['method', …]`,
  `['payload', sha256(body)]`, **schnorr/BIP-340 signed** (also in
  `swift-secp256k1`).
Your server-side component gets both from `nostr-tools` for free. This is a real
dependency add to a notarized app, but it's a well-trodden ~one-file addition,
not a research project.

---

## 2. The one tradeoff to design around (name it to users)

Grant-to-app means the credential is **decryptable at the instance** — "more
copies at rest" than the broker's RAM-only secret. For a **Gmail app-password**
that's inherent (it's one password; scope it, rotate it, revoke per instance).
For **Anthropic** there's a sharper edge: if the same underlying account key is
NIP-44'd to every instance, a single leaked device grant exposes that key. Two
mitigations, in order of preference:

1. **Per-instance distinct credentials where the provider allows it** — issue each
   instance its own scoped/budgeted Anthropic key (Anthropic workspaces / limited
   keys) so a leak is contained and independently revocable. The grant then
   carries a key that is *already* least-privilege.
2. **If a shared key is unavoidable:** tight per-instance grant TTL + fast
   rotation + immediate revoke-on-compromise (grant-to-app makes revoke a single
   signed event). A compromised instance still leaks a live key until rotation —
   disclose that honestly.

There is **no blind-broker middle path** for Anthropic: injecting an API key
requires terminating TLS and reading the request, so a broker that adds the key
*by definition* sees the prompt. ZK content ⇒ grant-to-app ⇒ accept the at-rest
tradeoff and mitigate it. That's the real decision, and it lives on the
*credential's* least-privilege design, not on the integration pattern.

---

## 3. Confirmed build order (your §5.5, refined)

1. **Nave side (Director):** stand up the **central `warm.contact` identity**;
   Director grants it the provider scopes **with re-delegation allowed**
   (Anthropic, Gmail) — a non-leaf grant.
2. **Central-as-issuer:** give the central identity a way to issue leaf sub-grants
   to instance npubs (a scoped Nvoy / fleet console). Decide human-approve vs
   auto-approve per install.
3. **Instance bootstrap:** each install generates its npub, self-requests to
   central, receives a `no_redelegate`, short-TTL, tightly-scoped leaf grant.
4. **Client crypto:** NIP-44 decrypt + NIP-98 sign (Swift via `swift-secp256k1` +
   CryptoKit; server via `nostr-tools`).
5. **Drop-in credential source:** implement your existing `SecretVault`
   indirection's "give me a secret" as "fetch + NIP-44-decrypt this instance's
   grant." Zero consumer-code changes — exactly the seam you already built.
6. Same pattern server-side for the data-entry component.

**Nactor is not on warm.contact's critical path.** It stays the broker for
*on-box, non-ZK* agents (Luke, Brain). warm.contact uses Nave as the **grant +
identity fabric** (relays + issuance), not as a content vault — which is the
correct trust boundary for a zero-knowledge product.

---

## 4. Net verdict

- Your reading of the spec (§4) is accurate; your lean to grant-to-app (§5.2) is
  **correct and blessed**, and it's Nave's own Phase B rather than a fork.
- The **hierarchical re-grant** (your linchpin) is **supported**, gated by grant
  terms; the central identity is a grantee-and-sub-issuer.
- **Per-instance identities** (1 central + N instances), not per-component.
- The only genuine tradeoff is **secret-at-rest** for grant-to-app; solve it on
  the credential (per-instance least-privilege keys), not the pattern.
- Nactor is **out of your call path**; Nave is your grant fabric.

Build items this creates on the Nave side: a **central-identity fleet console**
(scoped Nvoy for sub-grant issuance + revocation) and confirming **re-delegation
terms** flow through the grant model end-to-end. Both are tracked.
