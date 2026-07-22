# Quill: giving every person their own agent, not a shared one

*Everyone has a list of people they mean to get back to and never do. Here's an agent that writes the first draft — one minted for you, holding only what you gave it, that never presses send.*

---

You know the list even if you've never written it down. The friend from a job three roles ago who sent a genuinely warm "hey, saw this and thought of you" message four months back. The person you met at a conference who followed up and you meant to reply to that same week. The relative who texted a photo and got a thumbs-up emoji instead of an actual reply. None of these are hard replies to write. That's what makes them so easy to never write — there's no crisis forcing the issue, just a small, accumulating debt of warmth you owe people who reached out first.

That gap — not "I don't have contacts," but "I have replies I'm never going to sit down and compose" — is the problem **Quill** is built to close.

## The setup: an address book that doesn't spy on you to work

Quill lives inside **warm.contact**, a contact-collection app built around an inversion that's worth sitting with: instead of you maintaining records about other people (the normal address-book model, and the reason your contacts list is full of stale phone numbers and guessed birthdays), warm.contact is *inbound-first*. People wave at you — send you their own card, their own way of saying "here's how to reach me" — and it lands in your address book. Nobody's compiling a dossier on anyone; each person's record is theirs, self-maintained, shared out as a grant, not copied and gone stale.

The privacy model backing this isn't a feature bullet, it's structural. warm.contact runs its own `wc1` sealed-box crypto (elliptic-curve Diffie-Hellman on P-256) such that the *relay itself never sees plaintext* — it only ever brokers ciphertext between two parties who can decrypt it. Zero-knowledge isn't a marketing claim here; it's the thing that makes the app's entire threat model coherent: even the infrastructure operator can't read your contact card if they wanted to.

That's the inbound half, and it's solid — shipped, live, doing its job. The outbound half — actually replying — is where every human, regardless of how good their intentions are, quietly fails. That's the gap Quill fills.

## The engine already exists

Before there was a plan for Quill's identity, there was a working engine, and it's worth being precise about what's actually shipped versus what's still a design on paper, because the honest version is more interesting than the hand-wave.

`WarmCore/Rekindle.swift`, together with `Reconnect.swift` and `ReconnectPriority.swift`, is real, tested code — 59 green tests. It takes a person (a `ReconnectItem`, carrying whatever's known about them and your specific history with them) plus a shared voice profile (a `ReconnectProfile`, carrying a narrative of what you've been up to, your sign-off, your home region) and calls Claude directly from the Mac, no relay in the path, to produce a structured, channel-appropriate draft reply.

The guardrails aren't an afterthought — they're pure functions with their own unit tests. The engine is instructed to use only facts it was actually given and never invent shared history it doesn't have; to open by acknowledging that *they* reached out, not the other way around; to include exactly one light call-to-action matched to what they actually seem to want (a hello back, coffee, a meetup); to respect channel-appropriate length; and to include a genuine "how are you" beat rather than launching straight into logistics. When it doesn't have enough to work with, it says so — flagging `insufficient_context` — rather than papering over the gap with something plausible-sounding but made up.

And critically: it never sends. Draft, you review, you edit if you want to, you approve, and then it hands off to your own iMessage or Mail — an `sms:` or `mailto:` link that opens your own composer with your own account, never a `noreply@` address pretending to be you. Once you've sent, the card flips from "Warm" to "Warm-Contacted" and drops out of the queue. There's also a `ReconnectPriority` layer that ranks who to answer first, with a plain-English reason attached — draft ready, brand new, they've been waiting N days, overdue, or someone nearby — so the person who's waited longest doesn't quietly fall to the bottom of an unordered list.

So: the actual hard part, generating a warm, honest, non-fabricated reply in your voice, is done and tested. What's missing is everything around it that makes it *yours* in the way the rest of this ecosystem means that word — a real identity for the agent, and a clean, revocable way for it to hold what it needs instead of an API key pasted into a Keychain entry.

## Every person gets their own agent, not a seat in a shared one

Here's the design decision that makes Quill more than "a nice Swift feature": Quill isn't one shared assistant serving every warm.contact user from a common backend. Every user gets their own **Quill** — a distinct nostr identity, minted specifically for them, holding only their own credentials and their own voice.

