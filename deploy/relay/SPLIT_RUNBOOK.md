# NIP-46 transport split (nave.pub#130)

Splits the bunker's NIP-46 transport (kind 24133) off relay.nave.pub onto its
own relay, transport.nave.pub. Fixes two things a full anonymous read of
relay.nave.pub turned up (nave.pub#130):

- **an open write channel** — 24133 is accepted from any key on relay.nave.pub
  today, necessarily, since a NIP-46 client's ephemeral key can't be
  allow-listed in advance. That carve-out lands on the same relay that holds
  the grant plane.
- **a metadata firehose** — anyone who reads relay.nave.pub can see the
  bunker/client signer pair and every one of their round-trips (866 of them,
  in the original audit), which is a live activity feed even though the
  payloads are encrypted.

This does **not** add read authentication to relay.nave.pub — strfry doesn't
speak NIP-42 and there's nothing to gate reads with. It removes the two things
that made open reads matter beyond the grant plane's own (already-encrypted,
already-scoped) content. `docs/sovereign-signing.md` named this split as the
fallback when the relay was first built; #130 is the trigger to actually do
it.

## Order — do not skip or reorder

| # | Script | Touches | Risk |
|---|---|---|---|
| 1 | `split-01-nip11-fix.sh` | strfry.conf (description only) | none — no write-policy change |
| 2 | `split-02-bring-up-transport.sh` | new `strfry-transport` service, Caddy | none — main relay untouched |
| 3 | `split-03-verify-and-repoint.sh` | bunker dashboard (**manual**) | none from this script; the manual step is where a mistake would show up before it matters |
| 4 | `split-04-cutover.sh` | allowlist.json `allowKinds` on relay.nave.pub | **the one step that can break signing** — gated behind `CONFIRM=1` |
| 5 | `split-05-rollback.sh` | reverts step 4 | use if signing breaks after cutover |

Each script prints what it verified and what to run next. Steps 1–2 are safe
to run back-to-back. Do **not** run step 4 until you have personally watched a
real sign approval succeed through transport.nave.pub in step 3 — not "the
dashboard saved," an actual phone approval that completed.

## Prereqs only you can do (same pattern as the rest of deploy/)

- **DNS:** point `transport.nave.pub` at this box (same IP as
  `relay.nave.pub` / `bunker.nave.pub`) before step 2.
- **`nak`** (https://github.com/fiatjaf/nak) on the box, for the automated
  smoke tests in steps 3 and 4. Without it those steps skip the automated
  checks and fall back to telling you what to check by hand.

## Gate before step 4: every paired client must already use the transport relay

A bunker URI carries its relay (`relay=` parameter), and a paired client
keeps using the relay it was paired on. Moving the dashboard's signer relay
list (step 3) does not move clients that are already paired. The nvoy
fleet brokers keep their pairing in `/etc/nvoy/credentials/<name>.bunker-uri`
on the fleet host. After step 4, a broker whose URI still names
relay.nave.pub cannot sign at all.

So, before step 4:
- re-issue each connection from the dashboard so its URI names
  transport.nave.pub, and replace the fleet credential files;
- restart each broker;
- have each broker sign once and check that the signature comes back.

The bunker's `bunker_connections` table lists the clients that need this.
Check the URIs by their relay parameter only, and never print a whole URI:
it carries the pairing secret.

## What step 4 actually flips

`allowlist.json`'s `allowKinds: [24133]` is what lets any key write 24133 to
relay.nave.pub — it's config, not code, already read live by write-policy.py
on every event. Step 4 sets it to `[]` and restarts strfry; nothing else
changes. That's why rollback (step 5) is just "put it back and restart" — no
rebuild, no redeploy, no git revert required to recover.

## After cutover

- relay.nave.pub: fleet-authored events and recipient-addressed gift wraps
  only. No more anonymous 24133.
- transport.nave.pub: kind 24133 only, from anyone, rate-limited per author
  (`write-policy-transport.py` — see its header for why the limit lives there
  and not on the main relay).
- Update the bunker's signer relay list (done in step 3) and, once you're
  confident it's stable, consider removing `relay.nave.pub` from that list
  entirely rather than keeping it as a fallback — it no longer accepts 24133
  after step 4, so keeping it listed just adds a dead connection attempt.
