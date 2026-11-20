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
const meta = { name: 'PortaoBase', category: 'prop' };
function build() {
  const root = createRoot('PortaoBase');
  const red = mat('Pillar', 0xC8283A), black = mat('Beam', 0x2A2230), gold = mat('Gold', 0xE6B84A, { metalness: 0.7, roughness: 0.3 }), stone = mat('Stone', 0x6B6F7E);
  // torii 3.4 m de vao (Z), 3.6 m de altura, frente +X
  for (const sz of [-1, 1]) { createPart('Post' + sz, cylinderGeo(0.17, 0.2, 3.4, 10), red, { position: [0, 1.7, sz * 1.7], parent: root }); createPart('Foot' + sz, cylinderGeo(0.27, 0.3, 0.35, 10), black, { position: [0, 0.17, sz * 1.7], parent: root }); }
  createPart('Nuki', boxGeo(0.22, 0.24, 4.2), red, { position: [0, 2.75, 0], parent: root });
  createPart('Kasagi', bend(boxGeo(0.34, 0.32, 5.0, 1, 1, 16), { angle: 0 }), black, { position: [0, 3.55, 0], parent: root });
  createPart('Shimaki', boxGeo(0.3, 0.2, 4.6), red, { position: [0, 3.3, 0], parent: root });
  for (const sz of [-1, 1]) createPart('Tip' + sz, coneGeo(0.12, 0.45, 6), black, { position: [0, 3.72, sz * 2.55], rotation: [sz * 70, 0, 0], parent: root });
  createPart('Plate', boxGeo(0.12, 0.5, 0.5), gold, { position: [0.13, 3.03, 0], parent: root });
  return root;
}
