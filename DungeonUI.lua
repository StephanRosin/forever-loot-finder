local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

--[[---------------------------------------------------------------------------
DungeonUI.lua -- "Upgrades: <instance>": a small window that opens by itself
on entering a dungeon or raid and lists what drops there and beats what the
player wears or carries (DungeonUpgrades.lua), best first. The spec is chosen
in it; a switch adds the alternatives under their own caption.

A row: icon, name in its quality's colour, slot and boss, and how many points
it brings over the owned item. Hover: the item with its bosses; click: the
item in the finder; shift-click: link; right-click: the shopping list.

The window is as high as its list, at most as high as the player made it.
Closed by hand it stays away until another instance is entered.
-----------------------------------------------------------------------------]]
local DungeonUI = {}
ns.DungeonUI = DungeonUI

local Rules, Items = ns.Rules, ns.Items
local UI -- ns.Window.UI, there once Window.lua has run

local TITLE, PAD, CHIP_H, GAP = 26, 8, 22, 6   -- CHIP_H: Window.lua's chips
local ROW, ROW_GAP, ICON, CAPTION = 36, 2, 28, 18
local TEXT_X, NAME_Y, WHERE_Y = (ROW - ICON) / 2 + ICON + 8, 5, 21   -- the row's two lines right of the icon
local DELTA_W, THUMB_W, THUMB_MIN, GRIP = 40, 2, 16, 16
local TOP = TITLE + GAP + CHIP_H + GAP          -- title, specs
local BOTTOM = GAP + CHIP_H + PAD               -- the switch and the count
local MESSAGE_H = 84                            -- the list's height with a message instead of rows
local MIN_W, MIN_H, MAX_W, MAX_H = 240, TOP + BOTTOM + ROW, 520, 800
local DEFAULT = { x = 40, y = -240, w = 300, h = TOP + BOTTOM + 6 * (ROW + ROW_GAP) - ROW_GAP }
local MAX_SPECS = 4
local WHEEL_ROWS = 2
local GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 },
    { 1, 0.5, 0 } }
local UP_COLOR, ALT_COLOR = { 0.3, 0.9, 0.4 }, { 1, 0.82, 0.2 }   -- Window.lua's verdicts

local frame
local items = {}          -- what the list shows: { entry = e } rows and one { caption = true }
local offset = 0
local loading, loadWhy    -- the loot tables: being read, or why they could not be
local current             -- the instance the player is in (its id or name), nil outside
local sizing = false

local function ui()
    UI = UI or ns.Window.UI
    return UI
end

-- Position, size and the instance it was closed in: ForeverLootFinderDB.dungeonWindow.
local function store()
    local db = ns.DB()
    db.dungeonWindow = db.dungeonWindow or {}
    return db.dungeonWindow
end

local function ownClass() return select(2, UnitClass("player")) end
local function specAt(i) return (Rules.SPECS[ownClass()] or {})[i] end
local function specLabel(spec) return spec and L[Rules.SpecLabelKey(ownClass(), spec)] or "" end

-- As in the finder: a tank spec turns "best armour only" on.
local function setSpec(spec)
    if spec.role == "TANK" and Rules.HasArmorChoice(ownClass()) and not S("filterBestArmor") then
        Settings.Set("filterBestArmor", true)
    end
    Settings.SetSpec(spec.id)
end

