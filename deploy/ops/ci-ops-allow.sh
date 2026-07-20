#!/bin/sh
# Forced-command allowlist for the relay/BUNKER box CI key. This box holds the
# sovereign key, so its CI key must NOT be a root shell. Install the CI public
# key in ~/.ssh/authorized_keys with this script as a forced command:
#
#   command="/root/nave.pub/deploy/ops/ci-ops-allow.sh",no-pty,no-port-forwarding,no-agent-forwarding,no-X11-forwarding ssh-ed25519 AAAA...nave-ci-relay
#
# With that prefix, the CI key can ONLY run the verbs below — never an arbitrary
# command, never a shell, never `cat`/read the .env or the encrypted DB. The
# requested verb arrives in $SSH_ORIGINAL_COMMAND (sent by relay-ops.yml); we
# parse the first two words and dispatch via a fixed case — the input is never
# eval'd, so there's no injection path.
set -u
NAVE=/root/nave.pub
BUNKER=/root/bunker46/docker-compose.yml

# Split the requested command into words WITHOUT evaluating it.
# shellcheck disable=SC2086
set -- ${SSH_ORIGINAL_COMMAND:-help}
VERB="${1:-help}"
ARG="${2:-}"
logger -t nave-ci-ops "verb=$VERB arg=$ARG from=${SSH_CONNECTION:-?}" 2>/dev/null || true

case "$VERB" in
  status)
    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'; echo
    df -h / | tail -1; uptime ;;
  ps)
    docker ps -a --format '{{.Names}} | {{.Status}}' ;;
  inventory)
    sh "$NAVE/deploy/ops/inventory.sh" ;;
  bunker-ps)
    docker compose -f "$BUNKER" ps ;;
  restart-relay)
    ( cd "$NAVE/deploy/relay" && docker compose up -d ) ;;
  restart-bunker)
    docker compose -f "$BUNKER" up -d ;;
  logs)
    case "$ARG" in
      relay-strfry-1|relay-caddy-1|bunker46-web-1|bunker46-server-1|bunker46-db-1|bunker46-redis-1)
        docker logs --tail 80 "$ARG" 2>&1 ;;
      *) echo "logs: allowed containers: relay-strfry-1 relay-caddy-1 bunker46-web-1 bunker46-server-1 bunker46-db-1 bunker46-redis-1" ;;
    esac ;;
  help|*)
    echo "nave-ci-ops allowlist. verbs:"
    echo "  status | ps | inventory | bunker-ps | restart-relay | restart-bunker | logs <container>"
    [ "$VERB" = help ] || { echo "DENIED verb: $VERB"; exit 1; } ;;
esac
