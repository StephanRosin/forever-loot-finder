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
    filterBetter = false,       -- only better than (or alternatives to) what is worn
    filterAlternatives = true,  -- with "better": the unclear ones too
    sort = "POINTS",            -- Filter.SORTS
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

-- The roles chosen for the player's class: every role of it until chosen.
-- One role at a time ({ HEAL = true }): healing and damage are measured
-- differently, an item better for one would count as an upgrade for both.
-- The character's chosen role, else the class's first.
function Settings.Role(class)
    local list = ns.Rules.CLASS_ROLES[class] or {}
    local stored = ns.CharDB().role
    for _, role in ipairs(list) do if role == stored then return role end end
    return list[1]
end

function Settings.Roles(class)
    local role = Settings.Role(class)
    return role and { [role] = true } or {}
end

function Settings.SetRole(role)
    ns.CharDB().role = role
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
