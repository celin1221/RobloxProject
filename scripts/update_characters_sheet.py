"""
update_characters_sheet.py — Gera/atualiza automaticamente a Planilha de Personagens do RobloxProjetoX.

Le diretamente a fonte da verdade em:
  - src/shared/Data/Characters.luau
  - src/shared/Data/Moves.luau
  - src/server_storage/Codes.luau

E grava a planilha formatada com 4 abas (Personagens, Ataques, Kit por Personagem, Resumo) em:
  - Blender/Planilha_Personagens.xlsx
  - Planilha_Personagens.xlsx (copia sincronizada na raiz do repositorio)

REGRA DO PROJETO: Sempre executar `python scripts/update_characters_sheet.py` apos adicionar
ou modificar personagens ou ataques/golpes em src/shared/Data/Characters.luau ou Moves.luau.
"""

from __future__ import annotations

import os
import re
import shutil
from pathlib import Path
from typing import Any

import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter

ROOT = Path(__file__).resolve().parent.parent
CHARACTERS_LUAU = ROOT / "src" / "shared" / "Data" / "Characters.luau"
MOVES_LUAU = ROOT / "src" / "shared" / "Data" / "Moves.luau"
PASSIVES_LUAU = ROOT / "src" / "shared" / "Data" / "Passives.luau"
AWAKENING_LUAU = ROOT / "src" / "shared" / "Data" / "Awakening.luau"
CODES_LUAU = ROOT / "src" / "server_storage" / "Codes.luau"
OUT_BLENDER = ROOT / "Blender" / "Planilha_Personagens.xlsx"
OUT_ROOT = ROOT / "Planilha_Personagens.xlsx"

# Metadados de producao (rig, estagio de arte 3D, notas).
# Qualquer personagem novo adicionado em Characters.luau aparece automaticamente mesmo sem entrada aqui.
DEV_META: dict[str, dict[str, str]] = {
    "Kaen": {
        "Stage": "Protótipo Base",
        "HasModel": "Sim",
        "Rig": "R15 Padrão",
        "Anim": "Não (Base)",
        "VfxCutIn": "Não / Não",
        "Shiny": "Sem Preset",
        "Notes": "Personagem base genérico; golpes sem Anim/VFX/Assinatura dedicados",
    },
    "Raiko": {
        "Stage": "Protótipo Base",
        "HasModel": "Sim",
        "Rig": "R15 + Acessórios",
        "Anim": "Não (Base)",
        "VfxCutIn": "Não / Não",
        "Shiny": "Sem Preset",
        "Notes": "Personagem base genérico; golpes sem Anim/VFX/Assinatura dedicados",
    },
    "Yomogi": {
        "Stage": "Concluído (100%)",
        "HasModel": "Sim",
        "Rig": "R15 + Acessórios",
        "Anim": "Sim (10 anims)",
        "VfxCutIn": "VFX Sim / Cut-In Não",
        "Shiny": "Sim (Paleta Outono)",
        "Notes": "Pronto; 4 golpes exclusivos completos com animações e VFX",
    },
    "Setero": {
        "Stage": "Concluído (100%)",
        "HasModel": "Sim",
        "Rig": "R15 Skinned (Mixamo)",
        "Anim": "Sim (9 anims)",
        "VfxCutIn": "Sim / Sim (Tudo Roxo)",
        "Shiny": "Sim (Tex Platina)",
        "Notes": "2 golpes exclusivos (Atração, Tudo Roxo com Cut-In) + 2 base",
    },
    "San": {
        "Stage": "Concluído (100%)",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Tripo v2)",
        "Anim": "Sim (4 golpes + base)",
        "VfxCutIn": "Sim / Sim (2 Cut-Ins)",
        "Shiny": "Sim (Tex Dourada)",
        "Notes": "4 golpes exclusivos completos (Kamehameha, Genki Dama, Combo Marcial, Carga de Ki)",
    },
    "BarbaBranca": {
        "Stage": "Concluído (100%)",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Tripo + Capa/Bisento)",
        "Anim": "Sim (4 golpes + base)",
        "VfxCutIn": "Sim / Sim (2 Cut-Ins)",
        "Shiny": "Sim (Paleta + Aura)",
        "Notes": "Líder do Ginásio da Grand Line; modelo Tripo com Capa + Bisento e 4 golpes completos",
    },
    "Luffy": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Inicial de One Piece; faltam golpes exclusivos, animações próprias, VFX e Cut-In",
    },
    "Zoro": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo + 3 Katanas)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D com 3 katanas e bandana; faltam golpes exclusivos, animações próprias e VFX",
    },
    "Sanji": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto; faltam golpes exclusivos (chutes), animações próprias e VFX",
    },
    "Nami": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo + Clima-Tact)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D com Clima-Tact; faltam golpes exclusivos, animações próprias e VFX",
    },
    "Usopp": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo + Estilingue)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D com estilingue; faltam golpes exclusivos, animações próprias e VFX",
    },
    "Sakura": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto (Naruto); faltam golpes exclusivos, animações próprias e VFX",
    },
    "Shikamaru": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto (Naruto); faltam golpes exclusivos, animações próprias e VFX",
    },
    "Kakashi": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto (Naruto); faltam golpes exclusivos, animações próprias e VFX",
    },
    "Sasuke": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto (Naruto); faltam golpes exclusivos, animações próprias e VFX",
    },
    "Naruto": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Inicial de Naruto com modelo 3D pronto; faltam golpes exclusivos, animações próprias, VFX e Cut-In",
    },
    "Sarutobi": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo + Aura Hokage 5 Elementos)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Aura Sim / Golpes Pendentes",
        "Shiny": "Sim (Paleta + Aura)",
        "Notes": "Líder do Ginásio de Konoha com modelo 3D + Aura Lendária (Vontade do Fogo & 5 Orbes Elementais); faltam golpes exclusivos, animações e Cut-In",
    },
    "Chad": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto (Bleach, braço blindado); faltam golpes exclusivos, animações próprias e VFX",
    },
    "Uryu": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto (Bleach); faltam golpes exclusivos, animações próprias e VFX",
    },
    "Rukia": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto (Bleach); faltam golpes exclusivos, animações próprias e VFX",
    },
    "Renji": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Modelo 3D pronto (Bleach); faltam golpes exclusivos, animações próprias e VFX",
    },
    "Ichigo": {
        "Stage": "Em Andamento",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo)",
        "Anim": "Não (Provisórias)",
        "VfxCutIn": "Pendente",
        "Shiny": "Sim (Paleta)",
        "Notes": "Inicial de Bleach com modelo 3D pronto; faltam golpes exclusivos, animações próprias, VFX e Cut-In",
    },
    "Byakuya": {
        "Stage": "Concluído (100%)",
        "HasModel": "Sim",
        "Rig": "R6-on-R15 (Auto-Tripo + Aura Minimalista Senbonzakura)",
        "Anim": "Sim (CombatAnimator 60 FPS + 4 golpes)",
        "VfxCutIn": "Sim / Sim (2 Cut-Ins)",
        "Shiny": "Sim (Paleta + Aura)",
        "Notes": "Líder do Ginásio da Soul Society; aura minimalista, cabelo corrigido, CorteBasico/CorteCruzado + Senbonzakura (Shikai) e SenbonzakuraKageyoshi (Bankai)",
    },
    "ProtoRaro": {
        "Stage": "Teste (Remover)",
        "HasModel": "Sim",
        "Rig": "R15 + Acessórios",
        "Anim": "Não",
        "VfxCutIn": "Não / Não",
        "Shiny": "Não",
        "Notes": "Prototype = true (apenas teste de Equipe; remover antes de publicar)",
    },
    "ProtoEpico": {
        "Stage": "Teste (Remover)",
        "HasModel": "Sim",
        "Rig": "R15 + Acessórios",
        "Anim": "Não",
        "VfxCutIn": "Não / Não",
        "Shiny": "Não",
        "Notes": "Prototype = true (apenas teste de Equipe; remover antes de publicar)",
    },
}

