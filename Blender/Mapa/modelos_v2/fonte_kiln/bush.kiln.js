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
const meta = { name: 'Arbustos', category: 'prop' };
async function blob(name, cx, cy, cz, s, m, r, n) {
  const pts = [];
  for (let i = 0; i < (n || 14); i++) { const a = r() * 6.283, b = r(); pts.push(createPart('q', sphereGeo(0.3 * s, 4, 3), m, { position: [cx + Math.cos(a) * s * (0.7 + r() * 0.3), cy + b * s * 0.8, cz + Math.sin(a) * s * (0.7 + r() * 0.3)] })); }
  const g = await hull(name, ...pts, { smooth: false }); g.material = m; return g;
}
async function build() {
  const root = createRoot('Arbustos');
  const g = mat('Bush', 0x4FA35A), gl = mat('BushLight', 0x7CC66A), fl = [mat('FlowerPink', 0xFF7AB8, { emissive: 0xFF7AB8, emissiveIntensity: 0.2 }), mat('FlowerYellow', 0xFFD447, { emissive: 0xFFD447, emissiveIntensity: 0.2 }), mat('FlowerWhite', 0xFFFFFF)];
  const r = rng(21);
  root.add(await blob('B1', 0, 0.1, 0, 0.8, g, r)); root.add(await blob('B2', 0.7, 0.05, 0.3, 0.55, gl, r)); root.add(await blob('B3', -0.6, 0.05, -0.2, 0.5, gl, r));
  for (let k = 0; k < 12; k++) { const a = r() * 6.283, d = 0.3 + r() * 0.6; createPart('F' + k, sphereGeo(0.09, 5, 4), fl[k % 3], { position: [Math.cos(a) * d, 0.55 + r() * 0.5, Math.sin(a) * d], parent: root }); }
  return root;
}
