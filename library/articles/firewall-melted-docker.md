# The day firewalld melted Docker: a self-hosting war story

*A stale rule, a wedged daemon, and the on-call debugging arc that ends with "never run firewalld on a Docker host" tattooed somewhere permanent.*

---

It started, as these things do, with a 502.

The bunker box — the hardened server holding the sovereign nostr key that everything in the fleet ultimately chains up to — went dark. Not slow, not flaky. A flat 502 from the edge proxy, the kind that means "something behind me isn't answering," which in a Docker-based stack usually means one container fell over and you restart it. I've done that a hundred times. This was not that.

## The false start

First read on the situation: the container's down, restart it. Except restarting it required Docker, and Docker wouldn't come up. Not "container crash-looping" — the *daemon itself* refused to boot, throwing `INVALID_ZONE: docker`. Docker manages its own iptables rules through a zone it expects to own outright. Something had reached in and taken that zone away from it.

The something was `firewalld`. It had been running alongside Docker on the box — a decision nobody had consciously made, more an artifact of the box's provisioning defaults than a choice — and at some point a stale `--permanent --direct` rule had wedged it into a FAILED state. When it next reloaded, it flushed Docker's own iptables chains out from under it. The `DOCKER-FORWARD` chain Docker depends on to route traffic between containers simply wasn't there anymore. Docker looked at its own zone, didn't recognize what it found, and declined to start rather than run in a state it couldn't reason about. Reasonable behavior from Docker. Catastrophic behavior for the box.

## The detour that didn't help

Before the actual root cause was clear, the first fix attempt was to route around the flapping proxy hop entirely — put the affected containers on a shared Docker network (`naveedge`) so they could reach each other directly instead of through the wobbling `host.docker.internal:8080` path. Sensible instinct. It failed immediately: `docker network create` itself errored out with `iptables: No chain…`, because the chains a new Docker network needs to wire itself into were the exact chains firewalld had just erased. You cannot route around damage to the plumbing by asking for more plumbing. That attempt got reverted within minutes, but it's a useful data point on how the incident *felt* in real time — the first hypothesis (flaky network hop) was plausible enough to spend real minutes on before the actual scope of the damage (the chains are just gone) became undeniable.

## The scare that wasn't the scare

In the middle of this, something worse-looking happened: the bunker's connection endpoint started handing phones a plain text file — `document.txt`, `Key.text` — instead of launching the signer app it was supposed to hand off to. For about the length of time it takes your stomach to drop, that reads as "the private key material is being served as a downloadable file to anyone who hits this URL." That would be a five-alarm fire, not a 502.

It wasn't that. The front Caddy reverse proxy's hop to the backend container was flapping — because of the same broken firewall chains — and when that hop failed, Caddy returned an error body that the phone's browser, given no useful content-type to go on, decided to interpret as a downloadable text file. It was an error page, mislabeled by the client, not a secret, mislabeled by the server. The real fix arrived as a side effect of the actual firewall purge, not as a targeted patch — which in hindsight was the tell that the "leak" and the 502 were the same underlying disease.

## The reading that lied

Along the way, a port probe reported `:8080` as "sealed (timeout)" — read, correctly at the time, as good news: the port isn't reachable from outside, the firewall is doing its job. It was a false positive of the worst kind, because it was false in the *reassuring* direction. The container behind that port was simply down, so of course nothing answered — that's indistinguishable, from a naive timeout probe, from a port that's actively blocked. Once the container came back up, the same port was answering from anywhere on the internet, completely unfirewalled, because at that point in the incident there was no working on-box firewall left to seal it — firewalld had been ripped out and nothing had replaced it yet. "Container down" and "port sealed" look identical to a stopwatch. They are not identical in any way that matters.

## The fix, once the shape was clear

Once the actual failure mode was understood — firewalld had corrupted the exact chains Docker needs to exist — the fix was blunt and, in retrospect, obvious:

```
systemctl disable --now firewalld
nft flush ruleset
systemctl start docker
docker compose down && docker compose up -d   # rebuild the stale networks
```

Disable the thing that caused the damage. Wipe the corrupted rule state clean rather than trying to patch around it. Let Docker come up into a clean iptables world it recognizes. Then tear down and rebuild the compose networks, because they'd been created against the broken chain state and needed to be re-created against the clean one, not just restarted.

