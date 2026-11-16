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

-- Shows the panel beside parent for entry (nil hides it); onClose: its ×.
function Panel.Show(parent, entry, onClose)
    if not entry then
        if panel then panel:Hide() end
        return
    end
    if not panel then build(parent) end
    panel.onClose = onClose
    local drop, place = pick(entry)
    panel.title:SetText(place and place.name or drop.instance)
    panel.location:SetText(place and place.location or (drop.raid and L.RAID or L.DUNGEON))
    showMap(place)
    local model = panel.model
    panel.map:SetShown(not drop.craft)
    panel.who:ClearAllPoints()
    local above = drop.craft and panel.location or panel.entrance
    panel.who:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -12)
    panel.who:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -12)
    if drop.craft then
        panel.title:SetText(drop.instance)
        panel.location:SetText(L.CRAFT_SKILL:format(drop.skill or 0))
        panel.entrance:SetText("")
        panel.who:SetText(L.REAGENTS)
        local parts = {}
        for i, id in ipairs(drop.reagents or {}) do
            local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)
            if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            parts[#parts + 1] = ("%d× %s"):format((drop.counts or {})[i] or 1, name or ("#" .. id))
        end
        panel.whoDetail:SetText(table.concat(parts, ", "))
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

function Panel.Restyle()
    if not panel then return end
    local UI = ns.Window.UI
    ns.ThemeArt.StyleWindow(panel, panel.bar)
    panel.map.none:SetText(L.NO_MAP)
    panel.title:ClearAllPoints()
    panel.title:SetPoint("LEFT", panel.bar, "LEFT", ns.ThemeArt.TextStart(TITLE_H) or PAD, 0)
    panel.title:SetPoint("RIGHT", panel.bar, "RIGHT", -TITLE_H, 0)
    UI.paintEdges(panel.map.edges, UI.colour("muted"), 0.45)
    local a = UI.colour("accent")
    panel.map.ring:SetVertexColor(a[1], a[2], a[3], 0.55)
end

function Panel.IsShown() return panel ~= nil and panel:IsShown() end
function Panel.Frame() return panel end
