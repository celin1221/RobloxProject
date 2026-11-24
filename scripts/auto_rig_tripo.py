#!/usr/bin/env python3
r"""
auto_rig_tripo.py — Pipeline Automático Tripo (.glb / .fbx) -> Roblox Studio (R6-on-R15 Sólido)

Uso (via Blender headless):
    D:\Blender\blender.exe --background --python scripts/auto_rig_tripo.py -- \
        --input "d:/Downloads/personagem_tripo.glb" \
        --char "San" \
        --max-tris 7500

O que este script faz automaticamente em ~5 segundos:
1. Importa qualquer arquivo `.glb`, `.gltf` ou `.fbx` vindo direto do Tripo (malha única em T-Pose)
   OU já separado em partes (`Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`).
2. Extrai a textura embutida para `Blender/<Char>/texturas/<Char>_Tex.png` e gera a variante
   `Brilhante` (`<Char>_Tex_Brilhante.png`).
3. Se for malha única (direto do Tripo sem passar no Mixamo nem cortar na mão):
   - Alinha o personagem em pé (+Z up, -Y frente), centraliza X/Y=0 e apoia os pés em Z=0.
   - Reduz a contagem de triângulos (Decimate) caso ultrapasse `--max-tris`.
   - Detecta automaticamente a anatomia Blocky (largura do tronco, linha dos ombros, cintura e pescoço).
   - Corta matematicamente com planos retos (`bmesh.ops.bisect_plane`) nas 6 partes:
     `Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`.
4. Se já vier separado em 6 partes, corrige polígonos de calça presos no `Torso`.
5. Rotaciona os braços da T-Pose (+90° / -90° Y) para a pose vertical de descanso do Rig.
6. Fecha todas as aberturas (`Caps`) amostrando a cor real da textura na borda de cada corte e
   adiciona faces internas espelhadas (Double-Sided) para eliminar 100% qualquer efeito oco no Studio.
7. Escala para a medida exata do esqueleto do jogo (`4.303` studs até a linha do ombro) e exporta:
   - `Blender/<Char>/modelo/<Char>_R6_Auto.blend`
   - `Blender/<Char>/modelo/<Char>_R6_Auto.fbx` (com `embed_textures=True` para o Roblox aplicar `TextureID` nativamente)
   - `Blender/<Char>/referencias/<Char>_preview_front.png` e `<Char>_preview_34.png`
"""

import sys
import os
import glob
import shutil
import zipfile
import math
import argparse
import colorsys
import bpy
import bmesh
from mathutils import Vector, Matrix


def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    parser = argparse.ArgumentParser(description="Auto-cut and rig Tripo 3D model for Roblox Studio")
    parser.add_argument("--input", required=True, help="Caminho do arquivo .glb / .fbx / .zip de entrada")
    parser.add_argument("--char", required=True, help="Nome/ID do personagem (ex: San, Kaen, BarbaBranca, Luffy)")
    parser.add_argument("--max-tris", type=int, default=7500, help="Limite de triângulos da malha base (antes do double-side)")
    parser.add_argument("--shoulder-height", type=float, default=4.303, help="Altura em studs do chão até o ombro (padrão 4.303; BarbaBranca 4.577)")
    parser.add_argument("--force-resplit", action="store_true", help="Une as partes e refaz o corte matemático por planos")
    return parser.parse_args(argv)


