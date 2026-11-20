const meta = { name: 'TorrePagode', category: 'prop' };
function mat(label, hex, opts) { const m = gameMaterial(hex, opts); m.name = `${label}_${hex.toString(16).toUpperCase().padStart(6,'0')}`; return m; }
function roofGeo(side, h) {
  // telhado quadrado com curva concava (lathe de 4 lados), beiral grosso
  const R = side / Math.SQRT2, r = R * 0.22;
  const prof = [];
  const N = 7;
  for (let i = 0; i <= N; i++) { const t = i / N; prof.push([r + (R - r) * Math.pow(1 - t, 1.8), h * t]); }
  prof.push([r * 0.5, h]); prof.push([r * 0.5, h * 0.96]);
  for (let i = N; i >= 0; i--) { const t = i / N; prof.push([(r + (R - r) * Math.pow(1 - t, 1.8)) * 0.93, h * t - 0.22]); }
  // fecha o beiral: borda de baixo liga a casca de dentro com a de fora (sem fresta)
  prof.push([R * 1.0, -0.22]); prof.push([R, 0]);
  return lathe(prof, 4);
}
function build() {
  const root = createRoot('TorrePagode');
  const stone = mat('Stone', 0x6B6F7E, { roughness: 0.9 });
  const stoneDark = mat('StoneDark', 0x4A4D5C, { roughness: 0.9 });
  const wall = mat('Wall', 0x2E2840, { roughness: 0.8 });
  const pillar = mat('Pillar', 0xB3262E, { roughness: 0.6 });
  const roof = mat('Roof', 0x24365A, { roughness: 0.7 });
  const gold = mat('Gold', 0xE6B84A, { metalness: 0.8, roughness: 0.3 });
  const glow = mat('Window', 0xFFC86B, { emissive: 0xFFB347, emissiveIntensity: 1.0 });
  const plaque = mat('Plaque', 0x2A1A12, { roughness: 0.8 });
  const crystal = mat('Crystal', 0x8FF3FF, { emissive: 0x59E1FF, emissiveIntensity: 1.2 });
  // base de pedra em degraus
  createPart('Plinth1', boxGeo(17, 1.2, 17), stoneDark, { position: [0, 0.6, 0], parent: root });
  createPart('Plinth2', boxGeo(15.2, 1.0, 15.2), stone, { position: [0, 1.7, 0], parent: root });
  // escada da entrada (+X = frente)
  for (let i = 0; i < 4; i++) createPart('Step' + i, boxGeo(0.7, 0.55 * (i + 1), 5), stone, { position: [8.85 + (3 - i) * 0.7 - 0.35 - 0.0, 0.275 * (i + 1), 0], parent: root });
  let y = 2.2;
  const sides = [11.5, 10.0, 8.6, 7.2, 5.9];
  sides.forEach((w, i) => {
    const hBody = i === 0 ? 4.6 : 3.6;
    createPart('Body' + i, boxGeo(w, hBody, w), wall, { position: [0, y + hBody / 2, 0], parent: root });
    // pilares vermelhos nos cantos e no meio de cada lado
    for (const sx of [-1, 0, 1]) for (const sz of [-1, 0, 1]) {
      if (sx === 0 && sz === 0) continue;
      if (sx !== 0 && sz !== 0 || true) {
        const px = sx * (w / 2 + 0.05), pz = sz * (w / 2 + 0.05);
        if (Math.abs(sx) + Math.abs(sz) === 0) continue;
        if (i === 0 && sx === 1 && sz === 0) continue; // sem pilastra no meio da porta
        createPart(`P${i}_${sx}_${sz}`, boxGeo(0.45, hBody, 0.45), pillar, { position: [px, y + hBody / 2, pz], parent: root });
      }
    }
    // janelas acesas nos 4 lados (porta grande no terreo, frente +X)
    for (const [dx, dz, rot] of [[1, 0, 0], [-1, 0, 0], [0, 1, 90], [0, -1, 90]]) {
      const isDoor = i === 0 && dx === 1;
      const ww = isDoor ? 3.0 : w * 0.18, wh = isDoor ? 3.4 : hBody * 0.42;
      const off = w / 2 + 0.06;
      for (const s of isDoor ? [0] : [-1, 1]) {
        const lat = isDoor ? 0 : s * w * 0.22;
        createPart(`W${i}_${dx}_${dz}_${s}`, boxGeo(0.12, wh, ww), glow, { position: [dx * off + (dz ? lat : 0), y + (isDoor ? wh / 2 : hBody * 0.55), dz * off + (dx ? lat : 0)], rotation: [0, rot, 0], parent: root });
      }
    }
    if (i === 0) {
      const off = w / 2 + 0.06;
      createPart('DoorFrameTop', boxGeo(0.3, 0.3, 3.6), gold, { position: [off + 0.08, y + 3.55, 0], parent: root });
      for (const s of [-1, 1]) createPart('DoorFrame' + s, boxGeo(0.3, 3.7, 0.3), gold, { position: [off + 0.08, y + 1.85, s * 1.65], parent: root });
      createPart('Plaque', boxGeo(0.2, 0.75, 3.0), plaque, { position: [off + 0.12, y + 4.15, 0], parent: root });
      createPart('PlaqueFrame', boxGeo(0.16, 0.9, 3.2), gold, { position: [off + 0.06, y + 4.15, 0], parent: root });
    }
    // faixa dourada no topo do corpo
    createPart('Band' + i, boxGeo(w + 0.5, 0.3, w + 0.5), gold, { position: [0, y + hBody + 0.15, 0], parent: root });
    y += hBody + 0.3;
    // telhado curvo + ganchos dourados nos cantos
    const rs = w + 3.2, rh = 1.9;
    createPart('Roof' + i, roofGeo(rs, rh), roof, { position: [0, y - 0.1, 0], rotation: [0, 45, 0], parent: root });
    createPart('Soffit' + i, boxGeo(rs * 0.99, 0.3, rs * 0.99), roof, { position: [0, y - 0.24, 0], parent: root });
    createPart('RoofTrim' + i, boxGeo(rs * 0.72, 0.18, rs * 0.72), gold, { position: [0, y + 0.02, 0], parent: root });
    const c = rs / 2 * 0.98;
    for (const [sx, sz] of [[1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      createPart(`Hook${i}_${sx}_${sz}`, coneGeo(0.32, 1.2, 6), gold, { position: [sx * c, y + 0.25, sz * c], rotation: [sz * 35, 0, -sx * 35], parent: root });
    }
    y += rh * 0.55;
  });
  // agulha dourada e cristal
  const spire = [[0.55, 0], [0.55, 0.5], [0.32, 0.6], [0.32, 1.6], [0.5, 1.7], [0.5, 1.9], [0.22, 2.0], [0.22, 3.2], [0.4, 3.3], [0.4, 3.45], [0.15, 3.55], [0.15, 4.2], [0, 4.2]];
  createPart('Spire', lathe([[0, 0], ...spire], 10), gold, { position: [0, y, 0], parent: root });
  for (let k = 0; k < 4; k++) createPart('Ring' + k, cylinderGeo(0.75 - k * 0.1, 0.75 - k * 0.1, 0.12, 12), gold, { position: [0, y + 0.8 + k * 0.6, 0], parent: root });
  y += 4.2;
  createPart('Crystal', lathe([[0, 0], [1.1, 1.4], [0, 3.6]], 6), crystal, { position: [0, y + 0.6, 0], parent: root });
  createPart('CrystalHolder', lathe([[0, 0], [0.9, 0.2], [0.6, 0.7], [0, 0.7]], 6), gold, { position: [0, y, 0], parent: root });
  return root;
}
