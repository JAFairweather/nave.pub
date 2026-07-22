# Protocol as Fuel

There is a red plastic can on the shelf over my workbench with a yellow
spout, and I am fonder of it than a man ought to be of a container.

Two-stroke mix. Gasoline — a measured pour of oil — the cap back on — then
you lift the whole thing and rock it slow until the color goes even.

Fifty to one.

I love that ratio. And I love that it does not care what you are about to do
with it.

That can feeds the chainsaw — the string trimmer — the blower — and the
little generator I drag out when the power goes. Different machines —
different jobs — limbing a maple off the drive, edging a walk, a night of
lights in the kitchen — and none of them ever asked the fuel what it was
for.

Nobody designs a chainsaw around a fuel can.

You get the fuel right, and the machines show up.

[Nscope](https://github.com/JAFairweather/nostr-scoped-data-grants) is the
fuel. Three hundred lines, give or take, and four kinds of event — the
encrypted scope — the gift-wrapped grant that carries its key — the
revocation — and an index of everything you ever handed out, rebuildable
from your own secret key alone.

You publish a slice of your life under your own key, encrypted. You hand the
key to whoever needs it — wrapped so the relays ferrying it learn nothing.
And they read your current version, always, because there is only ever a
current one.

When you want somebody out, you do not edit a row in a table on somebody's
server. You rotate the key — republish — re-grant everyone still invited —
and the one you dropped is holding a key that opens nothing.

The signature is the authorization. The rotation is the revocation.

Now the part the spec says out loud, in the normative text, where nobody
skips past it.

Whoever already read it, read it.

No protocol takes a memory back. A rotation stops the next read and only the
next read, and the honest place for that sentence is the first page — not
the middle of somebody's divorce.
[Ntrigue](https://github.com/JAFairweather/ntrigue) is that sentence played
for money — a phones-only party game where every answer is an encrypted
scope, and the design law is that you can revoke a secret and still not
un-tell it.

Then the other choice, which I got right for the wrong reason.

Every operation in the library takes either a raw secret key or an object
shaped like a signer — give me your public key, decrypt this, sign this. I
wrote it that way on the first day because it was two extra lines and it
felt tidy. And it is now the only reason a web page can issue grants as a
real human being, with the secret never entering the tab.

Designed in before it was needed.

Then needed everywhere.

[Nontact](https://github.com/JAFairweather/nontact) went first. An address
book is not a database — it is the sum of what people currently grant you.
Update your card once and every holder reads the new truth. Move — change
your number — drop somebody entirely. One edit.

[Nvelope](https://github.com/JAFairweather/nvelope) carried it to files. A
shared folder is a scope, so revocation replaces the expiring link and
recovery needs your key alone. And payloads too fat for an event ride
encrypted on Blossom with their key delivered by grant — same wire, bigger
cargo.

[Nherit](https://github.com/JAFairweather/nherit) pointed it at time. One
estate record in per-beneficiary scopes — heirs holding grants you can pull
back while you are alive — the whole thing reconstituting from a square of
paper in a fire safe. Nothing between you and your family to be breached, or
sold, or sunset in thirty years.

[Notegate](https://github.com/JAFairweather/notegate) pointed it at a
newsroom. A tip line is a keypair. A source is a key her own browser minted,
whose only way back is twelve words she writes on her hand. And
proof-of-work is the toll at the door, paid before anything is decrypted,
and the grant index is the case docket.

[Noir](https://noir.nave.pub) asked whether the primitive could carry a
whole game with no other trust system in the building. Documents are scopes,
and discovery is a gift wrap. A burned contact is a key rotated past you,
and you feel it. And whole eras arrive as pure data over the same wire,
gated by a prover that makes the game prove itself fair before it deals a
card.

[Nvoy](https://nvoy.nave.pub) is where the grantee stopped being a person.
Handing your calendar to software is the moment permission stops being
manners and starts being survival, and a token has the wrong shape for it —
it delegates access into a system that keeps your data. Nvoy delegates the
data — encrypted to the agent's own key — dereferenced live at run time —
severable in one keystroke. And the agent finds out on its next read. So it
mounts as an MCP server, and anything that speaks MCP reads a grant knowing
nothing about nostr.

Terms ride along on the grant — purpose, expiry, do not persist — and those
are asked for, not enforced by arithmetic. But the lever that is actually
yours is the rotation. That is written down too.

Then the other direction, because seeing is only half of what you delegate.
[Nact](https://nact.nave.pub) is the half about doing. An agent drafts an
action, you look at it, you tap — and your signature is the thing that puts
it on the wire. Its runtime, Nactor, keeps credentials in memory and hands
one out against a signature, so an agent invokes a key it never holds. Every
live credential in the fleet arrived as a grant. And the engine running the
models holds none of them.

Then the arrow turned around, which I did not see coming.

[Ngage](https://ngage.nave.pub) is a desk where my agent grants drafts to
me. Each post it writes is a scope in a draft namespace, gift-wrapped to my
identity — and it reaches the desk only after the seal's verified signer
matches the author named inside — the scope is a draft and nothing else —
the grant came first-hand — and that hand is on a list I keep myself.

An empty list shows me nothing.

Then I read the exact note. Then my key signs it.

Nothing my agent writes can speak in my voice until my own hand moves.

[warm.contact](https://warm.contact) is the one that started before the
protocol did. People wave at you, their card lands in your book, and the
relay only ever brokers ciphertext — it cannot read who is contacting whom,
structurally, not as a promise. But the half that stalls is the reply.
Everybody has that list.

Quill writes the first draft of every one of them. Not a shared assistant
holding one big key — an agent minted for you, under your own identity —
carrying your voice and your credentials in a bundle you signed over —
drafting on your own machine, so your people's names never cross anybody's
infrastructure. And it knows who has been waiting longest. It refuses to
invent a history it was not given. And it never presses send. So you read
it, fix the one word that is not yours, and it leaves from your Messages
under your name.

The drafting is done and tested. The identity it runs under is the next
thing I build.

It is Luke, for everyone.

Cockpit and Console are the two rooms where my agent's whole life is legible
— his beats, his activity, every file he loads and the order he loads them
in. Neither has a password, because neither has anywhere to type one. A gate
that opens on one signature, and it has only ever opened on mine. Nops is
that idea turned on the box underneath — deploys, secrets, health —
authorized by a scoped grant of allowed verbs and a signed approval instead
of a key parked in a CI vault. It is drawn and proposed, not built. What
runs today is the right shape over the wrong transport, and I would rather
say so.

Three boxes carry all of it. One management key opens them — passwords are
off everywhere — and the sovereign key lives alone in a bunker on its own
machine, encrypted, lending out signatures and never leaving.

On the twentieth of July a stale firewall rule woke up on that box, flushed
Docker's own chains on reload, and took the bunker down. And then Docker
would not start at all. The fix was not a better rule — firewalld is gone
from every Docker host I own, replaced by a firewall that lives on the box
and asks a hosting panel for nothing, with the ban written down where the
next man has to read it.

So what does one bearer key cost?

A design review of the spec — filed in the same repository as the spec it
criticizes — came back with six weaknesses. Real ones. And every one traces
to a sentence at the bottom of the design: a scope is protected by one
symmetric key, handed to grantees as a bearer token.

That bet is why the thing runs today, on stock public relays, without anyone
agreeing to anything first.

And the six proposals are what it looks like to read a bill line by line —
verify who authored a grant instead of trusting the wrapper — put a second
counter outside the envelope, so a withholding relay cannot hand you last
week quietly — reach back behind your own cursor, because gift wraps are
backdated on purpose and a friend lands in the gap — rotate the address
alongside the key, so a stable name stops being a countable series — keep
your phone and your laptop from rotating past each other — and split a scope
into per-field keys, so revoking one drawer costs you the drawer and not the
house.

All six are in the spec now. Five rewrote its normative text, and the sixth
ships beside it — a new kind of event, its own document, its own library —
so nothing already running had to move.

And two implementations that share nothing but that document — a JavaScript
library and a Go command-line tool — run thirteen assertions against each
other on live public relays, each reading the other's scopes through the
other's grants. That is what keeps a wire format from becoming whatever the
reference implementation did last Tuesday.

The same discipline is queued on the action side. Freeze what will be signed
the moment it is proposed, and re-check its fingerprint before a key touches
it. Render it faithfully — the kind, the tags, the hidden characters
somebody slipped in. And make the dangerous kinds cost more than one
careless thumb.

Then Buzz, which is the next room and not yet a room of mine. A workspace
where people and agents sit in the same channels on a relay you own, every
message and every review and every commit landing as a signed event in one
log. Same identity model. Same audit trail. Whether or not the author
breathes.

And I forked it because that is where I want all of this to end up. My
people and my agents in one place, with the can already mixed.

So mix the fuel first.

Get the small thing right — write down what it cannot do while you are still
proud of it — and then go watch what other people bolt onto it. They will
bring machines you never imagined, and never once thank the can.

That is how you know it worked.

And whoever you have been meaning to write back for a month is still
waiting. Do that part in your own hand.
