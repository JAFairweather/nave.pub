// Nscribe — paste anything, get it back in your voice, send it to your desk to sign.
//
// v1 critical path is deliberately dependency-free (fetch + optional window.nostr),
// so the app can NEVER fail to load on a missing bundle. The re-voicing is a
// grant-to-app Anthropic call (your credential, in memory only). The Ngage handoff
// is copy-and-open — you sign on your own desk.
//
// TIER 2 (next increment, needs your live infra to verify): connect your jaf-quill
// bunker (vendor/nave-connect.mjs) and auto-publish the draft as a `draft:post/*`
// scope gift-wrapped to your npub (vendor/nipxx.mjs), pen-attested, so it lands on
// the desk without a paste. Left un-wired on purpose — untested relay/bunker crypto
// shipped as "working" is exactly what this estate refuses to do.

const $ = (id) => document.getElementById(id)
const els = {
  src: $('src'), out: $('out'), file: $('file'), register: $('register'), intent: $('intent'),
  revoice: $('revoice'), preview: $('preview'), toNgage: $('toNgage'), copy: $('copy'),
  st1: $('st1'), st2: $('st2'), srcCount: $('srcCount'), outCount: $('outCount'),
  signin: $('signin'), me: $('me'), akey: $('akey'), model: $('model'), dirnpub: $('dirnpub'),
  cfg: $('cfg'), openCfg: $('openCfg'), tmpl: $('tmpl'),
}

const words = (s) => (s.trim() ? s.trim().split(/\s+/).length : 0)
const setCount = (t, el) => { el.textContent = `${words(t)} words` }
els.src.addEventListener('input', () => setCount(els.src.value, els.srcCount))
els.out.addEventListener('input', () => { setCount(els.out.value, els.outCount); syncOutButtons() })
const status = (el, msg, cls = '') => { el.className = 'status ' + cls; el.textContent = msg }
const syncOutButtons = () => { const has = !!els.out.value.trim(); els.copy.disabled = !has; els.toNgage.disabled = !has }

// --- upload ---
els.file.addEventListener('change', async (e) => {
  const f = e.target.files?.[0]; if (!f) return
  const text = await f.text()
  els.src.value = text; setCount(text, els.srcCount)
  status(els.st1, `Loaded ${f.name} — ${words(text)} words.`, 'ok')
})

// --- the voice spec (your real steering file, vendored verbatim) ---
let VOICE = null
async function voiceSpec() {
  if (VOICE) return VOICE
  try {
    const r = await fetch('./voice/jaf-voice.md')
    if (!r.ok) throw new Error(r.status)
    VOICE = await r.text()
  } catch {
    VOICE = null   // file:// or missing — re-voice will explain; preview still shows the frame
  }
  return VOICE
}

// Register deltas — pulled straight from jaf.md's own rules, so each register
// obeys the measured differences (e.g. spaced hyphens are the EMAIL voice only).
const REGISTERS = {
  post:  'Register: a NOSTR POST. Short — let the object set the length; a 236-word piece that lands beats an 800-word one that explains. Open on the thing, keep the em-dashes, drop every hedge, back-load the point, close on a person or an instruction. Never a spaced hyphen, never a semicolon.',
  essay: 'Register: a LONG-FORM ESSAY. Build by extension, not argument — push one concrete object through domain after domain, one short paragraph each. No counterargument, no "on the other hand". Single-sentence paragraphs are the rhythm section. Never a spaced hyphen, never a semicolon, no section headers unless the source clearly has them.',
  email: 'Register: an EMAIL / note. Warm and brisk. This is the one register where a spaced hyphen is allowed (it is his email habit) — but still no semicolons. Frame asks as questions. Sign off warmly.',
  reply: 'Register: a short REPLY or reconnect note. One warm beat — acknowledge the person first, one light point, close on them. Never a spaced hyphen, never a semicolon.',
}

function buildSystem(spec, register) {
  const guard = spec
    ? spec
    : '(The voice steering file could not be loaded in this context — apply: open on a concrete object never a claim; build by extension not argument; em-dashes as the breath unit; no hedging of any kind; back-load the point; close short and warm on a person or an instruction; never summarize.)'
  return [
    'You re-voice text into James A. Fairweather\'s own hand. You are not writing from scratch and you are not editing for correctness — you are changing the VOICE and SHAPE while preserving his meaning and every fact.',
    '',
    'THE VOICE SPECIFICATION (measured from twelve essays he wrote by hand — obey it, do not paraphrase it):',
    guard,
    '',
    REGISTERS[register] || REGISTERS.post,
    '',
    'HARD RULES:',
    '- Preserve the source\'s facts, names, links, and intent exactly. Invent nothing. Drop nothing true.',
    '- Change the voice, not the substance. If the source hedges, un-hedge it — he overstates warmly.',
    '- Output ONLY the re-voiced piece. No preamble, no "here is", no notes, no options, no explanation of what you changed.',
    '- Never summarize or recap at the end — there is no argument to restate.',
  ].join('\n')
}

function buildUser(src, intent, register) {
  const ctx = intent.trim() ? `WHAT THIS IS (for steering, do not quote): ${intent.trim()}\n\n` : ''
  return `${ctx}SOURCE TEXT to re-voice as a ${register}:\n\n${src.trim()}`
}

