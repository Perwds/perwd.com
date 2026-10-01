#!/usr/bin/env node
// Renders preview/species.svg: a contact sheet of every species, drawn with the
// same silhouette builders the preview page and the game's models use.
//
//   python3 scripts/export_config.py > /tmp/config.json
//   node scripts/build_species_sheet.mjs /tmp/config.json [mutation]

import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..");
const require = createRequire(import.meta.url);
const { fishShapeMarkup, fishPalette } = require(resolve(root, "preview/fish-svg.js"));

const configPath = process.argv[2];
const mutation = process.argv[3] ?? "None";
if (!configPath) {
  console.error("usage: node scripts/build_species_sheet.mjs <config.json> [mutation]");
  process.exit(1);
}

const data = JSON.parse(readFileSync(configPath, "utf8"));
const FISH = data.Fish;
const ZONES = data.Zones.Data;
const ZONE_ORDER = data.Zones.Order;
const RARITIES = data.Rarities.Data;

const COLS = 5;
const CELL_W = 208;
const CELL_H = 186;
const PAD = 28;
const HEADER_H = 58;
const TITLE_H = 96;

const rgb = (c) => `rgb(${Math.round(c.r)},${Math.round(c.g)},${Math.round(c.b)})`;

function weight(kg) {
  if (kg < 0.01) return `${(kg * 1000).toFixed(1)} g`;
  if (kg < 1) return `${Math.round(kg * 1000)} g`;
  if (kg < 100) return `${kg.toFixed(2)} kg`;
  if (kg < 1000) return `${Math.round(kg)} kg`;
  return `${(kg / 1000).toFixed(1)} t`;
}

const groups = ZONE_ORDER.map((id) => ({ id, members: FISH.filter((f) => f.zone === id) }));

let height = TITLE_H + PAD;
for (const group of groups) {
  height += HEADER_H + Math.ceil(group.members.length / COLS) * CELL_H;
}
height += PAD;

const width = PAD * 2 + COLS * CELL_W;
const parts = [];

parts.push(`<rect width="${width}" height="${height}" fill="#0a0c12"/>`);
parts.push(`<text x="${PAD}" y="48" font-family="Helvetica,Arial,sans-serif" font-size="30"
  font-weight="800" fill="#eef2fa">Fishing RNG — every species</text>`);
parts.push(`<text x="${PAD}" y="74" font-family="ui-monospace,Menlo,monospace" font-size="13"
  fill="#5e677a">${FISH.length} fish across ${groups.length} zones · ${
  mutation === "None" ? "plain" : mutation.toLowerCase()
} · built from 8 silhouette archetypes, no uploaded models</text>`);

let y = TITLE_H + PAD;

for (const group of groups) {
  const zone = ZONES[group.id];
  parts.push(`<text x="${PAD}" y="${y + 20}" font-family="ui-monospace,Menlo,monospace"
    font-size="12" font-weight="600" letter-spacing="2" fill="#8d97ac">${zone.name.toUpperCase()}</text>`);
  parts.push(`<line x1="${PAD}" y1="${y + 34}" x2="${width - PAD}" y2="${y + 34}" stroke="#1e2330"/>`);
  y += HEADER_H;

  group.members.forEach((record, index) => {
    const col = index % COLS;
    const row = Math.floor(index / COLS);
    const x = PAD + col * CELL_W;
    const cy = y + row * CELL_H;
    const tier = RARITIES[record.rarity];
    const palette = fishPalette(record, mutation);

    parts.push(`<rect x="${x + 4}" y="${cy}" width="${CELL_W - 8}" height="${CELL_H - 12}"
      rx="12" fill="#0e1017" stroke="#1e2330"/>`);

    // The art is drawn in a 120x72 box; scale it into the cell, leaving room
    // for the three text lines underneath.
    const artW = CELL_W - 56;
    const scale = artW / 120;
    parts.push(`<g transform="translate(${x + 28}, ${cy + 14}) scale(${scale.toFixed(4)})">${
      fishShapeMarkup(record, mutation)
    }</g>`);

    const textY = cy + 14 + 72 * scale + 20;
    const label = (data.Mutations.Data[mutation].prefix ? data.Mutations.Data[mutation].prefix + " " : "") + record.name;
    parts.push(`<text x="${x + 18}" y="${textY}" font-family="Helvetica,Arial,sans-serif"
      font-size="13" font-weight="700" fill="${rgb(palette.body)}">${label}</text>`);
    parts.push(`<rect x="${x + 18}" y="${textY + 10}" width="7" height="7" rx="2" fill="${rgb(tier.color)}"/>`);
    parts.push(`<text x="${x + 31}" y="${textY + 17}" font-family="ui-monospace,Menlo,monospace"
      font-size="10" letter-spacing="1" fill="${rgb(tier.color)}">${record.rarity.toUpperCase()}</text>`);
    parts.push(`<text x="${x + 18}" y="${textY + 33}" font-family="ui-monospace,Menlo,monospace"
      font-size="10" fill="#5e677a">${weight(record.kg[0])} – ${weight(record.kg[1])} · ${record.shape}</text>`);
  });

  y += Math.ceil(group.members.length / COLS) * CELL_H;
}

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"
  viewBox="0 0 ${width} ${height}">${parts.join("\n")}</svg>\n`;

const out = resolve(root, mutation === "None" ? "preview/species.svg" : `preview/species-${mutation.toLowerCase()}.svg`);
writeFileSync(out, svg);
console.log(`wrote ${out.replace(root + "/", "")} (${(svg.length / 1024).toFixed(0)} KB, ${width}x${height})`);
