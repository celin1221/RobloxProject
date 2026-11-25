#!/usr/bin/env python3
"""Synchronize scripts between local `src/` and the open Roblox Studio Place via MCP.

Commands:
    python scripts/sync_studio.py status   # Compare local src/ vs Studio DataModel
    python scripts/sync_studio.py push     # Push all local src/ scripts into Studio
    python scripts/sync_studio.py test     # Run headless Luau smoke tests inside Studio
"""
from __future__ import annotations

import argparse
import base64
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "roblox-ai-skills-main" / "skills" / "create-roblox-game" / "scripts"))
import studio_mcp  # type: ignore


B64_DECODE_LUAU = """
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64lookup = {}
for i = 1, #b64chars do
	b64lookup[string.byte(b64chars, i)] = i - 1
end
local function b64decode(data)
	data = string.gsub(data, "[^" .. b64chars .. "=]", "")
	local out = {}
	local n = #data
	for i = 1, n, 4 do
		local a = b64lookup[string.byte(data, i)] or 0
		local b = b64lookup[string.byte(data, i + 1)] or 0
		local c = b64lookup[string.byte(data, i + 2)] or 0
		local d = b64lookup[string.byte(data, i + 3)] or 0
		local num = a * 262144 + b * 4096 + c * 64 + d
		local c1 = math.floor(num / 65536) % 256
		local c2 = math.floor(num / 256) % 256
		local c3 = num % 256
		table.insert(out, string.char(c1))
		if string.sub(data, i + 2, i + 2) ~= "=" then
			table.insert(out, string.char(c2))
		end
		if string.sub(data, i + 3, i + 3) ~= "=" then
			table.insert(out, string.char(c3))
		end
	end
	return table.concat(out)
end
"""


def disk_to_studio(rel: Path) -> tuple[str, str, str]:
    """Return (studio_parent_path, instance_name, class_name) for a file under src/."""
    parts = list(rel.parts)
    filename = parts[-1]
    if filename.endswith(".server.luau"):
        name = filename[:-12]
        cls = "Script"
    elif filename.endswith(".client.luau"):
        name = filename[:-12]
        cls = "LocalScript"
    elif filename.endswith(".luau"):
        name = filename[:-5]
        cls = "ModuleScript"
    else:
        raise ValueError(f"Unknown extension: {rel}")

    root_group = parts[0]
    sub = parts[1:-1]

    if root_group == "shared":
        parent = "/".join(["ReplicatedStorage"] + sub)
    elif root_group == "server":
        parent = "/".join(["ServerScriptService"] + sub)
    elif root_group == "server_storage":
        parent = "/".join(["ServerStorage"] + sub)
    elif root_group == "client" and sub and sub[0] == "Gui":
        parent = "/".join(["StarterGui"] + sub[1:])
    elif root_group == "client" and sub and sub[0] == "PlayerScripts":
        parent = "/".join(["StarterPlayer", "StarterPlayerScripts"] + sub[1:])
    else:
        raise ValueError(f"Unmapped src path: {rel}")

    return parent, name, cls


def iter_local_scripts() -> list[tuple[Path, str, str, str]]:
    src_root = REPO / "src"
    items = []
    for f in sorted(src_root.rglob("*.luau")):
        rel = f.relative_to(src_root)
        parent, name, cls = disk_to_studio(rel)
        items.append((f, parent, name, cls))
    return items


def cmd_push(c: studio_mcp.Client, sid: str) -> int:
    items = iter_local_scripts()
    print(f"Pushing {len(items)} scripts from src/ to Studio...")
    for f, parent, name, cls in items:
        source_bytes = f.read_text(encoding="utf-8").encode("utf-8")
        b64 = base64.b64encode(source_bytes).decode("ascii")
        code = B64_DECODE_LUAU + f"""
local targetSource = b64decode("{b64}")
local parts = string.split({json.dumps(parent)}, "/")
local cur = game:GetService(parts[1])
for i = 2, #parts do
    local nxt = cur:FindFirstChild(parts[i])
    if not nxt then
        nxt = Instance.new("Folder")
        nxt.Name = parts[i]
        nxt.Parent = cur
    end
    cur = nxt
end
local inst = cur:FindFirstChild({json.dumps(name)})
if not inst then
    inst = Instance.new({json.dumps(cls)})
    inst.Name = {json.dumps(name)}
    inst.Parent = cur
end
if inst.Source ~= targetSource then
    inst.Source = targetSource
    return "UPDATED"
end
return "UNCHANGED"
"""
        ok, res = c.tool("execute_luau", {"code": code, "datamodel_type": "Edit", "studio_id": sid})
        if not ok:
            print(f"  ERROR {parent}/{name}: {res}")
            return 1
        if res.strip() == "UPDATED":
            print(f"  updated {parent}/{name}")
    print("Push complete.")
    return 0


