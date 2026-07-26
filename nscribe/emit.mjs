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
import { KIND_DATA_SET, KIND_GRANT, newScopeKey } from './vendor/nipxx.mjs'

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