-- The loot tables load once, never in combat (AtlasLoot's modules are loaded on demand).
local function needSource()
    if ns.Source.Ready() or loading or loadWhy == "NONE" then return end
    if InCombatLockdown() then
        loadWhy = "COMBAT"
        return
    end
    loading, loadWhy = true, nil
    ns.Source.LoadAsync(function(ok, why)
        loading, loadWhy = false, not ok and why or nil
        DungeonUI.Refresh()
    end)
end

-- Rows ------------------------------------------------------------------------

local function percent(chance)
    return ("%g %%"):format(math.floor(chance * 10 + 0.5) / 10)
end

-- "Chest · Warden Calder · 12 %  (+1)": the slot, the first boss, how many more.
local function whereText(entry)
    local parts = { L["SLOT_" .. entry.slot.key] }
    local d = entry.drops[1]
    if d then
        parts[#parts + 1] = d.killed and L.DUNGEON_KILLED:format(d.boss) or d.boss
        if d.chance then parts[#parts + 1] = percent(d.chance) end
    end
    local more = #entry.drops > 1 and ("  (+%d)"):format(#entry.drops - 1) or ""
    return table.concat(parts, " · ") .. more
end

-- The item in the finder: its slot against what is worn, its row opened.
local function openInFinder(entry)
    ns.Window.OpenSlot(entry.slot.key, entry.slot.inv[1])
    for i, e in ipairs(ns.Window.Entries()) do
        if e.item.id == entry.item.id then return ns.Window.OpenEntry(i) end
    end
end

local function rowTooltip(row)
    local e = row.entry
    -- Away from the screen's edge the window sits at.
    local rightHalf = (row:GetCenter() or 0) > UIParent:GetWidth() / 2
    GameTooltip:SetOwner(row, rightHalf and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(e.item.link or ("item:" .. e.item.id))
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.DUNGEON_TIP_DROPS, 1, 0.82, 0)
    for _, d in ipairs(e.drops) do
        local c = d.killed and 0.5 or 1
        GameTooltip:AddDoubleLine(d.killed and L.DUNGEON_KILLED:format(d.boss) or d.boss,
            d.chance and percent(d.chance) or "", c, c, c, 0.7, 0.7, 0.7)
    end
    GameTooltip:AddLine(" ")
    if e.verdict == "UPGRADE" and e.delta then
        GameTooltip:AddLine(L.DUNGEON_TIP_UP:format(math.floor(e.delta + 0.5), specLabel(Rules.SpecOf(ownClass()))),
            UP_COLOR[1], UP_COLOR[2], UP_COLOR[3], true)
    else
        GameTooltip:AddLine(L.DUNGEON_TIP_ALT, ALT_COLOR[1], ALT_COLOR[2], ALT_COLOR[3], true)
    end
    GameTooltip:AddLine(L.DUNGEON_TIP_CLICK, 0.6, 0.6, 0.6)
    GameTooltip:AddLine(L.CLICK_HINT, 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

local function newRow(parent)
    local U = ui()
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.back = U.fill(row, "BACKGROUND")
    row.back:SetAllPoints()
    row.hover = U.fill(row, "HIGHLIGHT")
    row.hover:SetAllPoints()
    row.hover:SetVertexColor(1, 1, 1, 0.06)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", row, "LEFT", (ROW - ICON) / 2, 0)
    row.iconFrame = CreateFrame("Frame", nil, row)
    row.iconFrame:SetAllPoints(row.icon)
    row.iconEdges = U.edges(row.iconFrame)
    -- The points over the owned item: the row's one loud thing.
    row.delta = U.Text(row, 15, "text", false)
    row.delta:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
    row.delta:SetJustifyH("RIGHT")
    row.name = U.Text(row, 12, "text", false)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -NAME_Y)
    row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(PAD + DELTA_W), -NAME_Y)
    row.where = U.Text(row, 10, "muted")
    row.where:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -WHERE_Y)
    row.where:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(PAD + DELTA_W), -WHERE_Y)
    row:SetScript("OnClick", function(self, button)
        local item = self.entry.item
        if button == "RightButton" then return ns.ShoppingUI.LootMenu(self, item.id) end
        if item.link and IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP"))
            and HandleModifiedItemClick then
            return HandleModifiedItemClick(item.link)
        end
        openInFinder(self.entry)
    end)
    row:SetScript("OnEnter", rowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function fillRow(row, entry)
    local U = ui()
    row.entry = entry
    local item = entry.item
    local q = QUALITY[item.quality or 1] or QUALITY[1]
    row.icon:SetTexture(item.icon or UNKNOWN_ICON)
    U.paintEdges(row.iconEdges, q, item.loaded and 1 or 0.3)
    -- Not in the client's cache yet: asked for, Items.OnLoaded brings it.
    row.name:SetText(item.name or (Items.NoData(item) and L.ITEM_ID:format(item.id)) or L.LOADING)
    U.paintText(row.name, nil, item.loaded and q or U.colour("muted"))
    row.where:SetText(whereText(entry))
    -- An alternative without points is one whose effect cannot be weighed.
    local d = entry.delta and math.floor(entry.delta + 0.5)
    row.delta:SetText(not d and "–" or d == 0 and "±0" or ("%+d"):format(d))
    U.paintText(row.delta, nil, entry.verdict == "UPGRADE" and UP_COLOR or ALT_COLOR)
    local card = ns.ThemeArt.CardColour()
    row.back:SetVertexColor(card[1], card[2], card[3], card[4])
    -- Its boss is dead in this run: greyed, still there (another run, another chance).
    row.icon:SetDesaturated(entry.killed == true)
    row.name:SetAlpha(entry.killed and 0.45 or 1)
    row.where:SetAlpha(entry.killed and 0.6 or 1)
    row.delta:SetAlpha(entry.killed and 0.45 or 1)
    row.iconFrame:SetAlpha(entry.killed and 0.4 or 1)
    if entry.killed then U.paintText(row.delta, "muted") end
end

-- The list ----------------------------------------------------------------------

-- The entries as the list's lines: the upgrades (they come first), then the
-- alternatives under their caption.
local function lines(entries)
    local list, captioned = {}, false
    for _, e in ipairs(entries) do
        if e.verdict ~= "UPGRADE" and not captioned then
            captioned = true
            list[#list + 1] = { caption = true, h = CAPTION }
        end
        list[#list + 1] = { entry = e, h = ROW }
    end
    return list
end

local function heightFrom(first)
    local h = 0
    for i = first, #items do h = h + items[i].h + ROW_GAP end
    return math.max(0, h - ROW_GAP)
end

-- The furthest the list scrolls: its end at the list's bottom.
local function maxOffset(height)
    local o = #items
    while o > 0 and heightFrom(o) <= height do o = o - 1 end
    return o
end

local function draw()
    local U = ui()
    local list = frame.list
    local height = frame:GetHeight() - TOP - BOTTOM
    offset = math.max(0, math.min(offset, maxOffset(height)))
    local y, n, shown = 0, 0, 0
    list.caption:Hide()
    for i = offset + 1, #items do
        if y >= height then break end
        local line = items[i]
        local f = list.caption
        if line.entry then
            n = n + 1
            f = list.rows[n] or newRow(list)
            list.rows[n] = f
            fillRow(f, line.entry)
        end
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        f:SetPoint("TOPRIGHT", list, "TOPRIGHT", -(THUMB_W + 2), -y)
        f:Show()
        y = y + line.h + ROW_GAP
        if y - ROW_GAP <= height then shown = shown + 1 end
    end
    for i = n + 1, #list.rows do list.rows[i]:Hide() end
    local a = U.colour("accent")
    list.thumb:SetVertexColor(a[1], a[2], a[3], 0.8)
    local more = #items > shown and shown > 0
    list.thumb:SetShown(more)
    if more then
        local size = math.max(THUMB_MIN, height * shown / #items)
        list.thumb:SetHeight(size)
        list.thumb:ClearAllPoints()
        list.thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -(height - size) * offset / math.max(1, maxOffset(height)))
    end
end

-- The window -------------------------------------------------------------------

local function place()
    local db = store()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", db.x or DEFAULT.x, db.y or DEFAULT.y)
    frame:SetWidth(math.max(frame.minWidth or MIN_W, db.w or DEFAULT.w))
end

local function save()
    local db = store()
    db.x = math.floor(frame:GetLeft() + 0.5)
    db.y = math.floor(frame:GetTop() - UIParent:GetHeight() + 0.5)
    db.w = math.floor(frame:GetWidth() + 0.5)
    db.h = math.floor(frame:GetHeight() + 0.5)
end

-- As high as the list, at most as the player sized it; a message has its own height.
local function fit()
    local chrome = TOP + BOTTOM
    if #items == 0 then return frame:SetHeight(chrome + MESSAGE_H) end
    frame:SetHeight(math.max(MIN_H, math.min(store().h or DEFAULT.h, chrome + heightFrom(1))))
end

-- The specs as one bar; the window is never narrower than it.
local function layoutSpecs()
    local x = PAD
    for i, chip in ipairs(frame.specs) do
        chip:SetShown(specAt(i) ~= nil)
        if specAt(i) then
            chip:Relabel()
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(TITLE + GAP))
            x = x + chip:GetWidth() - 1   -- shared edges
        end
    end
    frame.alt:Relabel()
    frame.minWidth = math.max(MIN_W, x + 1 + PAD)
    if frame.SetResizeBounds then frame:SetResizeBounds(frame.minWidth, MIN_H, MAX_W, MAX_H) end
end

local function tip(owner, title, text)
    owner:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function build()
    local U = ui()
    frame = CreateFrame("Frame", "ForeverLootFinderDungeon", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    frame:EnableMouse(true)
    frame.bar = CreateFrame("Frame", nil, frame)
    frame.bar:SetHeight(TITLE)
    frame.bar:SetPoint("TOPLEFT"); frame.bar:SetPoint("TOPRIGHT")
    frame.bar:EnableMouse(true)
    frame.bar:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then frame:StartMoving() end end)
    frame.bar:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        local h = store().h   -- moved, not sized: the height is the list's, not the player's
        save()
        store().h = h
        place()
    end)
    ns.ThemeArt.BuildWindow(frame, frame.bar)
    frame.close = U.closeButton(frame.bar, function() DungeonUI.Close() end)
    frame.close:SetSize(TITLE, TITLE)
    tip(frame.close, L.DUNGEON_CLOSE, L.DUNGEON_CLOSE_TIP)
    frame.title = U.Text(frame.bar, 13, "title")

    frame.specs = {}
    for i = 1, MAX_SPECS do
        frame.specs[i] = U.Chip(frame, function() return specLabel(specAt(i)) end,
            function() local s = specAt(i); return s ~= nil and Rules.SpecOf(ownClass()).id == s.id end,
            function(on) local s = specAt(i); if on and s then setSpec(s) end end, { segment = true })
    end

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOP)
    list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, BOTTOM)
    if list.SetClipsChildren then list:SetClipsChildren(true) end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * WHEEL_ROWS
        draw()
    end)
    list.rows = {}
    list.caption = CreateFrame("Frame", nil, list)
    list.caption:SetHeight(CAPTION)
    list.caption.text = U.Text(list.caption, 10, "muted")
    list.caption.text:SetPoint("LEFT", list.caption, "LEFT", 2, 0)
    list.caption.rule = U.fill(list.caption, "ARTWORK")
    list.caption.rule:SetHeight(1)
    list.caption.rule:SetPoint("LEFT", list.caption.text, "RIGHT", GAP, 0)
    list.caption.rule:SetPoint("RIGHT", list.caption, "RIGHT", 0, 0)
    list.thumb = U.fill(list, "OVERLAY")
    list.thumb:SetWidth(THUMB_W)
    list.message = U.Text(list, 11, "muted")
    list.message:SetPoint("TOPLEFT", list, "TOPLEFT", GAP, -GAP)
    list.message:SetPoint("TOPRIGHT", list, "TOPRIGHT", -GAP, -GAP)
    list.message:SetWordWrap(true)
    list.message:SetJustifyH("CENTER")
    frame.list = list

    frame.alt = U.Chip(frame, function() return L.FILTER_ALTERNATIVES end,
        function() return S("dungeonAlternatives") end, function(on) Settings.Set("dungeonAlternatives", on) end)
    frame.alt:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD)
    tip(frame.alt, L.FILTER_ALTERNATIVES, L.DUNGEON_ALT_TIP)
    frame.count = U.Text(frame, 10, "muted")
    frame.count:SetPoint("LEFT", frame.alt, "RIGHT", GAP, 0)
    frame.count:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -(GRIP + 2), PAD + CHIP_H / 2)
    frame.count:SetJustifyH("RIGHT")

    frame.grip = CreateFrame("Button", nil, frame)
    frame.grip:SetSize(GRIP, GRIP)
    frame.grip:SetPoint("BOTTOMRIGHT")
    frame.grip:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.grip:SetNormalTexture(GRIP_TEXTURE)
    frame.grip:SetScript("OnMouseDown", function()
        sizing = true
        frame:StartSizing("BOTTOMRIGHT")
    end)
    frame.grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        sizing = false
        save()
        place()
        DungeonUI.Refresh()
    end)
    -- While it is dragged: the rows follow; the height is fitted again on release.
    frame:SetScript("OnSizeChanged", function() if sizing then draw() end end)
    frame:Hide()
