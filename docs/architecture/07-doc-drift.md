# 07 · Known Doc Drift — contradictions and stale statements, dated

*Found during the 2026-07-25 full-estate read. Where docs disagree, this page
names the current truth and the stale text. Fixing the stale files is queued
work; until then, trust the rulings below (each follows the most recent dated
decision).*

## Rulings

1. **Firewall authority** — *stale:* `deploy/ops/ssh-standard.md` ("no on-box
   firewall; the provider edge is the reliable control") and `PLAN.md`'s
   Guiding Decision #3. *Current:* the on-box `firewall.sh` (nftables +
   DOCKER-USER) is **primary** on all three boxes; the provider edge is
   belt-and-suspenders; firewalld is banned (PLAN.md incident record +
   `docs/sovereign-signing.md`, 2026-07-23).

2. **nave.pub#37 (relay gift-wrap admission)** — `PLAN.md` lists it both open
   and complete. *Current:* **complete 2026-07-23** (PR #54);
   `deploy/relay/allowlist.json` carries `"recipientKinds": [1059]`. The open
   entry is stale.

3. **"The drafting hand" names two agents** — `IDENTITY-REGISTRY.md` calls
   **kerouac** the drafting hand (Buzz nest, `steer:draft` grantee) and also
   calls **James's Quill** the Director's drafting hand, while the canonical-
   Quill row says "distinct from the drafting hand (`kerouac`)". *Reading that
   reconciles the dates:* since 2026-07-24 **James's Quill is the drafting
   hand for the Director's published posts** (the Ngage pipeline); **kerouac
   drafts on the Buzz nest** (its own relay/community lane). The registry
   should say which lane each hand drafts for — one word ("drafting hand")
   currently covers both. **Flagged for the Director; not resolved here.**

4. **Bunker contents** — *stale:* `deploy/bunker/README.md` ("holds the
   delegated operator key, **never the sovereign**") and
   `docs/sovereign-signing.md` ("the sovereign key stays offline on the Mac").
   *Current:* the registry's custody map (reconciled 2026-07-23/24) and
   `quill.md` §9 place **sovereign, operator, and jaf-quill** in Bunker46 —
   the sovereign invoked by hand, jaf-quill kind-scoped. The earlier docs
   describe the plan before the custody consolidation.

5. **quill.md §9 internal history** — the "per-device Keychain keys" custody
   model was superseded **2026-07-24** by one-key-in-Bunker46; §9 says so
   itself, but the scoped-agent-actions threat model (II·7·7) still speaks of
   "per-device keys (no key copied)" as the mitigation. *Current:* the NIP-46
   bunker adapter **is** the mitigation; per-device keys are dead.

6. **warm.contact §10.6/§10.9 vs shipped code** — the spec addendum says
   "don't hand-roll NIP-44/59/98 in Swift; M1 = Streamable HTTP." The shipped
   code hand-rolls all of it (`NostrCrypto.swift`, kept as the cross-test
   twin/fixture seam) and delivers via **M2 stdio** (bundled nvoy-mcp child).
   The architecture is sound; the addendum's transport section is behind the
   code.

7. **Spec-repo README/landing page** — advertise "four event kinds," "11
   smoke / 5 interop assertions." *Current:* six kinds counting the v2 track;
   ~60 smoke checks; 9 interop scenarios. `SPEC.md`/`SPEC-v2.md` are accurate.

8. **JOURNEY.md §Artifacts** — still points essays at `noir/docs/articles/`
   and counts three. *Current:* `library/README.md` — eight articles;
   `library/` is the source of truth. Related live duplication: three articles
   also exist as rendered HTML in `noir/docs/` — edit the `library/` Markdown
   and re-render, or links drift (flagged in `library/README.md` §Provenance).

9. **Commit/PR attribution** — HANDOFF.md (2026-07-23) mandates the plain
   `Co-Authored-By: Claude <noreply@anthropic.com>` trailer, **no model
   identifiers anywhere**, and the softened PR footer ("Drafted with
   assistance from…"). Any tooling still emitting the old footer is violating
   a standing rule.

10. **Ticket numbering** — INVENTORY.md's older prose (#26/#36/#37/#43/#44/
    #48/#56/#59/#60) predates the 2026-07-21 ticket index; the per-repo issue
    numbers supersede the old references. INVENTORY says this itself; repeated
    here because the old numbers still appear in several docs.

## Standing sources of truth (when in doubt)

| Question | Canonical source |
|---|---|
| Any grant's existence/status | the Nvoy Ledger (kind-10440 index) |
| Identities, npubs, custody | `docs/IDENTITY-REGISTRY.md` |
| Project list & status | `docs/PROJECTS.md` |
| Architecture decisions | `docs/nave-architecture-decisions.md` (AD-1…11) |
| Protocol wire truth | `nostr-scoped-data-grants/SPEC.md` + `SPEC-v2.md` |
| Relay write policy | `deploy/relay/allowlist.json` (the file, not prose) |
| Approval-path wiring | `nact/lib/routing.mjs` (tested spec) |
| The backlog | per-repo GitHub issues (issues-first, 2026-07-23) |
