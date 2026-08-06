#!/usr/bin/env bash
# Sync every app/service repo onto the box so the platform can serve/build it.
# Clones (or fast-forwards) each into deploy/sites/<name>, which the caddy
# container mounts read-only at /srv/apps, and which the director/luke builds
# use as their contexts. Run on the box:
#
#   bash deploy/sites.sh && docker compose up -d --build
#
# Re-run any time to update to each repo's latest main.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p sites

# name : github repo (default branch = main for all)
apps=(
  "nave:nave.pub"                 # the hub — served at the apex (/srv/apps/nave)
  "noir:noir"                     # the game client + the Director build
  "nvelope:nvelope"
  "nontact:nontact"
  "notegate:notegate"
  "ntrigue:ntrigue"
  "nvoy:nvoy"
  "ngage:ngage"                   # sovereign drafts — review + sign in your own hand
  "nherit:nherit"
  "nscope:nostr-scoped-data-grants"
  "nact:nact"                     # the signature-gated agentic-actions library + landing
  "luke:luke"                     # a service (built + proxied), not file-served
  "waggle:waggle"                 # cloned ONLY to serve console/ — the bridge runs elsewhere
)

for pair in "${apps[@]}"; do
  name="${pair%%:*}"; repo="${pair##*:}"; dir="sites/$name"
  if [ -d "$dir/.git" ]; then
    echo "↻ $name — refreshing"
    git -C "$dir" fetch --depth 1 origin main
    git -C "$dir" reset --hard origin/main
  else
    echo "＋ $name — cloning $repo"
    git clone --depth 1 "https://github.com/JAFairweather/$repo" "$dir"
  fi
done

# --- Design-system drift gate (AD-12, #113) -------------------------------
# Placed HERE deliberately: after the complete clone/reset loop, and BEFORE secret
# generation or any build. It reads the trees Caddy actually mounts, so it inspects the
# real serving state rather than this checkout's copy of it.
#
# THIS GATE IS A DIAGNOSTIC, NOT AN ATOMICITY GUARANTEE — and the distinction is a
# required one (#115). `./sites` is a LIVE bind mount and the loop above promotes thirteen
# trees IN PLACE, one at a time, so production has already served a mixed snapshot by the
# time this runs. The gate can report that the serving state disagrees with itself; it
# cannot prevent that state having been served, and a mid-loop failure still leaves
# production half-promoted. Nothing here may be read as a claim that a deploy is atomic.
# That property arrives only when #115 stages the complete set outside the mounted tree
# and swaps the serving root after a successful stage, with rollback on failed activation.
#
# What it detects is UNRECORDED CROSS-REPO DIVERGENCE IN THE SERVING SNAPSHOT — not a
# box-local edit. The reset above just overwrote anything box-local, so a difference at
# this point means an app repo's own main has diverged from the hub's shared component
# without that being recorded in design/VENDOR.json.
#
# Fail-closed is the right DESTINATION for this: shipping a snapshot whose shared
# components disagree is how the console drift of 2026-07 reached production and
# "rendered perfectly, then failed at the moment someone tried to sign in."
#
# But it REPORTS ONLY until the fleet is clean, and that is deliberate. The fleet has
# two recorded divergences today (nact's --mono fallback, ngage's Courier/Georgia
# override) that predate this gate. Enforcing on the first commit would red the very
# next deploy for drift the gate did not cause — and it would break the rule this
# whole wave is built on: Wave 0 is strictly additive and must behave identically to
# today. A gate that blocks a deploy is not additive.
#
# Flip it with NAVE_DRIFT_ENFORCE=1, and make that the default in Wave 5 once nact
# and ngage are reconciled (ngage's is a real design decision — the "signed artifact"
# type exception — not a patch, so it lands in its own wave).
# THE GATE MUST RUN FROM THE SERVED SNAPSHOT, NOT FROM THIS CHECKOUT.
# `sites/nave` is the clone Caddy mounts at /srv/apps/nave; this script lives in the
# platform checkout, which is updated by a separate `git pull`. The two are normally the
# same commit and are not guaranteed to be — so running ../bin/nave-drift would hash
# THIS checkout's tokens.css and manifest while production serves sites/nave's. The gate
# could pass while the snapshot about to be served disagrees, which is precisely the
# failure it exists to catch. Invariant: every hash and manifest the gate uses comes from
# the same reset sites/* snapshot the build then serves.
#
# A missing executable is a HARD failure, never a skip. If the gate cannot run, the
# correct conclusion is "unverified", not "fine" — being unable to check is not
# permission. That is separate from the divergence policy below.
echo "→ design-system drift gate"
if [ ! -f sites/nave/bin/nave-drift ]; then
  echo "  ✗ sites/nave/bin/nave-drift is absent from the freshly reset snapshot."
  echo "    The gate cannot verify what is about to be served. Stopping."
  exit 1
