-- A mock of the WoW API, just enough for Forever Loot Finder. Lua 5.1, as in the game.
local M = { frames = {}, byName = {}, chat = {}, placed = {}, timers = {}, fontStrings = {},
            popups = {}, casts = {}, registered = {} }

local widget = {}
widget.__index = function(t, k)
    -- Only CamelCase keys are widget methods. Everything else is the addon's
    -- own data and must be nil as in the game.
    if type(k) ~= "string" or not k:match("^%u") then return nil end
    local f = function() end
    rawset(t, k, f)
    return f
end

local function newWidget(name, kind)
    local w = setmetatable({ _name = name, _kind = kind, _scripts = {}, _events = {},
                             _w = 0, _h = 0, _shown = true, _attr = {} }, widget)
    function w:GetName() return self._name end
    function w:SetScript(s, fn) self._scripts[s] = fn end
    function w:GetScript(s) return self._scripts[s] end
    function w:HookScript(s, fn)
        local old = self._scripts[s]
        self._scripts[s] = function(...) if old then old(...) end return fn(...) end
    end
    function w:SetText(t) self._text = t end
    function w:GetText() return self._text end
    function w:GetAlpha() return self._alpha or 1 end
    function w:SetAlpha(v) self._alpha = v end
    function w:SetBlendMode(v) self._blend = v end
    function w:GetDrawLayer() return "OVERLAY", self._drawSub or 0 end
    function w:SetDrawLayer(_, sub) self._drawSub = sub end
    function w:GetBlendMode() return self._blend end
    function w:SetAllPoints(rel) self._allPoints = rel or true end
    function w:SetValue(v) self._value = v end
    function w:GetValue() return self._value end
    function w:SetMinMaxValues(a, b) self._min, self._max = a, b end
    -- Animations: a group that knows whether it plays.
    function w:CreateAnimationGroup()
        local g = newWidget()
        function g:CreateAnimation() return newWidget() end
        function g:Play() self._playing = true end
        function g:Stop() self._playing = false end
        function g:IsPlaying() return self._playing == true end
        return g
    end
    -- The fill texture of a status bar (made on first ask).
    function w:GetStatusBarTexture()
        if not self._fillTex then self._fillTex = newWidget() end
        return self._fillTex
    end
    function w:SetStatusBarColor(r, g, b, a) self._color = { r, g, b, a } end
    function w:SetStatusBarTexture(t) self._barTex = t end
    function w:SetTextureSliceMargins(...) self._slice = { ... } end
    function w:SetTextColor(r, g, b, a) self._textColor = { r, g, b, a } end
    function w:SetChecked(v) self._checked = not not v end
    function w:GetChecked() return self._checked end
    function w:SetAttribute(k, v) self._attr[k] = v end
    function w:GetAttribute(k) return self._attr[k] end
    function w:SetSize(a, b) self._w, self._h = a, b end
    function w:SetWidth(v) self._w = v end
    function w:SetHeight(v) self._h = v end
    function w:GetWidth() return self._w end
    function w:GetHeight() return self._h end
    function w:Hide()
        local was = self._shown
        self._shown = false
        if was and self._scripts.OnHide then self._scripts.OnHide(self) end
    end
    function w:Show() self._shown = true end
    function w:SetShown(v) if v then self:Show() else self:Hide() end end
    function w:IsShown() return self._shown end
    function w:IsVisible() return self._shown end
    function w:GetFrameLevel() return self._level or 3 end
    function w:SetParent(p) self._parent = p end
    function w:SetEnabled(on) self._enabled = on and true or false end
    function w:IsEnabled() return self._enabled ~= false end
    function w:GetParent() return self._parent end
    function w:SetFrameLevel(v) self._level = v end
    function w:GetEffectiveScale() return 1 end
    function w:SetMovable(v) self._movable = v end
    function w:IsMovable() return self._movable end
    function w:EnableMouse(v) self._mouse = v end
    function w:RegisterForDrag(...) self._drag = select("#", ...) > 0 end
    function w:RegisterEvent(e) self._events[e] = true end
    function w:UnregisterEvent(e) self._events[e] = nil end
    function w:SetPoint(p, rel, p2, x, y)
        if type(rel) == "number" then x, y, rel, p2 = rel, p2, nil, nil end
        self._points = self._points or {}
        self._points[p] = { rel, p2, x, y }
        M.placed[self] = { p, rel, p2, x, y }
    end
    function w:ClearAllPoints() self._points = {} end
    function w:SetScale(v) self._scale = v end
    function w:GetScale() return self._scale or 1 end
    function w:GetPoint(p)
        if type(p) == "number" then local a = M.placed[self]; if a then return a[1], a[2], a[3], a[4], a[5] end end
        local a = self._points and self._points[p]; if a then return p, a[1], a[2], a[3], a[4] end end
    function w:SetColorTexture(r, g, b, a) self._texColor = { r, g, b, a } end
    function w:SetVertexColor(r, g, b, a) self._vertex = { r, g, b, a } end
    function w:SetGradient(dir, a, b) self._gradient = { dir, a, b } end
    function w:SetTexture(t) self._texture = t end
    function w:SetAtlas(a) self._atlas = a end
    function w:SetTexCoord(...) self._texCoord = { ... } end
    function w:SetHorizTile(v) self._horizTile = v == true end
    function w:GetHorizTile() return self._horizTile == true end
    function w:SetVertTile(v) self._vertTile = v == true end
    function w:CreateTexture()
        local t = newWidget(nil, "Texture")
        t._owner = self
        return t
    end
    function w:CreateLine()
        local l = newWidget(nil, "Line")
        function l:SetStartPoint(p, rel, x, y) self._start = { x, y } end
        function l:SetEndPoint(p, rel, x, y) self._end = { x, y } end
        function l:SetThickness(v) self._thickness = v end
        return l
    end
    function w:CreateMaskTexture() return newWidget(nil, "MaskTexture") end
    function w:CreateFontString(_, _, template)
        local fs = newWidget(nil, "FontString")
        fs._font = { "Fonts\\FRIZQT__.TTF", 10, "" }
        fs._template, fs._owner = template, self
        function fs:GetFont() return self._font[1], self._font[2], self._font[3] end
        function fs:SetFont(p, s, f) self._font = { p, s, f }; return true end
        function fs:GetStringWidth() return #(tostring(self._text or "")) * 7 end
        M.fontStrings[#M.fontStrings + 1] = fs
        return fs
    end
    return w
end
M.newWidget = newWidget

function CreateFrame(kind, name, parent, template)
    local f = newWidget(name, kind)
    f._parent, f._template = parent, template
    M.frames[#M.frames + 1] = f
    if name then M.byName[name] = f; _G[name] = f end
    if template == "InterfaceOptionsCheckButtonTemplate" and name then
        _G[name .. "Text"] = f:CreateFontString()
    end
    if template == "OptionsSliderTemplate" and name then
        _G[name .. "Text"] = f:CreateFontString()
    end
    return f
end

-- Delivers an event to every frame that registered it, in creation order.
function M.Fire(event, ...)
    for _, f in ipairs(M.frames) do
        local handler = f._events[event] and f:GetScript("OnEvent")
        if handler then handler(f, event, ...) end
    end
end

function M.RunTimers()
    local list = M.timers
    M.timers = {}
    for _, fn in ipairs(list) do fn() end
end

UIParent = newWidget("UIParent")
UIParent._w, UIParent._h = 1920, 1080
function UIParent:GetCenter() return 960, 540 end
function UIParent:GetTop() return 1080 end
Minimap = newWidget("Minimap")
Minimap._w, Minimap._h = 140, 140
function Minimap:GetCenter() return 1800, 950 end
GameTooltip = newWidget("GameTooltip")
GameTooltipText = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12 end }
function GameTooltip:AddLine(t) self._lines = self._lines or {}; self._lines[#self._lines + 1] = t end
function GameTooltip:AddDoubleLine(a, b) self._lines = self._lines or {}; self._lines[#self._lines + 1] = a .. "|" .. b end
function GameTooltip:SetOwner()
    self._lines = {}
    local cleared = self:GetScript("OnTooltipCleared")
    if cleared then cleared(self) end
end
function GameTooltip:NumLines() return #(self._lines or {}) end
GameTooltip._left = {}
function GameTooltip:GetLeftLine(i)
    self._left[i] = self._left[i] or self:CreateFontString()
    return self._left[i]
end
function GameTooltip:IsOwned() return true end
function GameTooltip:SetMinimumWidth(v) self._minWidth = v end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) M.chat[#M.chat + 1] = m end }
SlashCmdList = {}
UISpecialFrames = {}
tinsert = table.insert
StaticPopupDialogs = {}
function StaticPopup_Show(which, a) M.popups[#M.popups + 1] = { which = which, text = StaticPopupDialogs[which].text, arg = a } end
C_Timer = { After = function(_, fn) M.timers[#M.timers + 1] = fn end }
-- Atlases this client has; the ornate ring is missing on purpose.
M.atlases = { ["communities-ring-gold"] = true }
C_Texture = { GetAtlasInfo = function(a) if M.atlases[a] then return { width = 64, height = 64 } end end }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
InterfaceOptions_AddCategory = function(panel) M.registered[#M.registered + 1] = panel.name end

M.locale = "enUS"
function GetLocale() return M.locale end
M.build = { "1.60.1", "70009", "Sep 25 2026", 16001 }
function GetBuildInfo() return M.build[1], M.build[2], M.build[3], M.build[4] end
M.state = { combat = false, time = 1000, level = 43, faction = "Alliance", class = "WARLOCK", sex = 2 }
function InCombatLockdown() return M.state.combat end
function RegisterStateDriver(f, kind, rule)
    f._driver = rule
    if kind == "visibility" then f:SetShown(not (M.state.combat and rule:find("[combat] hide", 1, true))) end
end
function UnregisterStateDriver(f) f._driver = nil end
function GetTime() return M.state.time end
date = os.date
time = os.time
function GetMoney() return M.state.money or 0 end

-- The player, gear and items ------------------------------------------------
M.state = { level = 60, class = "PRIEST", combat = false, worn = {}, loaded = {} }
M.locale = "enUS"
M.build = { "1.60.1", "70938", "", 16001 }
M.state.time = 0
function GetLocale() return M.locale end
function GetBuildInfo() return M.build[1], M.build[2], M.build[3], M.build[4] end
function InCombatLockdown() return M.state.combat end
function GetTime() return M.state.time end
function UnitLevel() return M.state.level end
function UnitClass() return "Class", M.state.class end
function UnitFactionGroup() return "Alliance" end
function GetCursorPosition() return 0, 0 end
function GetMinimapShape() return "ROUND" end
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
Enum = { ItemClass = { Armor = 4, Weapon = 2 } }

-- Items: id -> { name, quality, ilvl, reqLevel, equipLoc, classID, subClassID, stats }.
M.items = {}
M.requested = {}
C_Item = {
    GetItemInfoInstant = function(id)
        local it = M.items[id]
        if not it then return nil end
        return id, "Armor", "Cloth", it.equipLoc, "ICON" .. id, it.classID, it.subClassID
    end,
    GetItemInfo = function(id)
        local it = M.items[id]
        if not it or it.uncached then return nil end
        return it.name, "|Hitem:" .. id .. "|h[" .. it.name .. "]|h", it.quality, it.ilvl, it.reqLevel
    end,
    GetItemStats = function(link)
        local id = tonumber(tostring(link):match("item:(%d+)"))
        return id and M.items[id] and M.items[id].stats or nil
    end,
    RequestLoadItemDataByID = function(id) M.requested[#M.requested + 1] = id end,
    GetItemCount = function(id) return M.state.bags and M.state.bags[id] or 0 end,
    GetItemNameByID = function(id)
        local it = M.items[id]
        return it and not it.uncached and it.name or nil
    end,
    GetItemIconByID = function(id) return "ICON" .. id end,
    GetItemQualityByID = function(id) return M.items[id] and M.items[id].quality end,
}
-- Where the player is: M.state.instance = { name, kind, id } (nil: outside).
function GetInstanceInfo()
    local i = M.state.instance
    if not i then return "Azeroth", "none", 0, "", 0, 0, false, 0 end
    return i.name, i.kind, 1, "", 5, 0, false, i.id
end
-- Tooltip lines: an item's `tip` list of left texts.
C_TooltipInfo = { GetItemByID = function(id)
    local it = M.items[id]
    if not it then return nil end
    local lines = { { leftText = it.name } }
    for _, t in ipairs(it.tip or {}) do lines[#lines + 1] = { leftText = t } end
    return { lines = lines }
end }
ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONPROC = "Use:", "Equip:", "Chance on hit:"
function GetInventoryItemLink(_, slot)
    local id = M.state.worn[slot]
    return id and ("|Hitem:" .. id .. "|h[x]|h") or nil
end
function IsModifiedClick() return false end
function HandleModifiedItemClick(link) M.linked = link end
C_Map = { GetAreaInfo = function(id) return "Area" .. id end,
    GetMapInfo = function(id) return { name = "Map" .. id } end,
    GetMapArtLayers = function(id)
        if id ~= 1436 then return nil end
        return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } }
    end,
    GetMapArtLayerTextures = function(id)
        if id ~= 1436 then return nil end
        local t = {}
        for i = 1, 12 do t[i] = 270000 + i end
        return t
    end,
}

-- AtlasLoot ------------------------------------------------------------------
M.addons = { AtlasLootClassic = true }
C_AddOns = {
    IsAddOnLoaded = function(name) return M.addons[name] == true end,
    LoadAddOn = function(name)
        if name == "AtlasLootClassic_Crafting" and M.addons.AtlasLootClassic then
            M.addons[name] = true
            AtlasLoot.ItemDB.Storage[name] = M.crafting
            return true
        end
        if name == "AtlasLootClassic_Collections" and M.addons.AtlasLootClassic and M.world then
            M.addons[name] = true
            AtlasLoot.ItemDB.Storage[name] = { WorldEpics = M.world }
            return true
        end
        if name == "AtlasLootClassic_DungeonsAndRaids" and M.addons.AtlasLootClassic then
            M.addons[name] = true
            return true
        end
        return false
    end,
    GetAddOnMetadata = function() return "0.1.0" end,
}
local TYPES = { { "Dungeons" }, { "40 Raids" }, { "Forever Dungeons" } }
local module = { GetContentTypes = function() return TYPES end }
AtlasLoot = {
    Locales = setmetatable({}, { __index = function(_, k) return k end }),
    ItemDB = { Storage = { AtlasLootClassic_DungeonsAndRaids = module } },
    Data = { Droprate = { GetData = function(_, npc, item) return npc == 1 and item == 101 and 12.5 or nil end } },
}
M.atlas = module
-- Crafting: a profession's recipes as spell ids; Profession data per spell.
M.crafting = { Tailoring = { name = "Tailoring", items = { { name = "Robes", [1] = { { 1, 7001 }, { 2, 7002 }, { 3, 7003 } } } } } }
M.professions = { [7001] = { 150, 8, 250, 260, 280, { 14047, 14341 }, { 6, 1 } },
    [7003] = { 151, 8, 300, 300, 300, { 14047 }, { 4 } } }
-- The character's skill lines by id (rank), handed-in quests.
-- The character's skill lines by name -> rank, in the skills window's order (a header first).
M.skills, M.questsDone = { Tailoring = 300 }, {}
C_SkillInfo = {
    GetNumSkillLines = function()
        M.skillList = { { name = "Professions", isHeader = true } }
        for name, rank in pairs(M.skills) do M.skillList[#M.skillList + 1] = { name = name, rank = rank } end
        return #M.skillList
    end,
    GetSkillLineInfo = function(i) return M.skillList[i] end,
}
ITEM_MIN_SKILL = "Requires %s (%d)"
C_QuestLog = C_QuestLog or {}
C_QuestLog.IsQuestFlaggedCompleted = function(id) return M.questsDone[id] == true end
AtlasLoot.Data.Profession = { GetProfessionData = function(id) return M.professions[id] end }

-- The character window's slot buttons.
for _, n in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
    "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged" }) do
    CreateFrame("Button", "Character" .. n .. "Slot")
end

return M
