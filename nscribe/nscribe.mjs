// Nscribe — paste anything, get it back in your voice, send it to your desk to sign.
//
// Nothing is typed (AD-2). You sign in with your own key; Nscribe reads YOUR OWN
// steering record — the kind-10440 Grant Index Ngage wrote when you trusted a pen
// and published steering — and DISCOVERS your drafting hand from it (emit.mjs
// discoverDrafters). No "Director" to configure, no drafter npub to paste: your
// pen is metadata, discovered from published state. It then drafts from its own
// credential:anthropic grant (readAnthropicCredential) and seals the result as a
// `draft:post/*` scope gift-wrapped to your npub (publishDraft), pen-attested, so
// it lands on your Ngage desk where only your signature publishes it.
//
// The re-voice path stays dependency-free (fetch + optional window.nostr) so the
// page can never fail to load; the discovery/seal path lazy-loads the heavier
// modules only when you sign in and connect.

import { renderTitlebar, updateTitlebar } from './components/nave-titlebar.mjs'

const $ = (id) => document.getElementById(id)
const els = {
  src: $('src'), out: $('out'), file: $('file'), register: $('register'), intent: $('intent'),
  revoice: $('revoice'), preview: $('preview'), toNgage: $('toNgage'), copy: $('copy'),
  st1: $('st1'), st2: $('st2'), srcCount: $('srcCount'), outCount: $('outCount'),
  akey: $('akey'), model: $('model'), dirnpub: $('dirnpub'),
  cfg: $('cfg'), openCfg: $('openCfg'), tmpl: $('tmpl'), penInfo: $('penInfo'),
  bunker: $('bunker'), connectBunker: $('connectBunker'), stBunker: $('stBunker'),
}

// Nscribe's seal — a quill nib in its ink accent (favicon = header logo = grid icon).
const QUILL_SEAL = `<svg viewBox="0 0 32 32" fill="none" aria-hidden="true">
  <circle cx="16" cy="16" r="15" fill="none" stroke="var(--accent)" stroke-width="1.5"/>
  <path d="M23 9 L13 21 L11 23 L10.2 20.4 Z" fill="none" stroke="var(--accent-bright)" stroke-width="1.4" stroke-linejoin="round"/>
  <path d="M13 21 L16 24" stroke="var(--accent-bright)" stroke-width="1.4" stroke-linecap="round"/>
</svg>`
let directorSigner = null
// Discovered from your own steering record after sign-in — never typed.
// { drafters: hex[], names: {hex: name|null}, npub: string } | null
let discovery = null

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

// --- the re-voice call --------------------------------------------------------
// Your discovered pen drafts from its OWN credential:anthropic grant; the draft
// then routes to your Ngage desk to sign. You never draft with your own key —
// the pen proposes, you approve. A pasted key is a fallback only.

// The discovered pen's display name (or a neutral fallback) for user-facing copy —
// so the app never hardcodes an identity it claims to discover.
const penName = () => (discovery?.drafters?.length && discovery.names[discovery.drafters[0]]) || 'your pen'

// Resolve the drafting credential — the discovered pen's grant first, paste as fallback.
async function resolveDraftKey() {
  if (bunkerSigner) {   // the Cloud Drafter is connected → read jaf-quill's grant
    const [{ readAnthropicCredential }, { LiveRelay }] = await Promise.all([
      import('./emit.mjs'), import('./vendor/liverelay.mjs'),
    ])
    const relay = new LiveRelay(RELAYS)
    try { return { key: await readAnthropicCredential(relay, bunkerSigner), via: 'grant' } }
    finally { try { relay.close?.() } catch { /* best effort */ } }
  }
  const pasted = els.akey.value.trim()
  if (pasted) return { key: pasted, via: 'paste' }
  return null
}

// Precise, per-failure diagnostics so a live miss says exactly which prereq is off.
function credErr(e) {
  const pen = penName()
  switch (e?.code) {
    case 'DECRYPT_REFUSED': return `Connected to ${pen}, but the bunker refused to decrypt the grant — the connection needs nip44Decrypt permission, not just draft-kind signing. Widen it in the bunker console.`
    case 'NO_GRANT': return `Connected to ${pen}, but no credential:anthropic grant reached this key. Issue it in the Nvoy console (＋ grant → ${pen} → credential:anthropic).${e.seen?.length ? ' Scopes it CAN see: ' + e.seen.join(', ') + '.' : ''}`
    case 'STALE': return `The credential:anthropic grant is stale/rotated — re-issue it to ${pen} in Nvoy.`
    case 'SHAPE': return 'Found the credential:anthropic grant, but its payload has no string .value — check how it was issued in Nvoy.'
    default: return `Reading ${pen}'s credential grant failed: ` + String(e?.message || e)
  }
}

async function callAnthropic(key, spec, register, src) {
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
  if (!r.ok) { const b = await r.text().catch(() => ''); throw new Error(`Anthropic ${r.status} — ${b.slice(0, 200)}`) }
  const data = await r.json()
  const text = (data.content || []).filter(b => b.type === 'text').map(b => b.text).join('\n').trim()
  if (!text) throw new Error('empty draft returned')
  return text
}

