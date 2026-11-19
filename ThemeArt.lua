local ADDON, ns = ...

--[[---------------------------------------------------------------------------
ThemeArt.lua -- a window under a theme (the Data Bar's gold window): the
theme's backdrop with the theme's background colour over it, the rim on
every side, the title bar's colour and Pitwall's wedge in it, a framed
theme's frame around the rim and its banner as the title bar; under Classic
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
    frame.frameStrips = {}
    for i = 1, 4 do frame.frameStrips[i] = frame:CreateTexture(nil, "BORDER", nil, 2) end
    titleBar.isBar = true
    titleBar.fill = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBar.fill:SetAllPoints(titleBar)
    titleBar.ends = {}
    for i = 1, 2 do titleBar.ends[i] = titleBar:CreateTexture(nil, "BACKGROUND") end
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

-- The frame's four strips around the window's outside, the top and bottom
-- ones across the corners; its material repeats at its own size.
local function paintFrame(strips, frame, art)
    for _, s in ipairs(strips) do s:SetShown(art.frame ~= nil) end
    if not art.frame then return end
    local o = art.frameSize
    local spots = {
        { "TOPLEFT", -o, o, "TOPRIGHT", o, 0 },
        { "BOTTOMLEFT", -o, 0, "BOTTOMRIGHT", o, -o },
        { "TOPLEFT", -o, 0, "BOTTOMLEFT", 0, 0 },
        { "TOPRIGHT", 0, 0, "BOTTOMRIGHT", o, 0 },
    }
    for i, s in ipairs(strips) do
        local p = spots[i]
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", frame, p[1], p[2], p[3])
        s:SetPoint("BOTTOMRIGHT", frame, p[4], p[5], p[6])
        s:SetTexture(Lib.Texture(art.frame), "REPEAT", "REPEAT")
        s:SetHorizTile(true)
        s:SetVertTile(true)
        s:SetVertexColor(1, 1, 1, 1)
    end
end

-- A banner end's width per height of the bar (the file is half as wide as high).
local BANNER_END = 0.5
-- A repeating banner (Goblin's warning stripes) is only a strip this high
-- along the top: text on the stripes would not read.
local STRIPE_H = 5

-- The title bar as the theme's banner: stretched between its two ends (the
-- right one mirrored), or the stripes along the top. True when drawn.
local function paintBanner(bar, art)
    local fill, ends = bar.fill, bar.ends
    local h = bar:GetHeight()
    local withEnds = art.banner ~= nil and art.bannerEnd ~= nil
    for i, e in ipairs(ends) do
        e:SetShown(withEnds)
        if withEnds then
            local point = i == 1 and "TOPLEFT" or "TOPRIGHT"
            e:ClearAllPoints()
            e:SetPoint(point, bar, point, 0, 0)
            e:SetSize(math.floor(h * BANNER_END + 0.5), h)
            e:SetTexture(Lib.Texture(art.bannerEnd))
            if i == 1 then e:SetTexCoord(0, 1, 0, 1) else e:SetTexCoord(1, 0, 0, 1) end
        end
    end
    local tile = art.bannerTile == true
    fill:SetHorizTile(tile)
    fill:SetVertTile(tile)
    if not art.banner then return false end
    local inset = withEnds and math.floor(h * BANNER_END + 0.5) or 0
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", inset, 0)
    fill:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -inset, 0)
    fill:SetHeight(tile and STRIPE_H or h)
    fill:SetTexture(Lib.Texture(art.banner), tile and "REPEAT" or nil, tile and "REPEAT" or nil)
    fill:SetTexCoord(0, 1, 0, 1)
    fill:SetVertexColor(1, 1, 1, 1)
    fill:Show()
    return true
end

-- Where a title starts in a bar height high: past the theme's wedge or the
-- banner's end, nil without either.
function ThemeArt.TextStart(height)
    local art = ns.Themes.Art()
    if art and art.banner and art.bannerEnd then return math.floor(height * BANNER_END + 0.5) end
    if not (art and art.wedge) then return nil end
    return Lib.WedgeReach(height, height / 2) + Lib.TITLE_GAP
end

function ThemeArt.WindowRim()
    local art = ns.Themes.Art()
    return art and art.rimSize or 1
end

-- A shade alpha strong under rows and fields: black, but on a light paper
-- (Azeroth) a faint brown, so the dark ink on it still reads.
local PAPER_SHADE, PAPER_ALPHA = { 0.36, 0.22, 0.08 }, 0.5
function ThemeArt.Shade(alpha)
    local art = ns.Themes.Art()
    if art and art.ink then return { PAPER_SHADE[1], PAPER_SHADE[2], PAPER_SHADE[3], alpha * PAPER_ALPHA } end
    return { 0, 0, 0, alpha }
end

-- Cards (rows, chips): the options' panel under Classic; dark on Swiss and
-- Pitwall's black; a light shade elsewhere.
local CARD_SOLID = { 0, 0, 0, 0.85 }
function ThemeArt.CardColour()
    local art = ns.Themes.Art()
    if not art then return ns.Style.COLORS.panel end
    return art.strip and CARD_SOLID or ThemeArt.Shade(0.3)
end

function ThemeArt.StyleWindow(frame, titleBar)
    local art = ns.Themes.Art()
    if not art then
        local C = ns.Style.COLORS
        frame.themeBack:Hide()
        frame.bodyFill:SetColorTexture(unpack(C.bg))
        paintRims(frame.rims, frame, C.border, 1)
        paintFrame(frame.frameStrips, frame, {})
        paintBanner(titleBar, {})
        titleBar.fill:ClearAllPoints()
        titleBar.fill:SetAllPoints(titleBar)
        titleBar.fill:SetColorTexture(unpack(C.panel))
        titleBar.fill:Show()
        titleBar.wedge:Hide()
        return
    end
    paintBack(frame.themeBack, art)
    local bg = art.bg
    frame.bodyFill:SetColorTexture(bg[1], bg[2], bg[3], art.alpha / 100)
    paintRims(frame.rims, frame, ns.Themes.Rim(art) or { 0, 0, 0, 1 }, ThemeArt.WindowRim())
    paintFrame(frame.frameStrips, frame, art)
    if paintBanner(titleBar, art) then
        titleBar.wedge:Hide()
        return
    end
    titleBar.fill:ClearAllPoints()
    titleBar.fill:SetAllPoints(titleBar)
    if art.strip then titleBar.fill:SetColorTexture(unpack(art.strip)) end
    titleBar.fill:SetShown(art.strip ~= nil)
    paintWedge(titleBar.wedge, titleBar, art, titleBar:GetHeight())
end
