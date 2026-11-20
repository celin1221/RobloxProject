function mat(label, hex, opts) { const m = gameMaterial(hex, opts); m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6,'0')}`; return m; }
function roofGeo(side, h, curve) {
  const R = side / Math.SQRT2, r = R * 0.2, k = curve || 1.9, prof = [], N = 7;
  for (let i = 0; i <= N; i++) { const t = i / N; prof.push([r + (R - r) * Math.pow(1 - t, k), h * t]); }
  prof.push([r * 0.5, h]); prof.push([r * 0.5, h * 0.96]);
  for (let i = N; i >= 0; i--) { const t = i / N; prof.push([(r + (R - r) * Math.pow(1 - t, k)) * 0.93, h * t - 0.2]); }
  return lathe(prof, 4);
}
// telhado de duas aguas curvo ao longo de X (largura w em Z, comprimento L em X)
function curvedGable(L, w, h) {
  const prof = [], N = 6;
  for (let i = 0; i <= N; i++) { const t = i / N; prof.push([-w / 2 + (w / 2) * t, h * Math.pow(t, 1.6)]); }
  for (let i = N - 1; i >= 0; i--) { const t = i / N; prof.push([w / 2 - (w / 2) * t, h * Math.pow(t, 1.6)]); }
  for (let i = 0; i <= N; i++) { const t = i / N; prof.push([w / 2 - (w / 2) * t * 0.98, h * Math.pow(t, 1.6) - 0.16]); }
  for (let i = N - 1; i >= 1; i--) { const t = i / N; prof.push([-w / 2 + (w / 2) * t * 0.98, h * Math.pow(t, 1.6) - 0.16]); }
  return extrudeProfile(prof, { depth: L, axis: 'x' });
}
function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }
// Forja: nivel por variavel de ambiente LEVEL (1, 4, 7 ou 10)
const LEVEL = 7;
const meta = { name: 'Forja', category: 'prop' };
function build() {
  const root = createRoot('Forja');
  const stone = mat('Stone', 0x6B6F7E), stoneD = mat('StoneDark', 0x484B58), metal = mat('Metal', 0x3C4048, { metalness: 0.7, roughness: 0.4 });
  const fire = mat('Fire', 0xFF8A2B, { emissive: 0xFF6A1A, emissiveIntensity: 1.4 }), gold = mat('Gold', 0xE6B84A, { metalness: 0.8, roughness: 0.3 }), crystal = mat('Crystal', 0x9B6BFF, { emissive: 0x8A5CFF, emissiveIntensity: 1.2 }), wood = mat('Wood', 0x8A5A34);
  const L = LEVEL;
  const s = L >= 10 ? 1.35 : L >= 7 ? 1.2 : L >= 4 ? 1.1 : 1.0;
  // fornalha (frente +X)
  createPart('Base', boxGeo(2.4 * s, 0.4, 2.4 * s), stoneD, { position: [0, 0.2, 0], parent: root });
  createPart('Furnace', lathe([[0, 0], [1.05 * s, 0], [1.0 * s, 1.4 * s], [0.75 * s, 1.9 * s], [0.45 * s, 2.1 * s], [0, 2.1 * s]], 8), stone, { position: [-0.3, 0.4, 0], parent: root });
  createPart('Mouth', boxGeo(0.3, 0.8 * s, 0.9 * s), fire, { position: [0.62 * s, 0.4 + 0.55 * s, 0], parent: root });
  createPart('Chimney', cylinderGeo(0.28 * s, 0.32 * s, (L >= 4 ? 2.2 : 1.4) * s, 8), stoneD, { position: [-0.5, 0.4 + 2.1 * s + (L >= 4 ? 1.1 : 0.7) * s, 0], parent: root });
  if (L >= 4) for (let k = 0; k < 3; k++) createPart('Band' + k, cylinderGeo(1.03 * s, 1.03 * s, 0.1, 8), L >= 7 ? gold : metal, { position: [-0.3, 0.7 + k * 0.45 * s, 0], parent: root });
  // bigorna
  createPart('AnvilBase', boxGeo(0.35, 0.5, 0.35), metal, { position: [1.7 * s, 0.65, 0.9], parent: root });
  createPart('Anvil', boxGeo(0.45, 0.25, 0.9), metal, { position: [1.7 * s, 1.0, 0.9], parent: root });
  createPart('Horn', coneGeo(0.12, 0.4, 6), metal, { position: [1.7 * s, 1.0, 1.55], rotation: [90, 0, 0], parent: root });
  createPart('Stump', cylinderGeo(0.3, 0.35, 0.4, 8), wood, { position: [1.7 * s, 0.2, 0.9], parent: root });
  if (L >= 7) { createPart('Rune', cylinderGeo(1.6 * s, 1.6 * s, 0.04, 16), fire, { position: [0, 0.42, 0], parent: root }); createPart('Crown', lathe([[0, 0], [0.55 * s, 0], [0.6 * s, 0.35], [0.35 * s, 0.25], [0, 0.6]], 8), gold, { position: [-0.3, 0.4 + 2.1 * s, 0], parent: root }); }
  if (L >= 10) for (let k = 0; k < 4; k++) { const a = k * Math.PI / 2 + 0.6; createPart('Cr' + k, lathe([[0, 0], [0.2, 0.12], [0, 1.2]], 5), crystal, { position: [Math.cos(a) * 1.9, 0.4, Math.sin(a) * 1.9], rotation: [Math.sin(a) * 15, 0, -Math.cos(a) * 15], parent: root }); }
  return root;
}
