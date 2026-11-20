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
  const potG = mat('PotionG', 0x4DE07A, { emissive: 0x4DE07A, emissiveIntensity: 0.5 });
  const glass = mat('Glass', 0xDDF6FF, { roughness: 0.1 });
  const cork = mat('Cork', 0xA8774A);
  const books = [mat('BookR', 0xC0392B), mat('BookB', 0x2E5EAA), mat('BookG', 0x2E8B57), mat('BookY', 0xD9A527)];
  const liquids = [potR, potB, potG];
  // frasco redondo: vidro, liquido brilhante dentro e rolha
  const flaskProf = [[0, 0], [0.12, 0.01], [0.17, 0.08], [0.18, 0.16], [0.15, 0.24], [0.07, 0.29], [0.055, 0.31], [0.055, 0.42], [0, 0.42]];
  const liquidProf = [[0, 0.02], [0.11, 0.03], [0.155, 0.09], [0.16, 0.16], [0.13, 0.22], [0, 0.22]];
  let n = 0;
  for (let k = 0; k < 3; k++) {
    const sy = 1.25 + k * 0.8;
    let z = -3.35;
    while (z < 3.2) {
      if ((n % 4) === 3) {
        // pilha de livros em pe
        for (let b = 0; b < 3; b++) {
          const h = 0.34 + r() * 0.12;
          createPart(`Book${k}_${n}_${b}`, boxGeo(0.26, h, 0.09), books[(n + b) % 4], { position: [-2.1, sy + h / 2, z + b * 0.1], rotation: [b === 2 ? 12 : 0, 0, 0], parent: root });
        }
        z += 0.5;
      } else {
        const lq = liquids[n % 3];
        createPart(`Flask${k}_${n}`, await lathe(flaskProf, 10), glass, { position: [-2.1, sy, z], parent: root });
        createPart(`Liquid${k}_${n}`, await lathe(liquidProf, 10), lq, { position: [-2.1, sy, z], parent: root });
        createPart(`Cork${k}_${n}`, cylinderGeo(0.065, 0.06, 0.08, 8), cork, { position: [-2.1, sy + 0.45, z], parent: root });
        z += 0.48;
      }
      n++;
    }
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
