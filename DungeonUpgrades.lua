local ADDON, ns = ...

--[[---------------------------------------------------------------------------
DungeonUpgrades.lua -- what drops in the dungeon or raid the player is in and
beats what they own for the chosen spec: worn and carried in the bags alike
(Filter.Options bags), over all slots. DungeonUI.lua shows it.
-----------------------------------------------------------------------------]]
local DungeonUpgrades = {}
ns.DungeonUpgrades = DungeonUpgrades

local RANK = { UPGRADE = 2, ALT = 1 }

-- The bosses dead in this run, from DungeonJournal's run log (it reads kills,
-- resets and corpse runs; Forever closes the combat log): { npc = {}, name = {} },
-- nil without a run. Read in a pcall: another layout of the log greys nothing.
local function killed()
    local fdj = rawget(_G, "ForeverDungeonJournal_NS")
    local log = fdj and fdj.RunLog
    if not (log and log.Current) then return nil end
    local ok, set = pcall(function()
        local run = log.Current()
        if not run or run.closed then return nil end
        local out = { npc = {}, name = {} }
        for _, k in ipairs(run.kills or {}) do
            if k.n then out.npc[k.n] = true end
            if type(k.b) == "string" then out.name[k.b:lower()] = true end
        end
        return out
    end)
    return ok and set or nil
end
DungeonUpgrades.Killed = killed   -- the tests

local function dead(set, d)
    return set ~= nil and ((d.npcID and set.npc[d.npcID]) or (type(d.boss) == "string" and set.name[d.boss:lower()]))
        or false
end

-- Upgrades first, the living bosses' loot before the dead ones', then by how much more they bring.
local function better(a, b)
    if a.verdict ~= b.verdict then return RANK[a.verdict] > RANK[b.verdict] end
    if a.killed ~= b.killed then return not a.killed end
    local da, db = a.delta or -math.huge, b.delta or -math.huge
    if da ~= db then return da > db end
    return (a.item.ilvl or 0) > (b.item.ilvl or 0)
end

-- entries, here: entries { item, verdict, delta, slot, killed, drops = { { boss, chance, killed } } }; here { name, id }
-- or nil outside an instance. Empty while the loot tables are not read (Source.LoadAsync).
function DungeonUpgrades.List(alternatives)
    local here = ns.Source.Here()
    if not (here and ns.Source.Ready()) then return {}, here end
    local list = ns.Filter.Run(ns.Filter.Options({ here = here, better = true, alternatives = alternatives,
        bags = true, slot = nil, invSlot = nil, text = "" }))
    local set = killed()
    for _, e in ipairs(list) do
        local drops, alive = {}, false
        for _, d in ipairs(e.drops or {}) do
            local gone = dead(set, d)
            alive = alive or not gone
            drops[#drops + 1] = { boss = d.boss, chance = d.rate, killed = gone }
        end
        -- The living bosses named first; grey once every boss here that drops it is dead.
        table.sort(drops, function(a, b) return not a.killed and b.killed end)
        e.drops, e.killed = drops, #drops > 0 and not alive
    end
    table.sort(list, better)
    return list, here
end