Docker came back. The bunker came back. And the box was left, deliberately, with *no* firewalld at all — replaced by a hand-built on-box firewall using `nftables` directly: an `INPUT` chain for the box's own exposed ports, plus sealing the `DOCKER-USER` chain, which is the one hook Docker explicitly leaves open for an operator to add their own filtering without Docker fighting you for control of it. No provider-level firewall panel required — the box defends itself, verified from outside the network after the fact.

## The bug in the fix itself

The first pass at that new firewall script had its own bug, and it's the kind that's genuinely worth admitting to rather than glossing over: it checked for a `-j RETURN` rule as evidence that `DOCKER-USER` needed sealing, because that's the marker older Docker versions pre-seed the chain with. Docker 29 doesn't pre-seed it that way. So the script's guard condition was never true, the seal step silently no-opped, and the script printed "sealed" anyway — a script confidently lying about its own success, on the box's actual firewall, on the same day it was trying to prove the box was safe. Caught before it mattered, fixed to check for the chain's *existence* rather than a specific rule inside it, but it's exactly the kind of "verified" that wasn't.

## The smaller cuts

None of these were the main event, but each one cost real time on the same day:

- **SELinux mislabeling.** A freshly written `authorized_keys` file on the AlmaLinux box didn't have the SELinux context SSH expects, so key auth silently failed until `restorecon` ran — a one-line fix behind twenty minutes of "but the key is right there."
- **fail2ban banning the operator.** A `maxretry` threshold tuned too tight locked out James's own IP after a run of legitimate-but-failed attempts during the debugging. Loosened to 10 attempts per 15 minutes — enough slack for a human under pressure, still tight enough to matter against anyone else.
- **cloud-init undoing the lockdown.** A `cloud-init` drop-in silently re-enabled `PasswordAuthentication` on boot, quietly reopening a door that had been deliberately closed. The fix now `sed`s every file under `sshd_config.d/*` rather than trusting one canonical location, and checks the *live*, compiled config with `sshd -T` afterward instead of trusting that editing a file did anything.
- **The zsh comment gotcha, twice.** Pasting a multi-line shell command block with an inline `#` comment into a Mac terminal errored with `cat: #: No such file` — because zsh, unlike bash, doesn't treat `#` as a comment character by default in interactive shells. Hit this once, forgot, hit it again. Fixed permanently with `setopt interactive_comments`, or by just not putting comments in paste blocks going forward.
- **Secrets filed under the wrong repo.** A separate but same-week miss: `WARM_SSH_*` secrets were added to the `warm.contact` repository, but the GitHub Actions workflow that needed them lives in `nave.pub`. Actions secrets are scoped per-repo, so the workflow read them as simply empty and failed with "missing server host" — with a `H0ST`-versus-`HOST` typo red herring thrown in along the way to make the empty value look like a spelling bug instead of a repo-scoping bug.

One more moment from the same stretch worth naming honestly: mid-debug, a bunker connection string — a `bunker://` URI carrying a live secret — got pasted into a place it shouldn't have been. The instant reflex was to treat it as burned, full stop, no half-measures: every connection using it was re-minted fresh from the console rather than trusting that "well, it was only visible for a second." Key material doesn't get the benefit of the doubt.

## What actually changed

Two durable decisions came out of this, and they're now written into the standing conventions for every box in the fleet, not just the one that broke:

**Firewalld is banned outright on any Docker host.** Not "configured carefully around Docker" — banned. Port control lives in the on-box `nftables` script, with a cloud provider's edge firewall as optional belt-and-suspenders on top, never as the primary defense and never as a required one. The whole point is a box that can prove its own security without trusting a third-party panel to have done it right.

**One management key opens every box.** `nave_mgmt` is the only SSH key across all three machines in the fleet, key-only auth enforced and verified live (not just configured and hoped), stray keys pruned. New box provisioning now runs through a fixed sequence — stand it up, apply the on-box firewall, prove the key actually logs in, then lock it — instead of ad hoc setup that leaves room for exactly this kind of drift.

Neither of those is a clever idea. They're both just the boring, hard-won output of a day spent watching a Docker daemon refuse to boot because a firewall it was never supposed to be sharing a box with reached in and broke its plumbing. The lesson wasn't sophisticated. It was: stop running two firewalls on one machine, and stop assuming a port that isn't answering is a port that's protected. Sometimes it's just a container that hasn't come back up yet.
