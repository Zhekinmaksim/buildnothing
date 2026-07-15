#!/usr/bin/env node
// BUILD NOTHING share cards - abstinence graph (GitHub grid, inverted pride).
// Type: Schibsted Grotesk (display) + Roboto Mono (labels, per Monad kit).
// usage: node generate-grid.mjs clean|relapsed hours vowDays vowId stakeMON out.svg

const [, , kind = "clean", hoursArg = "288", vowDaysArg = "14", vowId = "1", stake = "10", out] = process.argv;
const hours = Number(hoursArg);
const vowDays = Number(vowDaysArg);
const cleanDays = Math.min(Math.floor(hours / 24), vowDays);
const isClean = kind === "clean";

const C = {
  bg: "#0E091C", bgGlow: "#1A1230",
  cell: "#DDD7FE", cellEmpty: "#2A2046",
  dim: "#7C6DB0", purple: "#6E54FF",
  amber: "#FFAE45", cyan: "#85E6FF", claude: "#D97757",
};

// ---- layout budget (1200x675) ----------------------------------------------
// header ends ~120 · grid block 148..492 · caption 518 · headline 584 · sub 622
const CELL = 40, GAP = 9, ROWS = 7;
const gx = 82, gy = 148;
const gridBottom = gy + ROWS * (CELL + GAP) - GAP; // 483

let cells = "";
for (let d = 0; d < vowDays; d++) {
  const col = Math.floor(d / ROWS);
  const row = d % ROWS;
  const x = gx + col * (CELL + GAP);
  const y = gy + row * (CELL + GAP);
  const isRelapseDay = !isClean && d === cleanDays;
  const done = d < cleanDays;
  if (isRelapseDay) {
    cells += `<rect x="${x}" y="${y}" width="${CELL}" height="${CELL}" rx="7" fill="${C.claude}"/>
    <path d="M ${x + 12} ${y + 12} L ${x + CELL - 12} ${y + CELL - 12} M ${x + CELL - 12} ${y + 12} L ${x + 12} ${y + CELL - 12}"
      stroke="${C.bg}" stroke-width="4.5" stroke-linecap="round"/>`;
  } else if (done) {
    const t = 0.66 + 0.34 * (d / Math.max(vowDays - 1, 1));
    cells += `<rect x="${x}" y="${y}" width="${CELL}" height="${CELL}" rx="7" fill="${C.cell}" opacity="${t.toFixed(2)}"/>`;
  } else {
    cells += `<rect x="${x + 1.5}" y="${y + 1.5}" width="${CELL - 3}" height="${CELL - 3}" rx="7"
      fill="none" stroke="${C.cellEmpty}" stroke-width="2.5"/>`;
  }
}

// ---- stamp with measured box ------------------------------------------------
function stamp(text, color, cx, cy, rot) {
  const fs = 44, ls = 6;
  const advance = fs * 0.6 + ls;             // Roboto Mono advance + tracking
  const textW = text.length * advance - ls;  // no trailing tracking
  const padX = 30, padY = 20;
  const W = textW + padX * 2, H = fs + padY * 2;
  return `
  <g transform="translate(${cx} ${cy}) rotate(${rot})" opacity="0.96">
    <rect x="${-W / 2}" y="${-H / 2}" width="${W}" height="${H}" fill="none" stroke="${color}" stroke-width="5.5" rx="4"/>
    <rect x="${-W / 2 + 7}" y="${-H / 2 + 7}" width="${W - 14}" height="${H - 14}" fill="none" stroke="${color}" stroke-width="1.5" rx="2" opacity="0.55"/>
    <text x="${ls / 2}" y="${fs * 0.34}" text-anchor="middle" font-family="Roboto Mono" font-weight="500"
      font-size="${fs}" letter-spacing="${ls}" fill="${color}">${text}</text>
  </g>`;
}

const headline = isClean ? `I built nothing for ${hours} hours` : `Lasted ${hours} hours`;
const sub = isClean
  ? `${cleanDays} of ${vowDays} days clean · the only graph where empty means winning`
  : `day ${cleanDays + 1}: claude code session detected. the chain does not forget.`;

const svg = `<svg width="1200" height="675" viewBox="0 0 1200 675" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <radialGradient id="bg" cx="38%" cy="30%" r="90%">
      <stop offset="0%" stop-color="${C.bgGlow}"/>
      <stop offset="100%" stop-color="${C.bg}"/>
    </radialGradient>
  </defs>
  <rect width="1200" height="675" fill="url(#bg)"/>
  <rect x="0" y="668" width="1200" height="7" fill="${C.purple}"/>

  <text x="80" y="84" font-family="Schibsted Grotesk" font-weight="500" font-size="32"
    letter-spacing="9" fill="#FFFFFF">BUILD NOTHING</text>
  <text x="80" y="114" font-family="Roboto Mono" font-size="15" letter-spacing="3"
    fill="${C.dim}">/ A VOW OF ABSTINENCE FROM VIBECODING · WITNESSED ON MONAD</text>

  ${cells}
  <text x="${gx}" y="${gridBottom + 34}" font-family="Roboto Mono" font-size="14"
    letter-spacing="2" fill="${C.dim}">ABSTINENCE GRAPH · ONE CELL = ONE DAY WITHOUT CLAUDE CODE</text>

  <text x="80" y="588" font-family="Schibsted Grotesk" font-weight="600"
    font-size="${headline.length > 28 ? 52 : 60}" fill="#FFFFFF">${headline}</text>
  <text x="80" y="626" font-family="Roboto Mono" font-size="19"
    fill="${isClean ? C.dim : C.claude}">${sub}</text>

  <g font-family="Roboto Mono" font-size="18" fill="${C.dim}">
    <text x="1120" y="172" text-anchor="end">/ VOW #${vowId}</text>
    <text x="1120" y="204" text-anchor="end" fill="${C.amber}">/ ${stake} MON AT STAKE</text>
    <text x="1120" y="236" text-anchor="end">/ WEEKLY COHORT</text>
    <text x="1120" y="636" text-anchor="end" font-size="15">buildnothing.fun</text>
  </g>

  ${isClean ? stamp("CLEAN", C.cyan, 965, 462, -7) : stamp("RELAPSED", C.claude, 900, 462, -6)}
</svg>`;

const outPath = out ?? `grid-${kind}.svg`;
await import("node:fs").then((fs) => fs.writeFileSync(outPath, svg));
console.log(`wrote ${outPath}`);
