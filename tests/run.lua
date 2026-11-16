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
    [106] = item("Mystic Trinket", 3, 61, 50, "INVTYPE_TRINKET", 4, 0, {}),
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
        { 17, 125 }, { 18, 126 }, { 19, 127 } } },
} }

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
check("loads AtlasLoot's module", Source.Load(), true)
check("module loaded on demand", M.addons.AtlasLootClassic_DungeonsAndRaids, true)
check("headers skipped (and two quest rewards)", #Source.Drops(), 24)
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
check("plate: not wearable", got[103], nil)
check("attack power cloak: excluded", got[105], nil)
check("leather: not wearable", got[108], nil)
check("level 70: not now", got[109], nil)
check("unknown to the client counted", unknown, 1)
check("drops of both places", #got[101].drops, 2)
check("sorted by item level", list[1].item.ilvl, 66)
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
check("search by name", #run({ text = "spirit" }), 1)
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

print(("%d passed, %d failed"):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
