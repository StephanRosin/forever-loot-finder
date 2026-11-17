-- Tests for Forever Loot Finder. Run with tests/run (Lua 5.1, as in WoW).
local M = dofile("wowmock.lua")
local ROOT = ADDONDIR
local ADDON = "ForeverLootFinder"

local pass, fail = 0, 0
local function check(label, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        print(("  FAIL %-55s -> %s   (want: %s)"):format(label, tostring(got), tostring(want)))
    end
end
local function section(name) print(name) end

-- Items ----------------------------------------------------------------------
local function item(name, quality, ilvl, req, loc, classID, sub, stats, extra)
    local t = { name = name, quality = quality, ilvl = ilvl, reqLevel = req, equipLoc = loc, classID = classID,
        subClassID = sub, stats = stats }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
end
local HEAL, DMG = "ITEM_MOD_SPELL_HEALING_DONE_SHORT", "ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"
M.items = {
    [101] = item("Eye of Divinity", 4, 66, 60, "INVTYPE_TRINKET", 4, 0, { [HEAL] = 35, [DMG] = 12 }),
    [102] = item("Spell Ring", 3, 60, 55, "INVTYPE_FINGER", 4, 0, { [HEAL] = 20, [DMG] = 20, ITEM_MOD_INTELLECT_SHORT = 5 }),
    [103] = item("Plate Helm of Might", 4, 66, 60, "INVTYPE_HEAD", 4, 4,
        { ITEM_MOD_STRENGTH_SHORT = 20, ITEM_MOD_STAMINA_SHORT = 15, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 10 }),
    [104] = item("Robe of Healing", 4, 63, 58, "INVTYPE_ROBE", 4, 1,
        { [HEAL] = 33, [DMG] = 11, ITEM_MOD_INTELLECT_SHORT = 15, ITEM_MOD_SPIRIT_SHORT = 10, RESISTANCE0_NAME = 70 }),
    [105] = item("Agile Cloak", 3, 60, 55, "INVTYPE_CLOAK", 4, 1, { ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_ATTACK_POWER_SHORT = 20 }),
    [106] = item("Mystic Trinket", 3, 61, 50, "INVTYPE_TRINKET", 4, 0, {}, { tip = { "Use: Restores 500 health." } }),
    [208] = item("Bracers of Aim", 4, 61, 55, "INVTYPE_WRIST", 4, 4, { ITEM_MOD_HIT_RATING_SHORT = 10 }),
    [107 + 100] = item("Blank Spaulders", 4, 61, 60, "INVTYPE_SHOULDER", 4, 1, {}),
    [107] = item("Shadow Staff", 4, 65, 60, "INVTYPE_2HWEAPON", 2, 10, { [DMG] = 40, [HEAL] = 40, ITEM_MOD_INTELLECT_SHORT = 20 }),
    [108] = item("Leather Spirit Gloves", 3, 58, 50, "INVTYPE_HAND", 4, 2, { ITEM_MOD_SPIRIT_SHORT = 15 }),
    [109] = item("Robe of Tomorrow", 4, 70, 70, "INVTYPE_ROBE", 4, 1, { [HEAL] = 50 }),
    [110] = item("Robe of Spirit", 3, 60, 55, "INVTYPE_CHEST", 4, 1,
        { [HEAL] = 25, ITEM_MOD_SPIRIT_SHORT = 40, ITEM_MOD_INTELLECT_SHORT = 15 }),
    [111] = item("Hidden Trinket", 3, 62, 55, "INVTYPE_TRINKET", 4, 0, {}, { uncached = true }),
    [113] = item("Better Robe", 4, 64, 60, "INVTYPE_ROBE", 4, 1,
        { [HEAL] = 40, ITEM_MOD_INTELLECT_SHORT = 15, ITEM_MOD_SPIRIT_SHORT = 10 }),
    [114] = item("Weak Trinket", 2, 40, 35, "INVTYPE_TRINKET", 4, 0, { [HEAL] = 5 }),
    [120] = item("Heart of Fire", 3, 61, 55, "INVTYPE_TRINKET", 4, 0, {},
        { tip = { "Chance on hit: Hurls a fiery ball that causes 286 to 376 Fire damage." } }),
    [121] = item("Emblem of Spells", 4, 63, 60, "INVTYPE_TRINKET", 4, 0, {},
        { tip = { "Use: Increases damage and healing done by magical spells and effects by up to 100 for 15 sec." } }),
    [122] = item("Fury Badge", 3, 60, 55, "INVTYPE_TRINKET", 4, 0, {},
        { tip = { "Use: Increases attack power by 260 for 20 sec." } }),
    [123] = item("Lightning Bolts", 3, 60, 55, "INVTYPE_TRINKET", 4, 0, {},
        { tip = { "Use: Blasts the enemy with lightning for 300 Nature damage." } }),
    [124] = item("Shadow Charm", 3, 60, 55, "INVTYPE_TRINKET", 4, 0, {},
        { tip = { "Use: Increases damage done by Shadow spells by up to 80 for 20 sec." } }),
    [125] = item("Prayer Beads", 3, 52, 50, "INVTYPE_TRINKET", 4, 0, {},
        { tip = { "Use: Increases healing done by spells by up to 190 for 20 sec." } }),
    [126] = item("Band of Shadows", 3, 62, 57, "INVTYPE_FINGER", 4, 0, { RESISTANCE5_NAME = 15, ITEM_MOD_HEALTH_REGEN_SHORT = 17 }),
    [127] = item("Flame Band", 3, 61, 56, "INVTYPE_FINGER", 4, 0, {},
        { tip = { "Equip: Increases damage done by Fire spells and effects by up to 24." } }),
}
-- 112: a new Forever item the client does not know.
M.atlas.TheDeadmines = { name = "The Deadmines|TInterface\\ltn4:18|t", ContentType = 1, items = {
    { name = "Cookie", npcID = 1, [1] = { { 1, 101 }, { 2, 102 }, { 3, "INV_Box_01" }, { 4, 105 } } },
} }
M.atlas.MoltenCore = { MapID = 2717, ContentType = 2, items = {
    { name = "Garr", npcID = 2, [2] = { { 1, 103 }, { 2, 104 }, { 3, 107 }, { 4, 106 }, { 5, 110 }, { 6, 111 },
        { 7, 112 }, { 8, 108 }, { 9, 109 }, { 10, 113 }, { 11, 101 }, { 12, 120 }, { 13, 121 }, { 14, 122 }, { 15, 123 }, { 16, 124 },
        { 17, 125 }, { 18, 126 }, { 19, 127 }, { 20, 207 }, { 21, 128 }, { 22, 129 } } },
    { name = "Twins", npcID = { 3, 4 }, [2] = { { 1, 110 }, { 2, 208 } } },
    { name = "Horde Only Quest Rewards", ExtraList = true, [2] = { { 1, 102 } } },
    { name = "Tier 1 Sets", ExtraList = true, IgnoreAsSource = true, [2] = { { 1, 201 } } },
} }

M.items[128] = item("Robe of the Archmage", 4, 62, 57, "INVTYPE_ROBE", 4, 1, { [HEAL] = 30, [DMG] = 30, ITEM_MOD_INTELLECT_SHORT = 20 },
    { tip = { "Classes: Mage" } })
M.items[129] = item("Coloured Vestments", 4, 62, 57, "INVTYPE_ROBE", 4, 1, { [HEAL] = 30, ITEM_MOD_INTELLECT_SHORT = 20 },
    { tip = { "Classes: |cffffffffPriest|r" } })
-- A world epic (AtlasLoot Collections).
M.items[160] = item("Wandering Charm", 4, 63, 58, "INVTYPE_TRINKET", 4, 0, { [HEAL] = 30 })
M.world = { items = { { name = "Trinkets", [1] = { { 1, 160 } } } } }
M.items[150] = item("Tailored Robe", 3, 58, 52, "INVTYPE_ROBE", 4, 1, { [HEAL] = 20, ITEM_MOD_INTELLECT_SHORT = 12 })
M.items[14047] = item("Runecloth", 1, 50, 0, "", 7, 0, {})
-- DungeonJournal: quest rewards, entrances, boss models.
M.items[130] = item("Quest Robe", 3, 58, 52, "INVTYPE_ROBE", 4, 1, { [HEAL] = 18, ITEM_MOD_INTELLECT_SHORT = 10 })
M.items[131] = item("Green Thing", 2, 50, 45, "INVTYPE_ROBE", 4, 1, { [HEAL] = 9 })
M.items[132] = item("Horde Ring", 3, 58, 52, "INVTYPE_FINGER", 4, 0, { [HEAL] = 12 })
ForeverDungeonJournal_NS = {
    DB = { ["The Deadmines"] = { location = "Westfall", bosses = { { name = "Cookie", npcID = 1 } },
        entrance = { mapID = 1436, x = 0.42, y = 0.71, label = "The Deadmines Entrance", detail = "In Moonbrook" },
        quests = {
            { name = "Red Silk Bandanas", id = 214, pickup = "Scout Riell", faction = "Alliance", rewardChoice = true,
                rewardItems = { { 130, "Quest Robe", 3 }, { 131, "Green Thing", 2 } } },
            { name = "Horde Only", faction = "Horde", rewardItems = { { 132, "Horde Ring", 3 } } },
        } } },
    STATIC_DISPLAY_IDS = { [1] = 555 },
}

-- Load the addon ---------------------------------------------------------------
local function tocFiles()
    local files = {}
    for line in io.lines(ROOT .. "/" .. ADDON .. ".toc") do
        line = line:gsub("\r", "")
        if line ~= "" and not line:match("^#") then files[#files + 1] = (line:gsub("\\", "/")) end
    end
    return files
end
local ns = {}
for _, f in ipairs(tocFiles()) do
    local chunk, err = loadfile(ROOT .. "/" .. f)
    if not chunk then error(f .. ": " .. tostring(err)) end
    local ok, e = pcall(chunk, ADDON, ns)
    if not ok then error(f .. ": " .. tostring(e)) end
end
M.Fire("ADDON_LOADED", ADDON)
-- The hub (Forever Themes) is there: the first login wears its theme.
local hubColor = LibForeverThemes.COLORS.PITWALL[2].id
ForeverThemesHub = { Theme = function() return "PITWALL" end, Color = function() return hubColor end,
    Follows = function() return false end }
M.Fire("PLAYER_LOGIN")
local adopted = ns.Themes.Current() .. "/" .. tostring(ns.Themes.Color())
ns.Themes.Switch("CLASSIC")
M.Fire("PLAYER_LOGIN")
local again = ns.Themes.Current()
ForeverThemesHub = nil
M.RunTimers()

local Rules, Filter, Source, Settings = ns.Rules, ns.Filter, ns.Source, ns.Settings

local function ids(list)
    local set = {}
    for _, e in ipairs(list) do set[e.item.id] = e end
    return set
end
local function run(over)
    return Filter.Run(Filter.Options(over))
end

section("Themes")
check("first login wears the hub's theme", adopted, "PITWALL/" .. hubColor)
check("only once", again, "CLASSIC")

section("Source")
local listed = {}
for _, id in ipairs(Source.WORLD_DROPS) do listed[id] = true end
check("Wowhead world drops: Uther's Strength listed", listed[11302], true)
Source.WORLD_DROPS = {}   -- the fixtures only
check("loads AtlasLoot's module", Source.Load(), true)
check("module loaded on demand", M.addons.AtlasLootClassic_DungeonsAndRaids, true)
check("headers skipped (with quest rewards and a craft)", #Source.Drops(), 31)
local twins
for _, d in ipairs(Source.ByItem(110)) do if d.boss == "Twins" then twins = d end end
check("several npc ids: the first", twins and twins.npcID, 3)
local questList = false
for _, d in ipairs(Source.Drops()) do
    if d.boss == "Horde Only Quest Rewards" or d.boss == "Tier 1 Sets" then questList = true end
end
check("quest lists and sets are no drops", questList, false)
check("instance name without the mark", Source.ByItem(102)[1].instance, "The Deadmines")
check("Forever mark kept", Source.ByItem(102)[1].forever, true)
check("name from the map", Source.ByItem(103)[1].instance, "Area2717")
check("raid by content type", Source.ByItem(103)[1].raid, true)
check("dungeon", Source.ByItem(102)[1].raid, false)
check("an item at two places", #Source.ByItem(101), 2)
check("drop rate", Source.ByItem(101)[1].rate or Source.ByItem(101)[2].rate, 12.5)
check("name", Source.Name(), "AtlasLoot Classic Forever + DungeonJournal")
check("quest reward read", Source.ByItem(130)[1].quest, "Red Silk Bandanas")
check("green quest reward left out", #Source.ByItem(131), 0)
check("place by the boss's npc id", Source.Place(Source.ByItem(102)[1]).name, "The Deadmines")
check("entrance", Source.Place(Source.ByItem(102)[1]).entrance.mapID, 1436)
check("no place for a raid", Source.Place(Source.ByItem(103)[1]), nil)
check("boss display", Source.Display(1), 555)

section("Priest, healer and caster")
local list, unknown = run({})
local got = ids(list)
check("healing trinket", got[101] ~= nil, true)
check("spell ring", got[102] ~= nil, true)
check("healing robe", got[104] ~= nil, true)
check("staff", got[107] ~= nil, true)
check("trinket without stats: unclear", got[106] and got[106].unclear, true)
check("not loaded: unclear", got[111] and got[111].unclear, true)
local hidden = got[111].item
check("asked for: still loading", ns.Items.NoData(hidden), false)
M.state.time = M.state.time + ns.Items.WAIT
check("no answer in time: no data", ns.Items.NoData(hidden), true)
M.state.time = M.state.time - ns.Items.WAIT
hidden.failed = true
check("the server says none: no data", ns.Items.NoData(hidden), true)
hidden.failed = nil
check("plate: not wearable", got[103], nil)
check("attack power cloak: excluded", got[105], nil)
check("leather: not wearable", got[108], nil)
check("level 70: not now", got[109], nil)
check("unknown to the client counted (and one without any data)", unknown, 2)
check("no stats, no effect: not listed", got[207], nil)
check("drops of both places", #got[101].drops, 2)
check("sorted by item level", list[1].item.ilvl, 66)
check("points sort without a slot: item level", ns.Filter.SortFor("POINTS", nil), "ILVL")
local bySlot = run({ slot = "TRINKET" })
local ordered = true
for i = 2, #bySlot do
    if (bySlot[i].points or -1) > (bySlot[i - 1].points or -1) then ordered = false end
end
check("points sort in a slot: best first", ordered and #bySlot > 1, true)
check("only the kept unloaded one asked for", table.concat(M.requested, ","), "111")
Settings.Set("filterNow", false)
check("not 'now': level 70 shown", ids(run({}))[109] ~= nil, true)
Settings.Set("filterNow", true)

section("Quests")
got = ids(run({}))
check("quest reward listed", got[130] and got[130].drops[1].quest, "Red Silk Bandanas")
check("other faction's quest out", got[132], nil)
Settings.Set("filterQuests", false)
check("quests off", ids(run({}))[130], nil)
Settings.Set("filterQuests", true)
Settings.Set("filterDungeons", false)
check("dungeons off: quests stay", ids(run({}))[130] ~= nil, true)
Settings.Set("filterDungeons", true)

section("Crafting")
check("crafted item read", Source.ByItem(150)[1].craft, true)
check("world drop read", Source.ByItem(160)[1].world, true)
check("world drop listed", ids(run({ class = "PRIEST", roles = { HEAL = true } }))[160] ~= nil, true)
Settings.Set("filterWorld", false)
check("world drops off", ids(run({ class = "PRIEST", roles = { HEAL = true } }))[160], nil)
Settings.Set("filterWorld", true)
check("profession and skill", Source.ByItem(150)[1].instance .. " " .. Source.ByItem(150)[1].skill, "Tailoring 250")
check("a spell without data left out", #Source.Drops() > 0, true)
check("crafted listed", ids(run({}))[150] ~= nil, true)
Settings.Set("filterCrafting", false)
check("crafting off", ids(run({}))[150], nil)
Settings.Set("filterCrafting", true)

section("Healing and spell damage")
got = ids(run({ roles = { CASTER = true } }))
check("caster: healing trinket out", got[101], nil)
check("caster: healing robe out", got[104], nil)
check("caster: spell damage ring", got[102] ~= nil, true)
got = ids(run({ roles = { HEAL = true } }))
check("healer: spell damage ring counts", got[102] ~= nil, true)
check("healer: spell damage staff counts", got[107] ~= nil, true)
check("healer: the role's value", got[102].roles[1].main, 20)

section("Effects")
check("effect lines read", M.items[120] and ns.Items.Get(120).effects[1].kind, "PROC")
check("effect text without the trigger", ns.Items.Get(121).effects[1].text:sub(1, 9), "Increases")
got = ids(run({ slot = "TRINKET" }))
check("priest: weapon proc out", got[120], nil)
check("priest: attack power use out", got[122], nil)
check("priest: spell use in", got[121] ~= nil, true)
check("priest: plain damage use in", got[123] ~= nil, true)
got = ids(run({ slot = "TRINKET", roles = { HEAL = true } }))
check("healer: shadow spells in? caster only", got[124], nil)
check("healer: healing use in", got[125] ~= nil, true)
got = ids(run({ slot = "TRINKET", roles = { CASTER = true } }))
check("caster: healing use out", got[125], nil)
check("caster: shadow spells in", got[124] ~= nil, true)
got = ids(run({ slot = "TRINKET", class = "WARRIOR", roles = { MELEE = true } }))
check("melee: proc in", got[120] ~= nil, true)
check("melee: attack power in", got[122] ~= nil, true)
check("melee: spell use out", got[121], nil)
got = ids(run({ slot = "FINGER" }))
check("only resistances: out", got[126], nil)
check("priest: fire spell ring out", got[127], nil)
check("mage: fire spell ring in", ids(run({ slot = "FINGER", class = "MAGE", roles = { CASTER = true } }))[127] ~= nil, true)
check("German words", ns.Rules.EffectRoles({ { kind = "USE", text = "Erhöht die Angriffskraft um 260." } }, "deDE").MELEE, true)
check("no word: anyone", ns.Rules.EffectRoles({ { kind = "USE", text = "Deals 300 Nature damage." } }, "enUS"), nil)

section("Warrior")
got = ids(run({ class = "WARRIOR", roles = { TANK = true, MELEE = true } }))
check("plate helm", got[103] ~= nil, true)
check("agility cloak for melee", got[105] ~= nil, true)
check("healing trinket out", got[101], nil)
check("staff of spell damage out", got[107], nil)
got = ids(run({ class = "WARRIOR", roles = { TANK = true }, level = 39 }))
check("plate before 40: not now", got[103], nil)

section("Filters")
got = ids(run({ slot = "TRINKET" }))
check("trinket slot: trinkets", got[101] ~= nil and got[106] ~= nil, true)
check("trinket slot: no robe", got[104], nil)
Settings.Set("filterDungeons", false)
got = ids(run({}))
check("dungeons off: dungeon only item gone", got[102], nil)
check("dungeons off: raid drop stays", #got[101].drops, 1)
Settings.Set("filterDungeons", true)
Settings.Set("filterRaids", false)
check("raids off", ids(run({}))[104], nil)
Settings.Set("filterRaids", true)
got = ids(run({ text = "spirit" }))
check("search is global: other armour too", got[108] ~= nil and got[110] ~= nil, true)
ns.Window.Open()
ns.Window.State().text = "plate"
check("global hit without a role draws", pcall(ns.Window.Update), true)
local F = ns.Window.Frame()
F.heads.ilvl:GetScript("OnClick")(F.heads.ilvl)
check("header click: item level", Settings.Get("sort"), "ILVL")
F.heads.points:GetScript("OnClick")(F.heads.points)
check("header click: points again", Settings.Get("sort"), "POINTS")
check("value and verdict headers do not sort", F.heads.value:GetScript("OnClick"), nil)
check("global hit listed", #ns.Window.Entries() > 0 and #ns.Window.Entries()[1].roles, 0)
ns.Window.State().text = ""
ns.Window.Update()
ns.Window.State().offset = 3
ns.Window.Update()
check("items arriving keep the scroll place", ns.Window.State().offset, 3)
Settings.Set("filterRaids", false)
check("another filter: list back to the top", ns.Window.State().offset, 0)
Settings.Set("filterRaids", true)
check("coloured class name: for a priest", ids(run({ class = "PRIEST", roles = { HEAL = true } }))[129] ~= nil, true)
check("coloured class name: not for a druid", ids(run({ class = "DRUID", roles = { HEAL = true } }))[129], nil)
check("healing spirit: priest (Meditation, Spiritual Guidance)", ns.Rules.Points("HEAL", { SPI = 10 }, "PRIEST"), 10)
check("healing spirit: druid (Reflection, Living Spirit)", ns.Rules.Points("HEAL", { SPI = 10 }, "DRUID"), 7)
check("class-only robe: not for a priest", ids(run({ class = "PRIEST", roles = { HEAL = true } }))[128], nil)
check("class-only robe: for a mage", ids(run({ class = "MAGE", roles = { CASTER = true } }))[128] ~= nil, true)
check("class-only robe: found by a search", ids(run({ class = "PRIEST", text = "archmage" }))[128] ~= nil, true)
check("search ignores slot and sources", ids(run({ slot = "TRINKET", dungeons = false, text = "robe" }))[104] ~= nil, true)
Settings.Set("filterBestArmor", true)
check("best armour: cloth robe stays", ids(run({}))[104] ~= nil, true)
check("best armour: warrior mail no", ids(run({ class = "WARRIOR", roles = { TANK = true } }))[103] ~= nil, true)
Settings.Set("filterBestArmor", false)

section("Better than worn")
M.state.worn = { [5] = 104, [13] = 106, [14] = 114 }
got = ids(run({ slot = "CHEST", better = true }))
check("more healing: upgrade", got[113] and got[113].verdict, "UPGRADE")
check("upgrade delta", got[113] and math.floor(got[113].delta + 0.5), 7)
check("less healing, more spirit: alternative", got[110] and got[110].verdict, "ALT")
check("the worn one itself: not listed", got[104], nil)
got = ids(run({ slot = "CHEST", better = true, alternatives = false }))
check("without alternatives", got[110], nil)
got = ids(run({ slot = "TRINKET", better = true }))
check("against the worn trinket with stats", got[101] and got[101].delta, 30)
got = ids(run({ slot = "TRINKET", better = true, invSlot = 14 }))
check("against slot 14", got[101] and got[101].verdict, "UPGRADE")
check("the other slot's trinket: not listed", got[106], nil)
M.state.worn = { [5] = 104, [13] = 106, [14] = 114 }
check("worn unclear trinket not listed", ids(run({ slot = "TRINKET", better = true }))[106], nil)
check("empty slot: all upgrades", ids(run({ slot = "FINGER", better = true }))[102].verdict, "UPGRADE")
M.state.worn = { [13] = 125, [14] = 125 }
got = ids(run({ slot = "TRINKET", better = true, roles = { HEAL = true } }))
check("worn on-use only: stat trinket at most alternative", got[101] and got[101].verdict, "ALT")
M.state.worn = { [13] = 125, [14] = 114 }
got = ids(run({ slot = "TRINKET", better = true, roles = { HEAL = true } }))
check("one worn with stats: compared with that", got[101] and got[101].verdict, "UPGRADE")
M.state.worn = { [5] = 104, [13] = 106, [14] = 114 }
local up, alt = Filter.Count("CHEST", 5)
check("count for the character window", up .. "/" .. alt, "1/1")
check("verdict: equal points alternative", Filter.Verdict(10, nil, 10, 0), "ALT")
check("verdict: clearly fewer dropped", Filter.Verdict(5, nil, 10, 0), nil)
check("verdict: more but less main", Filter.Verdict(20, 5, 10, 8), "ALT")

section("One role at a time")
check("priest's first role", next(Settings.Roles("PRIEST")), "HEAL")
M.items[140] = item("Shawl", 3, 60, 55, "INVTYPE_SHOULDER", 4, 1, { [HEAL] = 22, [DMG] = 7, ITEM_MOD_INTELLECT_SHORT = 10 })
M.items[141] = item("Mantle", 3, 62, 57, "INVTYPE_SHOULDER", 4, 1, { [HEAL] = 15, [DMG] = 15, ITEM_MOD_INTELLECT_SHORT = 12 })
M.atlas.MoltenCore.items[1][2][#M.atlas.MoltenCore.items[1][2] + 1] = { 30, 141 }
Source.Reset()
Source.Load()
M.state.worn = { [3] = 140 }
got = ids(run({ slot = "SHOULDER", better = true }))
check("healer: less healing is no upgrade", got[141] == nil or got[141].verdict ~= "UPGRADE", true)
Settings.SetRole("CASTER")
check("role switched", next(Settings.Roles("PRIEST")), "CASTER")
got = ids(run({ slot = "SHOULDER", better = true }))
check("caster: more spell damage is", got[141] and got[141].verdict, "UPGRADE")
Settings.SetRole("HEAL")
local diff = Filter.Diff(M.items[141] and ns.Items.Get(141), ns.Items.Get(140))
local parts = {}
for _, d in ipairs(diff) do parts[#parts + 1] = ("%s%+d"):format(d.key, d.delta) end
check("diff stat by stat", table.concat(parts, " "), "INT+2 HEAL-7 SPELLDMG+8")
check("compared with the worn one", Filter.Against(Rules.SLOT.SHOULDER, nil, "HEAL").id, 140)
M.state.worn = { [13] = 114, [14] = 125 }
check("trinkets: with the one with stats", Filter.Against(Rules.SLOT.TRINKET, nil, "HEAL").id, 114)
check("empty slot: nothing", Filter.Against(Rules.SLOT.HEAD, nil, "HEAL"), nil)
M.state.worn = { [13] = 114 }
check("one trinket, the other slot empty: compared with nothing", Filter.Against(Rules.SLOT.TRINKET, nil, "HEAL"), nil)
M.state.worn = { [5] = 104, [13] = 106, [14] = 114 }

section("Rules")
check("cloak is no armour type", Rules.IsBestArmor("WARRIOR", 4, 1, "INVTYPE_CLOAK", 60), true)
check("warrior plate at 40", Rules.CanWear("WARRIOR", 4, 4, "INVTYPE_HEAD", 40), true)
check("warrior plate at 39", Rules.CanWear("WARRIOR", 4, 4, "INVTYPE_HEAD", 39), false)
check("priest wand", Rules.CanWear("PRIEST", 2, 19, "INVTYPE_RANGEDRIGHT"), true)
check("priest sword", Rules.CanWear("PRIEST", 2, 7, "INVTYPE_WEAPON"), false)
check("shield: paladin", Rules.CanWear("PALADIN", 4, 6, "INVTYPE_SHIELD"), true)
check("shield: rogue", Rules.CanWear("ROGUE", 4, 6, "INVTYPE_SHIELD"), false)
check("one-hander off hand: rogue", Rules.InSlot(Rules.SLOT.OFFHAND, "INVTYPE_WEAPON", "ROGUE"), true)
check("one-hander off hand: priest", Rules.InSlot(Rules.SLOT.OFFHAND, "INVTYPE_WEAPON", "PRIEST"), false)
check("every class has roles", #Rules.CLASSES, 9)

section("Character window")
local buttons = ns.CharButtons.Buttons()
check("a button per slot", #buttons, 17)
Settings.Set("charButtonSize", 20)
Settings.Set("charButtonPoint", "TOPLEFT")
Settings.Set("charButtonX", 3)
Settings.Set("charButtonY", -4)
local b = buttons[1]
check("size", b:GetWidth(), 20)
local p, rel, relPoint, x, y = b:GetPoint("CENTER")
check("anchored at the chosen point", relPoint, "TOPLEFT")
check("offset", x .. "/" .. y, "3/-4")
check("size kept in range", (function() Settings.Set("charButtonSize", 99); return b:GetWidth() end)(), 32)
Settings.Set("charButtons", false)
check("switched off", b:IsShown(), false)
Settings.Set("charButtons", true)
b:GetScript("OnEnter")(b)
check("tooltip counts", GameTooltip._lines[1] ~= nil, true)

section("Window")
ns.Window.Open()
check("opens", ns.Window.IsShown(), true)
check("entries", #ns.Window.Entries() > 0, true)
Settings.Set("filterBetter", false)
buttons[5]:GetScript("OnClick")(buttons[5])
check("from a slot: better on", Settings.Get("filterBetter"), true)
local wornRow = ns.Window.Frame().worn
wornRow:GetScript("OnEnter")(wornRow)
check("worn row: its tooltip", wornRow.link ~= nil and GameTooltip:IsShown(), true)
local row1 = ns.Window.Frame().list.rows[1]
row1:GetScript("OnEnter")(row1)
local seen = table.concat(GameTooltip._lines or {}, "|")
check("row tooltip: compared with the worn", seen:find("Compared with Robe of Healing", 1, true) ~= nil, true)
check("from a slot: that slot", ns.Window.State().slot, "CHEST")
check("from a slot: its entries", ns.Window.Entries()[1].item.equipLoc:find("CHEST", 1, true) ~= nil
    or ns.Window.Entries()[1].item.equipLoc == "INVTYPE_ROBE", true)
local function openItem(id)
    for i, e in ipairs(ns.Window.Entries()) do if e.item.id == id then ns.Window.OpenEntry(i) return true end end
end
local state0 = ns.Window.State()
state0.slot, state0.invSlot = nil, nil
Settings.Set("filterBetter", false)
ns.Window.Update()
check("panel closed at first", ns.Panel.IsShown(), false)
check("priest: no best armour chip", ns.Window.Frame().armorChip:IsShown(), false)
ns.Window.State().class = "WARRIOR"
ns.Window.Relayout()
check("warrior: best armour chip", ns.Window.Frame().armorChip:IsShown(), true)
ns.Window.State().class = nil
ns.Window.Relayout()
openItem(102)
local P = ns.Panel.Frame()
check("panel opens with a row", ns.Panel.IsShown(), true)
check("panel: the dungeon", P.title:GetText(), "The Deadmines")
check("panel: the map's tiles", P.map.tiles[12] and P.map.tiles[12]:IsShown(), true)
check("panel: entrance marked", P.map.marker:IsShown(), true)
local _, _, _, mx, my = P.map.marker:GetPoint("CENTER")
check("panel: marker where the entrance is", math.floor(mx + 0.5) .. "/" .. math.floor(my + 0.5),
    math.floor(0.42 * 306 + 0.5) .. "/" .. math.floor(-0.71 * 668 * 306 / 1002 + 0.5))
check("panel: the boss", P.who:GetText(), "Cookie")
check("panel: model shown", P.model:IsShown(), true)
openItem(104)
check("panel: raid without map", P.map.none:IsShown(), true)
openItem(130)
check("panel: quest", P.who:GetText(), "Quest: Red Silk Bandanas")
check("panel: no model for a quest", P.model:IsShown(), false)
check("panel: no art for a quest", P.art:IsShown(), false)
openItem(150)
check("panel: craft title", P.title:GetText(), "Tailoring")
check("panel: no map for a craft", P.map:IsShown(), false)
check("panel: profession art shown", P.art:IsShown(), true)
P.art:GetScript("OnUpdate")(P.art, 1.5)   -- frame 22: second sheet, k 2
check("panel: both sheets loaded", P.art.sheets[2]._texture:match("Tailoring_2%.png$") ~= nil, true)
check("panel: art plays into sheet 2", P.art.sheets[2]:GetAlpha() == 1 and P.art.sheets[1]:GetAlpha() == 0, true)
check("art for a TBC table", ns.Panel.ArtFor("LeatherworkingBC"), "Leatherworking")
check("art for engineering", ns.Panel.ArtFor("EngineeringBC"), "Engineering")
check("no art for cooking", ns.Panel.ArtFor("Cooking"), nil)
local mats = P.mats
check("panel: reagents table", mats.rows[1].name:GetText() .. " / " .. mats.rows[2].name:GetText(), "6× Runecloth / 1× #14341")
M.linked = nil
IsModifiedClick = function(what) return what == "CHATLINK" end
mats.rows[1].hit:GetScript("OnClick")(mats.rows[1].hit)
IsModifiedClick = function() return false end
check("panel: shift-click links a reagent", M.linked ~= nil and M.linked:find("14047") ~= nil, true)
check("panel: no prices yet: hint", mats:IsShown() and mats.hints[1]:GetText(), ns.L.MATS_NONE)
-- The auction house: two Runecloth auctions (stacks of 20 at 2g, of 10 at 1g 50s).
local Prices = ns.Prices
GetRealmName = function() return "Testrealm" end
local auctions = { { 20, 20000, 14047 }, { 10, 15000, 14047 }, { 1, 0, 14341 } }
C_AuctionHouse = {
    ReplicateItems = function() M.replicated = (M.replicated or 0) + 1 end,
    GetNumReplicateItems = function() return #auctions end,
    GetReplicateItemInfo = function(i)
        local a = auctions[i + 1]
        return "x", 1, a[1], 1, true, 1, nil, 0, 0, a[2], 0, nil, nil, nil, nil, 0, a[3], true
    end,
}
AuctionHouseFrame = CreateFrame("Frame")
M.Fire("ADDON_LOADED", "Blizzard_AuctionHouseUI")
local scan
for _, f in ipairs(M.frames) do if f._parent == AuctionHouseFrame then scan = f end end
check("scan button on the auction house", scan ~= nil and scan:IsEnabled() ~= false, true)
scan:GetScript("OnClick")(scan)
check("scan fetches every auction", M.replicated, 1)
scan:GetScript("OnEvent")(scan, "REPLICATE_ITEM_LIST_UPDATE")
check("cheapest per unit", Prices.Get(14047), 1000)
check("no buyout: no price", Prices.Get(14341), nil)
check("then 20 minutes to wait", Prices.Wait() > 19 * 60 and scan:IsEnabled() == false, true)
M.RunTimers()   -- the 60 s timeout of that scan: already answered, nothing to do
check("answered scan keeps its cooldown", Prices.Wait() > 19 * 60, true)
local saved = ForeverLootFinderDB.prices["Testrealm-Alliance"]
saved.asked = 0
auctions = {}
scan:GetScript("OnClick")(scan)
scan:GetScript("OnEvent")(scan, "REPLICATE_ITEM_LIST_UPDATE")
check("an empty answer keeps the prices", Prices.Get(14047), 1000)
saved.asked = 0
scan:GetScript("OnClick")(scan)
M.RunTimers()   -- no answer within 60 s
check("no answer: button free again", Prices.Wait(), 0)
scan:GetScript("OnClick")(scan)
scan:GetScript("OnHide")(scan)
check("AH closed while scanning: button free again", Prices.Wait(), 0)
M.timers = {}
saved.asked = time()
check("money: no copper", Prices.Money(123456), "12|cffffd700g|r 34|cffc7c7cfs|r")
check("money: copper only under a silver", Prices.Money(56), "56|cffeda55fc|r")
ns.Panel.Refresh()
check("panel: price each and line total", mats.rows[1].each:GetText() .. " / " .. mats.rows[1].sum:GetText(),
    Prices.Money(1000) .. " / " .. Prices.Money(6000))
check("panel: no price: dash", mats.rows[2].each:GetText(), "–")
check("panel: sum of those with a price", mats.total:GetText(), Prices.Money(6000))
check("fresh prices, one missing: only that hint", mats.hints[1]:GetText(), ns.L.MATS_SOME)
ForeverLootFinderDB.prices["Testrealm-Alliance"].at = time() - 3 * 86400
ns.Panel.Refresh()
check("prices older than 2 days: second hint", mats.hints[2]:GetText(), ns.L.MATS_OLD)
Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function(_, id) return id == 14341 and 500 or nil end } } }
check("Auctionator's price first", Prices.Get(14341), 500)
Auctionator.API.v1.GetAuctionAgeByItemID = function() return 3 end
check("Auctionator's age in days", select(2, Prices.Get(14341)) <= time() - 3 * 86400, true)
Auctionator = { API = { v1 = { GetAuctionPriceByItemLink = function(_, link) return link == "item:14341" and 700 or nil end } } }
check("Auctionator by link", Prices.Get(14341), 700)
Auctionator = nil
P.bar.close:GetScript("OnClick")(P.bar.close)
check("panel: closed by its ×", ns.Panel.IsShown(), false)
check("themes switch", ns.Themes.Switch("PITWALL"), true)
check("still shown under Pitwall", ns.Window.IsShown(), true)
check("registered for the hub", _G.ForeverThemes ~= nil, true)
ns.Themes.Switch("CLASSIC")
ns.Options.Open()
check("options open", ns.Options.IsShown(), true)
ns.Options.ShowPage("character")
check("character page", ns.Options.Current(), "character")

section("Languages")
local en, de = ns.Locales.enUS, ns.Locales.deDE
local missing = {}
for k in pairs(en) do if de[k] == nil then missing[#missing + 1] = k end end
table.sort(missing)
check("German has every key", table.concat(missing, ","), "")
local sharp = 0
for _, v in pairs(de) do if type(v) == "string" and v:find("ß", 1, true) then sharp = sharp + 1 end end
check("no sharp s", sharp, 0)
for _, slot in ipairs(Rules.SLOTS) do check("slot name " .. slot.key, en["SLOT_" .. slot.key] ~= nil, true) end
for _, role in ipairs(Rules.ROLES) do check("role " .. role, de["ROLE_" .. role] ~= nil, true) end

section("No accidental globals")
local allowed = { ForeverLootFinderDB = true, ForeverLootFinderChar = true, SLASH_FOREVERLOOTFINDER1 = true,
    SLASH_FOREVERLOOTFINDER2 = true, ForeverLootFinder_OnAddonCompartmentClick = true,
    ForeverLootFinder_OnAddonCompartmentEnter = true, ForeverLootFinder_OnAddonCompartmentLeave = true,
    LibForeverThemes = true, ForeverThemes = true, ForeverThemesHub = true, ForeverDungeonJournal_NS = true, ForeverLootFinderWindow = true, ForeverLootFinderSearch = true,
    ForeverLootFinderButton = true, ForeverLootFinderOptions = true, ForeverLootFinderOptionsScroll = true,
    ForeverLootFinderInterfacePanel = true, ForeverLootFinderInterfaceOpen = true }
local stray = {}
for k in pairs(_G) do
    if type(k) == "string" and k:find("LootFinder", 1, true) and not allowed[k]
        and not k:find("^ForeverLootFinderPage") and not k:find("^ForeverLootFinderNav") then
        stray[#stray + 1] = k
    end
end
check("no stray globals", table.concat(stray, ","), "")

-- Opening before the tables are read: at once, with a spinner, the list after.
Source.Reset()
M.timers = {}
ns.Window.Open()
ns.Window.Update()
local lf = ns.Window.Frame()
check("loading: spinner at once", lf.list.spinner:IsShown(), true)
check("loading: no list yet", #ns.Window.Entries(), 0)
for _ = 1, 50 do if Source.Ready() then break end M.RunTimers() end
M.RunTimers()
check("loading: tables read over frames", Source.Ready(), true)
check("loading: spinner gone", lf.list.spinner:IsShown(), false)
check("loading: the list", #ns.Window.Entries() > 0, true)

-- Roles per class (the probe cases of the rule review).
local boots = Rules.Stats({ ITEM_MOD_STAMINA_SHORT = 21, ITEM_MOD_SPIRIT_SHORT = 18, ITEM_MOD_FROST_DAMAGE_DONE_SHORT = 20,
    RESISTANCE0_NAME = 69 })
check("frost boots: mage caster", (Rules.ForRole("CASTER", boots, "MAGE")), true)
check("frost boots: not a bear's", (Rules.ForRole("TANK", boots, "DRUID")), false)
check("frost boots: not a priest's heal", (Rules.ForRole("HEAL", boots, "PRIEST")), false)
local _, frostPts, frostMain = Rules.ForRole("CASTER", boots, "MAGE")
check("school damage as spell damage", frostMain, 20)
local bear = Rules.Stats({ ITEM_MOD_STAMINA_SHORT = 15, ITEM_MOD_AGILITY_SHORT = 10, RESISTANCE0_NAME = 200 })
local cat = Rules.Stats({ ITEM_MOD_STRENGTH_SHORT = 15, ITEM_MOD_AGILITY_SHORT = 15, RESISTANCE0_NAME = 100 })
check("bear tank: armour counts", select(2, Rules.ForRole("TANK", bear, "DRUID")) > select(2, Rules.ForRole("TANK", cat, "DRUID")), true)
local warder = Rules.Stats({ ITEM_MOD_STAMINA_SHORT = 20, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 10, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 12 })
check("spell power tank set: paladin", (Rules.ForRole("TANK", warder, "PALADIN")), true)
check("spell power tank set: not a warrior's", (Rules.ForRole("TANK", warder, "WARRIOR")), false)
local hitCaster = Rules.Stats({ ITEM_MOD_INTELLECT_SHORT = 10, ITEM_MOD_HIT_RATING_SHORT = 10 })
check("hit for casters", (Rules.ForRole("CASTER", hitCaster, "MAGE")), true)
check("spell power heals", Rules.Stats({ ITEM_MOD_SPELL_POWER_SHORT = 20 }).HEAL, 20)
check("bonus armour read", select(3, Rules.Stats({ ITEM_MOD_EXTRA_ARMOR_SHORT = 93, RESISTANCE0_NAME = 200 })), 93)
check("no bonus armour", select(3, Rules.Stats({ RESISTANCE0_NAME = 200 })), nil)
local hitOff = ids(run({ class = "WARRIOR", roles = { TANK = true }, slot = Rules.SLOT.WRIST, better = false, now = false }))
local hitOn = ids(run({ class = "WARRIOR", roles = { TANK = true }, slot = Rules.SLOT.WRIST, better = false, now = false,
    tankHit = true }))
check("tank: hit items hidden by default", hitOff[208], nil)
check("tank: hit items on request, marked", hitOn[208] and hitOn[208].hit, 10)
M.items[209] = item("Tank Maul", 4, 61, 55, "INVTYPE_2HWEAPON", 2, 5, { ITEM_MOD_STAMINA_SHORT = 20, ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = 10 })
M.atlas.MoltenCore.items[#M.atlas.MoltenCore.items + 1] = { name = "Axe Boss", npcID = 9, [2] = { { 1, 209 } } }
Source.Reset()
Source.Load()
local function tank2h(class)
    return ids(run({ class = class, roles = { TANK = true }, slot = Rules.SLOT.MAINHAND, better = false, now = false }))[209]
end
check("two-hander: not for a warrior tank", tank2h("WARRIOR"), nil)
check("two-hander: for a bear", tank2h("DRUID") ~= nil, true)
-- Caster weapons: a staff against mace + orb, a mace beside a worn staff.
M.items[210] = item("Healing Mace", 3, 60, 55, "INVTYPE_WEAPON", 2, 4, { [HEAL] = 30 })
M.items[211] = item("Healing Orb", 3, 60, 55, "INVTYPE_HOLDABLE", 4, 0, { [HEAL] = 20 })
M.items[212] = item("Healing Staff", 4, 62, 55, "INVTYPE_2HWEAPON", 2, 10, { [HEAL] = 45 })
M.items[213] = item("Worn Staff", 3, 55, 50, "INVTYPE_2HWEAPON", 2, 10, { [HEAL] = 20 })
M.atlas.MoltenCore.items[#M.atlas.MoltenCore.items + 1] = { name = "Staff Boss", npcID = 10, [2] = { { 1, 212 }, { 2, 210 } } }
Source.Reset()
Source.Load()
local function weapons()
    return ids(run({ class = "PRIEST", roles = { HEAL = true }, slot = "MAINHAND", better = true, now = false }))
end
M.state.worn = { [16] = 210, [17] = 211 }
check("staff vs mace + orb: both hands summed", Filter.Against(Rules.SLOT.MAINHAND, nil, "HEAL", "PRIEST", M.items[212]).stats.HEAL, 50)
check("staff (45) vs mace + orb (50): no upgrade, an alternative", weapons()[212] and weapons()[212].verdict, "ALT")
M.state.worn = { [16] = 213 }
check("staff over a worn staff: upgrade", weapons()[212] and weapons()[212].verdict, "UPGRADE")
check("mace beside a worn staff: only an alternative", weapons()[210] and weapons()[210].verdict, "ALT")
M.state.worn = { [16] = 210, [17] = 211 }
local w = run({ class = "PRIEST", roles = { HEAL = true }, slot = "MAINHAND", better = true, now = false, sort = "POINTS" })
local sorted = true
for i = 2, #w do if (w[i].delta or -1e9) > (w[i - 1].delta or -1e9) then sorted = false end end
check("points sort in a slot: by the difference shown", sorted and #w > 1, true)
M.state.worn = {}
check("dodge item: not for a druid's melee DPS", (Rules.ForRole("MELEE", Rules.Stats({ ITEM_MOD_AGILITY_SHORT = 10,
    ITEM_MOD_DODGE_RATING_SHORT = 12 }), "DRUID")), false)
check("defense item: not for a warrior's DPS", ids(run({ class = "WARRIOR", roles = { MELEE = true }, slot = Rules.SLOT.MAINHAND,
    better = false, now = false }))[209] ~= nil, false)
local eph = {}
check("on use: known trinket", Rules.AddUse(18820, eph), true)
check("on use: 175 for 15 of 90 sec at 75 %", eph.HEAL, 175 * 15 / 90 * 0.75)
local orb = { MP5 = 2 }
Rules.AddUse(20512, orb)
check("on use: mana spread as mp5", math.floor(orb.MP5 * 100 + 0.5) / 100, 2 + 4.25)
check("on use: unknown trinket", Rules.AddUse(1, {}), false)
AtlasLoot.Data.Recipe = { GetRecipeForSpell = function(spell)
    return ({ [1] = 14468, [2] = 253974, [3] = 999999 })[spell] end }
check("recipe: none, from the trainer", ns.Panel.RecipeText(4), "Recipe: from the trainer")
check("recipe: drop and vendor with zones", ns.Panel.RecipeText(1),
    "Recipe: drops from Ice Thistle Yeti (Area618) · vendor Qia (Area618)")
check("recipe: quest and vendors of a zone", ns.Panel.RecipeText(2), 'Recipe: quest "I Need a Tailor" · vendors in Area405')
check("recipe: item of unknown origin", ns.Panel.RecipeText(3), nil)
check("recipe: Forever's new one by the made item", ns.Panel.RecipeText(5, 254095), "Recipe: world drop")
ns.RECIPE_SOURCES[999998] = { { "VENDOR", "Hordling", 17, 2 }, { "VENDOR", "Ally", 44, 1 }, { "VENDOR", "Goblin", 405, 3 } }
AtlasLoot.Data.Recipe.GetRecipeForSpell = function(spell) return ({ [1] = 14468, [2] = 253974, [3] = 999999, [6] = 999998 })[spell] end
check("recipe: only the own faction's vendors", ns.Panel.RecipeText(6), "Recipe: vendor Ally (Area44) · vendor Goblin (Area405)")
ns.RECIPE_SOURCES[999998][4] = { "VENDOR", "Ally2", 1, 1 }
check("recipe: more than two vendors counted", ns.Panel.RecipeText(6), "Recipe: vendor Ally (Area44) · vendor Goblin (Area405) · +1 more vendors")
C_SpellBook = { IsSpellKnown = function(spell) return spell == 1 end }
check("recipe: learned, a green check", ns.Panel.RecipeText(1):find("You know this recipe", 1, true) ~= nil, true)
C_SpellBook = nil
AtlasLoot.Data.Recipe = nil
check("recipe: without AtlasLoot's table", ns.Panel.RecipeText(1), nil)
local tap = {}
Rules.AddUse(18371, tap)
check("Mindtap: not for damage casters (mana only, less intellect)", (Rules.ForRole("CASTER", tap, "PRIEST")), false)
check("Mindtap: for healers", (Rules.ForRole("HEAL", tap, "PRIEST")), true)
check("damage casters: no points for mp5", Rules.Points("CASTER", { MP5 = 10 }, "SHAMAN"), 0)
M.items[18820] = item("Talisman of Ephemeral Power", 4, 66, 0, "INVTYPE_TRINKET", 4, 0, {})
local tal = ns.Items.Get(18820)
check("only a Use effect: now with points", tal.onUse and ns.Rules.HasStats(tal.stats), true)
check("label: warrior DPS", Rules.RoleLabelKey("WARRIOR", "MELEE"), "ROLE_DPS")
check("label: priest DPS", Rules.RoleLabelKey("PRIEST", "CASTER"), "ROLE_DPS")
check("label: druid melee DPS", Rules.RoleLabelKey("DRUID", "MELEE"), "ROLE_MELEE_DPS")
check("label: shaman caster DPS", Rules.RoleLabelKey("SHAMAN", "CASTER"), "ROLE_CASTER_DPS")
check("label: tank", Rules.RoleLabelKey("DRUID", "TANK"), "ROLE_TANK")
for _, k in ipairs({ "ROLE_DPS", "ROLE_MELEE_DPS", "ROLE_CASTER_DPS", "STAT_FROSTDMG" }) do
    check("deDE " .. k, de[k] ~= nil, true)
end

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
