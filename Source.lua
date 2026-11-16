local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Source.lua -- where items drop. The client has no loot tables (they are the
server's), so they are read at runtime from an addon that keeps them for
Forever, nothing is copied: AtlasLoot Forever's dungeon and raid module
(AtlasLootClassic_DungeonsAndRaids, loaded on demand; loading it is
refused in combat). An adapter per source, so more can join later.

Quest rewards (blue and better) come from DungeonJournal (Forever Dungeon
Journal, its global ForeverDungeonJournal_NS): its dungeons' quests with
their reward items. It also knows each dungeon's entrance on the world map
and its bosses' models (Source.Place, Source.Display).

Source.Drops() lists { item, instance, boss, npcID, raid, forever, rate }
and, for quests, { item, instance, quest, questID, giver, choice, faction,
classOnly, journal }; Source.ByItem(id) the drops of one item.
-----------------------------------------------------------------------------]]
local Source = {}
ns.Source = Source

local drops, byItem, sourceName, journalByNpc
local MODULE, CORE = "AtlasLootClassic_DungeonsAndRaids", "AtlasLootClassic"
local CRAFT_MODULE = "AtlasLootClassic_Crafting"
local QUEST_QUALITY = 3

local function journal()
    local fdj = rawget(_G, "ForeverDungeonJournal_NS")
    return type(fdj) == "table" and type(fdj.DB) == "table" and fdj or nil
end

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

-- AtlasLoot's crafting tables: per profession its recipes as spell ids;
-- prof (AtlasLoot.Data.Profession) gives { createdItem, profession, skill,
-- low, high, reagents, counts } per spell. Items made, not spells.
function Source.ReadCrafting(module, prof)
    local list = {}
    for key, content in pairs(module) do
        if type(content) == "table" and type(content.items) == "table" then
            local profName = cleanName(content.name)
            profName = (profName and profName ~= "") and profName or key
            local seen = {}
            for _, section in ipairs(content.items) do
                if type(section) == "table" then
                    bossItems(section, function(spellID)
                        local ok, data = pcall(prof.GetProfessionData, spellID)
                        local made = ok and type(data) == "table" and data[1]
                        if type(made) == "number" and not seen[made] then
                            seen[made] = true
                            list[#list + 1] = { item = made, instance = profName, craft = true, skill = data[3],
                                spellID = spellID, reagents = data[6], counts = data[7], raid = false }
                        end
                    end)
                end
            end
        end
    end
    return list
end

-- The journal's quest rewards of at least QUEST_QUALITY.
function Source.ReadJournal(fdj)
    local list = {}
    for key, dungeon in pairs(fdj.DB) do
        if type(dungeon) == "table" then
            for _, q in ipairs(type(dungeon.quests) == "table" and dungeon.quests or {}) do
                for _, r in ipairs(type(q.rewardItems) == "table" and q.rewardItems or {}) do
                    if type(r[1]) == "number" and (r[3] or 0) >= QUEST_QUALITY then
                        list[#list + 1] = { item = r[1], instance = key, quest = q.name or "?", questID = q.id,
                            giver = q.pickup, choice = q.rewardChoice == true, faction = q.faction,
                            classOnly = q.classOnly, journal = key, raid = false }
                    end
                end
            end
        end
    end
    return list
end

-- The journal's dungeon of each boss by npc id.
local function indexBosses(fdj)
    local index = {}
    for key, dungeon in pairs(fdj and fdj.DB or {}) do
        for _, boss in ipairs(type(dungeon) == "table" and type(dungeon.bosses) == "table" and dungeon.bosses or {}) do
            if type(boss) == "table" and boss.npcID then index[boss.npcID] = key end
        end
    end
    return index
end

-- Where a drop is, from the journal: { name, location, entrance = { mapID,
-- x, y, label, detail } }, nil when the journal does not know it (raids).
function Source.Place(drop)
    local fdj = journal()
    if not (fdj and drop) then return nil end
    local key = drop.journal or (journalByNpc and drop.npcID and journalByNpc[drop.npcID])
    if not key and fdj.DungeonFromInstanceName then
        local ok, found = pcall(fdj.DungeonFromInstanceName, drop.instance)
        key = ok and found or nil
    end
    local dungeon = key and fdj.DB[key]
    if type(dungeon) ~= "table" then return nil end
    return { name = key, location = dungeon.location, entrance = dungeon.entrance }
end

-- A boss's creature display id from the journal (nil: ask by npc id).
function Source.Display(npcID)
    local fdj = journal()
    local ids = fdj and fdj.STATIC_DISPLAY_IDS
    return npcID and type(ids) == "table" and ids[npcID] or nil
end

-- Loads the source once (not in combat). Returns true when drops are there,
-- else nil and why: "NONE" (no source addon), "COMBAT".
function Source.Load()
    if drops then return true end
    local module, crafting
    if addonLoaded(CORE) then
        if not (addonLoaded(MODULE) and addonLoaded(CRAFT_MODULE)) then
            if InCombatLockdown() then return nil, "COMBAT" end
            if not addonLoaded(MODULE) then loadAddon(MODULE) end
            if not addonLoaded(CRAFT_MODULE) then loadAddon(CRAFT_MODULE) end
        end
        local db = AtlasLoot and AtlasLoot.ItemDB and AtlasLoot.ItemDB.Storage
        module = db and db[MODULE]
        local prof = AtlasLoot.Data and AtlasLoot.Data.Profession
        crafting = db and db[CRAFT_MODULE] and prof and Source.ReadCrafting(db[CRAFT_MODULE], prof)
    end
    local fdj = journal()
    if not (module or fdj) then return nil, "NONE" end
    drops, byItem = module and Source.ReadAtlasLoot(module) or {}, {}
    local names = {}
    if module then names[#names + 1] = "AtlasLoot Classic Forever" end
    for _, d in ipairs(crafting or {}) do drops[#drops + 1] = d end
    if fdj then
        for _, d in ipairs(Source.ReadJournal(fdj)) do drops[#drops + 1] = d end
        names[#names + 1] = "DungeonJournal"
    end
    sourceName, journalByNpc = table.concat(names, " + "), indexBosses(fdj)
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
function Source.Reset() drops, byItem, sourceName, journalByNpc = nil, nil, nil, nil end
