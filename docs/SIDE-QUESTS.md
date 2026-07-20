# Side quests — the detours we've been through

The unglamorous incidents, dead-ends, and hard-won fixes. Recorded so we don't
re-learn them the hard way, and so the "why is it built this way?" answers live
somewhere. Roughly chronological within the last ~8 days.

## Infra / Fleet ops (2026-07-20 — the big day)
<!-- NB: this is the *interim* SSH+CI control plane, NOT Nops. Nops = the
nostr-native ops concept (nact/docs/nops.md): server-as-identity, ops as
scoped grants. What we did here is the proto over the "wrong transport." -->


- **firewalld melted Docker.** A stale `--permanent --direct` rule wedged
  firewalld into FAILED state; a reload flushed Docker's iptables chains
  (`DOCKER-FORWARD` missing) → bunker 502 → Docker daemon wouldn't even boot
  (`INVALID_ZONE: docker`). Fix: `systemctl disable --now firewalld` →
  `nft flush ruleset` → `systemctl start docker` → `compose down/up` to rebuild
  stale networks. **Lesson: never run firewalld on a Docker host.**
- **The "document.txt" / "Key.text" bunker scare.** `bunker.nave.pub` handed the
  phone a text download instead of the app. Not a leaked key — the front Caddy's
  `host.docker.internal:8080` hop was flapping through the broken firewall; a
  Caddy error body the browser mislabeled. Real fix came with the firewalld purge.
- **Bunker looked "down" but wasn't.** Repeated 502s were the *container* down,
  not a firewall — and the earlier "`:8080` sealed (timeout)" probe reading was a
  **false positive** (container down ≠ firewalled). `:8080` was actually open to
  the world until the on-box firewall landed.
- **The shared-network detour.** First fix attempt for the flapping proxy was a
  shared docker network (`naveedge`); `docker network create` failed
  (`iptables: No chain…`) because the chains were already wiped. Reverted — a
  shared net can't help when the chains themselves are gone.
- **SSH self-inflicted wounds:** SELinux mislabel on a fresh `authorized_keys`
  (needs `restorecon`); fail2ban banned James's own IP (maxretry too tight →
  now 10/15m); a `cloud-init` drop-in silently re-enabling `PasswordAuthentication`
  (the lock step now seds `sshd_config.d/*` and checks `sshd -T`).
- **DOCKER-USER guard bug.** First firewall build checked for a `-j RETURN` rule
  Docker 29 doesn't pre-seed, so the `:8080` seal silently skipped while printing
  "sealed." Fixed to guard on chain existence.
- **zsh comment gotcha (×2).** Mac's zsh doesn't treat `#` as a comment by default
  → pasted command blocks with inline comments errored (`cat: #: No such file`).
  Fix: `setopt interactive_comments` or comment-free blocks.
- **Secrets in the wrong repo.** `WARM_SSH_*` were put in the *warm.contact* repo,
  but the workflow lives in `nave.pub` — Actions secrets are per-repo, so it read
  empty (`missing server host`). (The `H0ST` vs `HOST` red herring along the way.)

## Identity / bunker

- **Which nsec goes in the bunker?** Long back-and-forth resolved: the bunker
  holds **`jaf@dequalsf.com`** (the sovereign Director), because everything in
  Nact and Nvoy chains up to him. A considered exception to "never put a key on a
  box" — a dedicated hardened bunker ≠ the agent box.
- **A leaked `bunker://…secret=…`** was pasted mid-debug → treated as **burned**;
  connections re-minted from the console.
- **Operator key churn** — minted, lost, re-minted
  (`npub15a6ycljnfyxuhnxjp2wdv08umpr573fkss0g0h8eaxzlypvmh05sn47lel`).
- **Bunker NIP-46 relays** flapping on public relays looked alarming; turned out
  to be benign re-subscribe log noise — the relays themselves were fine.

## Product / app

- **Luke's approvals stopped posting.** Root cause chain: luke-brain imported
  `nact-resolve.mjs` but the Dockerfile COPY'd files individually and missed it →
  crash-loop; then `max_tokens=1400` truncated the JSON; then no `setWebhook` was
  ever registered after a bot/token churn. Fixes: `COPY nact-resolve.mjs`,
  max_tokens 4000 + tolerant parse, boot-time `registerWebhook()` with retry.
- **Nactor broker crash-loop** (missing `ws` dep).
- **warm.contact avatar** — rebuilt from a placeholder seal to their actual
  wood-burning-stove brand icon.
- **Caddy `--watch` broke 443** on the relay box → reverted to image default.

## Meta

- **Docker on warm.contact?** Considered, declined: 1 GB box, single app, native
  Caddy already there — Docker's daemon would eat scarce RAM for no gain.
- **Naming:** **Nfra** = the sovereign substrate (boxes/keys/relay/bunker);
  **Nest** the poetic alt. The interim SSH+CI control plane is just "fleet ops."
  **Nops** is reserved for its real meaning — the *nostr-native* server-ops
  concept (`nact/docs/nops.md`), not what we ran over GitHub Actions. No
  per-subdomain repos.
