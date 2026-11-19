#!/usr/bin/env bash
# firewall.test.sh — the nftables input table that deploy/ops/firewall.sh writes, checked as text (and by nft when it can).
#
#   deploy/ops/firewall.test.sh
#
# WHY THIS EXISTS. On 18 Nov 2026 Navidrome and Audiobookshelf moved onto this box (herd-infra bin/move-media). They listen
# on the box's tailnet address only, but the nave_fw input policy is drop and allowed only 22/80/443, so every phone lost
# its music and audiobooks ("a server with the specified hostname cannot be found") until a rule was added by hand. A
# hand-added rule is gone on the next reboot or firewall.sh run. The rule now lives in firewall.sh, and this checks that it
# opens the media and R1 ports (OwnTone, Navidrome, R1 Manager, Audiobookshelf) on tailscale0 only, and that nothing else changed for the internet.
set -euo pipefail
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
nft=$(awk "/^cat > \/etc\/nftables.d\/nave-fw.nft <<'NFT'\$/{f=1;next} /^NFT\$/{f=0} f" "$here/firewall.sh")
pass=0 fail=0
ok() { if eval "$2"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1"; fi; }
media=$(grep -E '3689|4533|8420|13378' <<<"$nft" || true)

ok "the table is extracted" '[ -n "$nft" ]'
ok "input policy is drop" 'grep -q "type filter hook input priority 0; policy drop;" <<<"$nft"'
ok "the internet still gets 22, 80 and 443 only" '[ "$(grep -cE "^ *tcp dport" <<<"$nft")" = 1 ] && grep -qE "^ *tcp dport \{ 22, 80, 443 \} accept" <<<"$nft"'
ok "media ports accepted on tailscale0" 'grep -qE "^ *iifname \"tailscale0\" tcp dport \{ 3689, 4533, 8420, 13378 \} accept" <<<"$nft"'
ok "media ports appear on that one line only" '[ "$(wc -l <<<"$media")" = 1 ] && grep -q "iifname \"tailscale0\"" <<<"$media"'
ok "mosh UDP range accepted on tailscale0 only" 'grep -qE "^ *iifname \"tailscale0\" udp dport 60000-61000 accept" <<<"$nft"'
ok "no other iifname rule" '[ "$(grep -c iifname <<<"$nft")" = 2 ]'
ok "the success message names the media ports" 'grep -q "tailnet-only 3689,4533,8420,13378" "$here/firewall.sh"'

# nft's own parser, when this host lets an unprivileged user make a network namespace (CI runners do; skip otherwise).
if command -v nft >/dev/null 2>&1 && unshare -rn true 2>/dev/null; then
  ok "nft -c accepts the table" 'unshare -rn nft -c -f - <<<"$nft" 2>/dev/null'
else
  echo "skip: nft -c (no nft, or no unprivileged network namespace here)"
fi

echo "firewall.test.sh: $pass passed, $fail failed"
[ "$fail" = 0 ]
