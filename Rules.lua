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
-- What the window offers per class: its specs, each with a role (what it
-- wants, excludes, its main stat). A spec without a name of its own (id =
-- its role) is shown as the role.
Rules.SPECS = {
    WARRIOR = { { id = "ARMS", role = "MELEE" }, { id = "FURY", role = "MELEE" }, { id = "PROT", role = "TANK" } },
    PALADIN = { { id = "HOLY", role = "HEAL" }, { id = "PROT", role = "TANK" }, { id = "HOLYSHOCK", role = "MELEE" },
        { id = "UNSEALED", role = "MELEE" } },
    HUNTER = { { id = "TURRET", role = "RANGED" }, { id = "WEAVE", role = "RANGED" }, { id = "MELEE", role = "MELEE" } },
    ROGUE = { { id = "ASSA", role = "MELEE" }, { id = "COMBAT", role = "MELEE" }, { id = "SUB", role = "MELEE" } },
    PRIEST = { { id = "DISC", role = "HEAL" }, { id = "HOLY", role = "HEAL" }, { id = "SHADOW", role = "CASTER" } },
    SHAMAN = { { id = "ELE", role = "CASTER" }, { id = "ENH", role = "MELEE" }, { id = "RESTO", role = "HEAL" } },
    MAGE = { { id = "ARCANE", role = "CASTER" }, { id = "FIRE", role = "CASTER" }, { id = "FROST", role = "CASTER" },
        { id = "FFB", role = "CASTER" } },
    WARLOCK = { { id = "AFF", role = "CASTER" }, { id = "DEMO", role = "CASTER" }, { id = "DESTRO", role = "CASTER" },
        { id = "SMRUIN", role = "CASTER" } },
    DRUID = { { id = "BALANCE", role = "CASTER" }, { id = "CAT", role = "MELEE" }, { id = "BEAR", role = "TANK" },
        { id = "RESTO", role = "HEAL" } },
}

