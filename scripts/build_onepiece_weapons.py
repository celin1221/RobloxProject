#!/usr/bin/env python3
r"""
build_onepiece_weapons.py — Gera os 3 assets 3D estilizados de One Piece no Blender 5.3.0:
  1. Estilingue do Usopp (Blender/Usopp/assets/Usopp_Slingshot.*)
  2. Bastao Clima-Tact da Nami (Blender/Nami/assets/Nami_ClimaTact.*)
  3. 3 Katanas do Zoro em bainha para empunhar de lado (Blender/Zoro/assets/Zoro_Katanas.*)

Cada asset recebe UV atlas 512x512 pintado proceduralmente (com preenchimento anti-bleed),
escala exata em Roblox studs (0.01 metros no Blender = 1 stud no Roblox FBX),
FBX com embed_textures=True, .blend fonte e renders de conferencia.
"""

import os
import math
import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix, Euler

STUD = 0.01  # 1 stud no Roblox = 0.01 unidades no Blender (mesma escala de auto_rig_tripo.py)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def make_grid_atlas(filepath: str, palette_specs: list[tuple[str, tuple, tuple]], size: int = 512):
    """
    Cria atlas 4x4 (16 celulas de 128x128 px) com gradiente vertical sutil em cada celula
    e retorna dict name -> (u_min, v_min, u_max, v_max) ja com margem interna anti-bleed.
    """
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    arr = np.zeros((size, size, 4), dtype=np.float32)
    arr[:, :, 3] = 1.0
    cell = size // 4
    pad = 10
    uv_boxes = {}

    for idx, (name, top_rgb, bot_rgb) in enumerate(palette_specs):
        col = idx % 4
        row = idx // 4  # row 0 = fundo em imagem Bottom-Up (Blender image pixels: row 0 = bottom!)
        x0, x1 = col * cell, (col + 1) * cell
        y0, y1 = row * cell, (row + 1) * cell
        for py in range(y0, y1):
            t = (py - y0) / max(1, cell - 1)
            r = (bot_rgb[0] * (1.0 - t) + top_rgb[0] * t) / 255.0
            g = (bot_rgb[1] * (1.0 - t) + top_rgb[1] * t) / 255.0
            b = (bot_rgb[2] * (1.0 - t) + top_rgb[2] * t) / 255.0
            arr[py, x0:x1, 0] = r
            arr[py, x0:x1, 1] = g
            arr[py, x0:x1, 2] = b

        uv_boxes[name] = (
            (x0 + pad) / size,
            (y0 + pad) / size,
            (x1 - pad) / size,
            (y1 - pad) / size,
        )

    img = bpy.data.images.new(os.path.basename(filepath), width=size, height=size, alpha=False)
    img.pixels.foreach_set(arr.ravel())
    img.filepath_raw = filepath
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img, uv_boxes


def make_solid_mat(name: str, rgb: tuple[int, int, int], metallic: float = 0.0, roughness: float = 0.42):
    """Cria material PBR solido por parte para garantir cores perfeitas no Blender e MeshParts coloridas nativas no Roblox."""
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.35
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def append_bmesh_part(target_bm: bmesh.types.BMesh, part_bm: bmesh.types.BMesh, xform: Matrix = None):
    """Transfere geometria triangulada de part_bm para target_bm mantendo UV valida."""
    bmesh.ops.triangulate(part_bm, faces=part_bm.faces[:])
    if xform is not None:
        bmesh.ops.transform(part_bm, matrix=xform, verts=part_bm.verts)
    uv_dst = target_bm.loops.layers.uv.verify()
    vmap = {v: target_bm.verts.new(v.co) for v in part_bm.verts}
    for f in part_bm.faces:
        new_f = target_bm.faces.new([vmap[v] for v in f.verts])
        for loop in new_f.loops:
            loop[uv_dst].uv = (0.5, 0.5)
    part_bm.free()


