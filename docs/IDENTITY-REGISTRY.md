# Nave — Identity Registry

Every key in the Nave family: who it is, its public identity, where its secret
is custodied, and a Bitwarden checklist so all of it lives in one vault. **No
nsec appears in this file** (it's a public repo); npubs and hex pubkeys are
public and safe. Copy nsecs from their custody source (SOPS / bunker) into
Bitwarden yourself.

Source of truth for the pubkeys below: `deploy/relay/allowlist.json` (verified
2026-07-20). `nactor` and `operator` npubs cross-check against the live nactor
health endpoint and the minted operator key.

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
| **canonical-quill** | Quill — the canonical (first) instance; becoming the Director's drafting hand (`quill.md` §9) | `npub1jp4aykaleyndasdzp6nsvafxddpc8x9ys2073ptmz3m5dln7p8ysz2rgr3` | — | Sealed age env **with the deploy secrets** — never in the warm.contact app repo (its `.gitignore` bans identity files by pattern: `*.nave.env*`, `*.npub.txt`) |
| **mydude** | Buzz nest — maker and verifier (builds the tooling, then tries to break its own claims) | `npub1p28qwgxra3fvd07euf296csv7k8zarfhzfzz2hhuu0wa27aq5vkq05erd2` | `0a8e0720c3ec` | **Agent-held** — Buzz Desktop runtime, never in SOPS (see below) |
| **kerouac** | Buzz nest — drafting hand; holds the `steer:draft` voice grant | `npub1advxk85uy9xpqa32esxaf4pg4jg4ds5yzchjm8wvnptzuezdwxjsfs6j2q` | `eb586b1e9c21` | **Agent-held** — Buzz Desktop runtime, never in SOPS (see below) |
| **dennis** | Buzz nest — research; holds the `bumble-research-corpus` grant | `npub1ngrnqrfjjhee9554ek8h8j8360rjtqym9eg0c55ptkuxsthegzjsgvmpsw` | `9a07300d3295` | **Agent-held** — Buzz Desktop runtime, never in SOPS (see below) |

> **Not identities:** Ngage is an *app* (the Director's posting desk), not a key
> — its drafts are signed by the Director's own hand; its drafting is done by an
> agent identity (today the scribe under luke's key, next James's Quill). The
> approval-path binding per identity is AD-10.

> ⚠️ **The roster may be incomplete.** The "7+ Nvoy agents" you referenced live
> in the Nvoy ledger (`nvoy_agents`), which can hold identities beyond this fleet
> write-allowlist. **Open task:** enumerate the full Nvoy roster (paste the npubs
> or let me pull them via the ops channel) and add any missing rows here — this
> is the same roster the relay allowlist + relay.nave.pub rollout needs.

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
