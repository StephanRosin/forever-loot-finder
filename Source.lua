local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Source.lua -- where items drop. The client has no loot tables (they are the
server's), so they are read at runtime from an addon that keeps them for
Forever, nothing is copied: AtlasLoot Forever's dungeon and raid module
(AtlasLootClassic_DungeonsAndRaids, loaded on demand; loading it is
refused in combat). An adapter per source, so more can join later.

Source.Drops() lists { item, instance, boss, npcID, raid, forever, rate };
Source.ByItem(id) the drops of one item.
-----------------------------------------------------------------------------]]
local Source = {}
ns.Source = Source

local drops, byItem, sourceName
local MODULE, CORE = "AtlasLootClassic_DungeonsAndRaids", "AtlasLootClassic"

local function addonLoaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return fn and fn(name) and true or false
end

local function loadAddon(name)
    local fn = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if not fn then return false end
    local ok, loaded = pcall(fn, name)
    return ok and loaded and true or false
end

-- "Name|T…|t" (AtlasLoot's Forever mark) -> "Name", true.
local function cleanName(name)
    if type(name) ~= "string" then return nil, false end
    local forever = name:find("|T", 1, true) ~= nil
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return (name:gsub("^%s+", ""):gsub("%s+$", "")), forever
end

local function instanceName(key, content)
    local name, forever = cleanName(content.name)
    if (not name or name == "") and content.MapID and C_Map and C_Map.GetAreaInfo then
        name = C_Map.GetAreaInfo(content.MapID)
    end
    return (name and name ~= "") and name or key, forever
end

-- AtlasLoot's content types by index: { name, colour }, the names in the
-- client's language. Raids are its "20 Raids", "40 Raids" (through its
-- locale table) and "Forever Raids", and the world bosses.
local function raidTypes()
    local AL = AtlasLoot and AtlasLoot.Locales
    local names = { ["Forever Raids"] = true }
    if AL then
        names[AL["20 Raids"]] = true
        names[AL["40 Raids"]] = true
    end
    return names
end

local function isRaid(module, content, key, names)
    if key == "WorldBosses" then return true end
    local types = module.GetContentTypes and module:GetContentTypes()
    local t = types and content.ContentType and types[content.ContentType]
    return t ~= nil and names[t[1]] == true
end

local function dropRate(npcID, itemID)
    local rates = AtlasLoot and AtlasLoot.Data and AtlasLoot.Data.Droprate
    if not (rates and npcID) then return nil end
    local ok, rate = pcall(rates.GetData, rates, npcID, itemID)
    return ok and rate or nil
end

-- One boss's items: every difficulty's list ({ position, itemID } pairs;
-- strings are AtlasLoot's headers and icons).
local function bossItems(boss, add)
    for k, list in pairs(boss) do
        if type(k) == "number" and type(list) == "table" then
            for _, entry in ipairs(list) do
                local id = type(entry) == "table" and entry[2]
                if type(id) == "number" and id > 0 then add(id) end
            end
        end
    end
end

function Source.ReadAtlasLoot(module)
    local list, names = {}, raidTypes()
    for key, content in pairs(module) do
        if type(content) == "table" and type(content.items) == "table" then
            local instance, forever = instanceName(key, content)
            local raid = isRaid(module, content, key, names)
            for _, boss in ipairs(content.items) do
                if type(boss) == "table" then
                    local bossName, newBoss = cleanName(boss.name)
                    local seen = {}
                    bossItems(boss, function(id)
                        if seen[id] then return end
                        seen[id] = true
                        list[#list + 1] = { item = id, instance = instance, boss = bossName or "?",
                            npcID = boss.npcID, raid = raid, forever = forever or newBoss,
                            rate = dropRate(boss.npcID, id) }
                    end)
                end
            end
        end
    end
    return list
end

-- Loads the source once (not in combat). Returns true when drops are there,
-- else nil and why: "NONE" (no source addon), "COMBAT".
function Source.Load()
    if drops then return true end
    if not addonLoaded(CORE) then return nil, "NONE" end
    if not addonLoaded(MODULE) then
        if InCombatLockdown() then return nil, "COMBAT" end
        if not loadAddon(MODULE) then return nil, "NONE" end
    end
    local db = AtlasLoot and AtlasLoot.ItemDB and AtlasLoot.ItemDB.Storage
    local module = db and db[MODULE]
    if not module then return nil, "NONE" end
    drops, byItem, sourceName = Source.ReadAtlasLoot(module), {}, "AtlasLoot Forever"
    for _, d in ipairs(drops) do
        byItem[d.item] = byItem[d.item] or {}
        table.insert(byItem[d.item], d)
    end
    return true
end

function Source.Drops() return drops or {} end
function Source.ByItem(id) return byItem and byItem[id] or {} end
function Source.Name() return sourceName end

-- Forgets the drops (the tests).
function Source.Reset() drops, byItem, sourceName = nil, nil, nil end
