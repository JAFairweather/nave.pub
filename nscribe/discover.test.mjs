// Round-trip proof for discoverDrafters() — write the SAME record Ngage writes
// when the Director trusts a pen and publishes steering (a `steer:draft` issued
// entry in his kind-10440 Grant Index), then discover the pen back through
// Nscribe's reader with nothing typed. This is the answer to "you should only
// have to somehow read this?" made executable: the record IS the config.
//
// Run:  node nscribe/discover.test.mjs   (needs the dev-only nostr-tools shim)
import assert from 'node:assert'
import { generateSecretKey, getPublicKey, nip44, finalizeEvent } from 'nostr-tools'
import { discoverDrafters, resolveNames } from './emit.mjs'
import { loadGrantIndex, saveGrantIndex, toIssuedEntry, newScopeKey } from './vendor/nipxx.mjs'

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
    async publish(e) {
      // replaceable kinds (10000-19999): newest per (author,kind) wins, like a relay
      if (e.kind >= 10000 && e.kind < 20000) {
        for (let i = events.length - 1; i >= 0; i--)
          if (events[i].kind === e.kind && events[i].pubkey === e.pubkey) events.splice(i, 1)
      }
      events.push(e); return { acks: 1, of: 1, rejections: [] }
    },
    async query(f) {
      return events.filter(e => {
        if (f.kinds && !f.kinds.includes(e.kind)) return false
        if (f.authors && !f.authors.includes(e.pubkey)) return false
        if (f.ids && !f.ids.includes(e.id)) return false
        for (const k of Object.keys(f))
          if (k[0] === '#') { const have = tagVals(e, k.slice(1)); if (!f[k].some(v => have.includes(v))) return false }
        return true
      })
    },
  }
}

const dirSk = generateSecretKey()
const dir = testSigner(dirSk)
const quillSk = generateSecretKey(), quillPub = getPublicKey(quillSk)
const relay = memRelay()

// Nothing published yet → discovery finds no drafter (the safe empty direction).
assert.deepEqual(await discoverDrafters(relay, dir), [], 'no steering published → no drafter discovered')

// The Director publishes his kind-0 so the pen has a name to resolve.
await relay.publish(await testSigner(quillSk).signEvent({
  kind: 0, created_at: 1, tags: [], content: JSON.stringify({ display_name: "James's Quill" }),
}))

// Ngage's record, written verbatim the way nvoy-index.mjs writes it: upsert a
// single `steer:draft` issued entry naming the pen as grantee, into the
// Director's own encrypted-to-self Grant Index.
const idx = await loadGrantIndex(relay, dir)
idx.issued = (idx.issued ?? []).filter(e => e.scope_name !== 'steer:draft')
  .concat(toIssuedEntry({ scopeId: 'steerscope01', scopeName: 'steer:draft', generation: 3, scopeKey: newScopeKey() }, [quillPub]))
await saveGrantIndex(relay, dir, idx)

// Now Nscribe discovers the pen with nothing typed — just the Alby sign-in.
const drafters = await discoverDrafters(relay, dir)
assert.deepEqual(drafters, [quillPub], 'the pen is discovered from the steer:draft grantees')

const names = await resolveNames(relay, drafters)
assert.equal(names[quillPub], "James's Quill", 'the pen resolves to its published name')

// A stranger signing in discovers nothing of the Director's — the index is his.
const stranger = testSigner(generateSecretKey())
assert.deepEqual(await discoverDrafters(relay, stranger), [], 'a stranger discovers no drafter')

console.log('discover round-trip: PASS')
console.log('  ✓ empty before publish   ✓ pen discovered from steer:draft record   ✓ name resolved   ✓ private to its owner')