fi
# THIS HOST HAS NO `node`. Every node process in this estate runs inside a container —
# `node:20-alpine` appears in docker-compose.yml only as a BUILD STAGE — and line 98 of the
# first version of this gate was the sole place the deploy assumed a host interpreter. It
# exited 127, the `if` fell through to the else branch, and the deploy logged
# "DIVERGENCE FOUND" for a check that had never started. That is worse than no gate: it
# manufactured a verdict. So the runner is resolved explicitly, and a run that cannot start
# is reported as UNVERIFIED rather than as a finding.
drift_run() {
  if command -v node >/dev/null 2>&1; then
    node sites/nave/bin/nave-drift --root "$PWD/sites" --write-report
  elif command -v docker >/dev/null 2>&1; then
    # The executable and every hash still come from the served snapshot — only the
    # interpreter is borrowed. `sites` is mounted rw solely so --write-report can land
    # design/DRIFT.md in sites/nave, the same tree this script just hard-reset.
    docker run --rm -v "$PWD/sites:/w/sites" -w /w node:20-alpine \
      node /w/sites/nave/bin/nave-drift --root /w/sites --write-report
  else
    echo "  (no host node and no docker — nothing can run the detector)"
    return 127
  fi
}
# `set -e` is on (line 10), and an assignment whose command substitution exits nonzero aborts the
# script AT THIS LINE — which would kill the deploy with no message and make every branch below
# unreachable, including the unverified one. The suspension is deliberate and minimal: this gate
# decides its own exits explicitly, a few lines down, with a reason attached.
set +e
DRIFT_OUT="$(drift_run 2>&1)"; DRIFT_RC=$?
set -e
printf '%s\n' "$DRIFT_OUT"

# REQUIRE THE COMPLETION SENTINEL BEFORE BELIEVING ANY VERDICT. Exit status alone cannot
# distinguish "ran and found divergence" (1) from "never started" (127 no interpreter, 125
# failed image pull, 137 OOM). The detector prints `nave-drift: complete —` as its last act;
# absent that line the correct conclusion is unverified, and unverified is a HARD failure for
# the same reason a missing executable is: being unable to check is not permission.
if ! printf '%s' "$DRIFT_OUT" | grep -q 'nave-drift: complete —'; then
  echo "  ✗ drift gate UNVERIFIED — the detector did not run to completion (exit $DRIFT_RC)."
  echo "    This is NOT a divergence finding and must not be read as one. Nothing was checked."
  echo "    Stopping before secrets and build. Fix the runner, do not skip the gate."
  exit 1
fi

# Divergence itself REPORTS ONLY until the fleet is clean, and that is deliberate: the
# fleet has two divergences that predate this gate (nact's dropped --mono fallback,
# ngage's Courier/Georgia override), and blocking on them would red a deploy for drift
# the gate did not cause. Wave 5 flips the default once those are reconciled.
if [ "$DRIFT_RC" -eq 0 ]; then
  echo "  drift gate: clean"
