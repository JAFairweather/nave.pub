// nscribe/emit.mjs — seal a re-voiced draft as a `draft:post/<id8>` scope and
// gift-wrap it to the Director's npub, so it lands on the Ngage desk pen-attested.
//
// The three ceremony functions (giftWrapWithSigner / publishScopeWithSigner /
// grantWithSigner) are lifted VERBATIM from ngage/steering.mjs — the same
// wire-tested, signer-driven counterparts to nipxx.giftWrap / publishScope /
// grant that Ngage already ships. Only `publishDraft` (the draft:post payload +
// scopeName glue) and `newScopeId` are new here. Because the pen is the seal
// author, signing with the jaf-quill bunker connection makes the desk read this
// as penned direct (ngage/drafts.mjs `pennedDraft`, author === publisher).

import { getEventHash, finalizeEvent, generateSecretKey, nip44, nip19 } from 'nostr-tools'
import { KIND_DATA_SET, KIND_GRANT, newScopeKey, receiveGrants, latestGrants, fetchScope,
         loadGrantIndex, fromIssuedEntry } from './vendor/nipxx.mjs'

let lastTs = 0
const now = () => (lastTs = Math.max(Math.floor(Date.now() / 1000), lastTs + 1))
const fuzz = () => now() - Math.floor(Math.random() * 2 * 24 * 60 * 60)
const b64 = (bytes) => btoa(String.fromCharCode(...bytes))
const toHex = (u8) => Array.from(u8, b => b.toString(16).padStart(2, '0')).join('')

// ---- signer-driven crypto (verbatim from ngage/steering.mjs) ----------------

async function giftWrapWithSigner(signer, recipientPub, rumor) {
  rumor.id = getEventHash(rumor)
  const seal = await signer.signEvent({
    kind: 13, created_at: fuzz(), tags: [],
    content: await signer.nip44Encrypt(recipientPub, JSON.stringify(rumor)),
  })
  const ephemeral = generateSecretKey()
  return finalizeEvent({
    kind: 1059, created_at: fuzz(), tags: [['p', recipientPub]],
    content: nip44.v2.encrypt(JSON.stringify(seal),
      nip44.v2.utils.getConversationKey(ephemeral, recipientPub)),
  }, ephemeral)
}

export async function publishScopeWithSigner(relay, signer, { scopeId, generation, scopeKey, payload }) {
  const ts = now()
  const event = await signer.signEvent({
    kind: KIND_DATA_SET,
    created_at: ts,
    tags: [['d', scopeId], ['v', String(generation)]],
    content: nip44.v2.encrypt(JSON.stringify({ ...payload, updated_at: ts }), scopeKey),
  })
  const receipt = await relay.publish(event)
  return { event, ...receipt }
}

export async function grantWithSigner(relay, signer, granteePubkey,
                                      { scopeId, generation, scopeKey, scopeName, relayHint = '' }) {
  const publisherPub = await signer.getPublicKey()
  const rumor = {
    pubkey: publisherPub,
    kind: KIND_GRANT,
    created_at: now(),
    tags: [
      ['a', `${KIND_DATA_SET}:${publisherPub}:${scopeId}`, relayHint],
      ['v', String(generation)],
    ],
    content: JSON.stringify({ scope_key: b64(scopeKey), scope_name: scopeName }),
  }
  const wrap = await giftWrapWithSigner(signer, granteePubkey, rumor)
  const receipt = await relay.publish(wrap)
  return { wrap, ...receipt }
}

// ---- the draft:post glue (new) ----------------------------------------------

export const newScopeId = () => toHex(crypto.getRandomValues(new Uint8Array(16)))

/** hex pubkey passthrough, or decode an npub1… to hex. Throws on anything else. */
export function toHexPubkey(npubOrHex) {
  const s = (npubOrHex || '').trim()
  if (/^[0-9a-f]{64}$/i.test(s)) return s.toLowerCase()
  if (s.startsWith('npub1')) {
    const { type, data } = nip19.decode(s)
    if (type === 'npub') return data
  }
  throw new Error('recipient must be an npub1… or a 64-char hex pubkey')
}