def ensure_fbm_textures(filepath: str, work_dir: str) -> str:
    """Se a entrada for .zip ou um .fbx sem a pasta .fbm ao lado, procura e extrai a textura automaticamente."""
    ext = os.path.splitext(filepath)[1].lower()
    if ext == ".zip":
        extract_dir = os.path.join(work_dir, "_zip_extracted")
        os.makedirs(extract_dir, exist_ok=True)
        with zipfile.ZipFile(filepath, 'r') as z:
            z.extractall(extract_dir)
        for root, _, files in os.walk(extract_dir):
            for f in files:
                if f.lower().endswith((".fbx", ".glb", ".gltf")):
                    return os.path.join(root, f)
        raise FileNotFoundError(f"Nenhum .fbx ou .glb encontrado dentro de {filepath}")

    if ext == ".fbx":
        base_no_ext = os.path.splitext(filepath)[0]
        fbm_dir = base_no_ext + ".fbm"
        fbx_basename = os.path.basename(filepath)
        if not os.path.exists(fbm_dir):
            # Procura em zips no Desktop e Downloads se esse fbx veio de um zip do Tripo
            search_dirs = [
                os.path.dirname(filepath),
                os.path.expanduser("~/Desktop"),
                os.path.expanduser("~/Downloads"),
                r"d:\Downloads",
            ]
            for sdir in search_dirs:
                if not os.path.exists(sdir):
                    continue
                for zpath in glob.glob(os.path.join(sdir, "*.zip")):
                    try:
                        with zipfile.ZipFile(zpath, 'r') as z:
                            names = z.namelist()
                            if any(os.path.basename(n) == fbx_basename for n in names):
                                print(f"Extraindo pasta .fbm encontrada dentro de {zpath}...")
                                z.extractall(os.path.dirname(filepath))
                                break
                    except Exception:
                        pass
    return filepath


def import_model(filepath: str, work_dir: str):
    filepath = ensure_fbm_textures(filepath, work_dir)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    ext = os.path.splitext(filepath)[1].lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=filepath)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=filepath)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=filepath)
    else:
        raise ValueError(f"Formato não suportado: {ext}")

    # Remove câmeras, luzes e armatures antigas
    for o in list(bpy.data.objects):
        if o.type != 'MESH':
            bpy.data.objects.remove(o, do_unlink=True)

    # Aplica matrix_world diretamente nos vértices
    for o in bpy.data.objects:
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)


def extract_and_make_shiny_texture(tex_dir: str, char_name: str):
    os.makedirs(tex_dir, exist_ok=True)
    base_tex_path = os.path.join(tex_dir, f"{char_name}_Tex.png")
    shiny_tex_path = os.path.join(tex_dir, f"{char_name}_Tex_Brilhante.png")

    main_img = None
    for img in bpy.data.images:
        if img.size[0] > 0 and img.size[1] > 0:
            main_img = img
            break

    if not main_img:
        print("WARN: Nenhuma imagem embutida encontrada no modelo.")
        return None, None, None

    main_img.filepath_raw = base_tex_path
    main_img.file_format = 'PNG'
    main_img.save()
    print(f"Textura base salva em: {base_tex_path} ({main_img.size[0]}x{main_img.size[1]})")

    # Gera textura Brilhante trocando matizes principais
    shiny_img = main_img.copy()
    shiny_img.name = f"{char_name}_Tex_Brilhante"
    pixels = list(shiny_img.pixels)
    for i in range(0, len(pixels), 4):
        r, g, b, a = pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if v < 0.28 and s < 0.35:
            t = max(0.0, min(1.0, (v - 0.03) / 0.25))
            nr, ng, nb = colorsys.hsv_to_rgb(46.0 / 360.0, 0.75 - 0.20 * t, 0.55 + 0.43 * t)
        else:
            nr, ng, nb = colorsys.hsv_to_rgb((h + 0.12) % 1.0, min(1.0, s * 0.95), min(1.0, v * 1.15 + 0.05))
        pixels[i], pixels[i + 1], pixels[i + 2] = nr, ng, nb
    shiny_img.pixels[:] = pixels
    shiny_img.filepath_raw = shiny_tex_path
    shiny_img.file_format = 'PNG'
    shiny_img.save()
    print(f"Textura Brilhante salva em: {shiny_tex_path}")

    return main_img, base_tex_path, shiny_tex_path


def get_bounds(obj):
    verts = [v.co for v in obj.data.vertices]
    xs = [v.x for v in verts]
    ys = [v.y for v in verts]
    zs = [v.z for v in verts]
    return (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs))


def percentile(vals, p):
    if not vals:
        return 0.0
    s = sorted(vals)
    idx = max(0, min(len(s) - 1, int(round(p * (len(s) - 1)))))
    return s[idx]


