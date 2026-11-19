local ADDON, ns = ...
local L = ns.L

--[[
The shopping list on screen: a tab of the window, an add dialog (search from
three letters) and a sticky note that floats over the game like the
Quest Log's undocked task lists. A row: icon, "Name (origin)", in bags/goal;
ticked once enough are in the bags, framed where it can drop right now.
]]
local ShoppingUI = {}
ns.ShoppingUI = ShoppingUI

local Shopping = ns.Shopping
local UI -- ns.Window.UI, there once Window.lua has run

local TITLE_H, PAD, HEAD_H = 32, 12, 30
local PANEL_ROW, NOTE_ROW, ICON_GAP = 28, 22, 6
local NOTE_TITLE, NOTE_PAD, GRIP = 26, 8, 16
local NOTE_MIN_W, NOTE_MIN_H, NOTE_MAX_W, NOTE_MAX_H = 180, 80, 700, 900
local NOTE_DEFAULT = { shown = false, x = 300, y = -200, w = 280, h = 220 }
local DIALOG_W, FIELD_H, SUGGESTION_H = 360, 24, 22
local CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
local SORT_ICON = "Interface\\AddOns\\ForeverLootFinder\\Media\\IconSort"
local GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local DONE_COLOUR = { 0.3, 0.9, 0.4 }
local QUALITY = { [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000" }

local panel, note, dialog

local function ui()
    UI = UI or ns.Window.UI
    return UI
end

-- The loot tables give the origins and "drops here": loaded once, also for
-- a note shown right after login, before the window was ever opened.
local function needSource(after)
    if ns.Source.Ready() then return end
    ns.Source.LoadAsync(function() after() end)
end

-- Rows ------------------------------------------------------------------------

local function nameText(line)
    local colour = QUALITY[line.quality or 1] or QUALITY[1]
    local text = ("|c%s%s|r"):format(colour, line.name)
    if line.origin then text = text .. ("  |cff999999(%s)|r"):format(line.origin) end
    return text
end

local function newRow(parent, height, size)
    local U = ui()
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.back = U.fill(row, "BACKGROUND")
    row.back:SetAllPoints()
    -- The frame of an item that can drop where the player is.
    row.edges = U.edges(row)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(height - 6, height - 6)
    row.icon:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetSize(height - 4, height - 4)
    row.check:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.check:SetTexture(CHECK)
    row.count = U.Text(row, size, "text", false)
    row.count:SetPoint("RIGHT", row.check, "LEFT", -2, 0)
    row.count:SetJustifyH("RIGHT")
    row.name = U.Text(row, size, "text", false)
    row.name:SetPoint("LEFT", row.icon, "RIGHT", ICON_GAP, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -ICON_GAP, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ShoppingUI.EntryMenu(self, self.entry)
            return
        end
        local link = select(2, C_Item.GetItemInfo(self.entry.itemID))
        if link and IsModifiedClick and IsModifiedClick("CHATLINK") and HandleModifiedItemClick then
            HandleModifiedItemClick(link)
        end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.entry.itemID)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Custom order: drag a row onto another to put it there.
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
        if Shopping.Sort() ~= "custom" then return end
        self.dragging = true
        self:SetAlpha(0.4)
    end)
    row:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = nil
        self:SetAlpha(1)
        for _, other in ipairs(self.rows) do
            if other ~= self and other:IsShown() and other:IsMouseOver() then
                for i, e in ipairs(Shopping.Entries()) do
                    if e == other.entry then return Shopping.Move(self.entry.itemID, i) end
                end
            end
        end
    end)
    return row
end

local function fillRow(row, entry)
    local U = ui()
    row.entry = entry
    local line = Shopping.Line(entry)
    row.icon:SetTexture(line.icon)
    row.icon:SetDesaturated(line.done)
    row.name:SetText(nameText(line))
    row.name:SetAlpha(line.done and 0.55 or 1)
    row.count:SetText(("%d/%d"):format(line.have, line.goal))
    if line.done then
        row.count:SetTextColor(DONE_COLOUR[1], DONE_COLOUR[2], DONE_COLOUR[3])
    else
        U.paintText(row.count, "text")
    end
    row.check:SetShown(line.done)
    row.back:SetVertexColor(0, 0, 0, 0.25)
    U.paintEdges(row.edges, U.colour("accent"), line.here and not line.done and 0.95 or 0)