/**
 * Publish a re-voiced draft to the Director's Ngage desk.
 *   relay   — anything with async publish(event) (LiveRelay, or an in-memory one)
 *   signer  — the PEN (jaf-quill bunker connection); its key signs the scope + seal
 *   recipient — the Director's npub / hex (the desk that decrypts + approves)
 *   draft   — { text, image?, hashtags?, rationale? }
 * Returns { scopeId, scopeName, penPub, scopeReceipt, grantReceipt }.
 */
export async function publishDraft(relay, signer, recipient, draft) {
  const recipientHex = toHexPubkey(recipient)
  const text = (draft.text || '').trim()
  if (!text && !draft.image) throw new Error('nothing to send — the draft is empty')
  const scopeId = newScopeId()
  const generation = 1
  const scopeKey = newScopeKey()
  const scopeName = `draft:post/${scopeId.slice(0, 8)}`
  const payload = {
    kind: 'draft:post',
    text,
    image: draft.image || null,
    hashtags: Array.isArray(draft.hashtags) ? draft.hashtags : [],
    rationale: draft.rationale || undefined,
    proposedBy: 'nscribe',
    proposedAt: now(),
  }
  const scopeReceipt = await publishScopeWithSigner(relay, signer, { scopeId, generation, scopeKey, payload })
  const grantReceipt = await grantWithSigner(relay, signer, recipientHex, { scopeId, generation, scopeKey, scopeName })
  return { scopeId, scopeName, penPub: await signer.getPublicKey(), scopeReceipt, grantReceipt }
}

// ---- the Cloud Drafter: jaf-quill reads its OWN credential grant ------------
//
// The AD-10 director path: the Director never drafts with his own key. jaf-quill
// (the pen, the bunker connection) dereferences the `credential:anthropic` grant
// the Director issued to it — off the relays, with its own key — and drafts with
// that. No key is ever pasted. Errors are typed so the UI can say exactly which
// prerequisite is missing (grant not issued vs. bunker won't decrypt).
//
//   relay  — LiveRelay (or any {query})
//   signer — the jaf-quill bunker connection (nip44Decrypt + getPublicKey)
// Returns the Anthropic key string. Throws Error with a machine code in .code.
const CRED_SCOPE = 'credential:anthropic'

export async function readAnthropicCredential(relay, signer) {
  let grants
  try {
    grants = await receiveGrants(relay, signer)   // needs the bunker to nip44Decrypt
  } catch (e) {
    const err = new Error(String(e?.message || e)); err.code = 'DECRYPT_REFUSED'; throw err
  }
  const latest = latestGrants(grants)
  const cred = latest.find(g => g.scopeName === CRED_SCOPE)
  if (!cred) {
    const err = new Error('no credential:anthropic grant reached this key')
    err.code = 'NO_GRANT'; err.seen = latest.map(g => g.scopeName).filter(Boolean); throw err
  }
  const scope = await fetchScope(relay, cred)
  if (scope.status !== 'ok') {
    const err = new Error('credential grant is ' + scope.status); err.code = 'STALE'; throw err
  }
  const value = scope.data?.value ?? scope.data?.anthropic ?? scope.data?.key
  if (!value || typeof value !== 'string') {
    const err = new Error('credential payload has no string .value'); err.code = 'SHAPE'; throw err
  }
  return value
}

// ---- discovery: read your own record, don't type it -------------------------
//
// The Director's exact question — "ngage knows my drafting source... you should
// only have to somehow read this? or when that was created it created the record?"
// The answer is yes, it created the record. When he trusted a pen in Ngage and
// published steering, ngage/nvoy-index.mjs wrote a `steer:draft` issued entry
// into his kind-10440 Grant Index (the one Nvoy is the source of truth for), and
// that entry's `grantees` ARE his pens. So after an Alby sign-in Nscribe reads
// his own index and discovers jaf-quill — no npub typed, no "Director" concept,
// no config. His drafting hand is metadata, discovered from published state (AD-2).
const STEER_SCOPE = 'steer:draft'

/**
 * Discover the signed-in identity's drafting pens straight from their own Grant
 * Index. `signer` is the Alby (or bunker) sign-in — it decrypts the encrypted-
 * to-self kind-10440 event. Returns hex pubkeys, current rotation winning,
 * deduped; [] when no steering has been published yet (nothing to discover).
 */
