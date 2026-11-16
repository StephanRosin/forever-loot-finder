local ADDON, ns = ...
local L, Settings = ns.L, ns.Settings
local S = Settings.Get

--[[---------------------------------------------------------------------------
Window.lua -- the finder: the class and its roles, the filters as chips, the
slots as the paper doll's icons, a name search, then the list (Filter.lua).
A click on a row opens where it drops; shift-click links it in the chat,
ctrl-click tries it on (HandleModifiedItemClick). Opened from the minimap
button (free search) or from a slot of the character window
(Window.OpenSlot: that slot, "better than worn" on).

Drawn in the theme's colours and fonts (ThemeArt.lua); everything restyles
when the theme or its colour changes.
-----------------------------------------------------------------------------]]
local Window = {}
ns.Window = Window

local Rules, Filter, Items = ns.Rules, ns.Filter, ns.Items
local Lib = LibForeverThemes

local WIDTH, HEIGHT, TITLE_H, PAD = 700, 640, 32, 12
local CHIP_H, CHIP_GAP, SLOT_SIZE = 22, 6, 32
local ROW_H, ROW_GAP, DETAIL_LINE, ICON = 44, 4, 16, 34
local FOOTER_H = 26
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SEARCH_ICON = "Interface\\Common\\UI-Searchbox-Icon"
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 },
    { 1, 0.5, 0 } }
local ROLE_COLORS = { HEAL = { 0.27, 0.88, 0.54 }, CASTER = { 0.70, 0.55, 1 }, TANK = { 0.55, 0.75, 1 },
    MELEE = { 1, 0.55, 0.35 }, RANGED = { 0.95, 0.85, 0.35 } }
local UP_COLOR, ALT_COLOR = { 0.3, 0.9, 0.4 }, { 1, 0.82, 0.2 }

local frame
local state = { slot = nil, invSlot = nil, text = "", class = nil, offset = 0, open = nil }
local entries, unknown = {}, 0
local texts = {}   -- every font string: { fs, size, kind } (restyled with the theme)

-- ---------------------------------------------------------------------------
-- Look
-- ---------------------------------------------------------------------------
local function colour(kind)
    if kind == "accent" then return ns.Themes.Accent() end
    local c = ns.Themes.TextColor()
    if kind == "muted" then return { c[1], c[2], c[3], 0.62 } end
    return c
end

local function paintText(fs, kind, c)
    c = c or colour(kind)
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

local function styleText(t)
    local name, add = ns.Themes.BodyFont()
    if t.kind == "title" then name, add = ns.Themes.TitleFont(), 0 end
    local ok = t.fs:SetFont(ns.Media.FontPath(name), t.size + (add or 0), ns.Themes.Outline())
    if not ok then t.fs:SetFont(ns.Media.FontPath("Friz Quadrata"), t.size, ns.Themes.Outline()) end
    t.fs:SetShadowOffset(ns.Themes.Outline() == "" and 1 or 0, ns.Themes.Outline() == "" and -1 or 0)
    if t.paint ~= false then paintText(t.fs, t.kind) end
end

