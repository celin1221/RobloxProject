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
const meta = { name: 'Loja', category: 'prop' };
async function build() {
  const root = createRoot('Loja');
  const wood = mat('Wood', 0x8A5A34, { roughness: 0.8 }), woodD = mat('WoodDark', 0x5C3A22, { roughness: 0.8 });
  const red = mat('Pillar', 0xB3262E), roof = mat('Roof', 0x1F8F86), white = mat('Cloth', 0xF4F1EA);
  const gold = mat('Gold', 0xE6B84A, { metalness: 0.7, roughness: 0.3 }), stone = mat('Stone', 0x6B6F7E);
  const potR = mat('PotionR', 0xFF4D6D, { emissive: 0xFF4D6D, emissiveIntensity: 0.5 }), potB = mat('PotionB', 0x3D8BFF, { emissive: 0x3D8BFF, emissiveIntensity: 0.5 });
  // frente = +X. 8.4 (Z) x 5.6 (X)
  createPart('Floor', boxGeo(5.6, 0.4, 8.4), stone, { position: [0, 0.2, 0], parent: root });
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) createPart(`Post${sx}${sz}`, boxGeo(0.4, 3.6, 0.4), red, { position: [sx * 2.4, 2.2, sz * 3.8], parent: root });
  createPart('Counter', boxGeo(1.0, 1.1, 7.2), wood, { position: [1.9, 0.95, 0], parent: root });
  createPart('CounterTop', boxGeo(1.3, 0.14, 7.6), woodD, { position: [1.9, 1.55, 0], parent: root });
  createPart('Back', boxGeo(0.3, 3.2, 7.6), woodD, { position: [-2.5, 2.0, 0], parent: root });
  for (let k = 0; k < 3; k++) createPart('Shelf' + k, boxGeo(0.7, 0.1, 7.2), wood, { position: [-2.15, 1.2 + k * 0.8, 0], parent: root });
  const r = rng(7);
  for (let k = 0; k < 3; k++) for (let j = 0; j < 9; j++) {
    const m = (j + k) % 2 ? potR : potB;
    createPart(`Pot${k}_${j}`, cylinderGeo(0.11, 0.14, 0.34, 8), m, { position: [-2.1, 1.42 + k * 0.8, -3.2 + j * 0.8 + r() * 0.1], parent: root });
  }
  for (let j = 0; j < 4; j++) createPart('Crate' + j, boxGeo(0.6, 0.6, 0.6), wood, { position: [1.9 + (j % 2 ? 0.1 : -0.1), 1.92, -3 + j * 2], rotation: [0, r() * 30, 0], parent: root });
  // toldo listrado e telhado curvo
  for (let s = 0; s < 8; s++) createPart('Awning' + s, boxGeo(1.4, 0.08, 1.05), s % 2 ? white : roof, { position: [3.0, 3.75, -3.68 + s * 1.05], rotation: [0, 0, -20], parent: root });
  createPart('Roof', await curvedGable(9.6, 7.0, 1.6), roof, { position: [-0.1, 4.0, 0], rotation: [0, 90, 0], parent: root });
  createPart('RoofRidge', boxGeo(0.3, 0.3, 9.8), gold, { position: [-0.1, 5.6, 0], parent: root });
  createPart('Sign', boxGeo(0.15, 0.9, 3.6), woodD, { position: [3.35, 4.3, 0], parent: root });
  createPart('SignFrame', boxGeo(0.12, 1.05, 3.8), gold, { position: [3.3, 4.3, 0], parent: root });
  return root;
}
