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
const meta = { name: 'Pedreira', category: 'prop' };
async function build() {
  const root = createRoot('Pedreira');
  const rock = mat('Rock', 0x7A7F8C, { roughness: 0.95 }), rockD = mat('RockDark', 0x5A5E6B), ore = mat('Ore', 0xE07B2C, { emissive: 0xE07B2C, emissiveIntensity: 0.6 }), wood = mat('Wood', 0x8A5A34), metal = mat('Metal', 0x9AA0AA, { metalness: 0.6 });
  const r = rng(11);
  const blobs = [];
  const rocks = [[-1.2, 0, 0, 1.6], [0.6, 0, -1.4, 1.2], [0.4, 0, 1.5, 1.3], [-2.4, 0, 1.6, 0.9], [-2.2, 0, -1.7, 1.0]];
  for (const [x, y, z, s] of rocks) {
    const pts = [];
    for (let i = 0; i < 14; i++) { const a = r() * 6.283, b = r() * 1.4; pts.push(createPart('p', sphereGeo(0.3 * s, 4, 3), rock, { position: [x + Math.cos(a) * s * (0.6 + r() * 0.5), y + b * s * 1.25, z + Math.sin(a) * s * (0.6 + r() * 0.5)] })); }
    blobs.push(await hull('Rock' + blobs.length, ...pts, { smooth: false }));
  }
  blobs.forEach((g, i) => { g.material = i % 2 ? rockD : rock; root.add(g); });
  // veios de minerio
  for (let k = 0; k < 9; k++) createPart('Ore' + k, lathe([[0, 0], [0.12, 0.05], [0, 0.55]], 5), ore, { position: [-1.6 + r() * 2.6, 1.6 + r() * 1.4, -1.5 + r() * 3.0], rotation: [r() * 60 - 30, r() * 360, r() * 60 - 30], parent: root });
  // carrinho de minerio
  createPart('Cart', boxGeo(0.9, 0.5, 0.6), wood, { position: [1.9, 0.5, 0], parent: root });
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) createPart(`Wheel${sx}${sz}`, cylinderGeo(0.15, 0.15, 0.08, 10), metal, { position: [1.9 + sx * 0.3, 0.17, sz * 0.33], rotation: [90, 0, 0], parent: root });
  for (let k = 0; k < 4; k++) createPart('Load' + k, sphereGeo(0.16, 5, 4), ore, { position: [1.75 + (k % 2) * 0.3, 0.8, -0.15 + (k > 1 ? 0.3 : 0)], parent: root });
  return root;
}
