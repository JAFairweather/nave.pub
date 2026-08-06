// stamp.mjs — the provenance-stamp comparator, extracted so it can be tested (nave.pub#120).
//
// A vendored copy carries a stamp the hub file does not, so the two can only be compared body-to-body.
// The rule is MATCH THE STAMP, NEVER COUNT LINES.
//
// WHY: `hashFile` dropped exactly one line, and `nvoy/bin/sync-vendor.mjs` writes TWO — the hash line and
// a DO-NOT-EDIT line — so one stamp line survived into the body hash and the comparison could never match.
// The gate's first real run in production therefore reported nvoy's titlebar as `diverged` when the file
// was byte-identical to the hub and correctly stamped with the hub's own current hash.
//
// A false `diverged` is the worst output this tool has. It is an AD-11 accusation — a shared component was
// forked and nobody recorded it — and it is the verdict Wave 5's enforcement flip FAILS A DEPLOY on. A gate
// that cries fork on correct files is one people learn to ignore, and then it protects nothing.
//
// Counting was unsafe in the other direction too: the hub file has no stamp, so dropping its first line
// silently discarded a real line of code from the baseline it was computing.
//
// Extracted into its own module for one reason: `bin/nave-drift` is a script with side effects and cannot
// be imported, so the comparison rule could not be tested where it lived. Every defect in this tool so far
// has been a rule that looked right and was wrong on real files.

/**
 * A provenance-stamp line. Deliberately narrow — it must match what the vendoring scripts write and
 * nothing else, because a rule that also matched ordinary header comments would strip real code.
 */
const STAMP_LINE = /^\s*\/\/.*(?:vendored|VENDORED|DO NOT EDIT|do not edit)/

/**
 * Drop a LEADING run of stamp lines. A stamp-looking line in the middle of a file is left alone: only a
 * leading block is provenance, and `// DO NOT EDIT below this point` halfway down is ordinary prose.
 */
export function stripStamp(text) {
  const lines = String(text ?? '').split('\n')
  let i = 0
  while (i < lines.length && STAMP_LINE.test(lines[i])) i++
  return lines.slice(i).join('\n')
}

/**
 * Does this consumer's copy carry a stamp? Declared per consumer in VENDOR.json.
 *
 * The manifest key was `skipFirstLine`, which named an implementation (drop one line) rather than a fact
 * about the file (it is stamped) — and the implementation was wrong for any stamp longer than one line.
 * The old key is still honoured: ignoring it would read every stamped consumer as unstamped and report the
 * whole fleet as diverged in a single commit, which is precisely the failure this fix exists to remove.
 */
export const isStamped = (c) => c?.stamped ?? c?.skipFirstLine ?? false
