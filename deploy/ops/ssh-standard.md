# Nave SSH standard — one management key for the whole empire

The rule: **every box you own is reachable by exactly one SSH key — the Nave
management key — held only in your Mac's Keychain.** No per‑box keys, no
passwords, no confusion about "which key is on which server." New boxes get the
same key at birth. This is the "one clean process" for rekeying what exists and
provisioning what's next.

## The key (make once, on your Mac)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/nave_mgmt -C nave-mgmt      # passphrase optional
ssh-add --apple-use-keychain ~/.ssh/nave_mgmt               # store it in Keychain
cat ~/.ssh/nave_mgmt.pub                                    # the public line
```

Paste that public line into **`deploy/ops/nave_mgmt.pub`** in this repo and
commit it (public keys are safe to commit). That file is the single source of
truth every bring‑up script reads from.

- **Private key** (`~/.ssh/nave_mgmt`) never leaves your Mac.
- **Passphrase** lives in Keychain, so it's never re‑typed and never forgotten.
- Optional: use `~/.ssh/config` so `ssh nave-bunker` just works:
  ```
  Host nave-*
      User root
      IdentityFile ~/.ssh/nave_mgmt
      IdentitiesOnly yes
  Host nave-bunker
      HostName 145.79.6.80
  ```

## Rekey an existing box  →  `rekey.sh`

Run from your Mac. It installs the management key, fixes perms + SELinux label,
and **verifies key login before it will ever disable passwords** — so it cannot
lock you out.

```bash
sh deploy/ops/rekey.sh root@145.79.6.80          # install + verify (leaves password on)
sh deploy/ops/rekey.sh root@145.79.6.80 --lock   # + disable password/root-password (only after verify)
```

Do it once per box **with a console/session open as a lifeline**, confirm the
plain `--lock` step reports success, then move to the next box. Your three boxes:
main Nave (Hostinger), bunker/relay (145.79.6.80), warm.contact (165.22.13.236).

> Main Nave box only: it also holds the **CI deploy key** GitHub Actions uses.
> rekey.sh **appends** (never overwrites), so that key is preserved — but never
> hand‑edit `authorized_keys` there with `>`.

## Provision a NEW box  →  `newbox.sh`

Every new server, from birth, gets the management key + baseline hardening in one
shot. Run it on the fresh box (as root, via the provider console) — it's
distro‑aware (dnf/apt, firewalld/ufw):

```bash
curl -fsSL https://raw.githubusercontent.com/JAFairweather/nave.pub/main/deploy/ops/newbox.sh | sh
# or: scp it over and `sh newbox.sh`
```

It installs the committed management key, a host firewall (22/80/443), fail2ban,
and automatic security updates — then prints the one manual step (`rekey.sh
--lock` from your Mac once you've confirmed key login).

## The port rule (cloud VPS)

Docker publishes container ports **straight into the kernel firewall, bypassing
firewalld/ufw** — so the host firewall does NOT reliably block a Docker port
(e.g. a bunker's `:8080`). The reliable control is the **provider's edge
firewall** (Hostinger hPanel / DigitalOcean cloud firewall): allow only inbound
**22 / 80 / 443**, deny the rest. Set that on every box. The on‑box firewall is
defense‑in‑depth; the provider firewall is the real seal.

## Checklist per box

1. `newbox.sh` (new) or `rekey.sh` (existing) — management key + baseline.
2. Provider edge firewall → 22/80/443 only.
3. Confirm `ssh nave-<box>` works key‑only, then `rekey.sh --lock`.
4. Done. One key, everywhere.
