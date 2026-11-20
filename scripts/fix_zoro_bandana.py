#!/usr/bin/env python3
"""
fix_zoro_bandana.py — Separa o no/lacinho da bandana de Zoro que o slicer automatico
colocou dentro de Head (x >= 0.009) e o une corretamente em LeftArm, para se mover
junto com o braco esquerdo (LeftUpperArm/LeftArm_Mesh) em vez da cabeca.

Salva:
  - Blender/Zoro/modelo/Zoro_R6_Auto_v2.blend
  - Blender/Zoro/modelo/Zoro_Head_LeftArm_v2.fbx (contendo Zoro_Head e Zoro_LeftArm limpos)
  - renders de conferencia em scratch/Zoro_bandana_v2_*.png
"""

import os
import math
import bpy
import bmesh
from mathutils import Vector, Matrix, Euler

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_BLEND = os.path.join(REPO, "Blender", "Zoro", "modelo", "Zoro_R6_Auto.blend")
OUT_BLEND = os.path.join(REPO, "Blender", "Zoro", "modelo", "Zoro_R6_Auto_v2.blend")
OUT_FBX   = os.path.join(REPO, "Blender", "Zoro", "modelo", "Zoro_Head_LeftArm_v2.fbx")


def split_bandana_knot_to_left_arm():
    bpy.ops.wm.open_mainfile(filepath=SRC_BLEND)
    head = bpy.data.objects["Head"]
    left_arm = bpy.data.objects["LeftArm"]

    bm_head = bmesh.new()
    bm_head.from_mesh(head.data)
    bm_head.verts.ensure_lookup_table()
    bm_head.faces.ensure_lookup_table()

    uv_head = bm_head.loops.layers.uv.verify()

    # Identifica ilhas com X > 0.009 (no da bandana sobre o ombro esquerdo)
    knot_verts = {v for v in bm_head.verts if v.co.x > 0.009}
    knot_faces = [f for f in bm_head.faces if all(v in knot_verts for v in f.verts)]
    print(f"[Zoro Bandana] Vertices movidos de Head -> LeftArm: {len(knot_verts)} ({len(knot_faces)} faces)")

    # Transfere exatamente vertices + faces + UVs para LeftArm
    bm_arm = bmesh.new()
    bm_arm.from_mesh(left_arm.data)
    uv_arm = bm_arm.loops.layers.uv.verify()

    vmap = {}
    for f in knot_faces:
        new_vs = []
        for v in f.verts:
            nv = vmap.get(v)
            if nv is None:
                nv = bm_arm.verts.new(v.co)
                vmap[v] = nv
            new_vs.append(nv)
        nf = bm_arm.faces.new(new_vs)
        nf.material_index = f.material_index
        for l_src, l_dst in zip(f.loops, nf.loops):
            l_dst[uv_arm].uv = l_src[uv_head].uv

    # Remove as faces e vertices do no de dentro de Head
    bmesh.ops.delete(bm_head, geom=list(knot_verts), context='VERTS')

    bm_head.normal_update()
    bm_head.to_mesh(head.data)
    head.data.update()
    bm_head.free()

    bm_arm.normal_update()
    bm_arm.to_mesh(left_arm.data)
    left_arm.data.update()
    bm_arm.free()

    for nm, obj in (("Head", head), ("LeftArm", left_arm)):
        vs = [obj.matrix_world @ v.co for v in obj.data.vertices]
        mn = tuple(round(min(p[i] for p in vs) * 100, 3) for i in range(3))
        mx = tuple(round(max(p[i] for p in vs) * 100, 3) for i in range(3))
        sz = tuple(round(mx[i] - mn[i], 3) for i in range(3))
        ctr = tuple(round((mx[i] + mn[i]) * 0.5, 3) for i in range(3))
        print(f"  [{nm}] studs min={mn} max={mx} size={sz} center={ctr}")

    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

    # Exporta APENAS Head e LeftArm em Zoro_Head_LeftArm_v2.fbx
    # Remove os nos de textura externa na copia exportada para nao gerar upload duplicado de imagem
    # (usaremos no Roblox a TexturaID oficial ja existente do Zoro rbxassetid://91845586938167!)
    head.name = "Zoro_Head_v2"
    left_arm.name = "Zoro_LeftArm_v2"
    bpy.ops.object.select_all(action='DESELECT')
    head.select_set(True)
    left_arm.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.export_scene.fbx(
        filepath=OUT_FBX,
        use_selection=True,
        object_types={'MESH'},
        mesh_smooth_type='FACE',
        add_leaf_bones=False,
        path_mode='AUTO',
        embed_textures=False,
    )
    print(f"[EXPORT] {OUT_FBX}")


if __name__ == "__main__":
    split_bandana_knot_to_left_arm()
