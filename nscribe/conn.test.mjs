// Round-trip proof for the remembered connection — save the bunker connection
// as self-encrypted app data, read it back exactly as a reload (or another
// device) would, and confirm a stranger key finds nothing. This is what makes
// the app usable across sessions: sign in, and the connection is already there.
//
// Run:  node nscribe/conn.test.mjs   (via the vendored-nostr-tools resolve hook)
import assert from 'node:assert'
import { generateSecretKey, getPublicKey, nip44, finalizeEvent } from 'nostr-tools'
import { saveConnection, loadConnections, connectionUri, KIND_APP_DATA } from './emit.mjs'

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
      // replaceable addressable (30000-39999): newest per (author,kind,d) wins
      if (e.kind >= 30000 && e.kind < 40000) {
        const d = tagVals(e, 'd')[0]
        for (let i = events.length - 1; i >= 0; i--)
          if (events[i].kind === e.kind && events[i].pubkey === e.pubkey && tagVals(events[i], 'd')[0] === d) events.splice(i, 1)
      }
      events.push(e); return { acks: 1, of: 1, rejections: [] }
    },
    async query(f) {
      return events.filter(e => {
        if (f.kinds && !f.kinds.includes(e.kind)) return false
        if (f.authors && !f.authors.includes(e.pubkey)) return false
        for (const k of Object.keys(f))
          if (k[0] === '#') { const have = tagVals(e, k.slice(1)); if (!f[k].some(v => have.includes(v))) return false }
        return true
      })
    },
  }
}

const meSk = generateSecretKey()
const me = testSigner(meSk)
const relay = memRelay()
const penPub = getPublicKey(generateSecretKey())
const penPub2 = getPublicKey(generateSecretKey())
const bunkerRelays = ['wss://bunker.example', 'wss://relay.nave.pub']
const clientSecretHex = Buffer.from(generateSecretKey()).toString('hex')

// Nothing saved yet.
assert.deepEqual(await loadConnections(relay, me), {}, 'no connections before the first save')

// Save one pen's connection, then read it back as a fresh session would.
await saveConnection(relay, me, { penPub, relays: bunkerRelays, clientSecretHex })
const back = await loadConnections(relay, me)
assert.ok(back[penPub], 'the connection round-trips')
assert.equal(back[penPub].clientSecretHex, clientSecretHex, 'the stable transport key is preserved')
assert.deepEqual(back[penPub].relays, bunkerRelays, 'the pen relays are preserved')

// A second pen MERGES, does not clobber the first.
await saveConnection(relay, me, { penPub: penPub2, relays: ['wss://two.example'], clientSecretHex: 'ff'.repeat(32) })
const both = await loadConnections(relay, me)
assert.ok(both[penPub] && both[penPub2], 'a second pen merges alongside the first')

// The reconnect pointer carries pen + relays and NO secret (session is bound to
// the persisted client key, so no secret is needed or stored).
const uri = connectionUri(penPub, both[penPub])
assert.ok(uri.startsWith(`bunker://${penPub}?`), 'the reconnect URI targets the pen')
assert.ok(uri.includes('relay=wss'), 'the reconnect URI carries the relays')
assert.ok(!/secret=/.test(uri), 'the reconnect URI carries NO secret')

// The record is private: a stranger signing in finds nothing of yours.
const stranger = testSigner(generateSecretKey())
assert.deepEqual(await loadConnections(relay, stranger), {}, 'a stranger finds no connection')

console.log('connection round-trip: PASS')
console.log(`  ✓ saved as kind ${KIND_APP_DATA} to self   ✓ transport key + relays round-trip   ✓ multi-pen merge   ✓ no secret stored   ✓ private to its owner`)
