#!/usr/bin/env bash
# drift-gate.test.sh — the deploy gate's branch logic, driven with a stubbed detector.
#
#   bin/drift-gate.test.sh
#
# WHY THIS EXISTS. On 2026-08-05 the drift gate shipped a line that assumed a host `node`. This box
# has none — every node process in the estate runs inside a container, and `node:20-alpine` appears
# in docker-compose.yml only as a build stage. So the detector exited 127, the `if` fell through to
# its else branch, and the deploy logged **"DIVERGENCE FOUND"** for a check that had never started.
# A gate that manufactures a verdict is worse than no gate, because the log then reads as evidence.
#
# A second defect was found while fixing the first, and only by running the logic: `sites.sh` is
# `set -euo pipefail`, so an assignment whose command substitution exits nonzero aborts the script
# AT THAT LINE. The unverified branch was unreachable dead code, and the deploy would have died with
# no message at all.
#
# Both are branch-selection bugs in shell, invisible to `bash -n` and to any amount of reading. So
# the logic is extracted verbatim from deploy/sites.sh and driven with a stub, under the same
# `set -euo pipefail` the deploy uses. Extracting rather than duplicating is the point: a copy of
# the logic would drift from the original and pass while production failed.
#
# The invariant under test, in one sentence: THE GATE MUST NEVER REPORT A VERDICT IT DID NOT GET.
# `unverified` is distinct from `clean` and distinct from `diverged`, and it is a hard failure — for
# the same reason a missing executable is. Being unable to check is not permission.

set -uo pipefail
SITES="${1:-$(cd "$(dirname "$0")/.." && pwd)/deploy/sites.sh}"
[ -f "$SITES" ] || { echo "no such file: $SITES" >&2; exit 2; }

BODY=$(mktemp); CASE=$(mktemp); OUT=$(mktemp)
trap 'rm -f "$BODY" "$CASE" "$OUT"' EXIT

# From the `set +e` guard through the second `fi` — the sentinel check and the verdict branches.
awk '/^set \+e$/{f=1} f{print} f&&/^fi$/{n++; if(n==2) exit}' "$SITES" > "$BODY"
[ "$(wc -l < "$BODY")" -gt 20 ] || { echo "extraction failed — the gate's shape in sites.sh changed; fix this extractor rather than deleting the test" >&2; exit 2; }

pass=0; fail=0
expect() { # name stub_out stub_rc enforce want_exit want_word
  cat > "$CASE" <<EOF
set -euo pipefail
drift_run() { printf '%s\n' "\$STUB_OUT"; return "\$STUB_RC"; }
$(cat "$BODY")
EOF
  STUB_OUT="$2" STUB_RC="$3" NAVE_DRIFT_ENFORCE="$4" bash "$CASE" >"$OUT" 2>&1
  local got=$? word
  word=$(grep -oE 'drift gate: clean|NOT ENFORCED|UNVERIFIED|drift gate FAILED' "$OUT" | head -1)
  if [ "$got" = "$5" ] && [ "$word" = "$6" ]; then
    printf 'ok   — %-42s exit=%s  %s\n' "$1" "$got" "$word"; pass=$((pass+1))
  else
    printf 'FAIL — %-42s exit=%s (want %s)  said=%s (want %s)\n' "$1" "$got" "$5" "${word:-<nothing>}" "$6"; fail=$((fail+1))
  fi
}

SOK='nave-drift: complete — 8 artifact(s) checked, verdict ok'
SDV='nave-drift: complete — 8 artifact(s) checked, verdict diverged'

# The detector ran to completion: its exit status is a real verdict and is honoured.
expect 'ran, clean'                        "$SOK" 0   0 0 'drift gate: clean'
# ENFORCEMENT IS NOW THE DEFAULT (Wave 5), so the unset case must STOP the deploy. Passing an empty
# string for the env var exercises exactly that: `${NAVE_DRIFT_ENFORCE:-1}` treats unset and empty alike.
expect 'ran, diverged — DEFAULT stops the deploy' "$SDV" 1  ''  1 'drift gate FAILED'
expect 'ran, diverged — ENFORCE=1 stops'          "$SDV" 1  1   1 'drift gate FAILED'
# Opting OUT is still possible for one deploy, and must still say so loudly. It is an opt-out rather than
# an opt-in now: the default should be the safe one, and someone suppressing a fork should have to say so.
expect 'ran, diverged — ENFORCE=0 reports only'   "$SDV" 1  0   0 'NOT ENFORCED'

# The detector did NOT run to completion. Every one of these is unverified, never a finding.
# 127 is the original bug; the others are the same class arriving by a different route.
expect 'node: command not found (the bug)'  'bash: node: command not found'  127 0 1 'UNVERIFIED'
expect 'docker image pull failed'           'Unable to find image'           125 0 1 'UNVERIFIED'
expect 'no runner at all'                   '(no host node and no docker)'   127 0 1 'UNVERIFIED'
# Partial output is the nastiest case: the table starts, so a reader skimming the log sees a real
# report — but the run died before the sentinel, so nothing may be concluded from it.
expect 'killed mid-run, partial table'      'nave-drift — hub /x
  ✓ tokens.css   nvoy   ok'                                                  137 0 1 'UNVERIFIED'
# And enforcement must not convert "could not check" into "found divergence" — the strictest
# setting is exactly where that confusion would be most damaging.
expect 'unverified under ENFORCE=1'         'bash: node: command not found'  127 1 1 'UNVERIFIED'
# An empty run is unverified too: silence is not a clean bill of health.
expect 'detector printed nothing'           ''                                 0 0 1 'UNVERIFIED'

echo; echo "$pass/$((pass + fail)) passed"
[ "$fail" -eq 0 ]
