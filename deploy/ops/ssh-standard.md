# Nave SSH standard — one management key for the whole fleet

The rule: **every box you own is reachable by exactly one SSH key — the Nave
management key — held only in your Mac's Keychain.** No per-box keys, no
passwords, no confusion about "which key is on which server." New boxes get the
same key at birth. This is the process we used to unify the fleet on 2026-07-20,
written so you can bring any new box under the same keychain in a few minutes.

> **Firewalld is banned on these boxes.** It fights Docker — it manages the
> `docker` firewalld zone and flushes Docker's iptables chains on reload — and on
> 2026-07-20 that took the relay/bunker box fully offline: Docker wouldn't even
> boot (`INVALID_ZONE: docker`). Port control lives at the **provider edge
> firewall** instead. See `harden.sh` and `PLAN.md`.

## The key (make once, on your Mac)

```bash
ssh-keygen -t ed25519 -f ~/.ssh/nave_mgmt -C nave-mgmt   # give it a passphrase
ssh-add --apple-use-keychain ~/.ssh/nave_mgmt            # store passphrase in Keychain
cat ~/.ssh/nave_mgmt.pub                                 # the public line
```

- **Private key** (`~/.ssh/nave_mgmt`) never leaves your Mac.
- **Passphrase** lives in the Keychain, so it's never re-typed and never forgotten.
- We deliberately do **not** commit the public key to this (public) repo — no
  reason to advertise "this is the master SSH key for the whole fleet." Keep the
  public line in your password manager; paste it in when provisioning a box.
- Optional `~/.ssh/config` so `ssh nave-<box>` just works:
  ```
  Host nave-*
      User root
      IdentityFile ~/.ssh/nave_mgmt
      IdentitiesOnly yes
  ```

## Rekey an EXISTING box → `rekey.sh` (or by hand)

`rekey.sh` runs from your Mac. It installs the management key, fixes perms +
SELinux label, and **verifies key login before it will ever disable passwords** —
so it cannot lock you out.

```bash
sh deploy/ops/rekey.sh root@HOST          # install + verify (leaves password on)
sh deploy/ops/rekey.sh root@HOST --lock   # disable passwords (only after verify)
```

Always keep a **provider console open as a lifeline** while doing a box, and only
run `--lock` after you've seen key login work.

### If the box is ALREADY key-only (ssh-copy-id can't get in)

Some boxes (e.g. fresh DigitalOcean droplets) already refuse passwords, so
`ssh-copy-id` fails with `Permission denied (publickey)` — the key it tried isn't
authorized. Don't fight it: use the **provider's web console** (out-of-band, needs
no SSH key; reset the root password in the panel if the console asks for one), and
paste the key in directly:

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo 'ssh-ed25519 AAAA...YOUR-nave-mgmt-LINE... nave-mgmt' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
restorecon -Rv ~/.ssh 2>/dev/null || true          # AlmaLinux/SELinux; no-op on Ubuntu
grep -c 'nave-mgmt' ~/.ssh/authorized_keys          # expect 1+
```

### The lock step, by hand (what `--lock` runs)

Only after you've **proven** key login from a second terminal
(`ssh -i ~/.ssh/nave_mgmt -o IdentitiesOnly=yes root@HOST 'echo KEY_LOGIN_OK'`),
with a console open:

```bash
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
# cloud images hide a "PasswordAuthentication yes" in a drop-in — force it off too:
for f in /etc/ssh/sshd_config.d/*.conf; do [ -e "$f" ] && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$f"; done
sshd -t && sshd -T | grep -Ei 'passwordauthentication|permitrootlogin'   # MUST show: passwordauthentication no
systemctl reload sshd || systemctl reload ssh                            # service is 'ssh' on Ubuntu
```

Then re-prove from a fresh terminal before closing the console. The `sshd -T`
check is essential — it shows the *effective* config, catching a cloud-init
drop-in that would otherwise keep passwords silently on. (`permitrootlogin
without-password` is just this sshd version's spelling of `prohibit-password` —
same thing: root by key only.)

## Provision a NEW box → `newbox.sh`

Run it on the fresh box (as root, via the provider console). It installs the
management key and the baseline hardening — **no firewalld**:

```bash
MGMT_PUB='ssh-ed25519 AAAA...nave-mgmt' sh newbox.sh
```

It installs the key, calls `harden.sh` (fail2ban, auto-updates, Docker enabled,
firewalld removed), then prints the two manual steps: set the provider edge
firewall to 22/80/443, then `rekey.sh --lock` from your Mac once key login is
confirmed.

## The port rule (cloud VPS)

Docker publishes container ports **straight into the kernel firewall**, so a host
firewall does not reliably block a Docker port (e.g. a bunker's `:8080`). The
reliable control is the **provider edge firewall** (Hostinger hPanel /
DigitalOcean cloud firewall): allow only inbound **22 / 80 / 443**, deny the rest.
Set that on every box. There is intentionally **no on-box firewalld** — it breaks
Docker on these hosts.

## Checklist per box

1. `newbox.sh` (new) or `rekey.sh` (existing) — management key + baseline.
2. Provider edge firewall → 22/80/443 only.
3. Prove `ssh -i ~/.ssh/nave_mgmt root@HOST` works key-only, then `rekey.sh --lock`.
4. Re-prove from a fresh terminal. Done — one key, everywhere.

## The fleet (roles, not addresses)

Keep the actual IPs in your password manager, not in this public repo. Roles:
- **Main Nave** — nact / luke / nvoy / nactor. Also holds the **CI deploy key**
  (`github-deploy`) GitHub Actions uses; `rekey.sh` appends, so it's preserved.
- **Relay / bunker** — strfry relay + Bunker46 (sovereign remote signer).
- **warm.contact** — the warm.contact app.
