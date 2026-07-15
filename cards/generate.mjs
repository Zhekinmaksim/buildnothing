#!/usr/bin/env node
// BUILD NOTHING share cards (1200x675, X timeline).
// Two brands, two roles: Monad is the witness, Claude is the temptation.
// Monad: #6E54FF / #DDD7FE / #0E091C / #FFAE45 / #85E6FF (official kit)
// Claude: #D97757 terracotta - marks everything the relapse touches.
// usage: node generate.mjs clean|relapsed hours vowId stakeMON out.svg

const [, , kind = "clean", hoursArg = "72", vowId = "1", stake = "5", out] = process.argv;
const hours = Number(hoursArg);
const days = Math.floor(hours / 24);

const C = {
  bg: "#0E091C",          // Monad deep ink
  bgGlow: "#1A1230",
  tally: "#DDD7FE",       // Monad lavender - the witness's chalk
  dim: "#6E5FA3",
  purple: "#6E54FF",      // Monad primary
  amber: "#FFAE45",       // Monad secondary - the stake
  cyan: "#85E6FF",        // Monad secondary - CLEAN verdict
  claude: "#D97757",      // Claude terracotta - the temptation
};

// ---- tally geometry: groups of 5, slight hand jitter -----------------------
function tallyGroup(x, y, h, strokes, color, seed) {
  const w = 26;
  let s = "";
  const j = (i, k) => (Math.sin(seed * 7.3 + i * 3.1 + k) * 3).toFixed(1);
  const n = Math.min(strokes, 4);
  for (let i = 0; i < n; i++) {
    const xx = x + i * w;
    s += `<path d="M ${xx + +j(i, 1)} ${y + +j(i, 2)}
      C ${xx + 3} ${y + h * 0.3}, ${xx - 3} ${y + h * 0.7}, ${xx + +j(i, 3)} ${y + h}"
      stroke="${color}" stroke-width="9" stroke-linecap="round" fill="none"/>`;
  }
  if (strokes >= 5) {
    s += `<path d="M ${x - 14} ${y + h - 6} L ${x + 3 * w + 14} ${y + 8}"
      stroke="${color}" stroke-width="9" stroke-linecap="round" fill="none" opacity="0.95"/>`;
  }
  return s;
}

function tallies(count, color) {
  const groups = Math.ceil(count / 5) || 1;
  const gw = 128, rowH = 130, gh = 96;
  let s = "";
  for (let g = 0; g < groups; g++) {
    const inGroup = Math.min(5, count - g * 5);
    if (inGroup <= 0) break;
    s += tallyGroup(80 + (g % 5) * gw, 158 + Math.floor(g / 5) * rowH, gh, inGroup, color, g + 1);
  }
  return s;
}

function stamp(text, color, x, y, rot) {
  const w = text.length * 33 + 30;
  return `
  <g transform="translate(${x} ${y}) rotate(${rot})" opacity="0.96">
    <rect x="-16" y="-50" width="${w}" height="84" fill="none" stroke="${color}" stroke-width="6" rx="4"/>
    <rect x="-10" y="-44" width="${w - 12}" height="72" fill="none" stroke="${color}" stroke-width="1.5" rx="2" opacity="0.6"/>
    <text x="${(w - 30) / 2}" y="13" text-anchor="middle" font-family="Roboto Mono" font-weight="500"
      font-size="50" letter-spacing="8" fill="${color}">${text}</text>
  </g>`;
}

const isClean = kind === "clean";
const headline = isClean ? `I BUILT NOTHING FOR ${hours} HOURS` : `LASTED ${hours} HOURS`;
const sub = isClean
  ? `${days} ${days === 1 ? "day" : "days"} clean · every hour verified by a heartbeat I cannot fake`
  : `claude code session detected. the chain does not forget.`;

const svg = `<svg width="1200" height="675" viewBox="0 0 1200 675" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="bg" cx="38%" cy="30%" r="90%">
      <stop offset="0%" stop-color="${C.bgGlow}"/>
      <stop offset="100%" stop-color="${C.bg}"/>
    </radialGradient>
  </defs>

  <rect width="1200" height="675" fill="url(#bg)"/>

  <!-- purple baseline rail: the chain, always under everything -->
  <rect x="0" y="668" width="1200" height="7" fill="${C.purple}"/>

  <!-- wordmark -->
  <text x="80" y="86" font-family="Inter" font-weight="500" font-size="34"
    letter-spacing="12" fill="#FFFFFF">BUILD NOTHING</text>
  <text x="80" y="116" font-family="Roboto Mono" font-size="16" letter-spacing="3"
    fill="${C.dim}">/ A VOW OF ABSTINENCE FROM VIBECODING · WITNESSED ON MONAD</text>

  <!-- the count -->
  ${tallies(Math.max(days, 1), isClean ? C.tally : C.dim)}

  ${isClean ? "" : `<line x1="58" y1="146" x2="746" y2="384" stroke="${C.claude}" stroke-width="13" stroke-linecap="round"/>
  <text x="762" y="392" font-family="Roboto Mono" font-size="15" fill="${C.claude}" opacity="0.9">— claude was here</text>`}

  <!-- tally caption -->
  <text x="82" y="${158 + Math.ceil(Math.max(days,1)/25)*0 + (Math.floor((Math.ceil(Math.max(days,1)/5)-1)/5)+1)*130 - 8}" font-family="Roboto Mono" font-size="15" letter-spacing="2" fill="${C.dim}">DAYS, COUNTED ON THE WALL</text>

  <!-- headline -->
  <text x="80" y="556" font-family="Inter" font-weight="600"
    font-size="${headline.length > 26 ? 54 : 64}" fill="#FFFFFF">${headline}</text>
  <text x="80" y="602" font-family="Roboto Mono" font-size="20"
    fill="${isClean ? C.dim : C.claude}">${sub}</text>

  <!-- data column -->
  <g font-family="Roboto Mono" font-size="19" fill="${C.dim}">
    <text x="1120" y="176" text-anchor="end">/ VOW #${vowId}</text>
    <text x="1120" y="210" text-anchor="end" fill="${C.amber}">/ ${stake} MON AT STAKE</text>
    <text x="1120" y="244" text-anchor="end">/ WEEKLY COHORT</text>
    <text x="1120" y="638" text-anchor="end" font-size="16">buildnothing.fun</text>
  </g>

  <!-- verdict stamp -->
  ${isClean ? stamp("CLEAN", C.cyan, 890, 470, -7) : stamp("RELAPSED", C.claude, 742, 470, -6)}
</svg>`;

const outPath = out ?? `card-${kind}-${hours}h.svg`;
await import("node:fs").then((fs) => fs.writeFileSync(outPath, svg));
console.log(`wrote ${outPath}`);
