const meta = { name: 'StarInvoke', category: 'prop' };
function mat(label, hex, opts) { const m = gameMaterial(hex, opts); m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6,'0')}`; return m; }
// estrela 3D "estufada": cada ponta e o miolo sao cascas convexas; o centro e alto na frente e atras e as bordas sao finas
async function build() {
  const root = createRoot('StarInvoke');
  const body = mat('Body', 0xFFD447, { emissive: 0xFFB020, emissiveIntensity: 0.4, roughness: 0.3 });
  const R = 1.0, r = 0.45, edge = 0.07, mid = 0.36, cy = 1.2;
  const P = (i, rad) => { const a = Math.PI / 2 + i * Math.PI / 5; return [rad * Math.cos(a), rad * Math.sin(a)]; };
  const dot = (x, y, z) => createPart('q', sphereGeo(0.012, 4, 3), body, { position: [x, cy + y, z] });
  // eixo da espessura = X (frente +X), estrela no plano YZ
  const pt = (yz, x) => dot(x, yz[1], yz[0]);
  for (let k = 0; k < 5; k++) {
    const tip = P(2 * k, R), l = P(2 * k - 1, r), rr = P(2 * k + 1, r);
    const pts = [pt(tip, edge), pt(tip, -edge), pt(l, edge * 1.6), pt(l, -edge * 1.6), pt(rr, edge * 1.6), pt(rr, -edge * 1.6), dot(mid, 0, 0), dot(-mid, 0, 0)];
    const g = await hull('Arm' + k, ...pts, { smooth: false }); g.material = body; root.add(g);
  }
  const inner = [];
  for (let k = 0; k < 5; k++) { const q = P(2 * k + 1, r); inner.push(pt(q, edge * 1.6), pt(q, -edge * 1.6)); }
  const c = await hull('Core', ...inner, dot(mid, 0, 0), dot(-mid, 0, 0), { smooth: false }); c.material = body; root.add(c);
  return root;
}
