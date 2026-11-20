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
const meta = { name: 'LanternaPapel', category: 'prop' };
function build() {
  const root = createRoot('LanternaPapel');
  const wood = mat('Wood', 0x5C3A22), lamp = mat('Lamp', 0xFF5A4E, { emissive: 0xFF6A3D, emissiveIntensity: 0.9 }), gold = mat('Gold', 0xE6B84A, { metalness: 0.7 });
  createPart('Pole', boxGeo(0.12, 2.5, 0.12), wood, { position: [0, 1.25, 0], parent: root });
  createPart('Arm', boxGeo(0.7, 0.08, 0.08), wood, { position: [0.3, 2.42, 0], parent: root });
  createPart('Lamp', lathe([[0, 0], [0.16, 0.02], [0.26, 0.15], [0.28, 0.32], [0.26, 0.5], [0.16, 0.62], [0, 0.64]], 10), lamp, { position: [0.58, 1.68, 0], parent: root });
  createPart('CapT', cylinderGeo(0.14, 0.14, 0.06, 10), gold, { position: [0.58, 2.34, 0], parent: root });
  createPart('CapB', cylinderGeo(0.14, 0.14, 0.06, 10), gold, { position: [0.58, 1.68, 0], parent: root });
  return root;
}