def assign_uv_box(bm: bmesh.types.BMesh, uv_layer, box: tuple[float, float, float, float], axis: str = 'Z'):
    """Projeta UVs de todas as faces atuais do bm dentro da celula [u0,v0,u1,v1] usando eixo escolhido para gradiente."""
    u0, v0, u1, v1 = box
    verts = list(bm.verts)
    if not verts:
        return
    idx_axis = {'X': 0, 'Y': 1, 'Z': 2}[axis]
    vals = [v.co[idx_axis] for v in verts]
    mn, mx = min(vals), max(vals)
    span = mx - mn if mx - mn > 1e-6 else 1.0
    for f in bm.faces:
        for loop in f.loops:
            t = (loop.vert.co[idx_axis] - mn) / span
            # sutil variacao horizontal tambem para dar volume em curvas
            tu = 0.5 + 0.35 * max(-1.0, min(1.0, loop.vert.co.x))
            u = u0 + (u1 - u0) * max(0.05, min(0.95, tu))
            v = v0 + (v1 - v0) * max(0.0, min(1.0, t))
            loop[uv_layer].uv = (u, v)


def add_bm_part(target_bm: bmesh.types.BMesh, part_bm: bmesh.types.BMesh, uv_box: tuple, axis: str = 'Z', xform: Matrix = None):
    """Copia part_bm (com UV atribuida dentro de uv_box) para dentro de target_bm."""
    bmesh.ops.triangulate(part_bm, faces=part_bm.faces[:])
    uv_src = part_bm.loops.layers.uv.verify()
    assign_uv_box(part_bm, uv_src, uv_box, axis=axis)
    if xform is not None:
        bmesh.ops.transform(part_bm, matrix=xform, verts=part_bm.verts)

    uv_dst = target_bm.loops.layers.uv.verify()
    vmap = {}
    for v in part_bm.verts:
        vmap[v] = target_bm.verts.new(v.co)
    for f in part_bm.faces:
        new_f = target_bm.faces.new([vmap[v] for v in f.verts])
        for l_src, l_dst in zip(f.loops, new_f.loops):
            l_dst[uv_dst].uv = l_src[uv_src].uv
    part_bm.free()


def tube_along_points(pts: list[Vector], radii: list[float], segs: int = 16, cap_start: bool = True, cap_end: bool = True) -> bmesh.types.BMesh:
    """Cria tubo suave fechado ao longo de uma polilinha 3D."""
    bm = bmesh.new()
    rings = []
    n = len(pts)
    prev_normal = None
    for i in range(n):
        if i == 0:
            tangent = (pts[1] - pts[0]).normalized()
        elif i == n - 1:
            tangent = (pts[-1] - pts[-2]).normalized()
        else:
            tangent = (pts[i + 1] - pts[i - 1]).normalized()

        if prev_normal is None:
            ref = Vector((0, 1, 0)) if abs(tangent.dot(Vector((0, 1, 0)))) < 0.9 else Vector((1, 0, 0))
            norm = tangent.cross(ref).normalized()
        else:
            norm = (prev_normal - tangent * prev_normal.dot(tangent))
            if norm.length < 1e-6:
                ref = Vector((0, 1, 0)) if abs(tangent.dot(Vector((0, 1, 0)))) < 0.9 else Vector((1, 0, 0))
                norm = tangent.cross(ref)
            norm.normalize()
        binorm = tangent.cross(norm).normalized()
        prev_normal = norm

        r = radii[i]
        ring = []
        for s in range(segs):
            ang = 2.0 * math.pi * s / segs
            offset = (norm * math.cos(ang) + binorm * math.sin(ang)) * r
            ring.append(bm.verts.new(pts[i] + offset))
        rings.append(ring)

    for i in range(n - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(segs):
            sn = (s + 1) % segs
            bm.faces.new([r0[s], r0[sn], r1[sn], r1[s]])

    if cap_start:
        bm.faces.new(list(reversed(rings[0])))
    if cap_end:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def finalize_mesh_obj(name: str, bm: bmesh.types.BMesh, mat, smooth: bool = True):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()

    # Escala padrao do projeto: 0.01 no Blender = 1 stud no Roblox
    mesh.transform(Matrix.Scale(STUD, 4))
    if smooth:
        for p in mesh.polygons:
            p.use_smooth = True

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def render_asset_views(ref_dir: str, prefix: str, target_center_studs: Vector, view_dist_studs: float):
    os.makedirs(ref_dir, exist_ok=True)
    sun_data = bpy.data.lights.new("PreviewSun", type='SUN')
    sun_data.energy = 3.2
    sun = bpy.data.objects.new("PreviewSun", sun_data)
    bpy.context.scene.collection.objects.link(sun)

    fill_data = bpy.data.lights.new("PreviewFill", type='SUN')
    fill_data.energy = 1.6
    fill = bpy.data.objects.new("PreviewFill", fill_data)
    fill.rotation_euler = Euler((math.radians(45), 0, math.radians(-140)))
    bpy.context.scene.collection.objects.link(fill)

    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.09, 0.08, 0.14, 1.0)
        bg.inputs[1].default_value = 1.0
    bpy.context.scene.world = world

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = view_dist_studs * STUD
    cam_data.clip_start = 0.0005
    cam_data.clip_end = 20.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    bpy.context.scene.render.engine = 'BLENDER_EEVEE'
    bpy.context.scene.render.resolution_x = 640
    bpy.context.scene.render.resolution_y = 640

    center = target_center_studs * STUD
    dist = view_dist_studs * 2.2 * STUD
    views = [
        ("front", Vector((0, -dist, 0))),
        ("34", Vector((dist * 0.65, -dist * 0.72, dist * 0.35))),
    ]
    for vname, offset in views:
        loc = center + offset
        cam.location = loc
        direction = (center - loc).normalized()
        cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
        sun.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
        out_png = os.path.join(ref_dir, f"{prefix}_preview_{vname}.png")
        bpy.context.scene.render.filepath = out_png
        bpy.ops.render.render(write_still=True)

    bpy.data.objects.remove(cam, do_unlink=True)
    bpy.data.objects.remove(sun, do_unlink=True)
    bpy.data.objects.remove(fill, do_unlink=True)


