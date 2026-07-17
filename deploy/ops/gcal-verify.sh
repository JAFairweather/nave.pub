#!/usr/bin/env bash
# Verify the Google Calendar OAuth path end-to-end from inside Nactor: mint an
# access token from the stored refresh bundle, then call the Calendar API. Prints
# only success + a count — never the token, never event contents.
set -u
if [ -f /root/nave.pub/deploy/.flipped ]; then D=/root/nave.pub/deploy; else D=/root/noir/deploy; fi
cd "$D"
echo "credentials loaded:"
docker compose exec -T nactor node -e "fetch('http://localhost:8791/api/health').then(r=>r.json()).then(j=>console.log('  count:',j.credentials))"
echo
echo "minting a token + calling the Calendar API (token/events never printed):"
docker compose exec -T nactor node --input-type=module -e '
const c = { client_id: process.env.GOOGLE_OAUTH_CLIENT_ID, client_secret: process.env.GOOGLE_OAUTH_CLIENT_SECRET, refresh_token: process.env.GOOGLE_OAUTH_REFRESH_TOKEN };
if (!c.client_id || !c.client_secret || !c.refresh_token) { console.log("  ✗ GOOGLE_OAUTH_* env not all present in nactor"); process.exit(0); }
const form = new URLSearchParams({ grant_type: "refresh_token", client_id: c.client_id, client_secret: c.client_secret, refresh_token: c.refresh_token });
const tr = await fetch("https://oauth2.googleapis.com/token", { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body: form });
const tj = await tr.json();
if (!tr.ok || !tj.access_token) { console.log("  ✗ token mint failed:", tr.status, (tj.error||"") + " " + (tj.error_description||"")); process.exit(0); }
console.log("  ✓ access token minted (len " + tj.access_token.length + ", expires_in " + tj.expires_in + "s)");
const r = await fetch("https://www.googleapis.com/calendar/v3/calendars/primary/events?maxResults=1", { headers: { authorization: "Bearer " + tj.access_token } });
const j = await r.json();
if (r.ok) console.log("  ✓ Calendar API OK — status " + r.status + ", calendar: " + (j.summary||"primary") + ", items: " + ((j.items||[]).length));
else console.log("  ✗ Calendar API " + r.status + ": " + JSON.stringify(j.error||j).slice(0,180));
'
echo "== gcal-verify done =="
