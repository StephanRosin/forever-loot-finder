local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Items.lua -- what the client knows of an item by id. The equip location,
class and icon come at once (GetItemInfoInstant); name, link, quality,
level, required level and stats only once the item is in the client's
cache: until then it is asked for (RequestLoadItemDataByID) and
Items.OnLoaded's listeners hear when it arrives. Forever's new items the
server has not handed out to anyone yet never arrive: they stay "unknown".
-----------------------------------------------------------------------------]]
local Items = {}
ns.Items = Items

local cache, asked, listeners = {}, {}, {}

local function instant(id)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then return nil end
    local _, _, _, equipLoc, icon, classID, subClassID = fn(id)
    return equipLoc, icon, classID, subClassID
end

local function full(id)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then return nil end
    local name, link, quality, ilvl, reqLevel = fn(id)
    return name, link, quality, ilvl, reqLevel
end

local function stats(link)
    local fn = (C_Item and C_Item.GetItemStats) or GetItemStats
    return ns.Rules.Stats(fn and link and fn(link) or nil)
end

-- The tooltip's effect lines, the trigger cut off: { kind, text }.
local TRIGGERS = { { "USE", "ITEM_SPELL_TRIGGER_ONUSE", "Use:" }, { "EQUIP", "ITEM_SPELL_TRIGGER_ONEQUIP", "Equip:" },
    { "PROC", "ITEM_SPELL_TRIGGER_ONPROC", "Chance on hit:" } }
local function effects(id)
    local get = C_TooltipInfo and C_TooltipInfo.GetItemByID
    local ok, data = false, nil
    if get then ok, data = pcall(get, id) end
    local list = {}
    for _, line in ipairs(ok and data and data.lines or {}) do
        local text = line.leftText
        if type(text) == "string" then
            for _, t in ipairs(TRIGGERS) do
                local prefix = _G[t[2]] or t[3]
                if text:sub(1, #prefix) == prefix then
                    list[#list + 1] = { kind = t[1], text = (text:sub(#prefix + 1):gsub("^%s+", "")) }
                    break
                end
            end
        end
    end
    return list
end

local function request(id)
    if asked[id] then return end
    asked[id] = true
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
end

-- The item, or nil when the client does not know the id at all. `loaded`
-- tells whether name, level and stats are there; not loaded, it is not
-- asked for (Items.Request): thousands of ids at once would flood the
-- server, only those that pass the cheap filters are asked for.
function Items.Get(id)
    local item = cache[id]
    if item and item.loaded then return item end
    if not item then
        local equipLoc, icon, classID, subClassID = instant(id)
        if not equipLoc then return nil end
        item = { id = id, equipLoc = equipLoc, icon = icon, classID = classID, subClassID = subClassID }
        cache[id] = item
    end
    local name, link, quality, ilvl, reqLevel = full(id)
    if name then
        item.name, item.link, item.quality, item.ilvl, item.reqLevel = name, link, quality, ilvl, reqLevel or 0
        item.stats = stats(link)
        item.effects = effects(id)
        item.loaded = true
    end
    return item
end

function Items.Request(item)
    if item and not item.loaded then request(item.id) end
end

-- What is worn in an inventory slot, nil when empty.
function Items.Worn(invSlot)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", invSlot)
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return nil end
    local item = Items.Get(id)
    Items.Request(item)
    -- The worn link may carry an enchant: its stats as worn.
    if item and item.loaded then
        local worn = setmetatable({ link = link, stats = stats(link) }, { __index = item })
        return worn
    end
    return item
end

function Items.OnLoaded(fn) listeners[#listeners + 1] = fn end

-- Forgets what was not loaded yet (the tests).
function Items.Reset() cache, asked = {}, {} end

-- Many items arrive in a burst: one notice for all of them, a moment later.
local pending = false
local function arrived(id)
    local item = cache[id]
    if item then item.loaded = nil end
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        for _, fn in ipairs(listeners) do fn() end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, _, id, ok)
    if ok ~= false and id then arrived(id) end
end)