def save_and_export(repo_dir: str, rel_folder: str, asset_name: str, objs: list):
    base_dir = os.path.join(repo_dir, "Blender", rel_folder, "assets")
    os.makedirs(base_dir, exist_ok=True)
    blend_path = os.path.join(base_dir, f"{asset_name}.blend")
    fbx_path = os.path.join(base_dir, f"{asset_name}.fbx")

    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        object_types={'MESH'},
        mesh_smooth_type='FACE',
        add_leaf_bones=False,
        path_mode='COPY',
        embed_textures=True,
    )
    print(f"[EXPORT] {fbx_path} ({sum(len(o.data.polygons) for o in objs)} tris)")


# ==============================================================================
# 1. ESTILINGUE DO USOPP (Verde, fita branca no cabo, ponteiras douradas, elastico marrom)
# ==============================================================================
def catmull_rom_resample(pts_radii: list[tuple[Vector, float]], subdivisions: int = 4) -> tuple[list[Vector], list[float]]:
    """Suaviza lista de (ponto, raio) via spline Catmull-Rom Centripetal/Uniform para curvas sem quinas."""
    n = len(pts_radii)
    if n < 2 or subdivisions <= 1:
        return [p for p, _ in pts_radii], [r for _, r in pts_radii]
    out_pts: list[Vector] = []
    out_r: list[float] = []
    for i in range(n - 1):
        p0, r0 = pts_radii[max(0, i - 1)]
        p1, r1 = pts_radii[i]
        p2, r2 = pts_radii[i + 1]
        p3, r3 = pts_radii[min(n - 1, i + 2)]
        steps = subdivisions if i < n - 2 else subdivisions + 1
        for s in range(steps):
            t = s / subdivisions
            t2 = t * t
            t3 = t2 * t
            pos = 0.5 * (
                (2.0 * p1)
                + (-p0 + p2) * t
                + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
                + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
            )
            rad = r1 * (1.0 - t) + r2 * t
            out_pts.append(pos)
            out_r.append(rad)
    return out_pts, out_r


def finalize_group_objs(part_bms: dict[str, tuple[bmesh.types.BMesh, tuple[int, int, int], float, float]]) -> list:
    objs = []
    for pname, (pbm, rgb, metal, rough) in part_bms.items():
        if len(pbm.faces) == 0:
            pbm.free()
            continue
        mat = make_solid_mat(f"{pname}_Mat", rgb, metallic=metal, roughness=rough)
        objs.append(finalize_mesh_obj(pname, pbm, mat, smooth=True))
    return objs


