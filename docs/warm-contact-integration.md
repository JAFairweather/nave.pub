# Deploying `warm.contact` to the Nave box — integration spec

**Audience:** the agent/engineer standing up `warm.contact` on the same VPS that
serves the Nave ecosystem. **Goal:** deploy the app behind the shared Caddy front
door, on the private `nave` network, and give it the secrets it needs (an IMAP
app-specific password, plus others) **without** ever writing a plaintext secret
into the app's process or a services-facing env file — by plugging into **the
Nave Nactor** (this box's credential/execution runtime) the sovereign way.

Read [`nact/docs/credential-sovereignty.md`](https://github.com/JAFairweather/nact/blob/main/docs/credential-sovereignty.md)
first — it is the identity + credential half of this contract. This doc is the
deploy + wiring half.

---

## 0. What class of entity this is — a **Nhosted** app

`warm.contact` is the charter member of a new class in the Nave ontology: a
**Nhosted** app. Where the *protocol-native* apps (Nontact, Nvelope, Nvoy,
Nherit, Notegate, Noir) put their **data model** on NIP-DA — the protocol *is*
the product — a Nhosted app runs a **conventional backend** and is made
sovereign by **integration**: it brings its own key, receives its secrets as
grants addressed to that key, and reaches the world through verb-scoped broker
calls it signs itself. Nostr secures **how it runs**, not **what it stores**.

> **Nhosted** — *conventional apps made sovereign by the Nave. Nave runs the
> plumbing (front door, credential brokering, deployment); the app brings its own
> key, gets its secrets as grants, and stays portable to any box running its own
> Nactor.*

Placement in the ontology: **Nave** (root) → **Nave Nactor** (runtime) →
**agents** (Luke, Brain) → **Nact_jaf** (approvals carrier) → **apps**, where
apps split into **Native** (data on NIP-DA) and **Nhosted** (conventional
backend, sovereign by integration). This doc is the deploy contract for that
class — `warm.contact` is simply the first to use it. ("Hosted," not "Managed":
the app stays self-sovereign; Nave hosts and brokers, it does not custody.)

---

## 1. What this box is

One VPS, one `docker compose` project (`nave.pub/deploy/`), one front door:

- **Caddy** is the only container that publishes ports (80/443). It terminates
  TLS (auto-ACME) and routes each vhost to a service or a static dir.
- **Every other service is `expose:`-only on the private `nave` network** — never
  a published port. Reachable by service name from inside the network
  (`http://nactor:8791`, `http://director:8787`), never from the internet except
  through Caddy.
- **`sites.sh`** clones/fast-forwards each app repo into `deploy/sites/<name>`;
  Caddy mounts that read-only at `/srv/apps` and file-serves the static ones,
  while the dynamic ones (`luke`, `director`, `nactor`) are built into images.
- **The Nave Nactor** (`nactor` service, `nact.nave.pub/api`) is the credential
  broker + NIP-98-gated control plane. It holds provider secrets in RAM and makes
  the privileged outbound call itself, so callers never touch a raw key.

```
internet ──▶ Caddy (:443) ──┬─ static vhosts  → /srv/apps/<name>  (file_server)
                            ├─ director.nave.pub → director:8787
                            ├─ nact.nave.pub/api → nactor:8791     (broker)
                            └─ …                                   [ private nave net ]
                                    nactor ── egress ──▶ Anthropic / Telegram / Google / IMAP …
```

## 2. The deploy pipeline

- **`deploy.yml`** (full): SSH to the box → `git pull` the platform repo →
  `bash deploy/sites.sh` (pull every app repo) → `docker compose up -d --build`.
  Auto-runs on a push to `nave.pub` `main` **except** paths-ignored ones
  (`.github/**`, `**.md`, `LICENSE`, `deploy/ops/**`). Dispatch manually for an
  app-only change (an app-repo push does **not** auto-deploy — `sites.sh` pulls it
  on the next platform deploy).
- **`ops.yml`** (no deploy): run one curated task or a `deploy/ops/<script>` on the
  box — status, logs, restarts, or a `custom` command. Use for inspection and
  one-off box commands; never for secrets in the command field (it lands in CI
  logs).
- **The box is git pull-only** (no push creds). Anything the box must regenerate
  (SOPS re-encryption) is transited back out for commit from a workstation.

## 3. Add `warm.contact` — three edits + a deploy

**(a) `deploy/sites.sh`** — add the repo so it's pulled onto the box:

```bash
apps=(
  # …existing…
  "warm:warm.contact"          # or whatever the GitHub repo is named
)
```

**(b) `deploy/caddy/Caddyfile`** — add a vhost. Static SPA:

```
warm.contact {
	root * /srv/apps/warm
	encode gzip zstd
	@mjs path *.mjs
	header @mjs Content-Type "text/javascript; charset=utf-8"
	file_server
}
```

…or, if `warm` runs a server, `reverse_proxy warm:<port>` instead (and give it a
compose service, below). Point DNS `warm.contact` → the box IP; Caddy fetches the
cert on first hit.

**(c) `deploy/docker-compose.yml`** — only if `warm` is a *dynamic* service (has a
backend). Static apps need nothing here (Caddy serves the pulled files):

```yaml
  warm:
    build: { context: ./sites/warm }
    image: warm:latest
    restart: unless-stopped
    env_file:
      - path: ./warm.env            # box-local, non-secret config; brokered creds NOT here
        required: false
    environment:
      - NACT_BROKER_URL=http://nactor:8791/api   # reach the broker on the nave net
    expose: ["<port>"]              # never `ports:` — Caddy is the only front door
    networks: [nave]
```

Then a manual `deploy.yml` dispatch. **Golden rule:** `expose`, never `ports`;
`networks: [nave]`; secrets come from the broker, not `env_file`.

## 4. Secrets — the sovereign path (do NOT put the IMAP password in an env file)

The box's flat-secrets era is over. The target: **`warm.contact` is an identity;
its IMAP password is a credential granted to *that identity*, held in Nactor's RAM,
and used only through a verb-scoped broker adapter — the app never holds it.**

**Two different keys — do not conflate them (this is the key chain):**

| | `WARM_NSEC` — the **identity key** | the **IMAP app-password** — a *brokered credential* |
|---|---|---|
| What it is | *who* `warm` is; the key it **signs its own broker calls with** | *what* `warm` may do; a secret it must **never hold** |
| Where it lives | custodial in the sealed `nave.env` (an identity key, like `LUKE_NSEC`), delivered to the `warm` process so it can sign | NIP-44-encrypted to `warm`'s npub, decrypted only into **Nactor's RAM**, never into `warm` |
| Env-split | **NOT stripped** — identity keys stay (add `WARM_NSEC` to the allowlist) | **stripped** from every consumer env; only Nactor reads the bundle |
| Rotation = | revoke `warm` itself | revoke *just* the credential grant, `warm` survives |

The chain, top to bottom: **Nave** (root the box boots under) → **Nave Nactor**
(the runtime Nave bootstraps; holds each identity's key, reads each identity's own
grants) → **`warm`** (a Nhosted app identity that signs for itself and is
*granted* its secrets). Authority flows down the chain by **signature**, never by a
box-local ACL. `warm` proves it is `warm` (NIP-98), and a Director-signed grant —
addressed to `warm` — is what entitles it. Nothing about `warm` lives in Nactor's
config; it lives in the grant.

### 4.1 Stand up the `warm` identity

1. Generate a keypair for `warm`. Its **nsec** is the app's **identity key**
   (custodial: sealed in `nave.env` alongside `LUKE_NSEC`/`BRAIN_NSEC`, and **kept
   by the env-split — identity keys aren't stripped, so leave `WARM_NSEC` off the
   brokered-credential strip list**) — the process needs it to sign its own broker
   calls. Its **npub** is public.
2. Publish a kind-0 profile (`name: warm.contact`, `nip05: warm@nave.pub`) and add
   a `warm` entry to `nave.pub/.well-known/nostr.json` — same pattern as the other
   Nave identities (`luke/publish-profiles.mjs`, the `nostr.json` names map).
3. Register `warm` as an agent in the Nvoy console (it self-requests; the Director
   approves) so the Director can issue it grants.
4. **Director-activate `warm` on the Nave Nactor** (Nact app → *Agent Identities* →
   *Activate (sign)*). This is the **base gate** and it is now **live**: the broker
   rejects *any* credential call from a key that isn't in `config.activations`
   (`403 not activated`) **before** it even checks ownership. Activation is a
   Director-signed act — jaf@ signs it; the box cannot self-activate. A grant
   without an activation is inert.

### 4.2 Grant the IMAP password to `warm` (not to the broker)

The Director (jaf@, key never on the box) issues a **credential scope**, NIP-44
**encrypted to `warm`'s npub**, carrying the IMAP app-password under `.value` (or a
JSON bundle `{host, port, user, app_password}`). Delivered via the Nvoy console's
delegation flow (or the Ledger's **"＋ grant to another identity"**). Because it's
addressed to `warm`, it **follows the app** — move `warm` to another box with
another Nactor and the credential still resolves. That is the whole point: no box
ACL, no broker-owned keys.

### 4.3 Use it through Nmail — the verb-scoped IMAP broker adapter

Do **not** decrypt the password into the app. Add an IMAP **provider** to the Nave
Nactor (this is the `Nmail` adapter — a sibling of the `telegram`/`gcal` providers
in `nactor.mjs`'s `BROKER_PROVIDERS`): the app calls
`POST http://nactor:8791/api/broker`, **NIP-98-signed as `warm`**, with a
*verb* (`list`, `search`, `fetch`, `flag` — read-first, like the Gmail surface is
readonly), and Nactor:

1. checks the **two gates, in order** (both **live** today):
   - **base gate** — is the caller (`warm`) *activated*? (`config.activations`,
     Director-signed.) If not → `403`, before anything else.
   - **ownership gate** — under `NACT_ENFORCE_CREDENTIAL_OWNERSHIP=1`, does a
     Director-signed grant *addressed to `warm`* name this `imap` credential?
     Nactor reads each identity's **own** grants (with that identity's key) into an
     entitlements map — the authority is in the grant, never a box ACL. Enforcement
     is **graduated**: a credential becomes enforced the moment *some* identity
     holds a grant for it, so `imap` — granted only to `warm` — is enforced from its
     first grant;
2. mints/uses the IMAP session **from the RAM-held app-password**;
3. runs the scoped verb and returns **only the result** — the password never leaves
   Nactor, is never logged, and is never returned by the API.

App code shape (mirrors `luke-calendar.mjs`'s broker client):

```js
const r = await broker({ provider: 'imap', verb: 'search',
                         query: 'FROM someone UNSEEN', method: 'POST' })
//        ^ signed NIP-98 as warm; no password anywhere in this process
```

**Write/send** (SMTP) stays behind the same human-gated propose→approve discipline
the rest of the box uses — draft-only by default; a send is a proposed action the
Director approves, never an autonomous reach. The approval card itself routes
through **Nact_jaf** (the approvals-carrier identity, `telegram-nactjaf`), the same
path Luke's calendar/poster beats now use: `warm` *proposes*, Nact_jaf *carries it
to the Director*, and only the Director's tap enacts. `warm` never holds the
approvals bot token either — it's just another brokered credential, owned by
Nact_jaf.

## 5. Env conventions (for the non-secret bits)

- **Brokered credentials** (the IMAP app-password, any bot token) → credential
  scopes (§4), granted to the owning npub. **Never** in `warm.env`, never in the
  SOPS bundle-as-app-env, never returned by the broker. The env-split strips these
  from every consumer env.
- **`warm`'s identity key** (`WARM_NSEC`) → the *one* secret that legitimately rides
  in `warm`'s env, because the process must sign its own broker calls with it. It
  sits in the sealed `nave.env` like the other identity keys and is on the
  **identity-key allowlist** (not stripped). A credential the app *may use* is
  brokered; the key that says *who the app is* is delivered. Keep the two straight.
- **Platform secret bundle** → SOPS-sealed, decrypted on the box by `sites.sh` into
  the box-local `nave.env` (see the `nave.env` migration in the sovereignty ADR).
  Only Nactor reads the full bundle; consumers get a stripped copy (brokered creds
  removed, identity keys kept).
- **Non-secret config** (ports, feature flags, the broker URL, relay lists) → plain
  `warm.env` (box-local) or `environment:` in compose. These are about *where the
  process runs*, not *what it may do*.
- **Pure runtime** (`*_PORT`, paths) → compose `environment:`.

## 6. Checklist

- [ ] DNS `warm.contact` → box IP
- [ ] `sites.sh` apps entry
- [ ] Caddyfile vhost (`expose`/`reverse_proxy`, never `ports`)
- [ ] compose service on `networks: [nave]` (only if dynamic)
- [ ] `warm` identity: keypair, kind-0 profile, `nostr.json` entry, agent registered
- [ ] `WARM_NSEC` sealed in `nave.env` **and added to the identity-key allowlist** (not stripped) — the app signs with it
- [ ] **Director-activates `warm`** on the Nave Nactor (base gate — `403 not activated` until then)
- [ ] IMAP app-password granted as a credential scope **to `warm`'s npub** (ownership gate)
- [ ] `imap` provider (Nmail) added to Nactor's `BROKER_PROVIDERS`, verb-scoped, read-first
- [ ] app calls the broker NIP-98-signed as `warm` — holds **no** password
- [ ] SMTP/send (if any) behind propose→approve via **Nact_jaf**, draft-only by default
- [ ] manual `deploy.yml` dispatch; verify vhost + a broker round-trip (expect `403` until activation **and** grant are both in place)

---

*The one-line contract: an app on this box is an **identity** that plugs into **the
Nave Nactor**. It brings its own key, receives its secrets as grants addressed to
that key, and reaches the world through verb-scoped broker calls it signs itself —
so no raw credential ever lands in the app, and the app stays portable to any other
box running its own Nactor.*