export async function discoverDrafters(relay, signer) {
  const index = await loadGrantIndex(relay, signer)
  const issued = Array.isArray(index?.issued) ? index.issued : []
  const steer = issued
    .filter(e => e && e.scope_name === STEER_SCOPE && Array.isArray(e.grantees))
    .map(fromIssuedEntry)
    .sort((a, b) => (b.generation || 0) - (a.generation || 0))   // newest rotation first
  const seen = new Set(); const drafters = []
  for (const s of steer) for (const g of s.grantees)
    if (typeof g === 'string' && /^[0-9a-f]{64}$/i.test(g) && !seen.has(g)) {
      seen.add(g); drafters.push(g)
    }
  return drafters
}

// ---- the connection, remembered as a self-grant -----------------------------
//
// The bunker connection to your pen, stored the SAME way your credential is: a
// secret, encrypted to your own key, on your own relays — so a reload or a
// different device reconnects with nothing pasted. It follows your identity, not
// your browser. We persist the pen's pubkey, its relays, and the STABLE client
// transport key — NOT the one-time bunker secret: once paired, Bunker46 binds to
// the client key and reconnect needs no secret. A NIP-78 replaceable app-data
// event (kind 30078), separate from the Nvoy-managed Grant Index so neither
// clobbers the other; content NIP-44'd to self, same trust model as the
// credential and scope keys already on your relays.
export const KIND_APP_DATA = 30078
const CONN_D = 'nscribe:connections'

/** Load your saved pen connections: { [penPubHex]: { relays, clientSecretHex, updated_at } }. */
export async function loadConnections(relay, signer) {
  const self = await signer.getPublicKey()
  const [event] = await relay.query({ kinds: [KIND_APP_DATA], authors: [self], '#d': [CONN_D] })
  if (!event) return {}
  try {
    const obj = JSON.parse(await signer.nip44Decrypt(self, event.content))
    return obj && typeof obj === 'object' ? obj : {}
  } catch { return {} }
}

/**
 * Remember (or replace) the connection to one pen, merging with any others.
 * `signer` is your own sign-in (it self-encrypts). Returns the publish receipt.
 */
export async function saveConnection(relay, signer, { penPub, relays: bunkerRelays, clientSecretHex }) {
  const self = await signer.getPublicKey()
  const all = await loadConnections(relay, signer)
  all[penPub] = {
    relays: [...new Set(bunkerRelays || [])],
    clientSecretHex,
    updated_at: Math.floor(Date.now() / 1000),
  }
  const event = await signer.signEvent({
    kind: KIND_APP_DATA,
    created_at: Math.floor(Date.now() / 1000),
    tags: [['d', CONN_D]],
    content: await signer.nip44Encrypt(self, JSON.stringify(all)),
  })
  return relay.publish(event)
}

/** Rebuild a bunker:// pointer for a saved connection — pen + relays, no secret
 *  (the session is already bound to the persisted client key). */
export function connectionUri(penPub, saved) {
  const relays = (saved?.relays || []).map(r => `relay=${encodeURIComponent(r)}`).join('&')
  return `bunker://${penPub}?${relays}`
}

/**
 * Resolve display names for pubkeys from their published kind-0 profiles, so the
 * discovered pen shows as "James's Quill", not a hex string. Best-effort: a
 * pubkey with no profile (or an unreachable relay) maps to null.
 */
export async function resolveNames(relay, pubkeys) {
  const uniq = [...new Set(pubkeys)].filter(pk => /^[0-9a-f]{64}$/i.test(pk))
  if (!uniq.length) return {}
  let events = []
  try { events = await relay.query({ kinds: [0], authors: uniq }) } catch { /* offline → nulls */ }
  const best = {}
  for (const ev of events) {
    if (best[ev.pubkey] && best[ev.pubkey].created_at >= ev.created_at) continue
    try {
      const p = JSON.parse(ev.content)
      best[ev.pubkey] = { created_at: ev.created_at, name: p.display_name || p.name || p.nip05 || null }
    } catch { /* malformed profile → skip */ }
  }
  const out = {}
  for (const pk of uniq) out[pk] = best[pk]?.name || null
  return out
}
