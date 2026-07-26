// Round-trip proof for emit.mjs — publish a re-voiced draft, then read it back
// through nipxx's OWN reader exactly as the Ngage desk (the Director) would,
// and confirm a stranger gets nothing. Local signer stands in for the jaf-quill
// bunker (same signer interface — NIP-46 is a custody swap, not a wire change).
//
// Run:  node nscribe/emit.test.mjs   (needs the dev-only nostr-tools shim)
import assert from 'node:assert'
import { generateSecretKey, getPublicKey, nip44, nip19, finalizeEvent } from 'nostr-tools'
import { publishDraft } from './emit.mjs'
import { receiveGrants, latestGrants, fetchScope } from './vendor/nipxx.mjs'

function testSigner(sk) {
  const pub = getPublicKey(sk)
  return {
    getPublicKey: async () => pub,
    signEvent: async (e) => finalizeEvent({ ...e, pubkey: pub }, sk),
    nip44Encrypt: async (pk, pt) => nip44.v2.encrypt(pt, nip44.v2.utils.getConversationKey(sk, pk)),
    nip44Decrypt: async (pk, ct) => nip44.v2.decrypt(ct, nip44.v2.utils.getConversationKey(sk, pk)),
  }
}

function memRelay() {
  const events = []
  const tagVals = (e, t) => e.tags.filter(x => x[0] === t).map(x => x[1])
  return {
    async publish(e) { events.push(e); return { acks: 1, of: 1, rejections: [] } },
    async query(f) {
      return events.filter(e => {
        if (f.kinds && !f.kinds.includes(e.kind)) return false
        if (f.authors && !f.authors.includes(e.pubkey)) return false
        if (f.ids && !f.ids.includes(e.id)) return false
        for (const k of Object.keys(f)) {
          if (k[0] === '#') { const have = tagVals(e, k.slice(1)); if (!f[k].some(v => have.includes(v))) return false }
        }
        return true
      })
    },
  }
}

const quillSk = generateSecretKey(), quillPub = getPublicKey(quillSk)
const dirSk = generateSecretKey(), dirPub = getPublicKey(dirSk)
const relay = memRelay()
const pen = testSigner(quillSk)

const TEXT = 'A barbershop — and the man who cuts my hair. Here it is, in my hand.'
const res = await publishDraft(relay, pen, nip19.npubEncode(dirPub), { text: TEXT, hashtags: ['craft'] })
assert.ok(res.scopeName.startsWith('draft:post/'), 'scopeName has the draft:post/<id8> shape')
assert.equal(res.penPub, quillPub, 'the pen is jaf-quill (the signer)')

// The Director reads it back exactly as the Ngage desk does.
const grants = latestGrants(await receiveGrants(relay, dirSk))
const g = grants.find(x => x.scopeName.startsWith('draft:post'))
assert.ok(g, 'the Director received the draft grant')
assert.equal(g.publisher, quillPub, 'grant author === publisher === the pen (desk reads penned:direct)')
const scope = await fetchScope(relay, g)
assert.equal(scope.status, 'ok', 'the scope decrypts for the Director')
assert.equal(scope.data.text, TEXT, 'the exact re-voiced text round-trips')
assert.equal(scope.data.kind, 'draft:post', 'payload kind is draft:post')

// The adversarial-observer law: a non-recipient gets nothing.
const stranger = await receiveGrants(relay, generateSecretKey())
assert.equal(stranger.length, 0, 'a stranger key finds no grant')

console.log('emit round-trip: PASS —', res.scopeName)
console.log('  ✓ text round-trips to the Director   ✓ pen = jaf-quill   ✓ recipient-only (stranger got 0)')
