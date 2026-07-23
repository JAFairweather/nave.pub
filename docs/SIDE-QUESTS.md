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

## The voice-and-sovereign-hand sessions (2026-07-21 → 23)

- **The stacked-rebase cascade ate P3–P6.** The P-series spec PRs were stacked;
  rebase-merging the base rewrote SHAs underneath the rest, and four "MERGED"
  PRs left main at P2. Nothing failed loudly — the tracker said done, the tree
  said otherwise. Recovered by `git rebase --onto origin/main` and re-landing
  P3–P6 as **one linear PR (spec #17)**. **Lessons: never stack rebase-merges;
  when a stack exists, merge the tip and close the rest as included; verify the
  TREE, not the PR badge.** (The same trap was dodged live on luke#14/#15.)
- **Silent push failures (×3).** Piping `git push` through `| tail -1` swallowed
  rejections; success was reported while commits sat local. Recovered by
  cherry-pick each time. **Lesson: never filter push output; check `status -sb`
  after.**
- **A local `main` tracking the wrong upstream.** `git pull` on luke's main was
  silently pulling `origin/widen-topics` — work "vanished" until the tracking
  ref was repointed. **Lesson: `git status -sb` shows the truth; `##
  main...origin/widen-topics` is a five-second catch.**
- **The missing-COPY crash-loop, again.** A new module (`post-format.mjs`)
  imported by shipped code wasn't COPY'd into the Dockerfile → deploy
  crash-looped luke in production (502). Same class repeated later in the brain
  workflow, which mounts `luke-brain.mjs` from the box but didn't mount its new
  imports — new brain code could pair with a stale module. **Lesson: a file must
  ship everywhere its importer ships; grep the Dockerfile AND the workflow
  mounts on every new module.**
- **The Nact stale-cache double incident.** "The app isn't updated" twice after
  green deploys — the box was right, the browser wasn't. (1) `nact.nave.pub`
  served **no Cache-Control at all**: it can't use the shared `(app)` snippet
  (needs its own handle blocks for `/api`), so it silently missed the fix from
  the 07-21 nvoy incident (nave.pub#51). (2) The header alone still wasn't
  enough: a fresh page paired with an **already-cached** bundle and died at
  module resolution — in the sign-in path. Only a changed URL reaches an entry
  a browser already holds → versioned module URLs in the importmap, bare
  specifiers keep the token in one block (nact#29). **Lesson: HTML + importmap
  + modules move as one unit; headers govern new responses only.**
- **A control plane that invented approvals.** Nact's app shipped fabricated
  pending approvals, history, channels, and a named Director as seed data —
  rendered identically to real state (nact#27). **Lesson: disconnected means
  empty; "demo mode" may never be indistinguishable from production. An
  approval queue that invents approvals is the one thing it must never do.**
- **The voice profile was guessed — twice.** The posting corpus described
  Luke as "wry, deferring" (his own charter says *"have a spine … a yes-man is
  worthless"*) and had the creed wrong (**discipline = freedom**, not "focus");
  an early Director profile was derived from an AI-assisted essay — a feedback
  loop. Both caught by James asking one question: *"what did you use as
  samples?"* Fixed by AD-9: evidence-only voice sources, structurally isolated
  per identity (luke#15). **Lesson: voice is data, not vibes — and never train
  a voice on your own generated output.**
- **An overclaiming draft.** A generated post said a review "tried to break it
  and mostly couldn't" — the review found six real weaknesses. Caught pre-post;
  "no overclaims about our own work" is now written into the shared steering.
- **`ssh-keygen` answered "y" wrote a private key named `y`** — into a PUBLIC
  repo's working tree, one `git add -A` from history. Confirmed authorized
  nowhere (all three boxes, GitHub, deploy keys) before deletion; broad ignore
  patterns added. Companion incident: a second identity's sealed env slipped
  past warm.contact's name-based ignore rule → **rule generalized to patterns**
  (`*.nave.env*`, `*.npub.txt`). **Lesson: guards must be patterns, not names.**
- **Ops-channel friction, mapped.** `ops.yml`'s custom-task input is `command`
  (not `cmd` — a wrong name 422s); the CI runner's SSH to the main box
  intermittently times out **while the box is healthy** (public 200s, port 22
  open) — retry or use the direct mgmt path; a remote `cat` of several files
  can trip the permission classifier where `scp` to a scratchpad reads clean.
- **SOPS, twice.** `--extract` syntax doesn't apply to dotenv files (use
  `--input-type dotenv` + grep); and the age key must be the one the file was
  sealed to — `age-keygen -y` against the recipient answers it in seconds.
- **Model-strength ≠ depth.** "Are the posts shallow because of the model?" —
  partly, but the fix that mattered was **feeding real material** (essay bodies,
  key-doc excerpts) and demanding a developed thought, plus the per-identity
  split. The strongest model on thin signals still writes headlines.

## Meta

- **Docker on warm.contact?** Considered, declined: 1 GB box, single app, native
  Caddy already there — Docker's daemon would eat scarce RAM for no gain.
- **Naming:** **Nfra** = the sovereign substrate (boxes/keys/relay/bunker);
  **Nest** the poetic alt. The interim SSH+CI control plane is just "fleet ops."
  **Nops** is reserved for its real meaning — the *nostr-native* server-ops
  concept (`nact/docs/nops.md`), not what we ran over GitHub Actions. No
  per-subdomain repos.
