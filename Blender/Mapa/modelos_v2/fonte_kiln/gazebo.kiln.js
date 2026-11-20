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
const meta = { name: 'Pavilhao', category: 'prop' };
function build() {
  const root = createRoot('Pavilhao');
  const wood = mat('Wood', 0x8A5A34), red = mat('Pillar', 0xB3262E), roof = mat('Roof', 0x24365A), gold = mat('Gold', 0xE6B84A, { metalness: 0.7 }), stone = mat('Stone', 0x8A8E9C);
  createPart('Deck', cylinderGeo(1.9, 2.0, 0.3, 6), stone, { position: [0, 0.15, 0], parent: root });
  for (let k = 0; k < 6; k++) { const a = k * Math.PI / 3; createPart('Post' + k, cylinderGeo(0.1, 0.12, 2.4, 8), red, { position: [Math.cos(a) * 1.6, 1.5, Math.sin(a) * 1.6], parent: root }); }
  createPart('Roof', lathe([[0, 0], [2.6, 0.0], [2.2, 0.25], [1.2, 0.8], [0.3, 1.3], [0, 1.35], [0, 0]], 6), roof, { position: [0, 2.65, 0], parent: root });
  createPart('Top', sphereGeo(0.18, 8, 6), gold, { position: [0, 4.05, 0], parent: root });
  createPart('Bench', boxGeo(1.6, 0.12, 0.45), wood, { position: [0, 0.6, 0], parent: root });
  return root;
}
