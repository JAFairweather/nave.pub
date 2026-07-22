# Hardening a protocol in public

*A design review found six weaknesses in NIP-DA. None were mistakes —
they were the itemized cost of one deliberate bet, and hardening meant
paying the lines that could be paid and writing the rest into the spec.*

---

A design review that finds six weaknesses in your protocol is either an
obituary or an invoice, and the difference is whether the findings trace
back to mistakes or to a decision. The review of
[NIP-DA](https://github.com/JAFairweather/nostr-scoped-data-grants) —
committed to the same repository as the spec it criticizes — traced all
six to a single sentence in the design: *a scope is protected by one
symmetric key, handed to grantees as a bearer token.*

That bet is why the protocol is usable at all. One key over one payload
makes the encrypted data set O(1) in grantee count, makes updates free
(republish; every grantee dereferences the new truth), and asks nothing
of relays beyond plain NIP-01 addressable-event semantics — which is why
it runs today against stock public relays instead of waiting on anyone's
adoption. The six weaknesses are what that costs, itemized. So hardening
could not mean fixing bugs. It meant reading the invoice line by line,
paying the lines that could be paid, and moving the unpayable ones into
normative text, where the applications standing on top can't quietly
promise otherwise.

## What a client can refuse

The spec already required a replacement `kind:30440` to be signed by the
publisher named in its own address. The symmetric check on the *grant*
side was only implementation lore. A `kind:440` grant is an unsigned
rumor, sealed and gift-wrapped; its authenticated author is the seal's
pubkey. If that author differs from the publisher encoded in the grant's
`a` tag, the grant is a **re-wrap** — a grantee re-gifting a key it holds
— and is cryptographically indistinguishable from key exfiltration.
Nothing normative said so, and the default reader would have presented it
as though the publisher had issued it.

P1 makes the comparison a MUST, default-rejects re-wraps, and keeps the
distinct author on the record so an explicit deployment policy can
override. What that buys is narrower than it looks, and the spec says so
in the same breath: a grantee holding a scope key can always paste it
into a channel no client mediates. Enforcement is honest-client, not
cryptographic. The win is a clean line between the sanctioned delegation
path — a derived scope, where a sub-issuer publishes its *own* `30440`
and author matches publisher by construction — and raw key re-delivery,
which no conforming client will mistake for a first-party grant again.

## Detectable, not impossible

Replacement is what makes grants live, but content updates never bumped
the rotation counter `v`, so a grantee talking to a single withholding
relay could be pinned indefinitely to an older, perfectly valid,
perfectly signed event. The only freshness evidence was an `updated_at`
claim invisible until after decryption.

P2 adds `u`: a signed, relay-visible content sequence, strictly
increasing per `(pubkey, d)`, bumped on **every** publish. The counters
now have disjoint jobs — `v` is the rotation generation, `u` the content
sequence, a rotation bumps both. Grantees fetch from at least two relays
and take the highest `(u, created_at)`, ties broken by lowest event id —
NIP-01's own replacement tiebreak, so readers converge on exactly the
event the relays will keep. They persist a per-scope `(v, u)` high-water
mark and MUST NOT downgrade below it; an event with no `u` compares as
zero, so a pre-`u` copy served after a sequenced one is flagged too.

The honest word there is *detectable*. Rollback becomes visible without
decryption, and multi-relay fanout routes around it whenever any queried
relay carries the newer event. But a relay can still withhold, and a
grantee whose every relay withholds — and whose mark never advanced past
the old copy — gets no signal at all. Withholding, like erasure, is not
something a protocol gets to prevent.

## The cursor that loses mail

Rebuilding an address book meant pulling every `kind:1059` wrap addressed
to you and trial-unwrapping all of them, every time. Half that cost is
intrinsic: the inner kind is encrypted, so no relay can ever be asked for
"grant wraps only." That indistinguishability isn't a defect to fix — it
is precisely the NIP-59 property the protocol rests on, since the grant
graph is the thing being protected. P4 documents it and bounds the rest.

The bound is a `since` cursor plus the Grant Index as a warm cache, and
it contains the sharpest bug of the series. NIP-59 canonically backdates
wrap timestamps by up to two days, so a wrap delivered *after* your scan
can carry a `created_at` older than everything that scan saw. A naive
`since = checkpoint` silently drops those grants — no error, no gap to
notice. The fix reaches back the full randomization window behind the
checkpoint, which makes consecutive scans overlap, which makes
deduplication by wrap id mandatory. Trial-unwrapping is idempotent, so a
forgotten id costs a repeated decrypt and never a wrong answer: the id
set is a cost bound, not a safety mechanism. The cursor lives in the
Grant Index beside the cache it summarizes, written in the same event,
because a cursor that outruns its cache hides grants behind an
already-advanced checkpoint. The test suite proves the miss first, then
proves the fix.

## Raising the price of watching

Gift-wrapping hides the grant graph from a single relay. It doesn't hide
that a stable `d` tag turns a scope's history into a countable series —
*this scope changed 47 times, at these hours* — or that a wrap delivery
followed by a fetch of a specific address correlates grantor to grantee
on the clock.

P6 collects five independent defenses, and the first is the one worth the
argument: **rotate the `d` at rotation time.** It is free. Rotation is
already re-granting every survivor, so the new address rides inside the
same gift wrap as the new key, and a re-granted client follows it exactly
as it would a first grant. The old address is stranded behind an empty
tombstone under a never-granted key; a revoked party watching it sees
ordinary generation supersession and learns neither the new address nor
whether one exists. The content sequence restarts under the new identity
— a continued `u` would be a correlator re-linking the very histories the
move severed — so the high-water mark is keyed per `(pubkey, d)` and MUST
NOT cross the change, or a client false-flags its own publisher for
rollback. Fetch jitter, read-relay separation, coarse size padding, and
decoy updates are the opt-in remainder.

The profile raises an observer's cost; it does not buy unobservability,
and the spec spends a paragraph saying so. The rotation moment is loud:
an observer watching both addresses sees one identity go quiet as another
appears, and links them on timing alone. What item 1 severs is the
*longitudinal* trail. Jitter widens the correlation window without
closing it; padding coarsens size classes without erasing them; decoys
blur which updates are real, not that the publisher is active. Each item
removes one cheap handle. None removes the observer.

## Two devices, one key

Everyone has a phone and a laptop, and a publisher's devices share one
keypair while coordinating only through relays. Two rotating the same
scope concurrently would each naively pick `v + 1` with *different* keys;
survivors re-granted by the loser would read stale forever; concurrent
Grant Index writes would clobber each other outright.

P3 answers with three rules. `v` becomes a **Lamport counter** — max
observed across your own record and what your relays currently serve,
plus one — which cannot prevent a collision but guarantees the generation
never moves backwards once devices see each other. The **deterministic
winner** is whatever NIP-01 replacement already leaves standing (highest
`created_at`, ties to lowest id), so relays and readers converge with no
coordination; the grantee holding the losing key gets a MAC failure and
reads `stale` — detectably, not silently — and MUST be re-granted.
**Reconciliation** is mandatory: on index sync, a device whose issued
`(v, key)` doesn't match the authoritative event re-issues. That last
rule works only because the Grant Index stops being a last-write-wins
blob and becomes a **mergeable** structure — entries keyed by scope or
address, each carrying an `mtime`, merged by union with a per-key max,
deletions written as tombstones so a lagging device cannot resurrect a
revoked grant. Same-`v` rivals union their grantee lists and mark the
survivor conflicted, which is how a collision reaches the one device that
can repair it.

This is convergence for **honest devices sharing a key**, not byzantine
tolerance, and the spec refuses the upgrade: a malicious holder of the
publisher key is not a device to reconcile with. It can sign anything the
key can sign, rotations and index rewrites included, and no client-side
rule constrains it.

## The one that argues with the bet

P1, P2, P4 and P6 all work *within* the bet. P5 argues with it, and so
ships as an experimental parallel track — `kind:31440` beside `30440`,
its own spec document, its own library, nothing in v1 touched.

A scope gets a random 32-byte root key `K`, and each field is encrypted
under a subkey derived from it:
`K_f(g) = HKDF-Expand(K, "nipda/v2/field:" || f || ":" || g, 32)`. The
generation `g` sits *inside* the derivation, which is the whole trick —
it is what lets one field rotate without rotating the root. A grant
carries a *subset* of subkeys, and because HKDF-Expand is a PRF, no
computation on the subkeys you hold reaches `K`, a sibling field, or
another generation of your own. An attenuated grantee cryptographically
cannot read what it wasn't given — against a malicious grantee too — and
an onward re-wrap can only narrow. Revoking one field costs O(that
field's attenuated holders) rather than O(everyone). Field names never
reach the wire: each travels under an opaque derived label, and every
label changes when the root rotates. Even the grant is a new rumor kind
(`442`), because a `440` rumor without a `scope_key` would crash a
conforming v1 reader mid-scan — coexistence by construction beats
coexistence by careful parsing.

The limits are stated as flatly as the gains. Subkeys are still bearer
tokens; a holder can re-share what it holds and nothing sees it happen.
There is **no cryptographic re-delegation control** — a narrowing re-wrap
can be rejected by an honest reader, never prevented — and **no expiry
enforcement**: `expiration` stays advisory exactly as in v1. A
field-revoked holder keeps the manifest key, and with it field names and
generations, until the root rotates. Attenuation also hands the relay a
new leak class: per-label size trajectories and rotation counters, finer
structure in exchange for finer grants, disclosed rather than discovered.
P5 closes the half of the bearer-token weakness that cryptography can
close, and doesn't pretend about the other half.

## Why any of this is believable

The discipline is older than the series. Two independent implementations
— a JavaScript reference library and a Go CLI — share nothing but the
spec, and thirteen cross-implementation assertions run them against real
public relays: each decrypts the other's scopes through the other's
grants, reads the content sequence the other published, recovers an
address book from the other's Grant Index, honors an inbox cursor the
other wrote. Every proposal touching a field the Go side reads had to
land on both sides in the same PR, or the suite went red.

That is what stops a wire format from quietly becoming "whatever the
reference implementation happens to do," and it produced the series'
cleanest compatibility proof: P6's claim that a `d`-rotation demands
nothing of readers was demonstrated by an **unmodified** Go
implementation following a JS rotation to a new address with zero new
code, reading the stranded old one as ordinary supersession. The
discipline also names its own edge — Go doesn't read `31440` yet, so the
v2 suite is JavaScript-only, listed in the spec as an open question
rather than left as an omission.

## What hardening turned out to be

None of the six made the protocol safe from a malicious grantee, and none
was ever going to. What they did was convert vague liabilities into
precise ones: rollback went from invisible to *detectable*; discovery
from O(everything) to bounded, with the timestamp trap that bound
conceals written down; observer correlation from free to merely cheap;
concurrent devices from silently divergent to convergent and repairable;
attenuation from impossible to real for decryption, still absent for
re-delegation.

Every one of those sentences has a second half, and that is the point.
This primitive is fuel for things that inherit its claims — an address
book, a document vault, a tip line, an agent runtime handing scope keys
to software that will read them with no human in the loop — and an
application implying containment the primitive does not provide is a more
dangerous artifact than the weakness itself. Hardening in public means
the review ships in the tree beside the spec, the fixes ship as numbered
proposals anyone can audit, and the limits ship *inside* the normative
text, where whoever builds on it next has to read them.

The bet stands. The bill is itemized, paid where it could be, and printed
on the receipt where it couldn't.

---

*The spec, both reference implementations, the design review, and all six
proposals are public:
[nostr-scoped-data-grants](https://github.com/JAFairweather/nostr-scoped-data-grants).*
