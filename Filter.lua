local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Filter.lua -- the list: every item the source knows, kept when the class can
wear it (now: at the player's level and with the armour learned), it goes
into the chosen slot, it drops where the player looks (dungeons, raids) and
it fits one of the chosen roles (Rules.ForRole).

With "better than worn" each item is compared with what is worn in that
slot (the weaker of two rings or trinkets, or the one slot the character
window asked for), per chosen role by the role's points:
  UPGRADE   more points (5 % and more) and no less of the role's own stat
  ALT       about as many (from 90 %), or more points but less of the own
            stat (less healing, more spirit: the player's call), or an
            item whose effects are no stats (a trinket's "Use:"), or one
            the client has not loaded yet
  (dropped) clearly fewer points
-----------------------------------------------------------------------------]]
local Filter = {}
ns.Filter = Filter

local Rules, Items = ns.Rules, ns.Items

-- POINTS: the role's points, best first (only with a slot picked: across slots a
-- chest always outscores a ring, so the window sorts by item level then).
Filter.SORTS = { "POINTS", "ILVL", "QUALITY", "NAME" }
function Filter.SortFor(sort, slot)
    if sort == "POINTS" and not slot then return "ILVL" end
    return sort
end
local UPGRADE_SHARE, ALT_SHARE, UPGRADE_MIN = 1.05, 0.9, 0.5

-- The points the worn item has for a role (fitting or not: a worn item is
-- compared as it is), and its own stat.
local function wornFor(role, worn, class)
    if not worn or not worn.loaded then return 0, 0 end
    if not Rules.HasStats(worn.stats) then return 0, 0, true end
    -- Fitting the role or not (an excluded stat): weighed as it is.
    local points, main = Rules.Points(role, worn.stats, class)
    return points, main or 0
end

-- The weakest of the worn items with stats for a role; true third when all
-- worn are effects only (an on-use trinket: nothing is surely better).
local function weakest(role, wornList, class)
    -- An empty ring or trinket slot: anything fills it.
    if wornList.empty then return 0, 0, false, nil end
    local bestP, bestM, bestItem, unclear
    for _, worn in ipairs(wornList) do
        local p, m, effectOnly = wornFor(role, worn, class)
        if effectOnly then
            unclear = true
        elseif not bestP or p < bestP then
            bestP, bestM, bestItem = p, m, worn
        end
    end
    return bestP or 0, bestM or 0, unclear and not bestP, bestItem or wornList[1]
end

-- The worn item an item of `slot` is compared with for `role` (the weaker of
-- two rings or trinkets, or the one invSlot), nil when the slot is empty.
-- A two-hander replaces both hands: the worn main and off hand count as one
-- (their stats summed). Without an off hand the main hand stands alone.
local function bothHands(mainList, offList)
    local a, b = mainList[1], offList[1]
    if not (a and b) then return mainList end
    if not (a.loaded and b.loaded) then return { a } end
    local stats = {}
    for _, w in ipairs({ a, b }) do
        for k, v in pairs(w.stats or {}) do stats[k] = (stats[k] or 0) + v end
    end
    return { { id = a.id, loaded = true, quality = a.quality, name = (a.name or "?") .. " + " .. (b.name or "?"), stats = stats } }
end
Filter.BothHands = bothHands

local function twoHanded(item, slot)
    return slot and slot.key == "MAINHAND" and item and item.equipLoc == "INVTYPE_2HWEAPON"
end

function Filter.Against(slot, invSlot, role, class, item)
    local list = Filter.WornIn(slot, invSlot)
    if twoHanded(item, slot) then list = bothHands(list, Filter.WornIn(Rules.SLOT.OFFHAND)) end
    local _, _, _, worn = weakest(role, list, class or select(2, UnitClass("player")))
    return worn
end

