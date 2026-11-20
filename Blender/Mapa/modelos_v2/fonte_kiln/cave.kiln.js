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
const meta = { name: 'CavernaRefugio', category: 'prop' };
async function rockBlob(name, pts3, m) {
  const parts = pts3.map(([x, y, z, s]) => createPart('q', sphereGeo(s, 4, 3), m, { position: [x, y, z] }));
  const g = await hull(name, ...parts, { smooth: false }); g.material = m; return g;
}
async function build() {
  const root = createRoot('CavernaRefugio');
  const rock = mat('Rock', 0x6E7484), rockD = mat('RockDark', 0x4A4F5E), moss = mat('Moss', 0x5E9E4E), portal = mat('Portal', 0x9B6BFF, { emissive: 0x8A5CFF, emissiveIntensity: 1.3 }), crystal = mat('Crystal', 0x7FE8FF, { emissive: 0x59E1FF, emissiveIntensity: 1.0 }), dark = mat('Inside', 0x120E22);
  const r = rng(9);
  // arco de rocha, abertura virada para +X (2.2 m de largura, 2.6 m de altura)
  const left = [], right = [], top = [];
  for (let i = 0; i < 10; i++) { left.push([r() * 1.2 - 0.6, r() * 3.0, -1.6 - r() * 0.9, 0.5]); right.push([r() * 1.2 - 0.6, r() * 3.0, 1.6 + r() * 0.9, 0.5]); top.push([r() * 1.4 - 0.7, 2.9 + r() * 0.9, r() * 4.4 - 2.2, 0.5]); }
  root.add(await rockBlob('Left', left, rock)); root.add(await rockBlob('Right', right, rock)); root.add(await rockBlob('Top', top, rockD));
  const back = []; for (let i = 0; i < 10; i++) back.push([-1.0 - r() * 0.8, r() * 3.4, r() * 3.6 - 1.8, 0.6]);
  root.add(await rockBlob('Back', back, rockD));
  const mossP = []; for (let i = 0; i < 8; i++) mossP.push([r() * 1.2 - 0.6, 3.7 + r() * 0.4, r() * 3.6 - 1.8, 0.35]);
  root.add(await rockBlob('Moss', mossP, moss));
  createPart('Inside', boxGeo(0.2, 2.6, 2.4), dark, { position: [-0.55, 1.3, 0], parent: root });
  createPart('Portal', boxGeo(0.08, 2.3, 2.0), portal, { position: [-0.35, 1.25, 0], parent: root });
  for (let k = 0; k < 7; k++) createPart('Cr' + k, lathe([[0, 0], [0.12, 0.08], [0, 0.6 + r() * 0.4]], 5), crystal, { position: [0.3 + r() * 0.5, 0.05, (k % 2 ? 1 : -1) * (1.3 + r() * 0.5)], rotation: [r() * 40 - 20, r() * 360, r() * 40 - 20], parent: root });
  return root;
}