end

local function countText(up, alt)
    local parts = {}
    if up > 0 then parts[#parts + 1] = up == 1 and L.DUNGEON_COUNT_UP_1 or L.DUNGEON_COUNT_UP:format(up) end
    if alt > 0 then parts[#parts + 1] = alt == 1 and L.DUNGEON_COUNT_ALT_1 or L.DUNGEON_COUNT_ALT:format(alt) end
    return table.concat(parts, " · ")
end

-- What stands in place of the rows: where the player is not, what is loading, why nothing is listed.
local function message(here, entries)
    if not here then return L.DUNGEON_OUTSIDE end
    if not ns.Source.Ready() then return loading and L.LOADING_TABLES or L["SOURCE_" .. (loadWhy or "NONE")] end
    if #entries > 0 then return "" end
    local text = L.DUNGEON_EMPTY:format(specLabel(Rules.SpecOf(ownClass())))
    if not S("dungeonAlternatives") then text = text .. "|n|n" .. L.DUNGEON_EMPTY_HINT end
    return text
end

-- Reads the list anew and draws it; after anything it depends on changed.
function DungeonUI.Refresh()
    if not (frame and frame:IsShown()) then return end
    local U = ui()
    local here = ns.Source.Here()
    if here then needSource() end
    local entries = ns.DungeonUpgrades.List(S("dungeonAlternatives"))
    items = lines(entries)
    local up = 0
    for _, e in ipairs(entries) do if e.verdict == "UPGRADE" then up = up + 1 end end

    frame.title:SetText(here and L.DUNGEON_TITLE:format(here.name) or L.DUNGEON_TITLE_OUT)
    frame.list.message:SetText(message(here, entries))
    frame.list.caption.text:SetText(L.FILTER_ALTERNATIVES)
    frame.count:SetText(#entries > 0 and countText(up, #entries - up) or "")
    for _, chip in ipairs(frame.specs) do U.paintChip(chip) end
    U.paintChip(frame.alt)
    if not sizing then fit() end
    draw()
end

-- The theme's art, fonts and colours; the labels in the language.
function DungeonUI.Restyle()
    if not frame then return end
    local U = ui()
    ns.ThemeArt.StyleWindow(frame, frame.bar)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT", frame.bar, "LEFT", ns.ThemeArt.TextStart(TITLE) or PAD, 0)
    frame.title:SetPoint("RIGHT", frame.close, "LEFT", 0, 0)
    local m = U.colour("muted")
    frame.list.caption.rule:SetVertexColor(m[1], m[2], m[3], 0.35)
    layoutSpecs()
    place()
    DungeonUI.Refresh()
end

function DungeonUI.Show()
    if not frame then build() end
    store().closed = nil
    offset = 0
    frame:Show()
    DungeonUI.Restyle()
end

-- Closed by the player: not back by itself in this instance.
function DungeonUI.Close()
    store().closed = current
    if frame then frame:Hide() end
end

function DungeonUI.Toggle()
    if DungeonUI.IsShown() then DungeonUI.Close() else DungeonUI.Show() end
end

function DungeonUI.IsShown() return frame ~= nil and frame:IsShown() end
function DungeonUI.Frame() return frame end   -- the tests

-- Into another instance: the window opens (the setting, and not where it was
-- closed by hand); out of one: it goes.
local function arrive()
    local here = ns.Source.Here()
    local key = here and (here.id or here.name)
    if key == current then return end
    current = key
    if not key then
        if frame then frame:Hide() end
        return
    end
    if store().closed ~= key then
        store().closed = nil
        if S("dungeonUpgrades") then return DungeonUI.Show() end
    end
    DungeonUI.Refresh()   -- opened by hand before
end

Settings.OnChange(function(key)
    -- The theme (and a reset) restyles through Window.Restyle.
    if key == nil or key == "theme" or key == "themeColors" then return end
    DungeonUI.Refresh()
end)
Items.OnLoaded(function() DungeonUI.Refresh() end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")   -- the loot tables load once combat is over
events:RegisterEvent("BOSS_KILL")              -- a dead boss greys its loot (DungeonJournal logs it)
events:RegisterEvent("ENCOUNTER_END")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then return arrive() end
    if event == "BOSS_KILL" or event == "ENCOUNTER_END" then return C_Timer.After(1, DungeonUI.Refresh) end
    if event == "PLAYER_REGEN_ENABLED" then
        if loadWhy ~= "COMBAT" then return end
        loadWhy = nil
    end
    DungeonUI.Refresh()
end)
