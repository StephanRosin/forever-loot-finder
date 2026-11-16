local ADDON, ns = ...

--[[---------------------------------------------------------------------------
Rules.lua -- facts of the game the filter needs and the client does not
answer: which class wears which armour and weapons (and from which level),
the roles of each class with their stat weights, and the slots.

Roles: an item fits a role when it has one stat the role wants and none it
excludes; its points for the role are its stats times the weights. Healing
and spell damage are separate stats in Forever (GetItemStats): a spell
damage item carries as much healing (it counts for healers too), a healing
item more healing than damage (it does not count for casters).
-----------------------------------------------------------------------------]]
local Rules = {}
ns.Rules = Rules

Rules.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
Rules.ROLES = { "HEAL", "CASTER", "TANK", "MELEE", "RANGED" }
Rules.CLASS_ROLES = {
    WARRIOR = { "TANK", "MELEE" },
    PALADIN = { "HEAL", "TANK", "MELEE" },
    HUNTER = { "RANGED" },
    ROGUE = { "MELEE" },
    PRIEST = { "HEAL", "CASTER" },
    SHAMAN = { "HEAL", "CASTER", "MELEE" },
    MAGE = { "CASTER" },
    WARLOCK = { "CASTER" },
    DRUID = { "HEAL", "CASTER", "TANK", "MELEE" },
}

-- GetItemStats' keys (without _SHORT) -> the short names below.
Rules.STAT_KEYS = {
    ITEM_MOD_STRENGTH = "STR", ITEM_MOD_AGILITY = "AGI", ITEM_MOD_STAMINA = "STA",
    ITEM_MOD_INTELLECT = "INT", ITEM_MOD_SPIRIT = "SPI",
    ITEM_MOD_SPELL_HEALING_DONE = "HEAL", ITEM_MOD_SPELL_DAMAGE_DONE = "SPELLDMG", ITEM_MOD_SPELL_POWER = "SPELLDMG",
    ITEM_MOD_MANA_REGENERATION = "MP5", ITEM_MOD_POWER_REGEN0 = "MP5",
    ITEM_MOD_ATTACK_POWER = "AP", ITEM_MOD_MELEE_ATTACK_POWER = "AP", ITEM_MOD_RANGED_ATTACK_POWER = "RAP",
    ITEM_MOD_FERAL_ATTACK_POWER = "FAP",
    ITEM_MOD_HIT_RATING = "HIT", ITEM_MOD_HIT_MELEE_RATING = "HIT", ITEM_MOD_HIT_RANGED_RATING = "RHIT",
    ITEM_MOD_HIT_SPELL_RATING = "SHIT",
    ITEM_MOD_CRIT_RATING = "CRIT", ITEM_MOD_CRIT_MELEE_RATING = "CRIT", ITEM_MOD_CRIT_RANGED_RATING = "RCRIT",
    ITEM_MOD_CRIT_SPELL_RATING = "SCRIT",
    ITEM_MOD_DEFENSE_SKILL_RATING = "DEF", ITEM_MOD_DODGE_RATING = "DODGE", ITEM_MOD_PARRY_RATING = "PARRY",
    ITEM_MOD_BLOCK_RATING = "BLOCK", ITEM_MOD_BLOCK_VALUE = "BLOCKVAL",
    ITEM_MOD_EXTRA_ARMOR = "ARMOR", RESISTANCE0_NAME = "ARMOR",
    ITEM_MOD_DAMAGE_PER_SECOND = "DPS",
}

-- Stats every caster and healer has no use for.
local PHYSICAL = { "STR", "AGI", "AP", "RAP", "FAP", "HIT", "RHIT", "CRIT", "RCRIT", "DEF", "DODGE", "PARRY",
    "BLOCK", "BLOCKVAL" }
local MAGICAL = { "HEAL", "SPELLDMG", "MP5", "SHIT", "SCRIT" }

local function set(list, more)
    local s = {}
    for _, k in ipairs(list) do s[k] = true end
    for _, k in ipairs(more or {}) do s[k] = true end
    return s
