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

-- Wide enough for the widest theme and language (Console, Frost in German: 744 measured).
local WIDTH, HEIGHT, TITLE_H, PAD = 780, 640, 32, 12
local CHIP_H, CHIP_GAP, SLOT_SIZE = 22, 6, 32
local ROW_H, ROW_GAP, DETAIL_LINE, ICON = 44, 4, 16, 34
-- Right edges of the row's columns (item level, points, verdict, main value), from the row's
-- right; the headers above use the same. Rows end SCROLL_W short of the list (the scroll thumb).
local COL = { ilvl = 12, points = 62, verdict = 118, value = 210 }
local SCROLL_W = 4
local FOOTER_H = 26
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SEARCH_ICON = "Interface\\Common\\UI-Searchbox-Icon"
local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 },
    { 1, 0.5, 0 } }
local UP_COLOR, ALT_COLOR = { 0.3, 0.9, 0.4 }, { 1, 0.82, 0.2 }

local frame
local loading, loadWhy -- the loot tables: being read, or why they could not be
local state = { slot = nil, invSlot = nil, text = "", class = nil, offset = 0, open = nil }
local entries, unknown = {}, 0
local texts = {}   -- every font string: { fs, size, kind } (restyled with the theme)

-- ---------------------------------------------------------------------------
-- Look
-- ---------------------------------------------------------------------------
-- onBar: on a title bar that is a banner (Azeroth), titles and accents in
-- its gold, the rest light; never the window's dark ink on its red.
local function colour(kind, onBar)
    if onBar and ns.Themes.Banner() then
        local T = ns.Themes
        if kind == "title" or kind == "accent" then return T.BANNER_GOLD end
        local c = T.BANNER_INK
        return kind == "muted" and { c[1], c[2], c[3], 0.75 } or c
    end
    if kind == "accent" then return ns.Themes.Accent() end
    local c = ns.Themes.TextColor()
    if kind == "muted" then return { c[1], c[2], c[3], 0.62 } end
    return c
end

-- A coloured value (quality, class, verdict) in the window's body: in dark
-- ink on a light paper (Themes.Ink). Not in the class menu: that is dark.
local function ink(c) return ns.Themes.Ink(c) end

local function paintText(fs, kind, c)
    c = c or colour(kind, fs.onBar)
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

-- The client can refuse a theme font on its first use (Bungee) and take it a
-- moment later. Chips and columns were measured in Friz Quadrata meanwhile:
-- everything is styled and measured once more then, at most FONT_RETRIES times.
local FONT_RETRY, FONT_RETRIES = 1, 2
local fontRetries, retryQueued = 0, false
local function fontRefused()
    if retryQueued or fontRetries >= FONT_RETRIES then return end
    retryQueued, fontRetries = true, fontRetries + 1
    C_Timer.After(FONT_RETRY, function()
        retryQueued = false
        Window.Restyle()
    end)
end

local function styleText(t)
    local name, add = ns.Themes.BodyFont()
    if t.kind == "title" then name, add = ns.Themes.TitleFont(), 0 end
    local ok = t.fs:SetFont(ns.Media.FontPath(name), t.size + (add or 0), ns.Themes.Outline())
    if not ok then
        t.fs:SetFont(ns.Media.FontPath("Friz Quadrata"), t.size, ns.Themes.Outline())
        fontRefused()
    end
    -- A drop shadow under text without an outline, but not under ink on a light paper (it smudges).
    local art = ns.Themes.Art()
    local shadow = ns.Themes.Outline() == "" and not (art and art.ink)
    t.fs:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
    if t.paint ~= false then paintText(t.fs, t.kind) end
end

-- kind: text, muted, accent, title; paint false: the caller colours it.
local function Text(parent, size, kind, paint)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs.onBar = parent.isBar or parent.onBar
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

