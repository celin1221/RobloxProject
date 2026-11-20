#!/usr/bin/env python3
"""
build_ore_icons.py — Gera os 4 icones de minerios de atributo em estilo anime/cartoon
com contorno espesso (#1A1233), sombreamento cel-shaded e cristais distintos por raridade:
  - ore_hp.png  : Minerio Vital (HP - Comum - Verde Esmeralda)
  - ore_def.png : Minerio Ferreo (Defesa - Raro - Azul Cobalto)
  - ore_vel.png : Minerio Veloz (Velocidade - Epico - Roxo Eletrico)
  - ore_atq.png : Minerio Rubro (Ataque - Lendario - Rubro/Dourado)
"""

from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

OUTLINE = (26, 18, 51, 255)  # #1A1233 — identico a UITheme.Outline e ore.png
S = 1024  # 4x supersampling -> reduz para 256x256 com LANCZOS
FINAL = 256
OUT_DIR = Path(__file__).resolve().parent.parent / "Blender" / "UI" / "icones"


def lerp_c(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def stroke_poly(draw: ImageDraw.ImageDraw, pts, width: int, fill=None, outline=OUTLINE):
    if fill is not None:
        draw.polygon(pts, fill=fill)
    n = len(pts)
    for i in range(n):
        p1, p2 = pts[i], pts[(i + 1) % n]
        draw.line([p1, p2], fill=outline, width=width)
    r = width * 0.48
    for x, y in pts:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=outline)


def scale_pts(pts, s=S):
    return [(int(x * s), int(y * s)) for x, y in pts]


def make_ore_hp() -> Image.Image:
    # Pedra arredondada verde-ardosia com cristais vibrantes esmeralda + formato de "+"/joia vital
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    rock_pts = scale_pts([
        (0.24, 0.25), (0.52, 0.16), (0.78, 0.26), (0.86, 0.56),
        (0.70, 0.84), (0.34, 0.86), (0.16, 0.62), (0.18, 0.38),
    ])
    shade_pts = scale_pts([
        (0.52, 0.16), (0.78, 0.26), (0.86, 0.56), (0.70, 0.84), (0.50, 0.54),
    ])
    stroke_poly(d, rock_pts, width=44, fill=(92, 118, 128, 255))
    d.polygon(shade_pts, fill=(64, 86, 98, 255))
    stroke_poly(d, rock_pts, width=44, fill=None)

    # Cristais de esmeralda (diamantes/losangos estilizados como em ore.png + brilho vital)
    c1 = scale_pts([(0.44, 0.28), (0.58, 0.44), (0.44, 0.60), (0.30, 0.44)])
    c2 = scale_pts([(0.66, 0.44), (0.76, 0.56), (0.66, 0.68), (0.56, 0.56)])
    c3 = scale_pts([(0.42, 0.62), (0.51, 0.72), (0.42, 0.81), (0.33, 0.72)])
    for pts, main_c, hi_c in [
        (c1, (75, 224, 122, 255), (175, 255, 200, 255)),
        (c2, (58, 205, 112, 255), (156, 250, 190, 255)),
        (c3, (75, 224, 122, 255), (175, 255, 200, 255)),
    ]:
        stroke_poly(d, pts, width=22, fill=main_c)
        cx = sum(p[0] for p in pts) // 4
        cy = sum(p[1] for p in pts) // 4
        d.polygon([pts[0], (cx, cy), pts[3]], fill=hi_c)
        stroke_poly(d, pts, width=18, fill=None)

    # Brilho branco no topo
    d.ellipse(scale_pts([(0.30, 0.23), (0.45, 0.30)]), fill=(255, 255, 255, 240))
    return img.resize((FINAL, FINAL), Image.Resampling.LANCZOS)


def make_ore_def() -> Image.Image:
    # Rocha pesada hexagonal blindada com placas/cristais azul cobalto (escudo)
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    rock_pts = scale_pts([
        (0.20, 0.28), (0.50, 0.14), (0.80, 0.28), (0.82, 0.66), (0.50, 0.88), (0.18, 0.66),
    ])
    shade_pts = scale_pts([
        (0.50, 0.14), (0.80, 0.28), (0.82, 0.66), (0.50, 0.88), (0.50, 0.50),
    ])
    stroke_poly(d, rock_pts, width=44, fill=(104, 118, 146, 255))
    d.polygon(shade_pts, fill=(72, 84, 114, 255))
    stroke_poly(d, rock_pts, width=44, fill=None)

    # Placa cristalina em forma de escudo no centro
    shield = scale_pts([
        (0.32, 0.34), (0.68, 0.34), (0.66, 0.58), (0.50, 0.74), (0.34, 0.58),
    ])
    stroke_poly(d, shield, width=24, fill=(61, 165, 255, 255))
    shield_hi = scale_pts([(0.34, 0.36), (0.50, 0.36), (0.50, 0.70), (0.36, 0.57)])
    d.polygon(shield_hi, fill=(138, 212, 255, 255))
    stroke_poly(d, shield, width=22, fill=None)

    # Pequeno chanfro lateral esquerdo/direito
    gem_l = scale_pts([(0.23, 0.50), (0.30, 0.42), (0.30, 0.58)])
    stroke_poly(d, gem_l, width=16, fill=(120, 200, 255, 255))

    d.ellipse(scale_pts([(0.33, 0.20), (0.48, 0.26)]), fill=(255, 255, 255, 240))
    return img.resize((FINAL, FINAL), Image.Resampling.LANCZOS)


