local ADDON, ns = ...

--[[---------------------------------------------------------------------------
DungeonUpgrades.lua -- what drops in the dungeon or raid the player is in and
beats what they own for the chosen spec: worn and carried in the bags alike
(Filter.Options bags), over all slots. DungeonUI.lua shows it.
-----------------------------------------------------------------------------]]
local DungeonUpgrades = {}
ns.DungeonUpgrades = DungeonUpgrades

local RANK = { UPGRADE = 2, ALT = 1 }

-- Upgrades first, then by how much more they bring.
local function better(a, b)
    if a.verdict ~= b.verdict then return RANK[a.verdict] > RANK[b.verdict] end
    local da, db = a.delta or -math.huge, b.delta or -math.huge
    if da ~= db then return da > db end
    return (a.item.ilvl or 0) > (b.item.ilvl or 0)
end

-- entries, here: entries { item, verdict, delta, slot, drops = { { boss, chance } } }; here { name, id }
-- or nil outside an instance. Empty while the loot tables are not read (Source.LoadAsync).
function DungeonUpgrades.List(alternatives)
    local here = ns.Source.Here()
    if not (here and ns.Source.Ready()) then return {}, here end
    local list = ns.Filter.Run(ns.Filter.Options({ here = here, better = true, alternatives = alternatives,
        bags = true, slot = nil, invSlot = nil, text = "" }))
    for _, e in ipairs(list) do
        local drops = {}
        for _, d in ipairs(e.drops or {}) do drops[#drops + 1] = { boss = d.boss, chance = d.rate } end
        e.drops = drops
    end
    table.sort(list, better)
    return list, here
end
