# Nave — Identity Registry

Every key in the Nave family: who it is, its public identity, where its secret
is custodied, and a Bitwarden checklist so all of it lives in one vault. **No
nsec appears in this file** (it's a public repo); npubs and hex pubkeys are
public and safe. Copy nsecs from their custody source (SOPS / bunker) into
Bitwarden yourself.

Sources of truth: `deploy/relay/allowlist.json` for the **fleet write-keys**;
the **Nvoy ledger (`nvoy_agents`) + `.well-known/nostr.json`** for the agent
identities (the Quill instances, the Buzz nest, partners). `nactor` / `operator`
cross-check against the live nactor health endpoint and the minted operator key.

## The roster

| Name | Role | npub | hex (first 12) | Secret custody |
|---|---|---|---|---|
| **sovereign** (`jaf@dequalsf.com`) | Root Director — the whole chain signs up to him | *(mint/record)* | `REPLACE_…` in allowlist | **Bunker** (Bunker46, encrypted) |
| **nave** | The hub / top fleet identity | `npub1mr09rp9qjmjfk0mewvp93szl3la4dn038rqgk0rmpvrgtg8mjclqk5002v` | `d8de5184a096` | SOPS `nave.enc.env` |
| **nactor** | The runtime / credential broker | `npub1yr20dq2c67nr8ll4zehndc37uc4nzddsz4nmkgq3fu5gay590hmqdhmw0w` | `20d4f68158d7` | SOPS |
| **luke** | The employee agent | `npub1lyuqym67ztczd7xunupjednja9r05xmrrgvhmsrwvdw5duq5vedq44kfxv` | `f938026f5e12` | SOPS |
| **brain** | Luke's proposer identity | `npub16grw57ekvvrudstm6fn7kduc5g0zv350j5057jnnsvat6ct4xr6swjtd6h` | `d206ea7b3663` | SOPS |
| **nact_jaf** | Approvals owner (Nact channel) | `npub1hd8l0hhmekccnt3kagk6mr3yq2up7q8wt3rcaq6xqmw0fe4kl9lsgmkmrh` | `bb4ff7defbcd` | SOPS |
| **noir** | Legacy hub identity (superseded by nave.pub) | `npub1v8pkpmlesnzk4h8pcjs8x5exk2n8ulmd6ewp0nvaeku7rzhml34qjqa5fz` | `61c360eff984` | SOPS |
| **operator** | Relay operator / bunker signer #2 | `npub15a6ycljnfyxuhnxjp2wdv08umpr573fkss0g0h8eaxzlypvmh05sn47lel` | `a7744c7e5349` | **Bunker** |
| **Quill (canonical)** | The canonical (first) Quill instance — the warm.contact reconnect agent. **Distinct from James's Quill** (below) and from the drafting hand (`kerouac`). | `npub1jp4aykaleyndasdzp6nsvafxddpc8x9ys2073ptmz3m5dln7p8ysz2rgr3` | `906bd25bbfc9` | Sealed age env **with the deploy secrets** — never in the warm.contact app repo (its `.gitignore` bans identity files by pattern: `*.nave.env*`, `*.npub.txt`) |
| **James's Quill** | The Director's own (personal) Quill instance — his reconnect agent (`quill.md` §9). **Distinct from the canonical instance.** | `npub13uuznpc7chk4mlcmve2d8j5832slgvffdre33vvtzk8pmyls5dlsezdfj8` | `8f3829871ec5` | Device-held — Mac Keychain (`WhenUnlockedThisDeviceOnly`); never in SOPS |
| **mydude** | The Director's **proving hand** (Buzz nest) — maker & verifier: builds the tooling, then tries to break its own claims. Nvoy grantee | `npub1p28qwgxra3fvd07euf296csv7k8zarfhzfzz2hhuu0wa27aq5vkq05erd2` | `0a8e0720c3ec` | **Agent-held** — Buzz Desktop runtime, never in SOPS (see below) |
| **kerouac** | The Director's **drafting hand** (Buzz nest) — holds the `steer:draft` voice grant (Nvoy); drafts for review, never posts | `npub1advxk85uy9xpqa32esxaf4pg4jg4ds5yzchjm8wvnptzuezdwxjsfs6j2q` | `eb586b1e9c21` | **Agent-held** — Buzz Desktop runtime, never in SOPS (see below) |
| **dennis** | The Director's **foraging hand** (Buzz nest) — research; holds the `bumble-research-corpus` grant (Nvoy) | `npub1ngrnqrfjjhee9554ek8h8j8360rjtqym9eg0c55ptkuxsthegzjsgvmpsw` | `9a07300d3295` | **Agent-held** — Buzz Desktop runtime, never in SOPS (see below) |
| **warm.contact** | **Partner** — the zero-knowledge contact app's central identity; holds a Director-issued Nvoy grant (the integration). Own `wc1` crypto; **off** the fleet relay allowlist (public relays only) | `npub17fc8tle34k50gvl9ysmz9yeyyjjzaanre3hry9thgyejqarqg0tqlqsldk` | `f27075ff31ad` | **Partner-held** — warm.contact's own custody; never in SOPS/bunker |

> **Not identities:** Ngage is an *app* (the Director's posting desk), not a key
> — its drafts are signed by the Director's own hand; its drafting is done by an
> agent identity (**`kerouac`**, the drafting hand, holding the `steer:draft`
> grant). The approval-path binding per identity is AD-10.

> ✅ **Roster reconciled against the Nvoy ledger (2026-07-23).** The Buzz-nest
> agents (`kerouac`, `dennis`, `mydude`), **James's Quill**, and the
> **warm.contact** partner identity are now listed alongside the fleet keys.
> Going forward: when a new agent is minted, re-check `nvoy_agents` and add its
> row here (npub / role / custody only — never an nsec).

## Custody map

- **Bunker (Bunker46, `bunker.nave.pub`, encrypted with ENCRYPTION_KEY):**
  `sovereign` (jaf), `operator`. The `.env` holding ENCRYPTION_KEY is backed up
  to Bitwarden (disaster recovery — losing it means re-importing the keys).
- **SOPS (`deploy/secrets/nave.enc.env`, age-encrypted):** the fleet agent
  nsecs. Decrypt with `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops …`.
- **SOPS age key** itself: on your Mac (`~/.config/sops/age/keys.txt`) — this is
  the master that unlocks all agent nsecs, so **it belongs in Bitwarden too**.

## Bitwarden checklist (do once, per identity)

Create a **Secure Note per identity**, named e.g. `nave · luke`:
- [ ] name + role
- [ ] npub (from the table above)
- [ ] nsec (copy from SOPS / bunker — never from chat)
- [ ] nip05 if it has one (e.g. `nactor@nave.pub`)
- [ ] where it runs (which box / service)

Plus these **vault-critical** items (not per-identity, but the keys to everything):
- [ ] **SOPS age key** (`~/.config/sops/age/keys.txt`) — unlocks all agent nsecs
- [ ] **bunker `/root/bunker46/.env`** (ENCRYPTION_KEY) — decrypts jaf + operator
- [ ] **`nave_mgmt` SSH private key + passphrase** — opens every box
- [ ] per-box **root passwords** (console break-glass): main, relay, warm.contact
- [ ] the three **`nave_ci_*`** CI private keys (or note they're in GitHub secrets)

## Convention going forward

Every new agent, at birth: mint key → add hex to `deploy/relay/allowlist.json`
(so it can write to `relay.nave.pub`) → store nsec in SOPS → add a Bitwarden
secure note → add a row here. That keeps this registry the single human-readable
index of the whole identity graph.

### Exception: agent-held keys (the Buzz nest)

`mydude`, `kerouac` and `dennis` are the Director's agents on the Buzz nest
(relay `wss://nave.communities.buzz.xyz`). Their nsecs were minted by Buzz
Desktop and live in the agents' own runtimes — **they are not in SOPS and must
not be**. Three consequences, all deliberate:

- **`luke/publish-profiles.mjs` cannot publish these profiles.** It loads each
  identity's nsec from a box env var; these keys never reach the box. Each agent
  publishes its own kind-0 and kind-10002 under its own key instead. That is not
  a workaround — an agent whose key the box holds is not separately keyed, and
  separate keys are the point of the nest.
- **No Bitwarden nsec note, and no SOPS row.** Custody is the runtime. If a key
  is lost, the identity is re-minted and these rows are updated; there is no
  recovery path and there is not meant to be one.
- **Not on the relay write-allowlist.** They publish to the public trio, not to
  `relay.nave.pub`. Add a hex to `deploy/relay/allowlist.json` only if that
  changes — an unused write grant is still a write grant.

What the Director holds over them is not their keys. It is the scoped grants
(NIP-DA) he issues to those npubs, and rotating a scope key revokes one without
touching the identity.
