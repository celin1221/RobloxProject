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
    Player = { Team = { { CharacterId = "Kaen", Level = 20 }, { CharacterId = "Yomogi", Level = 20 }, { CharacterId = "Raiko", Level = 20 }, { CharacterId = "San", Level = 20 } } },
    Enemy = { Team = { { CharacterId = "Raiko", Level = 20 }, { CharacterId = "Yomogi", Level = 20 }, { CharacterId = "Kaen", Level = 20 } }, AI = "Medio" },
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

-- Spread move (BrasaViva = move 2 of Kaen Learnset, Target = AllEnemies) hits BOTH enemies with Spread = 0.75
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
    Player = { Team = { { CharacterId = "San", Level = 50 }, { CharacterId = "Kaen", Level = 40 } } },
    Enemy = { Team = { { CharacterId = "Raiko", Level = 5 }, { CharacterId = "Yomogi", Level = 50 } }, AI = "Facil" },
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
        { FieldSlot = 2, Kind = "Move", Index = 3 }, -- PosturaDeCombate
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
    Player = { Team = { { CharacterId = "Kaen", Level = 5 }, { CharacterId = "Raiko", Level = 5 }, { CharacterId = "San", Level = 50 }, { CharacterId = "Setero", Level = 50 } } },
    Enemy = { Team = { { CharacterId = "Raiko", Level = 50 }, { CharacterId = "San", Level = 50 }, { CharacterId = "Yomogi", Level = 50 } } },
    Format = "2x2",
    Mode = "PvP",
    EnemyHuman = true,
    Seed = 999,
})
bDoubleRep:ResolveTurn(
    { Kind = "Double", Actions = {
        { FieldSlot = 1, Kind = "Move", Index = 3 }, -- PosturaDeCombate (Lv5 Kaen has 3 moves)
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

return string.format("PASS: 1x1 GDD [12..14] (%d turns) & 2x2 Doubles (spread 0.75/1.0, redirect, 2v1 ClearSlot, double replace, PvP sim %d turns, Winner=%s)", b.Turn, simTurns, tostring(bDoubleRep.Winner))
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