def build_usopp_slingshot(repo_root: str):
    clear_scene()
    groups = {
        "Usopp_GreenFrame":  (bmesh.new(), (112, 224, 56),  0.0, 0.38),
        "Usopp_WhiteWrap":   (bmesh.new(), (246, 250, 252), 0.0, 0.55),
        "Usopp_WrapSeam":    (bmesh.new(), (168, 182, 194), 0.0, 0.50),
        "Usopp_GoldPins":    (bmesh.new(), (252, 202, 54),  0.8, 0.25),
        "Usopp_BrownElastic":(bmesh.new(), (120, 72, 42),   0.0, 0.55),
    }

    # Cabo continuo da ponta esferica do pomo (-0.50) ate entrar limpo dentro do arco em U (+0.60)
    handle_pts = [
        Vector((0, 0, -0.50)),
        Vector((0, 0, -0.47)),
        Vector((0, 0, -0.42)),
        Vector((0, 0, -0.36)),
        Vector((0, 0, -0.29)),
        Vector((0, 0, -0.26)),
        Vector((0, 0, 0.24)),
        Vector((0, 0, 0.29)),
        Vector((0, 0, 0.42)),
        Vector((0, 0, 0.56)),
        Vector((0, 0, 0.62)),
    ]
    handle_r = [0.055, 0.112, 0.142, 0.146, 0.140, 0.112, 0.112, 0.144, 0.150, 0.145, 0.120]
    append_bmesh_part(groups["Usopp_GreenFrame"][0], tube_along_points(handle_pts, handle_r, segs=24))

    # Cilindro interno cinza-claro da base da fita
    append_bmesh_part(groups["Usopp_WrapSeam"][0], tube_along_points([Vector((0, 0, -0.26)), Vector((0, 0, 0.24))], [0.128, 0.128], segs=22))

    # Enrolamento da fita branca em camadas suaves
    for idx, zc in enumerate([-0.22, -0.125, -0.03, 0.065, 0.16, 0.22]):
        rot = Matrix.Rotation(math.radians(3.5 * (1 if idx % 2 == 0 else -1)), 4, 'Y')
        xf = Matrix.Translation(Vector((0, 0, zc))) @ rot
        pts = [Vector((0, 0, -0.042)), Vector((0, 0, -0.018)), Vector((0, 0, 0.0)), Vector((0, 0, 0.018)), Vector((0, 0, 0.042))]
        append_bmesh_part(groups["Usopp_WhiteWrap"][0], tube_along_points(pts, [0.134, 0.152, 0.156, 0.152, 0.134], segs=22), xform=xf)

    # Arco completo em U continuo
    arch_ctrl = [
        (Vector((-0.38, -0.10, 1.81)), 0.172),
        (Vector((-0.57, -0.10, 1.71)), 0.178),
        (Vector((-0.70, -0.09, 1.46)), 0.174),
        (Vector((-0.70, -0.07, 1.14)), 0.168),
        (Vector((-0.54, -0.05, 0.83)), 0.164),
        (Vector((-0.28, -0.02, 0.65)), 0.164),
        (Vector(( 0.00,  0.00, 0.60)), 0.170),
        (Vector(( 0.28, -0.02, 0.65)), 0.164),
        (Vector(( 0.54, -0.05, 0.83)), 0.164),
        (Vector(( 0.70, -0.07, 1.14)), 0.168),
        (Vector(( 0.70, -0.09, 1.46)), 0.174),
        (Vector(( 0.57, -0.10, 1.71)), 0.178),
        (Vector(( 0.38, -0.10, 1.81)), 0.172),
    ]
    arch_pts, arch_rads = catmull_rom_resample(arch_ctrl, subdivisions=4)
    append_bmesh_part(groups["Usopp_GreenFrame"][0], tube_along_points(arch_pts, arch_rads, segs=24))

    for side in (-1.0, 1.0):
        tip_pos = Vector((side * 0.34, -0.10, 1.83))
        bm_bulb = bmesh.new()
        bmesh.ops.create_uvsphere(bm_bulb, u_segments=22, v_segments=14, radius=0.226)
        append_bmesh_part(groups["Usopp_GreenFrame"][0], bm_bulb, xform=Matrix.Translation(tip_pos))

        pin_pos = tip_pos + Vector((side * 0.21, 0.0, 0.07))
        bm_pin = bmesh.new()
        bmesh.ops.create_uvsphere(bm_pin, u_segments=14, v_segments=10, radius=0.064)
        append_bmesh_part(groups["Usopp_GoldPins"][0], bm_pin, xform=Matrix.Translation(pin_pos))

    left_anchor = Vector((-0.34, -0.08, 1.83))
    right_anchor = Vector((0.34, -0.08, 1.83))
    pouch_center = Vector((0.0, 0.32, 1.46))

    for anc in (left_anchor, right_anchor):
        mid1 = anc.lerp(pouch_center, 0.45) + Vector((0, 0.04, 0.02))
        e_pts, e_r = catmull_rom_resample([(anc, 0.036), (mid1, 0.033), (pouch_center, 0.036)], subdivisions=4)
        append_bmesh_part(groups["Usopp_BrownElastic"][0], tube_along_points(e_pts, e_r, segs=12))

    bm_pouch = bmesh.new()
    bmesh.ops.create_uvsphere(bm_pouch, u_segments=14, v_segments=10, radius=0.12)
    pouch_mat = Matrix.Translation(pouch_center) @ Matrix.Diagonal((1.4, 0.65, 1.1, 1.0))
    append_bmesh_part(groups["Usopp_BrownElastic"][0], bm_pouch, xform=pouch_mat)

    objs = finalize_group_objs(groups)
    render_asset_views(os.path.join(repo_root, "Blender", "Usopp", "assets"), "Usopp_Slingshot_v2", Vector((0, 0.0, 0.72)), 2.8)
    save_and_export(repo_root, "Usopp", "Usopp_Slingshot_v2", objs)


