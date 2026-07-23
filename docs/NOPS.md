# Fleet Ops — the interim control plane (proto-Nops)

> **Naming correction.** **Nops is a *concept*, not this.** Nops = *Nostr server
> ops*: operate the box with your nostr key — every op a signed, scoped, human-
> approved, revocable action, the ops-runner holding its **own identity** and
> receiving its allowed verbs as a **scoped data grant**. No SSH, no CI secret.
> Spec: [`nact/docs/nops.md`](https://github.com/JAFairweather/nact/blob/main/docs/nops.md).
>
> **What's documented below is the *interim* control plane** — the same shape
> (verb menu, restricted key, versioned scripts, config-as-grant) but run over
> **GitHub Actions + SSH** instead of nostr. The Nops note calls this exactly:
> "we already built the proto over the wrong transport." Today's restricted
> `relay-ops` allowlist is the closest organ — swap its SSH transport for a
> scoped grant + signed approval and it *becomes* Nops.

The operations discipline for the Nfra substrate (boxes, keys, relay, bunker,
CI). Jump-page: what's built, where it lives, and ideas floated but not built.
Deep runbook: `deploy/ops/PLAN.md`.

## Built — the toolkit (links)

Server bring-up & keys (the "one management key" standard):
- **[`deploy/ops/ssh-standard.md`](../deploy/ops/ssh-standard.md)** — the process: one `nave_mgmt` key opens every box.
- **[`deploy/ops/rekey.sh`](../deploy/ops/rekey.sh)** — rekey an existing box (verify-before-lock; can't lock you out).
- **[`deploy/ops/newbox.sh`](../deploy/ops/newbox.sh)** — provision a fresh box to the standard (`MGMT_PUB=… sh newbox.sh`).
- **[`deploy/ops/harden.sh`](../deploy/ops/harden.sh)** — Docker-safe baseline (firewalld-free; fail2ban; auto-updates; reboot survival) → calls firewall.sh.
- **[`deploy/ops/firewall.sh`](../deploy/ops/firewall.sh)** — on-box firewall: nftables INPUT + DOCKER-USER seal. No provider panel needed.
- **[`deploy/ops/inventory.sh`](../deploy/ops/inventory.sh)** — read-only box inventory (OS, docker, firewall, containers, keys, ports).
- **[`deploy/ops/ci-ops-allow.sh`](../deploy/ops/ci-ops-allow.sh)** — forced-command allowlist for the bunker box's restricted CI key.
- **[`deploy/ops/PLAN.md`](../deploy/ops/PLAN.md)** — the living fleet runbook + firewalld-vs-Docker incident reference.

SOPS / secrets & deploy:
- **`deploy/secrets/nave.enc.env`** — age-encrypted fleet env (agent nsecs, relay lists, tokens). Edit: `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops deploy/secrets/nave.enc.env`.
- **`deploy/secrets/nactjaf.age`** — Nact_jaf key material (age).
- **`deploy/bunker/setup.sh`** + `README.md` — stand up Bunker46 (stable `.env`, compose up).
- **`deploy/relay/`** — strfry relay: `allowlist.json` (fleet write-allowlist), `write-policy.py`, `Caddyfile`, `docker-compose.yml`, `setup.sh`.

CI ops channels (GitHub Actions in `nave.pub`):
- **`fleet-ops.yml`** — run a command on `main` or `warmcontact` (full CI key).
- **`relay-ops.yml`** — RESTRICTED verb channel for the bunker box (allowlist only; can't read the sovereign `.env`).
- **`ops.yml`** — main-box curated tasks / run-script. The custom task's input
  is **`command`** (`-f task=custom -f command='…'`); a wrong input name fails
  with `HTTP 422: Unexpected inputs`. Main-box paths are **flip-aware**: check
  for the deploy flip marker to pick the live deploy root before pathing.
- **`probe.yml`** — external read-only probe (endpoints, cert, port seals).
- **`verify.yml`** — post-deploy health harness. `deploy.yml` / `smoke.yml` — deploy + smoke.
- Per-box CI keys: `nave_ci_relay` (restricted), `nave_ci_warm`; main uses `github-deploy`. Secrets live in the **`nave.pub` repo** (VPS_*, RELAY_SSH_*, WARM_SSH_*).

Channel reliability (learned 2026-07-22→23):
- The runner's SSH to the main box **intermittently times out while the box is
  healthy** (public endpoints 200, port 22 reachable from the Mac). The action
  retries once; if both dials fail, re-dispatch or fall back to the direct
  mgmt path below. A deploy's verify step can also read a container
  mid-restart as down (a 502 ✗ on a service that is healthy seconds later) —
  re-verify before treating a red deploy as a real outage.
- **Direct mgmt path:** `nave_mgmt` from the Mac opens every box and is faster
  for reads. Prefer `scp` of specific files to a scratchpad over long remote
  `cat` pipelines. Luke's OpenClaw workspace (`SOUL.md` etc.) lives under the
  deploy root's `openclaw-state/` — deliberately gitignored, **box-only**;
  private files there (MEMORY/DREAMS) stay on the box.

## The fleet (roles — IPs live in Bitwarden, not here)

| Box | Provider | Runtime | CI channel |
|---|---|---|---|
| **main Nave** | Hostinger (Ubuntu 24.04) | Docker: nact/luke/nvoy/nactor/caddy/openclaw | full (`fleet-ops` main) |
| **relay / bunker** | Hostinger (AlmaLinux 10) | Docker: strfry + Bunker46 | **restricted** (`relay-ops`) |
| **warm.contact** | DigitalOcean (Ubuntu, 1 GB) | native Caddy + Node `:8484` | full (`fleet-ops` warmcontact) |

## Ideas we floated (not built)

- **Move relay lists out of SOPS into plain env** — relay URLs aren't secrets;
  today they're bundled in `nave.enc.env`, so only James (age key) can change
  them. Plain env → relay changes become ordinary CI deploys I can run.
- **`nave-fleet` / `nfra` repo** — if ops ever outgrows `nave.pub/deploy`,
  relocate the whole toolkit + secrets into one (private) repo. Not needed now;
  a private repo would also let secrets stop living in a public repo.
- **A `harden` verb on the bunker's restricted channel** — deliberately *not*
  added: mutating scripts on the sovereign box stay human-in-the-loop.
- **Provider edge firewalls (22/80/443)** — belt-and-suspenders now that the
  on-box firewall is primary; optional.
- **Self-heartbeat / scheduled fleet probe** — a cron that runs `probe.yml` +
  `inventory.sh` on a cadence and pings on drift (ties to Luke's heartbeat).
- **`send_later`-style incident check-ins** for the assistant when babysitting.

## Standing conventions

- **firewalld is banned** on Docker hosts (it flushed Docker's chains → full
  outage). Port control = on-box `firewall.sh` (+ optional provider edge).
- **New box** = `newbox.sh` → edge/on-box firewall → prove key login → `rekey.sh --lock`.
- **New agent** = mint key → allowlist.json → SOPS → Bitwarden note → registry row.
- **Break-glass** = provider console (out-of-band, root password in Bitwarden);
  key-only SSH never locks you out of the box itself.
