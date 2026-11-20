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
const meta = { name: 'PlacaBase', category: 'prop' };
function build() {
  const root = createRoot('PlacaBase');
  const wood = mat('Wood', 0x8A5A34), plank = mat('Plank', 0xE8D2A6), roof = mat('Roof', 0x24365A);
  for (const sz of [-1, 1]) createPart('Post' + sz, boxGeo(0.16, 2.0, 0.16), wood, { position: [0, 1.0, sz * 1.05], parent: root });
  createPart('Plank', boxGeo(0.12, 0.8, 2.3), plank, { position: [0.06, 1.45, 0], parent: root });
  createPart('Frame', boxGeo(0.1, 0.92, 2.42), wood, { position: [0.0, 1.45, 0], parent: root });
  for (const sx of [-1, 1]) createPart('Roof' + sx, boxGeo(0.34, 0.06, 2.7), roof, { position: [sx * 0.14, 2.06, 0], rotation: [0, 0, -sx * 28], parent: root });
  return root;
}
