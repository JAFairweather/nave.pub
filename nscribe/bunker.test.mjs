// Wire proof for the hand-rolled NIP-46 client in nave-connect.nip46Signer —
// the fix for the Bunker46 "Cannot read properties of undefined (reading
// 'pubkey')" bug. A fake pool plays Bunker46: it answers in nip44 (the real
// bug was BunkerSigner listening in nip04) and is driven by a SINGLE filter
// object (the real bug was passing an array to subscribeMany). If the client
// can get_public_key and sign_event through this, the two hard-won lessons hold.
//
// Run:  node nscribe/bunker.test.mjs   (via the vendored-nostr-tools resolve hook)
import assert from 'node:assert'
import { generateSecretKey, getPublicKey, finalizeEvent, verifyEvent, nip44 } from 'nostr-tools'
import { nip46Signer } from './vendor/nave-connect.mjs'

// The bunker's identity (the remote signer — jaf-quill stands in here).
const bunkerSk = generateSecretKey(), bunkerPk = getPublicKey(bunkerSk)

// A fake pool: subscribeMany registers the client's inbox; publish decrypts the
// client's request with the bunker's side of the conv key and answers in nip44.
function fakeBunkerPool() {
  let inbox = null            // the client's onevent
  let filter = null           // what the client subscribed with
  return {
    subscribeMany(_relays, f, { onevent }) {
      // The real subscribeMany takes ONE object; an array here would mean the
      // client passed an array, which we refuse exactly as the wire does.
      assert.ok(!Array.isArray(f), 'subscribeMany must receive a single filter object, not an array')
      filter = f; inbox = onevent
      return { close() {} }
    },
    publish(_relays, ev) {
      // Deliver the request to "the bunker": decrypt, dispatch, answer.
      queueMicrotask(async () => {
        assert.equal(ev.kind, 24133, 'requests are kind 24133')
        assert.ok(verifyEvent(ev), 'request is a valid signed event')
        const clientPk = ev.pubkey
        // Filter must target the bunker as author and the client via #p.
        assert.deepEqual(filter.authors, [bunkerPk])
        assert.deepEqual(filter['#p'], [clientPk])
        const bConv = nip44.v2.utils.getConversationKey(bunkerSk, clientPk)
        const req = JSON.parse(nip44.v2.decrypt(ev.content, bConv))
        let result = '', error
        if (req.method === 'connect') result = 'ack'
        else if (req.method === 'get_public_key') result = bunkerPk
        else if (req.method === 'sign_event') {
          const tmpl = JSON.parse(req.params[0])
          result = JSON.stringify(finalizeEvent({ ...tmpl, pubkey: bunkerPk }, bunkerSk))
        } else error = 'unknown method'
        const reply = finalizeEvent({
          kind: 24133, created_at: Math.floor(Date.now() / 1000), tags: [['p', clientPk]],
          content: nip44.v2.encrypt(JSON.stringify({ id: req.id, result, error }), bConv),
        }, bunkerSk)
        inbox(reply)
      })
      return [Promise.resolve()]
    },
    close() {},
  }
}

const relay = 'wss://relay.example'
const bunkerUri = `bunker://${bunkerPk}?relay=${encodeURIComponent(relay)}&secret=deadbeef`
const signer = nip46Signer(bunkerUri, { _pool: fakeBunkerPool() })

// get_public_key round-trips (the exact call that returned undefined under the bug).
const pk = await signer.getPublicKey()
assert.equal(pk, bunkerPk, 'getPublicKey returns the bunker pubkey — not undefined')

// sign_event round-trips and the signature verifies as the bunker.
const signed = await signer.signEvent({ kind: 1, created_at: 1, tags: [], content: 'penned by the bunker' })
assert.equal(signed.pubkey, bunkerPk, 'the bunker signed it')
assert.ok(verifyEvent(signed), 'the signature verifies')

// A reused bunker:// re-pairs to the SAME transport key when the secret persists.
const s2 = nip46Signer(bunkerUri, { clientSecret: signer.clientSecretHex, _pool: fakeBunkerPool() })
assert.equal(s2.clientSecretHex, signer.clientSecretHex, 'the persisted transport key is stable across reconnects')

console.log('bunker nip46 round-trip: PASS')
console.log('  ✓ nip44 both ways   ✓ single-filter subscribe   ✓ get_public_key not undefined   ✓ sign verifies   ✓ stable transport key')
