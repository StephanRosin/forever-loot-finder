local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

--[[---------------------------------------------------------------------------
CharButtons.lua -- a small search button on every slot of the character
window: its tooltip counts the upgrades and alternatives for that slot, a
click opens the finder on it (Window.OpenSlot). Size, the point of the slot
it sits at and an offset are settings.

Own buttons, children of Blizzard's slot buttons (shown and hidden with
them); nothing of Blizzard's is hooked (in Forever hooksecurefunc on a
frame's methods takes them from Blizzard's own code).
-----------------------------------------------------------------------------]]
local CharButtons = {}
ns.CharButtons = CharButtons

CharButtons.POINTS = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
CharButtons.ICON = "Interface\\Common\\UI-Searchbox-Icon"

local buttons = {}

function CharButtons.Place()
    local size, point = S("charButtonSize"), S("charButtonPoint")
    for _, b in ipairs(buttons) do
        b:SetSize(size, size)
        b:ClearAllPoints()
        b:SetPoint("CENTER", b:GetParent(), point, S("charButtonX"), S("charButtonY"))
        b:SetShown(S("charButtons"))
    end
end

local function paint(b, hover)
    local a = ns.Themes.Accent()
    b.ring:SetVertexColor(a[1], a[2], a[3], hover and 1 or 0.85)
    b.icon:SetVertexColor(hover and 1 or 0.9, hover and 1 or 0.9, hover and 1 or 0.9, 1)
end

local function onEnter(b)
    paint(b, true)
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(L.CHAR_BUTTON_TIP)
    local ok = ns.Source.Load()
    if ok then
        local up, alt = ns.Filter.Count(b.slot.key, b.invSlot)
        GameTooltip:AddLine(L.CHAR_BUTTON_COUNT:format(up, alt), 0.3, 0.9, 0.4)
    end
    GameTooltip:Show()
end

local function onLeave(b)
    paint(b, false)
    GameTooltip:Hide()
end

local function make(parent, slot, invSlot)
    local b = CreateFrame("Button", nil, parent)
    -- Controller navigation would take it as one of the slots (blocked actions).
    if SmartNavigation_MarkFrameIgnored then SmartNavigation_MarkFrameIgnored(b) end
    b:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    b.ring = b:CreateTexture(nil, "BACKGROUND")
    b.ring:SetAllPoints()
    b.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    if b.ring.SetMask then b.ring:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.icon:SetTexture(CharButtons.ICON)
    b.slot, b.invSlot = slot, invSlot
    b:SetScript("OnEnter", onEnter)
    b:SetScript("OnLeave", onLeave)
    b:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        ns.Window.OpenSlot(self.slot.key, self.invSlot)
    end)
    paint(b, false)
    buttons[#buttons + 1] = b
    return b
end

function CharButtons.Create()
    if #buttons > 0 then return end
    for _, slot in ipairs(ns.Rules.SLOTS) do
        for i, name in ipairs(slot.frames) do
            local parent = _G[name]
            if parent then make(parent, slot, slot.inv[i]) end
        end
    end
    CharButtons.Place()
end

-- The tests.
function CharButtons.Buttons() return buttons end

Settings.OnChange(function(key)
    if key == nil or (key and key:find("^charButton")) then CharButtons.Place() end
    if key == nil or key == "theme" or key == "themeColors" then
        for _, b in ipairs(buttons) do paint(b, false) end
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() CharButtons.Create() end)
