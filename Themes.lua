local ADDON, ns = ...
local Settings = ns.Settings

--[[---------------------------------------------------------------------------
Themes.lua -- the window's look. The themes are LibForeverThemes'; this
addon keeps no settings per theme (nothing here is placed per theme), so a
switch only stores the id and repaints. The colour chosen per theme is
stored outside (themeColors), as in every Forever addon. Registered with the
library, so the hub (Forever Themes) and "apply to all" reach it.
-----------------------------------------------------------------------------]]
local Themes = {}
ns.Themes = Themes

local Lib = LibForeverThemes
Themes.CLASSIC = Lib.CLASSIC

-- Per theme only what the library's identity lacks: the window's background
-- colour over the backdrop (alpha 0..100), its text colour and outline, the
-- rim's width, and the face for body text (the Data Bar's values).
local function look(text, bg, alpha, outline, rimSize)
    return { text = text, bg = bg, alpha = alpha, outline = outline or "OUTLINE", rimSize = rimSize or 1 }
end

-- A framed theme's part: its accent (the library gives it none).
local function framed(art, accent)
    art.accent = accent
    return art
end

Themes.SPECS = Lib.Specs({
    WOOD = { art = look({ 0.96, 0.88, 0.70 }, { 0.1, 0.06, 0.02 }, 0, nil, 2) },
    TECH = { art = look({ 0.80, 0.97, 1 }, { 0.02, 0.05, 0.08 }, 0) },
    PARCHMENT = { art = look({ 1, 0.95, 0.82 }, { 0.22, 0.15, 0.07 }, 0, nil, 2) },
    RUNESTONE = { art = look({ 0.86, 0.95, 0.93 }, { 0.04, 0.05, 0.06 }, 0, nil, 2) },
    GLASS = { art = look({ 1, 0.93, 0.75 }, { 0.05, 0.04, 0.06 }, 90, nil, 3) },
    COMIC = { bodyFont = false, art = look({ 1, 1, 1 }, { 0, 0, 0 }, 0, nil, 3) },
    FROST = { art = look({ 0.92, 0.98, 1 }, { 0.02, 0.07, 0.15 }, 45, "") },
    PIXEL = { art = look({ 1, 0.95, 0.91 }, { 0, 0, 0 }, 0, nil, 2) },
    SWISS = { font = "Inter Tight", bodyFont = false,
        art = look({ 0.95, 0.95, 0.95 }, { 0.039, 0.039, 0.039 }, 100, nil, 3) },
    CONSOLE = { font = "IBM Plex Mono", bodyFont = false, art = look({ 0.9, 0.91, 0.93 }, { 0.06, 0.06, 0.07 }, 0) },
    PITWALL = { font = "Titillium Web SemiBold", bodyFont = false,
        art = look({ 0.95, 0.95, 0.96 }, { 0.039, 0.039, 0.039 }, 100) },
    -- A goblin workshop: sooty sheet metal, warning stripes along the top.
    GOBLIN = { art = framed(look({ 0.96, 0.92, 0.85 }, { 0, 0, 0 }, 0, nil, 2), { 0.95, 0.76, 0.19 }) },
}, true) -- the HD themes too, each from its base theme's part here
-- Glass HD is there to show its glass: the dark fill over it at 60 % (Glass: 90 %).
Themes.SPECS.GLASS_HD.art.alpha = 60

function Themes.Current()
    local id = Settings.Get("theme")
    return Themes.SPECS[id] and id or Themes.CLASSIC
end

function Themes.Spec(id)
    return Themes.SPECS[id or Themes.Current()] or Themes.SPECS[Themes.CLASSIC]
end

-- The art of the current theme, nil under Classic.
function Themes.Art()
    if Themes.Current() == Themes.CLASSIC then return nil end
    return Themes.Spec().art
end

function Themes.Colors(themeId)
    return Lib.Colors(themeId or Themes.Current())
end

function Themes.Color(themeId)
    themeId = themeId or Themes.Current()
    return Lib.ValidColor(themeId, (ns.DB().themeColors or {})[themeId])
