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
  "nherit:nherit"
  "nscope:nostr-scoped-data-grants"
  "luke:luke"                     # a service (built + proxied), not file-served
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

# --- Luke's secrets: decrypt SOPS ciphertext → the env the compose reads --
# Decrypt sites/luke/secrets.enc.env with the box's age key into ./luke.env
# (gitignored, root-only). Guarded: if SOPS or the encrypted file isn't set
# up, this is a no-op and the stack still comes up (luke env_file is
# required:false). See the luke repo's SECRETS.md.
if [ -f sites/luke/secrets.enc.env ] && command -v sops >/dev/null 2>&1; then
  if sops --input-type dotenv --output-type dotenv -d sites/luke/secrets.enc.env > luke.env; then
    chmod 600 luke.env
    echo "🔓 luke secrets decrypted → luke.env"
  else
    echo "⚠ luke secrets present but decrypt FAILED (age key missing?) — luke runs without env"
  fi
else
  echo "· luke secrets: SOPS/enc file not set up yet — skipping (see luke/SECRETS.md)"
fi

echo
echo "done. now: docker compose up -d --build"