# ==============================================================================
# 2. BASTAO CLIMA-TACT DA NAMI (Azul segmentado em 3 estagios com pinos claros)
# ==============================================================================
def build_nami_climatact(repo_root: str):
    clear_scene()
    groups = {
        "Nami_SkyBlueBarrels": (bmesh.new(), (58, 166, 248),  0.45, 0.30),
        "Nami_DarkCobalt":     (bmesh.new(), (18, 66, 148),   0.55, 0.32),
        "Nami_CreamRings":     (bmesh.new(), (246, 222, 162), 0.15, 0.40),
        "Nami_DarkDots":       (bmesh.new(), (32, 24, 28),    0.0,  0.45),
    }

    bm_cap = bmesh.new()
    bmesh.ops.create_uvsphere(bm_cap, u_segments=20, v_segments=10, radius=0.090)
    append_bmesh_part(groups["Nami_DarkCobalt"][0], bm_cap, xform=Matrix.Translation(Vector((0, 0, -1.55))))

    append_bmesh_part(groups["Nami_SkyBlueBarrels"][0], tube_along_points([Vector((0, 0, -1.55)), Vector((0, 0, -0.15))], [0.088, 0.098], segs=24))
    append_bmesh_part(groups["Nami_DarkCobalt"][0],     tube_along_points([Vector((0, 0, -0.17)), Vector((0, 0, -0.11))], [0.114, 0.114], segs=24))
    append_bmesh_part(groups["Nami_SkyBlueBarrels"][0], tube_along_points([Vector((0, 0, -0.14)), Vector((0, 0, 1.30))],  [0.106, 0.122], segs=24))
    append_bmesh_part(groups["Nami_DarkCobalt"][0],     tube_along_points([Vector((0, 0, 1.28)),  Vector((0, 0, 1.35))],  [0.138, 0.138], segs=24))

    top_profile = [
        (Vector((0, 0, 1.32)), 0.128),
        (Vector((0, 0, 2.58)), 0.155),
        (Vector((0, 0, 2.78)), 0.176),
        (Vector((0, 0, 2.86)), 0.184),
    ]
    append_bmesh_part(groups["Nami_SkyBlueBarrels"][0], tube_along_points([p for p, _ in top_profile], [r for _, r in top_profile], segs=28, cap_end=False))

    rim_bm = bmesh.new()
    segs = 28
    ring_outer = [rim_bm.verts.new(Vector((0.184 * math.cos(2 * math.pi * i / segs), 0.184 * math.sin(2 * math.pi * i / segs), 2.86))) for i in range(segs)]
    ring_inner = [rim_bm.verts.new(Vector((0.132 * math.cos(2 * math.pi * i / segs), 0.132 * math.sin(2 * math.pi * i / segs), 2.86))) for i in range(segs)]
    ring_deep  = [rim_bm.verts.new(Vector((0.118 * math.cos(2 * math.pi * i / segs), 0.118 * math.sin(2 * math.pi * i / segs), 2.35))) for i in range(segs)]
    for i in range(segs):
        inext = (i + 1) % segs
        rim_bm.faces.new([ring_outer[i], ring_outer[inext], ring_inner[inext], ring_inner[i]])
        rim_bm.faces.new([ring_inner[i], ring_inner[inext], ring_deep[inext], ring_deep[i]])
    rim_bm.faces.new(ring_deep)
    bmesh.ops.recalc_face_normals(rim_bm, faces=rim_bm.faces[:])
    append_bmesh_part(groups["Nami_DarkCobalt"][0], rim_bm)

    nub_specs = [
        (2.68, 0.168,  1, 0, 0.064),
        (2.68, 0.168, -1, 0, 0.064),
        (2.68, 0.168,  0, 1, 0.054),
        (1.42, 0.128,  1, 0, 0.048),
        (1.42, 0.128, -1, 0, 0.048),
        (0.56, 0.114,  0,-1, 0.046),
        (0.56, 0.114,  0, 1, 0.046),
        (-0.26,0.096,  1, 0, 0.044),
        (-0.26,0.096, -1, 0, 0.044),
    ]
    for zn, r_surf, dx, dy, n_r in nub_specs:
        dir_xy = Vector((dx, dy, 0)).normalized()
        rot_axis = Vector((0, 0, 1)).cross(dir_xy)
        rot_q = Matrix.Rotation(math.pi / 2, 4, rot_axis) if rot_axis.length > 1e-4 else Matrix.Rotation(math.pi / 2, 4, 'Y')
        pos = dir_xy * (r_surf + n_r * 0.18) + Vector((0, 0, zn))
        xf = Matrix.Translation(pos) @ rot_q
        append_bmesh_part(groups["Nami_CreamRings"][0], tube_along_points([Vector((0, 0, -n_r*0.45)), Vector((0, 0, n_r*0.35))], [n_r, n_r * 0.92], segs=14), xform=xf)
        pos2 = dir_xy * (r_surf + n_r * 0.42) + Vector((0, 0, zn))
        xf2 = Matrix.Translation(pos2) @ rot_q
        append_bmesh_part(groups["Nami_DarkDots"][0], tube_along_points([Vector((0, 0, 0)), Vector((0, 0, n_r*0.24))], [n_r * 0.52, n_r * 0.46], segs=12), xform=xf2)

    objs = finalize_group_objs(groups)
    render_asset_views(os.path.join(repo_root, "Blender", "Nami", "assets"), "Nami_ClimaTact_v2", Vector((0, 0, 0.65)), 4.9)
    save_and_export(repo_root, "Nami", "Nami_ClimaTact_v2", objs)