def cmd_status(c: studio_mcp.Client, sid: str) -> int:
    items = iter_local_scripts()
    drifted = 0
    for f, parent, name, _ in items:
        source_bytes = f.read_text(encoding="utf-8").encode("utf-8")
        b64 = base64.b64encode(source_bytes).decode("ascii")
        code = B64_DECODE_LUAU + f"""
local targetSource = b64decode("{b64}")
local parts = string.split({json.dumps(parent)}, "/")
local cur = game:GetService(parts[1])
for i = 2, #parts do
    cur = cur and cur:FindFirstChild(parts[i])
end
local inst = cur and cur:FindFirstChild({json.dumps(name)})
if not inst then return "MISSING_IN_STUDIO" end
if inst.Source ~= targetSource then return "MODIFIED" end
return "OK"
"""
        ok, res = c.tool("execute_luau", {"code": code, "datamodel_type": "Edit", "studio_id": sid})
        status = res.strip() if ok else f"ERROR: {res}"
        if status != "OK":
            print(f"  {status:18s} {f.relative_to(REPO)} <-> {parent}/{name}")
            drifted += 1
    if drifted == 0:
        print(f"All {len(items)} scripts in src/ are 100% in sync with Roblox Studio.")
    else:
        print(f"{drifted} script(s) out of sync.")
    return 0 if drifted == 0 else 1


