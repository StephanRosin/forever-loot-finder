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
local WORLD_MODULE, WORLD_TABLE = "AtlasLootClassic_Collections", "WorldEpics"
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

-- Inside Source.LoadAsync's coroutine: a pause every few hundred entries,
-- the rest goes on next frame. Outside one (Source.Load) it does nothing.
local CHUNK, done = 150, 0
local function breathe()
    if not coroutine.running() then return end
    done = done + 1
    if done >= CHUNK then
        done = 0
        coroutine.yield()
    end
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

-- A table of set ids, not items: its table type is AtlasLoot's "Set" (the
-- type numbers are per module, so by name).
local function isSet(module, boss)
    local get = boss.TableType and module.GetItemTableType
    local ok, t = false, nil
    if get then ok, t = pcall(get, module, boss.TableType) end
    return ok and type(t) == "table" and t[1] == "Set"
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

-- Blue and purple world drops from level 30 that Wowhead's Forever database knows
-- (source "drop", no creature or zone named); AtlasLoot lists only the epics.
-- shortcut: a snapshot (November 2026), refresh by hand when Forever adds world drops.
Source.WORLD_DROPS = {
    647, 754, 809, 810, 811, 812, 867, 868, 869, 870, 871, 873, 934, 936, 937, 940, 942, 943, 944, 1168, 1169,
    1203, 1204, 1263, 1265, 1315, 1443, 1447, 1607, 1713, 1714, 1715, 1716, 1718, 1720, 1721, 1722, 1726, 1979,
    1980, 1981, 1982, 2099, 2100, 2163, 2164, 2244, 2246, 2276, 2277, 2291, 2564, 2565, 2802, 2815, 2824, 2825,
    2915, 2951, 3075, 4090, 4091, 4696, 5266, 5267, 6622, 6660, 7734, 8006, 8190, 9381, 9384, 9385, 9386, 9393,
    9402, 9406, 9420, 9428, 9433, 9434, 9435, 10573, 10582, 10584, 10623, 10624, 10625, 10627, 10634, 11302,
    12103, 13000, 13001, 13002, 13003, 13004, 13006, 13007, 13008, 13009, 13013, 13014, 13015, 13017, 13018,
    13020, 13021, 13022, 13023, 13025, 13026, 13027, 13028, 13029, 13030, 13034, 13035, 13036, 13038, 13039,
    13040, 13042, 13043, 13044, 13045, 13046, 13047, 13051, 13052, 13053, 13054, 13055, 13056, 13058, 13059,
    13060, 13064, 13065, 13066, 13067, 13068, 13070, 13071, 13072, 13073, 13074, 13075, 13076, 13077, 13081,
    13082, 13083, 13084, 13085, 13088, 13089, 13091, 13093, 13095, 13096, 13100, 13101, 13102, 13103, 13105,
    13107, 13109, 13110, 13111, 13112, 13113, 13115, 13116, 13117, 13118, 13119, 13120, 13121, 13122, 13123,
    13124, 13125, 13126, 13128, 13129, 13130, 13132, 13133, 13134, 13135, 13138, 13139, 13144, 13145, 13146,
    13199, 13358, 14549, 14551, 14552, 14553, 16671, 16681, 16685, 16702, 16710, 16714, 16716, 16736, 17007,
    23197, 23199, 23203, 24222, 280026, 280027, 280028, 280029, 280031, 280032, 287028, 287029, 287030, 287032,
    287033, 287034, 287035, 287036, 287044, 287045, 287070,
}

-- Pix Xizzix in Booty Bay: gear for Tarnished Undermine Reals (currency 3469), item = price.
-- shortcut: a snapshot of Wowhead Forever's currency page (November 2026), refresh by hand when the vendor changes.
Source.VENDOR = {
    npc = "Pix Xizzix", place = "Booty Bay", currency = 3469,
    entrance = { mapID = 1434, x = 0.284, y = 0.758 },
    items = {
        [228175] = 15, [228176] = 15, [272393] = 100, [272394] = 100, [272395] = 100, [272396] = 100,
        [272397] = 100, [272398] = 100, [272399] = 100, [272401] = 100, [272402] = 100, [272403] = 100,
        [272404] = 100, [272405] = 100, [272406] = 75, [272407] = 75, [272408] = 75, [272409] = 75,
        [272410] = 100, [272411] = 75, [272413] = 75, [272414] = 75, [272415] = 75, [272427] = 50,
        [272428] = 50, [272429] = 50, [272430] = 50, [272431] = 50, [272432] = 50, [272433] = 50,
        [272434] = 50, [272435] = 50, [272436] = 50, [272437] = 125, [272438] = 125, [272439] = 125,
        [272440] = 125,
    },
}

function Source.ReadVendor()
    local v, list = Source.VENDOR, {}
    for id, cost in pairs(v.items) do
        list[#list + 1] = { item = id, instance = v.place, vendor = v.npc, cost = cost, currency = v.currency,
            raid = false }
    end
    return list