-- kind: text, muted, accent, title; paint false: the caller colours it.
local function Text(parent, size, kind, paint)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local t = { fs = fs, size = size, kind = kind or "text", paint = paint }
    texts[#texts + 1] = t
    styleText(t)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function fill(parent, layer, sub)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
    t:SetTexture(WHITE)
    return t
end

-- Four edges of a box, coloured by paintEdges.
local function edges(parent)
    local e = {}
    for i = 1, 4 do e[i] = fill(parent, "BORDER") end
    e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
    e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
    e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
    e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
    return e
end

local function paintEdges(e, c, a)
    for _, t in ipairs(e) do t:SetVertexColor(c[1], c[2], c[3], a or c[4] or 1) end
end

-- ---------------------------------------------------------------------------
-- Chips: a toggle with a tick, as in the mockup
-- ---------------------------------------------------------------------------
local chips = {}

local function paintChip(chip)
    local on = chip.get()
    local a = colour("accent")
    chip.fill:SetVertexColor(a[1], a[2], a[3], on and 0.2 or 0)
    paintEdges(chip.edges, on and a or colour("muted"), on and 0.9 or 0.45)
    paintText(chip.text, on and "text" or "muted")
    chip.tick:SetShown(on and not chip.dot)
end

local function Chip(parent, label, get, set, opts)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(CHIP_H)
    chip.fill = fill(chip, "BACKGROUND")
    chip.fill:SetAllPoints()
    chip.edges = edges(chip)
    chip.tick = chip:CreateTexture(nil, "ARTWORK")
    chip.tick:SetSize(16, 16)
    chip.tick:SetPoint("LEFT", chip, "LEFT", 3, 0)
    chip.tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    chip.text = Text(chip, 12, "text", false)
    chip.text:SetPoint("LEFT", chip, "LEFT", (opts and opts.dot) and 8 or 20, 0)
    chip.label, chip.get, chip.set = label, get, set
    chip.dot = opts and opts.dot
    function chip:Relabel()
        self.text:SetText(type(self.label) == "function" and self.label() or self.label)
        self:SetWidth(math.max(48, math.floor((self.text:GetStringWidth() or 40) + (self.dot and 18 or 30))))
    end
    chip:Relabel()
    chip:SetScript("OnClick", function(self)
        if self.set then self.set(not self.get()) end
        Window.Update()
    end)
    chips[#chips + 1] = chip
    return chip
end

-- Lays chips out from x along a row.
local function flow(list, parent, x, y)
    for _, chip in ipairs(list) do
        if chip:IsShown() then
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
            x = x + chip:GetWidth() + CHIP_GAP
        end
    end
    return x
end

-- ---------------------------------------------------------------------------
-- The class menu
-- ---------------------------------------------------------------------------
local function currentClass()
    if state.class then return state.class end
    local _, class = UnitClass("player")
    return class
end

local function className(class)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return (names and names[class]) or L["CLASS_" .. class]
end

local function classColor(class)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and { c.r, c.g, c.b } or colour("text")
end

local function roles()
    local class = currentClass()
    local _, own = UnitClass("player")
    if class == own then return Settings.Roles(class) end
    -- Another class: all its roles, until chosen in this session.
    state.otherRoles = state.otherRoles or {}
    local r = state.otherRoles[class]
    if not r then
        r = {}
        for _, role in ipairs(Rules.CLASS_ROLES[class] or {}) do r[role] = true end
        state.otherRoles[class] = r
    end
    return r
end

local function setRole(role, on)
    local class = currentClass()
    local _, own = UnitClass("player")
    if class == own then Settings.SetRole(role, on) else roles()[role] = on end
end

local function buildClassMenu()
    local menu = CreateFrame("Frame", nil, frame)
    menu:SetFrameStrata("DIALOG")
    menu:SetSize(150, #Rules.CLASSES * 20 + 8)
    menu.back = fill(menu, "BACKGROUND")
    menu.back:SetAllPoints()
    menu.back:SetVertexColor(0.05, 0.05, 0.06, 0.97)
    menu.edges = edges(menu)
    for i, class in ipairs(Rules.CLASSES) do
        local b = CreateFrame("Button", nil, menu)
        b:SetSize(142, 20)
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (i - 1) * 20)
        b.text = Text(b, 12, "text", false)
        b.text:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.text:SetText(className(class))
        paintText(b.text, nil, classColor(class))
        b.hover = fill(b, "HIGHLIGHT")
        b.hover:SetAllPoints()
        b.hover:SetVertexColor(1, 1, 1, 0.08)
        b:SetScript("OnClick", function()
            state.class = class
            menu:Hide()
            Window.Relayout()
        end)
    end
    menu:Hide()
    return menu
end

-- ---------------------------------------------------------------------------
-- Slots
-- ---------------------------------------------------------------------------
local function paintSlots()
    local a = colour("accent")
    for _, b in ipairs(frame.slots) do
        local on = state.slot == b.slot.key
        paintEdges(b.edges, on and a or colour("muted"), on and 1 or 0.35)
        b.icon:SetDesaturated(not on)
        b.icon:SetAlpha(on and 1 or 0.7)
    end
    local slot = state.slot and Rules.SLOT[state.slot]
    frame.slotName:SetText(slot and L["SLOT_" .. slot.key] or L.SLOT_ALL)
end

local function buildSlots(y)
    frame.slots = {}
    local n = #Rules.SLOTS
    local gap = (WIDTH - 2 * PAD - n * SLOT_SIZE) / (n - 1)
    for i, slot in ipairs(Rules.SLOTS) do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(SLOT_SIZE, SLOT_SIZE)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (i - 1) * (SLOT_SIZE + gap), y)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexture(Rules.SlotArt(slot))
        b.edges = edges(b)
        b.slot = slot
        b:SetScript("OnClick", function()
            state.slot = state.slot ~= slot.key and slot.key or nil
            state.invSlot = nil
            Window.Update()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(L["SLOT_" .. slot.key])
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame.slots[i] = b
    end
end

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------
local function statText(entry)
    if entry.unclear then
        return entry.item.loaded and L.NO_STATS or L.LOADING
    end
    local r = entry.roles[1]
    local p = Rules.PROFILES[r.role]
    if p.main and r.main and r.main > 0 then return L["VALUE_" .. p.main]:format(r.main) end
    -- No own stat: the two that weigh most.
    local best = {}
    for k, v in pairs(entry.item.stats) do
        local w = (p.weights[k] or 0) * v
        if w > 0 then best[#best + 1] = { k = k, v = v, w = w } end
    end
    table.sort(best, function(a, b) return a.w > b.w end)
    local parts = {}
    for i = 1, math.min(2, #best) do parts[i] = ("%s %d"):format(L["STAT_" .. best[i].k], best[i].v) end
    return table.concat(parts, " · ")
end

local function dropText(d)
    local where = ("%s · %s"):format(d.boss, d.instance)
    if d.rate then where = where .. (" · %s %%"):format(d.rate) end
    return where
end

local function newRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.back = fill(row, "BACKGROUND")
    row.back:SetAllPoints()
    row.hover = fill(row, "HIGHLIGHT")
    row.hover:SetAllPoints()
    row.hover:SetVertexColor(1, 1, 1, 0.05)
    row.edge = fill(row, "BORDER")
    row.edge:SetPoint("TOPLEFT"); row.edge:SetPoint("BOTTOMLEFT"); row.edge:SetWidth(3)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -5)
    row.frame = CreateFrame("Frame", nil, row)
    row.frame:SetAllPoints(row.icon)
    row.iconEdges = edges(row.frame)
    row.name = Text(row, 13, "text", false)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", ICON + 18, -7)
    row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -260, -7)
    row.where = Text(row, 11, "muted")
    row.where:SetPoint("TOPLEFT", row, "TOPLEFT", ICON + 18, -25)
    row.where:SetPoint("TOPRIGHT", row, "TOPRIGHT", -260, -25)
    row.ilvl = Text(row, 18, "title")
    row.ilvl:SetPoint("RIGHT", row, "TOPRIGHT", -12, -ROW_H / 2)
    row.ilvl:SetJustifyH("RIGHT")
    row.verdict = Text(row, 11, "text", false)
    row.verdict:SetPoint("RIGHT", row, "TOPRIGHT", -52, -ROW_H / 2)
    row.verdict:SetJustifyH("RIGHT")
    row.value = Text(row, 12, "text", false)
    row.value:SetPoint("RIGHT", row.verdict, "LEFT", -10, 0)
    row.value:SetJustifyH("RIGHT")
    row.badges = Text(row, 11, "text", false)
    row.badges:SetPoint("TOPLEFT", row.where, "TOPRIGHT", 0, 0)
    row.details = {}
    for i = 1, 6 do
        local d = Text(row, 11, "text")
        d:SetPoint("TOPLEFT", row, "TOPLEFT", ICON + 18, -ROW_H - (i - 1) * DETAIL_LINE)
        d:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -ROW_H - (i - 1) * DETAIL_LINE)
        row.details[i] = d
    end
    row:SetScript("OnClick", function(self, button)
        local e = self.entry
        if not e then return end
        local link = e.item.link
        if link and IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP"))
            and HandleModifiedItemClick then
            HandleModifiedItemClick(link)
            return
        end
        state.open = state.open ~= e.item.id and e.item.id or nil
        Window.Draw()
    end)
    row:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(e.item.link or ("item:" .. e.item.id))
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function roleBadges(entry)
    local parts = {}
    for _, r in ipairs(entry.roles) do
        local c = ROLE_COLORS[r.role]
        parts[#parts + 1] = ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, L["ROLE_SHORT_" .. r.role])
    end
    return #parts > 0 and ("   " .. table.concat(parts, " ")) or ""
end

local function details(entry)
    local lines = {}
    for i, d in ipairs(entry.drops) do
        if i > 4 then
            lines[#lines + 1] = L.MORE_DROPS:format(#entry.drops - 4)
            break
        end
        lines[#lines + 1] = ("%s  %s"):format(d.raid and L.RAID or L.DUNGEON, dropText(d))
    end
    local item = entry.item
    if item.loaded and item.reqLevel and item.reqLevel > 1 then lines[#lines + 1] = L.REQ_LEVEL:format(item.reqLevel) end
    lines[#lines + 1] = L.CLICK_HINT
    return lines
end

local function fillRow(row, entry, open)
    row.entry = entry
    local item = entry.item
    local q = QUALITY[item.quality or 1] or QUALITY[1]
    row.icon:SetTexture(item.icon)
    paintEdges(row.iconEdges, q, 1)
    row.name:SetText(item.name or ("item:" .. item.id))
    paintText(row.name, nil, item.loaded and q or colour("muted"))
    local d = entry.drops[1]
    local more = #entry.drops > 1 and ("  (+%d)"):format(#entry.drops - 1) or ""
    row.where:SetText(dropText(d) .. more .. (d.forever and ("  " .. L.NEW_MARK) or ""))
    row.badges:SetText(roleBadges(entry))
    row.value:SetText(statText(entry))
    paintText(row.value, entry.unclear and "muted" or "text")
    if entry.verdict then
        local up = entry.verdict == "UPGRADE"
        local delta = entry.delta and entry.delta ~= 0 and (" %+d"):format(math.floor(entry.delta + 0.5)) or ""
        row.verdict:SetText((up and L.UPGRADE or L.ALTERNATIVE) .. (up and delta or ""))
        paintText(row.verdict, nil, up and UP_COLOR or ALT_COLOR)
    else
        row.verdict:SetText("")
    end
    row.ilvl:SetText(item.ilvl and tostring(item.ilvl) or "–")
    local card = ns.ThemeArt.CardColour()
    row.back:SetVertexColor(card[1], card[2], card[3], card[4])
    local a = colour("accent")
    row.edge:SetVertexColor(a[1], a[2], a[3], open and 1 or 0)
    local lines = open and details(entry) or {}
    for i, fs in ipairs(row.details) do
        fs:SetText(lines[i] or "")
        fs:SetShown(lines[i] ~= nil)
    end
    return ROW_H + (open and (#lines * DETAIL_LINE + 6) or 0)
end

-- ---------------------------------------------------------------------------
-- Building
-- ---------------------------------------------------------------------------
local function closeButton(bar)
    local b = CreateFrame("Button", nil, bar)
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    b.text = Text(b, 16, "muted")
    b.text:SetPoint("CENTER")
    b.text:SetText("×")
    b:SetScript("OnClick", function() frame:Hide() end)
    b:SetScript("OnEnter", function() paintText(b.text, "accent") end)
    b:SetScript("OnLeave", function() paintText(b.text, "muted") end)
    return b
end

local function buildList()
    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOTER_H)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        state.offset = math.max(0, math.min(#entries - 1, state.offset - delta * 2))
        Window.Draw()
    end)
    if list.SetClipsChildren then list:SetClipsChildren(true) end
    list.rows = {}
    list.empty = Text(list, 13, "muted")
    list.empty:SetPoint("TOP", list, "TOP", 0, -30)
    list.empty:SetWordWrap(true)
    list.empty:SetWidth(WIDTH - 4 * PAD)
    list.empty:SetJustifyH("CENTER")
    list.thumb = fill(list, "OVERLAY")
    list.thumb:SetWidth(2)
    frame.list = list
end

local function buildWorn()
    local w = CreateFrame("Frame", nil, frame)
    w:SetHeight(ROW_H)
    w.back = fill(w, "BACKGROUND")
    w.back:SetAllPoints()
    w.edges = edges(w)
    w.icon = w:CreateTexture(nil, "ARTWORK")
    w.icon:SetSize(ICON, ICON)
    w.icon:SetPoint("LEFT", w, "LEFT", 8, 0)
    w.label = Text(w, 11, "muted")
    w.label:SetPoint("TOPLEFT", w, "TOPLEFT", ICON + 18, -7)
    w.name = Text(w, 13, "text", false)
    w.name:SetPoint("TOPLEFT", w, "TOPLEFT", ICON + 18, -22)
    w.ilvl = Text(w, 18, "title")
    w.ilvl:SetPoint("RIGHT", w, "RIGHT", -12, 0)
    paintText(w.ilvl, "muted")
    frame.worn = w
end

local function build()
    frame = CreateFrame("Frame", "ForeverLootFinderWindow", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() frame:StartMoving() end)
    bar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame.bar = bar
    ns.ThemeArt.BuildWindow(frame, bar)
    frame.title = Text(bar, 16, "title")
    frame.title:SetText(L.ADDON_NAME)
    bar.close = closeButton(bar)
    frame.gear = CreateFrame("Button", nil, bar)
    frame.gear:SetSize(TITLE_H, TITLE_H)
    frame.gear:SetPoint("RIGHT", bar.close, "LEFT", 0, 0)
    frame.gear.icon = frame.gear:CreateTexture(nil, "ARTWORK")
    frame.gear.icon:SetSize(14, 14)
    frame.gear.icon:SetPoint("CENTER")
    frame.gear.icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    frame.gear:SetScript("OnClick", function() ns.Options.Toggle() end)

    -- Row 1: class, roles, search.
    frame.classChip = Chip(frame, function() return className(currentClass()) end, function() return true end, nil,
        { dot = true })
    frame.classChip:SetScript("OnClick", function()
        frame.classMenu:SetShown(not frame.classMenu:IsShown())
    end)
    frame.classMenu = buildClassMenu()
    frame.classMenu:SetPoint("TOPLEFT", frame.classChip, "BOTTOMLEFT", 0, -2)
    frame.roleChips = {}
    for _, role in ipairs(Rules.ROLES) do
        frame.roleChips[role] = Chip(frame, L["ROLE_" .. role], function() return roles()[role] == true end,
            function(v) setRole(role, v) end)
    end
    local box = CreateFrame("EditBox", "ForeverLootFinderSearch", frame)
    box:SetSize(170, CHIP_H)
    box:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(TITLE_H + 10))
    box:SetAutoFocus(false)
    box:SetTextInsets(22, 6, 0, 0)
    box.back = fill(box, "BACKGROUND")
    box.back:SetAllPoints()
    box.back:SetVertexColor(0, 0, 0, 0.45)
    box.edges = edges(box)
    box.icon = box:CreateTexture(nil, "OVERLAY")
    box.icon:SetTexture(SEARCH_ICON)
    box.icon:SetSize(13, 13)
    box.icon:SetPoint("LEFT", box, "LEFT", 6, 0)
    box.hint = Text(box, 12, "muted")
    box.hint:SetPoint("LEFT", box, "LEFT", 22, 0)
    box.hint:SetText(L.SEARCH)
    texts[#texts + 1] = { fs = box, size = 12, kind = "text" }
    styleText(texts[#texts])
    box:SetScript("OnTextChanged", function(self)
        state.text = self:GetText() or ""
        self.hint:SetShown(state.text == "")
        Window.Update()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame.search = box

    -- Row 2: the filters.
    local function setting(key) return function() return S(key) end, function(v) Settings.Set(key, v) end end
    frame.filterChips = {}
    for _, f in ipairs({ { "filterNow", "FILTER_NOW" }, { "filterBestArmor", "FILTER_BEST_ARMOR" },
        { "filterDungeons", "FILTER_DUNGEONS" }, { "filterRaids", "FILTER_RAIDS" },
        { "filterBetter", "FILTER_BETTER" }, { "filterAlternatives", "FILTER_ALTERNATIVES" } }) do
        local get, set = setting(f[1])
        frame.filterChips[#frame.filterChips + 1] = Chip(frame, L[f[2]], get, set)
    end
    frame.altChip = frame.filterChips[#frame.filterChips]

    -- Row 3: the slots, their name under them.
    buildSlots(-(TITLE_H + 10 + 2 * (CHIP_H + 8)))
    frame.slotName = Text(frame, 12, "accent")
    frame.slotName:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TITLE_H + 10 + 2 * (CHIP_H + 8) + SLOT_SIZE + 6))

    -- Row 4: count and sort.
    frame.count = Text(frame, 14, "title")
    frame.count:SetPoint("TOPLEFT", frame.slotName, "BOTTOMLEFT", 0, -6)
    frame.sort = CreateFrame("Button", nil, frame)
    frame.sort:SetSize(140, 18)
    frame.sort:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(TITLE_H + 10 + 2 * (CHIP_H + 8) + SLOT_SIZE + 26))
    frame.sort.text = Text(frame.sort, 12, "accent")
    frame.sort.text:SetPoint("RIGHT")
    frame.sort.text:SetJustifyH("RIGHT")
    frame.sort:SetScript("OnClick", function()
        local i = 1
        for k, v in ipairs(Filter.SORTS) do if v == S("sort") then i = k end end
        Settings.Set("sort", Filter.SORTS[i % #Filter.SORTS + 1])
        Window.Update()
    end)

    buildWorn()
    buildList()
    frame.footer = Text(frame, 11, "muted")
    frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 8)
    frame.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 8)

    frame:SetScript("OnHide", function() frame.classMenu:Hide() end)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "ForeverLootFinderWindow") end
    Window.Restyle()
end

-- ---------------------------------------------------------------------------
-- Updating
-- ---------------------------------------------------------------------------
local TOP_LIST = TITLE_H + 10 + 2 * (CHIP_H + 8) + SLOT_SIZE + 50

-- Places what comes and goes: the role chips of the class, the worn row.
function Window.Relayout()
    if not frame then return end
    local class = currentClass()
    frame.classChip:Relabel()
    paintText(frame.classChip.text, nil, classColor(class))
    local classRoles = {}
    for _, role in ipairs(Rules.CLASS_ROLES[class] or {}) do classRoles[role] = true end
    local row1 = { frame.classChip }
    for _, role in ipairs(Rules.ROLES) do
        frame.roleChips[role]:SetShown(classRoles[role] == true)
        row1[#row1 + 1] = frame.roleChips[role]
    end
    flow(row1, frame, PAD, -(TITLE_H + 10))
    frame.altChip:SetShown(S("filterBetter"))
    flow(frame.filterChips, frame, PAD, -(TITLE_H + 10 + CHIP_H + 8))
    Window.Update()
end

local function wornShown()
    return S("filterBetter") and state.slot ~= nil
end

local function paintWorn()
    local w = frame.worn
    local slot = state.slot and Rules.SLOT[state.slot]
    w:SetShown(wornShown())
    if not wornShown() then return end
    w:ClearAllPoints()
    w:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOP_LIST)
    w:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -TOP_LIST)
    local list = Filter.WornIn(slot, state.invSlot)
    local item = list[1]
    w.label:SetText(L.WORN)
    w.icon:SetTexture(item and item.icon or Rules.SlotArt(slot))
    w.name:SetText(item and (item.name or "…") or L.EMPTY_SLOT)
    if #list > 1 and list[2].name then w.name:SetText(item.name .. "  ·  " .. list[2].name) end
    paintText(w.name, "muted")
    w.ilvl:SetText(item and item.ilvl and tostring(item.ilvl) or "")
    w.back:SetVertexColor(0, 0, 0, 0.25)
    paintEdges(w.edges, colour("muted"), 0.35)
end

-- The list's rows from the offset on, as many as fit.
function Window.Draw()
    if not frame then return end
    local list = frame.list
    local top = TOP_LIST + (wornShown() and (ROW_H + 8) or 0)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
    list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOTER_H)
    local height = HEIGHT - top - FOOTER_H
    local y, n = 0, 0
    for i = state.offset + 1, #entries do
        if y >= height then break end
        n = n + 1
        local row = list.rows[n] or newRow(list)
        list.rows[n] = row
        local e = entries[i]
        local h = fillRow(row, e, state.open == e.item.id)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -4, -y)
        row:SetHeight(h)
        row:Show()
        y = y + h + ROW_GAP
    end
    for i = n + 1, #list.rows do list.rows[i]:Hide(); list.rows[i].entry = nil end
    local a = colour("accent")
    list.thumb:SetVertexColor(a[1], a[2], a[3], 0.8)
    if #entries > n and #entries > 0 then
        local share = n / #entries
        list.thumb:SetHeight(math.max(16, height * share))
        list.thumb:ClearAllPoints()
        list.thumb:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, -(height - math.max(16, height * share))
            * state.offset / math.max(1, #entries - n))
        list.thumb:Show()
    else
        list.thumb:Hide()
    end
end

-- Runs the filter anew and draws.
function Window.Update()
    if not frame or not frame:IsShown() then return end
    for _, chip in ipairs(chips) do paintChip(chip) end
    frame.classChip.fill:SetVertexColor(0, 0, 0, 0)
    paintText(frame.classChip.text, nil, classColor(currentClass()))
    frame.altChip:SetShown(S("filterBetter"))
    flow(frame.filterChips, frame, PAD, -(TITLE_H + 10 + CHIP_H + 8))
    paintSlots()
    paintWorn()
    local ok, why = ns.Source.Load()
    if ok then
        local o = Filter.Options({ class = currentClass(), roles = roles(), slot = state.slot,
            invSlot = state.invSlot, text = state.text })
        entries, unknown = Filter.Run(o)
        frame.list.empty:SetText(#entries == 0 and L.NOTHING or "")
    else
        entries, unknown = {}, 0
        frame.list.empty:SetText(L["SOURCE_" .. why])
    end
    state.offset = math.max(0, math.min(state.offset, #entries - 1))
    frame.count:SetText(L.HITS:format(#entries))
    frame.sort.text:SetText(L["SORT_" .. S("sort")])
    local foot = ns.Source.Name() and L.SOURCE:format(ns.Source.Name()) or ""
    if unknown > 0 then foot = foot .. "   ·   " .. L.UNKNOWN_ITEMS:format(unknown) end
    frame.footer:SetText(foot)
    Window.Draw()
end

-- Fonts, colours and art from the theme.
function Window.Restyle()
    if not frame then return end
    for _, t in ipairs(texts) do styleText(t) end
    ns.ThemeArt.StyleWindow(frame, frame.bar)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT", frame.bar, "LEFT", ns.ThemeArt.TextStart(TITLE_H) or PAD, 0)
    paintEdges(frame.search.edges, colour("muted"), 0.45)
    paintEdges(frame.classMenu.edges, colour("accent"), 0.8)
    for _, chip in ipairs(chips) do chip:Relabel() end
    Window.Relayout()
end

function Window.Open()
    if not frame then build() end
    frame:Show()
    Window.Restyle()
end

function Window.Toggle()
    if frame and frame:IsShown() then frame:Hide() else Window.Open() end
end

function Window.IsShown() return frame ~= nil and frame:IsShown() end

-- From the character window: that slot (and inventory slot), what is worn
-- compared.
function Window.OpenSlot(slotKey, invSlot)
    state.slot, state.invSlot, state.offset, state.open = slotKey, invSlot, 0, nil
    if not S("filterBetter") then Settings.Set("filterBetter", true) end
    Window.Open()
end

-- Opens the i-th row's drops (the tests, the renderer's scenarios).
function Window.OpenEntry(i)
    local e = entries[i or 1]
    state.open = e and e.item.id or nil
    Window.Draw()
end

-- The tests.
function Window.Entries() return entries end
function Window.State() return state end
function Window.Frame() return frame end

Settings.OnChange(function(key)
    if not frame then return end
    if key == nil or key == "theme" or key == "themeColors" then Window.Restyle()
    elseif key == "roles" or key:find("^filter") or key == "sort" then Window.Relayout() end
end)

Items.OnLoaded(function() if Window.IsShown() then Window.Update() end end)

-- Worn gear changes: the comparison too.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function() if Window.IsShown() then Window.Update() end end)