end

function Themes.Back(art) return Lib.Back(art, Themes.Current(), Themes.Color()) end
function Themes.Tint(art) return Lib.Tint(art, Themes.Current(), Themes.Color()) end
function Themes.Rim(art) return Lib.Rim(Themes.Current(), Themes.Color()) or art.rim end
function Themes.WedgeColor(art) return Lib.WedgeColor(art, Themes.Current(), Themes.Color()) end

-- Classic's gold: titles and accent, as every Forever addon's window under Classic.
Themes.CLASSIC_GOLD = { 1, 0.82, 0.29, 1 }

-- The accent: the colour's, else the theme's own, else Classic's gold.
function Themes.Accent()
    local art = Themes.Art()
    return Lib.Accent(Themes.Current(), Themes.Color()) or art and art.accent or Themes.CLASSIC_GOLD
end

-- A window title's colour: Classic's gold, else the theme's text colour.
function Themes.TitleColor()
    return Themes.Art() and Themes.TextColor() or Themes.CLASSIC_GOLD
end

-- Fonts: the display face for headings, the body face for the rest (the
-- theme's font where it reads small, else Friz Quadrata). Not on a client
-- the theme fonts cannot write.
function Themes.TitleFont()
    if Themes.Current() == Themes.CLASSIC or not Lib.LatinClient() then return "Friz Quadrata" end
    return Themes.Spec().font or "Friz Quadrata"
end

function Themes.BodyFont()
    if Themes.Current() == Themes.CLASSIC or not Lib.LatinClient() then return "Friz Quadrata", 0 end
    -- As the Data Bar: the identity's body face, else (none, or false) the
    -- display face made a little larger (fontSizeAdd).
    local spec = Themes.Spec()
    if spec.bodyFont then return spec.bodyFont, 0 end
    if spec.font then return spec.font, spec.fontSizeAdd or 0 end
    return "Friz Quadrata", 0
end

-- The text colour and outline of the window's body text.
function Themes.TextColor()
    local art = Themes.Art()
    return art and art.text or ns.Style.COLORS.text
end

function Themes.Outline()
    local art = Themes.Art()
    return art and art.outline or ""
end

local function refuse()
    if InCombatLockdown() then return "COMBAT" end
end

function Themes.Switch(id)
    if not Themes.SPECS[id] then return nil, "UNKNOWN" end
    local why = refuse()
    if why then return nil, why end
    Settings.Set("theme", id)
    return true
end

function Themes.SetColor(id, themeId)
    themeId = themeId or Themes.Current()
    if not Lib.Colour(themeId, id) then return nil, "UNKNOWN" end
    local db = ns.DB()
    db.themeColors = db.themeColors or {}
    db.themeColors[themeId] = id ~= Lib.COLORS[themeId][1].id and id or nil
    if themeId == Themes.Current() then Settings.Changed("themeColors") end
    return true
end

Lib.Register(ADDON, {
    title = "Forever Loot Finder",
    Current = function() return Themes.Current() end,
    Switch = function(id) return Themes.Switch(id) end,
    Colors = function(themeId) return Themes.Colors(themeId) end,
    Color = function(themeId) return Themes.Color(themeId) end,
    SetColor = function(id, themeId) return Themes.SetColor(id, themeId) end,
})

function Themes.HasOthers() return #Lib.Others(ADDON) > 0 end

function Themes.ApplyToAll()
    return Lib.ApplyToAll(ADDON, Themes.Current(), Themes.Color())
end

-- Once, on the first login: wear the hub's theme and colour. The hub lets an
-- addon it sees for the first time follow only when it already wears them,
-- so a fresh install would otherwise keep Classic as its own theme.
ns.On("PLAYER_LOGIN", function()
    local db, hub = ns.DB(), Lib.Hub()
    if db.themeAdopted then return end
    db.themeAdopted = true
    local theme = hub and hub.Theme and hub.Theme()
    if not (theme and Themes.Switch(theme)) then return end
    local color = hub.Color and hub.Color()
    if color then Themes.SetColor(color, theme) end
end)
