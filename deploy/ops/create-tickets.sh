#!/usr/bin/env bash
# One-shot, idempotent ticket creator. Runs on a GitHub Actions runner (gh + jq
# preinstalled) with GH_TOKEN = a fine-grained PAT (Issues: read/write on the
# target repos). Dry-run by default; pass --apply to create for real.
#
#   sh create-tickets.sh docs/handoffs/tickets-2026-07-21.json [--apply]
#
# Idempotency: a ticket whose EXACT title already exists (open or closed) in
# its repo is skipped and its number reused for cross-references. Optional
# skip_if_search skips a ticket when a keyword search already hits (possible
# pre-existing issue under a different title) — those land in the summary for
# a human look. {{key}} placeholders in bodies resolve to owner/repo#number of
# earlier entries, so dependency links thread automatically.
set -euo pipefail

JSON="$1"
APPLY="${2:-}"
OWNER="jafairweather"
declare -A NUM

label_color() {
  case "$1" in
    P0) echo b60205 ;;
    P1) echo d93f0b ;;
    P2) echo fbca04 ;;
    P3) echo c5def5 ;;
    *)  echo ededed ;;
  esac
}

subst() {
  local body="$1" k
  for k in "${!NUM[@]}"; do body="${body//\{\{$k\}\}/${NUM[$k]}}"; done
  printf '%s' "$body"
}

say() { echo "$1" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"; }

say "## Ticket run ($( [ "$APPLY" = "--apply" ] && echo APPLY || echo DRY-RUN ))"

count=$(jq '.tickets | length' "$JSON")
for i in $(seq 0 $((count - 1))); do
  repo=$(jq -r ".tickets[$i].repo" "$JSON")
  key=$(jq -r ".tickets[$i].key" "$JSON")
  title=$(jq -r ".tickets[$i].title" "$JSON")
  labels=$(jq -r ".tickets[$i].labels | join(\",\")" "$JSON")
  skipq=$(jq -r ".tickets[$i].skip_if_search // empty" "$JSON")
  body=$(jq -r ".tickets[$i].body" "$JSON")

  existing=$(gh issue list -R "$OWNER/$repo" --state all --limit 200 --json number,title \
    | jq -r --arg t "$title" '.[] | select(.title == $t) | .number' | head -1)
  if [ -n "$existing" ]; then
    NUM[$key]="$OWNER/$repo#$existing"
    say "- SKIP (exists ${NUM[$key]}): $title"
    continue
  fi

  if [ -n "$skipq" ]; then
    hits=$(gh issue list -R "$OWNER/$repo" --state all --limit 100 --search "$skipq" --json number | jq length)
    if [ "$hits" -gt 0 ]; then
      say "- SKIP (search '$skipq' already hits $hits in $repo — review by hand): $title"
      continue
    fi
  fi

  body=$(subst "$body")
  if [ "$APPLY" = "--apply" ]; then
    IFS=',' read -ra LS <<< "$labels"
    for l in "${LS[@]}"; do
      gh label create -R "$OWNER/$repo" "$l" --color "$(label_color "$l")" --force >/dev/null 2>&1 || true
    done
    url=$(gh issue create -R "$OWNER/$repo" --title "$title" --body "$body" --label "$labels")
    NUM[$key]="$OWNER/$repo#${url##*/}"
    say "- CREATED ${NUM[$key]}: $title"
  else
    NUM[$key]="$OWNER/$repo#TBD"
    say "- would create [$repo] $title  (labels: $labels)"
  fi
done

ccount=$(jq '.comments | length' "$JSON")
for i in $(seq 0 $((ccount - 1))); do
  repo=$(jq -r ".comments[$i].repo" "$JSON")
  issue=$(jq -r ".comments[$i].issue" "$JSON")
  cbody=$(subst "$(jq -r ".comments[$i].body" "$JSON")")
  if ! gh issue view "$issue" -R "$OWNER/$repo" >/dev/null 2>&1; then
    say "- SKIP comment: $OWNER/$repo#$issue not found"
    continue
  fi
  if [ "$APPLY" = "--apply" ]; then
    gh issue comment "$issue" -R "$OWNER/$repo" --body "$cbody" >/dev/null
    say "- COMMENTED on $OWNER/$repo#$issue"
  else
    say "- would comment on $OWNER/$repo#$issue"
  fi
done

say ""
say "### Cross-reference map"
for k in "${!NUM[@]}"; do say "- $k → ${NUM[$k]}"; done
