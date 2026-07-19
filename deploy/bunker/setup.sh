#!/bin/sh
# Bring up Bunker46 (NIP-46 remote signer) on this box. Clones the upstream
# repo (dsbaars/bunker46 — its compose is the tested one), generates a stable
# .env on first run, and brings it up. Idempotent: re-running pulls + restarts
# without touching the .env, so the ENCRYPTION_KEY stays stable (regenerating it
# would orphan every stored nsec — DO NOT let that happen).
#
#   DOMAIN=bunker.nave.pub sh deploy/bunker/setup.sh
set -e

DIR=${BUNKER_DIR:-/root/bunker46}
DOMAIN=${DOMAIN:-bunker.nave.pub}

if [ ! -d "$DIR/.git" ]; then
  git clone https://github.com/dsbaars/bunker46.git "$DIR"
else
  git -C "$DIR" pull --ff-only || true
fi
cd "$DIR"

if [ ! -f .env ]; then
  echo "generating $DIR/.env (secrets are created ONCE and must stay stable)"
  cat > .env <<EOF
JWT_SECRET=$(openssl rand -base64 48)
JWT_REFRESH_SECRET=$(openssl rand -base64 48)
ENCRYPTION_KEY=$(openssl rand -base64 48)
CORS_ORIGINS=https://$DOMAIN
WEBAUTHN_RP_ID=$DOMAIN
WEBAUTHN_ORIGIN=https://$DOMAIN
TRUST_PROXY=true
ALLOW_REGISTRATION=true
EOF
  chmod 600 .env
else
  echo ".env already exists — leaving it untouched (stable ENCRYPTION_KEY)."
fi

docker compose up -d --build
echo
echo "Bunker46 is starting. It listens on :8080 (HTTP) inside the box."
echo "Next: add the bunker.nave.pub vhost to deploy/relay/Caddyfile (see deploy/bunker/README.md),"
echo "then open https://$DOMAIN to register your admin account + import the operator nsec."
