local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

-- The options window, built like Forever Unit Frames' (Style.lua and
-- Widgets.lua are the same): a title bar, the pages on the left with the
-- language at the bottom, the chosen page on the right, a footer. Opened
-- from the finder's title bar, a right-click on the minimap button or
-- /flf options. Copied from Forever Data Bar.
local Window = {}
ns.Options = Window

local Style, Widgets = ns.Style, ns.Widgets

local function num(key, label)
    local range = Settings.RANGES[key]
    return {
        label = label, min = range[1], max = range[2], step = 1, unit = "px",
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function check(key, label)
    return {
        type = "check", label = label,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local function choice(key, label, values, prefix)
    return {
        type = "select", label = label,
        choices = function()
            local list = {}
            for _, v in ipairs(values) do list[#list + 1] = { label = L[prefix .. v], value = v } end
            return list
        end,
        get = function() return S(key) end,
        set = function(v) Settings.Set(key, v) end,
    }
end

local WIDTH, HEIGHT = 700, 500
local TITLE_H, NAV_W, FOOTER_H = 32, 160, 40
local NAV_ROW_H, NAV_TOP, NAV_BAR_W, NAV_CAPTION_H = 26, 6, 3, 20
local SCROLLBAR_W, WHEEL_STEP = 10, 40
local CONTENT_W = WIDTH - NAV_W - SCROLLBAR_W
local PAGE_TOP, PAGE_BOTTOM, SECTION_GAP, INSET = 4, 16, 8, 16
local TEXT_AREA_H, HINT_ROW_H = 70, 26
local BUTTON_H, BUTTON_W, BUTTON_GAP = 24, 140, 8

-- A label: a locale key or a function (read again on refresh).
local function labelText(label)
    if type(label) == "function" then return label() end
    return L[label]
end

-- Stacks rows top to bottom; a header after other rows gets a gap.
local function newStack(page)
    local stack = { y = PAGE_TOP, rows = {} }
    function stack.add(row, height)
        if row.isSection and #stack.rows > 0 then stack.y = stack.y + SECTION_GAP end
        row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -stack.y)
        row:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -stack.y)
        row:SetHeight(height or row:GetHeight())
        stack.rows[#stack.rows + 1] = row
        stack.y = stack.y + (height or row:GetHeight())
    end
    return stack
end

-- A muted line of explanation.
local function hintRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    row.text = Style.Text(row, 11, "muted")
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", INSET, -4)
    row.text:SetPoint("RIGHT", row, "RIGHT", -INSET, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)
    row.text:SetText(labelText(opt.label))
    function row:Refresh() end
    function row:SetEnabled() end
    return row, opt.height or HINT_ROW_H
end

-- Several buttons side by side.
local function buttonsRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local x = INSET
    row.buttons = {}
    for _, b in ipairs(opt.buttons) do
        local button = Widgets.Button(row, { text = labelText(b.label), width = b.width or BUTTON_W,
            onClick = b.onClick })
        button:SetPoint("LEFT", row, "LEFT", x, 0)
        x = x + (b.width or BUTTON_W) + BUTTON_GAP
        row.buttons[#row.buttons + 1] = button
    end
    function row:Refresh() end
    function row:SetEnabled(on) for _, button in ipairs(row.buttons) do button:SetEnabled(on) end end
    return row, BUTTON_H + 12
end

-- A text area to copy from or paste into (export / import).
local function editRow(page, opt)
    local row = CreateFrame("Frame", nil, page)
    local area = Widgets.TextArea(row, { width = CONTENT_W - 2 * INSET, height = TEXT_AREA_H })
    area:SetPoint("TOPLEFT", row, "TOPLEFT", INSET, -4)
    -- The buttons use it like an edit box.
    function area:SetFocus() area.edit:SetFocus() end
    function area:HighlightText() area.edit:HighlightText() end
    if opt.ref then opt.ref.box = area end
    function row:Refresh() end
    function row:SetEnabled() end
    return row, TEXT_AREA_H + 12
end

-- The widget for one spec row, and its height (nil: the widget's own).
local function widgetFor(page, opt)
    local kind = opt.type or "slider"
    if kind == "header" then
        local row = Widgets.Header(page, labelText(opt.label))
        row.isSection = true
        return row
    elseif kind == "text" then
        return hintRow(page, opt)
    elseif kind == "buttons" then
        return buttonsRow(page, opt)
    elseif kind == "edit" then
        return editRow(page, opt)
    end
    local o = { label = labelText(opt.label), get = opt.get, set = opt.set,
        placeholder = opt.placeholder and labelText(opt.placeholder) }
    local row
    if kind == "check" then
        row = Widgets.Checkbox(page, o)
    elseif kind == "select" then
        o.items = function()
            local items = {}
            for _, c in ipairs(opt.choices()) do
                items[#items + 1] = { value = c.value, text = c.label, font = c.font }
            end
            return items
        end
        row = Widgets.Dropdown(page, o)
    elseif kind == "color" then
        o.noOpacity = opt.noOpacity
        row = Widgets.Color(page, o)
    else
        o.min, o.max, o.step = opt.min, opt.max, opt.step or 1
        row = Widgets.Slider(page, o)
    end
    -- A row that is only usable under a setting.
    if opt.enabled then
        local refresh = row.Refresh
        function row:Refresh()
            refresh(self)
            row:SetEnabled(opt.enabled())
        end
    end
    -- A label that follows the settings (e.g. "X" for a free level).
    if type(opt.label) == "function" then
        local refresh = row.Refresh
        function row:Refresh()
            row:SetLabel(opt.label())
            refresh(self)
        end
    end
    return row
end

-- A row with `visible` comes and goes: page.relayout stacks the page anew.
local function buildRows(page, spec)
    local built = {}
    for i, opt in ipairs(spec) do
        local row, height = widgetFor(page, opt)
        built[i] = { row = row, height = height, visible = opt.visible }
    end
    page.relayout = function()
        local stack = newStack(page)
        for _, b in ipairs(built) do
            local shown = not b.visible or b.visible()
            b.row:SetShown(shown)
            if shown then
                b.row:ClearAllPoints()
                stack.add(b.row, b.height)
            end
        end
        page.rows, page.height = stack.rows, stack.y + PAGE_BOTTOM
    end
    page.relayout()
end

-- The theme: names shown in the theme's font.
local function themeRefused(ok, why)
    if not ok and why then ns.Print(L["THEME_REFUSED_" .. why]) end
end

-- While Forever Themes (the hub) sets this addon's theme, the pickers are
-- its: dimmed here, with a way there. Asked anew on every refresh: the
-- player may switch "own theme" in the hub at any time.
local function hubFollowed() return LibForeverThemes.Follows(ADDON) end
local function notHubFollowed() return not hubFollowed() end
local function noHub() return LibForeverThemes.Hub() == nil end
-- The hub's texts are the library's, in the client's language.
local function hubText(key) return function() return LibForeverThemes.Text(key, ns.Locale.Current()) end end
local function showHubLink() LibForeverThemes.ShowHubLink(nil, ns.Locale.Current()) end

local function themeRow()
    return {
        type = "select", label = "OPT_THEME_CHOICE",
        choices = function()
            local list, Lib = {}, LibForeverThemes
            -- HD themes are colours of their base (colour menu below).
            for _, id in ipairs(Lib.MenuIds(Lib.SpecIds(ns.Themes.SPECS))) do
                list[#list + 1] = { label = L["THEME_" .. id], value = id, font = ns.Themes.SPECS[id].font }
            end
            return list
        end,
        get = function() return LibForeverThemes.BaseTheme(ns.Themes.Current()) end,
        set = function(v)
            -- The base shown already (an HD colour of it worn): stays as it is.
            if v == LibForeverThemes.BaseTheme(ns.Themes.Current()) then return end
            themeRefused(ns.Themes.Switch(v))
        end,
        enabled = notHubFollowed,
    }
end

-- The current theme's colours, then its HD theme's ("HD <colour>"); none
-- under Classic.
local function themeColorRow()
    return {
        type = "select", label = "OPT_THEME_COLOR",
        visible = function() return #ns.Themes.Colors() > 0 end,
        choices = function()
            local Lib, list = LibForeverThemes, {}
            for _, e in ipairs(Lib.MenuColors(ns.Themes.SPECS, ns.Themes.Current())) do
                local label = L["THEME_COLOR_" .. e.theme .. "_" .. e.color]
                list[#list + 1] = { label = e.hd and "HD " .. label or label, value = Lib.MenuValue(e.theme, e.color) }
            end
            return list
        end,
        get = function() return LibForeverThemes.MenuValue(ns.Themes.Current(), ns.Themes.Color()) end,
        -- An HD colour switches to the HD theme, a plain one back.
        set = function(v)
            local theme, color = LibForeverThemes.ParseMenuValue(v)
            local ok, why = ns.Themes.Switch(theme)
            if ok then ok, why = ns.Themes.SetColor(color, theme) end
            themeRefused(ok, why)
        end,
        enabled = notHubFollowed,
    }
end

-- General: the theme, the minimap button, a reset.
local function generalRows()
    return {
        { type = "header", label = "OPT_THEME" },
        themeRow(),
        themeColorRow(),
        { type = "text", label = hubText("HUB_MISSING"), visible = noHub },
        { type = "buttons", visible = noHub, buttons = {
            { label = hubText("HUB_LINK"), width = 200, onClick = showHubLink },
        } },
        { type = "text", label = hubText("HUB_FOLLOWS"), visible = hubFollowed },
        { type = "buttons", visible = hubFollowed, buttons = {
            { label = hubText("HUB_OPEN"), width = 200, onClick = function() LibForeverThemes.Hub().OpenOptions() end },
        } },
        { type = "buttons", visible = function() return ns.Themes.HasOthers() and not hubFollowed() end, buttons = {
            { label = "OPT_THEME_ALL", width = 240, onClick = function()
                ns.Print(L.MSG_THEME_ALL:format(ns.Themes.ApplyToAll()))
            end },
        } },
        { type = "header", label = "OPT_ADVANCED" },
        check("dynamic", "OPT_DYNAMIC"),
        { type = "text", label = "OPT_DYNAMIC_HINT", height = 40 },
        check("advanced", "OPT_ADVANCED_SHOW"),
        { type = "text", label = "OPT_ADVANCED_HINT", height = 40 },
        { type = "header", label = "OPT_MINIMAP" },
        check("minimapShow", "OPT_MINIMAP_SHOW"),
        { type = "header", label = "OPT_RESET" },
        { type = "text", label = "OPT_RESET_HINT", height = 40 },
        { type = "buttons", buttons = {
            { label = "OPT_RESET_BUTTON", width = 200, onClick = function()
                Settings.Reset()
                Window.Refresh()
            end },
        } },
    }
end

-- The character window's buttons: shown, size, where on the slot, offset.
local function charRows()
    local function on() return S("charButtons") end
    local function choicePoint()
        return {
            type = "select", label = "OPT_CHAR_POINT",
            choices = function()
                local list = {}
                for _, p in ipairs(ns.CharButtons.POINTS) do list[#list + 1] = { label = L["POINT_" .. p], value = p } end
                return list
            end,
            get = function() return S("charButtonPoint") end,
            set = function(v) Settings.Set("charButtonPoint", v) end,
            enabled = on,
        }
    end
    local size, x, y = num("charButtonSize", "OPT_CHAR_SIZE"), num("charButtonX", "OPT_CHAR_X"),
        num("charButtonY", "OPT_CHAR_Y")
    size.enabled, x.enabled, y.enabled = on, on, on
    return {
        { type = "header", label = "OPT_CHAR" },
        check("charButtons", "OPT_CHAR_SHOW"),
        { type = "text", label = "OPT_CHAR_HINT", height = 40 },
        size, choicePoint(), x, y,
        -- No button that opens it: ToggleCharacter from addon code taints the
        -- character window (Blizzard's health text then fails on secret values).
        { type = "text", label = "OPT_CHAR_OPEN", height = 20 },
    }
end

-- The point weights of a class and spec (Advanced): one slider per stat the spec weighs, its
-- default beside the name; buttons back to the defaults.
local picked = {}
local function pickedClass() return picked.class or select(2, UnitClass("player")) end
local function pickedSpec()
    for _, s in ipairs(ns.Rules.SPECS[pickedClass()] or {}) do if s.id == picked.spec then return s.id end end
    return ns.Rules.SpecOf(pickedClass()).id
end
local function weightsChanged()
    Settings.Changed("weights")
    Window.Refresh()
end
local function fmt(v) return (("%.2f"):format(v):gsub("%.?0+$", "")) end

local function weightRows()
    local Rules = ns.Rules
    local rows = {
        { type = "header", label = "OPT_WEIGHTS" },
        { type = "text", label = "OPT_WEIGHTS_HINT", height = 52 },
        { type = "select", label = "OPT_WEIGHTS_CLASS",
            choices = function()
                local list = {}
                for _, c in ipairs(Rules.CLASSES) do
                    list[#list + 1] = { label = (LOCALIZED_CLASS_NAMES_MALE or {})[c] or c, value = c }
                end
                return list
            end,
            get = pickedClass, set = function(v) picked.class, picked.spec = v, nil; Window.Refresh() end },
        { type = "select", label = "OPT_WEIGHTS_ROLE",
            choices = function()
                local list = {}
                for _, s in ipairs(Rules.SPECS[pickedClass()] or {}) do
                    list[#list + 1] = { label = L[Rules.SpecLabelKey(pickedClass(), s)], value = s.id }
                end
                return list
            end,
            get = pickedSpec, set = function(v) picked.spec = v; Window.Refresh() end },
        -- Priest healers and tanks: wowsims' set or the Loot Finder's own (Rules.CLASSIC).
        { type = "select", label = "OPT_WEIGHTS_SOURCE",
            choices = function()
                return { { label = L.SOURCE_WOWSIMS, value = "WOWSIMS" }, { label = L.SOURCE_CLASSIC, value = "CLASSIC" } }
            end,
            get = function() return Rules.IsClassic(pickedClass(), pickedSpec()) and "CLASSIC" or "WOWSIMS" end,
            set = function(v) Rules.SetSource(pickedClass(), pickedSpec(), v == "CLASSIC"); weightsChanged() end,
            visible = function() return Rules.CLASSIC[pickedClass() .. ":" .. pickedSpec()] == true end },
    }
    for _, stat in ipairs(Rules.WEIGHT_KEYS) do
        local function default() return Rules.SpecProfile(pickedClass(), pickedSpec(), true).weights[stat] end
        rows[#rows + 1] = {
            label = function()
                local text = L.OPT_WEIGHT_LABEL:format(L["STAT_" .. stat], fmt(default() or 0))
                local own = Rules.SpecProfile(pickedClass(), pickedSpec()).weights[stat]
                if own == default() then return text end
                -- Changed: in the accent colour.
                local c = Style.COLORS.accent
                return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, text)
            end,
            -- Up to 10: weapon DPS weighs up to about 8 (wowsims).
            min = 0, max = 10, step = 0.05,
            get = function() return Rules.SpecProfile(pickedClass(), pickedSpec()).weights[stat] or 0 end,
            set = function(v) Rules.SetWeight(pickedClass(), pickedSpec(), stat, v); weightsChanged() end,
            -- Only the stats the spec weighs at all (a zero there counts: mp5 for damage casters).
            visible = function() return default() ~= nil end,
        }
    end
    rows[#rows + 1] = { type = "buttons", buttons = {
        { label = "OPT_WEIGHTS_RESET", width = 220, onClick = function()
            Rules.SetWeight(pickedClass(), pickedSpec()); weightsChanged()
        end },
        { label = "OPT_WEIGHTS_RESET_ALL", width = 220, onClick = function()
            Rules.ResetWeights(); weightsChanged()
        end },
    } }
    return rows
end

Window.PAGES = {
    { id = "general", label = "PAGE_GENERAL", rows = generalRows },
    { id = "character", label = "PAGE_CHARACTER", rows = charRows },
    { id = "weights", label = "PAGE_WEIGHTS", rows = weightRows, shown = function() return S("advanced") end },
}

-- --------------------------------------------------------------------------
local frame, current
local pages = {}

local function line(parent, colorKey)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(Style.COLORS[colorKey]))
    return t
end

local function horizontalLine(parent, anchor)
    local t = line(parent, "border")
    t:SetHeight(1)
    t:SetPoint(anchor .. "LEFT"); t:SetPoint(anchor .. "RIGHT")
    return t
end

local function pageFor(id)
    if pages[id] then return pages[id] end
    local spec
    for _, p in ipairs(Window.PAGES) do if p.id == id then spec = p end end
    if not spec then return nil end
    local page = CreateFrame("Frame", "ForeverLootFinderPage" .. id, frame.scrollChild)
    page:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, 0)
    page:SetWidth(CONTENT_W)
    if spec.build then spec.build(page) else buildRows(page, spec.rows()) end
    page:SetHeight(page.height)
    page:Hide()
    pages[id] = page
    return page
end

-- Scrolling: a thin accent thumb, as in Forever Unit Frames.
local function updateScrollbar()
    local scroll, thumb = frame.scroll, frame.scrollThumb
    local range, view = scroll:GetVerticalScrollRange() or 0, scroll:GetHeight() or 0
    if range <= 0 or view <= 0 then thumb:Hide(); return end
    local thumbH = view * view / (view + range)
    thumb:SetHeight(thumbH)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", SCROLLBAR_W - 3,
        -(view - thumbH) * (scroll:GetVerticalScroll() or 0) / range)
    thumb:Show()
end

local function onWheel(scroll, delta)
    local v = (scroll:GetVerticalScroll() or 0) - delta * WHEEL_STEP
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, v)))
    updateScrollbar()
end

-- Besides the wheel the thumb can be dragged, and a click on the track above
-- or below it turns a page (reported: with a broken wheel the lower options
-- were out of reach). The thumb is a button as wide as the track, its bar
-- 2 px at the right edge, 4 px while hovered or dragged.
local function setScroll(v)
    local scroll = frame.scroll
    scroll:SetVerticalScroll(math.max(0, math.min(scroll:GetVerticalScrollRange() or 0, v)))
    updateScrollbar()
end

local function cursorY(region)
    return select(2, GetCursorPosition()) / region:GetEffectiveScale()
end

local function followDrag(thumb)
    local scroll = frame.scroll
    local free = (scroll:GetHeight() or 0) - thumb:GetHeight()
    if free > 0 then
        setScroll(thumb.startScroll + (thumb.startY - cursorY(thumb)) * (scroll:GetVerticalScrollRange() or 0) / free)
    end
end

local function createThumb(body)
    local thumb = CreateFrame("Button", nil, body)
    thumb:SetWidth(SCROLLBAR_W - 3)
    thumb:SetFrameLevel(body:GetFrameLevel() + 5)
    local bar = thumb:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(unpack(Style.COLORS.accent))
    bar:SetPoint("TOPRIGHT"); bar:SetPoint("BOTTOMRIGHT")
    bar:SetWidth(2)
    local function wide(on) bar:SetWidth((on or thumb.startY) and 4 or 2) end
    thumb:SetScript("OnEnter", function() wide(true) end)
    thumb:SetScript("OnLeave", function() wide(false) end)
    thumb:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        self.startY, self.startScroll = cursorY(self), frame.scroll:GetVerticalScroll() or 0
        self:SetScript("OnUpdate", followDrag)
    end)
    thumb:SetScript("OnMouseUp", function(self)
        self.startY = nil
        self:SetScript("OnUpdate", nil)
        wide(self:IsMouseOver())
    end)
    thumb:EnableMouseWheel(true)
    thumb:SetScript("OnMouseWheel", function(_, delta) onWheel(frame.scroll, delta) end)
    thumb:Hide()
    return thumb
end

local function createTrack(body, scroll)
    local track = CreateFrame("Frame", nil, body)
    track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", SCROLLBAR_W, 0)
    track:EnableMouse(true)
    track:EnableMouseWheel(true)
    track:SetScript("OnMouseWheel", function(_, delta) onWheel(scroll, delta) end)
    track:SetScript("OnMouseDown", function(self, button)
        local thumb = frame.scrollThumb
        if button ~= "LeftButton" or not thumb:IsShown() then return end
        local step = (scroll:GetHeight() or 0) - WHEEL_STEP
        setScroll((scroll:GetVerticalScroll() or 0) + (cursorY(self) < thumb:GetBottom() and step or -step))
    end)
end

local function createScroll(body)
    local scroll = CreateFrame("ScrollFrame", "ForeverLootFinderOptionsScroll", body)
    scroll:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -SCROLLBAR_W, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", onWheel)
    scroll:SetScript("OnScrollRangeChanged", updateScrollbar)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(CONTENT_W, 1)
    scroll:SetScrollChild(child)
    createTrack(body, scroll)
    local thumb = createThumb(body)
    frame.scroll, frame.scrollChild, frame.scrollThumb = scroll, child, thumb
end

-- Navigation ----------------------------------------------------------------------
local function paintNav()
    for id, b in pairs(frame.navButtons) do
        local selected = id == current
        Style.Paint(b.text, selected and "accent" or "text")
        b.selected = selected
        b.bar:SetShown(selected)
    end
end

local function navButton(nav, page, y)
    local b = CreateFrame("Button", "ForeverLootFinderNav" .. page.id, nav)
    b:SetHeight(NAV_ROW_H)
    b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
    b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -y)
    b.hover = Style.Fill(b, "hover", "ARTWORK")
    b.hover:Hide()
    b.bar = line(b, "accent")
    b.bar:SetPoint("TOPLEFT"); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetWidth(NAV_BAR_W)
    b.text = Style.Text(b, 12, "text")
    b.text:SetPoint("LEFT", b, "LEFT", INSET, 0)
    b.text:SetText(L[page.label])
    b:SetScript("OnEnter", function(self) self.hover:Show() end)
    b:SetScript("OnLeave", function(self) self.hover:Hide() end)
    b:SetScript("OnClick", function() Window.ShowPage(page.id) end)
    frame.navButtons[page.id] = b
end

-- The language, at the bottom of the navigation: a label above a dropdown
-- as wide as the column; the list opens upwards.
local LANGUAGE_BUTTON_H, LANGUAGE_LABEL_H, LANGUAGE_BOTTOM = 22, 18, 10

local function languageRow(nav)
    local row = Widgets.Dropdown(nav, {
        label = L.OPT_LANGUAGE,
        items = function()
            local list = { { value = "AUTO", text = L.LANGUAGE_AUTO } }
            for _, c in ipairs(ns.Locale.CHOICES) do list[#list + 1] = { value = c.value, text = c.label } end
            return list
        end,
        get = function() return ns.Locale.Setting() end,
        set = function(v) ns.Locale.Set(v) end,
        listAbove = true,
    })
    row:SetHeight(LANGUAGE_LABEL_H + LANGUAGE_BUTTON_H)
    row:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT", INSET, LANGUAGE_BOTTOM)
    row:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -INSET, LANGUAGE_BOTTOM)
    row:EnableMouse(false)
    row.hover:SetAlpha(0)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    Style.Paint(row.label, "muted")
    row.button:ClearAllPoints()
    row.button:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.button:SetHeight(LANGUAGE_BUTTON_H)
    row:Refresh()
    frame.languageRow = row
end

local function createNav(parent)
    local nav = CreateFrame("Frame", nil, parent)
    nav:SetWidth(NAV_W)
    Style.Fill(nav, "panel")
    local edge = line(nav, "border")
    edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
    frame.navButtons, frame.navCaptions, frame.nav = {}, {}, nav
    for _, page in ipairs(Window.PAGES) do
        navButton(nav, page, 0)
        if page.group then frame.navButtons[page.id].text:SetPoint("LEFT", frame.navButtons[page.id], "LEFT", INSET + 8, 0) end
        if page.group and not frame.navCaptions[page.group] then
            local caption = Style.Text(nav, 10, "muted")
            caption:SetText(L[page.group]:upper())
            frame.navCaptions[page.group] = caption
        end
    end
    languageRow(nav)
    return nav
end

local function pageShown(page)
    return not page.shown or page.shown()
end

-- The navigation's order: a caption above each group, the pages in it
-- indented; a page not shown (its part off, or `shown` says no) and a group
-- with none leave no gap.
local function layoutNav()
    if not frame or not frame.nav then return end
    local nav, y, group = frame.nav, NAV_TOP, nil
    for _, caption in pairs(frame.navCaptions) do caption:Hide() end
    for _, page in ipairs(Window.PAGES) do
        local b = frame.navButtons[page.id]
        local shown = pageShown(page)
        b:SetShown(shown)
        if shown then
            if page.group ~= group then
                group = page.group
                local caption = group and frame.navCaptions[group]
                if caption then
                    caption:Show()
                    caption:ClearAllPoints()
                    caption:SetPoint("TOPLEFT", nav, "TOPLEFT", INSET, -(y + NAV_CAPTION_H - 14))
                    y = y + NAV_CAPTION_H
                end
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", nav, "TOPLEFT", 0, -y)
            b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -1, -y)
            y = y + NAV_ROW_H
        end
    end
