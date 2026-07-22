# Hardening a protocol in public

There is a wall at the back of every good hardware store that I have
never once walked past. Key blanks — hundreds of them — brass and nickel
on little hooks, sorted by a numbering system only the man behind the
counter understands.

Hand him yours and he looks at it for a second, then reaches without
counting.

Then the machine. The vise — the tracer riding your old key while the
wheel cuts the new one — the small arc of sparks — the burr he takes off
with a wire brush before he hands it back warm.

I love that whole ritual.

And I have handed out a lot of keys that came off that machine — to a
neighbor before a long trip — to a contractor I met exactly once — to a
kid who would be home before I was.

Not one of them ever asked the person holding it who he was.

That is not a flaw in the key. That is the entire reason a house works.

Bearer — the one who carries. Not the owner, not the name on the deed,
not the person I had in mind at that counter. The one whose pocket it is
in when the door comes up.

Now, a protocol.

[NIP-DA](https://github.com/JAFairweather/nostr-scoped-data-grants) is a
small nostr primitive for handing somebody scoped, revocable access to a
slice of your life — a contact list — a folder — one field on one
record. And the sentence at the bottom of its design is the sentence on
the hook by my back door.

A scope is protected by one symmetric key, handed to grantees as a
bearer token.

That bet is why the thing is usable at all. One key over one payload
means the encrypted data does not grow when your circle does — twelve
grantees or twelve hundred, the same ciphertext. It means an update is
free. Republish, and every grantee reads the new truth the next time it
looks.

And it asks a relay for nothing beyond plain addressable events, which
is why it runs today, on stock public relays, without anyone agreeing to
anything first.

A careful design review of that spec — committed to the same repository
as the spec it criticizes — came back with six weaknesses.

All six trace to that one sentence.

None of them were mistakes. They were the bill for the key, itemized.

And the six proposals that followed are what it looks like to read a
bill line by line — pay the lines that can be paid — and print the rest
on the receipt where whoever comes next has to read it.

Start with the copy. A man I handed a key to can have another cut off it —
same wall, same machine, same warm burr — and that key opens my door,
and it always will, and no lock ever made can tell the two apart from
the inside.

A grant here is an unsigned rumor, sealed and gift-wrapped, and the
author it authenticates is the pubkey on the seal. When that author is
not the publisher named inside the grant's own address, what you hold is
a re-wrap — a grantee re-gifting a key it was given. And it is
cryptographically identical to somebody walking off with mine.

The spec said nothing normative about that.

So the comparison is a MUST now. Re-wraps are rejected by default, and
where a deployment allows one the different author stays on the record.

You cannot stop a man from having your key copied. You can stop a
program from telling you the key came from me.

Then the old copy. Replacement is what keeps a grant alive, but a
content update never touched the rotation counter. So a grantee talking
to one withholding relay could sit forever on an event that was stale
and perfectly valid and perfectly signed all at once.

The only evidence of freshness sat inside the ciphertext. Invisible
until after you had decrypted it and believed it.

So there is a second counter on the outside of the envelope now.

A signed, relay-visible content sequence, bumped on every single
publish. The two counters have disjoint jobs — one is the generation of
the key, the other is the sequence of the content — and a rotation moves
both.

A grantee asks two relays and keeps the highest, ties broken the way
nostr already breaks them. So a reader lands on the event the relays are
going to keep anyway. And it writes down a high-water mark that it will
never go beneath.

You cannot stop a relay from withholding. You can make it impossible for
one to lie to you quietly.

Then the mail. Rebuilding an address book meant pulling every gift wrap
ever addressed to you and trying to open all of them, every time. Half
that cost is the property and not the defect — the inner kind is
encrypted, so no relay can ever be asked for just the grants.

The grant graph is the thing being protected. You do not get to ask the
guard to sort your secrets for you.

The other half is a cursor, and it hid the sharpest bug in the series.
Gift wraps are backdated by as much as two days on purpose. So a wrap
that lands in your inbox after a scan can carry a timestamp older than
everything that scan saw.

Set the cursor to the checkpoint and those grants are gone.

No error. No gap. Just a friend who wonders why you never picked up.

So the fix reaches back the whole window behind the checkpoint — which
makes consecutive scans overlap — which makes deduplication by wrap id
mandatory.

The test suite proves the miss first. Then it proves the fix.

Then the man across the street. A gift wrap hides who I gave a key to.
But it does not hide that a door with a stable name becomes a countable
series — this one opened forty-seven times — at these hours — on these
days. Or that a delivery followed by a fetch of one address puts a
grantor and a grantee on the same clock.

So rotate the name of the door when you rotate the key.

It costs nothing. A rotation is already re-granting every survivor, so
the new address rides inside the same gift wrap as the new key. The old
one is left behind an empty tombstone under a key nobody was ever given,
and a revoked party watching it learns neither the new address nor
whether one exists.

An observer is a man with a budget. Fetch jitter widens the window he
has to correlate across — read-relay separation splits the picture
between parties who each hold half — coarse padding blurs the size
classes — decoy updates blur which of them are real. Every one of those
raises what he has to spend. What you take off the table is the long
trail behind a scope.

He is still standing there.

Then your other hand. Everybody has a phone and a laptop, and a
publisher's devices share one keypair while speaking to each other only
through relays. Two of them rotating the same scope at the same moment
would each reach for the next generation holding a different key, and
the survivors re-granted by the loser would read stale forever.

Mr. Lamport wrote the answer to that in 1978 and it still fits in a
sentence. The generation becomes the highest one you have seen anywhere
— your own record joined with whatever your relays are serving right now
— plus one.

Collisions still happen. The generation never walks backwards once two
devices have laid eyes on each other.

The winner is whoever nostr replacement already leaves standing, so
relays and readers converge with no coordination at all. And the grantee
holding the losing key gets a MAC failure and reads stale — out loud,
not silently — and gets re-granted.

On the next sync, a device whose issued key does not match the
authoritative event issues again. Which only works because the index
stopped being a blob you overwrite and became something you merge —
entries keyed by scope — deletions written as tombstones so a lagging
device can never resurrect a grant you revoked.

That is convergence between honest devices holding one key. A key still
does not know which of your hands it is in — the hook by the back door,
arriving again. Whoever holds the publisher key can sign a rotation and
rewrite an index, and nothing written on the client side reaches him.

The sixth one goes after the key itself.

It ships as a parallel track — a new event kind beside the old one — its
own spec — its own library — nothing in v1 touched. A scope gets a
random 32-byte root, and every field is encrypted under its own subkey
derived from that root, with the generation sitting inside the
derivation.

That is the whole trick. It is what lets one field turn over without
turning over the root.

A grant carries a subset. The derivation is a pseudorandom function, so
nothing you can compute from the subkeys in your hand reaches the root,
or a sibling field, or another generation of the field you were handed.

So revoking one field costs you the holders of that field instead of
everybody. And field names never touch the wire — each travels under a
label that changes when the root does.

A subkey is a key. Whoever holds one can hand it on, and nothing sees
that happen.

What the tree does is make the key smaller — one drawer instead of the
house — and a small key is the only kind worth handing to software that
will read it with nobody in the room.

Why should you believe any of it?

Because there are two implementations of this protocol that share
nothing but the spec — a JavaScript library and a Go command-line tool —
and thirteen cross-implementation assertions that run the two of them
against real public relays. Each decrypts the other's scopes through the
other's grants — reads the sequence the other published — recovers an
address book out of the other's index — honors an inbox cursor the other
wrote.

Any proposal touching a field the Go side reads had to land on both
sides in the same pull request, or the suite went red that afternoon.

That is what keeps a wire format from quietly becoming whatever the
reference implementation happened to do last Tuesday.

And it produced the cleanest thing in the series. The claim that
rotating a door's name asks nothing of readers — shown by an unmodified
Go client following a JavaScript rotation to a brand-new address with
zero new code, reading the stranded old one as an ordinary supersession.

Grant — to hand a thing over. And, says Oxford, to admit that a thing
is so.

So hand out the key. Then sit down and write what it costs to hold one.

Not in the blog post — in the normative text, where whoever builds the
address book and the vault and the tip line and the agent that reads
your calendar at three in the morning has to read it before he can use
your work.

I promise you he will build something better on it than the thing you
had in mind.