# ==============================================================================
# 3. AS 3 KATANAS DO ZORO NA BAINHA (Mais verticais na cintura direita!)
# ==============================================================================
def build_single_katana(groups: dict,
                        saya_key: str, ito_key: str, same_key: str,
                        guard_style: str, mid_bands: bool,
                        transform: Matrix):
    def sori_y(z: float) -> float:
        return -0.013 * (z + 0.35) * (z + 0.35)

    def add_k(key: str, pbm: bmesh.types.BMesh, local_xf: Matrix = None):
        combined = transform if local_xf is None else (transform @ local_xf)
        append_bmesh_part(groups[key][0], pbm, xform=combined)

    # 1. Bainha (Saya) de z = -2.42 ate z = -0.03
    saya_z = [-2.42, -2.18, -1.70, -1.05, -0.42, -0.03]
    saya_r = [0.068, 0.072, 0.076, 0.080, 0.084, 0.086]
    pts_saya = [Vector((0, sori_y(z), z)) for z in saya_z]
    bm_saya = tube_along_points(pts_saya, saya_r, segs=14)
    for v in bm_saya.verts:
        v.co.x *= 0.66
    add_k(saya_key, bm_saya)

    # Ponteira dourada (Kojiri): z = -2.52 .. -2.32
    pts_kojiri = [Vector((0, sori_y(z), z)) for z in (-2.52, -2.44, -2.32)]
    bm_koj = tube_along_points(pts_kojiri, [0.035, 0.074, 0.080], segs=14)
    for v in bm_koj.verts:
        v.co.x *= 0.72
    add_k("Zoro_GoldHardware", bm_koj)

    # Boca dourada (Koiguchi): z = -0.08 .. 0.00
    pts_koi = [Vector((0, sori_y(-0.08), -0.08)), Vector((0, sori_y(0.0), 0.0))]
    bm_koi = tube_along_points(pts_koi, [0.092, 0.094], segs=14)
    for v in bm_koi.verts:
        v.co.x *= 0.72
    add_k("Zoro_GoldHardware", bm_koi)

    if mid_bands:
        for bz in (-0.90, -1.72):
            bm_band = tube_along_points([Vector((0, sori_y(bz - 0.05), bz - 0.05)), Vector((0, sori_y(bz + 0.05), bz + 0.05))], [0.088, 0.088], segs=14)
            for v in bm_band.verts:
                v.co.x *= 0.72
            add_k("Zoro_GoldHardware", bm_band)
    else:
        bm_kuri = bmesh.new()
        bmesh.ops.create_uvsphere(bm_kuri, u_segments=10, v_segments=6, radius=0.055)
        add_k("Zoro_GoldHardware", bm_kuri, Matrix.Translation(Vector((0.065, sori_y(-0.55), -0.55))))

    # 2. Guarda (Tsuba) dourada
    g_y = sori_y(0.02)
    if guard_style == "round":
        add_k("Zoro_GoldHardware", tube_along_points([Vector((0, g_y, 0.0)), Vector((0, g_y, 0.052))], [0.172, 0.172], segs=22))
    elif guard_style == "cross":
        for ang in (0.0, math.pi / 2):
            bm_bar = bmesh.new()
            bmesh.ops.create_cube(bm_bar, size=1.0)
            xf = Matrix.Translation(Vector((0, g_y, 0.026))) @ Matrix.Rotation(ang, 4, 'Z') @ Matrix.Diagonal((0.36, 0.12, 0.052, 1.0))
            add_k("Zoro_GoldHardware", bm_bar, xf)
        add_k("Zoro_GoldHardware", tube_along_points([Vector((0, g_y, 0.0)), Vector((0, g_y, 0.056))], [0.118, 0.118], segs=16))
    else:
        for ang in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
            px = math.cos(ang) * 0.088
            py = g_y + math.sin(ang) * 0.088
            add_k("Zoro_GoldHardware", tube_along_points([Vector((px, py, 0.0)), Vector((px, py, 0.052))], [0.095, 0.095], segs=14))

    # Colar Fuchi logo acima da tsuba
    add_k("Zoro_GoldHardware", tube_along_points([Vector((0, sori_y(0.05), 0.05)), Vector((0, sori_y(0.14), 0.14))], [0.086, 0.080], segs=14))

    # 3. Cabo (Tsuka) z = +0.14 .. +1.06
    tsuka_z = [0.14, 0.45, 0.76, 1.06]
    bm_core = tube_along_points([Vector((0, sori_y(z), z)) for z in tsuka_z], [0.066, 0.064, 0.064, 0.068], segs=14)
    for v in bm_core.verts:
        v.co.x *= 0.76
    add_k(same_key, bm_core)

    for kz in (0.21, 0.32, 0.43, 0.54, 0.65, 0.76, 0.87, 0.98):
        bm_wrap = tube_along_points([Vector((0, sori_y(kz - 0.028), kz - 0.028)), Vector((0, sori_y(kz + 0.028), kz + 0.028))], [0.080, 0.080], segs=12)
        for v in bm_wrap.verts:
            v.co.x *= 0.78
        add_k(ito_key, bm_wrap)

    # Pomo dourado (Kashira): z = +1.06 .. +1.16
    bm_kash = tube_along_points([Vector((0, sori_y(1.06), 1.06)), Vector((0, sori_y(1.16), 1.16))], [0.082, 0.066], segs=14)
    for v in bm_kash.verts:
        v.co.x *= 0.78
    add_k("Zoro_GoldHardware", bm_kash)


