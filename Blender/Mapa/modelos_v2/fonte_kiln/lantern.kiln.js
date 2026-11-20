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
const meta = { name: 'LanternaPedra', category: 'prop' };
function build() {
  const root = createRoot('LanternaPedra');
  const stone = mat('Stone', 0x9095A2), glow = mat('Glow', 0xFFD9A0, { emissive: 0xFFB347, emissiveIntensity: 1.0 });
  createPart('Base', cylinderGeo(0.32, 0.38, 0.22, 6), stone, { position: [0, 0.11, 0], parent: root });
  createPart('Pole', cylinderGeo(0.12, 0.15, 0.75, 6), stone, { position: [0, 0.6, 0], parent: root });
  createPart('Plate', cylinderGeo(0.34, 0.28, 0.12, 6), stone, { position: [0, 1.03, 0], parent: root });
  createPart('Light', boxGeo(0.36, 0.34, 0.36), glow, { position: [0, 1.26, 0], parent: root });
  for (const [x, z] of [[1, 1], [1, -1], [-1, 1], [-1, -1]]) createPart(`C${x}${z}`, boxGeo(0.07, 0.34, 0.07), stone, { position: [x * 0.19, 1.26, z * 0.19], parent: root });
  createPart('Roof', lathe([[0, 0], [0.5, 0], [0.42, 0.08], [0.2, 0.25], [0.06, 0.32], [0, 0.32]], 6), stone, { position: [0, 1.43, 0], parent: root });
  createPart('Jewel', sphereGeo(0.07, 6, 4), stone, { position: [0, 1.78, 0], parent: root });
  return root;
}
