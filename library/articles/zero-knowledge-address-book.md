# The zero-knowledge address book

*warm.contact's shipped architecture: one envelope implemented twice, a
relay that structurally cannot read a submission, and the Swift grant
plane that turned credentials into signed, revocable authority.*

---

Most privacy work is additive. You build the product, then you encrypt
something. warm.contact is the other kind: a constraint written down
before there was an application, which every decision afterwards had to
survive. **The relay must never be able to read a submission.** Not
*should not*, not *does not, as a matter of policy* — cannot, because it
is never handed anything readable. That single line is the first entry in
the repo's working notes, and everything the product is (and several
things it will never be) falls out of it.

The consequences arrive before the benefits. A server that cannot read a
submission cannot moderate one, cannot index it, cannot de-duplicate it,
cannot recover it for you, and cannot show you a useful preview in a web
dashboard. What it *can* do is check structure: is this a well-formed
envelope, is it under the cap, is the destination handle real, has this
address sent forty of these in a minute. **Structural checks on
ciphertext only.** That rule is why the address book is inbound-first
(each person maintains their own record and shares it, rather than you
compiling a dossier), why the abuse strategy lives at the identity and
behaviour layer instead of the content layer, and why the desktop client
is the only place plaintext exists at all. The constraint isn't a feature
of the product. It *is* the product, and the rest is consequence
management.

## One envelope, implemented twice

The wire format is `wc1`: a sealed box, hand-assembled from primitives
that exist natively in both WebCrypto and Apple CryptoKit. P-256 ECDH
from an ephemeral key to the recipient's static device key, the
x-coordinate through HKDF-SHA256, AES-256-GCM over the payload. Both raw
public keys are bound into the HKDF `info` string, which ties the wrapping
key to that exact (ephemeral, recipient) pair. The content-encryption key
is wrapped once per recipient device public key — the multi-recipient
pattern `age` popularised — which is how a user with three Macs decrypts
on any of them without a private key ever being shuttled between
machines.

Picking only primitives both platforms already ship was deliberate: zero
crypto dependencies in the browser, zero in the Swift client. The cost is
that the construction now exists twice, in two languages, maintained by
hand — roughly a hundred and fifty lines a side.

Two implementations of one envelope is a discipline, not redundancy. The
cross-test seals a payload with the TypeScript/WebCrypto implementation
and opens it with the Swift/CryptoKit one, with fresh keys every run, and
fails the build unless the plaintext comes back byte-for-byte. The
working-notes rule is blunt: any change to one side must change the other
and pass `npm run cross-test`. What that buys is that the wire format
can never quietly drift into "whatever the browser happens to do this
week." There is no reference implementation to defer to — there is an
agreement between two peers, and the agreement is executable.

Worth stating plainly, because the format doesn't hide it: sealed boxes
are anonymous by construction. There is no sender authenticity in the
envelope. Trust is adjudicated elsewhere — by the submitter's
round-trip verification and by the receiver's approval gate, which is
also what contains the harassment problem that zero knowledge makes
un-moderatable.

## The grant plane, in Swift

The second half of the architecture is what happened when an agent moved
into the building. warm.contact's original credential story was a
Keychain entry: you paste an API key, the app stores it this-device-only,
and that's custody. The shipped work replaces the *source* of that
credential with a grant the user signs — and does it behind an interface
that already existed.

The plumbing is `NostrCrypto.swift`, and it is the honest cost of the
decision. NIP-01 canonical serialization with string escaping that
matches `JSON.stringify` exactly, because the event id is a hash of that
serialization and byte-compatibility with the JS reference is
load-bearing. BIP-340 schnorr signing and verification. Bech32 for
`npub`/`nsec`. A hand-written ChaCha20 core, because CryptoKit exposes
only the Poly1305 AEAD and NIP-44 needs the raw stream at counter zero.

Then NIP-44 v2 in **both** of the forms the grant path actually requires,
which is the detail most descriptions of this protocol elide. The ECDH
form — a secp256k1 shared x-coordinate through an HKDF extract — produces
the conversation key for gift-wrap and seal layers. The raw form uses a
32-byte scope key *directly* as the conversation key, with no ECDH step at
all: that is how a scoped data set is encrypted, and it is what makes
revocation-by-rotation work. NIP-59 unwrap sits on top, deliberately
stricter than the reference JS library's: the kind-13 seal's signature
must verify, and the rumor's pubkey must equal the seal's, or the wrap is
discarded. NIP-98 signing (kind 27235, `Authorization: Nostr …`) completes
the set for authenticated HTTP back to Nave.

The reader's trust rules are where the design earns its keep. A grant
counts only if its publisher is in the caller's Director set, and
re-wrapped grants — where the addressed scope's publisher isn't the
rumor's author — are rejected outright. Without that, anyone could
gift-wrap a spoofed `credential:anthropic` scope at your Quill and, being
newest, shadow the real value. Newest issuance wins a name; a severed
scope never clobbers a live same-name sibling. And revocation isn't an
error path: a rotated scope key surfaces as a MAC failure on dereference
and is read as **stale**, a state, not a fault.