def make_katana_xf(pos: Vector, z_dir: Vector, sori_hint: Vector = Vector((0.0, 0.4, 1.0))) -> Matrix:
    """Matriz ortonormal dextrógira alinhando local +Z em z_dir e local +Y com sori_hint."""
    z_ax = z_dir.normalized()
    x_ax = sori_hint.cross(z_ax).normalized()
    y_ax = z_ax.cross(x_ax).normalized()
    return Matrix((
        (x_ax.x, y_ax.x, z_ax.x, pos.x),
        (x_ax.y, y_ax.y, z_ax.y, pos.y),
        (x_ax.z, y_ax.z, z_ax.z, pos.z),
        (0.0,    0.0,    0.0,    1.0),
    ))


def build_zoro_katanas(repo_root: str):
    clear_scene()
    groups = {
        "Zoro_WadoWhite":    (bmesh.new(), (245, 248, 252), 0.0, 0.35),
        "Zoro_YubashiriBlk": (bmesh.new(), (22, 24, 30),    0.1, 0.38),
        "Zoro_SandaiRed":    (bmesh.new(), (138, 22, 28),   0.1, 0.35),
        "Zoro_SandaiIto":    (bmesh.new(), (64, 24, 30),    0.0, 0.55),
        "Zoro_DarkSamegawa": (bmesh.new(), (44, 48, 58),    0.0, 0.60),
        "Zoro_TanSamegawa":  (bmesh.new(), (208, 158, 86),  0.0, 0.55),
        "Zoro_GoldHardware": (bmesh.new(), (246, 198, 56),  0.85, 0.24),
    }

    # Orientacao MAIS VERTICAL (~63 graus acima da horizontal!) seguindo a silhueta natural do Zoro:
    # cabos sobem inclinados para frente-fora (-X, -Y, +Z), bainhas descem para tras-dentro junto as pernas
    d_base = Vector((-0.26, -0.36, 0.896)).normalized()
    sep_vec = Vector((-0.26, -0.14, -0.13))
    sep_dir = sep_vec.normalized()

    specs = [
        ("Zoro_WadoWhite",    "Zoro_WadoWhite",    "Zoro_DarkSamegawa", "round", False, -1),
        ("Zoro_YubashiriBlk", "Zoro_YubashiriBlk", "Zoro_DarkSamegawa", "cross", False,  0),
        ("Zoro_SandaiRed",    "Zoro_SandaiIto",    "Zoro_TanSamegawa",  "petal", True,  +1),
    ]

    for saya_k, ito_k, same_k, gstyle, bands, i in specs:
        pos = Vector((0.0, -0.16, 0.0)) + sep_vec * i - d_base * (i * 0.17)
        d_i = (d_base - sep_dir * (i * 0.022)).normalized()
        xf = make_katana_xf(pos, d_i)
        build_single_katana(groups, saya_k, ito_k, same_k, gstyle, bands, xf)

    objs = finalize_group_objs(groups)
    render_asset_views(os.path.join(repo_root, "Blender", "Zoro", "assets"), "Zoro_Katanas_v2", Vector((0.0, 0.12, -0.42)), 5.0)
    save_and_export(repo_root, "Zoro", "Zoro_Katanas_v2", objs)


def main():
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    build_usopp_slingshot(repo_root)
    build_nami_climatact(repo_root)
    build_zoro_katanas(repo_root)
    print("Todos os 3 assets foram gerados com sucesso!")


if __name__ == "__main__":
    main()
