// Fish silhouettes, shared by the preview page and the static species sheet.
// One builder per archetype, matching the geometry FishModel.luau assembles out
// of primitives, so both are a fair likeness of what the game renders.
//
// Self-contained: its own colour helpers, so the sheet generator can load it
// without the page around it.

const _mix = (a, b, t) => ({ r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t });
const _css = (c) => `rgb(${Math.round(c.r)} ${Math.round(c.g)} ${Math.round(c.b)})`;
const _rgba = (c, a) => `rgb(${Math.round(c.r)} ${Math.round(c.g)} ${Math.round(c.b)} / ${a})`;

// Port of FishModel.TREATMENTS: a mutation repaints the whole fish.
const TREATMENTS = {
  None: {},
  Shiny: { lighten: 0.18 },
  Albino: { toward: { r: 248, g: 246, b: 250 }, blend: 0.86 },
  Golden: { toward: { r: 255, g: 190, b: 40 }, blend: 0.92, metal: true },
  Radioactive: { toward: { r: 140, g: 255, b: 70 }, blend: 0.64, glow: true },
  Void: { toward: { r: 44, g: 18, b: 78 }, blend: 0.8, glow: true, accent: { r: 150, g: 90, b: 255 } },
  Celestial: { toward: { r: 150, g: 230, b: 255 }, blend: 0.7, glow: true, accent: { r: 240, g: 250, b: 255 } },
  Glitched: { toward: { r: 255, g: 60, b: 220 }, blend: 0.95, glow: true, accent: { r: 90, g: 255, b: 230 } },
};

function fishPalette(record, mutation) {
  const t = TREATMENTS[mutation] ?? TREATMENTS.None;
  let body = { r: record.color[0], g: record.color[1], b: record.color[2] };
  if (t.toward) body = _mix(body, t.toward, t.blend);
  if (t.lighten) body = _mix(body, { r: 255, g: 255, b: 255 }, t.lighten);
  return {
    body,
    fin: t.accent ?? _mix(body, { r: 0, g: 0, b: 0 }, 0.26),
    belly: _mix(body, { r: 255, g: 255, b: 255 }, 0.34),
    accent: t.accent ?? _mix(body, { r: 255, g: 255, b: 255 }, 0.5),
    glow: t.glow ? (t.accent ?? body) : null,
    metal: !!t.metal,
  };
}

const EYE = (x, y, r = 4.2) =>
  `<circle cx="${x}" cy="${y}" r="${r}" fill="#f7fafd"/>` +
  `<circle cx="${x + r * 0.36}" cy="${y}" r="${r * 0.46}" fill="#11121a"/>`;

