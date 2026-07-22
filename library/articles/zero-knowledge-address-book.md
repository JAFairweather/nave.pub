# The zero-knowledge address book

I love a door with a letter slot in it.

The brass kind — worn bright down the middle where forty years of thumbs pushed it open — with the stiff spring and the little clap it makes swinging shut.

My favorite thing about a letter slot is what it refuses to do. It goes one way. Somebody comes up the path — posts a thing through — walks back down the path, and now the letter is inside and they are outside and neither one can reach across.

The postman never read it. Not because he is a good man, though he is. He never read it because the letter was in an envelope and the envelope was closed and his entire job was the outside of it.

That is warm.contact.

There is a line at the top of that repository's working notes, written down before there was an application for it to be about. The relay must never be able to read a submission. Not should not. Not does not, as a matter of policy, subject to annual review by a trust and safety team in a building somewhere.

Cannot — because it is never handed anything readable.

Everything the product turned out to be falls out of that sentence. So do a good number of things it will never be.

The costs arrive first. A server that cannot read a submission cannot moderate it — cannot index it — cannot get it back for you when the laptop goes in the lake.

But it can do what the postman does. Is this the right shape — is it under the weight — is that a real address — has this doorstep taken forty of these in the last minute. Structural checks on the outside of the envelope and nothing else, ever.

So the address book is inbound-first. Each person keeps their own record and hands it over — you never sit down and compile a dossier on anybody. And abuse gets settled at the identity layer and the behavior layer, because the content layer is dark and staying dark.

And plaintext lives in exactly one place on earth — the client running on your own machine.

Anybody who has made the same part twice knows the next bit in their hands. You cut one on the mill and one on the lathe, off the same drawing, then bring them together on the bench.

Either they fit or your drawing was a wish.

The envelope is called wc1 and it is made twice. Once in TypeScript against WebCrypto — for the browser the sender is standing in. Once in Swift against Apple's CryptoKit — for the Mac the letter is walking toward. A hundred and fifty lines a side, by hand, both off the same drawing: an ephemeral P-256 key agreed against the recipient's device key — that x-coordinate through HKDF-SHA256 — AES-256-GCM over the payload — both raw public keys bound into the info string, so the wrapping key belongs to that pair and no other pair that will ever exist.

And the content key gets wrapped once per device you own. Three Macs — three wraps — one letter, and no private key ever shuttled between machines to make it work.

Only primitives both platforms already ship. Zero crypto dependencies in the browser. Zero in Swift.

The cost is real and it is permanent — one construction living twice, in two languages, maintained by hand.

Which is the whole reason to do it.

There is a test that seals a payload with the TypeScript and opens it with the Swift — fresh keys every run — and fails the build unless the plaintext comes back byte for byte. Change one side without the other and the build says so, long before a person does.

One implementation is a claim about how a thing works. Two that fit is a measurement.

There is no reference implementation here to defer to. There is an agreement between two peers — and the agreement runs.

The envelope has no sender in it. A sealed box is anonymous by construction, and a letter through your slot carries a return address only if the writer chose to put one there. So trust gets settled at the door — the sender proves their own round trip — you approve what you keep.

The gate is a person and the person is you.

Then an agent moved into the house.

The original credential story was the one everybody ships. You paste an API key — the app tucks it in the Keychain, this device only — and that is custody. It works.

It also means the thing holding your authority is a string in a drawer. And a string in a drawer cannot be revoked. Only deleted, and only by whoever is standing at the drawer.

So the key stopped being a string and became a grant.

The bill for that came due in Swift — canonical serialization escaped to match JSON.stringify exactly, because the event id is a hash of it — Schnorr signing — Bech32 — a ChaCha20 core written out longhand, because NIP-44 wants the raw stream at counter zero.

And then NIP-44 in both of the forms the grant path actually needs, which is the part most descriptions of that protocol walk past. The ECDH form takes a secp256k1 shared x-coordinate through an HKDF extract and gives you the conversation key for the gift wrap and the seal. The raw form takes a 32-byte scope key and uses it directly, no ECDH at all — and that is the one that makes revocation mean something, because rotating a scope key is how you change a lock.

The unwrapping is stricter than the reference library's, deliberately. The kind-13 seal's signature has to verify. The rumor's pubkey has to equal the seal's. Anything else goes in the bin unopened.

