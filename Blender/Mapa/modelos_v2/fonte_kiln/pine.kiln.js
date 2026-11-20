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
const meta = { name: 'Pinheiro', category: 'prop' };
function build() {
  const root = createRoot('Pinheiro');
  const bark = mat('Bark', 0x5A3A2E), g1 = mat('Pine', 0x2E7D4F), g2 = mat('PineLight', 0x3FA066);
  createPart('Trunk', cylinderGeo(0.2, 0.3, 1.8, 7), bark, { position: [0, 0.9, 0], parent: root });
  const tiers = [[1.9, 2.0, 1.2], [1.55, 1.8, 2.3], [1.15, 1.6, 3.3], [0.75, 1.4, 4.2]];
  tiers.forEach(([rad, h, y], i) => createPart('Tier' + i, coneGeo(rad, h, 7), i % 2 ? g2 : g1, { position: [0, y + h / 2, 0], rotation: [0, i * 23, 0], parent: root }));
  return root;
}
