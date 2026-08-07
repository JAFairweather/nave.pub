// doc-drift.test.mjs — the known-drift page's citations must still resolve.
//
//   node bin/doc-drift.test.mjs
//
// WHAT THIS CHECKS, AND WHAT IT CANNOT.
//
// `docs/architecture/07-doc-drift.md` is the page that says, in its own words, where the docs disagree
// and which text to trust. It opens with "trust the rulings below" — which is a large thing to ask on
// the strength of a hand-maintained page dated 2026-07-25 that nothing has ever verified.
//
// This CANNOT check that a ruling is still true. Whether the on-box firewall is still primary, or which
// of two agents is "the drafting hand", is a judgement about the estate and not a property of a file.
// Claiming otherwise would be the worse failure: a green check that reads as "the rulings are correct"
// when it only ever meant "the page parses".
//
// What it CAN check is that every ruling still points at something. A ruling whose cited file has moved
// or been deleted is unverifiable — you cannot go and read the stale text it names — and that decays
// silently, because prose about a missing file looks exactly like prose about a present one. So:
// citations resolve, the one machine-checkable piece of evidence on the page is actually present, and
// the page is dated.
//
// The bare-name allowlist below is the honest record of an ambiguity in the page itself, not a way of
// making the check pass.

import assert from 'node:assert'
import { readFileSync, existsSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import { dirname, join, basename } from 'node:path'

const HUB = join(dirname(fileURLToPath(import.meta.url)), '..')
let pass = 0, fail = 0
const t = (name, fn) => {
  try { fn(); console.log(`ok   — ${name}`); pass++ }
  catch (e) { console.log(`FAIL — ${name}\n       ${e.message}`); fail++ }
}

const DOC = 'docs/architecture/07-doc-drift.md'
const src = readFileSync(join(HUB, DOC), 'utf8')

// Paths under another repo. This page deliberately reasons across the estate, and a hub checkout has
// no siblings — reporting them as missing would be reporting the checkout, not the docs.
const SIBLING = ['nact/', 'nvoy/', 'ngage/', 'waggle/', 'nostr-scoped-data-grants/']
// Bare filenames that belong to a sibling repo. Listed WITH THE REASON, because each one is a small
// ambiguity in the page — `SPEC.md` alone does not say whose spec it is, and line 82 has to spell out
// `nostr-scoped-data-grants/SPEC.md + SPEC-v2.md` to disambiguate the pair. Resolving them here rather
// than silently skipping unknown names keeps the check strict for everything else.
const FOREIGN_BARE = {
  'SPEC.md': 'the NIP-DA protocol spec in nostr-scoped-data-grants (see the table at the end of the page)',
  'SPEC-v2.md': 'ditto — the v2 protocol spec, cited beside it',
}

const tracked = new Set(
  execFileSync('git', ['-C', HUB, 'ls-files'], { encoding: 'utf8' }).split('\n').filter(Boolean))
const byBase = new Map()
for (const f of tracked) {
  const b = basename(f)
  if (!byBase.has(b)) byBase.set(b, [])
  byBase.get(b).push(f)
}

const cited = [...new Set([...src.matchAll(/`([A-Za-z0-9_./-]+\.(?:md|json|sh|mjs|css|html|yml))`/g)]
  .map(m => m[1]))].sort()

t('the page cites files at all — a parser that finds nothing passes everything', () => {
  assert.ok(cited.length >= 10, `only ${cited.length} citations found; the extractor has drifted`)
})

t('EVERY CITATION RESOLVES — a ruling pointing at a moved file cannot be checked by a reader', () => {
  const unresolved = []
  for (const p of cited) {
    if (SIBLING.some(s => p.startsWith(s))) continue          // another repo, absent by design
    if (tracked.has(p)) continue                              // exact
    if (byBase.has(basename(p))) continue                     // cited by name, lives somewhere here
    if (FOREIGN_BARE[basename(p)]) continue                   // known to be another repo's, with a reason
    unresolved.push(p)
  }
  assert.deepEqual(unresolved, [], `cited but nowhere in the repo: ${unresolved.join(', ')}`)
})

t('the allowlist has no dead entries — it must not outlive the ambiguity it records', () => {
  // An allowlist that keeps permitting something nobody cites any more is a rule with no subject, and
  // the next reader cannot tell whether it is load-bearing.
  const stale = Object.keys(FOREIGN_BARE).filter(b => !cited.some(p => basename(p) === b))
  assert.deepEqual(stale, [], `FOREIGN_BARE permits ${stale.join(', ')}, which the page no longer cites`)
})

t('ruling 2\'s evidence is actually in the file it names', () => {
  // The page's one fully machine-checkable claim: nave.pub#37 is complete because
  // deploy/relay/allowlist.json carries recipientKinds [1059]. If that is no longer true the ruling is
  // wrong, not merely stale — and this is the only ruling where a test can say so.
  const p = join(HUB, 'deploy/relay/allowlist.json')
  assert.ok(existsSync(p), 'deploy/relay/allowlist.json is gone; ruling 2 cites it as evidence')
  const allow = JSON.parse(readFileSync(p, 'utf8'))
  const kinds = JSON.stringify(allow)
  assert.match(kinds, /"recipientKinds"/, 'no recipientKinds key — ruling 2 claims one')
  assert.match(kinds, /1059/, 'recipientKinds no longer admits 1059 (gift wrap); ruling 2 is now false')
})

t('the page is dated, so a reader can weigh how old the rulings are', () => {
  assert.match(src, /20\d\d-\d\d-\d\d/, 'an undated drift page cannot be aged by the reader')
})

t('it still refuses to resolve what it cannot — the flagged ruling stays flagged', () => {
  // Ruling 3 says "Flagged for the Director; not resolved here." A later edit that quietly resolves an
  // open question by deleting the flag is the failure this page exists to prevent, one level up.
  assert.match(src.replace(/\s+/g, ' '), /not resolved here|Flagged for the Director/i,
    'the page no longer marks anything unresolved; check that it was decided, not dropped')
})

console.log(`\n${pass}/${pass + fail} passed`)
process.exit(fail ? 1 : 0)
