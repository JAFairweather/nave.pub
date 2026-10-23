// drift-json.test.mjs — the drift report's two outputs must agree, and the served one must not leak.
//
//   node bin/drift-json.test.mjs
//
// WHY THIS EXISTS. `nave-drift --write-report` now writes the same run twice: `design/DRIFT.md` for a
// human reading the repo, and `design/drift.json` for `/drift` to render. Two representations of one
// fact is exactly the condition this detector exists to catch — so the detector's own outputs get
// checked against each other, or the tool that reports drift becomes a source of it.
//
// The second guard is disclosure. `drift.json` is served by `file_server` off the public site, and
// the generator builds it from a run that knows absolute paths for thirteen clones. One careless
// field and the fleet's filesystem layout is a GET away. Asserted rather than trusted, because a leak
// is invisible in review — it looks like a helpful field.

import assert from 'node:assert'
import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'

const HUB = join(dirname(fileURLToPath(import.meta.url)), '..')
let pass = 0, fail = 0
const t = (name, fn) => {
  try { fn(); console.log(`ok   — ${name}`); pass++ }
  catch (e) { console.log(`FAIL — ${name}\n       ${e.message}`); fail++ }
}

const jsonPath = join(HUB, 'design/drift.json')
const mdPath = join(HUB, 'design/DRIFT.md')

t('the served report exists — /drift has nothing to render without it', () => {
  assert.ok(existsSync(jsonPath), 'design/drift.json is missing; run: node bin/nave-drift --write-report')
})

const report = JSON.parse(readFileSync(jsonPath, 'utf8'))
const raw = readFileSync(jsonPath, 'utf8')

t('it declares a version the page can refuse', () => {
  // The page hard-refuses anything but v:1 and says so. That is only safe if the version is really here.
  assert.equal(report.v, 1)
})

t('it carries a FULL timestamp, not a date', () => {
  // The page's whole job is to say how old the answer is. A date-only stamp cannot distinguish a run
  // from four minutes ago from one from eleven hours and four merges ago.
  assert.match(String(report.generated_at), /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
  assert.ok(!isNaN(new Date(report.generated_at)), 'and it must parse')
})

t('NO FILESYSTEM PATH REACHES THE SERVED FILE', () => {
  // Absolute paths, home directories, and the deploy root. The generator has all three in scope.
  for (const leak of ['/Users/', '/home/', '/srv/', '/etc/', '/private/', 'C:\\'])
    assert.ok(!raw.includes(leak), `design/drift.json contains ${leak}`)
  for (const field of ['root', 'hub', 'cwd', 'path'])
    assert.ok(!(field in report), `top-level "${field}" is a disclosure surface, not a report field`)
})

t('every row is one of the five verdicts, and nothing else', () => {
  const VERDICTS = new Set(['ok', 'stale', 'diverged', 'not adopted', 'missing'])
  assert.ok(Array.isArray(report.rows) && report.rows.length > 0, 'no rows')
  for (const r of report.rows) {
    assert.ok(VERDICTS.has(r.verdict), `unknown verdict ${JSON.stringify(r.verdict)}`)
    for (const k of ['artifact', 'repo', 'detail']) assert.equal(typeof r[k], 'string', `row.${k}`)
  }
})

t('the totals are counted from the rows, not asserted beside them', () => {
  // A hand-maintained count beside a list is the same defect as a restated suite count: it goes stale
  // silently, and the page renders the stale number as the verdict.
  const counted = {}
  for (const r of report.rows) counted[r.verdict] = (counted[r.verdict] || 0) + 1
  for (const [k, v] of Object.entries(report.totals))
    assert.equal(v, counted[k] || 0, `totals.${k} says ${v}, rows say ${counted[k] || 0}`)
})

t('THE TWO OUTPUTS OF ONE RUN AGREE — the report and the page cannot diverge', () => {
  assert.ok(existsSync(mdPath), 'design/DRIFT.md is missing')
  const md = readFileSync(mdPath, 'utf8')
  const bodyRows = md.split('\n').filter(l => /^\| `/.test(l))
  assert.equal(bodyRows.length, report.rows.length,
    `DRIFT.md has ${bodyRows.length} rows, drift.json has ${report.rows.length} — they came from one run`)
  // And the summary line the human reads must match the numbers the page renders.
  const summary = md.match(/^(\d+) ok · (\d+) stale · (\d+) diverged · (\d+) not adopted · (\d+) missing$/m)
  assert.ok(summary, 'DRIFT.md has no summary line to compare against')
  const [, ok_, stale, diverged, notAdopted, missing] = summary.map(Number)
  assert.deepEqual(
    [ok_, stale, diverged, notAdopted, missing],
    [report.totals.ok, report.totals.stale, report.totals.diverged,
     report.totals['not adopted'], report.totals.missing],
    'the Markdown summary and the JSON totals disagree')
})

t('the page reads the JSON, and never parses the Markdown for data', () => {
  const page = readFileSync(join(HUB, 'drift.html'), 'utf8')
  assert.match(page, /fetch\(\s*['"]design\/drift\.json['"]/, 'drift.html must fetch design/drift.json')
  // It may LINK DRIFT.md for a human. It must not fetch it — that would be the prose-parsing this
  // whole file exists to prevent.
  assert.ok(!/fetch\(\s*['"][^'"]*DRIFT\.md/.test(page), 'drift.html fetches DRIFT.md as data')
})

t('the page refuses to present a stale snapshot as a live answer', () => {
  // Whitespace-tolerant: this copy is indented inside template literals and wraps mid-sentence, so a
  // literal-space match would make this a formatting test. The first version of this assertion failed
  // on `not\n        the same as` — correct copy, wrong regex.
  const page = readFileSync(join(HUB, 'drift.html'), 'utf8').replace(/\s+/g, ' ')
  // The three properties that make this page honest rather than a green tick. Pinned as prose a later
  // change has to argue with, the way the console pins its own judgement calls.
  assert.match(page, /not a live check/i, 'must say it is not a live check')
  assert.match(page, /too old to trust/i, 'must demote an aged report rather than render it clean')
  assert.match(page, /not the same as/i, 'an unreachable report must name the conclusion it is refusing')
  assert.match(page, /24 \* 3600 \* 1000/, 'the demotion threshold must be in the page, not implied')
})

console.log(`\n${pass}/${pass + fail} passed`)
process.exit(fail ? 1 : 0)
