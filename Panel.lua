local ADDON, ns = ...
local L = ns.L

--[[---------------------------------------------------------------------------
Panel.lua -- beside the finder, for the opened row: the zone's map with the
dungeon's entrance marked, and the boss as a 3D model under it (for a quest
reward: the quest and who gives it). Map and entrance come from
DungeonJournal (Source.Place); the map is drawn from the world map's tiles
(C_Map.GetMapArtLayerTextures), the model by the boss's display id
(Source.Display) or else by its npc id. Raids the journal does not know get
no map.
-----------------------------------------------------------------------------]]
local Panel = {}
ns.Panel = Panel

local WIDTH, TITLE_H, PAD = 330, 32, 12
local MAP_W = WIDTH - 2 * PAD
local MODEL_H = 230
local MARKER = "Interface\\Minimap\\Dungeon"
-- Rendered profession loops (art/*.py): 40 frames of 512x384 on two sheets
-- of 4x5, played at 15 fps. Keyed by AtlasLoot's crafting table name prefix.
local ART = { "Blacksmithing", "Tailoring", "Leatherworking", "Enchanting", "Engineering" }
local ART_DIR = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Professions\\"
local ART_FPS, ART_FRAMES, ART_PER = 15, 40, 20

local panel

local function build(parent)
    local UI = ns.Window.UI
    panel = CreateFrame("Frame", nil, parent)
    panel:SetWidth(WIDTH)
    panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", 4, 0)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMRIGHT", 4, 0)
    panel:EnableMouse(true)
    local bar = CreateFrame("Frame", nil, panel)
    bar:SetHeight(TITLE_H)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    panel.bar = bar
    ns.ThemeArt.BuildWindow(panel, bar)
    panel.title = UI.Text(bar, 15, "title")
    panel.title:SetPoint("RIGHT", bar, "RIGHT", -TITLE_H, 0)
    bar.close = UI.closeButton(bar, function() if panel.onClose then panel.onClose() end end)

    panel.location = UI.Text(panel, 11, "muted")
    panel.location:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(TITLE_H + 8))
    panel.location:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(TITLE_H + 8))
    panel.location:SetWordWrap(true)

    local map = CreateFrame("Frame", nil, panel)
    map:SetSize(MAP_W, MAP_W * 2 / 3)
    map:SetPoint("TOPLEFT", panel.location, "BOTTOMLEFT", 0, -6)
    if map.SetClipsChildren then map:SetClipsChildren(true) end
    map.back = UI.fill(map, "BACKGROUND")
    map.back:SetAllPoints()
    map.back:SetVertexColor(0, 0, 0, 0.5)
    map.edges = UI.edges(map)
    map.tiles = {}
    map.marker = map:CreateTexture(nil, "OVERLAY", nil, 2)
    map.marker:SetTexture(MARKER)
    map.marker:SetSize(26, 26)
    map.ring = map:CreateTexture(nil, "OVERLAY", nil, 1)
    map.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    map.ring:SetSize(34, 34)
    if map.ring.SetMask then map.ring:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    map.none = UI.Text(map, 12, "muted")
    map.none:SetPoint("CENTER")
    map.none:SetText(L.NO_MAP)
    panel.map = map

    local art = CreateFrame("Frame", nil, panel)
    art:SetSize(MAP_W, MODEL_H)
    -- A craft's recipe source, under its skill.
    panel.recipe = UI.Text(panel, 11, "text")
    panel.recipe:SetPoint("TOPLEFT", panel.location, "BOTTOMLEFT", 0, -3)
    panel.recipe:SetPoint("TOPRIGHT", panel.location, "BOTTOMRIGHT", 0, -3)
    panel.recipe:SetWordWrap(true)
    art:SetPoint("TOPLEFT", panel.recipe, "BOTTOMLEFT", 0, -8)
    -- Both sheets stay loaded side by side and only their alpha flips:
    -- SetTexture to the other file each loop showed a black frame while it loaded.
    art.sheets = {}
    for i = 1, 2 do
        art.sheets[i] = art:CreateTexture(nil, "ARTWORK")
        art.sheets[i]:SetAllPoints()
    end
    art.edges = UI.edges(art)
    art:SetScript("OnUpdate", function(self, elapsed)
        self.t = (self.t or 0) + elapsed
        local f = math.floor(self.t * ART_FPS) % ART_FRAMES
        if f == self.frame then return end
        self.frame = f
        local sheet, k = math.floor(f / ART_PER) + 1, f % ART_PER
        local u, v = (k % 4) * 0.25, math.floor(k / 4) * 0.1875
        for i, tex in ipairs(self.sheets) do
            tex:SetAlpha(i == sheet and 1 or 0)
            if i == sheet then tex:SetTexCoord(u, u + 0.25, v, v + 0.1875) end
        end
    end)
    art:Hide()
    panel.art = art

    panel.entrance = UI.Text(panel, 11, "text")
    panel.entrance:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 0, -6)
    panel.entrance:SetPoint("TOPRIGHT", map, "BOTTOMRIGHT", 0, -6)
    panel.entrance:SetWordWrap(true)

    panel.who = UI.Text(panel, 14, "title")
    panel.who:SetPoint("TOPLEFT", panel.entrance, "BOTTOMLEFT", 0, -12)
    panel.who:SetPoint("TOPRIGHT", panel.entrance, "BOTTOMRIGHT", 0, -12)
    panel.whoDetail = UI.Text(panel, 11, "muted")
    panel.whoDetail:SetPoint("TOPLEFT", panel.who, "BOTTOMLEFT", 0, -3)
    panel.whoDetail:SetPoint("TOPRIGHT", panel.who, "BOTTOMRIGHT", 0, -3)
    panel.whoDetail:SetWordWrap(true)

    -- A craft's reagents: a table (count and name, price each, line total), the sum, hints.
    local mats = CreateFrame("Frame", nil, panel)
    mats:SetPoint("TOPLEFT", panel.who, "BOTTOMLEFT", 0, -8)
    mats:SetPoint("TOPRIGHT", panel.who, "BOTTOMRIGHT", 0, -8)
    mats.rows = {}
    mats.headName, mats.headEach, mats.headSum = UI.Text(mats, 10, "muted"), UI.Text(mats, 10, "muted"), UI.Text(mats, 10, "muted")
    mats.rule = UI.fill(mats, "ARTWORK")
    mats.rule:SetHeight(1)
    mats.totalLabel, mats.total = UI.Text(mats, 13, "title"), UI.Text(mats, 13, "title")
    mats.age = UI.Text(mats, 11, "muted")
    mats.hints = {}
    for i = 1, 2 do
        mats.hints[i] = UI.Text(mats, 11, "accent")
        mats.hints[i]:SetWordWrap(true)
    end
    mats:Hide()
    panel.mats = mats

    panel.model = CreateFrame("PlayerModel", nil, panel)
    panel.model:SetPoint("TOPLEFT", panel.whoDetail, "BOTTOMLEFT", 0, -6)
    panel.model:SetPoint("TOPRIGHT", panel.whoDetail, "BOTTOMRIGHT", 0, -6)
    panel.model:SetHeight(MODEL_H)
    -- Drag to turn the boss around.
    panel.model:EnableMouse(true)
    panel.model:SetScript("OnMouseDown", function(self) self.turning = GetCursorPosition() end)
    panel.model:SetScript("OnMouseUp", function(self) self.turning = nil end)
    panel.model:SetScript("OnUpdate", function(self)
        if not self.turning then return end
        local x = GetCursorPosition()
        self.facing = (self.facing or 0) + (x - self.turning) * 0.02
        self.turning = x
        self:SetFacing(self.facing)
    end)
    Panel.Restyle()
end

-- The world map's tiles of mapID; false when the client has none.
local function drawMap(mapID)
    local map = panel.map
    local ok, layers = pcall(C_Map.GetMapArtLayers, mapID)
    local ok2, textures = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
    local layer = ok and type(layers) == "table" and layers[1]
    if not (layer and ok2 and type(textures) == "table" and #textures > 0) then return false end
    local scale = MAP_W / layer.layerWidth
    local cols = math.ceil(layer.layerWidth / layer.tileWidth)
    local tw, th = layer.tileWidth * scale, layer.tileHeight * scale
    for i, file in ipairs(textures) do
        local t = map.tiles[i] or map:CreateTexture(nil, "ARTWORK")
        map.tiles[i] = t
        t:SetTexture(file)
        t:SetSize(tw, th)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", map, "TOPLEFT", ((i - 1) % cols) * tw, -math.floor((i - 1) / cols) * th)
        t:Show()
    end
    for i = #textures + 1, #map.tiles do map.tiles[i]:Hide() end
    map:SetHeight(layer.layerHeight * scale)
    return true
end

local function showMap(place)
    local map = panel.map
    local e = place and place.entrance
    local drawn = e and e.mapID and C_Map and drawMap(e.mapID)
    if not drawn then
        for _, t in ipairs(map.tiles) do t:Hide() end
        map:SetHeight(MAP_W * 2 / 3)
    end
    map.marker:SetShown(drawn == true)
    map.ring:SetShown(drawn == true)
    map.none:SetShown(not drawn)
    if drawn then
        local x, y = e.x * MAP_W, -e.y * map:GetHeight()
        map.marker:ClearAllPoints()
        map.marker:SetPoint("CENTER", map, "TOPLEFT", x, y)
        map.ring:ClearAllPoints()
        map.ring:SetPoint("CENTER", map, "TOPLEFT", x, y)
    end
    panel.entrance:SetText(e and (e.detail or e.label) or "")
end

-- The drop to show: the first the journal can place, else the first.
local function pick(entry)
    for _, d in ipairs(entry.drops) do
        local place = ns.Source.Place(d)
        if place and place.entrance then return d, place end
    end
    return entry.drops[1], ns.Source.Place(entry.drops[1])
end

-- Where the recipe comes from: "Recipe: vendor Qia (Winterspring) · ...", the trainer when the craft
-- has no recipe item (AtlasLoot's recipe table, ours for Forever's new ones), nil when nothing is known.
-- A recipe the player has learned: a green check instead.
function Panel.RecipeText(spellID, made)
    if not spellID then return nil end
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then
        return "|TInterface\\Buttons\\UI-CheckBox-Check:16:16:0:-1|t |cff33dd33" .. L.RECIPE_KNOWN .. "|r"
    end
    local data = AtlasLoot and AtlasLoot.Data and AtlasLoot.Data.Recipe
    if not data then return nil end
    local recipe = data.GetRecipeForSpell(spellID) or ns.RECIPE_FOR_ITEM[made]
    if not recipe then return L.RECIPE:format(L.RECIPE_TRAINER) end
    local parts = {}
    -- Vendors carry their faction (1 Alliance, 2 Horde, 3 both): only the player's, at most two named.
    local mine = UnitFactionGroup("player") == "Horde" and 2 or 1
    local vendors = 0
    for _, s in ipairs(ns.RECIPE_SOURCES[recipe] or {}) do
        local kind, name, zone, faction = s[1], s[2], s[3], s[4]
        zone = zone > 0 and C_Map.GetAreaInfo(zone) or nil
        local skip = kind == "VENDOR" and faction and faction ~= 3 and faction ~= mine
        if kind == "VENDOR" and not skip then
            vendors = vendors + 1
            skip = vendors > 2
        end
        local text
        if kind == "QUEST" then
            text = L.RECIPE_QUEST:format(name)
        elseif name ~= "" then
            text = (kind == "VENDOR" and L.RECIPE_VENDOR or L.RECIPE_DROP):format(name)
            if zone then text = text .. " (" .. zone .. ")" end
        elseif kind == "VENDOR" then
            text = zone and L.RECIPE_VENDORS_IN:format(zone) or L.RECIPE_VENDORS
        else
            text = zone and L.RECIPE_DROP_IN:format(zone) or L.RECIPE_WORLD
        end
        if not skip then parts[#parts + 1] = text end
    end
    if vendors > 2 then parts[#parts + 1] = L.RECIPE_MORE:format(vendors - 2) end
    if #parts == 0 then return nil end
    return L.RECIPE:format(table.concat(parts, " · "))
end

-- Shows the panel beside parent for entry (nil hides it); onClose: its ×.
function Panel.Show(parent, entry, onClose)
    if not entry then
        if panel then panel:Hide() end
        return
    end
    if not panel then build(parent) end
    panel.onClose, panel.entry, panel.parent = onClose, entry, parent
    local drop, place = pick(entry)
    panel.title:SetText(place and place.name or drop.world and L.WORLD_DROP or drop.instance)
    panel.location:SetText(place and place.location or drop.world and L.WORLD_WHERE or (drop.raid and L.RAID or L.DUNGEON))
    showMap(place)
    local model = panel.model
    panel.map:SetShown(not drop.craft and not drop.world)
    panel.who:ClearAllPoints()
    local artName = drop.craft and Panel.ArtFor(drop.prof)
    local art = panel.art
    if artName and artName ~= art.name then
        for i, tex in ipairs(art.sheets) do tex:SetTexture(ART_DIR .. artName .. "_" .. i .. ".png") end
    end
    art.name, art.frame, art.t = artName, nil, 0
    art:SetShown(artName ~= nil)
    local above = artName and art or drop.craft and panel.recipe or drop.world and panel.location or panel.entrance
    panel.who:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -12)
    panel.who:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -12)
    panel.mats:SetShown(drop.craft == true)
    panel.recipe:SetText(drop.craft and Panel.RecipeText(drop.spellID, drop.item) or "")
    panel.recipe:SetShown(drop.craft == true)
    if drop.craft then
        panel.title:SetText(drop.instance)
        panel.location:SetText(L.CRAFT_SKILL:format(drop.skill or 0))
        panel.entrance:SetText("")
        panel.who:SetText(L.REAGENTS)
        panel.whoDetail:SetText("")
        Panel.ShowMats(drop)
        model:Hide()
    elseif drop.world then
        panel.entrance:SetText("")
        panel.who:SetText("")
        panel.whoDetail:SetText("")
        model:Hide()
    elseif drop.quest then
        panel.who:SetText(L.QUEST_NAME:format(drop.quest))
        panel.whoDetail:SetText(drop.giver and L.QUEST_GIVER:format(drop.giver) or "")
        model:Hide()
    else
        panel.who:SetText(drop.boss)
        panel.whoDetail:SetText(drop.rate and L.DROP_RATE:format(drop.rate) or "")
        local display = ns.Source.Display(drop.npcID)
        model:Show()
        if model.ClearModel then model:ClearModel() end
        if display then
            model:SetDisplayInfo(display)
        elseif drop.npcID then
            model:SetCreature(drop.npcID)
        else
            model:Hide()
        end
        model.facing = 0
        model:SetFacing(0)
    end
    panel:Show()
end

-- The art for an AtlasLoot crafting table ("TailoringBC" -> "Tailoring"), or nil.
function Panel.ArtFor(key)
    for _, name in ipairs(ART) do
        if type(key) == "string" and key:sub(1, #name) == name then return name end
    end
end

function Panel.Restyle()
    if not panel then return end
    local UI = ns.Window.UI
    ns.ThemeArt.StyleWindow(panel, panel.bar)
    panel.map.none:SetText(L.NO_MAP)
    panel.title:ClearAllPoints()
    panel.title:SetPoint("LEFT", panel.bar, "LEFT", ns.ThemeArt.TextStart(TITLE_H) or PAD, 0)
    panel.title:SetPoint("RIGHT", panel.bar, "RIGHT", -TITLE_H, 0)
    UI.paintEdges(panel.map.edges, UI.colour("muted"), 0.45)
    UI.paintEdges(panel.art.edges, UI.colour("muted"), 0.45)
    local c = UI.colour("muted")
    panel.mats.rule:SetVertexColor(c[1], c[2], c[3], 0.5)
    local a = UI.colour("accent")
    panel.map.ring:SetVertexColor(a[1], a[2], a[3], 0.55)
end

local MATS_ROW, MATS_EACH, MATS_SUM = 16, 76, 0   -- row height; right edges of the price columns

local function matsRow(mats, i)
    local UI = ns.Window.UI
    local row = mats.rows[i]
    if row then return row end
    row = { name = UI.Text(mats, 11, "text"), each = UI.Text(mats, 11, "muted"), sum = UI.Text(mats, 11, "text") }
    local y = -(16 + (i - 1) * MATS_ROW)
    row.name:SetPoint("TOPLEFT", mats, "TOPLEFT", 0, y)
    row.name:SetPoint("TOPRIGHT", mats, "TOPRIGHT", -(MATS_EACH + 56), y)
    row.each:SetPoint("TOPRIGHT", mats, "TOPRIGHT", -MATS_EACH, y)
    row.sum:SetPoint("TOPRIGHT", mats, "TOPRIGHT", -MATS_SUM, y)
    row.each:SetJustifyH("RIGHT")
    row.sum:SetJustifyH("RIGHT")
    -- The whole row is the item: its tooltip, shift-click links it (or searches it in the open auction house).
    local hit = CreateFrame("Button", nil, mats)
    hit:SetPoint("TOPLEFT", mats, "TOPLEFT", 0, y + 2)
    hit:SetPoint("TOPRIGHT", mats, "TOPRIGHT", 0, y + 2)
    hit:SetHeight(MATS_ROW)
    hit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.id)
        GameTooltip:Show()
    end)
    hit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    hit:SetScript("OnClick", function(self)
        local link = C_Item and C_Item.GetItemInfo and select(2, C_Item.GetItemInfo(self.id))
        if link and IsModifiedClick and IsModifiedClick("CHATLINK") and HandleModifiedItemClick then
            HandleModifiedItemClick(link)
        end
    end)
    row.hit = hit
    mats.rows[i] = row
    return row
end

-- The reagents table of a craft, its sum and what to do about missing or old prices.
function Panel.ShowMats(drop)
    local mats, P = panel.mats, ns.Prices
    mats.headName:SetPoint("TOPLEFT", mats, "TOPLEFT", 0, 0)
    mats.headEach:SetPoint("TOPRIGHT", mats, "TOPRIGHT", -MATS_EACH, 0)
    mats.headSum:SetPoint("TOPRIGHT", mats, "TOPRIGHT", -MATS_SUM, 0)
    mats.headEach:SetText(L.MATS_EACH)
    mats.headSum:SetText(L.MATS_LINE)
    local reagents, counts = drop.reagents or {}, drop.counts or {}
    for i, id in ipairs(reagents) do
        local row = matsRow(mats, i)
        local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)
        if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        local n, price = counts[i] or 1, P.Get(id)
        row.name:SetText(("%d× %s"):format(n, name or ("#" .. id)))
        row.hit.id = id
        row.each:SetText(price and P.Money(price) or "–")
        row.sum:SetText(price and P.Money(price * n) or "–")
        for _, fs in pairs(row) do fs:Show() end
    end
    for i = #reagents + 1, #mats.rows do
        for _, fs in pairs(mats.rows[i]) do fs:Hide() end
    end
    local y = -(16 + #reagents * MATS_ROW + 2)
    mats.rule:SetPoint("TOPLEFT", mats, "TOPLEFT", 0, y)
    mats.rule:SetPoint("TOPRIGHT", mats, "TOPRIGHT", 0, y)
    local sum, all, at = P.Total(reagents, counts)
    mats.totalLabel:SetPoint("TOPLEFT", mats, "TOPLEFT", 0, y - 6)
    mats.total:SetPoint("TOPRIGHT", mats, "TOPRIGHT", -MATS_SUM, y - 6)
    mats.totalLabel:SetText(L.MATS_SUM)
    mats.total:SetText(sum > 0 and P.Money(sum) or "–")
    mats.age:SetPoint("TOPRIGHT", mats.total, "BOTTOMRIGHT", 0, -3)
    mats.age:SetText(at and L.MATS_AGE:format(P.Age(at)) or "")
    local hints = {}
    if sum == 0 and #reagents > 0 then hints[#hints + 1] = L.MATS_NONE
    elseif not all then hints[#hints + 1] = L.MATS_SOME end
    if at and time() - at >= 2 * 86400 then hints[#hints + 1] = L.MATS_OLD end
    local above = nil
    for i, fs in ipairs(mats.hints) do
        fs:ClearAllPoints()
        if above then
            fs:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -8)
            fs:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -8)
        else
            fs:SetPoint("TOPLEFT", mats, "TOPLEFT", 0, y - 44)
            fs:SetPoint("TOPRIGHT", mats, "TOPRIGHT", 0, y - 44)
        end
        fs:SetText(hints[i] or "")
        above = fs
    end
    mats:SetHeight(-y + 44)
end

-- Shown again with what it shows (new prices).
function Panel.Refresh()
    if panel and panel:IsShown() and panel.entry then Panel.Show(panel.parent, panel.entry, panel.onClose) end
end

function Panel.IsShown() return panel ~= nil and panel:IsShown() end
function Panel.Frame() return panel end
