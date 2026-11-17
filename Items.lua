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

-- A "Classes: Mage, Warlock" line -> { MAGE = true, WARLOCK = true }, nil without one.
-- Names may come coloured (|cff...Priest|r); a name that is no class is left out,
-- and a line naming none leaves the item to everyone rather than to no one.
local classPrefix, classTokens
local function classesOf(text)
    if not classPrefix then
        classPrefix = (ITEM_CLASSES_ALLOWED or "Classes: %s"):gsub("%%s.*$", "")
        classTokens = {}
        for _, token in ipairs(ns.Rules.CLASSES) do classTokens[token:lower()] = token end
        for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
            for token, name in pairs(names) do classTokens[name:lower()] = token end
        end
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if text:sub(1, #classPrefix) ~= classPrefix then return nil end
    local set, any = {}, false
    for name in text:sub(#classPrefix + 1):gmatch("[^,]+") do
        local token = classTokens[name:gsub("^%s+", ""):gsub("%s+$", ""):lower()]
        if token then set[token], any = true, true end
    end
    return any and set or nil
end

-- The tooltip's effect lines, the trigger cut off: { kind, text }; and the
-- classes it is limited to (nil: any).
local TRIGGERS = { { "USE", "ITEM_SPELL_TRIGGER_ONUSE", "Use:" }, { "EQUIP", "ITEM_SPELL_TRIGGER_ONEQUIP", "Equip:" },
    { "PROC", "ITEM_SPELL_TRIGGER_ONPROC", "Chance on hit:" } }
local function effects(id)
    local get = C_TooltipInfo and C_TooltipInfo.GetItemByID
    local ok, data = false, nil
    if get then ok, data = pcall(get, id) end
    local list, classes = {}, nil
    for _, line in ipairs(ok and data and data.lines or {}) do
        local text = line.leftText
        if type(text) == "string" then
            classes = classes or classesOf(text)
            for _, t in ipairs(TRIGGERS) do
                local prefix = _G[t[2]] or t[3]
                if text:sub(1, #prefix) == prefix then
                    list[#list + 1] = { kind = t[1], text = (text:sub(#prefix + 1):gsub("^%s+", "")) }
                    break
                end
            end
        end
    end
    return list, classes
end

-- How long an asked-for item may take before it counts as "no data".
Items.WAIT = 10

local notify
local function request(id)
    if asked[id] then return end
    asked[id] = GetTime()
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    C_Timer.After(Items.WAIT, function()
        local item = cache[id]
        if item and not item.loaded then notify() end   -- its row turns from loading to no data
    end)
end

-- What the client knows at once (equip location, class, icon), nil when it
-- does not know the id at all. Cheap: the filter asks it of thousands.
function Items.Instant(id)
    local item = cache[id]
    if item then return item end
    local equipLoc, icon, classID, subClassID = instant(id)
    if not equipLoc then return nil end
    item = { id = id, equipLoc = equipLoc, icon = icon, classID = classID, subClassID = subClassID }
    cache[id] = item
    return item
end

-- Name, level and stats when the client has them (`loaded`). Not asked for
-- here (Items.Request): only what passes the cheap filters is. The tooltip's
-- effect lines are read only for items without plain stats.
function Items.Full(item)
    if not item or item.loaded then return item end
    local name, link, quality, ilvl, reqLevel = full(item.id)
    if name then
        item.name, item.link, item.quality, item.ilvl, item.reqLevel = name, link, quality, ilvl, reqLevel or 0
        item.stats, item.otherStats, item.bonusArmor = stats(link)
        item.onUse = ns.Rules.AddUse(item.id, item.stats)
        if ns.Rules.HasStats(item.stats) then
            item.effects = {}
        else
            item.effects, item.classes = effects(item.id)
            item.classesRead = true
        end
        item.loaded = true
    end
    return item
end

function Items.Get(id) return Items.Full(Items.Instant(id)) end

-- Whether a loaded item is for the class ("Classes:" on its tooltip). The
-- tooltip is read once, and only for items the filter still keeps.
function Items.ForClass(item, class)
    if not item.classesRead then
        local _
        _, item.classes = effects(item.id)
        item.classesRead = true
    end
    return item.classes == nil or item.classes[class] == true
end

function Items.Request(item)
    if item and not item.loaded then request(item.id) end
end

-- Asked for, and the server has nothing (said so, or no answer in Items.WAIT seconds).
function Items.NoData(item)
    if item.loaded then return false end
    local at = asked[item.id]
    return item.failed == true or (at ~= nil and GetTime() - at >= Items.WAIT)
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
        local worn = setmetatable({ link = link, stats = (stats(link)) }, { __index = item })
        ns.Rules.AddUse(id, worn.stats)
        return worn
    end
    return item
end

-- A loaded item without stats read again (Forever's new crafts get them later), at most every
-- Items.RETRY seconds: each read makes the client answer, and each answer rebuilt the list.
Items.RETRY = 30
function Items.Retry(item)
    if (item.retryAt or 0) > GetTime() then return false end
    item.retryAt = GetTime() + Items.RETRY
    item.loaded, item.classesRead = nil, nil
    return true
end

function Items.OnLoaded(fn) listeners[#listeners + 1] = fn end

-- Forgets what was not loaded yet (the tests).
function Items.Reset() cache, asked = {}, {} end

-- Many items arrive in a burst: one notice for all of them, a moment later.
local pending = false
function notify()
    if pending then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        for _, fn in ipairs(listeners) do fn() end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
-- Only answers to what we asked matter: other addons and the bags ask too.
events:SetScript("OnEvent", function(_, _, id, ok)
    local item = id and cache[id]
    if not item or not asked[id] then return end
    -- Only news rebuild the list: an item the client still cannot read answers again on
    -- every read, and every rebuild reads it (a loop of rebuilds in game).
    if ok == false then
        if not item.failed then item.failed = true; notify() end
    elseif not item.loaded then
        if Items.Full(item).loaded then notify() end
    elseif not ns.Rules.HasStats(item.stats) and Items.Retry(item) then
        notify()
    end
end)