// The actuator template — the exact shape scoped-agent-actions §II·5 specifies:
// surface is a PARAMETER, not a fork. This is what a wired jaf-quill drafter consumes.
function actuatorTemplate() {
  return {
    surface: 'revoice',
    register: els.register.value,
    target: els.dirnpub.value.trim() ? `ngage:${els.dirnpub.value.trim()}` : 'ngage:<your-npub>',
    content: els.src.value.trim().slice(0, 160) + (els.src.value.trim().length > 160 ? '…' : ''),
    context: els.intent.value.trim() || null,
  }
}

// --- the re-voice call (grant-to-app: your credential → Anthropic directly) ---
async function revoice() {
  const src = els.src.value.trim()
  if (!src) return status(els.st1, 'Paste or upload some text first.', 'err')
  const key = els.akey.value.trim()
  if (!key) { openSettings(); return status(els.st1, 'Add your Anthropic credential in settings to re-voice (grant-to-app — held in memory only).', 'err') }
  const spec = await voiceSpec()
  const register = els.register.value
  els.revoice.disabled = true
  status(els.st1, 'Re-voicing in your hand…')
  try {
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: JSON.stringify({
        model: els.model.value.trim() || 'claude-opus-4-8',
        max_tokens: 4096,
        system: buildSystem(spec, register),
        messages: [{ role: 'user', content: buildUser(src, els.intent.value, register) }],
      }),
    })
    if (!r.ok) {
      const body = await r.text().catch(() => '')
      throw new Error(`Anthropic ${r.status} — ${body.slice(0, 200)}`)
    }
    const data = await r.json()
    const text = (data.content || []).filter(b => b.type === 'text').map(b => b.text).join('\n').trim()
    if (!text) throw new Error('empty draft returned')
    els.out.value = text; setCount(text, els.outCount); syncOutButtons()
    status(els.st1, spec ? 'Drafted against your steering file. Read it, tweak it, then send it to your desk.' : 'Drafted (steering file not loaded — voice applied from built-in rules). Read closely.', 'ok')
  } catch (err) {
    status(els.st1, String(err.message || err), 'err')
  } finally {
    els.revoice.disabled = false
  }
}

// --- preview: the exact frame, no credential, no call ---
async function preview() {
  const spec = await voiceSpec()
  const register = els.register.value
  const sys = buildSystem(spec, register)
  const usr = buildUser(els.src.value || '(your text)', els.intent.value, register)
  openSettings()
  els.tmpl.textContent =
    'ACTUATOR TEMPLATE (scoped-agent-actions §II·5):\n' +
    JSON.stringify(actuatorTemplate(), null, 2) +
    '\n\n— — —\nSYSTEM PROMPT (voice spec ' + (spec ? 'loaded' : 'NOT loaded — built-in fallback') + '):\n' +
    sys.slice(0, 1400) + (sys.length > 1400 ? '\n…[voice spec continues]…' : '') +
    '\n\n— — —\nUSER MESSAGE:\n' + usr.slice(0, 800) + (usr.length > 800 ? '\n…' : '')
  status(els.st1, 'Preview shown in settings — this is exactly what a wired jaf-quill drafter receives.', 'ok')
}

// --- handoffs ---
async function copyOut() {
  try { await navigator.clipboard.writeText(els.out.value); status(els.st2, 'Copied.', 'ok') }
  catch { status(els.st2, 'Copy failed — select the text and copy manually.', 'err') }
}
async function toNgage() {
  // v1: copy the draft and open the desk, where you sign in your own hand.
  // (tier 2 auto-seals a draft:post/* scope here via your jaf-quill bunker.)
  try { await navigator.clipboard.writeText(els.out.value) } catch { /* non-fatal */ }
  window.open('https://ngage.nave.pub', '_blank', 'noopener')
  status(els.st2, 'Draft copied and Ngage opened — paste it on your desk and sign in your own hand. (Auto-seal via your jaf-quill bunker is the next increment.)', 'ok')
}

// --- sign-in (v1: optional convenience via NIP-07; no hard dependency) ---
async function signIn() {
  try {
    const n = window.nostr
    if (!n) { openSettings(); return status(els.st2, 'No extension found — you don\'t need to sign in for v1. Paste your credential in settings and re-voice; sign on your own desk in Ngage.') }
    if (typeof n.enable === 'function') { try { await n.enable() } catch { return status(els.st2, 'Sign-in declined.', 'err') } }
    const pk = await n.getPublicKey()
    els.me.innerHTML = `<span class="badge">extension</span><span class="pill" title="${pk}">${pk.slice(0, 8)}…${pk.slice(-4)}</span>`
    status(els.st2, 'Signed in. (v1 uses this only to remember who you are — the draft still goes to your Ngage desk.)', 'ok')
  } catch (e) { status(els.st2, String(e.message || e), 'err') }
}

function openSettings() { els.cfg.open = true }
els.openCfg.addEventListener('click', (e) => { e.preventDefault(); openSettings(); els.akey.focus() })
els.revoice.addEventListener('click', revoice)
els.preview.addEventListener('click', preview)
els.copy.addEventListener('click', copyOut)
els.toNgage.addEventListener('click', toNgage)
els.signin.addEventListener('click', signIn)

setCount('', els.srcCount); setCount('', els.outCount); syncOutButtons()
