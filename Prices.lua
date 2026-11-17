-- Auction house prices for the reagents of crafted items: Auctionator's when it
-- is installed, otherwise our own scan. The scan is a "Scan" button on the
-- auction house that fetches every auction at once (C_AuctionHouse.ReplicateItems)
-- and keeps the cheapest buyout per unit of each item, per realm:
-- ForeverLootFinderDB.prices["realm-faction"] = { at = scan time, asked = last click, items = { [id] = copper } }
-- (by faction too: Classic realms keep an auction house per faction).
local ADDON, ns = ...
local L = ns.L
local Prices = {}
ns.Prices = Prices

Prices.COOLDOWN = 20 * 60   -- our own limit; Blizzard allows a full fetch about every 15 minutes

-- Auctionator's public API (Source/API/v1 in Auctionator 347, which has a Forever build).
local function auctionator()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    return api and (api.GetAuctionPriceByItemID or api.GetAuctionPriceByItemLink) and api or nil
end

local function store()
    local db = ns.DB()
    db.prices = db.prices or {}
    local key = (GetRealmName and GetRealmName() or "?") .. "-" .. (UnitFactionGroup and UnitFactionGroup("player") or "?")
    db.prices[key] = db.prices[key] or { items = {} }
    return db.prices[key]
end

-- The price of one, in copper, and when it was seen (nil: Auctionator's, or none).
function Prices.Get(id)
    local api = auctionator()
    if api then
        local ok, price
        if api.GetAuctionPriceByItemID then
            ok, price = pcall(api.GetAuctionPriceByItemID, ADDON, id)
        else
            ok, price = pcall(api.GetAuctionPriceByItemLink, ADDON, "item:" .. id)
        end
        price = ok and price or nil
        -- Its age is in whole days (nil past 21): only a day or more is worth a word.
        local days = price and api.GetAuctionAgeByItemID and select(2, pcall(api.GetAuctionAgeByItemID, ADDON, id))
        return price, type(days) == "number" and days >= 1 and time() - days * 86400 or nil
    end
    local s = store()
    local price = s.items[id]
    return price, price and s.at or nil
end

-- Seconds until the button may scan again.
function Prices.Wait()
    return math.max(0, (store().asked or 0) + Prices.COOLDOWN - time())
end

-- The auctions have arrived: the cheapest unit price of each item.
function Prices.Read()
    local best = {}
    for i = 0, C_AuctionHouse.GetNumReplicateItems() - 1 do
        local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = C_AuctionHouse.GetReplicateItemInfo(i)
        if itemID and buyout and buyout > 0 and count and count > 0 then
            local unit = math.floor(buyout / count)
            if not best[itemID] or unit < best[itemID] then best[itemID] = unit end
        end
    end
    local s, n = store(), 0
    for _ in pairs(best) do n = n + 1 end
    if n == 0 then return 0 end   -- an empty answer keeps the last prices
    s.items, s.at = best, time()
    return n
end

-- 12g 5s: no copper (it only widens the table), except under a silver.
function Prices.Money(copper)
    copper = math.floor(copper + 0.5)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "|cffffd700g|r" end
    if s > 0 then parts[#parts + 1] = s .. "|cffc7c7cfs|r" end
    if #parts == 0 then parts[#parts + 1] = c .. "|cffeda55fc|r" end
    return table.concat(parts, " ")
end

-- "5 min", "3 h", "2 d".
function Prices.Age(at)
    local s = math.max(0, time() - at)
    if s < 3600 then return L.AGE_MIN:format(math.floor(s / 60)) end
    if s < 86400 then return L.AGE_HOURS:format(math.floor(s / 3600)) end
    return L.AGE_DAYS:format(math.floor(s / 86400))
end

-- The reagents' total: copper (of those with a price), whether all had one, the oldest scan.
function Prices.Total(reagents, counts)
    local sum, all, oldest = 0, true, nil
    for i, id in ipairs(reagents or {}) do
        local price, at = Prices.Get(id)
        if price then
            sum = sum + price * ((counts or {})[i] or 1)
            if at and (not oldest or at < oldest) then oldest = at end
        else
            all = false
        end
    end
    return sum, all, oldest
end

-- The button on the auction house frame (only without Auctionator).
local button
local function refresh()
    local wait = Prices.Wait()
    button:SetEnabled(wait == 0 and not button.busy)
    button:SetText(button.busy and L.SCAN_BUSY or wait > 0 and L.SCAN_WAIT:format(math.ceil(wait / 60)) or L.SCAN)
end

local function makeButton()
    button = CreateFrame("Button", nil, AuctionHouseFrame, "UIPanelButtonTemplate")
    button:SetSize(150, 24)
    -- Under the frame, in line with its Buy/Sell/Auctions tabs: the title bar's border lies over its children.
    button:SetPoint("TOPRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -4, -2)
    button:SetFrameLevel(AuctionHouseFrame:GetFrameLevel() + 20)
    -- A scan that never answers (or the AH closed first) gives the 20 minutes back.
    local function abandon(self, why)
        if not self.busy then return end
        self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        self.busy = false
        store().asked = self.before
        if why then print(why) end
        refresh()
    end
    button:SetScript("OnClick", function(self)
        local s = store()
        self.before, s.asked = s.asked, time()
        self.busy = true
        self.scan = (self.scan or 0) + 1
        local scan = self.scan
        self:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        C_AuctionHouse.ReplicateItems()
        C_Timer.After(60, function() if self.scan == scan then abandon(self, L.SCAN_NONE) end end)
        refresh()
    end)
    button:SetScript("OnEvent", function(self)
        self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE")
        self.busy = false
        self.scan = (self.scan or 0) + 1   -- the timeout has nothing left to do
        print(L.SCAN_DONE:format(Prices.Read()))
        refresh()
        if ns.Panel.Refresh then ns.Panel.Refresh() end
    end)
    button:SetScript("OnHide", function(self) abandon(self) end)
    local tick = 0
    button:SetScript("OnUpdate", function(_, elapsed)
        tick = tick + elapsed
        if tick >= 1 then tick = 0; refresh() end
    end)
end

-- The auction house UI loads on demand (at the first auctioneer): the button
-- goes on its frame then, and shows with it.
local function attach()
    if button or not (AuctionHouseFrame and C_AuctionHouse and C_AuctionHouse.ReplicateItems) then return end
    makeButton()
    AuctionHouseFrame:HookScript("OnShow", function() button:SetShown(auctionator() == nil); refresh() end)
    button:SetShown(auctionator() == nil)
    refresh()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == "Blizzard_AuctionHouseUI" then attach() end
end)