Anyone at all can address a gift wrap to your Quill, the same way anyone at all can walk up your path. The slot is public and the door is not.

So a grant counts only if the hand that issued it is in your Director set, and a re-wrapped grant — where the addressed scope's publisher is not the rumor's author — gets turned away at the threshold. Without that, a stranger could gift-wrap a spoofed credential at your agent and, being newest, shadow the real one.

Newest issuance wins a name. A severed scope never clobbers a live sibling wearing that same name.

And a rotated key does not arrive as an error. It arrives as a MAC failure and reads as stale, which is a state, not a fault.

All of it lands behind three methods — load, store, delete — the same small seam every consumer already read its credentials through. So the grant vault is one more implementation of that seam, and Rekindle and the Gmail importer resolve a Director-signed grant instead of a Keychain item without one line of calling code changing anywhere.

And the shape of the new backend says the quiet part out loud. Store throws. Delete throws. Grant-backed credentials are read-only, and revocation is the Director rotating the scope key.

The application cannot write its own authority. I would like a great many more applications to be able to say that sentence.

The same reader eats a second namespace, and that is what changed how the thing feels to live with. Profile voice and profile policy carry what used to sit in a JSON file in a hidden folder — the narrative of what you have been up to — your sign-off — the region you call home — your default tone.

Granted from your own identity to your agent's key, that configuration comes back from your key alone, resolves the same on a second machine, and revokes one topic at a time.

Your voice stops being a file that dies with a hard drive.

The relay still sees each grant's existence — its label — its terms — its timing. That a Quill holds a Gmail credential is a public sentence, and the inside of it is not.

And editing a field stopped being a file write. It is a signed re-issue now, which puts your identity in the room. Persistence has a price and you pay it at the edit.

The agent all of this exists for is called Quill, and it belongs to one person. Not a seat in a shared one. Its own key — minted for you — holding only what you granted it.

It writes the first draft of the replies everybody owes and nobody sends, out of facts it was actually handed, and then it lays the draft in your own Messages or your own Mail and stops.

It does not press send. Nothing wearing your name goes out a noreply door.

And its credential cannot be brokered. The obvious pattern is to hold the provider key centrally and let a trusted runtime make the call for everybody — and that one fails here, because the drafting prompt has contact plaintext in it. There is no blind middle path, because putting a key into a request means reading the request.

So the key goes to the app and the app calls the provider itself. More copies of that secret sit at rest than a broker would keep. That is the price of not walking your friends' names through a stranger's building, and it is the right price.

The live plane spawns a child process and hands it the agent's key in the child's environment, where it lives in memory for the child's lifetime and never touches disk.

And the whole plane ships dark. With nothing configured, behavior is byte-identical to the old Keychain flow — and when a configured source is down or slow or spewing garbage, every consumer falls back to it.

The failure mode of the new system is the old system.

Rotate a scope key and the next update never reaches the reader you cut off. The one they already opened stays opened. Whoever read it, read it — no lock ever un-read a letter, and this one has never claimed to.

Spawning a child process is precisely what the App Sandbox forbids. So today's build stands outside it — hardened runtime, one entitlement for the address book — and the morning the sandbox goes on is the morning the grant plane goes off. Both are facts about the same door and both are written down.

The child needs a Node runtime and the server sitting on the machine beside it. On my box that is a Tuesday. In a notarized menu-bar app it is a decision — bundle the runtime — name the prerequisite — wait for a compiled server — and nobody has picked one.

And the contents of a submission are unreadable to whoever runs the relay, while the metadata around it is not — the address — the timestamp — the destination handle — the volume.

Why do I keep coming back to a letter slot?

Because the shape was chosen before anything got built on top of it. So go look at whatever holds the names of the people you care about — the app — the CRM — the sync — the helpful assistant that offered to tidy it up for you. Somebody built that, and somebody decided how much of it they get to see. If the answer is all of it, that was a choice, and it was theirs and not yours.

Make the other choice. Cut the slot before you build the house — it will cost you a preview pane and a dashboard and a few nights you wanted back — and the person coming up your path will never once have to wonder who read their letter.

That is worth a hundred and fifty lines a side.