end

-- Rows of a list into a frame from offset on, as many as fit; returns how many there are.
local function layoutRows(holder, rows, height, gap, offset, make)
    local entries = Shopping.Sorted()
    local fit = math.max(1, math.floor((holder:GetHeight() + gap) / (height + gap)))
    for i = 1, fit do
        local entry = entries[offset + i]
        local row = rows[i]
        if entry then
            if not row then
                row = make()
                row.rows = rows
                rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(i - 1) * (height + gap))
            row:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -(i - 1) * (height + gap))
            fillRow(row, entry)
            row:Show()
        elseif row then
            row:Hide()
        end
    end
    for i = fit + 1, #rows do rows[i]:Hide() end
    return #entries
end

local function doneCount()
    local done, entries = 0, Shopping.Entries()
    for _, e in ipairs(entries) do
        if Shopping.Line(e).done then done = done + 1 end
    end
    return done, #entries
end

-- Menus -----------------------------------------------------------------------

function ShoppingUI.LootMenu(owner, id)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if Shopping.Has(id) then
            root:CreateButton(L.SHOP_REMOVE, function() Shopping.Remove(id) end)
        else
            root:CreateButton(L.SHOP_ADD_THIS, function() Shopping.Add(id) end)
        end
    end)
end

-- The sticky note's sort button: the order to show.
function ShoppingUI.SortMenu(owner)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(L.SHOP_SORT)
        for _, mode in ipairs(Shopping.SORTS) do
            root:CreateRadio(L["SHOP_SORT_" .. mode:upper()], function() return Shopping.Sort() == mode end,
                function() Shopping.SetSort(mode) end)
        end
    end)
end

function ShoppingUI.EntryMenu(owner, entry)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateButton(L.SHOP_REMOVE, function() Shopping.Remove(entry.itemID) end)
    end)
end

-- The add dialog --------------------------------------------------------------
-- One field to search (from three letters); arrows pick a suggestion, Enter
-- takes it, once (an item already listed stays as it is).

local function field(parent, width)
    local U = ui()
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width, FIELD_H)
    box:SetAutoFocus(false)
    box:SetTextInsets(6, 6, 0, 0)
    box.back = U.fill(box, "BACKGROUND")
    box.back:SetAllPoints()
    box.back:SetVertexColor(0, 0, 0, 0.45)
    box.edges = U.edges(box)
    box:SetFontObject(ChatFontNormal)
    box:SetScript("OnEscapePressed", function() dialog:Hide() end)
    return box
end

local function take(id)
    if not id then return end
    Shopping.Add(id)
    dialog:Hide()
end

local function paintSuggestions()
    local U = ui()
    for i, b in ipairs(dialog.buttons) do
        U.paintEdges(b.edges, U.colour("accent"), i == dialog.selected and 0.9 or 0)
    end
end

