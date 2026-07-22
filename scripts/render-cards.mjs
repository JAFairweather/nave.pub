// render-cards.mjs — the social card library, as code.
//
// Each entry below IS the master for one card: a 1200×630 letterpress-noir
// graphic in the site's own tokens (ink, gold, cream; mono kicker, serif
// headline). Luke's brain reads assets/cards/manifest.json to pick a card per
// post; the poster attaches it (NIP-92 imeta) so every approved note ships
// with a relevant graphic. Adding a card = add an entry here, re-run, commit.
//
// Render (writes assets/cards/*.svg + *.png + manifest.json):
//   npm i sharp --no-save --prefix /tmp/cardtools   # or any dir
//   SHARP_PATH=/tmp/cardtools/node_modules/sharp/lib/index.js \
//     node scripts/render-cards.mjs
// Without SHARP_PATH it still writes the SVGs + manifest and skips PNGs.
import { mkdir, writeFile } from 'node:fs/promises'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const OUT = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets', 'cards')
const BASE = 'https://nave.pub/assets/cards'

// The site's design tokens (index.html :root) — keep in lockstep by hand.
const INK = '#0b0906', PANEL = '#12100a', GOLD = '#c39a56', CREAM = '#f4efe4', DIM = '#7a6338'

// slug · kicker · headline lines · when-to-use (the brain's selection hint)
const CARDS = [
  ['nave', 'THE ROOM', ['A room on the open internet', 'no one can take from you.'],
    'default — general Nave posts, or when nothing more specific fits'],
  ['nvoy', 'NVOY · DELEGATION', ['Delegation you can see.', 'Revocation you can feel.'],
    'Nvoy: the delegation console, issuing/revoking grants, the ledger'],
  ['grants', 'SCOPED DATA GRANTS', ['Hand out references,', 'not copies.'],
    'the data-grants spec/protocol: scopes, address books, live dereference'],
  ['revocation', 'KEY ROTATION', ['Rotate the key —', 'the room changes its locks.'],
    'revocation, key rotation, burn notices, taking access back'],
  ['nactor', 'NACT · THE RUNTIME', ['Agents act.', 'Keys stay home.'],
    'agents/credentials: Nactor, brokered keys, keyless runtimes, agent security'],
  ['warm-contact', 'WARM.CONTACT', ['Inbound-first contact.', 'Zero-knowledge on the wire.'],
    'warm.contact: contact collection, the reconnect agent, sealed envelopes'],
  ['noir', 'NOIR', ['Spycraft where a burn notice', 'is a key rotation.'],
    'Noir, the game: intel as grants, burns, the Director'],
  ['notegate', 'NOTEGATE', ['A tip line with', 'no one in the middle.'],
    'Notegate: journalism, secure tips, serverless drops'],
  ['shipping', 'SHIPPED', ['Built in the open.', 'This is today’s timber.'],
    'shipped-today / commit-digest posts about concrete progress'],
  ['essay', 'FROM THE DESK', ['Longer thoughts,', 'same room.'],
    'linking a Substack essay or any longer written piece'],
  ['community', 'THE CONVERSATION', ['Replies are how', 'a room gets built.'],
    'engagement follow-ups, replies, questions to the room'],
]

const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

function svgCard(kicker, lines) {
  const spacedKicker = esc(kicker.split('').join(' '))   // hair-spaced, like the site's .kick
  const headline = lines.map((l, i) =>
    `<tspan x="96" dy="${i === 0 ? 0 : 78}">${esc(l)}</tspan>`).join('')
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="${INK}"/>
  <rect x="24" y="24" width="1152" height="582" fill="${PANEL}" stroke="${GOLD}" stroke-opacity=".38" stroke-width="1.5"/>
  <rect x="34" y="34" width="1132" height="562" fill="none" stroke="${GOLD}" stroke-opacity=".14" stroke-width="1"/>
  <text x="96" y="150" font-family="'Courier New',Courier,monospace" font-size="26" letter-spacing="10" fill="${DIM}">${spacedKicker}</text>
  <rect x="96" y="178" width="120" height="2" fill="${GOLD}" fill-opacity=".65"/>
  <text x="96" y="315" font-family="Georgia,'Times New Roman',serif" font-style="italic" font-size="60" fill="${CREAM}">${headline}</text>
  <text x="96" y="540" font-family="'Courier New',Courier,monospace" font-weight="bold" font-size="30" letter-spacing="12" fill="${CREAM}">NAVE</text>
  <text x="1104" y="540" text-anchor="end" font-family="'Courier New',Courier,monospace" font-size="26" letter-spacing="4" fill="${GOLD}">nave.pub</text>
</svg>`
}

await mkdir(OUT, { recursive: true })
let sharp = null
if (process.env.SHARP_PATH) sharp = (await import(process.env.SHARP_PATH)).default

const manifest = []
for (const [slug, kicker, lines, use] of CARDS) {
  const svg = svgCard(kicker, lines)
  await writeFile(join(OUT, `${slug}.svg`), svg)
  if (sharp) await sharp(Buffer.from(svg), { density: 144 }).png().toFile(join(OUT, `${slug}.png`))
  manifest.push({ slug, url: `${BASE}/${slug}.png`, alt: lines.join(' '), use })
  console.log(`  ${sharp ? '✓' : '(svg only)'} ${slug}`)
}
await writeFile(join(OUT, 'manifest.json'), JSON.stringify({ cards: manifest }, null, 2) + '\n')
console.log(`${CARDS.length} cards → ${OUT}${sharp ? '' : '  (set SHARP_PATH to render PNGs)'}`)