def auto_split_single_mesh(body_obj, max_tris: int):
    """Corta automaticamente uma malha única em T-Pose nas 6 partes R6 usando planos matemáticos."""
    # 1. Centraliza X/Y e coloca a sola dos pés em Z=0
    bx, by, bz = get_bounds(body_obj)
    cx = (bx[0] + bx[1]) * 0.5
    cy = (by[0] + by[1]) * 0.5
    min_z = bz[0]
    body_obj.data.transform(Matrix.Translation(Vector((-cx, -cy, -min_z))))

    # 2. Decimate se ultrapassar max_tris
    curr_tris = len(body_obj.data.polygons)
    if curr_tris > max_tris:
        ratio = max_tris / float(curr_tris)
        print(f"Decimando malha de {curr_tris} para ~{max_tris} triângulos (ratio={ratio:.3f})...")
        bpy.context.view_layer.objects.active = body_obj
        mod = body_obj.modifiers.new(name="AutoDecimate", type='DECIMATE')
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)

    bx, by, bz = get_bounds(body_obj)
    h_total = bz[1] - bz[0]

    # 3. Detecta dimensões anatômicas a partir da nuvem de vértices
    verts = [v.co for v in body_obj.data.vertices]
    # Largura do tronco/pernas medida em duas faixas: canelas [6%..22%] e cintura/peito baixo [40%..52%],
    # usando min(+X, -X) e min(canelas, tronco) para ser imune tanto a bolsas laterais (Usopp)
    # quanto a casacos/haoris abertos na barra (Byakuya)
    pos_low = [v.x for v in verts if 0.06 * h_total <= v.z <= 0.22 * h_total and v.x > 0]
    neg_low = [-v.x for v in verts if 0.06 * h_total <= v.z <= 0.22 * h_total and v.x < 0]
    pos_mid = [v.x for v in verts if 0.40 * h_total <= v.z <= 0.52 * h_total and v.x > 0]
    neg_mid = [-v.x for v in verts if 0.40 * h_total <= v.z <= 0.52 * h_total and v.x < 0]
    w_low = min(
        percentile(pos_low, 0.98) if pos_low else 0.17 * h_total,
        percentile(neg_low, 0.98) if neg_low else 0.17 * h_total,
    )
    w_mid = min(
        percentile(pos_mid, 0.98) if pos_mid else 0.17 * h_total,
        percentile(neg_mid, 0.98) if neg_mid else 0.17 * h_total,
    )
    w_core = min(w_low, w_mid)
    x_shoulder = w_core * 1.02

    # Faixa vertical dos braços em T-Pose medida nas pontas externas (|X| > 1.90 * w_core)
    # Usa min(topo braço esq, topo braço dir) para ignorar espinhos/armadura em um só braço (ex: Chad)
    l_arm_zs = [v.z for v in verts if v.x > 1.90 * w_core]
    r_arm_zs = [v.z for v in verts if v.x < -1.90 * w_core]
    if not l_arm_zs:
        l_arm_zs = [v.z for v in verts if v.x > 1.50 * w_core]
    if not r_arm_zs:
        r_arm_zs = [v.z for v in verts if v.x < -1.50 * w_core]
    arm_zs = l_arm_zs + r_arm_zs
    z_arm_max_l = max(l_arm_zs) if l_arm_zs else 0.70 * h_total
    z_arm_max_r = max(r_arm_zs) if r_arm_zs else 0.70 * h_total
    z_arm_max = min(z_arm_max_l, z_arm_max_r)
    # Espessura máxima de um braço blocky em T-Pose é ~0.195*H (ignora fitas soltas penduradas sob o braço, ex: Sarutobi)
    z_arm_min = max(min(arm_zs) - 0.008 * h_total, z_arm_max - 0.195 * h_total)
    z_neck = z_arm_max + 0.004 * h_total
    z_hip = z_neck * 0.492

    print(f"Anatomia detectada: H={h_total:.4f}, W_core={w_core:.4f} (low={w_low:.4f}, mid={w_mid:.4f}), X_shoulder=±{x_shoulder:.4f}, Z_arm=[{z_arm_min:.4f},{z_arm_max:.4f}] (L={z_arm_max_l:.4f}, R={z_arm_max_r:.4f}), Z_hip={z_hip:.4f}, Z_neck={z_neck:.4f}")

    # 4. Passa planos de corte matemáticos (bisect_plane) para criar arestas retas perfeitas nas juntas
    bm = bmesh.new()
    bm.from_mesh(body_obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002 * h_total)

    # Plano 1: Pescoço (Z = z_neck)
    geom_all = list(bm.verts) + list(bm.edges) + list(bm.faces)
    bmesh.ops.bisect_plane(bm, geom=geom_all, dist=0.00001 * h_total,
                           plane_co=Vector((0, 0, z_neck)), plane_no=Vector((0, 0, 1)))

    # Plano 2: Ombro Esquerdo (X = +x_shoulder, apenas para Z in [z_arm_min, z_neck])
    geom_l_arm = [f for f in bm.faces if any(v.co.z >= z_arm_min and v.co.x > 0 for v in f.verts)]
    geom_l_edges = list({e for f in geom_l_arm for e in f.edges})
    geom_l_verts = list({v for f in geom_l_arm for v in f.verts})
    bmesh.ops.bisect_plane(bm, geom=geom_l_verts + geom_l_edges + geom_l_arm, dist=0.00001 * h_total,
                           plane_co=Vector((x_shoulder, 0, 0)), plane_no=Vector((1, 0, 0)))

    # Plano 3: Ombro Direito (X = -x_shoulder, apenas para Z in [z_arm_min, z_neck])
    geom_r_arm = [f for f in bm.faces if any(v.co.z >= z_arm_min and v.co.x < 0 for v in f.verts)]
    geom_r_edges = list({e for f in geom_r_arm for e in f.edges})
    geom_r_verts = list({v for f in geom_r_arm for v in f.verts})
    bmesh.ops.bisect_plane(bm, geom=geom_r_verts + geom_r_edges + geom_r_arm, dist=0.00001 * h_total,
                           plane_co=Vector((-x_shoulder, 0, 0)), plane_no=Vector((1, 0, 0)))

    # Plano 4: Cintura (Z = z_hip, apenas para |X| <= x_shoulder * 1.15)
    geom_hip = [f for f in bm.faces if any(abs(v.co.x) <= x_shoulder * 1.15 for v in f.verts)]
    geom_hip_edges = list({e for f in geom_hip for e in f.edges})
    geom_hip_verts = list({v for f in geom_hip for v in f.verts})
    bmesh.ops.bisect_plane(bm, geom=geom_hip_verts + geom_hip_edges + geom_hip, dist=0.00001 * h_total,
                           plane_co=Vector((0, 0, z_hip)), plane_no=Vector((0, 0, 1)))

    # Plano 5: Divisão entre as pernas (X = 0, apenas para Z < z_hip)
    geom_legs = [f for f in bm.faces if all(v.co.z <= z_hip + 0.002 * h_total for v in f.verts)]
    geom_legs_edges = list({e for f in geom_legs for e in f.edges})
    geom_legs_verts = list({v for f in geom_legs for v in f.verts})
    bmesh.ops.bisect_plane(bm, geom=geom_legs_verts + geom_legs_edges + geom_legs, dist=0.00001 * h_total,
                           plane_co=Vector((0, 0, 0)), plane_no=Vector((1, 0, 0)))

    # Plano 6 (se necessário): corta abaixo de z_arm_min nos braços (para separar/descartar fitas soltas sob braços T-pose como Sarutobi)
    geom_under_arm = [f for f in bm.faces if any(abs(v.co.x) > x_shoulder * 1.10 and v.co.z <= z_arm_min + 0.02 * h_total for v in f.verts)]
    if geom_under_arm:
        gua_edges = list({e for f in geom_under_arm for e in f.edges})
        gua_verts = list({v for f in geom_under_arm for v in f.verts})
        bmesh.ops.bisect_plane(bm, geom=gua_verts + gua_edges + geom_under_arm, dist=0.00001 * h_total,
                               plane_co=Vector((0, 0, z_arm_min)), plane_no=Vector((0, 0, 1)))

    bmesh.ops.triangulate(bm, faces=bm.faces)
    uv_src = bm.loops.layers.uv.active
    mats = list(body_obj.data.materials)

    # 5. Distribui as faces nas 6 partes R6
    part_names = ["Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
    part_bms = {name: bmesh.new() for name in part_names}
    part_uvs = {name: part_bms[name].loops.layers.uv.new("UVMap") for name in part_names}

    for f in bm.faces:
        c = f.calc_center_median()
        if c.z >= z_neck and (abs(c.x) < x_shoulder or (c.z >= z_neck + 0.065 * h_total and abs(c.x) < x_shoulder * 1.45)):
            pname = "Head"
        elif c.x >= x_shoulder and c.z >= z_arm_min:
            pname = "LeftArm"
        elif c.x <= -x_shoulder and c.z >= z_arm_min:
            pname = "RightArm"
        elif abs(c.x) > x_shoulder * 1.65 and c.z < z_arm_min:
            # Descarta apenas pontas soltas de fitas flutuando longe sob os braços em T-Pose (ex: Sarutobi)
            continue
        elif c.z >= z_hip or (abs(c.x) > x_shoulder * 1.05 and c.z >= z_hip * 0.55 and abs(c.x) <= x_shoulder * 1.65):
            pname = "Torso"
        elif c.x >= 0:
            pname = "LeftLeg"
        else:
            pname = "RightLeg"

        t_bm = part_bms[pname]
        t_uv = part_uvs[pname]
        new_verts = [t_bm.verts.new(v.co) for v in f.verts]
        try:
            new_f = t_bm.faces.new(new_verts)
            if uv_src:
                for l_src, l_dst in zip(f.loops, new_f.loops):
                    l_dst[t_uv].uv = l_src[uv_src].uv.copy()
        except ValueError:
            pass

    bm.free()
    bpy.data.objects.remove(body_obj, do_unlink=True)

    # Limpa fragmentos desconectados espúrios (fitas flutuando atrás dos braços em Sarutobi, poeira de corte na Head)
    for pname in part_names:
        p_bm = part_bms[pname]
        bmesh.ops.remove_doubles(p_bm, verts=p_bm.verts, dist=0.00002 * h_total)
        visited = set()
        comps = []
        for f in p_bm.faces:
            if f in visited:
                continue
            q = [f]
            visited.add(f)
            comp = []
            while q:
                cur = q.pop()
                comp.append(cur)
                for e in cur.edges:
                    for nf in e.link_faces:
                        if nf not in visited:
                            visited.add(nf)
                            q.append(nf)
            comps.append(comp)
        if len(comps) > 1:
            comps.sort(key=len, reverse=True)
            main_n = len(comps[0])
            to_delete = []
            for comp in comps[1:]:
                ratio = len(comp) / float(main_n)
                if pname in ("LeftArm", "RightArm") and ratio < 0.25:
                    to_delete.extend(comp)
                elif pname == "Head" and ratio < 0.02:
                    to_delete.extend(comp)
                elif pname == "Torso" and ratio < 0.15:
                    max_abs_x = max(abs(v.co.x) for f in comp for v in f.verts)
                    if max_abs_x > x_shoulder * 1.12:
                        to_delete.extend(comp)
            if to_delete:
                bmesh.ops.delete(p_bm, geom=to_delete, context='FACES')
                print(f"Limpeza '{pname}': removidos {len(to_delete)} tris de fragmentos soltos.")

        mesh_data = bpy.data.meshes.new(pname)
        for m in mats:
            mesh_data.materials.append(m)
        p_bm.to_mesh(mesh_data)
        p_bm.free()
        obj = bpy.data.objects.new(pname, mesh_data)
        bpy.context.scene.collection.objects.link(obj)
        print(f"Criada parte '{pname}': {len(mesh_data.polygons)} tris")


def fix_existing_6_parts():
    """Se o modelo já veio com as 6 partes separadas, devolve faces da calça presas no Torso."""
    torso_obj = bpy.data.objects['Torso']
    rleg_obj = bpy.data.objects['RightLeg']
    lleg_obj = bpy.data.objects['LeftLeg']

    _, _, lz = get_bounds(lleg_obj)
    _, _, rz = get_bounds(rleg_obj)
    hip_top_z = max(lz[1], rz[1]) * 0.985

    bm_t = bmesh.new()
    bm_t.from_mesh(torso_obj.data)
    bm_r = bmesh.new()
    bm_r.from_mesh(rleg_obj.data)
    bm_l = bmesh.new()
    bm_l.from_mesh(lleg_obj.data)

    uv_t = bm_t.loops.layers.uv.active
    uv_r = bm_r.loops.layers.uv.active
    uv_l = bm_l.loops.layers.uv.active

    faces_to_remove = []
    for f in bm_t.faces:
        c = f.calc_center_median()
        if c.z < hip_top_z:
            target_bm = bm_r if c.x < 0 else bm_l
            target_uv = uv_r if c.x < 0 else uv_l
            new_verts = [target_bm.verts.new(v.co) for v in f.verts]
            try:
                new_f = target_bm.faces.new(new_verts)
                if uv_t and target_uv:
                    for l_src, l_dst in zip(f.loops, new_f.loops):
                        l_dst[target_uv].uv = l_src[uv_t].uv.copy()
            except ValueError:
                pass
            faces_to_remove.append(f)

    if faces_to_remove:
        bmesh.ops.delete(bm_t, geom=faces_to_remove, context='FACES')
        bmesh.ops.remove_doubles(bm_t, verts=bm_t.verts, dist=0.00005)
        bmesh.ops.remove_doubles(bm_r, verts=bm_r.verts, dist=0.00005)
        bmesh.ops.remove_doubles(bm_l, verts=bm_l.verts, dist=0.00005)
        bm_t.to_mesh(torso_obj.data)
        bm_r.to_mesh(rleg_obj.data)
        bm_l.to_mesh(lleg_obj.data)
        print(f"Transferidas {len(faces_to_remove)} faces abaixo da cintura do Torso para as pernas.")

    bm_t.free()
    bm_r.free()
    bm_l.free()


def pick_loop_representative_uv(comp_edges, uv_layer):
    """Escolhe um UV representativo das faces adjacentes à borda do corte (sem cruzar ilhas UV)."""
    uvs = []
    for e in comp_edges:
        for l in e.link_loops:
            uvs.append(l[uv_layer].uv.copy())
    if not uvs:
        return Vector((0.5, 0.5))
    # Escolhe o UV real da malha mais próximo da mediana para nunca cair fora da ilha UV
    med_u = percentile([u.x for u in uvs], 0.5)
    med_v = percentile([u.y for u in uvs], 0.5)
    med = Vector((med_u, med_v))
    best_uv = min(uvs, key=lambda u: (u - med).length_squared)
    return best_uv


def cap_and_solidify_all():
    """Fecha todas as bordas abertas (Caps) e adiciona faces internas espelhadas (Double-Sided)."""
    for obj in bpy.data.objects:
        if obj.type != 'MESH':
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00002)
        uv_layer = bm.loops.layers.uv.active

        boundary_edges = [e for e in bm.edges if e.is_boundary]
        visited = set()
        caps_added = 0

        for start_e in boundary_edges:
            if start_e in visited:
                continue
            comp_edges = []
            comp_verts = set()
            queue = [start_e]
            visited.add(start_e)
            while queue:
                curr_e = queue.pop(0)
                comp_edges.append(curr_e)
                for v in curr_e.verts:
                    comp_verts.add(v)
                    for ne in v.link_edges:
                        if ne.is_boundary and ne not in visited:
                            visited.add(ne)
                            queue.append(ne)

            if len(comp_edges) < 3:
                continue

            cap_uv = pick_loop_representative_uv(comp_edges, uv_layer) if uv_layer else Vector((0.5, 0.5))
            verts_list = list(comp_verts)
            center_co = sum((v.co for v in verts_list), Vector((0, 0, 0))) / len(verts_list)
            v_center = bm.verts.new(center_co)

            for e in comp_edges:
                v1, v2 = e.verts[0], e.verts[1]
                try:
                    f_cap = bm.faces.new((v1, v2, v_center))
                    if uv_layer:
                        for loop in f_cap.loops:
                            loop[uv_layer].uv = cap_uv.copy()
                    caps_added += 1
                except ValueError:
                    pass

        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)

        # Duplica faces com normal invertida (Double-Sided nativo)
        orig_faces = list(bm.faces)
        vert_map = {}
        for f in orig_faces:
            for v in f.verts:
                if v not in vert_map:
                    vert_map[v] = bm.verts.new(v.co - v.normal * 0.00005)
        for f in orig_faces:
            rev_verts = [vert_map[v] for v in reversed(f.verts)]
            try:
                f_back = bm.faces.new(rev_verts)
                if uv_layer:
                    for l_src, l_dst in zip(reversed(f.loops), f_back.loops):
                        l_dst[uv_layer].uv = l_src[uv_layer].uv.copy()
            except ValueError:
                pass

        bm.to_mesh(obj.data)
        bm.free()
        print(f"Parte '{obj.name}': +{caps_added} tampas adicionadas, total final = {len(obj.data.polygons)} tris")