-- Stat by stat what item gives over worn: { { key, delta } } in a fixed order.
local ORDER = { "STR", "AGI", "STA", "INT", "SPI", "HEAL", "SPELLDMG", "MP5", "SHIT", "SCRIT", "AP", "RAP", "FAP",
    "HIT", "RHIT", "CRIT", "RCRIT", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "ARMOR", "DPS",
    "FIREDMG", "FROSTDMG", "SHADOWDMG", "NATUREDMG", "ARCANEDMG", "HOLYDMG" }
function Filter.Diff(item, worn)
    local a, b, list = item.stats or {}, worn and worn.stats or {}, {}
    for _, k in ipairs(ORDER) do
        local d = (a[k] or 0) - (b[k] or 0)
        if math.abs(d) >= 0.5 then list[#list + 1] = { key = k, delta = d } end
    end
    return list
end

function Filter.Verdict(points, main, wornPoints, wornMain)
    if points > wornPoints * UPGRADE_SHARE + UPGRADE_MIN and (main == nil or main >= wornMain) then
        return "UPGRADE"
    end
    if points >= wornPoints * ALT_SHARE or points > wornPoints then return "ALT" end
    return nil
end

local RANK = { UPGRADE = 2, ALT = 1 }

local function evaluate(item, o, slot)
    local stats = item.stats or {}
    local entry = { item = item, roles = {}, slot = slot }
    if not item.loaded then
        entry.unclear = true
    elseif not Rules.HasStats(stats) then
        entry.unclear = true
        -- Only stats no role weighs (resistances), and no effect: out.
        if item.otherStats and #(item.effects or {}) == 0 then return nil end
        local serves = Rules.EffectRoles(item.effects, GetLocale(), o.class)
        if serves then
            local any = false
            for _, role in ipairs(Rules.ROLES) do any = any or (o.roles[role] and serves[role]) or false end
            if not any then return nil end
        end
    else
        local wornHere = slot and o.worn and o.worn(slot)
        if wornHere and twoHanded(item, slot) then wornHere = bothHands(wornHere, o.worn(Rules.SLOT.OFFHAND)) end
        for _, role in ipairs(Rules.ROLES) do
            -- Warriors and paladins tank with a shield: no two-handers (bears may).
            local twoHandTank = role == "TANK" and item.equipLoc == "INVTYPE_2HWEAPON" and o.class ~= "DRUID"
            if o.roles[role] and not twoHandTank then
                local room = Rules.HitRoom(role, o.class, wornHere)
                local fits, points, main = Rules.ForRole(role, stats, o.class, room)
                -- Tanks need hit too: on request hit items count (points > 0: nothing excluded).
                local hit = role == "TANK" and o.tankHit and (stats.HIT or 0) > 0
                if hit then fits, entry.hit = fits or points > 0, stats.HIT end
                if fits then entry.roles[#entry.roles + 1] = { role = role, points = points, main = main, room = room } end
            end
        end
        if #entry.roles == 0 then return nil end
        for _, r in ipairs(entry.roles) do
            if not entry.points or r.points > entry.points then entry.points, entry.pointsRole, entry.pointsRoom = r.points, r.role, r.room end
        end
    end
    if not o.better then return entry end
    -- What is worn is no alternative to itself, in either ring or trinket slot.
    for _, worn in ipairs(Filter.WornIn(slot)) do
        if worn.id == item.id then return nil end
    end
    if entry.unclear then
        entry.verdict = "ALT"
    else
        local wornList = o.worn(slot)
        if twoHanded(item, slot) then wornList = bothHands(wornList, o.worn(Rules.SLOT.OFFHAND)) end
        -- A one-hander or off hand beside a worn two-hander: half a pair, at best an alternative.
        local halfPair = (slot.key == "MAINHAND" or slot.key == "OFFHAND") and item.equipLoc ~= "INVTYPE_2HWEAPON"
            and (o.worn(Rules.SLOT.MAINHAND)[1] or {}).equipLoc == "INVTYPE_2HWEAPON"
        for _, r in ipairs(entry.roles) do
            local wp, wm, wornUnclear = weakest(r.role, wornList, o.class)
            r.verdict = Filter.Verdict(r.points, r.main, wp, wm)
            if (wornUnclear or halfPair) and r.verdict then r.verdict = "ALT" end
            r.delta = r.points - wp
            if r.verdict and (not entry.verdict or RANK[r.verdict] > RANK[entry.verdict]) then
                entry.verdict, entry.delta = r.verdict, r.delta
            end
        end
    end
    if not entry.verdict then return nil end
    if entry.verdict == "ALT" and not o.alternatives then return nil end
    return entry
end

local function compare(sort)
    return function(a, b)
        local ia, ib = a.item, b.item
        local la, lb = ia.ilvl or -1, ib.ilvl or -1
        local qa, qb = ia.quality or -1, ib.quality or -1
        local na, nb = ia.name or "", ib.name or ""
        -- What the column shows: the difference to the worn one (two-handers against both hands), else the points.
        local pa, pb = a.delta or a.points or -math.huge, b.delta or b.points or -math.huge
        if sort == "POINTS" then
            if pa ~= pb then return pa > pb end
            if la ~= lb then return la > lb end
        elseif sort == "NAME" then
            if na ~= nb then return na < nb end
        elseif sort == "QUALITY" then
            if qa ~= qb then return qa > qb end
            if la ~= lb then return la > lb end
        else
            if la ~= lb then return la > lb end
            if qa ~= qb then return qa > qb end
        end
        if na ~= nb then return na < nb end
        return ia.id < ib.id
    end
end

-- o: class, level, roles (set), slot (key or nil), now, bestArmor, dungeons,
-- raids, better, alternatives, text, sort, worn(slot) -> list of worn items.
-- Returns the entries ({ item, drops, roles, verdict, delta, unclear }),
-- and how many items the client does not know.
function Filter.Run(o)
    Rules.ReadChar()
    -- The worn items once per slot and run: every item asks them (hit room), thousands without a filter.
    local wornOf, worn = {}, o.worn
    if worn then
        o = setmetatable({ worn = function(slot)
            local w = wornOf[slot]
            if not w then w = worn(slot); wornOf[slot] = w end
            return w
        end }, { __index = o })
    end
    local list, seen, unknown = {}, {}, 0
    local text = o.text and o.text ~= "" and o.text:lower() or nil
    -- A search is global: every source, slot, class and role; only the name counts.
    local global = text ~= nil
    local plain = global and setmetatable({ better = false }, { __index = o }) or o
    local wearLevel = o.now and o.level or nil
    local wanted = o.slot and Rules.SLOT[o.slot]
    -- "Now": quests only from their level and not handed in. Crafts stay without the profession (bought, still
    -- worn); an item whose tooltip asks for a profession to be worn needs it.
    local ranks = o.now and Items.Skills() or nil
    local function canQuest(d)
        return (d.requires or 0) <= o.level
            and not (d.questID and C_QuestLog.IsQuestFlaggedCompleted(d.questID))
    end
    for _, drop in ipairs(ns.Source.Drops()) do
        local id = drop.item
        if not seen[id] then
            seen[id] = true
            local drops = {}
            for _, d in ipairs(ns.Source.ByItem(id)) do
                local wanted
                if global then
                    wanted = true
                elseif o.here then
                    wanted = ns.Source.IsHere(d, o.here)
                elseif d.world then
                    wanted = o.world
                elseif d.vendor then
                    wanted = o.vendors
                elseif d.craft then
                    wanted = o.crafting
                elseif d.quest then
                    wanted = o.quests and (not d.faction or d.faction == "Both" or d.faction == o.faction)
                        and (not d.classOnly or tostring(d.classOnly):upper() == o.class)
                        and not (o.now and not canQuest(d))
                else
                    wanted = (d.raid and o.raids) or (not d.raid and o.dungeons)
                end
                if wanted then drops[#drops + 1] = d end
            end
            local item = #drops > 0 and Items.Instant(id) or nil
            if #drops > 0 and not item then unknown = unknown + 1 end
            -- The cheap checks first (equip location, class, armour type), the full item only then.
            local slot = item and (not global and wanted or Rules.SlotOf(item.equipLoc, o.class)) or nil
            local keep = item ~= nil and global or slot ~= nil and Rules.InSlot(slot, item.equipLoc, o.class)
                and Rules.CanWear(o.class, item.classID, item.subClassID, item.equipLoc, wearLevel)
                and not (o.bestArmor and not Rules.IsBestArmor(o.class, item.classID, item.subClassID,
                    item.equipLoc, wearLevel))
            if keep then Items.Full(item) end
            keep = keep and not (not global and item.loaded and not Items.ForClass(item, o.class))
                and not (not global and o.now and item.loaded and item.reqLevel > o.level)
                and not (not global and o.now and item.loaded and not Items.SkillMet(item, ranks))
                and not (text and not (item.name and item.name:lower():find(text, 1, true)))
            if keep then Items.Request(item) end
            -- Loaded, but neither stats nor an effect: the client does not know
            -- the item yet (Forever's new crafts); it waits like an unknown one.
            if keep and item.loaded and not Rules.HasStats(item.stats) and not item.otherStats
                and #(item.effects or {}) == 0 then
                keep, unknown = false, unknown + 1
                ns.Items.Retry(item) -- the stats may come later: read again, now and then
            end
            local entry = keep and (evaluate(item, plain, slot) or global and { item = item, roles = {}, slot = slot })
            if entry then
                entry.drops = drops
                list[#list + 1] = entry
            end
        end
    end
    local sortStart = debugprofilestop and debugprofilestop() or 0
    table.sort(list, compare(Filter.SortFor(o.sort, o.slot)))
    Filter.perf = { sort = (debugprofilestop and debugprofilestop() or 0) - sortStart, items = #ns.Source.Drops() }
    return list, unknown
end

-- The worn items of a slot (both rings, both trinkets), or of one
-- inventory slot.
function Filter.WornIn(slot, invSlot)
    local list = {}
    for _, inv in ipairs(invSlot and { invSlot } or slot.inv) do
        local worn = Items.Worn(inv)
        if worn then list[#list + 1] = worn else list.empty = true end
    end
    return list
end

-- The options for the player: own class and level, the stored filters and
-- roles; `over` replaces fields.
function Filter.Options(over)
    local S = ns.Settings.Get
    local _, class = UnitClass("player")
    local o = {
        class = class, level = UnitLevel("player") or 60, roles = ns.Settings.Roles(class),
        now = S("filterNow"), bestArmor = S("filterBestArmor"), dungeons = S("filterDungeons"),
        raids = S("filterRaids"), quests = S("filterQuests"), crafting = S("filterCrafting"), world = S("filterWorld"), vendors = S("filterVendors"), faction = UnitFactionGroup("player"), better = S("filterBetter"), alternatives = S("filterAlternatives"), tankHit = S("filterTankHit"),
        sort = S("sort"), text = "",
        -- Only the bosses of the dungeon or raid the player is in.
        here = S("filterHere") and ns.Source.Here() or nil,
    }
    for k, v in pairs(over or {}) do o[k] = v end
    local invSlot = o.invSlot
    o.worn = o.worn or function(slot) return Filter.WornIn(slot, invSlot) end
    return o
end

-- How many upgrades and alternatives a slot has (the character window's
-- tooltip).
function Filter.Count(slotKey, invSlot)
    local list = Filter.Run(Filter.Options({ slot = slotKey, invSlot = invSlot, better = true, alternatives = true }))
    local up, alt = 0, 0
    for _, e in ipairs(list) do
        if e.verdict == "UPGRADE" then up = up + 1 else alt = alt + 1 end
    end
    return up, alt
end
