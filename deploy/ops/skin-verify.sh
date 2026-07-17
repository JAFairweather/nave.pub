#!/usr/bin/env bash
# Verify the NEW Nave skin is live: the served stylesheet contains the new
# tokens, and the cockpit document has the skin <link> injected. Read-only.
set -u
echo "=== served /__nave-skin.css (via luke) ==="
docker compose exec -T luke node -e '
fetch("http://localhost:8790/__nave-skin.css",{headers:{"x-forwarded-host":"cockpit.nave.pub"}}).then(r=>r.text()).then(t=>{
  console.log("bytes:", t.length);
  console.log("has --tool-shell (new surface token):", t.includes("--tool-shell"));
  console.log("has --font-display serif:", t.includes("--font-display:Georgia"));
  console.log("has data-theme-mode light block:", t.includes("data-theme-mode=\"light\""));
  console.log("has mono-uppercase button rule:", t.includes(".btn:not(.btn--icon)"));
}).catch(e=>console.log("ERR", e.message))'
echo
echo "=== cockpit document: skin <link> injected? ==="
docker compose exec -T luke node -e '
fetch("http://openclaw:57419/",{headers:{accept:"text/html"}}).then(r=>r.text()).then(async oc=>{
  const has = oc.includes("__nave-skin.css");
  // Now fetch through luke as the cockpit host to confirm injection happens.
  const r = await fetch("http://localhost:8790/",{headers:{accept:"text/html","x-forwarded-host":"cockpit.nave.pub"}});
  const doc = await r.text();
  console.log("openclaw shell already had link:", has);
  console.log("luke-injected doc has skin link:", doc.includes("__nave-skin.css"));
  console.log("injected before </head>:", doc.indexOf("__nave-skin.css") < doc.indexOf("</head>") && doc.indexOf("__nave-skin.css")>0);
}).catch(e=>console.log("ERR", e.message))'
echo "== skin-verify done =="