All of which lands behind `SecretVault` — the three-method seam
(`load` / `store` / `delete`) every consumer in the app already read
credentials through. `GrantVault` is one more implementation of it, so
Rekindle and the Gmail importer resolve a Director-signed grant instead
of a Keychain item **with zero calling-code changes**. The new backend's
shape says something too: `store` and `delete` throw. *Grant-backed
credentials are read-only — revocation is the Director rotating the scope
key.* The application cannot write its own authority.

## Configuration that survives the laptop

The same reader consumes a second namespace, and this is the part that
changes what the product feels like. `profile:voice` and `profile:policy`
carry what used to live in `~/.warmcontact/reconnect.json` and in code:
the narrative of what you've been up to, your sign-off, your home region,
your scheduling link; your default tone and follow-up methodology. As
scoped data granted from the user's identity to their agent's key, that
configuration is recoverable from the user's own key alone, resolves
identically on a second machine, and is revocable one topic at a time.
Your voice stops being a file that dies with a hard drive.

The extension point is the scope *name*. The resolver enumerates
`profile:*` by prefix, so a future `profile:boundaries` appears with no
resolver change, and an unrecognised topic is inert rather than an error.
Within a topic the payload is versioned JSON decoded as an overlay:
present keys win, absent keys keep the file's value, unknown keys are
ignored, and a payload declaring a version beyond what the reader supports
leaves the base untouched rather than misreading a changed meaning.

Two costs, disclosed rather than finessed. The *values* are encrypted to
the agent's key, but relays see each grant's existence, its scope
**label**, its terms and its timing — "this Quill holds
`credential:gmail`" is public. And editing a field stops being a file
write and becomes a signed re-issue, which needs the user's identity
present to sign. Persistence has a price and it is paid at the edit.

## Quill drafts; it never presses send

The agent this plane exists for is per-person, not a seat in a shared
one: its own key, minted for that user, holding only what that user
granted it. It writes the first draft of the replies everybody owes and
nobody sends, uses only facts it was actually given, and hands off to your
own Messages or Mail — never a `noreply@` wearing your name.

The interesting constraint is why its credential can't be brokered. The
obvious pattern elsewhere in the fleet is to hold the provider key
centrally and let a trusted runtime make the call. That fails here for
one specific reason: the drafting prompt contains contact plaintext.
Brokering it would route exactly the material the entire architecture
exists to protect through multi-tenant infrastructure — and there is no
blind middle path, because injecting a key into a request requires reading
the request. So the credential is delivered *to* the app and the app calls
the provider directly. The honest cost, written into the design rather
than around it: more copies of the secret at rest than a broker's
RAM-only key. The mitigation belongs on the credential — user-supplied
keys, tight per-instance scope, rotation, and reads that bypass the cache
so a revocation bites now rather than a minute from now — not on the
pattern.

## Custody by subprocess

The app doesn't speak the protocol to reach Nave; it speaks a contract.
Two MCP tools — list the grants this key holds, dereference one — pinned
against the server's own conformance suite rather than against guesses.
That's the load-bearing choice: draft kind numbers, relay topology and
encryption details can all churn upstream without touching warm.contact.

The live plane spawns `nvoy-mcp` as a child process, hands it the agent's
key from Keychain custody in the child's environment — in memory for the
child's lifetime, never on disk — and speaks newline-delimited JSON-RPC
over its pipes. Sessions are lazy, serialized and self-healing: a
protocol or transport failure tears the session down, and the next call
respawns after a cooldown, so a crash-looping server degrades to fast
clean failures instead of a spawn storm.

The property worth naming is that the whole plane **ships dark**. With no
config present, behaviour is byte-identical to the old Keychain flow. And
when a configured source is down, slow, or spewing garbage, the sweep
throws, every consumer falls back, and the result is *also* byte-identical
to dark — a dead child and a garbage-spewing child are both test cases,
not hopes. The failure mode of the new system is the old system.

## What it can't do

Three limits, stated plainly, because a security architecture that only
lists its guarantees isn't describing itself.

**A revoked reader keeps whatever plaintext they already read.**
Revocation is key rotation, and rotation is forward-only: it severs
access to future updates. Nothing here un-tells a secret, and nothing here
claims to.

**The App Sandbox and the stdio plane are mutually exclusive.** Spawning
a child process is precisely what the sandbox forbids. Today's build is
unsandboxed — hardened runtime, one address-book entitlement — and
enabling the sandbox would kill the grant plane outright. That's recorded
as a constraint, not solved.

**Consumer packaging is unresolved.** The child needs a Node runtime and
the server's distribution present on the machine. That's fine for a
dogfood box and a real decision for a notarized menu-bar app: bundle a
runtime, document a prerequisite, or wait for a compiled server. Nobody
has picked, and pretending otherwise would be the kind of claim this
architecture is built to avoid.

Two more, from the spec rather than the roadmap: submission *contents* are
structurally unreadable to the operator, but *metadata* — address,
timestamp, destination handle, volume — is not; and a hosted tenant is
trusting the served page bundle at the moment of use in a way a
self-hoster is not.

None of this reads like a feature list, which is the argument. The
envelope exists twice because one implementation would be a claim and two
are a test. Credentials became grants because the seam for it was already
there and the alternative would have put contact plaintext through shared
infrastructure. The plane ships dark because a privacy system whose
failure mode is anything other than "the previous behaviour" is not a
privacy system. Ask what warm.contact's architecture is *for*, and the
honest answer is a single sentence that a server can't get around — and
then a long list of things that sentence made true.
