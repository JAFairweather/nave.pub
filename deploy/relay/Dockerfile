# Nave relay image: strfry + the python3 write-policy plugin.
#
# Base is the community strfry image (Debian-based, has apt). If you swap to an
# Alpine-based strfry image, change the install line to: RUN apk add --no-cache python3
FROM dockurr/strfry:latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && rm -rf /var/lib/apt/lists/*

COPY write-policy.py /app/write-policy.py
COPY allowlist.json  /app/allowlist.json
RUN chmod +x /app/write-policy.py