-- The roles of each class, in the order of its specs.
Rules.CLASS_ROLES = {}
for class, specs in pairs(Rules.SPECS) do
    local list, seen = {}, {}
    for _, spec in ipairs(specs) do
        if not seen[spec.role] then seen[spec.role], list[#list + 1] = true, spec.role end
    end
    Rules.CLASS_ROLES[class] = list
end

-- A spec's weights per point, from wowsims (github.com/wowsims/forever, MIT, as of 2026-11-22):
-- the EP of its presets (ui/specs/*/presets.ts, druid/feral_ep.ts; several of a spec averaged)
-- or, where it has none, simulated with its own sim on its test setups (mage, warlock: DPS EP;
-- protection paladin: threat EP; 60000 iterations). Put on our scale (healing, spell damage,
-- stamina or agility 1; melee attack power 0.5) and our stats: haste, expertise, armour
-- penetration and school damage have none; generic attack power counts for hunters as ranged
-- too (wowsims' Pawn export). The priest healers' are set by hand there (no healing sim).
-- They replace the role's weights. Without: holy paladins, restoration shamans and druids.
Rules.SPEC_WEIGHTS = {
    ["WARRIOR:ARMS"] = { STR = 1.1, AGI = 0.88, AP = 0.5, DPS = 8.36, HIT = 2.52, CRIT = 1.16 },
    ["WARRIOR:FURY"] = { STR = 1.1, AGI = 0.85, AP = 0.5, DPS = 6.29, ODPS = 1.33, HIT = 0.84, CRIT = 1.13 },
    ["WARRIOR:PROT"] = { STA = 1, STR = 0.54, AGI = 0.53, AP = 0.23, DPS = 1.25, HIT = 0.04, CRIT = 0.37, DEF = 0.43, DODGE = 0.23, PARRY = 0.21, BLOCKVAL = 0.6, ARMOR = 0.05 },
    ["PALADIN:PROT"] = { SPELLDMG = 1, MP5 = 0.12, INT = 0.08, STA = 0.05, STR = 0.45, AGI = 0.31, AP = 0.19, HIT = 1.89, CRIT = 0.63, DEF = 0.19, DODGE = 0.2, PARRY = 0.08, BLOCK = 0.75 },
    ["PALADIN:HOLYSHOCK"] = { SPELLDMG = 2.89, MP5 = 0.01, INT = 2.27, STR = 1.25, AGI = 1.55, AP = 0.5, DPS = 6.52, HIT = 5.12, CRIT = 2.33 },
    ["PALADIN:UNSEALED"] = { SPELLDMG = 1.18, MP5 = 0.12, INT = 1.03, STR = 1.2, AGI = 1.11, AP = 0.5, DPS = 6.92, HIT = 3.42, CRIT = 1.54 },
    ["HUNTER:TURRET"] = { MP5 = 0.41, INT = 0.64, AGI = 1, AP = 0.34, RAP = 0.34, RDPS = 3.29, HIT = 1.26, RHIT = 1.26, CRIT = 0.87, RCRIT = 0.87 },
    ["HUNTER:WEAVE"] = { MP5 = 0.12, INT = 0.44, STR = 0.22, AGI = 1, AP = 0.4, RAP = 0.2, DPS = 2.93, RDPS = 1.69, HIT = 1.43, RHIT = 1.43, CRIT = 0.83, RCRIT = 0.83 },
    ["HUNTER:MELEE"] = { MP5 = 0.31, INT = 0.94, STR = 0.55, AGI = 1.35, AP = 0.7, RAP = 0.2, DPS = 6.54, ODPS = 1.59, RDPS = 0.36, HIT = 3.34, CRIT = 1.35 },
    ["ROGUE:ASSA"] = { STA = 0.01, STR = 0.55, AGI = 1.03, AP = 0.5, DPS = 4.22, ODPS = 2.08, HIT = 1.4, CRIT = 1.01 },
    ["ROGUE:COMBAT"] = { STA = 0.01, STR = 0.55, AGI = 0.98, AP = 0.5, DPS = 5.19, ODPS = 1.48, HIT = 1.19, CRIT = 0.84 },
    ["ROGUE:SUB"] = { STA = 0.01, STR = 0.55, AGI = 0.96, AP = 0.5, DPS = 5.24, ODPS = 1.14, HIT = 1.06, CRIT = 0.81 },
    ["PRIEST:DISC"] = { HEAL = 1, MP5 = 0.3, INT = 0.2, SPI = 0.12, CRIT = 0.59, SCRIT = 0.59 },
    ["PRIEST:HOLY"] = { HEAL = 1, MP5 = 0.6, INT = 0.32, SPI = 0.28, CRIT = 0.27, SCRIT = 0.27 },
    ["PRIEST:SHADOW"] = { SPELLDMG = 1, INT = 0.24, SPI = 0.01, HIT = 1.14, SHIT = 1.14, CRIT = 0.84, SCRIT = 0.84 },
    ["SHAMAN:ELE"] = { SPELLDMG = 1, MP5 = 0.04, INT = 0.19, SPI = 0.02, HIT = 1.18, SHIT = 1.18, CRIT = 0.61, SCRIT = 0.61 },
    ["SHAMAN:ENH"] = { SPELLDMG = 0.64, INT = 0.99, STR = 1.1, AGI = 0.66, AP = 0.5, DPS = 7.09, HIT = 2.6, CRIT = 1.21 },
    ["DRUID:BALANCE"] = { SPELLDMG = 1, MP5 = 0.07, INT = 0.24, HIT = 1.46, SHIT = 1.46, CRIT = 0.76, SCRIT = 0.76 },
    ["DRUID:CAT"] = { STR = 1.22, AGI = 1.34, AP = 0.5, FAP = 0.5, DPS = 4.39, HIT = 1.07, CRIT = 1.04 },
    ["DRUID:BEAR"] = { STA = 1, STR = 0.48, AGI = 0.43, AP = 0.22, FAP = 0.22, DPS = 3.08, HIT = 0.69, CRIT = 0.36, DEF = 0.87, DODGE = 0.11, ARMOR = 0.17 },
    ["MAGE:ARCANE"] = { SPELLDMG = 1, MP5 = 0.31, INT = 0.81, SPI = 0.34, HIT = 1.49, SHIT = 1.49, CRIT = 0.63, SCRIT = 0.63 },
    ["MAGE:FIRE"] = { SPELLDMG = 1, MP5 = 0.11, INT = 0.35, SPI = 0.06, HIT = 1.49, SHIT = 1.49, CRIT = 0.73, SCRIT = 0.73 },
    ["MAGE:FROST"] = { SPELLDMG = 1, MP5 = 0.76, INT = 0.5, SPI = 0.3, HIT = 1.52, SHIT = 1.52, CRIT = 0.59, SCRIT = 0.59 },
    ["MAGE:FFB"] = { SPELLDMG = 1, MP5 = 0.04, INT = 0.11, SPI = 0.1, HIT = 1.44, SHIT = 1.44, CRIT = 0.78, SCRIT = 0.78 },
    ["WARLOCK:AFF"] = { SPELLDMG = 1, MP5 = 0.17, INT = 0.26, HIT = 0.7, SHIT = 0.7, CRIT = 0.67, SCRIT = 0.67 },
    ["WARLOCK:DEMO"] = { SPELLDMG = 1, MP5 = 0.28, INT = 0.31, SPI = 0.07, HIT = 1.35, SHIT = 1.35, CRIT = 0.62, SCRIT = 0.62 },
    ["WARLOCK:DESTRO"] = { SPELLDMG = 1, MP5 = 0.27, INT = 0.29, SPI = 0.11, HIT = 1.02, SHIT = 1.02, CRIT = 0.62, SCRIT = 0.62 },
    ["WARLOCK:SMRUIN"] = { SPELLDMG = 1, MP5 = 0.25, INT = 0.31, SPI = 0.07, HIT = 0.97, SHIT = 0.97, CRIT = 0.77, SCRIT = 0.77 },
}

-- Specs that may be weighed the Loot Finder's own way instead (ForeverLootFinderDB.weightSource
-- ["CLASS:SPEC"] = "CLASSIC"): the priest healers' wowsims set by hand, tanks' for threat.
Rules.CLASSIC = { ["PRIEST:DISC"] = true, ["PRIEST:HOLY"] = true, ["WARRIOR:PROT"] = true, ["PALADIN:PROT"] = true }

-- The spec chosen for another class in the window (this session); the
-- player's own class: the character's (ForeverLootFinderChar.spec).
local chosen = {}

local function ownClass() return select(2, UnitClass("player")) end

-- The chosen spec of a class, else the first of the role stored before
-- specs (ForeverLootFinderChar.role), else its first.
function Rules.SpecOf(class)
    local specs = Rules.SPECS[class] or {}
    local char = class == ownClass() and ns.CharDB and ns.CharDB() or {}
    local id = char.spec or chosen[class]
    for _, spec in ipairs(specs) do if spec.id == id then return spec end end
    for _, spec in ipairs(specs) do if spec.role == char.role then return spec end end
    return specs[1]
end

-- The spec weighing a role: the chosen one when it has that role, else the class's first of it.
function Rules.Spec(class, role)
    local spec = Rules.SpecOf(class)
    if spec and spec.role == role then return spec end
    for _, s in ipairs(Rules.SPECS[class] or {}) do if s.role == role then return s end end
    return { id = role, role = role }
end

-- Another class's spec, for this session (the player's own: Settings.SetSpec).
function Rules.Choose(class, id) chosen[class] = id end

-- The locale key of a spec's name: its own, or its role's.
function Rules.SpecLabelKey(class, spec)
    if spec.id == spec.role then return Rules.RoleLabelKey(class, spec.role) end
    return "SPEC_" .. class .. "_" .. spec.id
end

-- The label of a role for a class: plain "DPS" when the class deals damage
-- one way only, "Melee DPS" / "Caster DPS" for shamans and druids.
local DAMAGE = { MELEE = "ROLE_MELEE_DPS", CASTER = "ROLE_CASTER_DPS", RANGED = "ROLE_DPS" }
function Rules.RoleLabelKey(class, role)
    if not DAMAGE[role] then return "ROLE_" .. role end
    local n = 0
    for _, r in ipairs(Rules.CLASS_ROLES[class] or {}) do if DAMAGE[r] then n = n + 1 end end
    return n > 1 and DAMAGE[role] or "ROLE_DPS"
end

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
    ITEM_MOD_DAMAGE_PER_SECOND = "DPS",   -- off-hand and ranged weapons: ODPS, RDPS (Rules.HandDps)
    ITEM_MOD_FIRE_DAMAGE_DONE = "FIREDMG", ITEM_MOD_FROST_DAMAGE_DONE = "FROSTDMG",
    ITEM_MOD_SHADOW_DAMAGE_DONE = "SHADOWDMG", ITEM_MOD_NATURE_DAMAGE_DONE = "NATUREDMG",
    ITEM_MOD_ARCANE_DAMAGE_DONE = "ARCANEDMG", ITEM_MOD_HOLY_DAMAGE_DONE = "HOLYDMG",
}

-- Stats every caster and healer has no use for (hit and crit are generic in
-- Forever: casters use them too).
local PHYSICAL = { "STR", "AGI", "AP", "RAP", "FAP", "RHIT", "RCRIT", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL" }
local MAGICAL = { "HEAL", "SPELLDMG", "MP5", "SHIT", "SCRIT" }

local function set(list, more)
    local s = {}
    for _, k in ipairs(list) do s[k] = true end
    for _, k in ipairs(more or {}) do s[k] = true end
    return s
end

-- Per role: weights per point as GetItemStats gives them (ratings: about 10
-- hit, 14 crit or 12 dodge per percent), the stats it wants (one is enough)
-- and excludes. main: the role's own stat, which an upgrade must not lose
-- (else it is an alternative: less healing but more spirit is the player's call).
Rules.PROFILES = {
    HEAL = {
        weights = { HEAL = 1, MP5 = 2.5, INT = 0.5, SPI = 0.4, CRIT = 0.5, SCRIT = 0.5, STA = 0.1 },
        want = set({ "HEAL", "MP5", "INT", "SPI" }), exclude = set(PHYSICAL), main = "HEAL",
    },
    CASTER = {
        -- Damage casters do not run dry in a fight worth gearing for: no points for mana regeneration.
        weights = { SPELLDMG = 1, HIT = 1.2, SHIT = 1.2, CRIT = 0.7, SCRIT = 0.7, INT = 0.4, STA = 0.2, SPI = 0.1, MP5 = 0 },
        want = set({ "SPELLDMG", "HIT", "SHIT", "CRIT", "SCRIT", "INT" }), exclude = set(PHYSICAL), main = "SPELLDMG",
        healingItemsOut = true, schools = true,
    },
    TANK = {
        weights = { STA = 1, ARMOR = 0.06, DEF = 1, DODGE = 1, PARRY = 0.6, BLOCK = 0.5, BLOCKVAL = 0.3, STR = 0.3,
            AGI = 0.6, HIT = 0.4, AP = 0.1, DPS = 1 },
        want = set({ "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "STA" }), exclude = set(MAGICAL),
    },
    MELEE = {
        weights = { STR = 1, AGI = 1, AP = 0.5, HIT = 1.2, CRIT = 1, STA = 0.2, DPS = 3, ODPS = 1 },
        -- Tank stats make it a tank's item, not a damage dealer's.
        want = set({ "AP", "STR", "AGI", "HIT", "CRIT", "DPS", "ODPS" }),
        exclude = set(MAGICAL, { "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL" }),
    },
    RANGED = {
        weights = { AGI = 1, RAP = 0.5, AP = 0.5, HIT = 1.2, RHIT = 1.2, CRIT = 1, RCRIT = 1, INT = 0.2, MP5 = 0.5,
            STA = 0.2, RDPS = 3 },
        want = set({ "RAP", "AP", "AGI", "HIT", "RHIT", "CRIT", "RCRIT", "RDPS" }),
        exclude = set({ "HEAL", "SPELLDMG", "SHIT", "SCRIT", "DEF", "PARRY", "BLOCK", "BLOCKVAL" }),
    },
}

-- Per class: weights replace the role's (only where no spec has its own
-- SPEC_WEIGHTS, or for Rules.CLASSIC), want/exclude entries switch on
-- (true) or off (false). Bears cannot parry or block; paladin and shaman
-- damage and tank sets carry spell power.
-- Healing spirit in Forever: Meditation (priest) and Reflection (druid) keep 50% of the
-- regeneration while casting; a point of spirit then gives about 0.31 (priest, spirit/4
-- per tick) or 0.25 x 1.15 Living Spirit (druid, spirit/5) mana per 5 sec, at MP5's 2.5;
-- the priest's Spiritual Guidance adds 25% of spirit as healing.
-- Intellect is only a bigger pool and a little crit for them (no Illumination), half the base 0.5.
local HYBRID = { SPELLDMG = false, HEAL = false, MP5 = false }
Rules.CLASS_PROFILES = {
    PRIEST = { HEAL = { weights = { SPI = 1.0, INT = 0.25 } } },
    DRUID = {
        HEAL = { weights = { SPI = 0.7, INT = 0.25 } },
        TANK = { want = { AGI = true, PARRY = false, BLOCK = false, BLOCKVAL = false } },
        MELEE = { want = { FAP = true } },
    },
    PALADIN = {
        TANK = { weights = { SPELLDMG = 0.3, INT = 0.2, MP5 = 0.5 }, exclude = HYBRID, healingItemsOut = true },
        MELEE = { exclude = HYBRID, healingItemsOut = true },
        -- Illumination refunds a crit heal's mana: 1% crit is worth about 20 healing, Divine Intellect
        -- and ~30 int per 1% crit make intellect nearly a healing point (classic guides: int, crit before mp5).
        HEAL = { weights = { SPI = 0.1, INT = 0.9, CRIT = 1.2, SCRIT = 1.2 }, want = { SPI = false } },
    },
    SHAMAN = {
        MELEE = { exclude = HYBRID, healingItemsOut = true },
        HEAL = { weights = { SPI = 0.1 }, want = { SPI = false } },
    },
    ROGUE = { MELEE = { noMana = true } },
    WARRIOR = { MELEE = { noMana = true }, TANK = { noMana = true } },
    -- Melee hunters still cast from mana (wowsims weighs their intellect and mp5).
    HUNTER = { MELEE = { exclude = { MP5 = false } } },
}

local profiles, defaults, dynamics = {}, {}, {}
local dynamic

-- The player's own weights (options, "Advanced"): ForeverLootFinderDB.weights["CLASS:SPEC"] = { stat = weight },
-- only those that differ from the default.
local function custom(class, spec)
    local db = ns.DB and ns.DB().weights
    return db and db[tostring(class) .. ":" .. spec] or nil
end

-- The profile a role is weighed by for a class: that of its spec (Rules.Spec).
function Rules.Profile(class, role, plain)
    return Rules.SpecProfile(class, Rules.Spec(class, role).id, plain)
end

local function specEntry(class, id)
    for _, s in ipairs(Rules.SPECS[class] or {}) do if s.id == id then return s end end
    return { id = id, role = id }
end

-- A spec's profile: its role's rules with the class's overrides, the spec's
-- weights (else the role's with the class's), and the player's own weights;
-- plain: without them (the defaults the options show).
function Rules.SpecProfile(class, id, plain)
    local role = specEntry(class, id).role
    local key = tostring(class) .. ":" .. id
    local own = not plain and custom(class, id)
    if own then
        if profiles[key] then return profiles[key] end
        local d = Rules.SpecProfile(class, id, true)
        local p = setmetatable({ weights = {} }, { __index = d })
        for k, v in pairs(d.weights) do p.weights[k] = v end
        for k, v in pairs(own) do p.weights[k] = v end
        profiles[key] = p
        return p
    end
    if defaults[key] then return defaults[key] end
    local b = Rules.PROFILES[role]
    local o = Rules.CLASS_PROFILES[class] and Rules.CLASS_PROFILES[class][role] or {}
    local p = { weights = {}, want = {}, exclude = {}, main = b.main, schools = b.schools,
        healingItemsOut = b.healingItemsOut or o.healingItemsOut, noMana = o.noMana }
    for _, f in ipairs({ "weights", "want", "exclude" }) do
        for k, v in pairs(b[f]) do p[f][k] = v end
        for k, v in pairs(o[f] or {}) do p[f][k] = v or nil end
    end
    local sw = not Rules.IsClassic(class, id) and Rules.SPEC_WEIGHTS[key]
    if sw then
        -- What the role weighs and the spec does not stays at 0, there to be weighed (options).
        for k in pairs(p.weights) do p.weights[k] = 0 end
        for k, v in pairs(sw) do p.weights[k] = v end
    end
    defaults[key] = p
    return p
end

-- Sets one of the player's weights for a spec (the default again: dropped); no stat: all of it back.
function Rules.SetWeight(class, id, stat, weight)
    local db = ns.DB()
    db.weights = db.weights or {}
    local key = tostring(class) .. ":" .. id
    if stat then
        local t = db.weights[key] or {}
        local default = Rules.SpecProfile(class, id, true).weights[stat] or 0
        if weight and math.abs(weight - default) < 1e-6 then weight = nil end
        t[stat] = weight
        db.weights[key] = next(t) and t or nil
    else
        db.weights[key] = nil
    end
    if not next(db.weights) then db.weights = nil end
    profiles, dynamics = {}, {}
end

-- Whether a spec is weighed the Loot Finder's own way (Rules.CLASSIC) instead of wowsims'.
function Rules.IsClassic(class, id)
    local key = tostring(class) .. ":" .. id
    local db = ns.DB and ns.DB().weightSource
    return Rules.CLASSIC[key] and db and db[key] == "CLASSIC" or false
end

function Rules.SetSource(class, id, classic)
    local db = ns.DB()
    db.weightSource = db.weightSource or {}
    db.weightSource[tostring(class) .. ":" .. id] = classic and "CLASSIC" or nil
    if not next(db.weightSource) then db.weightSource = nil end
    profiles, defaults, dynamics = {}, {}, {}
end

-- Whether the player weighs the spec of this class and role differently.
function Rules.HasCustom(class, role) return custom(class, Rules.Spec(class, role).id) ~= nil end

-- All of the player's weights back to the defaults.
function Rules.ResetWeights()
    ns.DB().weights = nil
    profiles, dynamics = {}, {}
end

-- Hit and crit of the player's own damage roles follow the character (option "dynamic"):
-- what 1% is worth in the role's damage stat (spell power, attack power) at today's
-- damage, crit and hit, and hit only up to the cap against a raid boss (three levels up).
-- Each role: its damage stat, hit and crit keys, the cap in percent and the combat ratings.
Rules.DYNAMIC = {
    CASTER = { unit = "SPELLDMG", hit = { "HIT", "SHIT" }, crit = { "CRIT", "SCRIT" }, cap = 16, crHit = 8, crCrit = 11 },
    MELEE = { unit = "AP", hit = { "HIT" }, crit = { "CRIT" }, cap = 9, crHit = 6, crCrit = 9 },
    RANGED = { unit = "RAP", hit = { "HIT", "RHIT" }, crit = { "CRIT", "RCRIT" }, cap = 9, crHit = 7, crCrit = 10 },
}
-- A value the game gives, nothing when there is no such function or Forever keeps it secret
-- (in combat): then `hidden` is set and ReadChar keeps the last stand it could read.
local hidden
local function pass(...)
    for i = 1, select("#", ...) do
        if issecretvalue and issecretvalue((select(i, ...))) then
            hidden = true
            return
        end
    end
    return ...
end
local function read(f, ...)
    if f then return pass(f(...)) end
end

-- The caster's main nuke per school (GetSpellBonusDamage index: 3 fire, 4 nature, 5 frost, 6 shadow,
-- 7 arcane) and its spell power coefficient; the damage comes from the highest rank known, as the
-- game describes it (Forever's text holds the spell power from items and buffs already). Among several, the school with the most spell power. Crits do double damage
-- (Shadowform, Ice Shards, Ruin, Vengeance, Elemental Fury).
Rules.CASTER_SPELLS = {
    MAGE = { { 116, 5, 0.814 }, { 133, 3, 1.0 } },          -- Frostbolt, Fireball
    WARLOCK = { { 686, 6, 0.857 }, { 5676, 3, 0.429 } },   -- Shadow Bolt, Searing Pain
    PRIEST = { { 8092, 6, 0.429 } },                       -- Mind Blast
    DRUID = { { 2912, 7, 1.0 }, { 5176, 4, 0.571 } },      -- Starfire, Wrath
    SHAMAN = { { 403, 4, 0.794 } },                        -- Lightning Bolt
}

-- The class's nuke: its whole damage in spell power (the described damage over the coefficient)
-- and its school; nil when none is known or its text is not loaded yet.
function Rules.Nuke(class)
    local best
    for _, s in ipairs(Rules.CASTER_SPELLS[class] or {}) do
        local info = C_Spell and C_Spell.GetSpellInfo(s[1])
        local top = info and C_Spell.GetSpellInfo(info.name)   -- by name: the highest rank known
        local text = top and read(C_Spell.GetSpellDescription, top.spellID) or ""
        local lo, hi = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("(%d+)%s+%a+%s+(%d+)")
        local sp = read(GetSpellBonusDamage, s[2]) or 0
        if lo and (not best or sp > best.sp) then
            best = { school = s[2], sp = sp, damage = (lo + hi) / 2 / s[3] }
        end
    end
    return best
end

local RATING_PER_PCT = { hit = 10, crit = 14 }   -- without own rating to measure by

-- The rating that makes one percent: measured on the character, else the usual.
local function perPct(cr, fallback)
    local r, b = read(GetCombatRating, cr) or 0, read(GetCombatRatingBonus, cr) or 0
    return (r > 0 and b > 0) and r / b or fallback
end

-- The player's damage, hit and crit per damage role, read fresh (each search); nil: fixed weights.
function Rules.ReadChar()
    local last, lastDynamics = Rules.char, dynamics
    Rules.char, dynamics, hidden = nil, {}, false
    if not (ns.Settings and ns.Settings.Get("dynamic")) or not GetCombatRatingBonus then return end
    local _, class = UnitClass("player")
    local nuke = Rules.Nuke(class)
    local speed = read(UnitAttackSpeed, "player") or 2
    local min, max = read(UnitDamage, "player")
    local rSpeed, rMin, rMax = read(UnitRangedDamage, "player")
    -- Whole damage in the role's stat: a swing is worth its damage as attack power over 14 per second.
    local base = {
        CASTER = nuke and nuke.damage or 0,
        MELEE = ((min or 0) + (max or 0)) / 2 * 14 / speed,
        RANGED = (rSpeed or 0) > 0 and ((rMin or 0) + (rMax or 0)) / 2 * 14 / rSpeed or 0,
    }
    local hitMod = { CASTER = GetSpellHitModifier, MELEE = GetHitModifier, RANGED = GetRangedHitModifier }
    local critNow = { CASTER = GetSpellCritChance, MELEE = GetCritChance, RANGED = GetRangedCritChance }
    Rules.char = { class = class }
    for role, d in pairs(Rules.DYNAMIC) do
        local hit = (read(GetCombatRatingBonus, d.crHit) or 0) + (read(hitMod[role]) or 0)
        local crit = (read(critNow[role], nuke and nuke.school) or 0) / 100   -- spell crit of the nuke's school
        local hitPerPct, critPerPct = perPct(d.crHit, RATING_PER_PCT.hit), perPct(d.crCrit, RATING_PER_PCT.crit)
        Rules.char[role] = {
            hitPct = hit, missing = math.max(0, d.cap - hit),
            over = (hit - d.cap) * hitPerPct,                       -- rating over the cap (negative: missing)
            -- 1% more hit: one hit in (99% - what is missing) more; 1% crit: one hit more in (1 + crit), crits doubling.
            hitValue = base[role] * 0.01 / (0.99 - math.max(0, d.cap - hit) / 100),
            critValue = base[role] * 0.01 / (1 + crit),
            hitPerPct = hitPerPct, critPerPct = critPerPct,
        }
    end
    if hidden then Rules.char, dynamics = last, lastDynamics end
end

-- The dynamic hit and crit weights of a role for a class, nil when fixed: another class
-- (a twink in the list), healers and tanks, or the option off. Own weights stay the player's.
function dynamic(class, role)
    local c, d = Rules.char, Rules.DYNAMIC[role]
    if not (c and d and c[role] and c.class == class and (c[role].hitValue or 0) > 0) then return nil end
    local spec = Rules.Spec(class, role).id
    local key = class .. ":" .. spec
    if dynamics[key] ~= nil then return dynamics[key] or nil end
    local p, own, ch = Rules.Profile(class, role), custom(class, spec) or {}, c[role]
    local unit = p.weights[d.unit] or 0
    local w = { hit = {}, weights = {}, over = ch.over, char = ch }
    for _, k in ipairs(d.hit) do
        w.hit[k] = true
        w.weights[k] = own[k] or ch.hitValue * unit / ch.hitPerPct
    end
    for _, k in ipairs(d.crit) do w.weights[k] = own[k] or ch.critValue * unit / ch.critPerPct end
    dynamics[key] = unit > 0 and w or false
    return dynamics[key] or nil
end
Rules.Dynamic = dynamic

-- The weighable stats in the options' order.
Rules.WEIGHT_KEYS = { "HEAL", "SPELLDMG", "MP5", "INT", "SPI", "STA", "STR", "AGI", "AP", "RAP", "FAP", "DPS", "ODPS", "RDPS",
    "HIT", "SHIT", "RHIT", "CRIT", "SCRIT", "RCRIT", "DEF", "DODGE", "PARRY", "BLOCK", "BLOCKVAL", "ARMOR" }

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
-- Whether the class wears more than cloth (else "best armour" picks nothing out).
function Rules.HasArmorChoice(class)
    local best = Rules.BestArmor(class)
    return best ~= nil and best ~= CLOTH
end

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
    -- "Spell power" alone raises healing as well.
    local sp = raw and (raw.ITEM_MOD_SPELL_POWER_SHORT or raw.ITEM_MOD_SPELL_POWER)
    if type(sp) == "number" and not (raw.ITEM_MOD_SPELL_HEALING_DONE_SHORT or raw.ITEM_MOD_SPELL_HEALING_DONE) then
        stats.HEAL = (stats.HEAL or 0) + sp
    end
    -- Armour beyond the item's base ("+93 Armor"): shown for bear tanks.
    local bonus = raw and (raw.ITEM_MOD_EXTRA_ARMOR_SHORT or raw.ITEM_MOD_EXTRA_ARMOR)
    return stats, other, type(bonus) == "number" and bonus > 0 and bonus or nil
end

-- A weapon's DPS by hand (wowsims weighs them apart): a ranged weapon's is RDPS, an off-hand
-- weapon's (or a one-hander's in the off hand) ODPS, the rest DPS. Changes stats in place.
local RANGED_LOCS = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
function Rules.HandDps(stats, equipLoc, offHand)
    if not (stats and stats.DPS) then return stats end
    local key = RANGED_LOCS[equipLoc] and "RDPS"
        or (equipLoc == "INVTYPE_WEAPONOFFHAND" or offHand and equipLoc == "INVTYPE_WEAPON") and "ODPS"
    if key then stats[key], stats.DPS = stats.DPS, nil end
    return stats
end

-- The same stats with a one-hander's DPS as an off hand's (a copy; nil-safe).
function Rules.AsOffHand(stats, equipLoc)
    if not (stats and stats.DPS and equipLoc == "INVTYPE_WEAPON") then return stats end
    local copy = {}
    for k, v in pairs(stats) do copy[k] = v end
    return Rules.HandDps(copy, equipLoc, true)
end

Rules.SCHOOL_OF = { FIREDMG = "FIRE", FROSTDMG = "FROST", SHADOWDMG = "SHADOW", NATUREDMG = "NATURE",
    ARCANEDMG = "ARCANE", HOLYDMG = "HOLY" }

-- One school's spell damage counts as spell damage for a caster of that school.
local function schoolDamage(p, class, stats)
    local own, best = p.schools and Rules.CLASS_SCHOOLS[class] or {}, 0
    for k, v in pairs(stats) do
        local s = Rules.SCHOOL_OF[k]
        if s and own[s] then best = math.max(best, v) end
    end
    return best
end

-- What the points are made of: { { key, points } }, unsorted. With dynamic weights hit counts
-- only up to the cap: room is the hit rating the item can still use (nil: the item is worn,
-- its own hit is part of today's and only what is over the cap is lost).
local function parts(role, stats, class, room)
    local p, d = Rules.Profile(class, role), dynamic(class, role)
    local list, hit, key = {}, 0, nil
    local school = schoolDamage(p, class, stats)
    if school > 0 and (p.weights.SPELLDMG or 0) > 0 then list[#list + 1] = { "SPELLDMG", school * p.weights.SPELLDMG } end
    for k, v in pairs(stats) do
        local w = d and d.weights[k] or p.weights[k] or 0
        if d and d.hit[k] then hit, key = hit + v, k
        elseif w ~= 0 and v ~= 0 then list[#list + 1] = { k, v * w } end
    end
    if hit > 0 then
        local counted = math.max(0, math.min(hit, room or hit - math.max(0, d.over)))
        if counted > 0 then list[#list + 1] = { key, counted * d.weights[key] } end
    end
    return list
end

-- The hit rating an item in a slot can still use for a role: what the worn one (the least of
-- several) gives back, plus what is missing to the cap; nil without dynamic weights.
function Rules.HitRoom(role, class, wornList)
    local d = dynamic(class, role)
    if not d then return nil end
    local worn
    for _, w in ipairs(wornList or {}) do
        local h = 0
        for k in pairs(d.hit) do h = h + (w.stats and w.stats[k] or 0) end
        worn = math.min(worn or h, h)   -- shortcut: the ring or trinket least in hit, not the one replaced
    end
    return math.max(0, (wornList and wornList.empty and 0 or worn or 0) - d.over)
end

-- An item's points and main stat for a role, fitting or not.
function Rules.Points(role, stats, class, room)
    local p = Rules.Profile(class, role)
    local points = 0
    for _, part in ipairs(parts(role, stats, class, room)) do points = points + part[2] end
    local main = p.main and (stats[p.main] or 0) or nil
    if main and p.main == "SPELLDMG" then main = main + schoolDamage(p, class, stats) end
    return points, main
end

-- The same, biggest first (the tooltip's sum).
function Rules.PointParts(role, stats, class, room)
    local list = parts(role, stats, class, room)
    table.sort(list, function(x, y) return x[2] > y[2] end)
    return list
end

-- How an item serves a role of a class: fits (a wanted stat, no excluded
-- one), its points and its main stat. A healing item (more healing than
-- damage) is out for casters; a school's damage is out for all but its casters
-- (two schools, one of them its own: Robe of Winter Night's frost and shadow serve a shadow priest).
function Rules.ForRole(role, stats, class, room)
    local p = Rules.Profile(class, role)
    local own = p.schools and Rules.CLASS_SCHOOLS[class] or {}
    local fits, school, foreign = false, schoolDamage(p, class, stats), false
    for k, v in pairs(stats) do
        local s = Rules.SCHOOL_OF[k]
        if s then
            if own[s] then fits = true else foreign = true end
        else
            if p.exclude[k] then return false, 0, 0 end
            if p.want[k] and v > 0 then fits = true end   -- a stat taken away (Mindtap's intellect) is no reason
        end
    end
    if foreign and school == 0 then return false, 0, 0 end
    if p.healingItemsOut and (stats.HEAL or 0) > (stats.SPELLDMG or 0) + school then return false, 0, 0 end
    -- No mana: more intellect and spirit than strength and agility is someone else's item.
    if p.noMana and (stats.INT or 0) + (stats.SPI or 0) > (stats.STR or 0) + (stats.AGI or 0) + (stats.AP or 0) / 2 then
        return false, 0, 0
    end
    local points, main = Rules.Points(role, stats, class, room)
    return fits, points, main
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
    SHAMAN = { NATURE = true }, PALADIN = { HOLY = true },
}

-- A chance on hit comes from weapon blows.
Rules.PROC_ROLES = { TANK = true, MELEE = true, RANGED = true }

-- Trinkets' "Use:" effects as stats, read by hand from Wowhead's Forever tooltips:
-- [id] = { seconds it lasts, cooldown in seconds, stats while it lasts }. Mana
-- given at once is MANA (spread over the cooldown as mp5). A bonus that wears
-- off with each cast or hit counts with its average. Effects no stat can stand
-- for (stuns, pets, teleports, absorbs, direct heals) are left out.
Rules.ON_USE = {
    [18820] = { 15, 90, { HEAL = 175, SPELLDMG = 175 } },          -- Talisman of Ephemeral Power
    [20636] = { 15, 90, { HEAL = 350 } },                          -- Hibernation Crystal
    [23046] = { 20, 120, { HEAL = 130, SPELLDMG = 130 } },         -- The Restrained Essence of Sapphiron
    [21473] = { 30, 180, { SPELLDMG = 50 } },                      -- Eye of Moam
    [274615] = { 30, 360, { HEAL = 19, SPELLDMG = 19 } },          -- Heart of the Primeval
    [249469] = { 15, 300, { FROSTDMG = 29, SHADOWDMG = 29 } },     -- Frozen Heart of the Mountain
    [19950] = { 20, 120, { HEAL = 204, SPELLDMG = 102 } },         -- Zandalarian Hero Charm (falls per cast)
    [23047] = { 30, 120, { HEAL = 190 } },                         -- Eye of the Dead (450 on 5 of ~12 heals)
    [22678] = { 10, 60, { HEAL = 150, SPELLDMG = 80 } },           -- Talisman of Ascendance (stacks up)
    [11819] = { 0, 900, { MANA = 630 } },                          -- Second Wind
    [18371] = { 120, 420, { MANA = 1250, INT = -60 } },            -- Mindtap Talisman (-60 int for 2 min)
    [20512] = { 0, 300, { MANA = 340 } },                          -- Sanctified Orb
    [23027] = { 0, 180, { MANA = 500 } },                          -- Warmth of Forgiveness
    [20503] = { 0, 600, { MANA = 396 } },                          -- Enamored Water Spirit
    [11832] = { 0, 360, { MANA = 600 } },                          -- Burst of Knowledge (-150 on ~4 casts)
    [272439] = { 15, 360, { SPI = 72 } },                          -- Serenity Field
    [270226] = { 15, 300, { STR = 16, AGI = 16, STA = 16, INT = 16, SPI = 16 } }, -- Golden Banana
    [280071] = { 30, 300, { AGI = 33 } },                          -- Flamebreak Talisman
    [249470] = { 15, 300, { AP = 55, RAP = 55 } },                 -- Molten Heart of the Mountain
    [21180] = { 20, 120, { AP = 280, RAP = 280 } },                -- Earthstrike
    [23041] = { 20, 120, { AP = 260, RAP = 260 } },                -- Slayer's Crest
    [23570] = { 20, 120, { AP = 357, RAP = 357 } },                -- Jom Gabbar (65 more every 2 sec)
    [13965] = { 20, 300, { CRIT = 5 } },                           -- Blackhand's Breadth
    [272438] = { 8, 360, { CRIT = 5, SCRIT = 5 } },                -- Weakness Analyzer (until a crit)
    [13968] = { 20, 300, { SHIT = 7 } },                           -- Eye of the Beast
    [19952] = { 15, 180, { SCRIT = 10 } },                         -- Gri'lek's Charm of Valor
    [13966] = { 15, 300, { STA = 62 } },                           -- Mark of Tyranny (620 health)
    [15873] = { 126, 600, { STA = 40, STR = -10, AGI = -10 } },    -- Ragged John's Neverending Cup
    [11811] = { 20, 360, { ARMOR = 520 } },                        -- Smoking Heart of the Mountain
    [19345] = { 20, 300, { ARMOR = 500 } },                        -- Aegis of Preservation
    [19948] = { 20, 120, { ARMOR = 1000, DEF = 15 } },             -- Zandalarian Hero Badge (falls per hit)
    [23040] = { 20, 120, { BLOCKVAL = 235 } },                     -- Glyph of Deflection
    [18370] = { 6, 360, { DODGE = 20 } },                          -- Vigilance Charm (until 3 dodges)
    [274386] = { 20, 300, { DODGE = 3 } },                         -- Toy Soldier
    [280060] = { 15, 300, { DODGE = 5 } },                         -- Lucky Shovelnose Tuft
    [272440] = { 15, 360, { BLOCK = 8 } },                         -- Defender's Grip Stabilizer
}
-- Not used every time it is ready: the share counted.
Rules.USE_SHARE = 0.75

-- Adds an item's "Use:" effect to its stats (averaged over the cooldown); true when it had one.
function Rules.AddUse(id, stats)
    local use = Rules.ON_USE[id]
    if not (use and stats) then return false end
    local dur, cd, bonus = use[1], use[2], use[3]
    for k, v in pairs(bonus) do
        if k == "MANA" then
            stats.MP5 = (stats.MP5 or 0) + v / cd * 5 * Rules.USE_SHARE
        else
            stats[k] = (stats[k] or 0) + v * dur / cd * Rules.USE_SHARE
        end
    end
    return true
end

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
