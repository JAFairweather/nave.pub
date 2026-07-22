# Scoped autonomy: one nostr primitive, a whole ecosystem

*How a single signed, revocable data grant turned into contacts, files, secure intake, a legacy vault, two games, and an agent runtime — all speaking the same protocol.*

---

Here's a sentence that sounds like it can't possibly be literally true: I built a contacts app, a secure document vault, a whistleblower tip line, a family inheritance system, a spycraft mystery game, a party game about blackmail, and an AI agent runtime — and they're all the same nine lines of cryptography wearing different clothes.

It is literally true. And the reason it's true is worth explaining, because the idea underneath it is small enough to fit in a paragraph and general enough to swallow an entire product category.

## The idea

Start with what nostr actually is, stripped to the studs: a way of publishing signed messages ("events") to a set of dumb relay servers that don't know or care what's in them. Your identity is a keypair. You sign things with your private key; anyone can verify the signature with your public key. Relays store and forward bytes. That's it — no accounts, no platform, no server that has to trust you.

Now add one more move. Take a blob of data — a document, a contact record, an API credential, a clue in a mystery game — encrypt it under a random 32-byte key that has nothing to do with your identity key. Publish the ciphertext to a relay as an ordinary nostr event. Then, separately, hand the *decryption* key to exactly the people or agents you want to be able to read it, wrapped in a gift-wrapped, unlinkable event only they can open.

That's the whole primitive. It's called a **scoped data grant** — the draft spec is `nostr-scoped-data-grants` (NIP-DA), currently PR #2411 against the nostr protocol's own NIPs repository. Four event kinds carry it: **30440** is the encrypted data set itself; **440** is the grant — the gift-wrapped handoff of the scope key to a recipient; **441** is a revocation; **10440** is a grant index, recoverable from nothing but your own private key, so you can always reconstruct who you've granted what even if you lose every other record. Two independent reference implementations — a ~200-line JavaScript library and a Go CLI — have been built and verified to interoperate live against public relays. One client encrypts, the other decrypts, no coordination beyond the spec.

What makes this more than "encrypted file sharing" is what happens when you want to take access back. There's no server-side ACL to flip, no token to expire, no admin panel where someone clicks "revoke." You publish a new key-rotation event. The old scope key is dead. Anyone still holding it can decrypt the *old* ciphertext they already saved — you can't unsee a secret, and no cryptosystem pretends otherwise — but they get no more updates, ever, from that point forward. This is the idea in its sharpest form, and it's the creed the whole ecosystem drafts from:

> *The signature is the authorization; the rotation is the revocation.*

No password reset flows. No "please contact support to remove access." Just keys.

## The spine: perceiving and acting are the same shape

Once you have scoped, revocable grants for *data*, a second question falls out almost immediately: what about *actions*? An AI agent reading your calendar is a perceive problem — solved by the grant above. An AI agent booking a flight on your calendar is an act problem — a different shape entirely, because now something needs to happen in the world, not just be read.

This is the spine the whole ecosystem is built on: **perceive** (data flowing in) and **act** (actions flowing out), as two directions of the same underlying trust problem, each with its own protocol-in-progress.

On the perceive side: Scoped Data Grants (NIP-DA) is real, spec-complete, and interoperable today. On the act side: **Scoped Action Approvals** is deliberately *not yet* a NIP — a sketch, built-first, with the one thing worth standardizing already identified: a verifiable `["approval", id, approver]` tag that's public proof an agent's action passed an actual human tap before it went out. Rather than speculate a spec into existence, the working system — propose, human-approves, sign, enact — runs today on existing nostr primitives (gift-wrapped DMs and remote signing), and the NIP gets written only if and when other clients need to interoperate with it.

The runtimes mirror the split. **Nactor** is the act-side runtime — built, running a V1 HTTP API gated by signed requests, holding a proposal queue and role keys, currently juggling four live identities and seven credentials. **NCP** (Nostr Context Protocol) is the perceive-side runtime, still mostly a concept — except for one piece that's real: a transparent egress proxy that injects a credential from RAM into an outbound API call, so the calling code never touches the secret at all. It's the "missing quadrant" — the thing that would let an agent *read* a data grant the same principled way Nactor lets it *act* on an approval.