end

local function createFooter(parent)
    local footer = CreateFrame("Frame", nil, parent)
    footer:SetHeight(FOOTER_H)
    footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT")
    Style.Fill(footer, "panel")
    horizontalLine(footer, "TOP")
    return footer
end

-- Title bar with the version and a drawn close cross.
local CROSS_SIZE, CROSS_ANGLE = 14, math.pi / 4

local function closeButton(titleBar)
    local b = CreateFrame("Button", nil, titleBar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", titleBar, "RIGHT", 0, 0)
    b.lines = {}
    for i, angle in ipairs({ CROSS_ANGLE, -CROSS_ANGLE }) do
        local t = line(b, "muted")
        t:SetSize(CROSS_SIZE, 2)
        t:SetPoint("CENTER")
        if t.SetRotation then t:SetRotation(angle) end
        b.lines[i] = t
    end
    local function paint(colorKey)
        for _, t in ipairs(b.lines) do t:SetColorTexture(unpack(Style.COLORS[colorKey])) end
    end
    b:SetScript("OnEnter", function() paint("accent") end)
    b:SetScript("OnLeave", function() paint("muted") end)
    b:SetScript("OnClick", function() frame:Hide() end)
    return b
end

local function createTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    Style.Fill(bar, "panel")
    horizontalLine(bar, "BOTTOM")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    local title = Style.Text(bar, 16, "text")
    title:SetPoint("LEFT", bar, "LEFT", INSET, 0)
    title:SetText(L.ADDON_NAME)
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = Style.Text(bar, 11, "muted")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 1)
    version:SetText("v" .. ((getMetadata and getMetadata(ADDON, "Version")) or ""))
    bar.close = closeButton(bar)
    return bar
