--[[---------------------------------------------------------------------------
MinimapButton.lua -- a button on the map's edge: a click opens the finder,
a right-click the options;
dragged along the edge; switched off in the options.

Placed the way LibDBIcon places addon buttons, so it sits in line with
them: for the square map (GetMinimapShape answers "SQUARE") on a circle
clamped to the square's edges, a little outside. The art is a spyglass icon.
A plain button, fine in combat.
-----------------------------------------------------------------------------]]

local ADDON, ns = ...
local L = ns.L

local Button = {}
ns.MinimapButton = Button

Button.ICON = "Interface\\Icons\\INV_Misc_Spyglass_02"
local BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
local BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
local HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- LibDBIcon's layout: a 31 px button, the tracking border's ring at its
-- top left, the icon inside; its centre RADIUS_OUT outside the edge, a
-- square map's corner circle pulled in by CORNER_IN.
local SIZE, BORDER_SIZE, BACKGROUND_SIZE, ICON_SIZE = 31, 53, 20, 18
local RADIUS_OUT, CORNER_IN = 5, 10

-- Settings: minimapShow and minimapAngle (Settings.lua).
function Button.Get(field)
    return ns.Settings.Get(field == "show" and "minimapShow" or "minimapAngle")
end

function Button.Set(field, value)
    ns.Settings.Set(field == "show" and "minimapShow" or "minimapAngle", value)
    Button.Place()
end

-- The offset from the map's centre at angle degrees: on a circle for a
-- round map, clamped to the edges for a square one.
function Button.Offset(angle)
    local x, y = math.cos(math.rad(angle)), math.sin(math.rad(angle))
    local w = Minimap:GetWidth() / 2 + RADIUS_OUT
    local h = Minimap:GetHeight() / 2 + RADIUS_OUT
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "ROUND" then return x * w, y * h end
    local diagonalW = math.sqrt(2 * w * w) - CORNER_IN
    local diagonalH = math.sqrt(2 * h * h) - CORNER_IN
    return math.max(-w, math.min(x * diagonalW, w)), math.max(-h, math.min(y * diagonalH, h))
end

local function moveTo(button, angle)
    local x, y = Button.Offset(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Button.Place()
    local button = Button.button
    if not button then return end
    moveTo(button, Button.Get("angle"))
    button:SetShown(Button.Get("show"))
end

function Button.OnClick(_, mouse)
    if mouse == "RightButton" then ns.Options.Toggle() else ns.Window.Toggle() end
end

-- The cursor's angle around the map's centre, in whole degrees.
local function cursorAngle()
    local cx, cy = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    local angle = math.deg(math.atan2(py / scale - cy, px / scale - cx)) % 360
    return math.floor(angle + 0.5) % 360
end

local function followCursor(button)
    button.dragAngle = cursorAngle()
    moveTo(button, button.dragAngle)
end

local function showTooltip(button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_NAME)
    GameTooltip:AddLine(L.BUTTON_CLICK, 1, 1, 1)
    GameTooltip:AddLine(L.BUTTON_RIGHT, 1, 1, 1)
    GameTooltip:AddLine(L.BUTTON_DRAG, 1, 1, 1)
    GameTooltip:Show()
end

local function hideTooltip(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function texture(button, file, layer, size, x, y)
    local t = button:CreateTexture(nil, layer)
    t:SetTexture(file)
    t:SetSize(size, size)
    t:SetPoint("TOPLEFT", button, "TOPLEFT", x, y)
    return t
end

function Button.Create()
    if Button.button or not Minimap then return end
    -- The global name is what button collectors show for a button without
    -- LibDBIcon (Leatrix Plus: its tooltip), hence readable (reported); it
    -- ends in "Minimap" because Minimap Button Button collects only names
    -- like that (reported).
    local button = CreateFrame("Button", "Forever Loot Finder Minimap", Minimap)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(HIGHLIGHT, "ADD")
    button.background = texture(button, BACKGROUND, "BACKGROUND", BACKGROUND_SIZE, 7, -5)
    button.icon = texture(button, Button.ICON, "ARTWORK", ICON_SIZE, 6.5, -6)
    -- Round like the other addon buttons.
    if button.icon.SetTexCoord then button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    button.border = texture(button, BORDER, "OVERLAY", BORDER_SIZE, 0, 0)
    button:SetScript("OnClick", Button.OnClick)
    button:SetScript("OnEnter", showTooltip)
    button:SetScript("OnLeave", hideTooltip)
    button:SetScript("OnDragStart", function(self)
        hideTooltip(self)
        self:SetScript("OnUpdate", followCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.dragAngle then Button.Set("angle", self.dragAngle) end
        self.dragAngle = nil
    end)
    Button.button = button
    Button.Place()
    -- The map changes size: stay on its edge.
    -- HookScript, not hooksecurefunc: Forever hides hooked frame methods
    -- from Blizzard's code.
    Minimap:HookScript("OnSizeChanged", Button.Place)
end

-- Blizzard's addon compartment (the gear by the map) lists addons whose TOC
-- names these global functions: a click there opens the finder as well.
function ForeverLootFinder_OnAddonCompartmentClick()
    ns.Window.Toggle()
end

function ForeverLootFinder_OnAddonCompartmentEnter(_, menuButton)
    if not menuButton then return end
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_NAME)
    GameTooltip:AddLine(L.BUTTON_CLICK, 1, 1, 1)
    GameTooltip:Show()
end

function ForeverLootFinder_OnAddonCompartmentLeave(_, menuButton)
    if menuButton and GameTooltip:IsOwned(menuButton) then GameTooltip:Hide() end
end

-- The setting changed (options, profile switch, import): follow it.
ns.Settings.OnChange(function(key)
    if key == nil or key == "minimapShow" or key == "minimapAngle" then Button.Place() end
end)

ns.On("PLAYER_LOGIN", Button.Create)