def make_ore_vel() -> Image.Image:
    # Aglomerado veloz angular com laminas/cristais roxo eletrico inclinados
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Base rochosa compacta embaixo
    base_pts = scale_pts([
        (0.18, 0.54), (0.34, 0.42), (0.76, 0.48), (0.86, 0.68), (0.68, 0.85), (0.28, 0.84),
    ])
    stroke_poly(d, base_pts, width=42, fill=(78, 66, 118, 255))
    d.polygon(scale_pts([(0.52, 0.45), (0.76, 0.48), (0.86, 0.68), (0.68, 0.85), (0.50, 0.66)]), fill=(52, 42, 88, 255))
    stroke_poly(d, base_pts, width=42, fill=None)

    # 3 pontas de cristal roxo inclinadas para frente/direita (sensacao de velocidade)
    shards = [
        (scale_pts([(0.24, 0.60), (0.44, 0.16), (0.56, 0.24), (0.44, 0.64)]), (186, 108, 255, 255), (236, 192, 255, 255)),
        (scale_pts([(0.44, 0.66), (0.68, 0.14), (0.82, 0.24), (0.62, 0.68)]), (168, 85, 247, 255), (228, 174, 255, 255)),
        (scale_pts([(0.58, 0.72), (0.86, 0.36), (0.90, 0.50), (0.70, 0.74)]), (150, 72, 232, 255), (214, 152, 255, 255)),
    ]
    for pts, col, hi in shards:
        stroke_poly(d, pts, width=24, fill=col)
        d.polygon([pts[0], pts[1], ((pts[1][0] + pts[2][0]) // 2, (pts[1][1] + pts[2][1]) // 2), ((pts[0][0] + pts[3][0]) // 2, (pts[0][1] + pts[3][1]) // 2)], fill=hi)
        stroke_poly(d, pts, width=22, fill=None)

    d.ellipse(scale_pts([(0.46, 0.21), (0.55, 0.28)]), fill=(255, 255, 255, 230))
    return img.resize((FINAL, FINAL), Image.Resampling.LANCZOS)


def make_ore_atq() -> Image.Image:
    # Minerio Lendario Rubro/Dourado: rocha vulcanica escura com picos rubi/fogo intensos
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Picos de cristal atras/acima
    spikes = [
        (scale_pts([(0.22, 0.56), (0.28, 0.18), (0.44, 0.42)]), (255, 92, 64, 255), (255, 198, 88, 255)),
        (scale_pts([(0.58, 0.52), (0.76, 0.16), (0.84, 0.54)]), (242, 64, 58, 255), (255, 172, 78, 255)),
        (scale_pts([(0.36, 0.58), (0.52, 0.10), (0.68, 0.52)]), (255, 76, 62, 255), (255, 218, 96, 255)),
    ]
    for pts, col, hi in spikes:
        stroke_poly(d, pts, width=28, fill=col)
        d.polygon([pts[0], pts[1], ((pts[0][0] + pts[2][0]) // 2, pts[2][1])], fill=hi)
        stroke_poly(d, pts, width=24, fill=None)

    # Base de obsidiana escura com contorno dourado sutil/veios
    base_pts = scale_pts([
        (0.16, 0.58), (0.34, 0.48), (0.68, 0.48), (0.86, 0.60), (0.74, 0.85), (0.28, 0.85),
    ])
    stroke_poly(d, base_pts, width=42, fill=(68, 44, 56, 255))
    d.polygon(scale_pts([(0.50, 0.48), (0.68, 0.48), (0.86, 0.60), (0.74, 0.85), (0.50, 0.66)]), fill=(46, 28, 40, 255))
    stroke_poly(d, base_pts, width=42, fill=None)

    # Nucleo de joia dourado-rubro incrustado
    core = scale_pts([(0.50, 0.54), (0.61, 0.67), (0.50, 0.79), (0.39, 0.67)])
    stroke_poly(d, core, width=20, fill=(255, 198, 60, 255))
    d.polygon(scale_pts([(0.50, 0.55), (0.50, 0.78), (0.40, 0.67)]), fill=(255, 240, 150, 255))
    stroke_poly(d, core, width=18, fill=None)

    d.ellipse(scale_pts([(0.47, 0.16), (0.55, 0.24)]), fill=(255, 255, 255, 240))
    return img.resize((FINAL, FINAL), Image.Resampling.LANCZOS)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    builders = {
        "ore_hp.png": make_ore_hp,
        "ore_def.png": make_ore_def,
        "ore_vel.png": make_ore_vel,
        "ore_atq.png": make_ore_atq,
    }
    for fname, fn in builders.items():
        path = OUT_DIR / fname
        fn().save(path, format="PNG")
        print(f"Saved {path}")


if __name__ == "__main__":
    main()