And sitting in the middle of both directions is **Nvoy** — connective tissue that cuts both ways. It's the client that feeds ordinary agents their scoped data. It's *also* the mechanism by which the act-side runtime gets fed its own configuration, as a grant like any other. The perceive machinery isn't just a peer of the act machinery — in Nvoy's case it's literally how the act machinery gets configured.

## One protocol, seven apps, none of them special

Here's the part that still surprises me every time I list it out: every application in the ecosystem is a *pure client* of the data-grant primitive. None of them reimplement access control. None of them run a server that has to be trusted with plaintext.

**Nontact** is the most literal reading of the idea — a "no-maintenance" address book where nobody maintains contact data about anyone else; each person's record is self-maintained and shared out as scopes, so the address book you see is an *emergent view* over grants, not a copy anyone owns. **Nvelope** takes the same primitive and points it at documents — live folders with real revocation, large files handed off through Blossom blob storage while the manifest itself stays a scoped grant. **Nherit** points it at your death: a family legacy vault with three tiers, from live day-to-day grants down to a dead-man's-switch escrow daemon and a SLIP-39 paper Shamir backup you could reconstruct an entire estate from with nothing but a printed QR code. **Notegate** points it at journalism — a serverless secure tip line where proof-of-work gates spam, gift-wrapping hides sender identity, and timing jitter defeats traffic analysis, with no server ever holding a readable tip.

Then it gets playful. **Noir** is a nostr spycraft mystery game where the clues literally *are* scoped data grants — intel you've earned access to — and a wrong move burns an asset by rotating its key, which lands as a genuinely felt "burn notice," not a UI toast. Its game-master Director is, itself, just another Nvoy-speaking agent — the game doesn't get a special backend, it gets the same client library as everything else. **Ntrigue** takes the same bones to a phones-only party game about secrets and blackmail, where the tagline writes itself: you can revoke a secret, but you can't un-tell it — which is just the honest physics of the crypto, dramatized.

And then there's **Nvoy** again, this time in its main role: scoped, revocable data delegation to *AI agents specifically*, mounted as an MCP server with seven tools, so any MCP-speaking assistant can be handed exactly the slice of your data it needs — and cut off mid-conversation, live, with the access disappearing while the agent is mid-sentence. That's not a hypothetical; it's a working demo.

None of these seven apps needed a bespoke backend. Every one of them is contacts, files, or games wearing the same underlying grant.

## The agent, wearing the same clothes

The natural endpoint of "data flows in as scoped grants" is an agent that lives entirely on top of that flow — and that's **Luke**, the flagship agent, James's own. Luke drafts social posts from a voice corpus, proposes them, and only ever posts after a signed human approval comes back through a Telegram approval card — propose, approve, sign, broadcast, the act-side loop made concrete. Luke runs a calendar beat, a heartbeat, nightly memory consolidation, and drafts email without ever being allowed to hit send unsupervised. Luke is not a special case bolted onto the ecosystem; Luke is the pattern — *a per-person brain that drafts in your voice from granted credentials* — that everything downstream, including a second agent built for other people entirely, ends up generalizing.

The credential story underneath Luke follows the same logic as the data grants: authority is always a Director-signed grant carried by an *identity*, never a permission bit sitting on a box somewhere. There are two ways a credential actually gets consumed — brokered, where it stays on-box in RAM and a trusted runtime uses it on the agent's behalf, or granted directly to the app, where the agent's own identity holds the key and calls the provider itself. Which mode applies isn't a taste call — it's decided by two questions: is the content sensitive, and is the consumer off-box? Either yes tips it to grant-to-app; both no keeps it brokered. Same primitive, same signature-as-authority logic, just governing secrets instead of documents.

## The frontier

Everything above is perceive-and-act as two separate lanes, each protocol solving its half. The frontier — sketched but not yet built — is what happens when those lanes merge: **a single signed request that is simultaneously a grant and an enact.** Ask an agent to book a meeting, and in one exchange you've both handed it the calendar data it needs to see *and* authorized the write it needs to make — one signature, one scope, one revocation that kills both halves at once. Extend that far enough and providers themselves become first-class participants over NIP-05 identities, with revocation chaining across every provider a grant ever touched, instead of stopping at the first hop.

That's still ahead. What's already true is the harder-to-believe part: an idea about encrypting a blob and handing out the key turned out to be sufficient scaffolding for an address book, a document vault, a tip line, an inheritance system, two games, and the agent that ties an entire digital life together — with revocation, everywhere, meaning exactly one thing: you rotated a key.