def pose_arms_and_scale(shoulder_height: float = 4.303):
    """Se os braços estiverem em T-Pose (largura > altura), rotaciona ±90° para a pose de descanso e escala para shoulder_height studs."""
    torso_obj = bpy.data.objects['Torso']
    tx, ty, tz = get_bounds(torso_obj)
    # Limita a referência lateral do tronco ao corpo principal (ignora bolsas laterais como a do Usopp na parte baixa)
    torso_upper_xs = [v.co.x for v in torso_obj.data.vertices if v.co.z > (tz[0] + tz[1]) * 0.52]
    tx_pos = max(torso_upper_xs) if torso_upper_xs else tx[1]
    tx_neg = min(torso_upper_xs) if torso_upper_xs else tx[0]

    left_arm = bpy.data.objects['LeftArm']
    lx, ly, lz = get_bounds(left_arm)
    if (lx[1] - lx[0]) > (lz[1] - lz[0]):
        print("Rotacionando LeftArm da T-Pose (+90° Y) para vertical...")
        left_arm.data.transform(Matrix.Rotation(math.radians(90.0), 4, 'Y'))
        lx, ly, lz = get_bounds(left_arm)
        left_arm.data.transform(Matrix.Translation(Vector((tx_pos - lx[0], 0, (tz[1] - 0.0005) - lz[1]))))

    right_arm = bpy.data.objects['RightArm']
    rx, ry, rz = get_bounds(right_arm)
    if (rx[1] - rx[0]) > (rz[1] - rz[0]):
        print("Rotacionando RightArm da T-Pose (-90° Y) para vertical...")
        right_arm.data.transform(Matrix.Rotation(math.radians(-90.0), 4, 'Y'))
        rx, ry, rz = get_bounds(right_arm)
        right_arm.data.transform(Matrix.Translation(Vector((tx_neg - rx[1], 0, (tz[1] - 0.0005) - rz[1]))))

    # Garante sola dos pés em Z=0 e escala altura do ombro para shoulder_height studs
    _, _, llz = get_bounds(bpy.data.objects['LeftLeg'])
    _, _, rlz = get_bounds(bpy.data.objects['RightLeg'])
    min_foot_z = min(llz[0], rlz[0])
    if abs(min_foot_z) > 1e-6:
        for o in bpy.data.objects:
            if o.type == 'MESH':
                o.data.transform(Matrix.Translation(Vector((0, 0, -min_foot_z))))

    _, _, tz = get_bounds(torso_obj)
    scale_factor = shoulder_height / (tz[1] * 100.0)
    print(f"Escala final para {shoulder_height:.3f} studs no ombro: scale_factor={scale_factor:.5f}")
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.data.transform(Matrix.Scale(scale_factor, 4))


