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
const meta = { name: 'Pedras', category: 'prop' };
async function build() {
  const root = createRoot('Pedras');
  const rock = mat('Rock', 0x8A8F9C), moss = mat('Moss', 0x5E9E4E);
  const r = rng(33);
  const pts = [];
  for (let i = 0; i < 16; i++) { const a = r() * 6.283, b = r(); pts.push(createPart('q', sphereGeo(0.35, 4, 3), rock, { position: [Math.cos(a) * (0.9 + r() * 0.4), b * 1.3, Math.sin(a) * (0.7 + r() * 0.4)] })); }
  const g = await hull('Rock', ...pts, { smooth: false }); g.material = rock; root.add(g);
  const mp = [];
  for (let i = 0; i < 8; i++) { const a = r() * 6.283; mp.push(createPart('m', sphereGeo(0.3, 4, 3), moss, { position: [Math.cos(a) * 0.5, 1.35 + r() * 0.15, Math.sin(a) * 0.4] })); }
  const m = await hull('Moss', ...mp, { smooth: false }); m.material = moss; root.add(m);
  return root;
}
