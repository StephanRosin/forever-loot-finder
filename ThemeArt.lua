local ADDON, ns = ...

--[[---------------------------------------------------------------------------
ThemeArt.lua -- a window under a theme (the Data Bar's gold window): the
theme's backdrop with the theme's background colour over it, the rim on
every side, the title bar's colour and Pitwall's wedge in it; under Classic
the options window's flat look.
-----------------------------------------------------------------------------]]
local ThemeArt = {}
ns.ThemeArt = ThemeArt

local Lib = LibForeverThemes

function ThemeArt.BuildWindow(frame, titleBar)
    frame.themeBack = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    frame.themeBack:SetAllPoints(frame)
    frame.bodyFill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    frame.bodyFill:SetAllPoints(frame)
    frame.rims = {}
    for i = 1, 4 do frame.rims[i] = frame:CreateTexture(nil, "BORDER", nil, 1) end
    titleBar.fill = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.fill:SetAllPoints(titleBar)
    titleBar.wedge = titleBar:CreateTexture(nil, "OVERLAY", nil, 6)
end

local function paintBack(back, art)
    if not art.back then
        back:Hide()
        return
    end
    back:SetTexture(Lib.Texture(ns.Themes.Back(art)), "REPEAT", "REPEAT")
    if back.SetHorizTile then
        back:SetHorizTile(true)
        back:SetVertTile(true)
    end
    local tint = ns.Themes.Tint(art) or { 1, 1, 1, 1 }
    back:SetVertexColor(tint[1], tint[2], tint[3], tint[4])
    back:Show()
end

local function paintRims(rims, frame, c, size)
    local sides = { { "TOPLEFT", "TOPRIGHT", "SetHeight" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
        { "TOPLEFT", "BOTTOMLEFT", "SetWidth" }, { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" } }
    for i, side in ipairs(sides) do
        local t = rims[i]
        t:ClearAllPoints()
        t:SetPoint(side[1], frame, side[1], 0, 0)
        t:SetPoint(side[2], frame, side[2], 0, 0)
        t[side[3]](t, size)
        t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    end
end

local function paintWedge(wedge, frame, art, height)
    if art.wedge then
        wedge:ClearAllPoints()
        wedge:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        wedge:SetSize(height, height)
        wedge:SetTexture(Lib.Texture(art.wedge))
        wedge:SetTexCoord(0, Lib.WEDGE_PART, 0, 1)
        local c = ns.Themes.WedgeColor(art)
        wedge:SetVertexColor(c[1], c[2], c[3], c[4])
    end
    wedge:SetShown(art.wedge ~= nil)
end

-- Where a title starts in a bar height high: past the theme's wedge, nil
-- without one.
function ThemeArt.TextStart(height)
    local art = ns.Themes.Art()
    if not (art and art.wedge) then return nil end
    return Lib.WedgeReach(height, height / 2) + Lib.TITLE_GAP
end

function ThemeArt.WindowRim()
    local art = ns.Themes.Art()
    return art and art.rimSize or 1
end

-- Cards (rows, chips): the options' panel under Classic; dark on Swiss and
-- Pitwall's black; a light shade elsewhere.
local CARD_SOLID, CARD_SHADE = { 0, 0, 0, 0.85 }, { 0, 0, 0, 0.3 }
function ThemeArt.CardColour()
    local art = ns.Themes.Art()
    if not art then return ns.Style.COLORS.panel end
    return art.strip and CARD_SOLID or CARD_SHADE
end

function ThemeArt.StyleWindow(frame, titleBar)
    local art = ns.Themes.Art()
    if not art then
        local C = ns.Style.COLORS
        frame.themeBack:Hide()
        frame.bodyFill:SetColorTexture(unpack(C.bg))
        paintRims(frame.rims, frame, C.border, 1)
        titleBar.fill:SetColorTexture(unpack(C.panel))
        titleBar.fill:Show()
        titleBar.wedge:Hide()
        return
    end
    paintBack(frame.themeBack, art)
    local bg = art.bg
    frame.bodyFill:SetColorTexture(bg[1], bg[2], bg[3], art.alpha / 100)
    paintRims(frame.rims, frame, ns.Themes.Rim(art) or { 0, 0, 0, 1 }, ThemeArt.WindowRim())
    if art.strip then titleBar.fill:SetColorTexture(unpack(art.strip)) end
    titleBar.fill:SetShown(art.strip ~= nil)
    paintWedge(titleBar.wedge, titleBar, art, titleBar:GetHeight())
end