end

-- main: the role's own stat, which an upgrade must not lose (else it is an
-- alternative: less healing but more spirit is the player's call).
Rules.PROFILES = {
    HEAL = {
        weights = { HEAL = 1, MP5 = 2.5, INT = 0.5, SPI = 0.4, SCRIT = 8, STA = 0.1 },
        want = set({ "HEAL", "MP5", "INT", "SPI" }), exclude = set(PHYSICAL), main = "HEAL",
    },
    CASTER = {
        weights = { SPELLDMG = 1, SHIT = 12, SCRIT = 10, INT = 0.4, STA = 0.1, SPI = 0.1, MP5 = 0.5 },
        want = set({ "SPELLDMG", "SHIT", "SCRIT", "INT" }), exclude = set(PHYSICAL), main = "SPELLDMG",
        healingItemsOut = true,
    },
    TANK = {
        weights = { DEF = 1.5, DODGE = 12, PARRY = 12, BLOCK = 6, BLOCKVAL = 0.3, STA = 1, ARMOR = 0.03,
            STR = 0.4, AGI = 0.6, HIT = 5, DPS = 1 },
        want = set({ "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "STA" }), exclude = set(MAGICAL),
    },
    MELEE = {
        weights = { AP = 0.5, FAP = 0.5, STR = 1, AGI = 1, HIT = 10, CRIT = 12, STA = 0.2, DPS = 3 },
        want = set({ "AP", "FAP", "STR", "AGI", "HIT", "CRIT", "DPS" }), exclude = set(MAGICAL),
    },
    RANGED = {
        weights = { RAP = 0.5, AP = 0.5, AGI = 1, HIT = 10, RHIT = 10, CRIT = 12, RCRIT = 12, INT = 0.2,
            STA = 0.2, MP5 = 0.5, DPS = 3 },
        want = set({ "RAP", "AP", "AGI", "HIT", "RHIT", "CRIT", "RCRIT" }),
        exclude = set({ "HEAL", "SPELLDMG", "SHIT", "SCRIT", "DEF", "PARRY", "BLOCK", "BLOCKVAL" }),
    },
}

-- Armour (item class 4) subclasses and weapons (item class 2).
Rules.ARMOR, Rules.WEAPON = 4, 2
local CLOTH, LEATHER, MAIL, PLATE, SHIELD, LIBRAM, IDOL, TOTEM = 1, 2, 3, 4, 6, 7, 8, 9
Rules.ARMOR_TYPES = { CLOTH, LEATHER, MAIL, PLATE }

-- The best armour by class: { before 40, from 40 }.
Rules.BEST_ARMOR = {
    WARRIOR = { MAIL, PLATE }, PALADIN = { MAIL, PLATE },
    HUNTER = { LEATHER, MAIL }, SHAMAN = { LEATHER, MAIL },
    ROGUE = { LEATHER, LEATHER }, DRUID = { LEATHER, LEATHER },
    PRIEST = { CLOTH, CLOTH }, MAGE = { CLOTH, CLOTH }, WARLOCK = { CLOTH, CLOTH },
}
Rules.ARMOR_LEVEL = 40

Rules.EXTRA_ARMOR = {
    [SHIELD] = { WARRIOR = true, PALADIN = true, SHAMAN = true },
    [LIBRAM] = { PALADIN = true }, [IDOL] = { DRUID = true }, [TOTEM] = { SHAMAN = true },
}

-- Weapon subclasses a class can learn (Enum.ItemWeaponSubclass).
local W = { AXE1 = 0, AXE2 = 1, BOW = 2, GUN = 3, MACE1 = 4, MACE2 = 5, POLE = 6, SWORD1 = 7, SWORD2 = 8,
    STAFF = 10, FIST = 13, MISC = 14, DAGGER = 15, THROWN = 16, XBOW = 18, WAND = 19, FISHING = 20 }
local function weapons(...)
    local s = { [W.MISC] = true, [W.FISHING] = true }
    for _, k in ipairs({ ... }) do s[W[k]] = true end
    return s
end
Rules.WEAPONS = {
    WARRIOR = weapons("AXE1", "AXE2", "BOW", "GUN", "MACE1", "MACE2", "POLE", "SWORD1", "SWORD2", "STAFF", "FIST",
        "DAGGER", "THROWN", "XBOW"),
    PALADIN = weapons("AXE1", "AXE2", "MACE1", "MACE2", "POLE", "SWORD1", "SWORD2"),
    HUNTER = weapons("AXE1", "AXE2", "BOW", "GUN", "POLE", "SWORD1", "SWORD2", "STAFF", "FIST", "DAGGER", "THROWN",
        "XBOW"),
    ROGUE = weapons("BOW", "GUN", "MACE1", "SWORD1", "FIST", "DAGGER", "THROWN", "XBOW"),
    PRIEST = weapons("MACE1", "STAFF", "DAGGER", "WAND"),
    SHAMAN = weapons("AXE1", "AXE2", "MACE1", "MACE2", "STAFF", "FIST", "DAGGER"),
    MAGE = weapons("SWORD1", "STAFF", "DAGGER", "WAND"),
    WARLOCK = weapons("SWORD1", "STAFF", "DAGGER", "WAND"),
    DRUID = weapons("MACE1", "MACE2", "STAFF", "FIST", "DAGGER"),
}
-- Classes that hold a weapon in the off hand.
Rules.DUAL_WIELD = { WARRIOR = true, ROGUE = true, HUNTER = true }

-- The slots: the inventory slots (the character window's), the item
-- equip locations that go there and the paper doll's empty-slot art.
Rules.SLOTS = {
    { key = "HEAD", inv = { 1 }, locs = { "INVTYPE_HEAD" }, art = "Head", frames = { "CharacterHeadSlot" } },
    { key = "NECK", inv = { 2 }, locs = { "INVTYPE_NECK" }, art = "Neck", frames = { "CharacterNeckSlot" } },
    { key = "SHOULDER", inv = { 3 }, locs = { "INVTYPE_SHOULDER" }, art = "Shoulder",
        frames = { "CharacterShoulderSlot" } },
    { key = "BACK", inv = { 15 }, locs = { "INVTYPE_CLOAK" }, art = "Chest", frames = { "CharacterBackSlot" } },
    { key = "CHEST", inv = { 5 }, locs = { "INVTYPE_CHEST", "INVTYPE_ROBE" }, art = "Chest",
        frames = { "CharacterChestSlot" } },
    { key = "WRIST", inv = { 9 }, locs = { "INVTYPE_WRIST" }, art = "Wrists", frames = { "CharacterWristSlot" } },
    { key = "HANDS", inv = { 10 }, locs = { "INVTYPE_HAND" }, art = "Hands", frames = { "CharacterHandsSlot" } },
    { key = "WAIST", inv = { 6 }, locs = { "INVTYPE_WAIST" }, art = "Waist", frames = { "CharacterWaistSlot" } },
    { key = "LEGS", inv = { 7 }, locs = { "INVTYPE_LEGS" }, art = "Legs", frames = { "CharacterLegsSlot" } },
    { key = "FEET", inv = { 8 }, locs = { "INVTYPE_FEET" }, art = "Feet", frames = { "CharacterFeetSlot" } },
    { key = "FINGER", inv = { 11, 12 }, locs = { "INVTYPE_FINGER" }, art = "Finger",
        frames = { "CharacterFinger0Slot", "CharacterFinger1Slot" } },
    { key = "TRINKET", inv = { 13, 14 }, locs = { "INVTYPE_TRINKET" }, art = "Trinket",
        frames = { "CharacterTrinket0Slot", "CharacterTrinket1Slot" } },
    { key = "MAINHAND", inv = { 16 }, locs = { "INVTYPE_WEAPON", "INVTYPE_WEAPONMAINHAND", "INVTYPE_2HWEAPON" },
        art = "MainHand", frames = { "CharacterMainHandSlot" } },
    { key = "OFFHAND", inv = { 17 }, locs = { "INVTYPE_SHIELD", "INVTYPE_HOLDABLE", "INVTYPE_WEAPONOFFHAND" },
        art = "SecondaryHand", frames = { "CharacterSecondaryHandSlot" } },
    { key = "RANGED", inv = { 18 }, locs = { "INVTYPE_RANGED", "INVTYPE_RANGEDRIGHT", "INVTYPE_THROWN", "INVTYPE_RELIC" },
        art = "Ranged", frames = { "CharacterRangedSlot" } },
}
Rules.SLOT = {}
for _, slot in ipairs(Rules.SLOTS) do
    Rules.SLOT[slot.key] = slot
    slot.loc = {}
    for _, loc in ipairs(slot.locs) do slot.loc[loc] = true end
end

function Rules.SlotArt(slot)
    return "Interface\\PaperDoll\\UI-PaperDoll-Slot-" .. slot.art
end

-- Whether an item of this equip location goes into the slot for the class
-- (a one-hander goes into the off hand only for those who dual wield).
function Rules.InSlot(slot, equipLoc, class)
    if slot.loc[equipLoc] then return true end
    return slot.key == "OFFHAND" and equipLoc == "INVTYPE_WEAPON" and Rules.DUAL_WIELD[class] == true
end

function Rules.SlotOf(equipLoc, class)
    for _, slot in ipairs(Rules.SLOTS) do
        if Rules.InSlot(slot, equipLoc, class) then return slot end
    end
end

function Rules.BestArmor(class, level)
    local best = Rules.BEST_ARMOR[class]
    if not best then return nil end
    return (level or 60) >= Rules.ARMOR_LEVEL and best[2] or best[1]
end

-- Whether the class can wear it: at `level` (nil: at the top level) for the
-- armour; weapons by what the class can learn.
function Rules.CanWear(class, classID, subClassID, equipLoc, level)
    if classID == Rules.ARMOR then
        if equipLoc == "INVTYPE_CLOAK" or subClassID == 0 then return true end
        local extra = Rules.EXTRA_ARMOR[subClassID]
        if extra then return extra[class] == true end
        local best = Rules.BestArmor(class, level)
        return best ~= nil and subClassID <= best
    elseif classID == Rules.WEAPON then
        local ok = Rules.WEAPONS[class]
        return ok ~= nil and ok[subClassID] == true
    end
    return false
end

-- Whether it is the class's best armour: only body armour counts (cloaks,
-- jewellery, shields and off-hands are no armour type).
function Rules.IsBestArmor(class, classID, subClassID, equipLoc, level)
    if classID ~= Rules.ARMOR or equipLoc == "INVTYPE_CLOAK" then return true end
    local isBody = false
    for _, t in ipairs(Rules.ARMOR_TYPES) do if t == subClassID then isBody = true end end
    if not isBody then return true end
    return subClassID == Rules.BestArmor(class, level)
end

-- An item's stats under the short names; nil stats give an empty table.
-- Second: whether it has stats no role weighs (resistances, health per 5).
function Rules.Stats(raw)
    local stats, other = {}, false
    for key, value in pairs(raw or {}) do
        local short = Rules.STAT_KEYS[(key:gsub("_SHORT$", ""))]
        if short and type(value) == "number" then
            stats[short] = (stats[short] or 0) + value
        elseif type(value) == "number" and value ~= 0 then
            other = true
        end
    end
    return stats, other
end

-- How an item serves a role: fits (has a wanted stat, no excluded one),
-- its points and its main stat. A healing item (more healing than damage)
-- is out for casters.
function Rules.ForRole(role, stats)
    local p = Rules.PROFILES[role]
    local fits = false
    for k in pairs(stats) do
        if p.exclude[k] then return false, 0, 0 end
        if p.want[k] then fits = true end
    end
    if p.healingItemsOut and (stats.HEAL or 0) > (stats.SPELLDMG or 0) then return false, 0, 0 end
    local points = 0
    for k, v in pairs(stats) do points = points + v * (p.weights[k] or 0) end
    return fits, points, p.main and (stats[p.main] or 0) or nil
end

-- Effects ("Use:", "Equip:", "Chance on hit:") are text, not stats: words
-- in them tell which roles they serve. Lower case, found as plain text.
Rules.EFFECT_WORDS = {
    enUS = {
        HEAL = { "healing", "heals", "heal ", "mana" },
        CASTER = { "spell", "magical", "mana" },
        TANK = { "armor", "dodge", "parry", "block", "defense", "threat" },
        MELEE = { "attack power", "melee", "weapon", "strength", "agility", "rage", "energy" },
        RANGED = { "attack power", "ranged", "agility" },
        damage = "damage",
    },
    deDE = {
        HEAL = { "heil", "mana" },
        CASTER = { "zauber", "magisch", "mana" },
        TANK = { "rüstung", "ausweichen", "parier", "block", "verteidigung", "bedrohung" },
        MELEE = { "angriffskraft", "nahkampf", "waffe", "stärke", "beweglichkeit", "wut", "energie" },
        RANGED = { "angriffskraft", "distanz", "fernkampf", "beweglichkeit" },
        damage = "schaden",
    },
}
-- Spell schools, and which classes cast them: "damage done by Fire spells"
-- serves casters of those classes only.
Rules.SCHOOL_WORDS = {
    enUS = { FIRE = "fire", FROST = "frost", SHADOW = "shadow", NATURE = "nature", ARCANE = "arcane", HOLY = "holy" },
    deDE = { FIRE = "feuer", FROST = "frost", SHADOW = "schatten", NATURE = "natur", ARCANE = "arkan", HOLY = "heilig" },
}
Rules.CLASS_SCHOOLS = {
    MAGE = { FIRE = true, FROST = true, ARCANE = true }, WARLOCK = { FIRE = true, SHADOW = true },
    PRIEST = { SHADOW = true, HOLY = true }, DRUID = { NATURE = true, ARCANE = true },
    SHAMAN = { NATURE = true, FIRE = true, FROST = true }, PALADIN = { HOLY = true },
}

-- A chance on hit comes from weapon blows.
Rules.PROC_ROLES = { TANK = true, MELEE = true, RANGED = true }

-- The roles an item's effects serve ({ HEAL = true, ... }), or nil when no
-- word matched: a plain effect ("deals 300 nature damage") may serve anyone.
-- A school the class does not cast leaves an empty set: it serves none.
function Rules.EffectRoles(effects, locale, class)
    local words = Rules.EFFECT_WORDS[locale] or Rules.EFFECT_WORDS.enUS
    local roles, any = {}, false
    for _, e in ipairs(effects or {}) do
        if e.kind == "PROC" then
            for role in pairs(Rules.PROC_ROLES) do roles[role] = true end
            any = true
        else
            local text = e.text:lower()
            local found = {}
            for role, list in pairs(words) do
                for _, w in ipairs(type(list) == "table" and list or {}) do
                    if text:find(w, 1, true) then found[role] = true end
                end
            end
            -- "Healing done by spells" serves healers, not casters (as healing items).
            if found.HEAL and found.CASTER and not (text:find(words.damage, 1, true) or text:find("mana", 1, true)) then
                found.CASTER = nil
            end
            if found.CASTER and class then
                local mine = Rules.CLASS_SCHOOLS[class] or {}
                for school, w in pairs(Rules.SCHOOL_WORDS[locale] or Rules.SCHOOL_WORDS.enUS) do
                    if text:find(w, 1, true) and not mine[school] then found.CASTER, any = nil, true end
                end
            end
            for role in pairs(found) do roles[role], any = true, true end
        end
    end
    return any and roles or nil
end

-- Whether the item has any stat a role could weigh (else: unclear, its
-- effects are not stats, as a trinket's "Use:").
function Rules.HasStats(stats)
    for k in pairs(stats) do
        if k ~= "ARMOR" then return true end
    end
    return false
end