def cmd_test(c: studio_mcp.Client, sid: str) -> int:
    code = """
local rs = game:GetService("ReplicatedStorage")
local oldSandbox = rs:FindFirstChild("_TestSandbox")
if oldSandbox then oldSandbox:Destroy() end

local sandbox = Instance.new("Folder")
sandbox.Name = "_TestSandbox"
sandbox.Parent = rs

local ok, res = pcall(function()
    local dataClone = rs:WaitForChild("Data"):Clone()
    dataClone.Parent = sandbox
    local coreClone = rs:WaitForChild("Core"):Clone()
    coreClone.Parent = sandbox
    for _, child in ipairs(coreClone:GetChildren()) do
        if child:IsA("ModuleScript") then
            child.Source = child.Source
                :gsub('ReplicatedStorage:WaitForChild%("Data"%)', 'script.Parent.Parent:WaitForChild("Data")')
                :gsub('game:GetService%("ReplicatedStorage"%):WaitForChild%("Data"%)', 'script.Parent.Parent:WaitForChild("Data")')
        end
    end

    local BattleEngine = require(coreClone:WaitForChild("BattleEngine"))
    local DamageCalc = require(coreClone:WaitForChild("DamageCalc"))
    local Moves = require(dataClone:WaitForChild("Moves"))
    local TypeChart = require(dataClone:WaitForChild("TypeChart"))
    local Characters = require(dataClone:WaitForChild("Characters"))
    local Gyms = require(dataClone:WaitForChild("Gyms"))
    local Genetics = require(dataClone:WaitForChild("Genetics"))
    local Progression = require(dataClone:WaitForChild("Progression"))
    local Base = require(dataClone:WaitForChild("Base"))
    local StarterTrack = require(dataClone:WaitForChild("StarterTrack"))
    local PvPRank = require(dataClone:WaitForChild("PvPRank"))
    local Refuge = require(dataClone:WaitForChild("Refuge"))
    local AccountLevel = require(dataClone:WaitForChild("AccountLevel"))
    local Summon = require(dataClone:WaitForChild("Summon"))
    local Tower = require(dataClone:WaitForChild("Tower"))
    local Benefits = require(dataClone:WaitForChild("Benefits"))
    local Retention = require(dataClone:WaitForChild("Retention"))
    local Passives = require(dataClone:WaitForChild("Passives"))
    local Awakening = require(dataClone:WaitForChild("Awakening"))

-- Test 1: GDD Section 5 Damage Conference (Kaen Corte Flamejante on Raiko at Lv 10 = 12 to 14 non-crit)
local b = BattleEngine.New({
    Player = { Team = { { CharacterId = "Kaen", Level = 10 } } },
    Enemy = { Team = { { CharacterId = "Raiko", Level = 10 } }, AI = "Medio" },
    Mode = "Tower",
    Seed = 100,
})
local kaen = b:Active("Player")
local raiko = b:Active("Enemy")
local corte = Moves.Get("CorteFlamejante")
for s = 1, 50 do
    local res = DamageCalc.Compute(kaen, raiko, corte, Random.new(s))
    if not res.Crit then
        assert(res.Damage >= 12 and res.Damage <= 14, "Expected 12..14 damage, got " .. tostring(res.Damage))
    end
end

-- Test 2: Full 1x1 battle simulation finishes
local turns = 0
while b.State ~= "Ended" and turns < 20 do
    turns += 1
    b:ResolveTurn({ Kind = "Move", Index = 1 })
end
assert(b.State == "Ended", "1x1 battle did not end")

-- Test 3: 2x2 Spread multiplier (0.75x with 2 targets, 1.0x with 1 target)
local b2 = BattleEngine.New({
    Player = { Team = {
        { CharacterId = "Kaen", Level = 20, Moves = { "Investida", "BrasaViva", "PosturaDaLamina", "CorteFlamejante" } },
        { CharacterId = "Yomogi", Level = 20, Moves = { "Arranhao", "SementeToxica", "CascaDeCarvalho", "GaiolaDeEspinhos" } },
        { CharacterId = "Raiko", Level = 20 },
        { CharacterId = "San", Level = 20 },
    } },
    Enemy = { Team = {
        { CharacterId = "Raiko", Level = 20, Moves = { "SocoDireto", "PunhoDeMare", "Estatica", "Descarga" } },
        { CharacterId = "Yomogi", Level = 20, Moves = { "Arranhao", "SementeToxica", "CascaDeCarvalho", "GaiolaDeEspinhos" } },
        { CharacterId = "Kaen", Level = 20 },
    }, AI = "Medio" },
    Format = "2x2",
    Mode = "PvP",
    EnemyHuman = true,
    Seed = 2026,
})
assert(b2:IsDouble() and b2.Format == "2x2" and b2.SlotsPerSide == 2, "Expected 2x2 format")
-- Verify duplicate switch rejected
local okDup = b2:ValidateAction("Player", { Kind = "Double", Actions = {
    { FieldSlot = 1, Kind = "Switch", Index = 3 },
    { FieldSlot = 2, Kind = "Switch", Index = 3 },
} })
assert(not okDup, "Duplicate switch into same bench member should be rejected")

-- Spread move (BrasaViva = move 2, Target = AllEnemies) hits BOTH enemies with Spread = 0.75
local evSpread = b2:ResolveTurn(
    { Kind = "Double", Actions = {
        { FieldSlot = 1, Kind = "Move", Index = 2 },
        { FieldSlot = 2, Kind = "Move", Index = 3 },
    } },
    { Kind = "Double", Actions = {
        { FieldSlot = 1, Kind = "Move", Index = 1, TargetSide = "Enemy", TargetSlot = 2 },
        { FieldSlot = 2, Kind = "Move", Index = 3 },
    } }
)
local spreadHits = 0
for _, ev in ipairs(evSpread) do
    if ev.Kind == "Damage" and ev.Side == "Enemy" and ev.Spread == 0.75 then
        spreadHits += 1
    end
end
assert(spreadHits == 2, "Expected BrasaViva spread move to hit 2 enemies at 0.75x, got " .. tostring(spreadHits))

-- Test 4: 2x2 Mid-turn Redirection when chosen Enemy Slot 1 faints before Slot 2 acts
local bRedir = BattleEngine.New({
    Player = { Team = {
        { CharacterId = "San", Level = 50, Moves = { "Kamehameha", "GenkiDama", "ComboMarcial", "CargaDeKi" } },
        { CharacterId = "Kaen", Level = 40, Moves = { "CorteBasico", "BrasaViva", "PosturaDaLamina", "CorteFlamejante" } },
    } },
    Enemy = { Team = {
        { CharacterId = "Raiko", Level = 5 },
        { CharacterId = "Yomogi", Level = 50, Moves = { "Arranhao", "SementeToxica", "CascaDeCarvalho", "GaiolaDeEspinhos" } },
    }, AI = "Facil" },
    Format = "2x2",
    Mode = "PvP",
    EnemyHuman = true,
    Seed = 77,
})
local evRedir = bRedir:ResolveTurn(
    { Kind = "Double", Actions = {
        { FieldSlot = 1, Kind = "Move", Index = 1, TargetSide = "Enemy", TargetSlot = 1 },
        { FieldSlot = 2, Kind = "Move", Index = 4, TargetSide = "Enemy", TargetSlot = 1 }, -- CorteFlamejante (Lv40)
    } },
    { Kind = "Double", Actions = {
        { FieldSlot = 1, Kind = "Move", Index = 1, TargetSide = "Enemy", TargetSlot = 1 },
        { FieldSlot = 2, Kind = "Move", Index = 3 }, -- CascaDeCarvalho
    } }
)
local hitSlot1, hitSlot2, clearedSlot1 = false, false, false
for _, ev in ipairs(evRedir) do
    if ev.Kind == "Damage" and ev.Side == "Enemy" and ev.FieldSlot == 1 then hitSlot1 = true end
    if ev.Kind == "Damage" and ev.Side == "Enemy" and ev.FieldSlot == 2 then hitSlot2 = true end
    if ev.Kind == "ClearSlot" and ev.Side == "Enemy" and ev.FieldSlot == 1 then clearedSlot1 = true end
end
assert(hitSlot1 and hitSlot2, "Expected Slot 2 attack to redirect to Enemy Slot 2 after Enemy Slot 1 fainted")
assert(clearedSlot1, "Expected ClearSlot for Enemy Slot 1 when bench is empty (2v1 continuation)")
-- Verify Snapshot has dense ActiveSlots (0 for cleared slot, no sparse-array hole!)
local snapRedir = bRedir:Snapshot("Player")
assert(snapRedir.Enemy.ActiveSlots[1] == 0 and snapRedir.Enemy.ActiveSlots[2] == 2, "Expected dense ActiveSlots {0, 2}")
-- Now Enemy has only 1 active left: spread move must apply Spread = 1.0 (not 0.75!)
local evSingleSpread = bRedir:ResolveTurn(
    { Kind = "Double", Actions = {
        { FieldSlot = 1, Kind = "Move", Index = 2 }, -- GenkiDama (AllEnemies)
        { FieldSlot = 2, Kind = "Move", Index = 3 }, -- PosturaDaLamina
    } },
    { Kind = "Double", Actions = {
        { FieldSlot = 2, Kind = "Move", Index = 3 }, -- CascaDeCarvalho
    } }
)
local singleSpreadOk = false
for _, ev in ipairs(evSingleSpread) do
    if ev.Kind == "Damage" and ev.Side == "Enemy" and ev.FieldSlot == 2 then
        assert(ev.Spread == 1, "Spread move against 1 remaining target must use 1.0x, got " .. tostring(ev.Spread))
        singleSpreadOk = true
    end
end
assert(singleSpreadOk or bRedir.State == "Ended", "Expected single-target spread check")

-- Test 5: 2x2 Double Faint + Double Replacement + Full PvP Auto-Simulation
local bDoubleRep = BattleEngine.New({
    Player = { Team = {
        { CharacterId = "Kaen", Level = 5 },
        { CharacterId = "Raiko", Level = 5 },
        { CharacterId = "San", Level = 50 },
        { CharacterId = "Setero", Level = 50 },
    } },
    Enemy = { Team = {
        { CharacterId = "Raiko", Level = 50, Moves = { "SocoDireto", "PunhoDeMare", "Estatica", "Descarga" } },
        { CharacterId = "San", Level = 50, Moves = { "Kamehameha", "GenkiDama", "ComboMarcial", "CargaDeKi" } },
        { CharacterId = "Yomogi", Level = 50 },
    } },
    Format = "2x2",
    Mode = "PvP",
    EnemyHuman = true,
    Seed = 999,
})
bDoubleRep:ResolveTurn(
    { Kind = "Double", Actions = {
        { FieldSlot = 1, Kind = "Move", Index = 3 }, -- PosturaDaLamina (Lv5 Kaen has 3 moves)
        { FieldSlot = 2, Kind = "Move", Index = 1, TargetSide = "Enemy", TargetSlot = 1 },
    } },
    { Kind = "Double", Actions = {
        { FieldSlot = 1, Kind = "Move", Index = 4 }, -- Descarga (100% Acc, AllEnemies Lv50 vs Lv5 -> deterministic double KO!)
        { FieldSlot = 2, Kind = "Move", Index = 4 }, -- CargaDeKi
    } }
)
assert(bDoubleRep.State == "WaitingForReplacement", "Expected WaitingForReplacement after double KO, got " .. tostring(bDoubleRep.State))
assert(bDoubleRep.PendingReplace.Player and #bDoubleRep.PendingReplace.Player == 2, "Expected 2 pending replace slots")
local snapRep = bDoubleRep:Snapshot("Player")
assert(#snapRep.PendingReplaceSlots == 2, "Expected 2 PendingReplaceSlots in Snapshot")
local okBadRep = bDoubleRep:ValidateAction("Player", { Kind = "Replace", Replacements = { { FieldSlot = 1, Index = 3 }, { FieldSlot = 2, Index = 3 } } })
assert(not okBadRep, "Duplicate replacement index should be rejected")
bDoubleRep:ResolveReplacement("Player", { { FieldSlot = 1, Index = 3 }, { FieldSlot = 2, Index = 4 } })
assert(bDoubleRep.State == "WaitingForInput", "Expected WaitingForInput after double replacement")

-- Complete full 2x2 PvP battle using AutoAction / AutoReplacement
local simTurns = 0
while bDoubleRep.State ~= "Ended" and simTurns < 30 do
    simTurns += 1
    if bDoubleRep.State == "WaitingForReplacement" then
        for _, side in ipairs({ "Player", "Enemy" }) do
            if bDoubleRep.PendingReplace[side] then
                bDoubleRep:ResolveReplacement(side, bDoubleRep:AutoReplacement(side))
            end
        end
    else
        bDoubleRep:ResolveTurn(bDoubleRep:AutoAction("Player"), bDoubleRep:AutoAction("Enemy"))
    end
end
assert(bDoubleRep.State == "Ended", "Full 2x2 PvP simulation did not finish")

-- Test 6: Combat Classes (1x always, generic class kits), 3 Starters (Luffy/Naruto/Ichigo), Bleach Roster, Gyms & Practice 2x2
for _, c1 in ipairs(TypeChart.Classes) do
    for _, c2 in ipairs(TypeChart.Classes) do
        assert(TypeChart.Multiplier(c1, c2) == 1, "Expected 1x class multiplier for " .. c1 .. " vs " .. c2)
    end
end
local starters = Characters.Starters()
assert(#starters == 3, "Expected 3 starters, got " .. tostring(#starters))
local starterSet = {}
for _, sid in ipairs(starters) do starterSet[sid] = true end
assert(starterSet.Luffy and starterSet.Naruto and starterSet.Ichigo, "Expected Starters = Luffy, Naruto, Ichigo")
for _, bid in ipairs({ "Chad", "Uryu", "Rukia", "Renji", "Ichigo", "Byakuya" }) do
    local def = Characters.Get(bid)
    assert(def and def.Anime == "Bleach", "Missing Bleach character " .. bid)
    assert(def.Learnset and #def.Learnset >= 4, "Expected class kit learnset on " .. bid)
end
assert(#Gyms.Order == 3, "Expected 3 Gyms")
for _, gid in ipairs(Gyms.Order) do
    local g = Gyms.Get(gid)
    assert(g and #g.Stages == 3, "Expected 3 stages in Gym " .. gid)
    assert(#g.Stages[1].Team == 2 and #g.Stages[2].Team == 4 and #g.Stages[3].Team == 6, "Expected 2->4->6 stages in Gym " .. gid)
    assert(Gyms.ForBanner(g.BannerId) == g, "Expected ForBanner mapping for " .. gid)
end
local bPractice = BattleEngine.New({
    Player = { Team = { { CharacterId = "Ichigo", Level = 50 }, { CharacterId = "Luffy", Level = 50 } } },
    Enemy = { Team = { { CharacterId = "Naruto", Level = 50 }, { CharacterId = "Byakuya", Level = 50 } }, AI = "Medio" },
    Format = "2x2",
    Mode = "Practice",
    CanFlee = true,
    Seed = 42,
})
bPractice:ResolveTurn({ Kind = "Flee" })
assert(bPractice.State == "Ended" and bPractice.EndReason == "Fled", "Expected free flee in Practice 2x2 mode")

-- Test 7: Progression Rebalance (Scaled NPC Genetics, StarterKit, Bench XP, Live Base Gold/s, StarterTrack, PvPRank, Refuge GymBadges)
local gEasy, tEasy = Genetics.TowerEnemyPreset("Facil")
local gInf, tInf = Genetics.TowerEnemyPreset("Infinito")
assert(gEasy.HP == 25 and tEasy.HP == 0 and gInf.HP == 70 and tInf.HP == 100, "Expected scaled Tower presets")
local gGym1, tGym1 = Genetics.GymEnemyPreset(1)
assert(gGym1.HP == 35 and tGym1.HP == 15, "Expected Gym 1 preset 35/15")
assert(Progression.StarterKit and Progression.StarterKit.Gold == 600 and Progression.BenchXpRatio == 0.40, "Expected StarterKit & BenchXpRatio")
local gps1 = Base.MemberGoldPerSecond({ Level = 1, Stars = 0 }, "Epico", false)
local gps50 = Base.MemberGoldPerSecond({ Level = 50, Stars = 2 }, "Epico", false)
assert(gps1 == 0.55 and gps50 > gps1 * 2.5, "Expected Base Gold/s scaling with Level & Stars")
assert(#StarterTrack.Steps == 7, "Expected 7 StarterTrack steps")
local st0, h0, n0, d0 = StarterTrack.CurrentStep({ StarterTrack = { Claimed = {} }, Base = { Active = {} } })
assert(st0 and st0.Id == "BaseActive" and h0 == 0 and n0 == 1 and not d0, "Expected first StarterTrack step BaseActive")
local gain2x2, loss2x2 = PvPRank.Delta(1000, 1000, "2x2")
local gain1x1, _ = PvPRank.Delta(1000, 1000, "1x1")
assert(gain2x2 > gain1x1 and loss2x2 >= 6 and PvPRank.TierFor(1250).Id == "Ouro", "Expected PvPRank 2x2 Elo & Tiers")
assert(Refuge.Upgrades[3].Gems == 50 and Refuge.GoldPerLevel == 25 and Refuge.Levels[1].Interval == 90, "Expected rebalanced Forge gems, GoldPerLevel & agile Lv1 Refuge")

-- Test 8: AccountLevel XP curve, milestones, BaseCollect anti-exploit & unclaimed count
assert(AccountLevel.XpToNext(1) == 129 and AccountLevel.XpToNext(2) == 176, "Expected AccountLevel XpToNext(1)=129, (2)=176")
assert(AccountLevel.XpToNext(31) > AccountLevel.XpToNext(30), "Expected monotonic AccountLevel XP curve")
assert(AccountLevel.XpSources.BaseCollectCooldown == 120, "Expected BaseCollectCooldown = 120s anti-exploit")
local r1 = AccountLevel.RewardFor(1)
local r5 = AccountLevel.RewardFor(5)
local r10 = AccountLevel.RewardFor(10)
assert(r1.Gold == 300 and r5.Tier == "Epico" and r10.Tier == "Lendario" and r10.Tickets and r10.Tickets.Premium == 1, "Expected AccountLevel milestone rewards")
assert(AccountLevel.BattleVictoryXp({ 10, 10 }) == 60, "Expected BattleVictoryXp({10,10}) = 60")
assert(AccountLevel.CountUnclaimed({ Level = 3, Claimed = { ["1"] = true } }) == 2, "Expected 2 unclaimed level rewards")
assert(AccountLevel.FirstUnclaimedLevel({ Level = 3, Claimed = { ["1"] = true } }) == 2, "Expected first unclaimed = 2")

-- Test 9: Protected UI Guardrails (AccountLevelBar under TeamBar in TeamBarClient, Weekend Bonus in bottom-right of HudClient, Midnight-Blue Anime UITheme)
local sg = game:GetService("StarterGui")
local tbSrc = sg.TeamBarGui.TeamBarClient.Source
assert(tbSrc:find("AccountLevelBar", 1, true) and tbSrc:find("LevelPill", 1, true) and tbSrc:find("XpTrack", 1, true),
    "GUARDRAIL FAILED: AccountLevelBar (barra de XP embaixo da TeamBar) must remain in TeamBarClient!")
local hudSrc = sg.HudGui.HudClient.Source
assert(hudSrc:find("WeekendEventId", 1, true) and hudSrc:find("2x de Moedas", 1, true),
    "GUARDRAIL FAILED: Minimalist Weekend Bonus badge/tooltip must remain in bottom-right of HudClient!")
assert(not hudSrc:find("AccountLevelCard", 1, true),
    "GUARDRAIL FAILED: Do not duplicate AccountLevelCard in HudClient top-right; AccountLevelBar lives under TeamBar in TeamBarClient!")
local themeSrc = rs.UITheme.Source
assert(themeSrc:find("Color3.fromRGB(39, 48, 102)", 1, true),
    "GUARDRAIL FAILED: Midnight-Blue Anime palette must remain in ReplicatedStorage.UITheme!")

-- Test 10: Move Progression Nv. 1 -> 50 & Legendary Endgame Specials (Nv. 42-50)
for cid, def in pairs(Characters.List) do
    assert(def.Learnset and #def.Learnset >= 10, "Expected full Learnset (>=10 moves) on " .. cid)
    local prevLv = 0
    for _, entry in ipairs(def.Learnset) do
        assert(Moves.Get(entry.Move), "Invalid move " .. tostring(entry.Move) .. " on " .. cid)
        assert(entry.Level >= prevLv, "Learnset not sorted on " .. cid)
        prevLv = entry.Level
    end
    local active10 = Characters.DefaultActive(cid, 10)
    local active50 = Characters.DefaultActive(cid, 50)
    assert(#active10 >= 2 and #active10 <= 4 and #active50 == 4, "Invalid DefaultActive count on " .. cid)
    local hasDmg50 = false
    for _, mid in ipairs(active50) do
        if Moves.Get(mid).Category == "Damage" then hasDmg50 = true end
    end
    assert(hasDmg50, "Expected at least 1 damage move in DefaultActive(50) on " .. cid)
end
-- Legendaries unlock their special/signature moves at the final levels (>= 42 and 50)
assert(Characters.LearnLevelOf("Byakuya", "Senbonzakura") == 42 and Characters.LearnLevelOf("Byakuya", "SenbonzakuraKageyoshi") == 50, "Byakuya specials must be Nv 42 & 50")
assert(Characters.LearnLevelOf("BarbaBranca", "SocoSismico") == 44 and Characters.LearnLevelOf("BarbaBranca", "CeuETerra") == 50, "BarbaBranca specials must be Nv 44 & 50")
assert(Characters.LearnLevelOf("San", "Kamehameha") == 42 and Characters.LearnLevelOf("San", "GenkiDama") == 50, "San specials must be Nv 42 & 50")
assert(Characters.LearnLevelOf("Setero", "Atracao") == 42 and Characters.LearnLevelOf("Setero", "TudoRoxo") == 50, "Setero specials must be Nv 42 & 50")
assert(#Characters.UpcomingMoves("Byakuya", 10) >= 8 and #Characters.UpcomingMoves("Byakuya", 50) == 0, "Expected UpcomingMoves countdown on Byakuya")

-- Test 11: 100% Move Animation + VFX Coverage (all 93 moves have Anim, Vfx & Timing)
local caClone = rs:WaitForChild("CombatAnimator"):Clone()
caClone.Parent = sandbox
local vfxClone = rs:WaitForChild("VfxController"):Clone()
vfxClone.Source = vfxClone.Source
    :gsub('ReplicatedStorage:WaitForChild%("Data"%)', 'script.Parent:WaitForChild("Data")')
    :gsub('ReplicatedStorage:WaitForChild%("CombatAnimator"%)', 'script.Parent:WaitForChild("CombatAnimator")')
vfxClone.Parent = sandbox
local CombatAnimator = require(caClone)
local VfxController = require(vfxClone)
local ssChars = game:GetService("ServerStorage"):FindFirstChild("Characters")
local modelAnims = {}
if ssChars then
    for _, cm in ipairs(ssChars:GetChildren()) do
        local af = cm:FindFirstChild("Animations")
        if af then
            for _, a in ipairs(af:GetChildren()) do
                modelAnims[a.Name] = true
            end
        end
    end
end
local totalMoves = 0
for mid, mv in pairs(Moves.List) do
    totalMoves += 1
    assert(typeof(mv.Anim) == "string" and #mv.Anim > 0, "Missing Anim on move " .. mid)
    assert(typeof(mv.Vfx) == "string" and #mv.Vfx > 0, "Missing Vfx on move " .. mid)
    assert(typeof(mv.Timing) == "table" and mv.Timing.Charge and mv.Timing.Release and mv.Timing.Impact and mv.Timing.Length, "Missing Timing on move " .. mid)
    assert(CombatAnimator.Has(mv.Anim) or modelAnims[mv.Anim], "Unregistered Anim '" .. mv.Anim .. "' on move " .. mid)
    assert(VfxController.HasVfx(mv.Vfx), "Unregistered Vfx '" .. mv.Vfx .. "' on move " .. mid)
end
assert(totalMoves >= 93, "Expected >= 93 animated moves, got " .. tostring(totalMoves))

-- Test 12: Economy/XP Rebalance, Summon Rates & Clean Idle/Walk Animation Permissions
assert(Progression.XpToNext(10) == 100 and Progression.XpToNext(15) == 150 and Progression.XpToNext(49) == 2570 and Progression.XpToNext(50) == 0,
    "Expected two-phase Progression XP curve (Nv1-15 linear, Nv16-49 quadratic)")
local prevXp = 0
for lv = 1, 49 do
    local x = Progression.XpToNext(lv)
    assert(x > prevXp, "Expected strictly increasing Progression XP curve at Lv " .. lv)
    prevXp = x
end
assert(Summon.Portals.Comum.PityAt == 300 and Summon.Portals.Comum.Rates.Lendario == 0.005 and Summon.Portals.Comum.Rates.Epico == 0.035,
    "Expected rebalanced Common Portal rates (0.5% Leg / 3.5% Epic / Pity 300)")
assert(Summon.Portals.Premium.PityAt == 75 and Summon.Portals.Premium.Rates.Lendario == 0.02 and Summon.SellPrice.Lendario == 4000,
    "Expected rebalanced Premium Portal rates & Legendary sell price")
assert(Tower.Modes.Facil.Reward.Gold == 900 and Tower.Modes.Dificil.Reward.Gold == 9000 and Tower.Modes.Dificil.Reward.DailyGems == 8,
    "Expected rebalanced Tower rewards")
assert(Benefits.List.CuraAutomatica.Gems == 2500 and Retention.Daily.AllReward.Gems == 10 and PvPRank.WinReward["2x2"].Gold == 1500,
    "Expected rebalanced Benefits, Retention & PvP rewards")
assert(Characters.DefaultAnimations.Idle == 95978454415689 and Characters.DefaultAnimations.Walk == 81539047602340,
    "Expected authorized DefaultAnimations Idle/Walk IDs")
if ssChars then
    for _, inst in ipairs(ssChars:GetDescendants()) do
        if inst:IsA("Animation") then
            local aid = inst.AnimationId or ""
            assert(not aid:find("82392963584557", 1, true) and not aid:find("113228340758956", 1, true),
                "Unauthorized Idle/Walk AnimationId found on " .. inst:GetFullName())
        end
    end
end

-- Test 13: Passives System (20 passives, battle triggers) + Awakening Crafting & Secret Cave Altar
assert(#Passives.Order == 20, "Expected 20 passives in Passives.Order, got " .. tostring(#Passives.Order))
for cid, def in pairs(Characters.List) do
    local p = Characters.PassiveOf(cid, false)
    assert(p ~= nil, "Missing base passive on character " .. cid)
    if def.Rarity == "Lendario" then
        assert(p.Tier == "Unique", "Legendary " .. cid .. " must have Unique passive, got " .. tostring(p.Tier))
    end
end
for _, sid in ipairs({ "Luffy", "Naruto", "Ichigo" }) do
    local sp = Characters.PassiveOf(sid, true)
    assert(sp and sp.Tier == "Secret", "Awakened " .. sid .. " must unlock Secret passive")
    local rec = Awakening.RecipeFor(sid)
    assert(rec and rec.MinLevel == 35 and rec.Gold == 10000 and #rec.Materials >= 3, "Invalid Awakening recipe on " .. sid)
end
-- +10% Awakening stat bonus verification
local luffyBase = Progression.MemberMultiplier({ CharacterId = "Luffy", Stars = 0, Awakened = false })
local luffyAw = Progression.MemberMultiplier({ CharacterId = "Luffy", Stars = 0, Awakened = true })
assert(math.abs(luffyAw / luffyBase - 1.10) < 0.001, "Expected +10% Awakened stat multiplier")
-- CanAwaken validation
local fakeProf = {
    Gold = 10000,
    Materials = { EssenciaPunho = 8, FragmentoMares = 5, NucleoDespertar = 2 },
    Collection = {
        c1 = { CharacterId = "Luffy", Level = 34 },
        c2 = { CharacterId = "Luffy", Level = 35 },
    },
}
local ok34 = Awakening.CanAwaken(fakeProf, "c1")
local ok35 = Awakening.CanAwaken(fakeProf, "c2")
assert((not ok34) and ok35, "Expected Awakening Lv 35 gate to reject Lv 34 and accept Lv 35")

-- Battle passive test A: Sturdy (Chad survives lethal Lv 50 hit at 100% HP with 1 HP)
local bSturdy = BattleEngine.New({
    Player = { Team = { { CharacterId = "Byakuya", Level = 50, Moves = { "SenbonzakuraKageyoshi" } } } },
    Enemy = { Team = { { CharacterId = "Chad", Level = 5, Moves = { "SocoDireto" } } }, AI = "Facil" },
    Mode = "PvP", EnemyHuman = true, Seed = 10,
})
local evSturdy = bSturdy:ResolveTurn({ Kind = "Move", Index = 1 }, { Kind = "Move", Index = 1 })
assert(bSturdy:Active("Enemy").Hp == 1, "Expected Chad (Firmeza/Sturdy) to survive lethal hit with 1 HP, got " .. tostring(bSturdy:Active("Enemy").Hp))

-- Battle passive test B: Intimidacao (Zoro lowers enemy Attack on turn 1 entry) + InfinitoAbsoluto (Setero blocks it!)
local bIntim = BattleEngine.New({
    Player = { Team = { { CharacterId = "Zoro", Level = 30, Moves = { "CorteBasico" } } } },
    Enemy = { Team = { { CharacterId = "Setero", Level = 30, Moves = { "EsferaArcana" } } }, AI = "Facil" },
    Mode = "PvP", EnemyHuman = true, Seed = 11,
})
bIntim:ResolveTurn({ Kind = "Move", Index = 1 }, { Kind = "Move", Index = 1 })
assert(bIntim:Active("Enemy").Stages.Attack == 0, "Expected Setero (InfinitoAbsoluto) to block Zoro's Intimidacao drop")

-- Battle passive test C: Awakened Luffy (VontadeDeD) is immune to Paralysis
local bLuffy = BattleEngine.New({
    Player = { Team = { { CharacterId = "Luffy", Level = 40, Awakened = true, Moves = { "SocoDireto" } } } },
    Enemy = { Team = { { CharacterId = "Nami", Level = 40, Moves = { "SeloParalisante" } } }, AI = "Facil" },
    Mode = "PvP", EnemyHuman = true, Seed = 12,
})
bLuffy:ResolveTurn({ Kind = "Move", Index = 1 }, { Kind = "Move", Index = 1 })
assert(bLuffy:Active("Player").Status ~= "Paralysis", "Expected Awakened Luffy (VontadeDeD) to be immune to Paralysis")

-- Battle passive test D: BarbaBranca (TremorDosMares) ignores 2x2 spread penalty (Spread == 1.0!)
local bWB = BattleEngine.New({
    Player = { Team = {
        { CharacterId = "BarbaBranca", Level = 50, Moves = { "CeuETerra" } },
        { CharacterId = "Kaen", Level = 50, Moves = { "PosturaDaLamina" } },
    } },
    Enemy = { Team = {
        { CharacterId = "Yomogi", Level = 50, Moves = { "CascaDeCarvalho" } },
        { CharacterId = "Chad", Level = 50, Moves = { "PosturaDeCombate" } },
    } },
    Format = "2x2", Mode = "PvP", EnemyHuman = true, Seed = 13,
})
local evWB = bWB:ResolveTurn(
    { Kind = "Double", Actions = { { FieldSlot = 1, Kind = "Move", Index = 1 }, { FieldSlot = 2, Kind = "Move", Index = 1 } } },
    { Kind = "Double", Actions = { { FieldSlot = 1, Kind = "Move", Index = 1 }, { FieldSlot = 2, Kind = "Move", Index = 1 } } }
)
local wbSpreadHits = 0
for _, ev in ipairs(evWB) do
    if ev.Kind == "Damage" and ev.Side == "Enemy" then
        assert(ev.Spread == 1, "Expected BarbaBranca (TremorDosMares) to deal 1.0x spread damage, got " .. tostring(ev.Spread))
        wbSpreadHits += 1
    end
end
assert(wbSpreadHits == 2, "Expected BarbaBranca CeuETerra to hit 2 targets at 1.0x spread")

-- Secret Awakening Altar in Workspace + AwakeningGui ScreenGui exist
local mapAltar = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("SecretAwakeningAltar")
assert(mapAltar and mapAltar:FindFirstChild("AwakeningPrompt", true), "Missing Workspace.Map.SecretAwakeningAltar with AwakeningPrompt")
assert(sg:FindFirstChild("AwakeningGui") and sg.AwakeningGui:IsA("ScreenGui"), "Missing StarterGui.AwakeningGui ScreenGui")

-- Test 14: HollowPurple ("Vazio Roxo" - Setero / Gojo) 9-script modular system guardrail
local hpFolder = rs:FindFirstChild("HollowPurple")
assert(hpFolder, "Missing ReplicatedStorage.HollowPurple folder")
for _, modName in ipairs({ "Config", "Janitor", "LightningModule", "DebrisModule", "CameraEffects", "LightingEffects", "HollowPurpleVFX" }) do
    assert(hpFolder:FindFirstChild(modName), "Missing ReplicatedStorage.HollowPurple." .. modName)
end
assert(game:GetService("ServerScriptService"):FindFirstChild("HollowPurpleServer"), "Missing ServerScriptService.HollowPurpleServer")
assert(game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):FindFirstChild("HollowPurpleClient"), "Missing StarterPlayerScripts.HollowPurpleClient")
local hpCfg = require(hpFolder.Config)
assert(hpCfg.ActivationKey == Enum.KeyCode.R and hpCfg.Combat.ProjectileSpeed == 140, "Invalid HollowPurple Config")

return string.format("PASS: 1x1 GDD [12..14] (%d turns), 2x2 Doubles (%d turns), 20 Passives + Awakening + HollowPurple 5-Phase + %d/93 Animated Moves + UI Guardrails", b.Turn, simTurns, totalMoves)
end)
sandbox:Destroy()
assert(ok, res)
return res
"""
    ok, res = c.tool("execute_luau", {"code": code, "datamodel_type": "Edit", "studio_id": sid})
    print(res)
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("cmd", choices=["status", "push", "test"])
    args = ap.parse_args()
    c = studio_mcp.Client()
    try:
        sid = studio_mcp.studio_id(c, None)
        if args.cmd == "push":
            return cmd_push(c, sid)
        if args.cmd == "status":
            return cmd_status(c, sid)
        if args.cmd == "test":
            return cmd_test(c, sid)
        return 0
    finally:
        c.close()


if __name__ == "__main__":
    sys.exit(main())