end

local WINDOW_NAME = "ForeverLootFinderOptions"

local function createWindow()
    frame = CreateFrame("Frame", WINDOW_NAME, UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    Style.Fill(frame, "bg")
    Style.Border(frame)
    frame.titleBar = createTitleBar(frame)
    local footer = createFooter(frame)
    local nav = createNav(frame)
    nav:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", 0, 0)
    nav:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", frame.titleBar, "BOTTOMLEFT", NAV_W, 0)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)
    frame.body = body
    createScroll(body)
    -- Hiding the window (ESC, the cross) takes an open dropdown list along.
    frame:SetScript("OnHide", function() Widgets.CloseList() end)
    frame:SetScript("OnShow", function() Window.Refresh() end)
    frame:Hide()
    if UISpecialFrames then
        local listed = false
        for _, name in ipairs(UISpecialFrames) do if name == WINDOW_NAME then listed = true end end
        if not listed then table.insert(UISpecialFrames, WINDOW_NAME) end
    end
end

local function ensureWindow()
    if not frame then createWindow() end
end

-- Public API ----------------------------------------------------------------------

function Window.ShowPage(id)
    ensureWindow()
    layoutNav()
    -- A page of a part switched off is not offered: General instead.
    for _, p in ipairs(Window.PAGES) do
        if p.id == id and not pageShown(p) then id = "general" end
    end
    local page = pageFor(id)
    if not page then return end
    Widgets.CloseList()
    for _, p in pairs(pages) do if p ~= page then p:Hide() end end
    current = id
    -- Rows that come and go (the hub may have come or gone) stack anew.
    if page.relayout then
        page.relayout()
        page:SetHeight(page.height)
    end
    if page.rebuild then
        page.rebuild()
        page:SetHeight(page.height)
    end
    frame.scrollChild:SetHeight(page.height)
    frame.scroll:SetVerticalScroll(0)
    page:Show()
    for _, row in ipairs(page.rows or {}) do row:Refresh() end
    paintNav()
    updateScrollbar()
end

-- Fetches every value on the visible page again; a page no longer offered
-- gives way to the one before it.
function Window.Refresh()
    if not frame or not current then return end
    layoutNav()
    local page = pages[current]
    if not page then return end
    if page.relayout then
        page.relayout()
        page:SetHeight(page.height)
        frame.scrollChild:SetHeight(page.height)
        updateScrollbar()
    end
    for _, row in ipairs(page.rows or {}) do row:Refresh() end
    if frame.languageRow then frame.languageRow:Refresh() end
end
ns.RefreshOptions = Window.Refresh

function Window.Open(pageID)
    ensureWindow()
    frame:Show()
    Window.ShowPage(pageID or current or "general")
end

function Window.Toggle()
    if Window.IsShown() then frame:Hide() else Window.Open() end
end

-- The page on show (the tests).
function Window.Current() return current end

function Window.IsShown()
    return frame ~= nil and frame:IsShown()
end

-- A change from elsewhere (dragging, a slash command, a profile) shows on
-- the page.
Settings.OnChange(function()
    if frame and frame:IsShown() then Window.Refresh() end
end)

-- Every label is set when its widget is built: a new language gets a new
-- window. Frames cannot be destroyed, so the old one stays hidden and
-- unreferenced; the new one takes over its global name and page.
ns.Locale.OnChange(function()
    if not frame then return end
    local wasOpen, page = frame:IsShown(), current
    frame:Hide()
    frame, pages = nil, {}
    if wasOpen then Window.Open(page) end
end)