def render_previews(ref_dir: str, char_name: str):
    os.makedirs(ref_dir, exist_ok=True)
    for m in bpy.data.materials:
        m.use_backface_culling = True

    sun_data = bpy.data.lights.new("Sun", type='SUN')
    sun_data.energy = 3.5
    sun_obj = bpy.data.objects.new("Sun", sun_data)
    bpy.context.scene.collection.objects.link(sun_obj)

    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 0.080
    cam_data.clip_start = 0.001
    cam_data.clip_end = 10.0
    cam_obj = bpy.data.objects.new("Cam", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj

    bpy.context.scene.render.engine = 'BLENDER_EEVEE'
    bpy.context.scene.render.resolution_x = 512
    bpy.context.scene.render.resolution_y = 512

    for vname, loc, rot in [
        ("preview_front", (0.0, -0.45, 0.032), (math.radians(90), 0, 0)),
        ("preview_back", (0.0, 0.45, 0.032), (math.radians(90), 0, math.radians(180))),
        ("preview_34", (0.28, -0.45, 0.032), (math.radians(90), 0, math.radians(32))),
    ]:
        cam_obj.location = loc
        cam_obj.rotation_euler = rot
        sun_obj.rotation_euler = rot
        out_png = os.path.join(ref_dir, f"{char_name}_{vname}.png")
        bpy.context.scene.render.filepath = out_png
        bpy.ops.render.render(write_still=True)
        print(f"Preview salvo em: {out_png}")

    # Also render a slightly exploded front & back view so neck/hair/shoulder cuts are 100% inspectable
    offsets = {
        'Head': Vector((0, 0, 0.007)),
        'LeftArm': Vector((0.006, 0, 0)),
        'RightArm': Vector((-0.006, 0, 0)),
        'LeftLeg': Vector((0.002, 0, -0.005)),
        'RightLeg': Vector((-0.002, 0, -0.005)),
    }
    for name, off in offsets.items():
        if name in bpy.data.objects:
            bpy.data.objects[name].location = off
    for vname, loc, rot in [
        ("preview_exploded_front", (0.0, -0.45, 0.032), (math.radians(90), 0, 0)),
        ("preview_exploded_back", (0.0, 0.45, 0.032), (math.radians(90), 0, math.radians(180))),
    ]:
        cam_obj.location = loc
        cam_obj.rotation_euler = rot
        sun_obj.rotation_euler = rot
        out_png = os.path.join(ref_dir, f"{char_name}_{vname}.png")
        bpy.context.scene.render.filepath = out_png
        bpy.ops.render.render(write_still=True)


def main():
    args = parse_args()
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    char_dir = os.path.join(repo_root, "Blender", args.char)
    model_dir = os.path.join(char_dir, "modelo")
    tex_dir = os.path.join(char_dir, "texturas")
    ref_dir = os.path.join(char_dir, "referencias")
    os.makedirs(model_dir, exist_ok=True)

    print(f"=== AUTO-RIG TRIPO -> ROBLOX ({args.char}) ===")
    import_model(args.input, model_dir)
    extract_and_make_shiny_texture(tex_dir, args.char)

    required_6 = {"Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}
    existing_names = {o.name for o in bpy.data.objects if o.type == 'MESH'}

    if required_6.issubset(existing_names) and not args.force_resplit:
        print("Modo detectado: 6 partes já separadas.")
        fix_existing_6_parts()
    else:
        print("Modo detectado: Malha única do Tripo -> Executando Auto-Corte por planos matemáticos...")
        meshes = [o for o in bpy.data.objects if o.type == 'MESH']
        bpy.ops.object.select_all(action='DESELECT')
        for m in meshes:
            m.select_set(True)
        bpy.context.view_layer.objects.active = meshes[0]
        if len(meshes) > 1:
            bpy.ops.object.join()
        auto_split_single_mesh(bpy.context.view_layer.objects.active, args.max_tris)

    pose_arms_and_scale(args.shoulder_height)
    cap_and_solidify_all()

    blend_out = os.path.join(model_dir, f"{args.char}_R6_Auto.blend")
    fbx_out = os.path.join(model_dir, f"{args.char}_R6_Auto.fbx")
    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    bpy.ops.export_scene.fbx(
        filepath=fbx_out,
        use_selection=False,
        object_types={'MESH'},
        mesh_smooth_type='OFF',
        add_leaf_bones=False,
        path_mode='COPY',
        embed_textures=True,
    )
    print(f"Exportado com sucesso: {fbx_out}")
    render_previews(ref_dir, args.char)


if __name__ == "__main__":
    main()