local function suggest()
    local results = Shopping.Search(dialog.search:GetText())
    dialog.results = results
    dialog.selected = #results > 0 and math.min(dialog.selected or 1, #results) or nil
    for i, b in ipairs(dialog.buttons) do
        local r = results[i]
        b.id = r and r.id
        if r then
            b.icon:SetTexture(ns.Items.Get(r.id).icon)
            local listed = Shopping.Has(r.id)
            b.text:SetText(nameText({ name = r.name, quality = r.quality,
                origin = Shopping.Origin(r.id) }) .. (listed and ("  |cff999999– %s|r"):format(L.SHOP_LISTED) or ""))
            b:SetAlpha(listed and 0.55 or 1)
        end
        b:SetShown(r ~= nil)
    end
    local short = #(dialog.search:GetText() or "") < Shopping.MIN_SEARCH
    dialog.hint:SetText(short and L.SHOP_SEARCH_HINT or #results == 0 and L.SHOP_NOTHING or "")
    dialog:SetHeight(dialog.base + math.max(#results, 1) * SUGGESTION_H)
    paintSuggestions()
end

local function buildDialog()
    local U = ui()
    dialog = CreateFrame("Frame", "ForeverLootFinderShoppingAdd", UIParent)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:SetClampedToScreen(true)
    dialog:SetWidth(DIALOG_W)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    dialog.bar = CreateFrame("Frame", nil, dialog)
    dialog.bar:SetHeight(TITLE_H)
    dialog.bar:SetPoint("TOPLEFT"); dialog.bar:SetPoint("TOPRIGHT")
    ns.ThemeArt.BuildWindow(dialog, dialog.bar)
    dialog.title = U.Text(dialog.bar, 15, "title")
    dialog.bar.close = U.closeButton(dialog.bar, function() dialog:Hide() end)

    dialog.search = field(dialog, DIALOG_W - 2 * PAD)
    dialog.search:SetPoint("TOPLEFT", dialog, "TOPLEFT", PAD, -(TITLE_H + 10))
    dialog.search:SetJustifyH("LEFT")
    dialog.hint = U.Text(dialog, 11, "muted")
    dialog.hint:SetPoint("TOPLEFT", dialog.search, "BOTTOMLEFT", 0, -8)
    dialog.base = TITLE_H + 10 + FIELD_H + 8 + PAD

    dialog.buttons = {}
    for i = 1, Shopping.MAX_RESULTS do
        local b = CreateFrame("Button", nil, dialog)
        b:SetHeight(SUGGESTION_H)
        b:SetPoint("TOPLEFT", dialog.search, "BOTTOMLEFT", 0, -6 - (i - 1) * SUGGESTION_H)
        b:SetPoint("TOPRIGHT", dialog.search, "BOTTOMRIGHT", 0, -6 - (i - 1) * SUGGESTION_H)
        b.edges = U.edges(b)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(SUGGESTION_H - 4, SUGGESTION_H - 4)
        b.icon:SetPoint("LEFT", b, "LEFT", 2, 0)
        b.text = U.Text(b, 12, "text", false)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", ICON_GAP, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function(self) take(self.id) end)
        b:SetScript("OnEnter", function(self)
            dialog.selected = i
            paintSuggestions()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.id)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        dialog.buttons[i] = b
    end

    local function enter()
        local r = dialog.results[dialog.selected or 0]
        take(r and r.id)
    end
    dialog.search:SetScript("OnTextChanged", function(_, typed)
        if typed then dialog.selected = 1 end
        suggest()
    end)
    dialog.search:SetScript("OnEnterPressed", enter)
    dialog.search:SetScript("OnKeyDown", function(_, key)
        local n = #(dialog.results or {})
        if n == 0 then return end
        if key == "DOWN" then dialog.selected = (dialog.selected or 0) % n + 1
        elseif key == "UP" then dialog.selected = ((dialog.selected or 1) - 2) % n + 1
        else return end
        paintSuggestions()
    end)
    -- Items the finder asked for arrive: the suggestions follow.
    ns.Items.OnLoaded(function() if dialog:IsShown() then suggest() end end)
    dialog:SetScript("OnHide", function() dialog.search:ClearFocus() end)
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverLootFinderShoppingAdd") end
    ShoppingUI.Restyle()
end

function ShoppingUI.OpenAdd()
    if not dialog then buildDialog() end
    needSource(function() if dialog:IsShown() then suggest() end end)
    dialog.title:SetText(L.SHOP_ADD)
    dialog.title:ClearAllPoints()
    dialog.title:SetPoint("LEFT", dialog.bar, "LEFT", ns.ThemeArt.TextStart(TITLE_H) or PAD, 0)
    dialog.search:SetText("")
    dialog.selected = 1
    dialog:Show()
    suggest()
    dialog.search:SetFocus()
end

-- The tab ---------------------------------------------------------------------

function ShoppingUI.TabLabel()
    local done, total = doneCount()
    return total > 0 and L.TAB_SHOP_COUNT:format(done, total) or L.TAB_SHOP
end

function ShoppingUI.BuildPanel(window)
    local U = ui()
    panel = CreateFrame("Frame", nil, window)
    panel:SetPoint("TOPLEFT", window, "TOPLEFT", PAD, -(TITLE_H + 10))
    panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, PAD)
    panel:Hide()
    panel.offset = 0
    panel.add = U.Chip(panel, L.SHOP_ADD_BUTTON, function() return false end, function() ShoppingUI.OpenAdd() end)
    panel.add:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.noteChip = U.Chip(panel, L.SHOP_NOTE, function() return (Shopping.Note() or {}).shown == true end,
        function(on) ShoppingUI.ShowNote(on) end)
    panel.noteChip:SetPoint("LEFT", panel.add, "RIGHT", 6, 0)
    panel.sortLabel = U.Text(panel, 12, "muted")
    panel.sortLabel:SetPoint("LEFT", panel.noteChip, "RIGHT", 18, 0)
    panel.sortLabel:SetText(L.SHOP_SORT)
    panel.sorts = {}
    local last = panel.sortLabel
    for _, mode in ipairs(Shopping.SORTS) do
        local chip = U.Chip(panel, L["SHOP_SORT_" .. mode:upper()], function() return Shopping.Sort() == mode end,
            function() Shopping.SetSort(mode) end, { dot = true })
        chip:SetPoint("LEFT", last, "RIGHT", 6, 0)
        if mode == "custom" then
            chip:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(L.SHOP_SORT_CUSTOM_TIP, 1, 1, 1)
                GameTooltip:Show()
            end)
            chip:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        panel.sorts[#panel.sorts + 1] = chip
        last = chip
    end
    panel.sum = U.Text(panel, 13, "title")
    panel.sum:SetPoint("RIGHT", panel, "TOPRIGHT", 0, -11)
    panel.empty = U.Text(panel, 13, "muted")
    panel.empty:SetPoint("TOP", panel, "TOP", 0, -(HEAD_H + 40))
    panel.empty:SetText(L.SHOP_EMPTY)
    panel.list = CreateFrame("Frame", nil, panel)
    panel.list:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -HEAD_H)
    panel.list:SetPoint("BOTTOMRIGHT")
    panel.list:EnableMouseWheel(true)
    panel.list:SetScript("OnMouseWheel", function(_, delta)
        panel.offset = math.max(0, math.min(#Shopping.Entries() - 1, panel.offset - delta * 2))
        ShoppingUI.Refresh()
    end)
    panel.rows = {}
    panel:SetScript("OnShow", function() ShoppingUI.Refresh() end)
    return panel
end

local function refreshPanel()
    if not (panel and panel:IsShown()) then return end
    local done, total = doneCount()
    panel.sum:SetText(total > 0 and L.SHOP_DONE:format(done, total) or "")
    panel.empty:SetShown(total == 0)
    panel.offset = math.max(0, math.min(panel.offset, total - 1))
    layoutRows(panel.list, panel.rows, PANEL_ROW, 4, panel.offset, function() return newRow(panel.list, PANEL_ROW, 13) end)
    ui().paintChip(panel.add)
    ui().paintChip(panel.noteChip)
    for _, chip in ipairs(panel.sorts) do ui().paintChip(chip) end
end

-- The sticky note -------------------------------------------------------------

local function saveNote()
    local n = Shopping.Note()
    n.x = math.floor(note:GetLeft() + 0.5)
    n.y = math.floor(note:GetTop() - UIParent:GetHeight() + 0.5)
    n.w = math.floor(note:GetWidth() + 0.5)
    if not n.min then n.h = math.floor(note:GetHeight() + 0.5) end   -- folded: keep the open height
end

local function placeNote()
    local n = Shopping.Note()
    note:ClearAllPoints()
    note:SetPoint("TOPLEFT", UIParent, "TOPLEFT", n.x, n.y)
    note:SetSize(n.w, n.min and NOTE_TITLE or n.h)
    -- Minimised: the title only.
    note.list:SetShown(not n.min)
    note.grip:SetShown(not n.min)
end

local function titleButton(parent, label, tip, onClick)
    local U = ui()
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(NOTE_TITLE - 6, NOTE_TITLE - 6)
    b.text = U.Text(b, 15, "muted")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        U.paintText(self.text, "accent")
        -- Under the note's title, not under the pointer (the note often sits at the top of the screen).
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPRIGHT", self:GetParent(), "BOTTOMRIGHT", 0, -4)
        GameTooltip:SetText(tip, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        U.paintText(self.text, "muted")
        GameTooltip:Hide()
    end)
    return b
end

local function buildNote()
    local U = ui()
    note = CreateFrame("Frame", "ForeverLootFinderShoppingNote", UIParent)
    note:SetFrameStrata("MEDIUM")
    note:SetMovable(true)
    note:SetResizable(true)
    if note.SetResizeBounds then note:SetResizeBounds(NOTE_MIN_W, NOTE_MIN_H, NOTE_MAX_W, NOTE_MAX_H) end
    note:SetClampedToScreen(true)
    if note.SetDontSavePosition then note:SetDontSavePosition(true) end
    note:EnableMouse(true)
    note.bar = CreateFrame("Frame", nil, note)
    note.bar:SetHeight(NOTE_TITLE)
    note.bar:SetPoint("TOPLEFT"); note.bar:SetPoint("TOPRIGHT")
    note.bar:EnableMouse(true)
    note.bar:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then note:StartMoving() end end)
    note.bar:SetScript("OnMouseUp", function()
        note:StopMovingOrSizing()
        saveNote()
        placeNote()
    end)
    ns.ThemeArt.BuildWindow(note, note.bar)
    note.close = titleButton(note.bar, "×", L.SHOP_NOTE_CLOSE, function() ShoppingUI.ShowNote(false) end)
    note.close:SetPoint("RIGHT", note.bar, "RIGHT", -4, 0)
    note.fold = titleButton(note.bar, "–", L.SHOP_NOTE_FOLD, function()
        local n = Shopping.Note()
        n.min = not n.min
        placeNote()
        ShoppingUI.Refresh()
    end)
    note.fold:SetPoint("RIGHT", note.close, "LEFT", -2, 0)
    note.add = titleButton(note.bar, "+", L.SHOP_ADD, function() ShoppingUI.OpenAdd() end)
    note.add:SetPoint("RIGHT", note.fold, "LEFT", -2, 0)
    note.sort = titleButton(note.bar, "", L.SHOP_SORT_MENU, function(self) ShoppingUI.SortMenu(self) end)
    note.sort:SetPoint("RIGHT", note.add, "LEFT", -2, 0)
    note.sort.icon = note.sort:CreateTexture(nil, "ARTWORK")
    note.sort.icon:SetSize(14, 14)
    note.sort.icon:SetPoint("CENTER")
    note.sort.icon:SetTexture(SORT_ICON)
    local function tint(kind)
        local c = ui().colour(kind)
        note.sort.icon:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    end
    tint("muted")
    note.sort:HookScript("OnEnter", function() tint("accent") end)
    note.sort:HookScript("OnLeave", function() tint("muted") end)
    note.sort.tint = tint
    note.title = U.Text(note.bar, 13, "title")
    note.title:SetPoint("RIGHT", note.sort, "LEFT", -6, 0)
    note.title:SetJustifyH("LEFT")
    note.title:SetWordWrap(false)
    note.list = CreateFrame("Frame", nil, note)
    note.list:SetPoint("TOPLEFT", note, "TOPLEFT", NOTE_PAD, -(NOTE_TITLE + 4))
    note.list:SetPoint("BOTTOMRIGHT", note, "BOTTOMRIGHT", -NOTE_PAD, NOTE_PAD)
    note.list:EnableMouseWheel(true)
    note.list:SetScript("OnMouseWheel", function(_, delta)
        note.offset = math.max(0, math.min(#Shopping.Entries() - 1, note.offset - delta))
        ShoppingUI.Refresh()
    end)
    note.offset, note.rows = 0, {}
    note.grip = CreateFrame("Button", nil, note)
    note.grip:SetSize(GRIP, GRIP)
    note.grip:SetPoint("BOTTOMRIGHT")
    note.grip:SetFrameLevel(note:GetFrameLevel() + 20)
    note.grip:SetNormalTexture(GRIP_TEXTURE)
    note.grip:SetScript("OnMouseDown", function() note:StartSizing("BOTTOMRIGHT") end)
    note.grip:SetScript("OnMouseUp", function()
        note:StopMovingOrSizing()
        saveNote()
        placeNote()
        ShoppingUI.Refresh()
    end)
    note:SetScript("OnSizeChanged", function() if note:IsShown() then ShoppingUI.Refresh() end end)
    ShoppingUI.Restyle()
end

local function refreshNote()
    if not (note and note:IsShown()) then return end
    local done, total = doneCount()
    note.title:ClearAllPoints()
    note.title:SetPoint("LEFT", note.bar, "LEFT", ns.ThemeArt.TextStart(NOTE_TITLE) or NOTE_PAD, 0)
    note.title:SetPoint("RIGHT", note.sort, "LEFT", -6, 0)
    note.title:SetText(L.SHOP_NOTE_TITLE:format(done, total))
    note.offset = math.max(0, math.min(note.offset, total - 1))
    layoutRows(note.list, note.rows, NOTE_ROW, 2, note.offset, function() return newRow(note.list, NOTE_ROW, 12) end)
end

function ShoppingUI.ShowNote(on)
    local n = Shopping.Note()
    if not n then
        n = {}
        for k, v in pairs(NOTE_DEFAULT) do n[k] = v end
    end
    n.shown = on and true or false
    Shopping.SetNote(n)
    if on then
        if not note then buildNote() end
        placeNote()
        note:Show()
        needSource(ShoppingUI.Refresh)
    elseif note then
        note:Hide()
    end
    ShoppingUI.Refresh()
end

-- Everything that shows the list, after any change.
function ShoppingUI.Refresh()
    refreshPanel()
    refreshNote()
    local window = ns.Window.Frame()
    if window and window.tabs then window.tabs.shop:Relabel() end
end

function ShoppingUI.Restyle()
    local U = ui()
    if note then
        ns.ThemeArt.StyleWindow(note, note.bar)
        note.sort.tint("muted")
    end
    if dialog then
        ns.ThemeArt.StyleWindow(dialog, dialog.bar)
        U.paintEdges(dialog.search.edges, U.colour("muted"), 0.45)
    end
    ShoppingUI.Refresh()
end

Shopping.OnChange(ShoppingUI.Refresh)

-- A boss's tooltip: what it drops from the list, "Name 0/3" like a quest
-- objective. The loot tables are loaded once on the first boss hovered out of combat.
local loadTried
local function bossTooltip(tooltip, info)
    if tooltip ~= GameTooltip or #Shopping.Entries() == 0 then return end
    if not ns.Source.Ready() then
        if not loadTried and not InCombatLockdown() then
            loadTried = true
            ns.Source.LoadAsync(function() end)
        end
        return
    end
    local lines = Shopping.ForBoss(Shopping.NpcID(info and info.guid))
    if #lines == 0 then return end
    tooltip:AddLine(L.SHOP_TOOLTIP, 1, 0.82, 0)
    for _, line in ipairs(lines) do
        tooltip:AddDoubleLine("  " .. nameText({ name = line.name, quality = line.quality }),
            ("%d/%d"):format(line.have, line.goal), 1, 1, 1, 1, 1, 1)
    end
end
ShoppingUI.BossTooltip = bossTooltip   -- the tests
if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, bossTooltip)
end

-- The note as it was left, from login on.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    local n = Shopping.Note()
    if n and n.shown then ShoppingUI.ShowNote(true) end
end)
