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
const meta = { name: 'Cerejeira', category: 'prop' };
async function blob(name, cx, cy, cz, s, m, r, n) {
  const pts = [];
  for (let i = 0; i < (n || 16); i++) { const a = r() * 6.283, b = r() * 2 - 1; pts.push(createPart('q', sphereGeo(0.32 * s, 4, 3), m, { position: [cx + Math.cos(a) * s * Math.sqrt(1 - b * b) * (0.8 + r() * 0.3), cy + b * s * 0.7, cz + Math.sin(a) * s * Math.sqrt(1 - b * b) * (0.8 + r() * 0.3)] })); }
  const g = await hull(name, ...pts, { smooth: false }); g.material = m; return g;
}
async function build() {
  const root = createRoot('Cerejeira');
  const bark = mat('Bark', 0x5A3A2E), pink = mat('Blossom', 0xFFB0D2), pinkD = mat('BlossomDark', 0xF27BB4), pinkL = mat('BlossomLight', 0xFFD9EA);
  const r = rng(5);
  createPart('Trunk', cylinderGeo(0.22, 0.38, 2.6, 7), bark, { position: [0, 1.3, 0], rotation: [0, 0, 6], parent: root });
  const br = [[0.9, 2.9, 0.4, 35, 25], [-0.8, 3.0, -0.3, -30, -20], [0.1, 3.2, -0.9, 10, -35]];
  for (const [x, y, z, rz, rx] of br) createPart('Branch', cylinderGeo(0.1, 0.18, 1.6, 6), bark, { position: [x * 0.5, y - 0.3, z * 0.5], rotation: [rx, 0, -rz], parent: root });
  const cl = [[0, 3.9, 0, 1.7, pink], [1.3, 3.5, 0.5, 1.2, pinkD], [-1.2, 3.6, -0.4, 1.25, pinkL], [0.2, 3.5, -1.3, 1.1, pinkD], [-0.4, 4.6, 0.6, 1.0, pinkL], [0.6, 3.4, 1.2, 1.0, pink]];
  for (const [x, y, z, s, m] of cl) root.add(await blob('Leaves', x, y, z, s, m, r));
  return root;
}