end

-- AtlasLoot's world epics (Collections) and the list above: drops of no one boss, anywhere.
function Source.ReadWorld(content)
    local list, seen = {}, {}
    for _, id in ipairs(Source.WORLD_DROPS) do
        seen[id] = true
        list[#list + 1] = { item = id, instance = "", world = true, raid = false }
    end
    for _, section in ipairs(type(content) == "table" and content.items or {}) do
        if type(section) == "table" then
            bossItems(section, function(id)
                if seen[id] then return end
                seen[id] = true
                list[#list + 1] = { item = id, instance = "", world = true, raid = false }
            end)
        end
    end
    return list
end

function Source.ReadAtlasLoot(module)
    local list, names = {}, raidTypes()
    for key, content in pairs(module) do
        if type(content) == "table" and type(content.items) == "table" then
            local instance, forever = instanceName(key, content)
            local raid = isRaid(module, content, key, names)
            for _, boss in ipairs(content.items) do
                -- Set tables (set ids, not items) and the new dungeons' quest lists
                -- ("Horde Only Quest Rewards": DungeonJournal has those, with the faction) are no drops.
                local listOnly = type(boss) ~= "table" or boss.IgnoreAsSource or isSet(module, boss)
                    or (boss.ExtraList and type(boss.name) == "string" and boss.name:find("Quest", 1, true) ~= nil)
                if not listOnly then
                    local bossName, newBoss = cleanName(boss.name)
                    -- Several creatures (Twin Emperors, Four Horsemen): the first stands for them.
                    local npcID = type(boss.npcID) == "table" and boss.npcID[1] or boss.npcID
                    local seen = {}
                    breathe()
                    bossItems(boss, function(id)
                        if seen[id] then return end
                        seen[id] = true
                        list[#list + 1] = { item = id, instance = instance, instanceID = content.InstanceID, area = content.MapID,
                            boss = bossName or "?", npcID = npcID, raid = raid, forever = forever or newBoss,
                            rate = dropRate(npcID, id) }
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
                        breathe()
                        local ok, data = pcall(prof.GetProfessionData, spellID)
                        local made = ok and type(data) == "table" and data[1]
                        if type(made) == "number" and not seen[made] then
                            seen[made] = true
                            list[#list + 1] = { item = made, instance = profName, craft = true, skill = data[3], prof = key, profID = data[2],
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
            breathe()
            for _, q in ipairs(type(dungeon.quests) == "table" and dungeon.quests or {}) do
                for _, r in ipairs(type(q.rewardItems) == "table" and q.rewardItems or {}) do
                    if type(r[1]) == "number" and (r[3] or 0) >= QUEST_QUALITY then
                        list[#list + 1] = { item = r[1], instance = key, quest = q.name or "?", questID = q.id,
                            giver = q.pickup, choice = q.rewardChoice == true, faction = q.faction,
                            classOnly = q.classOnly, requires = q.requires, journal = key, raid = false }
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

-- The other quests' blue and purple rewards (QuestRewards.lua, Wowhead), not those the
-- journal has (known: quest ids). The zone is the place, in the client's language.
-- A quest of a raid's zone (raidAreas: AtlasLoot's MapIDs) is a raid's reward: a token
-- handed in (Naxxramas' tier pieces), listed with the raids.
local SIDES = { "Alliance", "Horde" }
function Source.ReadQuests(known, raidAreas)
    raidAreas = raidAreas or {}
    local list, zones = {}, {}
    for _, q in ipairs(ns.QUEST_REWARDS or {}) do
        local id, name, zone, side, req, choices, rewards = unpack(q)
        if not known[id] then
            if zones[zone] == nil then
                local area = zone > 0 and C_Map.GetAreaInfo and C_Map.GetAreaInfo(zone)
                zones[zone] = (area and area ~= "") and area or ns.L.QUEST
            end
            for _, set in ipairs({ { choices, true }, { rewards, false } }) do
                for _, item in ipairs(set[1]) do
                    list[#list + 1] = { item = item, instance = zones[zone], quest = name, questID = id, choice = set[2],
                        faction = SIDES[side], requires = req, zoneQuest = true, raid = raidAreas[zone] == true,
                        raidQuest = raidAreas[zone] }
                end
            end
        end
    end
    return list
end

-- AtlasLoot leaves out the npc id of Forever's new bosses (Bossman Toof): taken
-- from the journal's boss of that name (or alias), for the model and the tooltip.
function Source.FillNpcIDs(list, fdj)
    local byName = {}
    for _, dungeon in pairs(fdj and fdj.DB or {}) do
        for _, boss in ipairs(type(dungeon) == "table" and type(dungeon.bosses) == "table" and dungeon.bosses or {}) do
            if type(boss) == "table" and boss.npcID then
                if boss.name then byName[boss.name] = boss.npcID end
                for _, alias in ipairs(type(boss.aliases) == "table" and boss.aliases or {}) do byName[alias] = boss.npcID end
            end
        end
    end
    for _, d in ipairs(list) do
        if not d.npcID and d.boss then d.npcID = byName[d.boss] end
    end
end

-- Where a drop is, from the journal: { name, location, entrance = { mapID,
-- x, y, label, detail } }, nil when the journal does not know it (raids).
function Source.Place(drop)
    local fdj = journal()
    if drop and drop.vendor then
        local v, info = Source.VENDOR, C_Map.GetMapInfo(Source.VENDOR.entrance.mapID)
        local e = v.entrance
        return { name = v.place, location = info and info.name,
            entrance = { mapID = e.mapID, x = e.x, y = e.y, label = v.npc } }
    end
    if not (fdj and drop) or drop.world then return nil end
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
    local module, crafting, world
    if addonLoaded(CORE) then
        if not (addonLoaded(MODULE) and addonLoaded(CRAFT_MODULE) and addonLoaded(WORLD_MODULE)) then
            if InCombatLockdown() then return nil, "COMBAT" end
            if not addonLoaded(MODULE) then loadAddon(MODULE) end
            if not addonLoaded(CRAFT_MODULE) then loadAddon(CRAFT_MODULE) end
            if not addonLoaded(WORLD_MODULE) then loadAddon(WORLD_MODULE) end
        end
        local db = AtlasLoot and AtlasLoot.ItemDB and AtlasLoot.ItemDB.Storage
        module = db and db[MODULE]
        local prof = AtlasLoot.Data and AtlasLoot.Data.Profession
        crafting = db and db[CRAFT_MODULE] and prof and Source.ReadCrafting(db[CRAFT_MODULE], prof)
        world = Source.ReadWorld(db and db[WORLD_MODULE] and db[WORLD_MODULE][WORLD_TABLE])
    end
    local fdj = journal()
    if not (module or fdj) then return nil, "NONE" end
    -- Built aside and set at the end: while it reads, nothing sees half the drops.
    local list, index = module and Source.ReadAtlasLoot(module) or {}, {}
    local names = {}
    if module then names[#names + 1] = "AtlasLoot Classic Forever" end
    for _, d in ipairs(crafting or {}) do list[#list + 1] = d end
    for _, d in ipairs(world or {}) do list[#list + 1] = d end
    for _, d in ipairs(Source.ReadVendor()) do list[#list + 1] = d end
    if fdj then
        for _, d in ipairs(Source.ReadJournal(fdj)) do list[#list + 1] = d end
        names[#names + 1] = "DungeonJournal"
    end
    Source.FillNpcIDs(list, fdj)
    local known, raidAreas = {}, {}
    for _, d in ipairs(list) do
        if d.questID then known[d.questID] = true end
        if d.raid and d.area then raidAreas[d.area] = true end
    end
    for _, d in ipairs(Source.ReadQuests(known, raidAreas)) do list[#list + 1] = d end
    for _, d in ipairs(list) do
        index[d.item] = index[d.item] or {}
        table.insert(index[d.item], d)
    end
    if drops then return true end -- a direct Source.Load finished first
    drops, byItem, sourceName, journalByNpc = list, index, table.concat(names, " + "), indexBosses(fdj)
    return true
end

function Source.Ready() return drops ~= nil end

-- Source.Load spread over frames (the window opens at once and shows that it
-- loads); done(ok, why) when it is through. Loading AtlasLoot's modules
-- itself cannot be split.
local waiting
function Source.LoadAsync(done)
    if drops then return done(true) end
    if waiting then
        waiting[#waiting + 1] = done
        return
    end
    waiting = { done }
    local co = coroutine.create(Source.Load)
    local function step()
        local ok, a, b = coroutine.resume(co)
        if not ok then
            geterrorhandler()(a)
            a, b = nil, "NONE"
        end
        if coroutine.status(co) ~= "dead" then return C_Timer.After(0, step) end
        local list = waiting
        waiting = nil
        for _, fn in ipairs(list) do fn(a, b) end
    end
    C_Timer.After(0, step)
end

function Source.Drops() return drops or {} end

-- The dungeon or raid the player is in, { name, id }; nil outside.
function Source.Here()
    local name, kind, _, _, _, _, _, id = GetInstanceInfo()
    if kind ~= "party" and kind ~= "raid" then return nil end
    return { name = name, id = id }
end

-- Whether a boss drop is from there: AtlasLoot's InstanceID, else the name
-- (both in the client's language); a wing ("Dire Maul East") counts for its
-- instance ("Dire Maul"), which the game does not tell apart.
function Source.IsHere(d, here)
    if not (d.boss and here) then return false end
    if d.instanceID and d.instanceID == here.id then return true end
    local name = d.instance
    return name ~= nil and (name == here.name or name:sub(1, #here.name + 1) == here.name .. " ")
end
function Source.ByItem(id) return byItem and byItem[id] or {} end
function Source.Name() return sourceName end

-- Forgets the drops (the tests).
function Source.Reset() drops, byItem, sourceName, journalByNpc = nil, nil, nil, nil end
