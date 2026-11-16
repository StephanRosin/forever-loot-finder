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
    filterDungeons = true,
    filterRaids = true,
    filterBetter = false,       -- only better than (or alternatives to) what is worn
    filterAlternatives = true,  -- with "better": the unclear ones too
    sort = "ILVL",              -- Filter.SORTS
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
function Settings.Roles(class)
    local stored = ns.CharDB().roles
    local roles = {}
    for _, role in ipairs(ns.Rules.CLASS_ROLES[class] or {}) do
        roles[role] = not (stored and stored[role] == false)
    end
    return roles
end

function Settings.SetRole(role, on)
    local char = ns.CharDB()
    char.roles = char.roles or {}
    char.roles[role] = (not on) and false or nil
    Settings.Changed("roles")
end

-- Everything back to its default; the language and the theme colours stay.
function Settings.Reset()
    local old = ns.DB()
    ForeverLootFinderDB = { language = old.language, theme = old.theme, themeColors = old.themeColors }
    Settings.Changed(nil)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    Settings.Changed(nil)
end)
