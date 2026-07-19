# Nave relay image: strfry + the python3 write-policy plugin.
#
# Works whether the strfry base is Alpine (apk) or Debian (apt) — dockurr/strfry
# is Alpine, so apk wins here.
FROM dockurr/strfry:latest

RUN if command -v apk >/dev/null 2>&1; then \
        apk add --no-cache python3; \
    else \
        apt-get update && apt-get install -y --no-install-recommends python3 && rm -rf /var/lib/apt/lists/*; \
    fi

COPY write-policy.py /app/write-policy.py
COPY allowlist.json  /app/allowlist.json
RUN chmod +x /app/write-policy.py
