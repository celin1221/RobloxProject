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
const meta = { name: 'Placar', category: 'prop' };
async function build() {
  const root = createRoot('Placar');
  const red = mat('Pillar', 0xB3262E), dark = mat('Panel', 0x1E1748), gold = mat('Gold', 0xE6B84A, { metalness: 0.7, roughness: 0.3 }), roof = mat('Roof', 0x24365A), stone = mat('Stone', 0x6B6F7E);
  // 7.3 (Z) x 5.6 (Y), frente +X
  for (const sz of [-1, 1]) { createPart('Post' + sz, boxGeo(0.45, 6.2, 0.45), red, { position: [0, 3.1, sz * 3.6], parent: root }); createPart('Foot' + sz, boxGeo(0.9, 0.5, 0.9), stone, { position: [0, 0.25, sz * 3.6], parent: root }); }
  createPart('Panel', boxGeo(0.25, 4.4, 6.6), dark, { position: [-0.05, 3.4, 0], parent: root });
  createPart('Frame', boxGeo(0.2, 4.7, 6.9), gold, { position: [-0.12, 3.4, 0], parent: root });
  createPart('Beam', boxGeo(0.6, 0.45, 8.6), red, { position: [0, 6.0, 0], parent: root });
  createPart('Roof', await curvedGable(9.4, 1.8, 0.7), roof, { position: [0, 6.3, 0], rotation: [0, 90, 0], parent: root });
  return root;
}
