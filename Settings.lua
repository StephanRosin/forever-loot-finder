local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Settings.lua -- account wide (ForeverLootFinderDB): the theme, the window's
filters, the minimap button and the character window's buttons; per
character (ForeverLootFinderChar): the roles chosen for one's own class.
A value equal to its default is not stored.
-----------------------------------------------------------------------------]]
local Settings = {}
ns.Settings = Settings

Settings.DEFAULTS = {
    theme = "CLASSIC",          -- Themes.lua; switched only through Themes.Switch
    minimapShow = true, minimapAngle = 200,
    -- The search buttons on the character window's slots (CharButtons.lua).
    charButtons = true,
    charButtonSize = 14,
    charButtonPoint = "BOTTOMRIGHT",   -- where on the slot (CharButtons.POINTS)
    charButtonX = 0, charButtonY = 0,
    -- The window's filters (Filter.lua).
    filterNow = true,           -- only what this character can wear now (level, armour)
    filterBestArmor = false,    -- only the class's best armour type
    filterTankHit = false,      -- tanks: hit items too, marked
    filterDungeons = true,
    filterRaids = true,
    filterQuests = true,
    filterCrafting = true,
    filterWorld = true,
    filterVendors = true,
    filterHere = false,         -- inside a dungeon or raid: only its bosses' loot
    filterBetter = false,       -- only better than (or alternatives to) what is worn
    filterAlternatives = true,  -- with "better": the unclear ones too
    sort = "POINTS",            -- Filter.SORTS
    -- The window on entering a dungeon or raid (DungeonUI.lua).
    dungeonUpgrades = true,     -- opens by itself
    dungeonAlternatives = false,
    advanced = false,           -- options: the page with the point weights
    dynamic = true,             -- hit and crit weighed from the character (Rules.ReadChar)
}

Settings.RANGES = {
    charButtonSize = { 8, 32 },
    charButtonX = { -40, 40 }, charButtonY = { -40, 40 },
}

function ns.AccountDB()
    ForeverLootFinderDB = ForeverLootFinderDB or {}
    return ForeverLootFinderDB
end
ns.DB = ns.AccountDB

function ns.CharDB()
    ForeverLootFinderChar = ForeverLootFinderChar or {}
    return ForeverLootFinderChar
end

local listeners = {}

function Settings.OnChange(fn)
    listeners[#listeners + 1] = fn
end

-- key nil: everything may have changed.
function Settings.Changed(key)
    for _, fn in ipairs(listeners) do fn(key) end
end

function Settings.Get(key)
    local v = ns.DB()[key]
    if v == nil then v = Settings.DEFAULTS[key] end
    return v
end

-- Numbers rounded and kept in their range, the default as nil.
function Settings.Stored(key, value)
    local range = Settings.RANGES[key]
    if range and type(value) == "number" then
        value = math.max(range[1], math.min(range[2], math.floor(value + 0.5)))
    end
    if value == Settings.DEFAULTS[key] then value = nil end
    return value
end

function Settings.Set(key, value)
    ns.DB()[key] = Settings.Stored(key, value)
    Settings.Changed(key)
end

-- The role of the spec chosen for the class (Rules.SpecOf). One role at a
-- time ({ HEAL = true }): healing and damage are measured differently, an
-- item better for one would count as an upgrade for both.
function Settings.Role(class)
    local spec = ns.Rules.SpecOf(class)
    return spec and spec.role
end

function Settings.Roles(class)
    local role = Settings.Role(class)
    return role and { [role] = true } or {}
end

-- The character's spec (an id of Rules.SPECS); the role stored before specs goes.
function Settings.SetSpec(id)
    local char = ns.CharDB()
    char.spec, char.role = id, nil
    Settings.Changed("roles")
end

-- Everything back to its default; the language and the theme colours stay.
function Settings.Reset()
    local old = ns.DB()
    ForeverLootFinderDB = { language = old.language, theme = old.theme, themeColors = old.themeColors,
        themeAdopted = old.themeAdopted, prices = old.prices }
    ns.Rules.ResetWeights()   -- also forgets the profiles built with them
    Settings.Changed(nil)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Settings.Changed(nil)
end)
