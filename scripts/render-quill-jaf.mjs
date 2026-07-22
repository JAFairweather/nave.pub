// JAF's-Quill avatar: the nib caught mid-signature, inscribing "JAF".
import { writeFile } from 'node:fs/promises'
const INK='#160f08', GROUND='#1d140b', GOLD='#d9b06a', BRIGHT='#e7cd93'

// the canonical nib, as a reusable group (tip at ~256,436 in its own coords)
const nib = (t) => `<g transform="${t}">
  <path d="M256 108 C 196 150, 168 224, 196 314 C 214 372, 238 412, 256 436 C 274 412, 298 372, 316 314 C 344 224, 316 150, 256 108 Z" fill="${BRIGHT}" stroke="${GOLD}" stroke-width="3" stroke-opacity=".5"/>
  <circle cx="256" cy="246" r="21" fill="${GROUND}"/>
  <path d="M256 267 L256 434" stroke="${GROUND}" stroke-width="9" stroke-linecap="round"/>
</g>`

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="118" fill="${INK}"/>
  <rect x="16" y="16" width="480" height="480" rx="104" fill="${GROUND}"/>
  <rect x="30" y="30" width="452" height="452" rx="92" fill="none" stroke="${GOLD}" stroke-opacity=".22" stroke-width="2"/>
  <!-- the signature: JAF in script, rising like handwriting -->
  <text x="250" y="300" text-anchor="middle" font-family="'Snell Roundhand','Zapfino','Apple Chancery',Georgia,serif" font-style="italic" font-weight="700" font-size="188" fill="${BRIGHT}" letter-spacing="-4">JAF</text>
  <!-- the ink stroke the nib is trailing -->
  <path d="M104 356 C 210 398, 320 396, 398 338" stroke="${GOLD}" stroke-width="8" fill="none" stroke-linecap="round" stroke-opacity=".8"/>
  <!-- nib, small + angled, lifting off the end of the stroke -->
  ${nib('translate(388 300) rotate(40) scale(0.30)')}
</svg>`

let sharp=null
if (process.env.SHARP_PATH) sharp=(await import(process.env.SHARP_PATH)).default
const OUT='/Users/fairwja/Projects/nave-spine/nave.pub/assets/quill-jaf.png'
await writeFile('/Users/fairwja/Projects/nave-spine/nave.pub/assets/quill-jaf.svg', svg)
if (sharp){ await sharp(Buffer.from(svg),{density:200}).png().toFile(OUT); console.log('✓ wrote',OUT) } else console.log('svg only')
