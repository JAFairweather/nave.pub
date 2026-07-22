// JAF's-Quill avatar → nave.pub/assets/quill-jaf.png. A LARGE quill/nib as the
// hero, caught just past the F of a smaller "JAF" it has signed. Warm letterpress
// palette, kin with the canonical Quill (quill.png) and the card library.
import { writeFile } from 'node:fs/promises'
const INK = '#160f08', GROUND = '#1d140b', GOLD = '#d9b06a', BRIGHT = '#e7cd93'

// nib in its own coords: tip ≈ (256,436), shoulders ≈ y108, ~230w × 330h.
const nib = (t) => `<g transform="${t}">
  <path d="M256 108 C 196 150, 168 224, 196 314 C 214 372, 238 412, 256 436 C 274 412, 298 372, 316 314 C 344 224, 316 150, 256 108 Z" fill="${BRIGHT}" stroke="${GOLD}" stroke-width="4" stroke-opacity=".5"/>
  <circle cx="256" cy="246" r="22" fill="${GROUND}"/>
  <path d="M256 268 L256 432" stroke="${GROUND}" stroke-width="11" stroke-linecap="round"/>
</g>`

// The small signature sits left-of-centre; the large nib lands its tip just past
// the F (translate/rotate/scale tuned so the body angles up-right, clear of the text).
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="118" fill="${INK}"/>
  <rect x="16" y="16" width="480" height="480" rx="104" fill="${GROUND}"/>
  <rect x="30" y="30" width="452" height="452" rx="92" fill="none" stroke="${GOLD}" stroke-opacity=".22" stroke-width="2"/>
  <text x="196" y="360" text-anchor="middle" font-family="'Snell Roundhand','Zapfino','Apple Chancery',Georgia,serif" font-style="italic" font-weight="700" font-size="86" fill="${BRIGHT}">JAF</text>
  <path d="M100 378 C 166 400, 236 398, 300 366" stroke="${GOLD}" stroke-width="6" fill="none" stroke-linecap="round" stroke-opacity=".7"/>
  ${nib('translate(366 10) rotate(40) scale(0.68)')}
</svg>`

let sharp = null
if (process.env.SHARP_PATH) sharp = (await import(process.env.SHARP_PATH)).default
const OUT = '/Users/fairwja/Projects/nave-spine/nave.pub/assets/quill-jaf.png'
await writeFile('/Users/fairwja/Projects/nave-spine/nave.pub/assets/quill-jaf.svg', svg)
if (sharp) { await sharp(Buffer.from(svg), { density: 200 }).png().toFile(OUT); console.log('✓ wrote', OUT) }
else console.log('SVG only (set SHARP_PATH for PNG)')
