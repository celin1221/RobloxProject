const meta = { name: 'StarInvoke', category: 'prop' };
function mat(label, hex, opts) { const m = gameMaterial(hex, opts); m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6,'0')}`; return m; }
async function build() {
  const root = createRoot('StarInvoke');
  const body = mat('Body', 0xFFD447, { emissive: 0xFFB020, emissiveIntensity: 0.4, roughness: 0.3 });
  const core = mat('Core', 0xFFFFFF, { emissive: 0xFFFFFF, emissiveIntensity: 1.0 });
  const pts = [];
  for (let i = 0; i < 10; i++) { const r = i % 2 === 0 ? 1.0 : 0.46; const a = Math.PI/2 + i*Math.PI/5; pts.push([r*Math.cos(a), r*Math.sin(a)]); }
  const g = await extrudeProfile(pts, { depth: 0.42, bevel: 0.08, taper: 0.0, axis: 'x', segments: 3 });
  createPart('Star', g, body, { position: [0, 1.2, 0], parent: root });
  // bico em cada face (forma de estrela 3D gordinha)
  const inner = [];
  for (let i = 0; i < 10; i++) { const r = i % 2 === 0 ? 0.62 : 0.3; const a = Math.PI/2 + i*Math.PI/5; inner.push([r*Math.cos(a), r*Math.sin(a)]); }
  const g2 = await extrudeProfile(inner, { depth: 0.58, bevel: 0.05, axis: 'x', segments: 2 });
  createPart('StarCore', g2, core, { position: [0, 1.2, 0], parent: root });
  return root;
}
