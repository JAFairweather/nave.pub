// login-lockstep.test.mjs — the shared login component and its reference page stay in step.
//
//   node bin/login-lockstep.test.mjs
//
// WHY THIS EXISTS. `nave-login.mjs` has said "Keep in lock-step with components/nave-login.html" since
// it was written, and that file did not exist. Meanwhile the component is adopted by ZERO apps, and
// every app still carries a bespoke sign-in gate — the exact drift the shared surface was built to
// end. A component nobody has rendered is a component nobody has checked.
//
// So: the page must render every branch the component documents. Not because a demo is precious, but
// because the documented API is the only description of this component anyone has, and an option that
// no page passes is an option nobody has ever seen work.
//
// It also pins the one thing a login demo must never do — appear to sign in. A page that faked a
// successful sign-in would be a fabricated approval on the surface where a person decides whether to
// trust a key prompt, which is the AD-11 case at its sharpest.

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

const mjsPath = join(HUB, 'components/nave-login.mjs')
const htmlPath = join(HUB, 'components/nave-login.html')

t('the reference page the component names actually exists', () => {
  assert.ok(existsSync(htmlPath),
    'components/nave-login.mjs says "keep in lock-step with components/nave-login.html"')
})

const mjs = readFileSync(mjsPath, 'utf8')
const html = readFileSync(htmlPath, 'utf8')

t('EVERY documented option is exercised by the page', () => {
  // The options are read out of the component's own header block, so this cannot go stale by being
  // a hand-copied list here — add an option to the API and this check demands the page show it.
  const header = mjs.slice(0, mjs.indexOf('const STYLE_ID'))
  const documented = new Set()
  for (const m of header.matchAll(/^\/\/\s{4,}([a-zA-Z][a-zA-Z0-9]*),/gm)) documented.add(m[1])
  // The two multi-option lines carry more than one name before the comma-separated comment.
  for (const m of header.matchAll(/^\/\/\s{4,}([a-zA-Z][a-zA-Z0-9]*),\s*([a-zA-Z][a-zA-Z0-9]*),/gm)) {
    documented.add(m[1]); documented.add(m[2])
  }
  assert.ok(documented.size >= 10, `only found ${documented.size} documented options — parser drifted`)
  const missing = [...documented].filter(o => !new RegExp(`\\b${o}\\s*:`).test(html))
  assert.deepEqual(missing, [], `options no panel passes: ${missing.join(', ')}`)
})

t('both exported functions are used, not just imported', () => {
  const exported = [...mjs.matchAll(/^export function ([a-zA-Z]+)/gm)].map(m => m[1])
  assert.ok(exported.length >= 2, 'expected renderLogin and setLoginStatus')
  for (const fn of exported)
    assert.ok(new RegExp(`${fn}\\s*\\(`).test(html), `the page never calls ${fn}()`)
})

t('every callback branch is rendered somewhere — the option set IS the layout', () => {
  // renderLogin shows a control only when its callback is given, so a callback no panel passes is a
  // control this page has never drawn.
  for (const cb of ['onExtension', 'onBunker', 'onNostrConnect', 'onLocal'])
    assert.ok(new RegExp(`${cb}\\s*:`).test(html), `no panel supplies ${cb}, so its control is unrendered`)
})

t('the no-extension branch is shown, not just the happy path', () => {
  assert.match(html, /hasExtension:\s*false/,
    'the most common first visit has no NIP-07 signer; that layout must be on the page')
})

t('the error state is rendered, not only described', () => {
  assert.match(html, /setLoginStatus\([^)]*,\s*['"]error['"]\s*\)/,
    'the page must actually drive the error kind')
})

t('THE PAGE NEVER APPEARS TO SIGN ANYTHING', () => {
  const flat = html.replace(/\s+/g, ' ')
  assert.match(flat, /Nothing on this page signs anything|nothing was signed/i,
    'a reference login page must say plainly that it signs nothing')
  // No real signer may be touched. `window.nostr` is named in prose describing what a callback WOULD
  // do; calling it is what is forbidden.
  assert.ok(!/window\.nostr\s*\.\s*(signEvent|getPublicKey|nip04|nip44)/.test(html),
    'the demo calls a real signer method')
  assert.ok(!/localStorage\.setItem|sessionStorage\.setItem/.test(html),
    'the demo persists something; a reference page must leave no state behind')
})

t('it links tokens rather than vendoring them — a hub page must not become a copy', () => {
  assert.match(html, /href="\.\.\/design\/tokens\.css"/,
    'a vendored token copy inside the hub is a copy the drift detector then has to check')
})

console.log(`\n${pass}/${pass + fail} passed`)
process.exit(fail ? 1 : 0)
