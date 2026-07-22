// Renders the Quill avatar (nib) → nave.pub/assets/quill.png, warm letterpress
// palette in kin with the Nave card library. 512×512, profile-pic square.
import { writeFile } from 'node:fs/promises'

const INK = '#160f08', GROUND = '#1d140b', GOLD = '#d9b06a', BRIGHT = '#e7cd93', RULE = '#3a2c19'
const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" rx="118" fill="${INK}"/>
  <rect x="16" y="16" width="480" height="480" rx="104" fill="${GROUND}"/>
  <rect x="30" y="30" width="452" height="452" rx="92" fill="none" stroke="${GOLD}" stroke-opacity=".22" stroke-width="2"/>
  <!-- nib: leaf silhouette pointing down, vent hole + slit -->
  <g>
    <path d="M256 108
             C 196 150, 168 224, 196 314
             C 214 372, 238 412, 256 436
             C 274 412, 298 372, 316 314
             C 344 224, 316 150, 256 108 Z"
          fill="${BRIGHT}"/>
    <path d="M256 108
             C 196 150, 168 224, 196 314
             C 214 372, 238 412, 256 436
             C 274 412, 298 372, 316 314
             C 344 224, 316 150, 256 108 Z"
          fill="none" stroke="${GOLD}" stroke-width="3" stroke-opacity=".5"/>
    <circle cx="256" cy="246" r="21" fill="${GROUND}"/>
    <path d="M256 267 L256 434" stroke="${GROUND}" stroke-width="9" stroke-linecap="round"/>
  </g>
  <!-- a single ink dot: the mark it leaves -->
  <circle cx="256" cy="462" r="7" fill="${GOLD}" fill-opacity=".7"/>
</svg>`

let sharp = null
if (process.env.SHARP_PATH) sharp = (await import(process.env.SHARP_PATH)).default
const OUT = '/Users/fairwja/Projects/nave-spine/nave.pub/assets/quill.png'
await writeFile('/Users/fairwja/Projects/nave-spine/nave.pub/assets/quill.svg', svg)
if (sharp) { await sharp(Buffer.from(svg), { density: 200 }).png().toFile(OUT); console.log('✓ wrote', OUT) }
else console.log('SVG only (set SHARP_PATH for PNG)')
