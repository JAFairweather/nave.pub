// The provenance-stamp comparator — fixtures per case, because every defect in this tool so far has been
// a comparison rule that looked right and was wrong on real files.
//
//   node bin/stamp.test.mjs
//
// WHY THIS EXISTS (nave.pub#120). The gate's first real run in production reported nvoy's titlebar as
// `diverged` when the file was byte-identical to the hub and correctly stamped with the hub's own current
// hash. `hashFile` dropped exactly ONE line; `nvoy/bin/sync-vendor.mjs` writes TWO — the hash line and a
// DO-NOT-EDIT line — so one stamp line survived into the body hash and the comparison could never match.
//
// A false `diverged` is the worst output this tool has. It is an AD-11 accusation — a shared component was
// forked and nobody recorded it — and it is the verdict Wave 5's flip will FAIL A DEPLOY on. A gate that
// cries fork on correctly-vendored files is one people learn to ignore, and then it protects nothing.
//
// COUNTING WAS ALSO UNSAFE IN THE OTHER DIRECTION: the hub file carries no stamp at all, so dropping its
// first line silently discarded a real line of code from the baseline. Both directions are fixtured here.
//
// I attempted this fix once before and made it worse — 3 diverged became 5 — because changing how a body
// is hashed invalidates every recorded baseline at once. That is why the rule, the manifest key and both
// baselines move in ONE commit, and why this suite exists to prove the rule before any baseline is
// re-recorded.

import assert from 'node:assert'
import { stripStamp, isStamped } from './stamp.mjs'

let pass = 0, fail = 0
const t = (name, fn) => {
  try { fn(); console.log(`ok   — ${name}`); pass++ }
  catch (e) { console.log(`FAIL — ${name}\n       ${e.message}`); fail++ }
}

const BODY = "export function renderTitlebar(sel, opts) {\n  return 1\n}\n"

// ── the case that broke production: a TWO-line stamp ────────────────────────
t('a two-line stamp is stripped whole — the shape sync-vendor actually writes', () => {
  const stamped = '// vendored: components/nave-titlebar.mjs @ sha256:61a7e31cda51c2a1 — nave.pub@main\n'
    + '// DO NOT EDIT. Change it in nave.pub and re-run: npm run sync-vendor\n' + BODY
  assert.equal(stripStamp(stamped), BODY, 'both stamp lines must go, or the bodies can never match')
})
t('a longer stamp is stripped whole too — the count is not the rule', () => {
  // EVERY line must carry a marker. Discovered by this suite: a stamp I wrote earlier today had a third,
  // purely editorial line ("Exports NAVE_PLANES — …") with no marker in it, so the parser stopped there and
  // my own copies would still have read as diverged. The fix is at the SOURCE, not in the parser: a stamp
  // is something we write, so it must be self-identifying rather than something a regex has to guess at.
  // Widening the pattern to swallow any leading comment would strip a file's real header — and since the
  // hub file keeps its header, that would put the two bodies back out of sync.
  const stamped = '// vendored: x @ sha256:abc — nave.pub@main\n'
    + '// DO NOT EDIT. Change it in nave.pub and re-vendor.\n'
    + '// vendored copies must keep every stamp line marked, or the parser stops early.\n' + BODY
  assert.equal(stripStamp(stamped), BODY)
})
t('an unmarked line ENDS the stamp — the parser never guesses past what it was told', () => {
  const src = '// vendored: x @ sha256:abc — nave.pub@main\n// a friendly aside\n' + BODY
  assert.equal(stripStamp(src), '// a friendly aside\n' + BODY,
    'better to leave a line in and report a difference than to strip real code')
})
t('a one-line stamp still works — the old shape must not regress', () => {
  assert.equal(stripStamp('// vendored from JAFairweather/nave.pub @ abc123 — do not edit\n' + BODY), BODY)
})

// ── the other direction: the HUB file has no stamp ─────────────────────────
t('an UNSTAMPED file is returned untouched — no real code is discarded', () => {
  // The old rule dropped the hub file's first line, silently removing a line of code from the baseline.
  assert.equal(stripStamp(BODY), BODY)
})
t('a leading ordinary comment is NOT a stamp — only provenance markers count', () => {
  const src = '// renderTitlebar — the shared identity bar.\n' + BODY
  assert.equal(stripStamp(src), src, 'a normal header comment is part of the file')
})
t('a stamp-looking line in the MIDDLE of a file is left alone', () => {
  const src = BODY + '// DO NOT EDIT below this point\nconst x = 1\n'
  assert.equal(stripStamp(src), src, 'only a LEADING block is a stamp')
})

// ── the property that actually matters ────────────────────────────────────
t('THE INVARIANT: hub and stamped copy reduce to the SAME body', () => {
  // This single equality is the whole point of the tool. If it fails, every consumer reads as diverged.
  const copy = '// vendored: x @ sha256:deadbeef — nave.pub@main\n// DO NOT EDIT.\n' + BODY
  assert.equal(stripStamp(copy), stripStamp(BODY))
})
t('…and a REAL fork still differs, so the fix does not blind the detector', () => {
  const forked = '// vendored: x @ sha256:deadbeef — nave.pub@main\n// DO NOT EDIT.\n'
    + BODY.replace('return 1', 'return 2')
  assert.notEqual(stripStamp(forked), stripStamp(BODY), 'a genuine edit must still register')
})

// ── the manifest key ──────────────────────────────────────────────────────
t('the new key `stamped` is read', () => assert.equal(isStamped({ stamped: true }), true))
t('the LEGACY key is still honoured, so an un-migrated manifest does not flip the fleet', () => {
  // Ignoring it would make every stamped consumer read as unstamped — i.e. report the whole fleet as
  // diverged in one commit, which is exactly the failure this fix is for.
  assert.equal(isStamped({ skipFirstLine: true }), true)
})
t('the new key wins when both are present', () => {
  assert.equal(isStamped({ stamped: false, skipFirstLine: true }), false)
})
t('absent means unstamped', () => {
  assert.equal(isStamped({}), false)
  assert.equal(isStamped(undefined), false)
})

// ── degenerate input must not throw inside a deploy gate ──────────────────
t('empty and stamp-only files do not throw', () => {
  assert.equal(stripStamp(''), '')
  assert.equal(stripStamp('// vendored: x\n'), '')
})
t('CRLF line endings are handled — a Windows-authored copy is not a fork', () => {
  const copy = '// vendored: x @ sha256:abc — nave.pub@main\r\n// DO NOT EDIT.\r\n' + BODY
  assert.equal(stripStamp(copy).replace(/\r/g, ''), BODY)
})

console.log(`\n${pass}/${pass + fail} passed`)
process.exit(fail ? 1 : 0)