ANIME_DISPLAY = {
    "OnePiece": "One Piece",
    "Naruto": "Naruto",
    "Bleach": "Bleach",
    "DragonBall": "Dragon Ball",
    "JujutsuKaisen": "Jujutsu Kaisen",
    "Generico": "Genérico",
}
ANIME_ORDER = {
    "OnePiece": 1,
    "Naruto": 2,
    "Bleach": 3,
    "DragonBall": 4,
    "JujutsuKaisen": 5,
    "Generico": 6,
}
RARITY_DISPLAY = {
    "Comum": "Comum",
    "Raro": "Raro",
    "Epico": "Épico",
    "Lendario": "Lendário",
}
RARITY_ORDER = {"Comum": 1, "Raro": 2, "Epico": 3, "Lendario": 4}
TARGET_DISPLAY = {
    "Single": "1 Alvo",
    "AllEnemies": "Todos Inimigos",
    "AllOthers": "Todos Outros",
    "AllAllies": "Aliados",
    "EnemySide": "Campo Inimigo",
    "Self": "Próprio",
}
CATEGORY_DISPLAY = {
    "Damage": "Dano",
    "Status": "Status",
}
STATUS_DISPLAY = {
    "Burn": "Queimadura",
    "Poison": "Veneno",
    "Paralysis": "Paralisia",
    "Sleep": "Sono",
    "Freeze": "Congelamento",
}
STAT_DISPLAY = {
    "Attack": "Ataque",
    "Defense": "Defesa",
    "Speed": "Velocidade",
    "Accuracy": "Precisão",
}
HAZARD_DISPLAY = {
    "Spikes": "Estrepes (1/8, 1/6, 1/4 HP na entrada, até 3x)",
    "ToxicSpikes": "Estrepes Tóxicos (1x Veneno / 2x Veneno + dano)",
    "StickyWeb": "Rede Aderente (-1 Velocidade na entrada)",
}
SIDE_EFFECT_DISPLAY = {
    "Barrier": "Barreira (reduz dano recebido no time)",
    "Tailwind": "Vento a Favor (dobra Velocidade do time)",
}
CLASS_ORDER = {
    "Espadachim": 1,
    "Lutador": 2,
    "Mago": 3,
    "Atirador": 4,
    "Universal": 5,
}
ORIGIN_ORDER = {
    "Genérico de Classe": 1,
    "Genérico Universal": 2,
    "Assinatura": 3,
    "Exclusivo": 4,
    "Clássico": 5,
    "Reserva (Sem PP)": 6,
}


def stage_pct_str(stages: int) -> str:
    mult = (1.0 + 0.5 * stages) if stages >= 0 else (2.0 / (2.0 - stages))
    pct = int(round((mult - 1.0) * 100))
    return f"{pct:+d}%"


def strip_named_block(body: str, field_name: str) -> str:
    m = re.search(rf"{field_name}\s*=\s*\{{", body)
    if not m:
        return body
    _, end_idx = extract_braced_block(body, m.end() - 1)
    return body[: m.start()] + body[end_idx:]


def parse_effect_desc(body: str, move_target: str, drain: float | None, recoil: float | None, breaks_protect: bool) -> str:
    parts: list[str] = []

    if breaks_protect:
        parts.append("Rompe Proteger / Guarda Ampla")
    if drain is not None:
        parts.append(f"Dreno: absorve {int(round(drain * 100))}% do dano em HP")
    if recoil is not None:
        parts.append(f"Recuo: sofre {int(round(recoil * 100))}% do dano")

    m_eff = re.search(r"Effect\s*=\s*\{", body)
    if m_eff:
        eff_block, _ = extract_braced_block(body, m_eff.end() - 1)
        eff_top = strip_named_block(eff_block, "Changes")
        kind_m = re.search(r'Kind\s*=\s*"([^"]+)"', eff_top)
        chance_m = re.search(r"Chance\s*=\s*(\d+)", eff_top)
        tgt_m = re.search(r'Target\s*=\s*"([^"]+)"', eff_top)
        chance = int(chance_m.group(1)) if chance_m else 100
        if move_target == "AllAllies":
            tgt = "no Time"
        elif tgt_m and tgt_m.group(1) == "Self":
            tgt = "no Próprio"
        else:
            tgt = "no Alvo"
        kind = kind_m.group(1) if kind_m else ""

        if kind == "Status":
            st_m = re.search(r'Status\s*=\s*"([^"]+)"', eff_top)
            st_name = STATUS_DISPLAY.get(st_m.group(1), st_m.group(1)) if st_m else "Status"
            parts.append(f"Status: {st_name} {tgt} ({chance}%)")
        elif kind == "StatStage":
            stat_m = re.search(r'Stat\s*=\s*"([^"]+)"', eff_top)
            stg_m = re.search(r"Stages\s*=\s*(-?\d+)", eff_top)
            stat_name = STAT_DISPLAY.get(stat_m.group(1), stat_m.group(1)) if stat_m else "Atributo"
            stages = int(stg_m.group(1)) if stg_m else 1
            tag = "Buff" if stages > 0 else "Debuff"
            parts.append(f"{tag}: {stages:+d} {stat_name} ({stage_pct_str(stages)}) {tgt} ({chance}%)")
        elif kind == "MultiStat":
            changes = re.findall(r'Stat\s*=\s*"([^"]+)"\s*,\s*Stages\s*=\s*(-?\d+)', eff_block)
            ch_strs = [f"{int(st):+d} {STAT_DISPLAY.get(sn, sn)} ({stage_pct_str(int(st))})" for sn, st in changes]
            all_pos = all(int(st) > 0 for _, st in changes) if changes else True
            tag = "Buff" if all_pos else "Alteração"
            parts.append(f"{tag}: {', '.join(ch_strs)} {tgt}")
        elif kind == "Protect":
            parts.append("Proteção: bloqueia ataques inimigos no turno")
        elif kind == "WideProtect":
            parts.append("Proteção: bloqueia golpes em área no time (2x2)")
        elif kind == "Hazard":
            hz_m = re.search(r'Hazard\s*=\s*"([^"]+)"', eff_top)
            hz_name = HAZARD_DISPLAY.get(hz_m.group(1), hz_m.group(1)) if hz_m else "Hazard"
            parts.append(f"Hazard: {hz_name}")
        elif kind == "ClearHazards":
            sc_m = re.search(r'Scope\s*=\s*"([^"]+)"', eff_top)
            scope_txt = "ambos os campos" if (sc_m and sc_m.group(1) == "All") else "próprio campo"
            desc = f"Limpeza: remove hazards ({scope_txt})"
            bs_m = re.search(r'BonusStat\s*=\s*"([^"]+)"', eff_top)
            bst_m = re.search(r"BonusStages\s*=\s*(-?\d+)", eff_top)
            if bs_m:
                st_n = STAT_DISPLAY.get(bs_m.group(1), bs_m.group(1))
                st_v = int(bst_m.group(1)) if bst_m else 1
                desc += f" + {st_v:+d} {st_n} no Próprio"
            parts.append(desc)
        elif kind == "SideEffect":
            se_m = re.search(r'SideEffect\s*=\s*"([^"]+)"', eff_top)
            tr_m = re.search(r"Turns\s*=\s*(\d+)", eff_top)
            se_name = SIDE_EFFECT_DISPLAY.get(se_m.group(1), se_m.group(1)) if se_m else "Campo"
            turns_txt = f" ({tr_m.group(1)}t)" if tr_m else ""
            parts.append(f"Campo{turns_txt}: {se_name}")
        elif kind == "Heal":
            fr_m = re.search(r"Fraction\s*=\s*([0-9.]+)", eff_top)
            pct = int(round(float(fr_m.group(1)) * 100)) if fr_m else 50
            parts.append(f"Cura: recupera {pct}% HP {tgt}")
        elif kind == "Cleanse":
            parts.append(f"Purificação: remove status negativo {tgt}")
        else:
            parts.append(eff_block.strip())

    return " | ".join(parts) if parts else "Nenhum"


def parse_timing_desc(body: str) -> str:
    m_tim = re.search(r"Timing\s*=\s*\{", body)
    if not m_tim:
        return "-"
    tim_block, _ = extract_braced_block(body, m_tim.end() - 1)
    parts = []
    for key in ("Charge", "Release", "Impact", "Length"):
        km = re.search(rf"{key}\s*=\s*([0-9.]+)", tim_block)
        parts.append(f"{float(km.group(1)):.2f}s" if km else "-")
    return " / ".join(parts)


def decode_luau_str(raw: str) -> str:
    return re.sub(r"\\u\{([0-9a-fA-F]+)\}", lambda m: chr(int(m.group(1), 16)), raw)


def extract_braced_block(text: str, open_brace_idx: int) -> tuple[str, int]:
    depth = 0
    in_str = False
    escape = False
    i = open_brace_idx
    while i < len(text):
        ch = text[i]
        if in_str:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return text[open_brace_idx + 1 : i], i + 1
        i += 1
    raise ValueError("Unmatched '{' in Luau source")


