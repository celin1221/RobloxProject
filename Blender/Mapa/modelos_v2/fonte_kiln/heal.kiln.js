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
const meta = { name: 'CentroCura', category: 'prop' };
function build() {
  const root = createRoot('CentroCura');
  const stone = mat('Stone', 0x8A8E9C), wall = mat('Wall', 0xF6EFE6), red = mat('Pillar', 0xB3262E);
  const roof = mat('Roof', 0xC2409A), gold = mat('Gold', 0xE6B84A, { metalness: 0.7, roughness: 0.3 });
  const water = mat('Water', 0x7DF0C8, { emissive: 0x4BE0A0, emissiveIntensity: 0.9 }), leaf = mat('Leaf', 0xFF8BD0, { emissive: 0xFF6FB8, emissiveIntensity: 0.4 });
  // 5.6 x 5.6, frente +X aberta
  createPart('Base', boxGeo(5.8, 0.6, 5.8), stone, { position: [0, 0.3, 0], parent: root });
  for (let i = 0; i < 2; i++) createPart('Step' + i, boxGeo(0.5, 0.3 * (i + 1), 2.6), stone, { position: [3.15 + (1 - i) * 0.5, 0.15 * (i + 1), 0], parent: root });
  createPart('WallBack', boxGeo(0.3, 3.0, 5.0), wall, { position: [-2.4, 2.1, 0], parent: root });
  for (const sz of [-1, 1]) createPart('WallSide' + sz, boxGeo(3.6, 3.0, 0.3), wall, { position: [-0.6, 2.1, sz * 2.4], parent: root });
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) createPart(`Post${sx}${sz}`, boxGeo(0.4, 3.2, 0.4), red, { position: [sx * 2.5, 2.2, sz * 2.5], parent: root });
  createPart('Band', boxGeo(5.6, 0.3, 5.6), red, { position: [0, 3.85, 0], parent: root });
  createPart('Roof', roofGeo(8.4, 2.2, 2.0), roof, { position: [0, 4.0, 0], rotation: [0, 45, 0], parent: root });
  createPart('Top', lathe([[0, 0], [0.4, 0], [0.25, 0.4], [0.3, 0.8], [0, 1.2]], 8), gold, { position: [0, 6.1, 0], parent: root });
  // fonte de cura com lotus
  createPart('Basin', lathe([[0, 0], [1.2, 0], [1.35, 0.5], [1.1, 0.55], [1.0, 0.25], [0, 0.25]], 14), stone, { position: [0.3, 0.6, 0], parent: root });
  createPart('Water', cylinderGeo(1.05, 1.05, 0.06, 14), water, { position: [0.3, 1.0, 0], parent: root });
  for (let k = 0; k < 6; k++) { const a = k * 60; createPart('Petal' + k, boxGeo(0.55, 0.08, 0.28), leaf, { position: [0.3 + Math.cos(a * Math.PI / 180) * 0.3, 1.12, Math.sin(a * Math.PI / 180) * 0.3], rotation: [0, -a, 25], parent: root }); }
  createPart('Orb', sphereGeo(0.28, 10, 8), water, { position: [0.3, 1.45, 0], parent: root });
  return root;
}