The user, in turn, has their own identity too — either warm.contact mints one for them at signup (true for almost everyone, since most people using this app have never thought about nostr and shouldn't have to) or, for the nostr-native minority, they bring their own key. Either way, the user is the **Director** — the root of authority their own small estate chains up to, the same relationship James's own root identity has to the rest of the fleet he runs. The user's identity issues Quill a scoped grant. Quill can only ever do what that grant says. If the user ever wants Quill gone, they rotate the key, and every credential Quill was holding dies with it in one motion — not a support ticket, not an admin flipping a database flag, a signature.

This is the same shape as **Luke** — the agent that already exists for one specific person, drafting posts and managing a calendar and email from credentials that were explicitly granted to it. Quill is that exact pattern, generalized: not "build Luke again for a second person," but "make the Luke pattern into infrastructure so any user gets one." The project's own one-line pitch for this puts it better than a longer explanation would: *it's Luke, for everyone.*

## What Quill is trusted with — and why it isn't brokered

The credential question here has a specific, deliberate answer, and it's worth explaining *why*, because the obvious-sounding alternative was seriously considered and rejected.

The obvious alternative: route Quill's calls to Claude through the same shared, on-box credential broker that other agents in the fleet use — hold the API key centrally, in RAM, and let a trusted runtime make the call on the agent's behalf. That's a perfectly good pattern elsewhere in this ecosystem, and it's the default for on-box agents whose work doesn't touch sensitive content.

It's wrong for Quill specifically, because of what's actually inside the prompt Quill sends to Claude: a contact's name, the note they sent you, whatever shared history is known. That's exactly the plaintext warm.contact's entire architecture is built to keep off shared infrastructure. Routing it through a central broker — even briefly, even in transit, even with good intentions — would put contact plaintext through multi-tenant infrastructure that the rest of the app goes to real lengths to keep it away from. It would be a structural crack in the zero-knowledge promise, not a small one.

So the decision is **grant-to-app, applied uniformly**: Quill's own identity holds a scoped, NIP-44-encrypted credential — the Anthropic key, a read-only Gmail app password for history — decrypted locally with Quill's own key, on the user's own device, and calls the provider directly. Nave, the broader system, sees that a grant was issued. It never sees what's inside a draft. Only Anthropic ever reads the actual prompt, which is exactly the same trust boundary the product already discloses today — just formalized as a grant instead of a pasted-in secret.

There's a nice bit of software hygiene backing this up, too: the app already has `WarmCore/SecretVault.swift`, an abstraction that just means "give me a secret" without caring where it comes from — Keychain today, something else tomorrow. Making Quill's credentials arrive as decrypted grants instead of typed-in passwords means adding one new implementation behind that interface. No calling code has to change.

## The one genuinely new thing in the profile

The profile bundle Quill drafts from is mostly an extension of what already exists — `narrative`, `signature`, `homeRegion` are all already fields on `ReconnectProfile`, doing real work today. The one field that's actually new is a **Calendly link**. Add it to the bundle, and a reply that would otherwise end on a vague "let's find a time" can instead close with an actual bookable link — turning a warm reply into a scheduled meeting with zero back-and-forth. Small addition, disproportionate payoff: it's the difference between "I'd love to catch up" as a sentiment and as a calendar event.

## What's still open

None of this is finished, and it's worth saying plainly which parts aren't. The Nave side needs to confirm that a per-user identity — itself just a grantee, one hop down from the fleet's usual patterns — can re-issue its *own* scoped sub-grants correctly; that's the same missing piece the broader credential-migration work is separately blocked on, so the two efforts unblock each other rather than one waiting on the other. The Swift agent itself doesn't yet have the client-side crypto it needs — NIP-44 decryption and NIP-98 signing haven't been built into the app yet. Nobody has designed the actual signup-time bootstrap: how a new user's Quill identity gets minted or matched to a bring-your-own key, how its npub gets registered, how the first grant actually gets issued. And at real scale, "how do you register, scope, and revoke a Quill npub for thousands of users" is an open lifecycle question, not a solved one.

What's true today is narrower but real: the part that's hardest to get right — writing a reply that sounds like you, uses only what it actually knows, and never invents a shared memory that didn't happen — works, and has 59 tests proving it. What's left is entirely about identity and plumbing: giving that engine its own key, its own name, and a way to hold what you give it that you can take back with one signature, any time, for any reason, no conversation required.

Everyone has that list of people they mean to get back to. Quill doesn't get you off the hook for actually caring. It just makes sure the caring has somewhere to start from besides a blank text box at eleven at night.