def parse_top_level_entries(block: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    i = 0
    n = len(block)
    while i < n:
        # Skip whitespace and comments
        if block[i : i + 2] == "--":
            nl = block.find("\n", i)
            i = n if nl == -1 else nl + 1
            continue
        m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{", block[i:])
        if m:
            key = m.group(1)
            brace_idx = i + m.end() - 1
            inner, end_idx = extract_braced_block(block, brace_idx)
            entries.append((key, inner))
            i = end_idx
            continue
        i += 1
    return entries


def parse_moves() -> tuple[dict[str, dict[str, Any]], dict[str, list[str]]]:
    src = MOVES_LUAU.read_text(encoding="utf-8")

    # Moves.List
    m_list = re.search(r"Moves\.List\s*=\s*\{", src)
    assert m_list, "Moves.List nao encontrado"
    list_block, _ = extract_braced_block(src, m_list.end() - 1)

    moves: dict[str, dict[str, Any]] = {}
    for mid, body in parse_top_level_entries(list_block):
        name_m = re.search(r'Name\s*=\s*"([^"]+)"', body)
        type_m = re.search(r'Type\s*=\s*"([^"]+)"', body)
        cat_m = re.search(r'Category\s*=\s*"([^"]+)"', body)
        pow_m = re.search(r"Power\s*=\s*(\d+)", body)
        acc_m = re.search(r"Accuracy\s*=\s*(\d+|nil)", body)
        pp_m = re.search(r"PP\s*=\s*(\d+)", body)
        crit_m = re.search(r"CritChance\s*=\s*([0-9.]+)", body)
        prio_m = re.search(r"Priority\s*=\s*(-?\d+)", body)
        lvl_m = re.search(r"LearnLevel\s*=\s*(\d+)", body)
        drain_m = re.search(r"Drain\s*=\s*([0-9.]+)", body)
        recoil_m = re.search(r"Recoil\s*=\s*([0-9.]+)", body)
        breaks_protect = bool(re.search(r"BreaksProtect\s*=\s*true", body))
        body_no_effect = strip_named_block(body, "Effect")
        target_m = re.search(r'Target\s*=\s*"([^"]+)"', body_no_effect)
        sig = bool(re.search(r"Signature\s*=\s*true", body))
        cutin = bool(re.search(r"CutIn\s*=\s*true", body))
        hidden = bool(re.search(r"Hidden\s*=\s*true", body))
        anim_m = re.search(r'Anim\s*=\s*"([^"]+)"', body)
        vfx_m = re.search(r'Vfx\s*=\s*"([^"]+)"', body)
        generic = bool(re.search(r"Generic\s*=\s*true", body))

        has_anim = anim_m is not None
        has_vfx = vfx_m is not None
        cat = cat_m.group(1) if cat_m else "Damage"
        if target_m:
            target = target_m.group(1)
        elif cat == "Status" and re.search(r'Target\s*=\s*"Self"', body):
            target = "Self"
        else:
            target = "Single"

        acc_val: Any
        if acc_m and acc_m.group(1) != "nil":
            acc_val = int(acc_m.group(1))
        else:
            acc_val = "Nunca erra"

        crit_chance = float(crit_m.group(1)) if crit_m else 0.0625
        priority = int(prio_m.group(1)) if prio_m else 0
        learn_level = int(lvl_m.group(1)) if lvl_m else None
        drain = float(drain_m.group(1)) if drain_m else None
        recoil = float(recoil_m.group(1)) if recoil_m else None
        move_type = type_m.group(1) if type_m else "Universal"
        effect_desc = parse_effect_desc(body, target, drain, recoil, breaks_protect)
        timing_desc = parse_timing_desc(body)

        anim_name = anim_m.group(1) if anim_m else ""
        vfx_name = vfx_m.group(1) if vfx_m else ""
        is_proc_gen = vfx_name in {
            "GenSlash", "GenMelee", "GenGroundWave", "GenProjectile", "GenVolley",
            "GenSkyStrike", "GenHex", "GenBuff", "GenShield", "GenHazard", "GenHeal", "GenWind",
        }

        if hidden:
            origin = "Reserva (Sem PP)"
        elif generic and move_type == "Universal":
            origin = "Genérico Universal"
        elif generic:
            origin = "Genérico de Classe"
        elif sig:
            origin = "Assinatura"
        elif (has_anim or has_vfx or cutin) and not is_proc_gen:
            origin = "Exclusivo"
        else:
            origin = "Clássico"

        if hidden:
            dev_status = "Fallback (Sem PP)"
        elif has_anim and has_vfx:
            dev_status = "Implementado (100%)"
        elif has_anim or has_vfx:
            dev_status = "Parcial"
        else:
            dev_status = "Pendente (Anim/VFX)"

        moves[mid] = {
            "Id": mid,
            "Name": decode_luau_str(name_m.group(1)) if name_m else mid,
            "Type": move_type,
            "Category": cat,
            "Power": int(pow_m.group(1)) if pow_m else "-",
            "Accuracy": acc_val,
            "PP": int(pp_m.group(1)) if pp_m else 0,
            "Priority": priority,
            "LearnLevel": learn_level,
            "CritChance": crit_chance,
            "Target": target,
            "EffectDesc": effect_desc,
            "TimingDesc": timing_desc,
            "Origin": origin,
            "DevStatus": dev_status,
            "Signature": sig,
            "CutIn": cutin,
            "Hidden": hidden,
            "AnimName": anim_m.group(1) if anim_m else "",
            "VfxName": vfx_m.group(1) if vfx_m else "",
            "HasAnim": has_anim,
            "HasVfx": has_vfx,
            "Generic": generic,
        }

    # Moves.ClassDefaults -> list of (Level, MoveId)
    m_def = re.search(r"Moves\.ClassDefaults\s*=\s*\{", src)
    assert m_def, "Moves.ClassDefaults nao encontrado"
    def_block, _ = extract_braced_block(src, m_def.end() - 1)
    class_defaults: dict[str, list[tuple[int, str]]] = {}
    for cls_id, body in parse_top_level_entries(def_block):
        pairs = [(int(lv), mid) for lv, mid in re.findall(r'Level\s*=\s*(\d+)\s*,\s*Move\s*=\s*"([^"]+)"', body)]
        pairs.sort(key=lambda x: (x[0], x[1]))
        class_defaults[cls_id] = pairs

    return moves, class_defaults


PASSIVE_TIER_DISPLAY = {
    "Generic": "Comum (Genérica)",
    "Unique": "Única (Lendário)",
    "Secret": "Secreta (Despertar)",
}
PASSIVE_TIER_ORDER = {"Generic": 1, "Unique": 2, "Secret": 3}


def parse_passives() -> dict[str, dict[str, Any]]:
    src = PASSIVES_LUAU.read_text(encoding="utf-8")
    m_list = re.search(r"Passives\.List\s*=\s*\{", src)
    assert m_list, "Passives.List nao encontrado"
    list_block, _ = extract_braced_block(src, m_list.end() - 1)
    out: dict[str, dict[str, Any]] = {}
    for pid, body in parse_top_level_entries(list_block):
        top = strip_named_block(body, "Effect")
        name_m = re.search(r'Name\s*=\s*"([^"]+)"', top)
        tier_m = re.search(r'Tier\s*=\s*"([^"]+)"', top)
        owner_m = re.search(r'Owner\s*=\s*"([^"]+)"', top)
        short_m = re.search(r'Short\s*=\s*"([^"]+)"', top)
        desc_m = re.search(r'Description\s*=\s*"([^"]+)"', top)
        out[pid] = {
            "Id": pid,
            "Name": decode_luau_str(name_m.group(1)) if name_m else pid,
            "Tier": tier_m.group(1) if tier_m else "Generic",
            "Owner": owner_m.group(1) if owner_m else "",
            "Short": decode_luau_str(short_m.group(1)) if short_m else "",
            "Description": decode_luau_str(desc_m.group(1)) if desc_m else "",
        }
    return out


def parse_awakening() -> tuple[dict[str, str], dict[str, dict[str, Any]]]:
    src = AWAKENING_LUAU.read_text(encoding="utf-8")
    # Material names
    mat_names: dict[str, str] = {}
    m_mat = re.search(r"Awakening\.Materials\s*=\s*\{", src)
    if m_mat:
        mat_block, _ = extract_braced_block(src, m_mat.end() - 1)
        for mid, body in parse_top_level_entries(mat_block):
            nm = re.search(r'Name\s*=\s*"([^"]+)"', body)
            mat_names[mid] = decode_luau_str(nm.group(1)) if nm else mid

    recipes: dict[str, dict[str, Any]] = {}
    m_rec = re.search(r"Awakening\.Recipes\s*=\s*\{", src)
    if m_rec:
        rec_block, _ = extract_braced_block(src, m_rec.end() - 1)
        for cid, body in parse_top_level_entries(rec_block):
            top = strip_named_block(body, "Materials")
            lv_m = re.search(r"MinLevel\s*=\s*(\d+)", top)
            gold_m = re.search(r"Gold\s*=\s*(\d+)", top)
            sp_m = re.search(r'SecretPassive\s*=\s*"([^"]+)"', top)
            mats = re.findall(r'Id\s*=\s*"([^"]+)"\s*,\s*Qty\s*=\s*(\d+)', body)
            min_lv = int(lv_m.group(1)) if lv_m else 35
            gold = int(gold_m.group(1)) if gold_m else 10000
            parts = [f"Nv. {min_lv}+"]
            for mid, qty in mats:
                parts.append(f"{qty}x {mat_names.get(mid, mid)}")
            parts.append(f"{gold:,} Gold".replace(",", "."))
            recipes[cid] = {
                "MinLevel": min_lv,
                "Gold": gold,
                "SecretPassive": sp_m.group(1) if sp_m else "",
                "Summary": " + ".join(parts),
            }
    return mat_names, recipes


def parse_codes() -> dict[str, list[str]]:
    src = CODES_LUAU.read_text(encoding="utf-8")
    m_ret = re.search(r"return\s*\{", src)
    assert m_ret, "return table nao encontrado em Codes.luau"
    block, _ = extract_braced_block(src, m_ret.end() - 1)
    by_char: dict[str, list[str]] = {}
    for code, body in parse_top_level_entries(block):
        single = re.search(r'Character\s*=\s*"([^"]+)"', body)
        if single:
            by_char.setdefault(single.group(1), []).append(code)
    return by_char


def parse_characters(class_defaults: dict[str, list[tuple[int, str]]]) -> list[dict[str, Any]]:
    src = CHARACTERS_LUAU.read_text(encoding="utf-8")
    m_list = re.search(r"Characters\.List\s*=\s*\{", src)
    assert m_list, "Characters.List nao encontrado"
    list_block, after_list = extract_braced_block(src, m_list.end() - 1)

    raw_entries = parse_top_level_entries(list_block)
    # Also capture Characters.List.<Id> = { ... } (ProtoRaro, ProtoEpico, etc.)
    tail = src[after_list:]
    for m_extra in re.finditer(r"Characters\.List\.([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{", tail):
        cid = m_extra.group(1)
        inner, _ = extract_braced_block(tail, m_extra.end() - 1)
        raw_entries.append((cid, inner))

    chars: list[dict[str, Any]] = []
    for cid, body in raw_entries:
        name_m = re.search(r'Name\s*=\s*"([^"]+)"', body)
        anime_m = re.search(r'Anime\s*=\s*"([^"]+)"', body)
        type_m = re.search(r'Type\s*=\s*"([^"]+)"', body)
        rar_m = re.search(r'Rarity\s*=\s*"([^"]+)"', body)
        starter = bool(re.search(r"Starter\s*=\s*true", body))
        proto = bool(re.search(r"Prototype\s*=\s*true", body))
        passive_m = re.search(r'\bPassive\s*=\s*"([^"]+)"', body)
        secret_passive_m = re.search(r'\bSecretPassive\s*=\s*"([^"]+)"', body)
        has_placeholder = bool(re.search(r"PlaceholderColors\s*=\s*\{", body))
        has_shiny_palette = bool(re.search(r"ShinyPalette\s*=\s*\{", body))
        stats_m = re.search(
            r"BaseStats\s*=\s*\{\s*HP\s*=\s*(\d+)\s*,\s*Attack\s*=\s*(\d+)\s*,\s*Defense\s*=\s*(\d+)\s*,\s*Speed\s*=\s*(\d+)",
            body,
        )
        hp, atk, df, spd = (int(stats_m.group(i)) for i in range(1, 5)) if stats_m else (0, 0, 0, 0)

        cls_id = type_m.group(1) if type_m else "Lutador"
        ls_m = re.search(r"Learnset\s*=\s*\{", body)
        if ls_m:
            ls_block, _ = extract_braced_block(body, ls_m.end() - 1)
            learnset = [(int(lv), mid) for lv, mid in re.findall(r'Level\s*=\s*(\d+)\s*,\s*Move\s*=\s*"([^"]+)"', ls_block)]
            learnset.sort(key=lambda x: (x[0], x[1]))
            uses_class_kit = False
        else:
            learnset = list(class_defaults.get(cls_id, class_defaults["Lutador"]))
            uses_class_kit = True
        move_ids = [mid for _, mid in learnset]

        chars.append(
            {
                "Id": cid,
                "Name": decode_luau_str(name_m.group(1)) if name_m else cid,
                "Anime": anime_m.group(1) if anime_m else "Generico",
                "Class": cls_id,
                "Rarity": rar_m.group(1) if rar_m else "Comum",
                "Starter": starter,
                "Prototype": proto,
                "HasPlaceholder": has_placeholder,
                "HasShinyPalette": has_shiny_palette,
                "HP": hp,
                "ATK": atk,
                "DEF": df,
                "SPD": spd,
                "Learnset": learnset,
                "MoveIds": move_ids,
                "UsesClassKit": uses_class_kit,
                "Passive": passive_m.group(1) if passive_m else "",
                "SecretPassive": secret_passive_m.group(1) if secret_passive_m else "",
            }
        )

    chars.sort(
        key=lambda c: (
            1 if c["Prototype"] else 0,
            ANIME_ORDER.get(c["Anime"], 99),
            RARITY_ORDER.get(c["Rarity"], 99),
            c["Name"].lower(),
        )
    )
    return chars


def build_workbook(
    chars: list[dict[str, Any]],
    moves: dict[str, dict[str, Any]],
    codes_by_char: dict[str, list[str]],
    passives: dict[str, dict[str, Any]],
    awakening_recipes: dict[str, dict[str, Any]],
) -> openpyxl.Workbook:
    wb = openpyxl.Workbook()

    # Palette (matching original spreadsheet design + Combat Classes)
    HEADER_FILL = PatternFill("solid", fgColor="1E293B")
    HEADER_FONT = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    TITLE_FILL = PatternFill("solid", fgColor="0F172A")
    TITLE_FONT = Font(name="Calibri", size=12, bold=True, color="FFFFFF")
    BASE_FONT = Font(name="Calibri", size=10)
    BOLD_FONT = Font(name="Calibri", size=10, bold=True)
    THIN_SIDE = Side(border_style="thin", color="CBD5E1")
    CELL_BORDER = Border(left=THIN_SIDE, right=THIN_SIDE, top=THIN_SIDE, bottom=THIN_SIDE)

    GREEN = PatternFill("solid", fgColor="DCFCE7")
    YELLOW = PatternFill("solid", fgColor="FEF9C3")
    ORANGE = PatternFill("solid", fgColor="FFEDD5")
    RED = PatternFill("solid", fgColor="FEE2E2")
    SLATE = PatternFill("solid", fgColor="F1F5F9")
    BLUE = PatternFill("solid", fgColor="DBEAFE")
    PURPLE = PatternFill("solid", fgColor="F3E8FF")
    GOLD = PatternFill("solid", fgColor="FEF3C7")
    GRAY = PatternFill("solid", fgColor="E2E8F0")
    TEAL = PatternFill("solid", fgColor="CCFBF1")

    STAGE_FILL = {
        "Concluído (100%)": GREEN,
        "Em Andamento": ORANGE,
        "Modelo Provisório": YELLOW,
        "Protótipo Base": SLATE,
        "Teste (Remover)": RED,
    }
    RARITY_FILL = {
        "Comum": GRAY,
        "Raro": BLUE,
        "Épico": PURPLE,
        "Lendário": GOLD,
    }
    CLASS_FILL = {
        "Espadachim": RED,
        "Lutador": ORANGE,
        "Mago": PURPLE,
        "Atirador": GREEN,
        "Universal": GRAY,
    }
    ANIME_FILL = {
        "One Piece": BLUE,
        "Naruto": ORANGE,
        "Bleach": TEAL,
        "Dragon Ball": GOLD,
        "Jujutsu Kaisen": PURPLE,
        "Genérico": SLATE,
    }

    # -----------------------------------------------------------------
    # ABA 1: Personagens
    # -----------------------------------------------------------------
    ws = wb.active
    ws.title = "Personagens"
    ws.freeze_panes = "D2"

    headers = [
        "ID",
        "Nome",
        "Tag (Anime)",
        "Estágio de Dev",
        "Raridade",
        "Classe",
        "Starter",
        "Modelo 3D",
        "Rig / Origem",
        "HP",
        "ATK",
        "DEF",
        "SPD",
        "Total Stats",
        "Ataque Assinatura",
        "Poder Assinatura",
        "Animação Personalizada",
        "VFX / Cut-In",
        "Variante Brilhante",
        "Código Dev",
        "Passiva Base",
        "Tipo Passiva",
        "Passiva Secreta (Despertar)",
        "Receita de Despertar",
        "Pendências / Observações",
    ]
    ws.append(headers)
    ws.row_dimensions[1].height = 26
    for col_idx in range(1, len(headers) + 1):
        cell = ws.cell(1, col_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = CELL_BORDER

    for r_idx, ch in enumerate(chars, start=2):
        cid = ch["Id"]
        meta = DEV_META.get(cid, {})
        stage = meta.get(
            "Stage",
            "Teste (Remover)"
            if ch["Prototype"]
            else ("Modelo Provisório" if ch["HasPlaceholder"] else "Em Andamento"),
        )
        has_model = meta.get("HasModel", "Provisório" if ch["HasPlaceholder"] else "Sim")
        rig = meta.get(
            "Rig",
            "R15 Provisório (PlaceholderColors)" if ch["HasPlaceholder"] else "R15 / Tripo",
        )
        anim = meta.get("Anim", "Não (Provisórias)")
        vfx_cutin = meta.get("VfxCutIn", "Pendente")
        shiny = meta.get("Shiny", "Sim (Paleta)" if ch["HasShinyPalette"] else "Sem Preset")
        notes = meta.get("Notes", "Atualizado automaticamente de Characters.luau")

        # Signature move lookup
        sig_name = "Pendente"
        sig_power: Any = "-"
        if ch["Prototype"]:
            sig_name = "Nenhum"
        else:
            sig_moves = [moves[mid] for mid in ch["MoveIds"] if mid in moves and moves[mid]["Signature"]]
            if sig_moves:
                sig_name = sig_moves[0]["Name"]
                sig_power = sig_moves[0]["Power"]
            elif cid in ("Kaen", "Raiko") and ch["MoveIds"]:
                first_m = moves.get(ch["MoveIds"][0])
                if first_m:
                    sig_name = f"Nenhum ({first_m['Name']})"
                    sig_power = first_m["Power"]

        codes = codes_by_char.get(cid, [])
        code_str = " / ".join(codes) if codes else "-"

        anime_name = ANIME_DISPLAY.get(ch["Anime"], ch["Anime"])
        rarity_name = RARITY_DISPLAY.get(ch["Rarity"], ch["Rarity"])

        p_def = passives.get(ch["Passive"])
        p_name = p_def["Name"] if p_def else "-"
        p_tier_str = PASSIVE_TIER_DISPLAY.get(p_def["Tier"], p_def["Tier"]) if p_def else "-"
        sp_def = passives.get(ch["SecretPassive"])
        sp_name = sp_def["Name"] if sp_def else "-"
        rec = awakening_recipes.get(cid)
        rec_summary = rec["Summary"] if rec else "-"

        row_vals = [
            cid,
            ch["Name"],
            anime_name,
            stage,
            rarity_name,
            ch["Class"],
            "Sim" if ch["Starter"] else "Não",
            has_model,
            rig,
            ch["HP"],
            ch["ATK"],
            ch["DEF"],
            ch["SPD"],
            f"=SUM(J{r_idx}:M{r_idx})",
            sig_name,
            sig_power,
            anim,
            vfx_cutin,
            shiny,
            code_str,
            p_name,
            p_tier_str,
            sp_name,
            rec_summary,
            notes,
        ]
        ws.append(row_vals)
        ws.row_dimensions[r_idx].height = 22

        for c_idx in range(1, len(headers) + 1):
            cell = ws.cell(r_idx, c_idx)
            cell.border = CELL_BORDER
            cell.font = BOLD_FONT if c_idx in (1, 2, 14, 21) else BASE_FONT
            if c_idx in (1, 2, 9, 15, 20, 21, 23, 24, 25):
                cell.alignment = Alignment(horizontal="left", vertical="center", wrap_text=(c_idx in (24, 25)))
            else:
                cell.alignment = Alignment(horizontal="center", vertical="center")

        # Color badges
        if anime_name in ANIME_FILL:
            ws.cell(r_idx, 3).fill = ANIME_FILL[anime_name]
        if stage in STAGE_FILL:
            ws.cell(r_idx, 4).fill = STAGE_FILL[stage]
        if rarity_name in RARITY_FILL:
            ws.cell(r_idx, 5).fill = RARITY_FILL[rarity_name]
        if ch["Class"] in CLASS_FILL:
            ws.cell(r_idx, 6).fill = CLASS_FILL[ch["Class"]]
        if ch["Starter"]:
            ws.cell(r_idx, 7).fill = GREEN
            ws.cell(r_idx, 7).font = BOLD_FONT
        ws.cell(r_idx, 8).fill = GREEN if has_model == "Sim" else YELLOW
        ws.cell(r_idx, 17).fill = GREEN if anim.startswith("Sim") else RED
        if vfx_cutin.startswith("Sim"):
            ws.cell(r_idx, 18).fill = GREEN
        elif "VFX Sim" in vfx_cutin or "Aura Sim" in vfx_cutin:
            ws.cell(r_idx, 18).fill = YELLOW
        else:
            ws.cell(r_idx, 18).fill = RED
        if shiny.startswith("Sim"):
            ws.cell(r_idx, 19).fill = GREEN
        elif shiny.startswith("Parcial"):
            ws.cell(r_idx, 19).fill = YELLOW
        else:
            ws.cell(r_idx, 19).fill = RED
        if p_def:
            ws.cell(r_idx, 22).fill = GOLD if p_def["Tier"] == "Unique" else BLUE
        if sp_def:
            ws.cell(r_idx, 23).fill = PURPLE
            ws.cell(r_idx, 23).font = BOLD_FONT
            ws.cell(r_idx, 24).fill = PURPLE

    col_widths_p = {
        "A": 14, "B": 16, "C": 16, "D": 19, "E": 12, "F": 13, "G": 9,
        "H": 12, "I": 34, "J": 7, "K": 7, "L": 7, "M": 7, "N": 12,
        "O": 25, "P": 16, "Q": 22, "R": 22, "S": 20, "T": 24,
        "U": 22, "V": 19, "W": 22, "X": 46, "Y": 52,
    }
    for col, w in col_widths_p.items():
        ws.column_dimensions[col].width = w
    ws.auto_filter.ref = f"A1:Y{len(chars) + 1}"

    # -----------------------------------------------------------------
    # ABA 2: Ataques (Catálogo completo e único de todos os ataques do jogo)
    # -----------------------------------------------------------------
    ws_a = wb.create_sheet("Ataques")
    ws_a.freeze_panes = "C2"

    # Mapeia quais personagens ativos usam cada ataque
    users_by_move: dict[str, list[str]] = {}
    for ch in chars:
        if ch["Prototype"]:
            continue
        for mid in ch["MoveIds"]:
            users_by_move.setdefault(mid, []).append(ch["Name"])

    sorted_moves = sorted(
        moves.values(),
        key=lambda mv: (
            ORIGIN_ORDER.get(mv["Origin"], 99),
            CLASS_ORDER.get(mv["Type"], 99),
            mv["LearnLevel"] if mv["LearnLevel"] is not None else 999,
            mv["Name"].lower(),
        ),
    )

    a_headers = [
        "ID",
        "Nome do Ataque",
        "Origem",
        "Classe",
        "Nível Sugerido",
        "Categoria",
        "Poder",
        "Precisão",
        "PP",
        "Prioridade",
        "Crítico",
        "Alvo (2x2)",
        "Efeito / Mecânica Especial",
        "Assinatura?",
        "Cut-In?",
        "Animação 3D",
        "VFX 3D",
        "Status de Dev",
        "Timing (C / R / I / Total)",
        "Qtd. Usuários",
        "Personagens que Usam",
    ]
    ws_a.append(a_headers)
    ws_a.row_dimensions[1].height = 26
    for c_idx in range(1, len(a_headers) + 1):
        cell = ws_a.cell(1, c_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = CELL_BORDER

    ORIGIN_FILL = {
        "Genérico de Classe": BLUE,
        "Genérico Universal": TEAL,
        "Assinatura": GOLD,
        "Exclusivo": PURPLE,
        "Clássico": SLATE,
        "Reserva (Sem PP)": GRAY,
    }
    DEV_MOVE_FILL = {
        "Implementado (100%)": GREEN,
        "Parcial": YELLOW,
        "Pendente (Anim/VFX)": ORANGE,
        "Fallback (Sem PP)": SLATE,
    }

    for r_idx, mv in enumerate(sorted_moves, start=2):
        users = users_by_move.get(mv["Id"], [])
        if mv["Hidden"]:
            users_str = "Todos (fallback sem PP)"
        elif users:
            users_str = ", ".join(users)
        else:
            users_str = "Disponível p/ Progressão" if mv["Generic"] else "Nenhum (não atribuído)"

        cat_pt = CATEGORY_DISPLAY.get(mv["Category"], mv["Category"])
        acc_display = f"{mv['Accuracy']}%" if isinstance(mv["Accuracy"], int) else mv["Accuracy"]
        lvl_display = f"Nv. {mv['LearnLevel']}" if mv["LearnLevel"] is not None else "-"
        prio_val = mv["Priority"]
        prio_display = f"+{prio_val}" if prio_val > 0 else str(prio_val)
        anim_display = f"Sim ({mv['AnimName']})" if mv["HasAnim"] else ("Não (Fallback)" if mv["Hidden"] else "Não (Padrão Classe)")
        vfx_display = f"Sim ({mv['VfxName']})" if mv["HasVfx"] else "Não"

        ws_a.append(
            [
                mv["Id"],
                mv["Name"],
                mv["Origin"],
                mv["Type"],
                lvl_display,
                cat_pt,
                mv["Power"],
                acc_display,
                mv["PP"],
                prio_display,
                mv["CritChance"],
                TARGET_DISPLAY.get(mv["Target"], mv["Target"]),
                mv["EffectDesc"],
                "Sim" if mv["Signature"] else "Não",
                "Sim" if mv["CutIn"] else "Não",
                anim_display,
                vfx_display,
                mv["DevStatus"],
                mv["TimingDesc"],
                len(users),
                users_str,
            ]
        )
        ws_a.row_dimensions[r_idx].height = 22
        for c_idx in range(1, len(a_headers) + 1):
            cell = ws_a.cell(r_idx, c_idx)
            cell.border = CELL_BORDER
            cell.font = BOLD_FONT if c_idx in (1, 2) else BASE_FONT
            cell.alignment = Alignment(
                horizontal="left" if c_idx in (1, 2, 13, 16, 17, 21) else "center",
                vertical="center",
                wrap_text=(c_idx in (13, 21)),
            )

        ws_a.cell(r_idx, 11).number_format = "0.00%"
        if prio_val > 0:
            ws_a.cell(r_idx, 10).fill = TEAL
            ws_a.cell(r_idx, 10).font = BOLD_FONT
        if mv["CritChance"] > 0.0625:
            ws_a.cell(r_idx, 11).fill = GOLD
            ws_a.cell(r_idx, 11).font = BOLD_FONT
        if mv["Origin"] in ORIGIN_FILL:
            ws_a.cell(r_idx, 3).fill = ORIGIN_FILL[mv["Origin"]]
        if mv["Type"] in CLASS_FILL:
            ws_a.cell(r_idx, 4).fill = CLASS_FILL[mv["Type"]]
        ws_a.cell(r_idx, 6).fill = RED if cat_pt == "Dano" else BLUE
        eff = mv["EffectDesc"]
        if eff.startswith("Buff:") or eff.startswith("Cura:") or eff.startswith("Purificação:"):
            ws_a.cell(r_idx, 13).fill = GREEN
        elif eff.startswith("Debuff:") or eff.startswith("Recuo:"):
            ws_a.cell(r_idx, 13).fill = RED
        elif eff.startswith("Status:") or eff.startswith("Hazard:"):
            ws_a.cell(r_idx, 13).fill = PURPLE
        elif eff.startswith("Proteção:") or eff.startswith("Campo") or eff.startswith("Limpeza:"):
            ws_a.cell(r_idx, 13).fill = TEAL
        elif eff.startswith("Dreno:") or eff.startswith("Rompe"):
            ws_a.cell(r_idx, 13).fill = GOLD
        if mv["Signature"]:
            ws_a.cell(r_idx, 14).fill = GOLD
            ws_a.cell(r_idx, 14).font = BOLD_FONT
        if mv["CutIn"]:
            ws_a.cell(r_idx, 15).fill = PURPLE
            ws_a.cell(r_idx, 15).font = BOLD_FONT
        ws_a.cell(r_idx, 16).fill = GREEN if mv["HasAnim"] else (SLATE if mv["Hidden"] else RED)
        ws_a.cell(r_idx, 17).fill = GREEN if mv["HasVfx"] else (SLATE if mv["Hidden"] else RED)
        if mv["DevStatus"] in DEV_MOVE_FILL:
            ws_a.cell(r_idx, 18).fill = DEV_MOVE_FILL[mv["DevStatus"]]

    col_widths_a = {
        "A": 23, "B": 26, "C": 21, "D": 13, "E": 14, "F": 11, "G": 9, "H": 13, "I": 7,
        "J": 11, "K": 11, "L": 16, "M": 46, "N": 12, "O": 10, "P": 24, "Q": 24, "R": 21,
        "S": 26, "T": 14, "U": 44,
    }
    for col, w in col_widths_a.items():
        ws_a.column_dimensions[col].width = w
    ws_a.auto_filter.ref = f"A1:U{len(sorted_moves) + 1}"

    # -----------------------------------------------------------------
    # ABA 3: Kit por Personagem (progressao Nv. 1 -> 50 de todos os personagens ativos)
    # -----------------------------------------------------------------
    ws_m = wb.create_sheet("Kit por Personagem")
    ws_m.freeze_panes = "E2"
    m_headers = [
        "Personagem",
        "Tag (Anime)",
        "Nível",
        "ID do Golpe",
        "Nome",
        "Classe",
        "Categoria",
        "Alvo (2x2)",
        "Poder",
        "Precisão",
        "PP",
        "Prioridade",
        "Crítico",
        "Efeito / Mecânica Especial",
        "Kit Genérico?",
        "Assinatura?",
        "Cut-In?",
        "Tem Anim?",
        "Tem VFX?",
    ]
    ws_m.append(m_headers)
    ws_m.row_dimensions[1].height = 25
    for c_idx in range(1, len(m_headers) + 1):
        cell = ws_m.cell(1, c_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = CELL_BORDER

    m_row = 1
    for ch in chars:
        if ch["Prototype"]:
            continue
        anime_name = ANIME_DISPLAY.get(ch["Anime"], ch["Anime"])
        for unlock_lv, mid in ch["Learnset"]:
            mv = moves.get(mid)
            if not mv:
                continue
            m_row += 1
            prio_val = mv["Priority"]
            prio_display = f"+{prio_val}" if prio_val > 0 else str(prio_val)
            ws_m.append(
                [
                    ch["Name"],
                    anime_name,
                    f"Nv. {unlock_lv}",
                    mv["Id"],
                    mv["Name"],
                    mv["Type"],
                    CATEGORY_DISPLAY.get(mv["Category"], mv["Category"]),
                    TARGET_DISPLAY.get(mv["Target"], mv["Target"]),
                    mv["Power"],
                    mv["Accuracy"],
                    mv["PP"],
                    prio_display,
                    mv["CritChance"],
                    mv["EffectDesc"],
                    "Sim" if mv["Generic"] else "Não",
                    "Sim" if mv["Signature"] else "Não",
                    "Sim" if mv["CutIn"] else "Não",
                    "Sim" if mv["HasAnim"] else "Não",
                    "Sim" if mv["HasVfx"] else "Não",
                ]
            )
            ws_m.row_dimensions[m_row].height = 20
            for c_idx in range(1, len(m_headers) + 1):
                cell = ws_m.cell(m_row, c_idx)
                cell.border = CELL_BORDER
                cell.font = BOLD_FONT if c_idx in (1, 3, 5) else BASE_FONT
                cell.alignment = Alignment(
                    horizontal="left" if c_idx in (1, 4, 5, 14) else "center",
                    vertical="center",
                )
            ws_m.cell(m_row, 13).number_format = "0.00%"
            if anime_name in ANIME_FILL:
                ws_m.cell(m_row, 2).fill = ANIME_FILL[anime_name]
            if unlock_lv >= 42:
                ws_m.cell(m_row, 3).fill = GOLD
            elif unlock_lv >= 28:
                ws_m.cell(m_row, 3).fill = PURPLE
            elif unlock_lv >= 12:
                ws_m.cell(m_row, 3).fill = BLUE
            else:
                ws_m.cell(m_row, 3).fill = SLATE
            if mv["Type"] in CLASS_FILL:
                ws_m.cell(m_row, 6).fill = CLASS_FILL[mv["Type"]]
            if prio_val > 0:
                ws_m.cell(m_row, 12).fill = TEAL
                ws_m.cell(m_row, 12).font = BOLD_FONT
            if mv["Signature"]:
                ws_m.cell(m_row, 16).fill = GOLD
                ws_m.cell(m_row, 16).font = BOLD_FONT
            if mv["CutIn"]:
                ws_m.cell(m_row, 17).fill = PURPLE
                ws_m.cell(m_row, 17).font = BOLD_FONT
            ws_m.cell(m_row, 18).fill = GREEN if mv["HasAnim"] else RED
            ws_m.cell(m_row, 19).fill = GREEN if mv["HasVfx"] else RED

    col_widths_m = {
        "A": 15, "B": 16, "C": 10, "D": 21, "E": 26, "F": 13, "G": 11, "H": 15,
        "I": 9, "J": 12, "K": 7, "L": 11, "M": 11, "N": 42, "O": 13, "P": 13, "Q": 10, "R": 11, "S": 11,
    }
    for col, w in col_widths_m.items():
        ws_m.column_dimensions[col].width = w
    ws_m.auto_filter.ref = f"A1:S{m_row}"

    # -----------------------------------------------------------------
    # ABA 4: Passivas (Catalogo completo de Passivas + Receitas de Despertar)
    # -----------------------------------------------------------------
    ws_ps = wb.create_sheet("Passivas")
    ws_ps.freeze_panes = "C2"

    users_by_passive: dict[str, list[str]] = {}
    for ch in chars:
        if ch["Prototype"]:
            continue
        if ch["Passive"]:
            users_by_passive.setdefault(ch["Passive"], []).append(ch["Name"])
        if ch["SecretPassive"]:
            users_by_passive.setdefault(ch["SecretPassive"], []).append(f"{ch['Name']} (Desperto)")

    sorted_passives = sorted(
        passives.values(),
        key=lambda p: (PASSIVE_TIER_ORDER.get(p["Tier"], 99), p["Name"].lower()),
    )

    ps_headers = [
        "ID",
        "Nome da Passiva",
        "Categoria",
        "Resumo do Efeito",
        "Descrição Completa em Batalha",
        "Qtd. Usuários",
        "Personagens que Usam",
        "Como Obter / Receita de Despertar",
    ]
    ws_ps.append(ps_headers)
    ws_ps.row_dimensions[1].height = 26
    for c_idx in range(1, len(ps_headers) + 1):
        cell = ws_ps.cell(1, c_idx)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = CELL_BORDER

    TIER_PASSIVE_FILL = {
        "Generic": BLUE,
        "Unique": GOLD,
        "Secret": PURPLE,
    }

    for r_idx, p in enumerate(sorted_passives, start=2):
        users = users_by_passive.get(p["Id"], [])
        if p["Tier"] == "Secret":
            rec = awakening_recipes.get(p["Owner"])
            how = f"Altar Secreto (Gruta NO): {rec['Summary']}" if rec else "Altar Secreto do Despertar (Nv. 35+)"
        elif p["Tier"] == "Unique":
            how = "Inata do Lendário"
        else:
            how = "Inata (Pool Genérico)"
        users_str = ", ".join(users) if users else "Disponível no Pool p/ futuros personagens"
        tier_label = PASSIVE_TIER_DISPLAY.get(p["Tier"], p["Tier"])
        ws_ps.append(
            [
                p["Id"],
                p["Name"],
                tier_label,
                p["Short"],
                p["Description"],
                len(users),
                users_str,
                how,
            ]
        )
        ws_ps.row_dimensions[r_idx].height = 28
        for c_idx in range(1, len(ps_headers) + 1):
            cell = ws_ps.cell(r_idx, c_idx)
            cell.border = CELL_BORDER
            cell.font = BOLD_FONT if c_idx in (1, 2) else BASE_FONT
            cell.alignment = Alignment(
                horizontal="center" if c_idx in (3, 6) else "left",
                vertical="center",
                wrap_text=(c_idx in (4, 5, 7, 8)),
            )
        if p["Tier"] in TIER_PASSIVE_FILL:
            ws_ps.cell(r_idx, 3).fill = TIER_PASSIVE_FILL[p["Tier"]]
            if p["Tier"] in ("Unique", "Secret"):
                ws_ps.cell(r_idx, 3).font = BOLD_FONT

    col_widths_ps = {
        "A": 22, "B": 24, "C": 21, "D": 40, "E": 56, "F": 13, "G": 34, "H": 50,
    }
    for col, w in col_widths_ps.items():
        ws_ps.column_dimensions[col].width = w
    ws_ps.auto_filter.ref = f"A1:H{len(sorted_passives) + 1}"

    # -----------------------------------------------------------------
    # ABA 5: Resumo (formulas dinamicas sobre Personagens, Ataques e Passivas)
    # -----------------------------------------------------------------
    ws_r = wb.create_sheet("Resumo")
    last_p = len(chars) + 1
    last_a = len(sorted_moves) + 1
    p_anime = f"Personagens!$C$2:$C${last_p}"
    p_stage = f"Personagens!$D$2:$D${last_p}"
    p_rar = f"Personagens!$E$2:$E${last_p}"
    p_cls = f"Personagens!$F$2:$F${last_p}"
    a_origin = f"Ataques!$C$2:$C${last_a}"
    a_cls = f"Ataques!$D$2:$D${last_a}"
    a_cat = f"Ataques!$F$2:$F${last_a}"
    a_sig = f"Ataques!$N$2:$N${last_a}"
    a_cutin = f"Ataques!$O$2:$O${last_a}"
    a_dev = f"Ataques!$R$2:$R${last_a}"

    def add_summary_table(start_row: int, title: str, col_label: str, items: list[str], col_ref: str, exclude_test: bool = True) -> int:
        ws_r.merge_cells(start_row=start_row, start_column=1, end_row=start_row, end_column=3)
        tcell = ws_r.cell(start_row, 1, title)
        tcell.fill = TITLE_FILL
        tcell.font = TITLE_FONT
        tcell.alignment = Alignment(horizontal="left", vertical="center")
        ws_r.row_dimensions[start_row].height = 24

        r = start_row + 1
        pct_header = "% do Elenco Ativo" if exclude_test else "% do Total"
        denom_cell = "$B$3" if exclude_test else "$B$5"
        for ci, h in enumerate([col_label, "Quantidade", pct_header], start=1):
            c = ws_r.cell(r, ci, h)
            c.fill = HEADER_FILL
            c.font = HEADER_FONT
            c.alignment = Alignment(horizontal="center" if ci > 1 else "left", vertical="center")
            c.border = CELL_BORDER
        ws_r.row_dimensions[r].height = 22

        first_data = r + 1
        for item in items:
            r += 1
            ws_r.cell(r, 1, item)
            if exclude_test:
                ws_r.cell(r, 2, f'=COUNTIFS({col_ref},"{item}",{p_stage},"<>Teste (Remover)")')
            else:
                ws_r.cell(r, 2, f'=COUNTIF({col_ref},"{item}")')
            ws_r.cell(r, 3, f'=IF({denom_cell}>0,B{r}/{denom_cell},0)')
            ws_r.cell(r, 3).number_format = "0.0%"
            for ci in range(1, 4):
                c = ws_r.cell(r, ci)
                c.border = CELL_BORDER
                c.font = BASE_FONT
                c.alignment = Alignment(horizontal="left" if ci == 1 else "center", vertical="center")
            ws_r.row_dimensions[r].height = 20

        r += 1
        ws_r.cell(r, 1, "TOTAL")
        ws_r.cell(r, 2, f"=SUM(B{first_data}:B{r-1})")
        ws_r.cell(r, 3, f"=SUM(C{first_data}:C{r-1})")
        ws_r.cell(r, 3).number_format = "0.0%"
        for ci in range(1, 4):
            c = ws_r.cell(r, ci)
            c.border = CELL_BORDER
            c.font = BOLD_FONT
            c.fill = SLATE
            c.alignment = Alignment(horizontal="left" if ci == 1 else "center", vertical="center")
        ws_r.row_dimensions[r].height = 22
        return r + 2

    # Top KPI block
    ws_r.merge_cells("A1:C1")
    k = ws_r["A1"]
    k.value = "RESUMO DO ELENCO — RobloxProjetoX"
    k.fill = TITLE_FILL
    k.font = TITLE_FONT
    k.alignment = Alignment(horizontal="left", vertical="center")
    ws_r.row_dimensions[1].height = 26

    for ci, h in enumerate(["Métrica", "Valor", "Observação"], start=1):
        c = ws_r.cell(2, ci, h)
        c.fill = HEADER_FILL
        c.font = HEADER_FONT
        c.alignment = Alignment(horizontal="center" if ci == 2 else "left", vertical="center")
        c.border = CELL_BORDER

    kpis = [
        ("Personagens Ativos no Jogo", f'=COUNTIF({p_stage},"<>Teste (Remover)")', "Exclui protótipos de teste (Prototype = true)"),
        ("Protótipos de Teste", f'=COUNTIF({p_stage},"Teste (Remover)")', "Remover antes da publicação"),
        ("Total de Linhas na Planilha", f"=COUNTA(Personagens!$A$2:$A${last_p})", "Ativos + Protótipos"),
        ("Personagens Concluídos (100%)", f'=COUNTIF({p_stage},"Concluído (100%)")', "Modelo 3D + Animações + VFX completos"),
        ("Com Modelo 3D Real no Jogo", f'=COUNTIFS(Personagens!$H$2:$H${last_p},"Sim",{p_stage},"<>Teste (Remover)")', "Prontos em ServerStorage/Characters"),
        ("Aguardando Modelo 3D (Provisório)", f'=COUNTIF(Personagens!$H$2:$H${last_p},"Provisório")', "Usando PlaceholderColors temporário"),
    ]
    for idx, (label, formula, obs) in enumerate(kpis, start=3):
        ws_r.cell(idx, 1, label)
        ws_r.cell(idx, 2, formula)
        ws_r.cell(idx, 3, obs)
        for ci in range(1, 4):
            c = ws_r.cell(idx, ci)
            c.border = CELL_BORDER
            c.font = BOLD_FONT if ci in (1, 2) else BASE_FONT
            c.alignment = Alignment(horizontal="center" if ci == 2 else "left", vertical="center")
        ws_r.row_dimensions[idx].height = 20

    next_row = 10
    next_row = add_summary_table(
        next_row,
        "POR ANIME (Elenco Ativo)",
        "Anime",
        ["One Piece", "Naruto", "Bleach", "Dragon Ball", "Jujutsu Kaisen", "Genérico"],
        p_anime,
        exclude_test=True,
    )
    next_row = add_summary_table(
        next_row,
        "POR RARIDADE (Elenco Ativo)",
        "Raridade",
        ["Comum", "Raro", "Épico", "Lendário"],
        p_rar,
        exclude_test=True,
    )
    next_row = add_summary_table(
        next_row,
        "POR CLASSE DE COMBATE (Elenco Ativo)",
        "Classe",
        ["Espadachim", "Lutador", "Mago", "Atirador"],
        p_cls,
        exclude_test=True,
    )
    next_row = add_summary_table(
        next_row,
        "POR ESTÁGIO DE DESENVOLVIMENTO (Todos)",
        "Estágio",
        ["Concluído (100%)", "Em Andamento", "Modelo Provisório", "Protótipo Base", "Teste (Remover)"],
        p_stage,
        exclude_test=False,
    )

    # Bloco dinamico de Resumo dos Ataques (colunas E:G ao lado dos personagens)
    ws_r.merge_cells("E1:G1")
    ka = ws_r["E1"]
    ka.value = "RESUMO DE ATAQUES — RobloxProjetoX"
    ka.fill = TITLE_FILL
    ka.font = TITLE_FONT
    ka.alignment = Alignment(horizontal="left", vertical="center")

    for offset, h in enumerate(["Métrica", "Valor", "Observação"]):
        c = ws_r.cell(2, 5 + offset, h)
        c.fill = HEADER_FILL
        c.font = HEADER_FONT
        c.alignment = Alignment(horizontal="center" if offset == 1 else "left", vertical="center")
        c.border = CELL_BORDER

    attack_kpis = [
        ("Total de Ataques no Jogo", f"=COUNTA(Ataques!$A$2:$A${last_a})", "Todos os ataques de Moves.luau"),
        ("Ataques Implementados (100%)", f'=COUNTIF({a_dev},"Implementado (100%)")', "Com Animação 3D e VFX próprios"),
        ("Ataques Pendentes (Anim/VFX)", f'=COUNTIF({a_dev},"Pendente (Anim/VFX)")', "Usam animação padrão da classe"),
        ("Técnicas Assinatura", f'=COUNTIF({a_sig},"Sim")', "Golpes assinatura exclusivos"),
        ("Ataques com Cut-In", f'=COUNTIF({a_cutin},"Sim")', "Possuem cena cinematográfica"),
        ("Ataques de Dano vs Status", f'=COUNTIF({a_cat},"Dano")&" Dano / "&COUNTIF({a_cat},"Status")&" Status"', "Distribuição de categorias"),
    ]
    for idx, (label, formula, obs) in enumerate(attack_kpis, start=3):
        ws_r.cell(idx, 5, label)
        ws_r.cell(idx, 6, formula)
        ws_r.cell(idx, 7, obs)
        for ci in (5, 6, 7):
            c = ws_r.cell(idx, ci)
            c.border = CELL_BORDER
            c.font = BOLD_FONT if ci in (5, 6) else BASE_FONT
            c.alignment = Alignment(horizontal="center" if ci == 6 else "left", vertical="center")

    def add_attack_summary_table(start_row: int, title: str, col_label: str, items: list[str], col_ref: str) -> int:
        ws_r.merge_cells(start_row=start_row, start_column=5, end_row=start_row, end_column=7)
        tcell = ws_r.cell(start_row, 5, title)
        tcell.fill = TITLE_FILL
        tcell.font = TITLE_FONT
        tcell.alignment = Alignment(horizontal="left", vertical="center")
        r = start_row + 1
        for offset, h in enumerate([col_label, "Quantidade", "% do Total"]):
            c = ws_r.cell(r, 5 + offset, h)
            c.fill = HEADER_FILL
            c.font = HEADER_FONT
            c.alignment = Alignment(horizontal="center" if offset > 0 else "left", vertical="center")
            c.border = CELL_BORDER
        first_data = r + 1
        for item in items:
            r += 1
            ws_r.cell(r, 5, item)
            ws_r.cell(r, 6, f'=COUNTIF({col_ref},"{item}")')
            ws_r.cell(r, 7, f"=IF($F$3>0,F{r}/$F$3,0)")
            ws_r.cell(r, 7).number_format = "0.0%"
            for ci in (5, 6, 7):
                c = ws_r.cell(r, ci)
                c.border = CELL_BORDER
                c.font = BASE_FONT
                c.alignment = Alignment(horizontal="left" if ci == 5 else "center", vertical="center")
        r += 1
        ws_r.cell(r, 5, "TOTAL")
        ws_r.cell(r, 6, f"=SUM(F{first_data}:F{r-1})")
        ws_r.cell(r, 7, f"=SUM(G{first_data}:G{r-1})")
        ws_r.cell(r, 7).number_format = "0.0%"
        for ci in (5, 6, 7):
            c = ws_r.cell(r, ci)
            c.border = CELL_BORDER
            c.font = BOLD_FONT
            c.fill = SLATE
            c.alignment = Alignment(horizontal="left" if ci == 5 else "center", vertical="center")
        return r + 2

    a_row = 10
    a_row = add_attack_summary_table(
        a_row,
        "ATAQUES POR ORIGEM",
        "Origem",
        ["Genérico de Classe", "Genérico Universal", "Assinatura", "Exclusivo", "Clássico", "Reserva (Sem PP)"],
        a_origin,
    )
    a_row = add_attack_summary_table(
        a_row,
        "ATAQUES POR CLASSE",
        "Classe",
        ["Espadachim", "Lutador", "Mago", "Atirador", "Universal"],
        a_cls,
    )
    a_row = add_attack_summary_table(
        a_row,
        "ATAQUES POR STATUS DE DEV",
        "Status",
        ["Implementado (100%)", "Parcial", "Pendente (Anim/VFX)", "Fallback (Sem PP)"],
        a_dev,
    )

    last_ps = len(sorted_passives) + 1
    ps_cat = f"Passivas!$C$2:$C${last_ps}"
    ws_r.merge_cells(start_row=a_row, start_column=5, end_row=a_row, end_column=7)
    t_ps = ws_r.cell(a_row, 5, "RESUMO DE PASSIVAS E DESPERTAR")
    t_ps.fill = TITLE_FILL
    t_ps.font = TITLE_FONT
    t_ps.alignment = Alignment(horizontal="left", vertical="center")
    r_ps = a_row + 1
    for offset, h in enumerate(["Categoria de Passiva", "Quantidade", "Regra"]):
        c = ws_r.cell(r_ps, 5 + offset, h)
        c.fill = HEADER_FILL
        c.font = HEADER_FONT
        c.alignment = Alignment(horizontal="center" if offset == 1 else "left", vertical="center")
        c.border = CELL_BORDER
    ps_rows = [
        ("Comum (Genérica)", f'=COUNTIF({ps_cat},"Comum (Genérica)")', "Pool reutilizável (Comuns, Raros e Épicos base)"),
        ("Única (Lendário)", f'=COUNTIF({ps_cat},"Única (Lendário)")', "Exclusiva de cada Lendário"),
        ("Secreta (Despertar)", f'=COUNTIF({ps_cat},"Secreta (Despertar)")', "Altar Secreto Nv. 35+ (+10% Stats + Aura)"),
    ]
    first_ps_r = r_ps + 1
    for label, form, rule_txt in ps_rows:
        r_ps += 1
        ws_r.cell(r_ps, 5, label)
        ws_r.cell(r_ps, 6, form)
        ws_r.cell(r_ps, 7, rule_txt)
        for ci in (5, 6, 7):
            c = ws_r.cell(r_ps, ci)
            c.border = CELL_BORDER
            c.font = BASE_FONT
            c.alignment = Alignment(horizontal="center" if ci == 6 else "left", vertical="center")
    r_ps += 1
    ws_r.cell(r_ps, 5, "TOTAL PASSIVAS")
    ws_r.cell(r_ps, 6, f"=SUM(F{first_ps_r}:F{r_ps-1})")
    ws_r.cell(r_ps, 7, "100% integradas ao motor 1x1 e 2x2")
    for ci in (5, 6, 7):
        c = ws_r.cell(r_ps, ci)
        c.border = CELL_BORDER
        c.font = BOLD_FONT
        c.fill = SLATE
        c.alignment = Alignment(horizontal="center" if ci == 6 else "left", vertical="center")

    ws_r.column_dimensions["A"].width = 34
    ws_r.column_dimensions["B"].width = 14
    ws_r.column_dimensions["C"].width = 44
    ws_r.column_dimensions["D"].width = 4
    ws_r.column_dimensions["E"].width = 32
    ws_r.column_dimensions["F"].width = 16
    ws_r.column_dimensions["G"].width = 38

    return wb


def main() -> None:
    moves, class_defaults = parse_moves()
    passives = parse_passives()
    _, awakening_recipes = parse_awakening()
    codes_by_char = parse_codes()
    chars = parse_characters(class_defaults)
    wb = build_workbook(chars, moves, codes_by_char, passives, awakening_recipes)

    OUT_BLENDER.parent.mkdir(parents=True, exist_ok=True)
    wb.save(OUT_BLENDER)
    root_synced = True
    try:
        shutil.copy2(OUT_BLENDER, OUT_ROOT)
    except PermissionError:
        root_synced = False

    active = [c for c in chars if not c["Prototype"]]
    protos = [c for c in chars if c["Prototype"]]
    print(
        f"Planilha atualizada com sucesso: {len(active)} personagens ativos + {len(protos)} prototipos "
        f"(total {len(chars)} linhas) | {wb['Ataques'].max_row - 1} ataques unicos | "
        f"{wb['Passivas'].max_row - 1} passivas | "
        f"{wb['Kit por Personagem'].max_row - 1} vinculos kit por personagem."
    )
    print(f"  - {OUT_BLENDER}")
    if root_synced:
        print(f"  - {OUT_ROOT}")
    else:
        print(f"  ! AVISO: {OUT_ROOT} esta aberto no Excel; feche o arquivo e rode o script novamente para sincronizar a copia da raiz.")


if __name__ == "__main__":
    main()
