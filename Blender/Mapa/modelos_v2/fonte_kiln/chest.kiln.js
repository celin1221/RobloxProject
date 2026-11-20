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
const meta = { name: 'BauRefugio', category: 'prop' };
async function build() {
  const root = createRoot('BauRefugio');
  const wood = mat('Wood', 0x8A4F2A), woodD = mat('WoodDark', 0x5C3A22), gold = mat('Gold', 0xE6B84A, { metalness: 0.8, roughness: 0.3 }), gem = mat('Gem', 0xFF4FA3, { emissive: 0xFF4FA3, emissiveIntensity: 0.8 });
  createPart('Box', boxGeo(0.9, 0.6, 1.4), wood, { position: [0, 0.3, 0], parent: root });
  const arc = []; for (let i = 0; i <= 10; i++) { const a = Math.PI * i / 10; arc.push([Math.cos(a) * 0.47, Math.sin(a) * 0.32]); }
  createPart('Lid', await extrudeProfile(arc, { depth: 1.42, axis: 'z' }), woodD, { position: [0, 0.6, 0], parent: root });
  for (const z of [-0.5, 0.5]) createPart('LidBand' + z, await extrudeProfile(arc.map(([x, y]) => [x * 1.03, y * 1.05]), { depth: 0.12, axis: 'z' }), gold, { position: [0, 0.6, z], parent: root });
  for (const z of [-0.5, 0, 0.5]) createPart('Band' + z, boxGeo(0.95, 0.08, 0.12), gold, { position: [0, 0.32, z], parent: root });
  createPart('Lock', boxGeo(0.12, 0.22, 0.22), gold, { position: [0.47, 0.55, 0], parent: root });
  createPart('Gem', sphereGeo(0.07, 8, 6), gem, { position: [0.54, 0.56, 0], parent: root });
  return root;
}
