local ADDON, ns = ...
local L = ns.L

--[[
The shopping list: items the player wants, each with an amount. Counted from
the bags, done once enough are there. Per character (ForeverLootFinderChar.
shopping = { entries = { { itemID, goal } }, note = { shown, x, y, w, h } }).
Where an item comes from is read from the loot tables (Source), nothing stored.
]]
local Shopping = {}
ns.Shopping = Shopping

Shopping.MAX_GOAL = 9999
Shopping.MIN_SEARCH = 3     -- letters before the search suggests
Shopping.MAX_RESULTS = 12
local RECIPE = 9                                  -- item class: recipes, patterns, plans

local function data()
    local char = ns.CharDB()
    char.shopping = char.shopping or { entries = {} }
    return char.shopping
end

local listeners = {}
function Shopping.OnChange(fn) listeners[#listeners + 1] = fn end
local function changed() for _, fn in ipairs(listeners) do fn() end end

function Shopping.Entries() return data().entries end
function Shopping.Note() return data().note end
function Shopping.SetNote(note)
    data().note = note
    changed()
end

local function validGoal(n)
    n = math.floor(tonumber(n) or 1)
    return math.max(1, math.min(Shopping.MAX_GOAL, n))
end

local function find(id)
    for i, e in ipairs(data().entries) do
        if e.itemID == id then return i, e end
    end
end

-- On the list already: its amount is set instead.
function Shopping.Add(id, goal)
    local _, e = find(id)
    if e then
        e.goal = validGoal(goal or e.goal)
    else
        table.insert(data().entries, { itemID = id, goal = validGoal(goal) })
    end
    changed()
end

function Shopping.SetGoal(id, goal)
    local _, e = find(id)
    if e then
        e.goal = validGoal(goal)
        changed()
    end
end

function Shopping.Remove(id)
    local i = find(id)
    if i then
        table.remove(data().entries, i)
        changed()
    end
end

function Shopping.Has(id) return find(id) ~= nil end

-- Order: "custom" (as the player dragged it), "origin" or "slot" (in the
-- order of the window's slot bar, what is not worn last); then by name.
Shopping.SORTS = { "custom", "origin", "slot" }
function Shopping.Sort() return data().sort or "custom" end
function Shopping.SetSort(mode)
    data().sort = mode
    changed()
end

-- Moves an item to a place of the custom order.
function Shopping.Move(id, to)
    local i, e = find(id)
    local entries = data().entries
    if not i or to < 1 or to > #entries or to == i then return end
    table.remove(entries, i)
    table.insert(entries, to, e)
    changed()
end

local function slotIndex(id)
    local item = ns.Items.Instant(id)
    local loc = item and item.equipLoc
    for i, slot in ipairs(ns.Rules.SLOTS) do
        for _, l in ipairs(slot.locs or {}) do
            if l == loc then return i end
        end
    end
    return #ns.Rules.SLOTS + 1
end

local function nameOf(id) return (ns.Items.Get(id) or {}).name or "" end

function Shopping.Sorted()
    local list, mode = {}, Shopping.Sort()
    for i, e in ipairs(data().entries) do list[i] = e end
    if mode == "custom" then return list end
    local key = {}
    for _, e in ipairs(list) do
        key[e] = mode == "slot" and slotIndex(e.itemID) or (Shopping.Origin(e.itemID) or "\255")
    end
    table.sort(list, function(a, b)
        if key[a] ~= key[b] then return key[a] < key[b] end
        return nameOf(a.itemID) < nameOf(b.itemID)
    end)
    return list
end

-- Where it comes from, for "Devout Crown (Scholomance)": the first of its
-- sources in the loot tables; nil when they do not know it.
function Shopping.Origin(id)
    local d = ns.Source.ByItem(id)[1]
    if not d then return nil end
    if d.craft then return L.FILTER_CRAFTING end
    if d.world then return L.WORLD_DROP end
    return d.instance
end

-- Whether it can drop where the player is now: a boss of this dungeon or raid
-- has it. AtlasLoot's InstanceID where it has one (not Dire Maul, not Forever's
-- new dungeons), else the name, both in the client's language.
function Shopping.DropsHere(id)
    local here = ns.Source.Here()
    if not here then return false end
    for _, d in ipairs(ns.Source.ByItem(id)) do
        if ns.Source.IsHere(d, here) then return true end
    end
    return false
end

-- What a row shows: name and quality from the finder's item cache (asked for
-- once, kept once loaded), icon, origin, how many are in the bags and whether
-- that is enough.
function Shopping.Line(entry)
    local id = entry.itemID
    local have = C_Item.GetItemCount(id) or 0
    local item = ns.Items.Get(id) or {}
    ns.Items.Request(item.id and item)
    return {
        name = item.name or "…", icon = item.icon, quality = item.quality, origin = Shopping.Origin(id),
        have = have, goal = entry.goal, done = have >= entry.goal, here = Shopping.DropsHere(id),
    }
end

-- The window's search, without recipes, patterns and plans: names come from
-- the finder's item cache, so the same items are found, and they stay found
-- (the client forgets loaded items; asking it again while typing flickered).
function Shopping.Search(text)
    text = (text or ""):lower()
    if #text < Shopping.MIN_SEARCH then return {} end
    local found = {}
    for _, e in ipairs(ns.Filter.Run(ns.Filter.Options({ text = text }))) do
        local item = e.item
        if item.classID ~= RECIPE then
            found[#found + 1] = { id = item.id, name = item.name, quality = item.quality,
                start = item.name:lower():find(text, 1, true) == 1 }
        end
    end
    table.sort(found, function(a, b)
        if a.start ~= b.start then return a.start end
        return a.name < b.name
    end)
    for i = #found, Shopping.MAX_RESULTS + 1, -1 do found[i] = nil end
    return found
end

-- The bags changed: counts and ticks follow.
local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")   -- into or out of a dungeon: "drops here" marks follow
events:SetScript("OnEvent", function(_, event)
    -- shortcut: name stores of the 1.9 test builds, never released; drop this line in a later version.
    if event == "PLAYER_ENTERING_WORLD" then ns.DB().names, ns.DB().items = nil, nil end
    changed()
end)