elif [ "${NAVE_DRIFT_ENFORCE:-0}" = "1" ]; then
  echo "  ✗ drift gate FAILED — stopping before secrets and build."
  echo "    A shared component diverges in the snapshot about to be served."
  echo "    Reconcile it, or re-record the baseline: node bin/nave-drift --baseline"
  exit 1
else
  # The verdict must be unmistakable in the deploy log. "REPORTING ONLY" was too soft: a
  # reader skimming a green deploy could take it for a passing check. NOT ENFORCED says
  # what actually happened — divergence was found and the deploy continued anyway. The
  # detector's own table is above this line, so every divergence is named, not counted.
  echo "  ⚠ drift gate: DIVERGENCE FOUND — NOT ENFORCED. The deploy is continuing."
  echo "    Every divergence is named in the table above and in design/DRIFT.md."
  echo "    This deploy serves a snapshot whose shared components disagree."
  echo "    Set NAVE_DRIFT_ENFORCE=1 to make this stop the deploy (Wave 5 default)."
fi

# --- Platform secrets: decrypt SOPS ciphertext → the env the compose reads --
# The nave-owned secret bundle lives in THIS repo at deploy/secrets/nave.enc.env
# (SOPS/age; the private key is box-only). It decrypts to ./nave.env — the full
# platform env only Nactor reads. The old Luke-repo ciphertext remains a
# migration fallback, but every consumer now reads the canonical nave env files.
# Guarded: if SOPS or the file isn't
# set up this is a no-op and the stack still comes up (env_files are
# required:false). See deploy/secrets/.sops.yaml.
SECRETS_SRC=""
if [ -f secrets/nave.enc.env ]; then SECRETS_SRC=secrets/nave.enc.env
elif [ -f sites/luke/secrets.enc.env ]; then SECRETS_SRC=sites/luke/secrets.enc.env; fi  # migration fallback
if [ -n "$SECRETS_SRC" ] && command -v sops >/dev/null 2>&1; then
  if sops --input-type dotenv --output-type dotenv -d "$SECRETS_SRC" > nave.env; then
    chmod 600 nave.env
    # Nact_jaf's carrier key (the Nact-Approvals identity) rides in a SEPARATE age
    # file, sealed workspace-side to the box's age PUBLIC key (no sops needed to
    # add it, no fragile transit). Decrypt with the same box age key and append to
    # nave.env BEFORE the consumer split, so nactor AND the beats (consumer copy)
    # can sign as it. Guarded: absent/failed → skipped, stack still comes up.
    if [ -f secrets/nactjaf.age ] && command -v age >/dev/null 2>&1; then
      AGEKEY="${SOPS_AGE_KEY_FILE:-/root/.config/sops/age/keys.txt}"
      if age -d -i "$AGEKEY" secrets/nactjaf.age >> nave.env 2>/dev/null; then
        echo "🔓 Nact_jaf carrier key (NACTJAF_NSEC) → nave.env"
      else echo "⚠ nactjaf.age present but age-decrypt failed (age key?)"; fi
    fi
    echo "🔓 platform secrets decrypted → nave.env from $SECRETS_SRC"

    # env-split: the CONSUMERS (luke service, brain) get a copy with the BROKERED
    # credentials stripped — those live only in Nactor (which reads the full
    # nave.env). Box-local + gitignored.
    grep -vE '^(ANTHROPIC_API_KEY|TELEGRAM_BOT_TOKEN|TELEGRAM_LUKE_BOT_TOKEN|GOOGLE_OAUTH_[A-Z_]+|GMAIL_APP_PASSWORD|OPENCLAW_GATEWAY_PASSWORD|NACTOR_NSEC|NACT_CHANNEL_NSEC|NACT_PROXY_TOKEN)=' nave.env > nave-consumer.env
    chmod 600 nave-consumer.env
    echo "🔓 consumer env (brokered creds stripped) → nave-consumer.env"
    # The engine's internal-client password: its env_file is openclaw.env (the
    # engine must NOT read the full env — env-split), so sync just this one var
    # across from the freshly decrypted root. SOPS stays the source of truth.
    if grep -q '^OPENCLAW_GATEWAY_PASSWORD=' nave.env; then
      touch openclaw.env
      { grep -vE '^OPENCLAW_GATEWAY_PASSWORD=' openclaw.env || true; grep '^OPENCLAW_GATEWAY_PASSWORD=' nave.env; } > openclaw.env.tmp
      mv openclaw.env.tmp openclaw.env && chmod 600 openclaw.env
      echo "🔓 engine gateway password synced → openclaw.env"
    fi
    # M7 — the nvoy-mcp service env: Nvoy's MCP server custodies Nactor's key
    # (NVOY_NSEC ← NACTOR_NSEC) and serves its credential scopes as MCP tools
    # (nact docs/migration-status-2026-07.md §5 M7). Generated fresh from the
    # bundle on every deploy — box-local + gitignored, like the consumer envs.
    # Falls back to nactor.env (the pre-SOPS mint location) so a box whose key
    # never moved into the bundle still generates correctly. SOPS stays the
    # durable home of NACTOR_NSEC either way — M7 moves which PROCESS reads
    # it, not where it durably lives (still one of the two sanctioned
    # bootstrap secrets).
    NVOY_KEY_SRC=""
    if grep -q '^NACTOR_NSEC=' nave.env; then NVOY_KEY_SRC=nave.env
    elif [ -f nactor.env ] && grep -q '^NACTOR_NSEC=' nactor.env; then NVOY_KEY_SRC=nactor.env; fi
    if [ -n "$NVOY_KEY_SRC" ]; then
      NVOY_RELAYS_VAL=$(grep '^LUKE_RELAYS=' nave.env | head -1 | cut -d= -f2-)
      { printf '# generated by sites.sh — nvoy-mcp custodies the Nactor key (M7); never commit\n'
        printf 'NVOY_NSEC=%s\n' "$(grep '^NACTOR_NSEC=' "$NVOY_KEY_SRC" | head -1 | cut -d= -f2-)"
        printf 'NVOY_RELAYS=%s\n' "${NVOY_RELAYS_VAL:-wss://relay.damus.io,wss://nos.lol,wss://relay.primal.net}"
      } > nvoy-mcp.env
      chmod 600 nvoy-mcp.env
      echo "🔓 nvoy-mcp env (NVOY_NSEC ← NACTOR_NSEC from $NVOY_KEY_SRC) → nvoy-mcp.env"
    else
      echo "⚠ NACTOR_NSEC found in neither nave.env nor nactor.env — nvoy-mcp.env not generated"
    fi
    # M7 cutover marker (.m7-mcp-transport, set by ops/m7-cutover.sh): once
    # custody has moved, every regeneration keeps NACTOR_NSEC OUT of the envs
    # Nactor reads — without this, the next deploy would resurrect the key
    # the cutover just removed. Reversible: the cutover's self-restore (or a
    # manual `rm .m7-mcp-transport`) brings the pre-M7 shape back on the next
    # sites.sh run. nactor.env is box-local and handled by the cutover script
    # itself, not here.
    if [ -f .m7-mcp-transport ]; then
      grep -vE '^NACTOR_NSEC=' nave.env > nave.env.tmp
      chmod 600 nave.env.tmp
      mv nave.env.tmp nave.env
      echo "🔒 M7 cutover in force — NACTOR_NSEC stripped from nave.env (custody: nvoy-mcp)"
    fi
  else
    echo "⚠ platform secrets present but decrypt FAILED (age key missing?) — services run without env"
  fi
else
  echo "· platform secrets: SOPS/enc file not set up yet — skipping (see deploy/secrets/.sops.yaml)"
fi

# The transition aliases are retired only after all tracked consumers moved to
# the canonical names. Keep cleanup idempotent so future deploys cannot revive
# stale plaintext copies left by an older release.
rm -f luke.env luke-consumer.env

echo
echo "done. now: docker compose up -d --build"