// Drawn in a 120x72 box, nose to the right.
const SILHOUETTE = {
  round: (p) => `
    <path d="M30 36 L6 18 L11 36 L6 54 Z" fill="${_css(p.fin)}"/>
    <path d="M50 20 L66 7 L74 21 Z" fill="${_css(p.fin)}"/>
    <path d="M58 47 L50 63 L72 51 Z" fill="${_css(p.fin)}" opacity=".9"/>
    <ellipse cx="58" cy="36" rx="30" ry="17" fill="${_css(p.body)}"/>
    <ellipse cx="56" cy="43" rx="23" ry="8" fill="${_css(p.belly)}" opacity=".8"/>
    ${EYE(76, 31)}`,

  long: (p) => `
    <path d="M110 34 Q 92 23 66 28 Q 40 33 18 35 L10 25 L7 47 L18 38
             Q 40 41 66 44 Q 92 47 110 34 Z" fill="${_css(p.body)}"/>
    <path d="M66 28 Q 68 21 76 20 Q 72 26 72 29 Z" fill="${_css(p.fin)}"/>
    ${EYE(97, 31, 3.6)}`,

  flat: (p) => `
    <path d="M52 34 Q 26 33 4 30 Q 26 38 52 38 Z" fill="${_css(p.fin)}"/>
    <path d="M104 36
             C 94 18, 66 2, 18 9
             C 40 22, 50 30, 52 36
             C 50 42, 40 50, 18 63
             C 66 70, 94 54, 104 36 Z" fill="${_css(p.body)}"/>
    <path d="M96 36 C 86 24, 66 16, 44 20 C 56 28, 60 32, 61 36
             C 60 40, 56 44, 44 52 C 66 56, 86 48, 96 36 Z"
          fill="${_css(p.belly)}" opacity=".28"/>
    ${EYE(90, 30, 3.2)}${EYE(90, 42, 3.2)}`,

  bulb: (p) => `
    <path d="M16 38 L2 24 L5 38 L2 52 Z" fill="${_css(p.fin)}"/>
    <ellipse cx="30" cy="38" rx="15" ry="13" fill="${_css(p.body)}"/>
    <ellipse cx="62" cy="37" rx="29" ry="26" fill="${_css(p.body)}"/>
    <path d="M56 50 Q 76 62 90 48 L 87 42 Q 70 52 54 46 Z" fill="${_css(p.belly)}"/>
    ${[0, 1, 2, 3, 4].map((i) => `<path d="M${62 + i * 6} 50 l2.6 6 l2.6 -6 Z" fill="#f2f0e6"/>`).join("")}
    <path d="M70 13 Q 88 1 97 11" stroke="${_css(p.fin)}" stroke-width="2.6" fill="none"/>
    <circle cx="98" cy="12" r="6.4" fill="${_css(p.accent)}"/>
    ${EYE(76, 28, 6)}`,

  orb: (p) => `
    <ellipse cx="60" cy="36" rx="31" ry="12" fill="none"
             stroke="${_css(p.accent)}" stroke-width="2.6" opacity=".65"/>
    <circle cx="60" cy="36" r="20" fill="${_css(p.body)}"/>
    <circle cx="66" cy="30" r="7" fill="${_css(p.accent)}" opacity=".9"/>`,

  crab: (p) => `
    ${[-1, 0, 1].flatMap((row) => [-1, 1].map((side) =>
      `<path d="M${60 + row * 13} ${36 + side * 12} q ${side * -4} ${side * 11} ${-16} ${side * 13}"
             stroke="${_css(p.fin)}" stroke-width="3" fill="none" stroke-linecap="round"/>`)).join("")}
    <ellipse cx="60" cy="36" rx="26" ry="16" fill="${_css(p.body)}"/>
    ${[-1, 1].map((side) =>
      `<ellipse cx="90" cy="${36 + side * 11}" rx="9" ry="6" fill="${_css(p.accent)}"
                transform="rotate(${side * 22} 90 ${36 + side * 11})"/>`).join("")}
    ${EYE(66, 29, 3.4)}${EYE(66, 43, 3.4)}`,

  squid: (p) => `
    ${[0, 1, 2, 3, 4, 5, 6, 7].map((i) => {
      const spread = (i - 3.5) / 3.5;
      return `<path d="M52 ${36 + spread * 9} Q 30 ${36 + spread * 20} 8 ${36 + spread * 26}"
                    stroke="${_css(p.fin)}" stroke-width="3.4" fill="none" stroke-linecap="round"/>`;
    }).join("")}
    <ellipse cx="74" cy="36" rx="26" ry="18" fill="${_css(p.body)}"/>
    <path d="M98 36 Q 112 27 112 36 Q 112 45 98 36 Z" fill="${_css(p.body)}"/>
    ${EYE(62, 28, 5)}${EYE(62, 44, 5)}`,

  seahorse: (p) => `
    <path d="M58 11 Q 78 16 73 32 Q 68 46 53 47 Q 39 49 43 60 Q 47 69 58 64"
          stroke="${_css(p.body)}" stroke-width="13" fill="none" stroke-linecap="round"/>
    <path d="M60 8 L80 3" stroke="${_css(p.belly)}" stroke-width="5.5" stroke-linecap="round"/>
    ${[0, 1, 2].map((i) =>
      `<path d="M${64 - i * 4} ${16 + i * 9} l6 -4 l-1 6 Z" fill="${_css(p.fin)}"/>`).join("")}
    ${EYE(66, 13, 3.4)}`,
};

// Returns the inner markup only, so callers can wrap it in their own <svg>
// or <g> at whatever size they need.
function fishShapeMarkup(record, mutation) {
  const builder = SILHOUETTE[record.shape];
  return builder ? builder(fishPalette(record, mutation)) : "";
}

// w/h are CSS pixels; the art is drawn in a 120x72 box.
function fishSvg(record, mutation, w, h) {
  const markup = fishShapeMarkup(record, mutation);
  if (!markup) return "";

  const palette = fishPalette(record, mutation);
  const glow = palette.glow
    ? ` style="filter: drop-shadow(0 0 ${Math.max(w / 18, 3)}px ${_rgba(palette.glow, 0.75)})"`
    : "";

  return `<svg viewBox="0 0 120 72" width="${w}" height="${h}" role="img"
    aria-label="${record.name}"${glow}>${markup}</svg>`;
}

if (typeof module !== "undefined") {
  module.exports = { fishSvg, fishShapeMarkup, fishPalette, SILHOUETTE, TREATMENTS };
}