-- The look for Panel.lua (its texts restyle with the window's).
Window.UI = { Text = Text, colour = colour, paintText = paintText, fill = fill, edges = edges, paintEdges = paintEdges }

-- ---------------------------------------------------------------------------
-- Chips: a toggle with a tick, as in the mockup
-- ---------------------------------------------------------------------------
local chips = {}

local function paintChip(chip)
    local on = chip.get()
    local a = colour("accent", chip.onBar)
    chip.fill:SetVertexColor(a[1], a[2], a[3], on and 0.2 or 0)
    paintEdges(chip.edges, on and a or colour("muted", chip.onBar), on and 0.9 or 0.45)
    paintText(chip.text, on and "text" or "muted")
    chip.tick:SetShown(on and not chip.dot)
end

local function Chip(parent, label, get, set, opts)
    local chip = CreateFrame("Button", nil, parent)
    chip.onBar = parent.isBar
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

Window.UI.Chip, Window.UI.paintChip = Chip, paintChip

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

local function ownClass() return currentClass() == select(2, UnitClass("player")) end

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
    -- Another class: its first role, until another is chosen in this session.
    state.otherRole = state.otherRole or {}
    local role = state.otherRole[class] or (Rules.CLASS_ROLES[class] or {})[1]
    return role and { [role] = true } or {}
end

local function filterRow()
    local own = currentClass() == select(2, UnitClass("player"))
    frame.betterChip:SetShown(own)
    frame.altChip:SetShown(own and S("filterBetter"))
    -- Cloth wearers have one armour type: "best armour only" would change nothing.
    frame.armorChip:SetShown(Rules.HasArmorChoice(currentClass()))
    frame.hitChip:SetShown(roles().TANK == true)
    flow(frame.filterChips, frame, PAD, -(TITLE_H + 10 + 2 * (CHIP_H + 8)))
end

-- A role chip picks its role; the picked one stays (one role at a time).
-- Tanks wear their heaviest armour: choosing the role turns the filter on
-- (it can be turned off again).
local function tankArmor(class)
    if Rules.HasArmorChoice(class) and not S("filterBestArmor") then Settings.Set("filterBestArmor", true) end
end

local function setRole(role, on)
    if not on then return end
    local class = currentClass()
    if role == "TANK" then tankArmor(class) end
    local _, own = UnitClass("player")
    if class == own then Settings.SetRole(role) else state.otherRole = state.otherRole or {}; state.otherRole[class] = role end
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
            if roles().TANK then tankArmor(class) end
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
    local own = ownClass()
    for _, b in ipairs(frame.slots) do
        local on = state.slot == b.slot.key
        local dim = state.slot ~= nil and not on
        -- The worn item's icon reads at a glance; the paper doll's grey outline only for an empty slot.
        local worn = own and GetInventoryItemTexture and GetInventoryItemTexture("player", b.slot.inv[1])
        b.icon:SetTexture(worn or Rules.SlotArt(b.slot))
        b.icon:SetBlendMode(worn and "BLEND" or "ADD")   -- the outline art is dark grey; added it reads
        b.icon:SetDesaturated(dim)
        b.icon:SetAlpha(dim and 0.6 or 1)
        paintEdges(b.edges, on and a or colour("muted"), on and 1 or 0.6)
        b.glow:SetVertexColor(a[1], a[2], a[3], 0.6)
        b.glow:SetShown(on)
        b.mark:SetVertexColor(a[1], a[2], a[3], 1)
        b.mark:SetShown(on)
    end
    local slot = state.slot and Rules.SLOT[state.slot]
    frame.slotName:SetText(slot and L["SLOT_" .. slot.key] or L.SLOT_ALL)
end

local function buildSlots(y)
    frame.slots = {}
    local n = #Rules.SLOTS
    local gap = (WIDTH - 2 * PAD - n * SLOT_SIZE) / (n - 1)
    for i, slot in ipairs(Rules.SLOTS) do
        local b = CreateFrame("Button", nil, frame.body)
        b:SetSize(SLOT_SIZE, SLOT_SIZE)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + (i - 1) * (SLOT_SIZE + gap), y)
        -- Selected: an accent halo behind, the icon inset in it, a bar under it.
        b.glow = fill(b, "BACKGROUND")
        b.glow:SetPoint("TOPLEFT", -3, 3); b.glow:SetPoint("BOTTOMRIGHT", 3, -3)
        b.back = fill(b, "BACKGROUND", 1)   -- the halo stays a ring; added outline art needs a dark ground
        b.back:SetPoint("TOPLEFT", 1, -1); b.back:SetPoint("BOTTOMRIGHT", -1, 1)
        b.back:SetVertexColor(0, 0, 0, 1)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 1, -1); b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b.edges = edges(b)
        b.mark = fill(b, "OVERLAY")
        b.mark:SetHeight(3)
        b.mark:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -3); b.mark:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -3)
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
        if not entry.item.loaded then return Items.NoData(entry.item) and L.NO_DATA or L.LOADING end
        local e = entry.item.effects and entry.item.effects[1]
        return e and L["EFFECT_" .. e.kind] or L.NO_STATS
    end
    local r = entry.roles[1]
    local p = r and Rules.Profile(currentClass(), r.role)
    if p and p.main and r.main and r.main > 0 then return L["VALUE_" .. p.main]:format(r.main) end
    -- No own stat: the two that weigh most (no role, a global search hit: the biggest).
    local best = {}
    for k, v in pairs(entry.item.stats) do
        local w = (p and (p.weights[k] or 0) or 1) * v
        if w > 0 then best[#best + 1] = { k = k, v = v, w = w } end
    end
    table.sort(best, function(a, b) return a.w > b.w end)
    local parts = {}
    for i = 1, math.min(2, #best) do parts[i] = ("%s %d"):format(L["STAT_" .. best[i].k], best[i].v) end
    return table.concat(parts, " · ")
end

local function dropText(d)
    if d.quest then return ("%s · %s"):format(L.QUEST_NAME:format(d.quest), d.instance) end
    if d.craft then return L.CRAFT_NAME:format(d.instance, d.skill or 0) end
    if d.world then return L.WORLD_DROP end
    if d.vendor then return ("%s · %s"):format(d.vendor, d.instance) end
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
    row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(COL.value + 100), -7)
    row.where = Text(row, 11, "muted")
    row.where:SetPoint("TOPLEFT", row, "TOPLEFT", ICON + 18, -25)
    row.where:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(COL.value + 100), -25)
    row.ilvl = Text(row, 18, "title")
    row.ilvl:SetPoint("RIGHT", row, "TOPRIGHT", -COL.ilvl, -ROW_H / 2)
    row.ilvl:SetJustifyH("RIGHT")
    row.points = Text(row, 15, "text", false)
    row.points:SetPoint("RIGHT", row, "TOPRIGHT", -COL.points, -ROW_H / 2)
    row.points:SetJustifyH("RIGHT")
    row.verdict = Text(row, 11, "text", false)
    row.verdict:SetPoint("RIGHT", row, "TOPRIGHT", -COL.verdict, -ROW_H / 2)
    row.verdict:SetJustifyH("RIGHT")
    row.value = Text(row, 12, "text", false)
    row.value:SetPoint("RIGHT", row, "TOPRIGHT", -COL.value, -ROW_H / 2)
    row.value:SetJustifyH("RIGHT")
    -- Marks (bonus armor, hit) right under the value, which moves up for them.
    row.badges = Text(row, 11, "text", false)
    row.badges:SetPoint("TOPRIGHT", row.value, "BOTTOMRIGHT", 0, -1)
    row.badges:SetJustifyH("RIGHT")
    row.details = {}
    for i = 1, 10 do
        local d = Text(row, 11, "text")
        d:SetPoint("TOPLEFT", row, "TOPLEFT", ICON + 18, -ROW_H - (i - 1) * DETAIL_LINE)
        d:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -ROW_H - (i - 1) * DETAIL_LINE)
        row.details[i] = d
    end
    row:SetScript("OnClick", function(self, button)
        local e = self.entry
        if not e then return end
        if button == "RightButton" then
            ns.ShoppingUI.LootMenu(self, e.item.id)
            return
        end
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
        -- What it gives or takes against the worn one, stat by stat.
        if e.slot and e.item.loaded then
            local worn = Filter.Against(e.slot, state.slot and state.invSlot or nil, next(roles()), currentClass(), e.item)
            GameTooltip:AddLine(" ")
            if not worn then
                GameTooltip:AddLine(L.COMPARE_EMPTY, 1, 0.82, 0)
            else
                GameTooltip:AddLine(L.COMPARE_WITH:format(worn.name or "?"), 1, 0.82, 0)
                local diff = Filter.Diff(e.item, worn)
                for _, d in ipairs(diff) do
                    local up = d.delta > 0
                    GameTooltip:AddLine(("%+d %s"):format(d.delta, L["STAT_" .. d.key]), up and 0.3 or 1, up and 0.9 or 0.35,
                        up and 0.4 or 0.3)
                end
                if #diff == 0 then GameTooltip:AddLine(L.COMPARE_SAME, 0.7, 0.7, 0.7) end
            end
        end
        -- Where the points come from.
        if e.points and e.item.stats then
            local parts = {}
            for _, p in ipairs(Rules.PointParts(e.pointsRole, e.item.stats, currentClass(), e.pointsRoom)) do
                parts[#parts + 1] = ("%s %s"):format(L["STAT_" .. p[1]] or p[1], (("%.1f"):format(p[2]):gsub("%.0$", "")))
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.POINTS_TIP:format(L["ROLE_" .. e.pointsRole] or e.pointsRole,
                (("%.1f"):format(e.points):gsub("%.0$", ""))), 1, 0.82, 0)
            GameTooltip:AddLine(table.concat(parts, " + "), 0.85, 0.85, 0.85, true)
            if Rules.HasCustom(currentClass(), e.pointsRole) then GameTooltip:AddLine(L.POINTS_CUSTOM, 0.6, 0.6, 0.6) end
            local dyn = Rules.Dynamic(currentClass(), e.pointsRole)
            if dyn then
                local unit = L["STAT_" .. Rules.DYNAMIC[e.pointsRole].unit]
                GameTooltip:AddLine(L.POINTS_DYNAMIC:format(dyn.char.missing, dyn.char.hitValue, unit, dyn.char.critValue, unit),
                    0.6, 0.6, 0.6, true)
            end
            if e.item.onUse then
                GameTooltip:AddLine(L.USE_COUNTED:format(Rules.USE_SHARE * 100), 0.6, 0.6, 0.6, true)
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function details(entry)
    local lines = {}
    for i, d in ipairs(entry.drops) do
        if i > 4 then
            lines[#lines + 1] = L.MORE_DROPS:format(#entry.drops - 4)
            break
        end
        local line = (d.quest or d.craft) and dropText(d) or ("%s  %s"):format(d.raid and L.RAID or L.DUNGEON, dropText(d))
        lines[#lines + 1] = line .. (d.choice and ("  (" .. L.QUEST_CHOICE .. ")") or "")
    end
    local item = entry.item
    for i, e in ipairs(item.effects or {}) do
        if i > 2 then break end
        local text = L["EFFECT_" .. e.kind] .. ": " .. e.text
        lines[#lines + 1] = #text > 90 and (text:sub(1, 88) .. " …") or text
    end
    if item.loaded and item.reqLevel and item.reqLevel > 1 then lines[#lines + 1] = L.REQ_LEVEL:format(item.reqLevel) end
    lines[#lines + 1] = L.CLICK_HINT
    return lines
end

-- Another class is compared with nothing: the worn gear is the player's.
local function wornShown()
    return ownClass() and S("filterBetter") and state.slot ~= nil
end

local function fillRow(row, entry, open)
    row.entry = entry
    local item = entry.item
    local q = QUALITY[item.quality or 1] or QUALITY[1]
    row.icon:SetTexture(item.icon)
    paintEdges(row.iconEdges, q, 1)
    row.name:SetText(item.name or (Items.NoData(item) and L.ITEM_ID:format(item.id)) or L.LOADING)
    paintText(row.name, nil, item.loaded and ink(q) or colour("muted"))
    local d = entry.drops[1]
    local more = #entry.drops > 1 and ("  (+%d)"):format(#entry.drops - 1) or ""
    row.where:SetText(dropText(d) .. more .. (d.forever and ("  " .. L.NEW_MARK) or ""))
    -- Bears live on armour: an item's bonus armour stands out.
    local bonus = item.bonusArmor and currentClass() == "DRUID" and entry.roles[1] and entry.roles[1].role == "TANK"
    local marks = {}
    if bonus then marks[#marks + 1] = L.BONUS_ARMOR:format(item.bonusArmor) end
    if entry.hit then marks[#marks + 1] = L.HIT_MARK:format(entry.hit) end
    row.badges:SetText(table.concat(marks, " · "))
    row.value:SetPoint("RIGHT", row, "TOPRIGHT", -COL.value, -ROW_H / 2 + (#marks > 0 and 7 or 0))
    paintText(row.badges, nil, ink(UP_COLOR))
    row.value:SetText(statText(entry))
    paintText(row.value, entry.unclear and "muted" or "text")
    if entry.verdict then
        local up = entry.verdict == "UPGRADE"
        row.verdict:SetText(up and L.UPGRADE or L.ALTERNATIVE)
        paintText(row.verdict, nil, ink(up and UP_COLOR or ALT_COLOR))
    else
        row.verdict:SetText("")
    end
    row.ilvl:SetText(item.ilvl and tostring(item.ilvl) or "–")
    -- Against the worn one its difference, else the points themselves.
    if entry.points and wornShown() and entry.delta then
        local d = math.floor(entry.delta + 0.5)
        row.points:SetText(("%+d"):format(d))
        paintText(row.points, nil, d > 0 and ink(UP_COLOR) or colour("muted"))
    else
        row.points:SetText(entry.points and tostring(math.floor(entry.points + 0.5)) or "")
        paintText(row.points, "text")
    end
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
local function closeButton(bar, onClick)
    local b = CreateFrame("Button", nil, bar)
    b.onBar = bar.isBar
    b:SetSize(TITLE_H, TITLE_H)
    b:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    b.text = Text(b, 16, "muted")
    b.text:SetPoint("CENTER")
    b.text:SetText("×")
    b:SetScript("OnClick", onClick or function() frame:Hide() end)
    b:SetScript("OnEnter", function() paintText(b.text, "accent") end)
    b:SetScript("OnLeave", function() paintText(b.text, "muted") end)
    return b
end
Window.UI.closeButton = closeButton

local function buildList()
    local list = CreateFrame("Frame", nil, frame.body)
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
    -- While the loot tables load: a ring with a turning spark, in the accent colour.
    list.spinner = CreateFrame("Frame", nil, list)
    list.spinner:SetSize(36, 36)
    list.spinner:SetPoint("TOP", list.empty, "BOTTOM", 0, -12)
    list.spinner.ring = list.spinner:CreateTexture(nil, "BACKGROUND")
    list.spinner.ring:SetAllPoints()
    list.spinner.ring:SetTexture("Interface\\COMMON\\StreamCircle")
    list.spinner.spark = list.spinner:CreateTexture(nil, "OVERLAY")
    list.spinner.spark:SetAllPoints()
    list.spinner.spark:SetTexture("Interface\\COMMON\\StreamSpark")
    if list.spinner.spark.CreateAnimationGroup then
        local turn = list.spinner.spark:CreateAnimationGroup()
        turn:SetLooping("REPEAT")
        local r = turn:CreateAnimation("Rotation")
        r:SetDegrees(-360)
        r:SetDuration(1)
        list.spinner:SetScript("OnShow", function() turn:Play() end)
        list.spinner:SetScript("OnHide", function() turn:Stop() end)
    end
    list.spinner:Hide()
    list.thumb = fill(list, "OVERLAY")
    list.thumb:SetWidth(2)
    frame.list = list
end

local function buildWorn()
    local w = CreateFrame("Frame", nil, frame.body)
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
    w.ilvl:SetPoint("RIGHT", w, "TOPRIGHT", -COL.ilvl, -ROW_H / 2)
    w.ilvl:SetJustifyH("RIGHT")
    w.points = Text(w, 15, "text")
    w.points:SetPoint("RIGHT", w, "TOPRIGHT", -COL.points, -ROW_H / 2)
    w.points:SetJustifyH("RIGHT")
    w:EnableMouse(true)
    w:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    w:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.worn = w
end

local function build()
    frame = CreateFrame("Frame", "ForeverLootFinderWindow", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", -167, 0) -- half the side panel: both fit on 16:9
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

    -- Two tabs: the loot (everything below in body) and the shopping list.
    local body = CreateFrame("Frame", nil, frame)
    body:SetAllPoints()
    frame.body = body
    frame.tabs = {
        shop = Chip(bar, function() return ns.ShoppingUI.TabLabel() end, function() return state.tab == "shop" end,
            function() Window.ShowTab("shop") end, { dot = true }),
        loot = Chip(bar, L.TAB_LOOT, function() return state.tab ~= "shop" end, function() Window.ShowTab("loot") end,
            { dot = true }),
    }
    frame.tabs.shop:SetPoint("RIGHT", frame.gear, "LEFT", -8, 0)
    frame.tabs.loot:SetPoint("RIGHT", frame.tabs.shop, "LEFT", -CHIP_GAP, 0)
    frame.shop = ns.ShoppingUI.BuildPanel(frame)

    -- Row 1: class, roles, search.
    frame.classChip = Chip(body, function() return className(currentClass()) end, function() return true end, nil,
        { dot = true })
    frame.classChip:SetScript("OnClick", function()
        frame.classMenu:SetShown(not frame.classMenu:IsShown())
    end)
    frame.classMenu = buildClassMenu()
    frame.classMenu:SetPoint("TOPLEFT", frame.classChip, "BOTTOMLEFT", 0, -2)
    frame.roleChips = {}
    for _, role in ipairs(Rules.ROLES) do
        frame.roleChips[role] = Chip(body, function() return L[Rules.RoleLabelKey(currentClass(), role)] end, function() return roles()[role] == true end,
            function(v) setRole(role, v) end)
    end
    local box = CreateFrame("EditBox", "ForeverLootFinderSearch", body)
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

    -- Row 1 on: where items come from. Row 2: the filters (and the search).
    local function setting(key) return function() return S(key) end, function(v) Settings.Set(key, v) end end
    local function chipsOf(list)
        local out = {}
        for _, f in ipairs(list) do
            local get, set = setting(f[1])
            out[#out + 1] = Chip(body, function() return L[f[2]] end, get, set)
        end
        return out
    end
    frame.sourceChips = chipsOf({ { "filterDungeons", "FILTER_DUNGEONS" }, { "filterRaids", "FILTER_RAIDS" },
        { "filterQuests", "FILTER_QUESTS" }, { "filterCrafting", "FILTER_CRAFTING" }, { "filterWorld", "FILTER_WORLD" },
        { "filterVendors", "FILTER_VENDORS" } })
    -- Inside a dungeon or raid: its name on the chip.
    local get, set = setting("filterHere")
    frame.hereChip = Chip(body, function() return L.FILTER_HERE:format((ns.Source.Here() or {}).name or "") end, get, set)
    frame.sourceChips[#frame.sourceChips + 1] = frame.hereChip
    frame.filterChips = chipsOf({ { "filterNow", "FILTER_NOW" }, { "filterBestArmor", "FILTER_BEST_ARMOR" },
        { "filterBetter", "FILTER_BETTER" }, { "filterAlternatives", "FILTER_ALTERNATIVES" },
        { "filterTankHit", "FILTER_TANK_HIT" } })
    frame.hitChip = frame.filterChips[#frame.filterChips]
    frame.altChip = frame.filterChips[4]
    frame.armorChip, frame.betterChip = frame.filterChips[2], frame.filterChips[3]

    -- Row 3: the slots, their name under them.
    buildSlots(-(TITLE_H + 10 + 3 * (CHIP_H + 8)))
    frame.slotName = Text(body, 12, "accent")
    frame.slotName:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TITLE_H + 10 + 3 * (CHIP_H + 8) + SLOT_SIZE + 6))

    -- Row 4: count and sort.
    frame.count = Text(body, 14, "title")
    frame.count:SetPoint("TOPLEFT", frame.slotName, "BOTTOMLEFT", 0, -6)
    frame.sort = CreateFrame("Button", nil, body)
    frame.sort:SetSize(420, 18)
    frame.sort:SetPoint("LEFT", frame.count, "RIGHT", 14, 0)
    frame.sort.text = Text(frame.sort, 12, "accent")
    frame.sort.text:SetPoint("LEFT")
    frame.sort:SetScript("OnClick", function()
        local i = 1
        for k, v in ipairs(Filter.SORTS) do if v == S("sort") then i = k end end
        Settings.Set("sort", Filter.SORTS[i % #Filter.SORTS + 1])
        Window.Update()
    end)
    -- Column headers right over the columns; points and item level sort (best first) on a click.
    local headY = -(TITLE_H + 10 + 3 * (CHIP_H + 8) + SLOT_SIZE + 32)
    frame.heads = {}
    for _, h in ipairs({ { "value", "COL_VALUE" }, { "verdict", "COL_VERDICT" }, { "points", "COL_POINTS", "POINTS" },
        { "ilvl", "COL_ILVL", "ILVL" } }) do
        local b = CreateFrame("Button", nil, body)
        b:SetSize(80, 16)
        b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + SCROLL_W + COL[h[1]]), headY)
        b.text = Text(b, 11, "muted", false)
        b.text:SetPoint("RIGHT")
        b.text:SetJustifyH("RIGHT")
        b.key, b.label, b.sort = h[1], h[2], h[3]
        if b.sort then
            b:SetScript("OnClick", function(self)
                Settings.Set("sort", self.sort)
                Window.Update()
            end)
        end
        frame.heads[h[1]] = b
    end

    buildWorn()
    buildList()
    frame.footer = Text(body, 11, "muted")
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
local TOP_LIST = TITLE_H + 10 + 3 * (CHIP_H + 8) + SLOT_SIZE + 50

-- Places what comes and goes: the role chips of the class, the worn row.
function Window.Relayout()
    if not frame then return end
    local class = currentClass()
    frame.classChip:Relabel()
    paintText(frame.classChip.text, nil, ink(classColor(class)))
    local classRoles = {}
    for _, role in ipairs(Rules.CLASS_ROLES[class] or {}) do classRoles[role] = true end
    local row1 = { frame.classChip }
    for _, role in ipairs(Rules.ROLES) do
        frame.roleChips[role]:SetShown(classRoles[role] == true)
        row1[#row1 + 1] = frame.roleChips[role]
    end
    for _, role in ipairs(Rules.ROLES) do frame.roleChips[role]:Relabel() end
    flow(row1, frame, PAD, -(TITLE_H + 10))
    frame.hereChip:SetShown(ns.Source.Here() ~= nil)
    frame.hereChip:Relabel()
    flow(frame.sourceChips, frame, PAD, -(TITLE_H + 10 + CHIP_H + 8))
    filterRow()
    Window.Update()
end

-- The options as a string: what the list shows (not the functions it calls).
local function signature(o)
    local parts = {}
    for k, v in pairs(o) do
        if type(v) == "table" then
            for r, on in pairs(v) do parts[#parts + 1] = k .. "." .. tostring(r) .. "=" .. tostring(on) end
        elseif type(v) ~= "function" then
            parts[#parts + 1] = k .. "=" .. tostring(v)
        end
    end
    table.sort(parts)
    return table.concat(parts, ";")
end


local function paintWorn()
    local w = frame.worn
    local slot = state.slot and Rules.SLOT[state.slot]
    w:SetShown(wornShown())
    if not wornShown() then return end
    w:ClearAllPoints()
    w:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TOP_LIST)
    w:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD - SCROLL_W, -TOP_LIST)
    local list = Filter.WornIn(slot, state.invSlot)
    local item = list[1]
    w.label:SetText(L.WORN)
    w.link = item and item.link or nil
    w.icon:SetTexture(item and item.icon or Rules.SlotArt(slot))
    w.name:SetText(item and (item.name or "…") or L.EMPTY_SLOT)
    if #list > 1 and list[2].name then w.name:SetText((item.name or "…") .. "  ·  " .. list[2].name) end
    local q = item and item.quality and QUALITY[item.quality]
    paintText(w.name, q and nil or "muted", q and ink(q))
    w.ilvl:SetText(item and item.ilvl and tostring(item.ilvl) or "")
    -- Its points for the best of the picked roles: what the list's differences start from.
    local best
    if item and item.stats then
        for role in pairs(roles()) do
            local fits, pts = Rules.ForRole(role, item.stats, currentClass())
            if fits and (not best or pts > best) then best = pts end
        end
    end
    w.points:SetText(best and tostring(math.floor(best + 0.5)) or "")
    w.back:SetVertexColor(unpack(ns.ThemeArt.Shade(0.25)))
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
        row:SetPoint("TOPRIGHT", list, "TOPRIGHT", -SCROLL_W, -y)
        row:SetHeight(h)
        row:Show()
        y = y + h + ROW_GAP
    end
    for i = n + 1, #list.rows do list.rows[i]:Hide(); list.rows[i].entry = nil end
    local opened
    for _, e in ipairs(entries) do if e.item.id == state.open then opened = e end end
    ns.Panel.Show(frame, opened, function() state.open = nil; Window.Draw() end)
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
local lastUpdate
function Window.Update()
    if not frame or not frame:IsShown() then return end
    local started = ns.perf and debugprofilestop()
    for _, chip in ipairs(chips) do paintChip(chip) end
    frame.classChip.fill:SetVertexColor(0, 0, 0, 0)
    paintText(frame.classChip.text, nil, ink(classColor(currentClass())))
    frame.tabs.shop:Relabel()
    if state.tab == "shop" then
        ns.ShoppingUI.Refresh()
        return
    end
    filterRow()
    paintSlots()
    paintWorn()
    -- The loot tables load over several frames: the window is there at once.
    if not ns.Source.Ready() and not loading and not loadWhy then
        loading = true
        ns.Source.LoadAsync(function(ok, why)
            loading, loadWhy = false, not ok and why or nil
            Window.Update()
        end)
    end
    local a = colour("accent")
    frame.list.spinner.ring:SetVertexColor(a[1], a[2], a[3], 0.5)
    frame.list.spinner.spark:SetVertexColor(a[1], a[2], a[3], 1)
    frame.list.spinner:SetShown(loading)
    if ns.Source.Ready() then
        local o = Filter.Options({ class = currentClass(), roles = roles(), slot = state.slot,
            invSlot = state.invSlot, text = state.text, better = ownClass() and S("filterBetter") })
        local runStart = ns.perf and debugprofilestop()
        entries, unknown = Filter.Run(o)
        if ns.perf then ns.perf.run = debugprofilestop() - runStart end
        -- Other filters, another list: back to its top (items arriving keep the place).
        local sig = signature(o)
        if sig ~= state.sig then state.sig, state.offset = sig, 0 end
        frame.list.empty:SetText(#entries == 0 and L.NOTHING or "")
    else
        entries, unknown = {}, 0
        frame.list.empty:SetText(loading and L.LOADING_TABLES or L["SOURCE_" .. (loadWhy or "NONE")])
    end
    state.offset = math.max(0, math.min(state.offset, #entries - 1))
    frame.count:SetText(L.HITS:format(#entries))
    local sort = Filter.SortFor(S("sort"), state.slot)
    frame.sort.text:SetText(L.SORT_BY:format(L["SORT_" .. sort])
        .. (sort ~= S("sort") and ("  " .. L.SORT_POINTS_SLOT) or ""))
    for _, b in pairs(frame.heads) do
        local label = L[b.label]
        if b.key == "points" and wornShown() then label = L.COL_DELTA end
        b.text:SetText(label)
        if b.sort == sort then paintText(b.text, "accent") else paintText(b.text, "muted") end
    end
    local foot = ns.Source.Name() and L.SOURCE:format(ns.Source.Name()) or ""
    if unknown > 0 then foot = foot .. "   ·   " .. L.UNKNOWN_ITEMS:format(unknown) end
    frame.footer:SetText(foot)
    Window.Draw()
    -- /flf perf: what each rebuild costs and how often it comes.
    if started and ns.perf.run then
        local now, p = GetTime(), Filter.perf or {}
        print(("|cff33ff99FLF perf|r update %.0f ms (filter %.0f, sort %.0f) · %d drops → %d rows, %d unknown · %s"):format(
            debugprofilestop() - started, ns.perf.run, p.sort or 0, p.items or 0, #entries, unknown,
            lastUpdate and ("%.1f s since the last"):format(now - lastUpdate) or "first"))
        lastUpdate, ns.perf.run = now, nil
    end
end

-- Fonts, colours and art from the theme.
function Window.Restyle()
    -- The sticky note and the add dialog follow the theme with the window never opened.
    for _, t in ipairs(texts) do styleText(t) end
    ns.ShoppingUI.Restyle()
    if not frame then return end
    ns.ThemeArt.StyleWindow(frame, frame.bar)
    frame.title:ClearAllPoints()
    frame.title:SetPoint("LEFT", frame.bar, "LEFT", ns.ThemeArt.TextStart(TITLE_H) or PAD, 0)
    paintEdges(frame.search.edges, colour("muted"), 0.45)
    frame.search.back:SetVertexColor(unpack(ns.ThemeArt.Shade(0.45)))
    paintEdges(frame.classMenu.edges, colour("accent"), 0.8)
    for _, chip in ipairs(chips) do chip:Relabel() end
    frame.search.hint:SetText(L.SEARCH)
    ns.Panel.Restyle()
    Window.Relayout()
end

-- The loot or the shopping list in the window.
function Window.ShowTab(tab)
    state.tab = tab
    frame.classMenu:Hide()
    frame.body:SetShown(tab ~= "shop")
    frame.shop:SetShown(tab == "shop")
    Window.Update()
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
    -- The own class and no search text: the list is about the slot's worn item.
    state.slot, state.invSlot, state.offset, state.open, state.class = slotKey, invSlot, 0, nil, nil
    if frame then frame.search:SetText("") end
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
    if key == nil or key == "theme" or key == "themeColors" then
        fontRetries = 0 -- a new theme's fonts get their own tries
        return Window.Restyle()
    end
    if not frame then return end
    if key == "roles" or key:find("^filter") or key == "sort" then Window.Relayout()
    elseif (key == "weights" or key == "dynamic") and Window.IsShown() then Window.Update() end
end)

Items.OnLoaded(function() if Window.IsShown() then Window.Update() end end)

-- Worn gear changes: the comparison too.
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_REGEN_ENABLED") -- the loot tables load once combat is over
events:RegisterEvent("TRACKED_RECIPE_UPDATE") -- the panel's "Track recipe"
events:RegisterEvent("PLAYER_ENTERING_WORLD")   -- into or out of a dungeon: the "only here" chip
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        if Window.IsShown() then Window.Relayout() end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" and loadWhy == "COMBAT" then loadWhy = nil end
    if Window.IsShown() then Window.Update() end
end)

-- A language switch relabels the chips, the search hint and the panel.
ns.Locale.OnChange(function() Window.Restyle() end)
