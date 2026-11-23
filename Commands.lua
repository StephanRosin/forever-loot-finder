local ADDON, ns = ...
local L = ns.L

function ns.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7" .. L.ADDON_NAME .. ":|r " .. tostring(text))
end

-- /flf: the finder; /flf options: the options; /flf dungeon: the upgrades of the dungeon one is in.
SLASH_FOREVERLOOTFINDER1 = "/flf"
SLASH_FOREVERLOOTFINDER2 = "/foreverlootfinder"
SlashCmdList.FOREVERLOOTFINDER = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "perf" then
        -- Timing of each list rebuild in the chat, until asked again.
        ns.perf = not ns.perf and {} or nil
        print("|cff33ff99FLF perf|r " .. (ns.perf and "on" or "off"))
    elseif msg == "dungeon" then ns.DungeonUI.Toggle()
    elseif msg == "options" or msg == "config" or msg == "optionen" then ns.Options.Toggle() else ns.Window.Toggle() end
end