async function revoice() {
  const src = els.src.value.trim()
  if (!src) return status(els.st1, 'Paste or upload some text first.', 'err')
  els.revoice.disabled = true
  try {
    status(els.st1, bunkerSigner ? `${penName()} is reading its credential grant…` : 'Re-voicing…')
    let resolved
    try { resolved = await resolveDraftKey() }
    catch (e) { return status(els.st1, credErr(e), 'err') }
    if (!resolved) {
      openSettings()
      return status(els.st1, `Connect ${penName()} in settings — it drafts from its own credential:anthropic grant (no key to paste), then seals to your Ngage desk. A pasted key is a fallback only.`, 'err')
    }
    const spec = await voiceSpec()
    status(els.st1, resolved.via === 'grant' ? `Drafting as ${penName()} from the credential grant…` : 'Re-voicing (pasted-key fallback)…')
    const text = await callAnthropic(resolved.key, spec, els.register.value, src)
    els.out.value = text; setCount(text, els.outCount); syncOutButtons()
    const via = resolved.via === 'grant' ? `via ${penName()}'s credential grant — no key pasted` : 'via the pasted-key fallback'
    status(els.st1, `Drafted (${via})${spec ? ' against your steering file' : ''}. Read it, tweak it, then Send to Ngage to sign in your own hand.`, 'ok')
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
// The auto-seal path lazy-loads the heavier modules (nostr-tools + emit) only
// when used, so the dependency-free v1 path can never fail to load.
const RELAYS = ['wss://relay.nave.pub', 'wss://relay.damus.io', 'wss://nos.lol', 'wss://relay.primal.net']
let bunkerSigner = null

async function connectBunker() {
  const uri = els.bunker.value.trim()
  if (!uri) return status(els.stBunker, 'Paste the connection to your discovered drafter (draft kinds only).', 'err')
  status(els.stBunker, 'Connecting to your drafter…')
  try {
    const { nip46Signer } = await import('./vendor/nave-connect.mjs')
    // Persist the NIP-46 transport key (per bunker host) so a reload re-pairs to
    // the SAME session — a fresh key against a reused bunker:// looks like a
    // stranger with a spent invite and hangs. This is the client's own connection
    // identity, not any Nave key; standard NIP-46 client behaviour to persist it.
    let host = ''
    try { host = new URL(uri).hostname } catch { /* validated inside the signer */ }
    const ckKey = `nscribe:nip46-client:${host}`
    const clientSecret = (() => { try { return localStorage.getItem(ckKey) || undefined } catch { return undefined } })()
    const signer = nip46Signer(uri, { clientSecret })
    try { localStorage.setItem(ckKey, signer.clientSecretHex) } catch { /* private mode — session-only */ }
    const pk = await signer.getPublicKey()   // lazily performs the NIP-46 connect
    // Verify the connection lands on the pen your steering record names — a
    // bunker for some OTHER key is not your drafter, discovered or not.
    if (discovery?.drafters?.length && !discovery.drafters.includes(pk)) {
      bunkerSigner = null
      const { nip19 } = await import('nostr-tools')
      return status(els.stBunker,
        `That connection is ${nip19.npubEncode(pk).slice(0, 16)}… — not the pen your steering record names. ` +
        `Connect the discovered drafter, or re-check which key you trusted in Ngage.`, 'err')
    }
    bunkerSigner = signer
    els.toNgage.textContent = 'Seal to Ngage →'
    const nm = discovery?.names?.[pk] || 'your pen'
    status(els.stBunker, `Connected — ${nm} (${pk.slice(0, 8)}…${pk.slice(-4)})${discovery?.drafters?.includes(pk) ? ', verified against your steering record' : ''}. Re-voice now drafts from its credential grant; Send to Ngage auto-seals.`, 'ok')
  } catch (e) {
    bunkerSigner = null
    status(els.stBunker, 'Connect failed: ' + String(e.message || e), 'err')
  }
}

async function toNgage() {
  const text = els.out.value.trim()
  if (!text) return
  const recipient = els.dirnpub.value.trim()
  // Auto-seal: the connected pen pens the draft straight to your desk.
  if (bunkerSigner && recipient) {
    status(els.st2, 'Sealing the draft to your desk…')
    try {
      const [{ publishDraft }, { LiveRelay }] = await Promise.all([
        import('./emit.mjs'), import('./vendor/liverelay.mjs'),
      ])
      const hashtags = (text.match(/#(\w+)/g) || []).map(t => t.slice(1).toLowerCase())
      const relay = new LiveRelay(RELAYS)
      const res = await publishDraft(relay, bunkerSigner, recipient, { text, hashtags })
      try { relay.close?.() } catch { /* best effort */ }
      status(els.st2, `Sealed as ${res.scopeName}, gift-wrapped to your npub. Open Ngage and sign it in your own hand.`, 'ok')
      return
    } catch (e) {
      status(els.st2, 'Auto-seal failed (' + String(e.message || e) + ') — falling back to copy-and-open.', 'err')
      // fall through to the copy path
    }
  }
  // Fallback: copy the draft and open the desk, where you paste and sign.
  try { await navigator.clipboard.writeText(text) } catch { /* non-fatal */ }
  window.open('https://ngage.nave.pub', '_blank', 'noopener')
  if (!(bunkerSigner && recipient)) status(els.st2, 'Draft copied and Ngage opened — paste it and sign in your own hand. (Sign in and connect your discovered pen to auto-seal instead.)', 'ok')
}

// --- Sign in (Alby / your key) then DISCOVER your drafter (AD-2, AD-11) -------
// Sign in with your own key — you are the desk that approves. Then Nscribe reads
// your own steering record (the kind-10440 Grant Index Ngage wrote when you
// trusted a pen and published steering) and discovers your drafting hand from
// it: no npub typed, no "Director" to configure. nave-connect is lazy-loaded so
// the page can't fail to load on a bundle issue; the titlebar is dependency-free.
async function signIn() {
  try {
    const nc = await import('./vendor/nave-connect.mjs')
    let signer
    if (window.nostr) {
      signer = nc.nip07Signer()
    } else {
      const uri = prompt('No extension found. Paste a bunker:// or nostrconnect:// to sign in with your key:')
      if (!uri) return
      signer = nc.nip46Signer(uri)
    }
    const pk = await signer.getPublicKey()
    const { nip19 } = await import('nostr-tools')
    const npub = nip19.npubEncode(pk)
    directorSigner = signer
    els.dirnpub.value = npub   // you are the recipient / approver — always, never typed
    updateTitlebar('#titlebar', { npub, kind: signer.kind, onLogout: signOut, onSignIn: null })
    status(els.st2, 'Signed in. Reading your steering record to find your drafting hand…', 'ok')
    await discoverDrafter(signer, npub)
  } catch (e) { status(els.st2, 'Sign-in failed: ' + String(e.message || e), 'err') }
}

// Read your own Grant Index and surface the pen(s) Ngage recorded — nothing typed.
async function discoverDrafter(signer, npub) {
  els.penInfo.textContent = 'Discovering your drafting hand from your steering record…'
  try {
    const [{ discoverDrafters, resolveNames }, { LiveRelay }, { nip19 }] = await Promise.all([
      import('./emit.mjs'), import('./vendor/liverelay.mjs'), import('nostr-tools'),
    ])
    const relay = new LiveRelay(RELAYS)
    let drafters, names
    try {
      drafters = await discoverDrafters(relay, signer)
      names = await resolveNames(relay, drafters)
    } finally { try { relay.close?.() } catch { /* best effort */ } }
    discovery = { drafters, names, npub }
    if (!drafters.length) {
      els.penInfo.textContent =
        'No drafting pen found in your steering record yet. Trust your pen in Ngage → Settings → ' +
        'Trusted agents, and publish steering once. That write is what Nscribe reads here — then your ' +
        'drafter appears with nothing typed.'
      return
    }
    const label = drafters.map(pk => `${names[pk] || 'pen'} — ${nip19.npubEncode(pk)}`).join('\n')
    const primary = names[drafters[0]] || 'your pen'
    els.penInfo.textContent =
      `Your drafting hand (from your steering record — nothing typed):\n${label}\n\n` +
      `Connect ${primary} in settings to draft; the connection is verified against this discovered key.`
    // Prime the settings connection field with the discovered pen's name.
    els.bunker.placeholder = `bunker://… — the live connection to ${primary}. Leave blank to copy-and-open instead.`
  } catch (e) {
    els.penInfo.textContent = 'Could not read your steering record (' + String(e.message || e) + '). ' +
      'You can still connect a drafter manually in settings, or use the paste fallback.'
  }
}

function signOut() {
  directorSigner = null
  discovery = null
  els.penInfo.textContent = ''
  els.dirnpub.value = ''
  updateTitlebar('#titlebar', { npub: null, kind: null, onSignIn: signIn })
  status(els.st2, 'Signed out.', '')
}

function openSettings() { els.cfg.open = true }
els.openCfg.addEventListener('click', (e) => { e.preventDefault(); openSettings(); els.akey.focus() })
els.revoice.addEventListener('click', revoice)
els.preview.addEventListener('click', preview)
els.copy.addEventListener('click', copyOut)
els.toNgage.addEventListener('click', toNgage)
els.connectBunker.addEventListener('click', connectBunker)

// Mount the shared identity bar signed-out; sign-in swaps it to your pill.
renderTitlebar('#titlebar', {
  appName: 'Nscribe', tagline: 'say it in your hand', sealSvg: QUILL_SEAL,
  npub: null, onSignIn: signIn, signInLabel: 'Sign in',
})

setCount('', els.srcCount); setCount('', els.outCount); syncOutButtons()
