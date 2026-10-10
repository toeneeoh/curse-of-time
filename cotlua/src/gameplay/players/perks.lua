--[[
    perks.lua

    Profile-wide Perk Points are earned from character milestones and spent on
    a connected graph. Node IDs are permanent save identifiers. Never recycle
    or reorder them; removed nodes must remain reserved for migration.

    Allocation bits are stored thirty per integer so profile values remain
    positive and compact. The root is implicit and is not serialized.
]]

OnInit.final("Perks", function(Require)
    Require('Profile')
    Require('SaveSchema')
    Require('Progression')
    Require('UnitHelpers')
    Require('UnitTable')
    Require('Users')
    Require('Events')
    Require('CooldownAcceleration')

    Perks = {}

    local SOFTCORE_POINTS, HARDCORE_POINTS = 4, 6
    local BITS_PER_WORD = 30
    local milestone_bits = { naga = 0x1, scarab = 0x2 }
    local changed_actions = {}
    local applied_effects = {}
    local dev_point_total = {}
    local bonus_cache = {}
    local bloodline_applied = __jarray(0)
    local bloodline_stat = {}
    local refreshing_bloodline = {}

    -- Keep each branch visually legible without making every minor node use
    -- the generic selected-hero placeholder. Each imported icon below also
    -- has a matching DISBTN asset for unallocated nodes in the perk tree.
    local ICON_ATTACK = "ReplaceableTextures\\CommandButtons\\BTNDivineBroadsword.blp"
    local ICON_CRITICAL = "ReplaceableTextures\\CommandButtons\\BTNDemonicSword.blp"
    local ICON_SPELL = "ReplaceableTextures\\CommandButtons\\BTNArcaneMight2.blp"
    local ICON_ARMOR = "ReplaceableTextures\\CommandButtons\\BTNShield.blp"
    local ICON_REDUCTION = "ReplaceableTextures\\CommandButtons\\BTNDarkShield.BLP"
    local ICON_REGEN = "ReplaceableTextures\\CommandButtons\\BTNHeal.blp"
    local ICON_MOVEMENT = "ReplaceableTextures\\CommandButtons\\BTNBootsOfSpeed.blp"
    local ICON_GOLD = "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp"
    local ICON_EXPERIENCE = "ReplaceableTextures\\CommandButtons\\BTNblueBook.blp"
    local ICON_MASTERY = "ReplaceableTextures\\CommandButtons\\BTNManual3.blp"
    local ICON_INHERITANCE = "ReplaceableTextures\\CommandButtons\\BTNTreasureChest.blp"
    local ICON_QUEST = "ReplaceableTextures\\CommandButtons\\BTNImprovedBows.blp"
    local ICON_MAGIC_RESIST = "ReplaceableTextures\\CommandButtons\\BTNShieldofMagicVol3.blp"
    local ICON_STATUS_RESIST = "ReplaceableTextures\\CommandButtons\\BTNAntiMagicShell.blp"
    local ICON_DROP_RATE = "ReplaceableTextures\\CommandButtons\\BTNTransmute.blp"
    local ICON_MANA_REGEN = "ReplaceableTextures\\CommandButtons\\BTNBrilliance.blp"
    local ICON_COOLDOWN = "ReplaceableTextures\\CommandButtons\\BTNControlTime.blp"

    -- Names describe the effect, not where a repeated node happens to live.
    local effect_names = {
        damage_percent = "Attack Damage", crit_damage = "Critical Damage",
        crit_chance = "Critical Chance", primary_percent = "Mastery",
        spellboost = "Spell Power", spell_area = "Spell Area",
        spell_duration = "Spell Duration", armor_percent = "Armor",
        regen_percent = "Health Regeneration", damage_reduction = "Damage Resistance",
        movespeed = "Movement Speed", gold_rate = "Gold Find",
        shared_xp = "Fellowship", inheritance = "Inheritance", huntsman = "Huntsman's Favor",
        mana_regen_percent = "Mana Regeneration", magic_reduction = "Magic Resistance",
        status_resistance = "Status Resistance", cooldown_acceleration = "Cooldown Recovery",
        drop_rate = "Drop Rate", boss_drop_rate = "Boss Drop Rate",
        potion_restoration = "Potion Restoration", potion_duration = "Infusion Duration",
        potion_refill_discount = "Potion Refill Savings", recharge_discount = "Reincarnation Gold Savings",
        reincarnation_capacity = "Reincarnation Capacity", home_channel = "Return Home",
    }
    local branches = {
        {key = "might", name = "Might", x = 4.5, y = 0, color = "|cffffb060", description = "Attack damage, critical strikes, attributes, and spellcasting."},
        {key = "guard", name = "Guard", x = -4.5, y = 0, color = "|cff80c0ff", description = "Armor, damage resistance, recovery, and status resistance."},
        {key = "fellowship", name = "Fellowship", x = 0, y = 3.8, color = "|cff80e090", description = "Shared experience, exploration, and finding rewards."},
        {key = "legacy", name = "Legacy", x = 0, y = -4.3, color = "|cffd0a0ff", description = "Inheritance, potions, reincarnation, and Return Home."},
    }

    ---@class PerkNode
    ---@field id integer Stable save identifier.
    ---@field key string
    ---@field name string
    ---@field x number Logical graph position.
    ---@field y number Logical graph position.
    ---@field parent integer?
    ---@field alternate_parent integer?
    ---@field effect string?
    ---@field value number?
    ---@field rank_key string?
    ---@field icon string
    ---@field description string
    ---@field notable boolean?
    ---@field keystone boolean?
    ---@field branch string? Branch key for navigation and presentation.
    ---@field icon_size number Unscaled size, ranked by bonus within each effect.
    ---@field routes table<integer, number[][]> Static presentation routes indexed by prerequisite ID.

    local nodes = {}
    local nodes_by_key = {}
    local function add(id, key, name, x, y, parent, effect, value, description, icon, flags)
        local node = {
            id = id, key = key, name = effect_names[effect] or name, x = x, y = y, parent = parent,
            effect = effect, value = value, description = description,
            icon = icon or "ReplaceableTextures\\CommandButtons\\BTNSelectHeroOn.blp",
            notable = flags and flags.notable,
            keystone = flags and flags.keystone,
            rank_key = flags and flags.rank_key,
            alternate_parent = flags and flags.alternate_parent,
        }
        nodes[id] = node
        nodes_by_key[key] = node
    end

    add(1, "root", "Origin", 0, 0, nil, nil, nil,
        "The origin of your profile's permanent progression.",
        "ReplaceableTextures\\CommandButtons\\BTNHeroPanelPerkButton.dds", { keystone = true })

    -- Eastern offense web.
    add(2, "force", "Force", 1, 0, 1, "damage_percent", .01, "Gain |cffffcc001%|r Attack Damage.", ICON_ATTACK)
    add(3, "precision", "Precision", 2, 0, 2, "crit_damage", 5, "Gain |cffffcc005%|r Critical Damage.", ICON_CRITICAL)
    add(4, "bloodline_1", "Mastery I", 3, 0, 3, "primary_percent", .04,
        "Gain |cffffcc004%|r Primary Attribute.", ICON_MASTERY, { notable = true, rank_key = "bloodline" })
    add(5, "bloodline_2", "Mastery II", 4, 0, 4, "primary_percent", .04,
        "Gain |cffffcc004%|r Primary Attribute.", ICON_MASTERY, { notable = true, rank_key = "bloodline" })
    add(6, "bloodline_3", "Mastery III", 5, 0, 5, "primary_percent", .04,
        "Gain |cffffcc004%|r Primary Attribute.", ICON_MASTERY, { keystone = true, rank_key = "bloodline" })
    add(7, "brutality", "Brutality", 3, 1, 4, "crit_damage", 10, "Gain |cffffcc0010%|r Critical Damage.", ICON_CRITICAL)
    add(8, "keen_edge", "Keen Edge", 4, 1.35, 7, "crit_chance", 2, "Gain |cffffcc002%|r Critical Chance.", ICON_CRITICAL)
    add(9, "execution", "Execution", 5, 1.55, 8, "damage_percent", .03, "Gain |cffffcc003%|r Attack Damage.", ICON_ATTACK, { notable = true })
    add(10, "arcane_spark", "Arcane Spark", 3, -1, 4, "spellboost", .01, "Gain |cffffcc001%|r Spell Power.", ICON_SPELL)
    add(11, "potency", "Potency", 4, -1.35, 10, "spellboost", .02, "Gain |cffffcc002%|r Spell Power.", ICON_SPELL)
    add(12, "overwhelming_magic", "Overwhelming Magic", 5, -1.55, 11, "spellboost", .03, "Gain |cffffcc003%|r Spell Power.", ICON_SPELL, { notable = true })

    -- Western defense and sustain web.
    add(13, "endurance", "Endurance", -1, 0, 1, "armor_percent", .02, "Gain |cffffcc002%|r Armor.", ICON_ARMOR)
    add(14, "recovery", "Recovery", -2, 0, 13, "regen_percent", .02, "Gain |cffffcc002%|r Health Regeneration.", ICON_REGEN)
    add(15, "resolve_1", "Resolve I", -3, 0, 14, "damage_reduction", .02, "Take |cffffcc002%|r less damage.", ICON_REDUCTION, { notable = true })
    add(16, "resolve_2", "Resolve II", -4, 0, 15, "damage_reduction", .02, "Take |cffffcc002%|r less damage.", ICON_REDUCTION, { notable = true })
    add(17, "resolve_3", "Resolve III", -5, 0, 16, "damage_reduction", .02, "Take |cffffcc002%|r less damage.", ICON_REDUCTION, { keystone = true })
    add(18, "iron_skin", "Iron Skin", -3, 1, 15, "armor_percent", .03, "Gain |cffffcc003%|r Armor.", ICON_ARMOR)
    add(19, "bulwark", "Bulwark", -4, 1.35, 18, "armor_percent", .04, "Gain |cffffcc004%|r Armor.", ICON_ARMOR)
    add(20, "unyielding", "Unyielding", -5, 1.55, 19, "damage_reduction", .02, "Take |cffffcc002%|r less damage.", ICON_REDUCTION, { notable = true })
    add(21, "renewal", "Renewal", -3, -1, 15, "regen_percent", .03, "Gain |cffffcc003%|r Health Regeneration.", ICON_REGEN)
    add(22, "vital_current", "Vital Current", -4, -1.35, 21, "regen_percent", .04, "Gain |cffffcc004%|r Health Regeneration.", ICON_REGEN)
    add(23, "second_wind", "Second Wind", -5, -1.55, 22, "regen_percent", .05, "Gain |cffffcc005%|r Health Regeneration.", ICON_REGEN, { notable = true })

    -- Northern party and exploration web.
    add(24, "pathfinder", "Pathfinder", 0, 1, 1, "movespeed", 5, "Gain |cffffcc005|r Movespeed.", ICON_MOVEMENT)
    add(25, "prosperity", "Prosperity", 0, 2, 24, "gold_rate", 3, "Gain |cffffcc003%|r Gold Find.", ICON_GOLD)
    add(26, "fellowship_1", "Fellowship I", 0, 3, 25, "shared_xp", .02,
        "All players gain |cffffcc00+2%|r experience rate.", ICON_EXPERIENCE, { notable = true, rank_key = "fellowship" })
    add(27, "fellowship_2", "Fellowship II", 0, 4, 26, "shared_xp", .02,
        "All players gain |cffffcc00+2%|r experience rate.", ICON_EXPERIENCE, { notable = true, rank_key = "fellowship" })
    add(28, "fellowship_3", "Fellowship III", 0, 5, 27, "shared_xp", .02,
        "All players gain |cffffcc00+2%|r experience rate.", ICON_EXPERIENCE, { keystone = true, rank_key = "fellowship" })
    add(29, "fleetfoot", "Fleetfoot", 1, 3, 26, "movespeed", 5, "Gain |cffffcc005|r Movespeed.", ICON_MOVEMENT)
    add(30, "wanderer", "Wanderer", 2, 3.6, 29, "movespeed", 10, "Gain |cffffcc0010|r Movespeed.", ICON_MOVEMENT, { notable = true })
    add(31, "treasure_sense", "Treasure Sense", -1, 3, 26, "gold_rate", 3, "Gain |cffffcc003%|r Gold Find.", ICON_GOLD)
    add(32, "fortune", "Fortune", -2, 3.6, 31, "gold_rate", 5, "Gain |cffffcc005%|r Gold Find.", ICON_GOLD, { notable = true })

    -- Southern inheritance and quest web.
    add(33, "legacy_gold", "Legacy", 0, -1, 1, "gold_rate", 2, "Gain |cffffcc002%|r Gold Find.", ICON_GOLD)
    add(34, "preparation", "Preparation", 0, -2, 33, "movespeed", 5, "Gain |cffffcc005|r Movespeed.", ICON_MOVEMENT)
    add(35, "inheritance_1", "Inheritance I", 0, -3, 34, "inheritance", 1,
        "New characters begin with |cffffcc00+5 Levels|r and |cffffcc00+25,000 Gold|r.", ICON_INHERITANCE, { notable = true, rank_key = "inheritance" })
    add(36, "inheritance_2", "Inheritance II", 0, -4, 35, "inheritance", 1,
        "New characters begin with another |cffffcc00+5 Levels|r and |cffffcc00+25,000 Gold|r.", ICON_INHERITANCE, { notable = true, rank_key = "inheritance" })
    add(37, "inheritance_3", "Inheritance III", 0, -5, 36, "inheritance", 1,
        "New characters begin with another |cffffcc00+5 Levels|r and |cffffcc00+25,000 Gold|r.", ICON_INHERITANCE, { keystone = true, rank_key = "inheritance" })
    add(38, "hunters_mark", "Hunter's Mark", -1, -2.8, 34, "gold_rate", 2, "Gain |cffffcc002%|r Gold Find.", ICON_GOLD)
    add(39, "fieldcraft", "Fieldcraft", -2, -3.25, 38, "movespeed", 5, "Gain |cffffcc005|r Movespeed.", ICON_MOVEMENT)
    add(40, "huntsmans_favor", "Huntsman's Favor", -3, -3.5, 39, "huntsman", 1,
        "Automatically turns in completed kill quests when an eligible owner is active.", ICON_QUEST, { keystone = true, rank_key = "huntsmans_favor" })
    add(41, "nest_egg", "Nest Egg", 1, -3, 35, "gold_rate", 3, "Gain |cffffcc003%|r Gold Find.", ICON_GOLD)
    add(42, "patronage", "Patronage", 2, -3.5, 41, "gold_rate", 5, "Gain |cffffcc005%|r Gold Find.", ICON_GOLD, { notable = true })
    add(43, "quick_study", "Potion Refill Savings", 1, -4, 36, "potion_refill_discount", .02,
        "Pay |cffffcc002%|r less for potion refills.", ICON_GOLD)
    add(44, "mentorship", "Infusion Duration", 2, -4.5, 43, "potion_duration", .02,
        "Potion infusions last |cffffcc002%|r longer.", ICON_COOLDOWN, { notable = true })
    add(45, "heirloom", "Heirloom", 3, -3.5, 42, "gold_rate", 5, "Gain |cffffcc005%|r Gold Find.", ICON_GOLD, { notable = true, alternate_parent = 44 })

    -- Saved IDs stay stable. Two old Legacy experience nodes now
    -- grant potion utility; experience is limited to five nodes. Alternate
    -- entrances let spellcasters and sustain builds skip unrelated bonuses.
    nodes[10].alternate_parent = 47
    nodes[21].alternate_parent = 60
    local minor_effects = {
        damage_percent = {ICON_ATTACK, "Attack Damage", 100},
        crit_damage = {ICON_CRITICAL, "Critical Damage", 1},
        crit_chance = {ICON_CRITICAL, "Critical Chance", 1},
        primary_percent = {ICON_MASTERY, "Primary Attribute", 100},
        spellboost = {ICON_SPELL, "Spell Power", 100},
        spell_area = {"ReplaceableTextures\\CommandButtons\\BTNFlameStrike.blp", "Spell Area", 100},
        spell_duration = {"ReplaceableTextures\\CommandButtons\\BTNRejuvenation.blp", "Spell Duration", 100},
        armor_percent = {ICON_ARMOR, "Armor", 100},
        regen_percent = {ICON_REGEN, "Health Regeneration", 100},
        mana_regen_percent = {ICON_MANA_REGEN, "Mana Regeneration", 100},
        status_resistance = {ICON_STATUS_RESIST, "Status Resistance", 1},
        cooldown_acceleration = {ICON_COOLDOWN, "Cooldown Recovery", 100},
        gold_rate = {ICON_GOLD, "Gold Find", 1},
        shared_xp = {ICON_EXPERIENCE, "Experience Rate", 100},
        drop_rate = {ICON_DROP_RATE, "Drop Rate", 100},
        boss_drop_rate = {ICON_DROP_RATE, "Boss Drop Rate", 100},
        potion_restoration = {"ReplaceableTextures\\CommandButtons\\BTNPotionGreenSmall.blp", "Potion Restoration", 100},
        potion_duration = {ICON_COOLDOWN, "Infusion Duration", 100},
        potion_refill_discount = {ICON_GOLD, "Potion Refill Savings", 100},
        recharge_discount = {"ReplaceableTextures\\CommandButtons\\BTNReincarnation.blp", "Reincarnation Gold Savings", 100},
        home_channel = {"ReplaceableTextures\\CommandButtons\\BTNMassTeleport.blp", "Return Home Channel Speed", 100},
    }
    local function extend(id, branch, x, y, parent, effect, value, notable, keystone, rank_key)
        local spec = minor_effects[effect]
        local description, icon
        if spec then
            description = "Gain |cffffcc00" .. string.format("%g", value * spec[3]) .. "%|r " .. spec[2] .. "."
            icon = spec[1]
            if effect == "potion_refill_discount" or effect == "recharge_discount" then
                description = "Pay |cffffcc00" .. string.format("%g", value * 100) .. "%|r less "
                    .. (effect == "potion_refill_discount" and "for potion refills." or "gold for reincarnation recharge services.")
            elseif effect == "home_channel" then
                description = "Shorten Return Home's channel by |cffffcc00" .. string.format("%g", value * 100) .. "%|r."
            end
            if effect == "shared_xp" then
                description = "All players gain |cffffcc00+" .. math.floor(value * 100 + .5)
                    .. "%|r experience rate."
            end
        elseif effect == "damage_reduction" or effect == "magic_reduction" then
            description = "Take |cffffcc00" .. string.format("%g", value * 100) .. "%|r less "
                .. (effect == "magic_reduction" and "magic " or "") .. "damage."
            icon = ICON_REDUCTION
        elseif effect == "movespeed" then
            description = "Gain |cffffcc00" .. value .. "|r Movespeed."
            icon = ICON_MOVEMENT
        elseif effect == "reincarnation_capacity" then
            description = "Rechargeable reincarnation items can hold |cffffcc00+1|r additional charge. Charges must still be purchased."
            icon = "ReplaceableTextures\\CommandButtons\\BTNReincarnation.blp"
        else -- inheritance
            description = "New characters begin with another |cffffcc00+5 Levels|r and |cffffcc00+25,000 Gold|r."
            icon = ICON_INHERITANCE
        end
        add(id, "perk_" .. id, effect_names[effect], x, y, parent, effect, value, description, icon,
            {notable = notable, keystone = keystone, rank_key = rank_key})
        nodes[id].branch = branch
    end

    -- Might: a small general-power entrance branches into independent utility
    -- investments. Utility is never required to reach the power rewards.
    extend(46, "might", 1, -1.2, 10, "spell_duration", .01)
    extend(47, "might", 2, -1.2, 46, "spell_duration", .02)
    extend(48, "might", 6, -1.2, 47, "spell_duration", .03, true)
    extend(49, "might", 7, -1.2, 48, "cooldown_acceleration", .03, true)
    extend(50, "might", 8, -1.2, 49, "cooldown_acceleration", .04, nil, true)
    extend(51, "might", 3, -2.4, 10, "spell_area", .01)
    extend(52, "might", 4, -2.4, 51, "spell_area", .02)
    extend(53, "might", 5, -2.4, 52, "spell_area", .03, true)
    extend(54, "might", 6, 1.2, 9, "damage_percent", .02)
    extend(55, "might", 7, 1.2, 54, "crit_chance", 1)
    extend(56, "might", 8, 1.2, 55, "crit_damage", 10, nil, true)
    extend(57, "might", 6, 0, 6, "damage_percent", .02)
    extend(58, "might", 7, 0, 57, "primary_percent", .02, true, nil, "bloodline")

    -- Guard: a direct recovery entrance, with separate resistance lanes.
    extend(59, "guard", -1, -1.2, 1, "regen_percent", .02)
    extend(60, "guard", -2, -1.2, 59, "regen_percent", .02)
    extend(61, "guard", -6, -1.2, 23, "regen_percent", .05)
    extend(62, "guard", -7, -1.2, 61, "regen_percent", .05, true)
    extend(63, "guard", -3, -2.4, 21, "status_resistance", 2)
    extend(64, "guard", -4, -2.4, 63, "status_resistance", 3)
    extend(65, "guard", -5, -2.4, 64, "status_resistance", 5, nil, true)
    extend(66, "guard", -6, 1.2, 20, "armor_percent", .03)
    extend(67, "guard", -7, 1.2, 66, "damage_reduction", .02, true)
    extend(68, "guard", -3, 2.4, 18, "magic_reduction", .02)
    extend(69, "guard", -4, 2.4, 68, "magic_reduction", .02)
    extend(70, "guard", -5, 2.4, 69, "magic_reduction", .03, true)
    extend(71, "guard", -6, 0, 17, "armor_percent", .03)

    -- Fellowship: travel and reward-finding flanks around shared experience.
    extend(72, "fellowship", 3, 3, 30, "movespeed", 5)
    extend(73, "fellowship", 4, 3, 72, "movespeed", 5)
    extend(74, "fellowship", 5, 3, 73, "movespeed", 5, true)
    extend(75, "fellowship", -3, 3, 32, "gold_rate", 3)
    extend(76, "fellowship", -4, 3, 75, "gold_rate", 5, true)
    extend(77, "fellowship", -2, 4.2, 32, "drop_rate", .01)
    extend(78, "fellowship", -3, 4.2, 77, "drop_rate", .02)
    extend(79, "fellowship", -4, 4.2, 78, "boss_drop_rate", .02, true)
    extend(80, "fellowship", 1.2, 5, 28, "shared_xp", .02, nil, nil, "fellowship")
    extend(81, "fellowship", 2.4, 5, 80, "shared_xp", .02, true, nil, "fellowship")

    -- Legacy: deeper inheritance, wealth, and recovery for new characters.
    extend(82, "legacy", 4, -3, 45, "gold_rate", 3)
    extend(83, "legacy", 5, -3, 82, "drop_rate", .01)
    extend(84, "legacy", 6, -3, 83, "drop_rate", .02, true)
    extend(85, "legacy", 4, -4.2, 45, "boss_drop_rate", .01)
    extend(86, "legacy", 5, -4.2, 85, "boss_drop_rate", .02, true)
    extend(87, "legacy", 6, -4.2, 86, "gold_rate", 3)
    extend(88, "legacy", 0, -6, 37, "inheritance", 1, true, nil, "inheritance")
    extend(89, "legacy", 0, -7, 88, "inheritance", 1, nil, true, "inheritance")
    extend(90, "legacy", -1, -4.2, 39, "mana_regen_percent", .05)
    extend(91, "legacy", -2, -4.2, 90, "mana_regen_percent", .05, true)

    for id = 2, 45 do
        nodes[id].branch = id <= 12 and "might" or id <= 23 and "guard"
            or id <= 32 and "fellowship" or "legacy"
    end

    -- Define minor investments before threading their rewards below. Each
    -- ten-node budget preserves the graph's total power and storage capacity.
    local next_id = 92
    local function lane(branch, parent, effect, value, terminal)
        for step = 1, 10 do
            local selected, amount = effect, value
            if step == 10 and terminal then selected, amount = terminal[1], terminal[2] end
            extend(next_id, branch, 0, 0, parent, selected, amount, step == 10)
            parent, next_id = next_id, next_id + 1
        end
    end
    lane("might", 2, "damage_percent", .0025)
    lane("might", 10, "spell_duration", .0025)
    lane("might", 3, "crit_damage", 1)
    lane("might", 10, "spell_area", .0025)
    lane("guard", 13, "armor_percent", .005)
    lane("guard", 59, "regen_percent", .005)
    lane("guard", 14, "damage_reduction", .001)
    lane("guard", 60, "magic_reduction", .001)
    lane("fellowship", 24, "movespeed", 1)
    lane("fellowship", 25, "gold_rate", .5)
    lane("fellowship", 31, "drop_rate", .001)
    lane("legacy", 33, "potion_restoration", .01, {"potion_duration", .08})
    lane("legacy", 34, "potion_refill_discount", .01)
    lane("legacy", 38, "recharge_discount", .01, {"reincarnation_capacity", 1})
    lane("legacy", 39, "home_channel", .025)
    assert(#nodes - 1 <= PROFILE_PERK_NODE_WORDS * BITS_PER_WORD,
        "Perk graph exceeds profile allocation storage")

    -- Investment precedes payoff. Keep IDs/effect totals, but thread the old
    -- rewards through minor nodes rather than offering parallel inferior lanes.
    local function investment(entry, first, rewards)
        local parent, cursor = entry, first
        for index, reward in ipairs(rewards) do
            local count = index == 1 and 4 or 3
            for _ = 1, count do
                nodes[cursor].parent, nodes[cursor].alternate_parent = parent, nil
                parent, cursor = cursor, cursor + 1
            end
            nodes[reward].parent, nodes[reward].alternate_parent = parent, nil
            parent = reward
        end
        assert(cursor == first + 10, "Investment path must consume its ten minor nodes")
    end
    investment(1, 92, {2, 9, 54})                 -- Attack: 4 small, +1%; 3 small, +3%; 3 small, +2%.
    nodes[10].parent, nodes[10].alternate_parent = 1, nil -- General power, then a choice of three lanes.
    investment(10, 102, {46, 47, 48})            -- Spell Duration investment and rewards.
    investment(2, 112, {3, 7, 56})                -- Critical damage specialization.
    investment(10, 122, {51, 52, 53})            -- Spell Area investment and rewards.
    investment(1, 132, {13, 18, 19})              -- Armor entrance.
    investment(1, 142, {59, 14, 21})              -- Recovery entrance independent of damage resistance.
    investment(13, 152, {15, 16, 17})             -- Damage resistance specialization.
    investment(13, 162, {68, 69, 70})             -- Magic resistance specialization.
    investment(1, 172, {24, 29, 30})              -- Four +1 movement nodes before the first +5 payoff.
    investment(24, 182, {25, 31, 32})             -- Gold-finding specialization.
    investment(25, 192, {77, 78, 79})             -- Drop-finding specialization.
    nodes[55].parent, nodes[8].parent = 7, 55      -- +1 critical chance precedes +2, not the reverse.
    nodes[58].parent, nodes[4].parent = 3, 58     -- Smaller attribute investment precedes +4% rewards.
    nodes[57].parent = 54
    nodes[20].parent, nodes[66].parent, nodes[71].parent = 17, 19, 67
    nodes[60].parent, nodes[146].parent = 59, 60  -- Extra recovery is on the path, not a superior parallel detour.
    nodes[63].parent = 18
    nodes[26].parent = 24                        -- XP is a separate choice, not mandatory movement travel.
    nodes[75].parent = 32
    -- Utility paths already end in large duration/capacity rewards. Thread the
    -- separate refill reward into its minor investment and gate Legacy's flat
    -- movement rewards behind Return Home investments instead of cheap detours.
    nodes[212].parent, nodes[43].parent, nodes[216].parent = 33, 215, 43
    nodes[232].parent, nodes[34].parent, nodes[39].parent = 33, 236, 241
    nodes[44].parent = 211
    nodes[45].alternate_parent = nil             -- No bypass of the reward-finding investment.

    -- Lay out the actual prerequisite tree, not unrelated rings of node IDs.
    -- Each subtree owns a disjoint sideways interval. Branch corridors leave
    -- the parent before entering that interval, so unrelated paths cannot merge.
    local district_angle = {might = 0., fellowship = math.pi * .5,
        guard = math.pi, legacy = -math.pi * .5}
    local function place(id, outward, sideways)
        local node = nodes[id]
        local angle = district_angle[node.branch]
        node.x = outward * math.cos(angle) - sideways * math.sin(angle)
        node.y = outward * math.sin(angle) + sideways * math.cos(angle)
    end
    local children, widths, coordinates = {}, {}, {}
    for id = 1, #nodes do children[id] = {} end
    for id = 2, #nodes do
        local siblings = children[nodes[id].parent]
        siblings[#siblings + 1] = id
    end
    local function measure(id)
        local width = 0
        for _, child in ipairs(children[id]) do width = width + measure(child) end
        widths[id] = math.max(1, width)
        return widths[id]
    end
    measure(1)
    local function side_at(left, width, depth)
        -- Fan out gradually instead of immediately reserving the final leaf
        -- width after the district entrance (especially wide in Legacy).
        local spread = math.min(1, .5 + math.max(0, depth - 2) * .15)
        return (left + width * .5) * 2.1 * spread + .28 * math.sin(depth * .8)
    end
    local function arrange(id, left, depth, previous_outward, entry_side)
        local sideways = side_at(left, widths[id], depth)
        local outward = math.max(previous_outward + 1.6, math.abs(sideways) * 1.25 + 1.6)
        if entry_side then outward, sideways = 1.5, entry_side end
        coordinates[id] = {outward, sideways}
        place(id, outward, sideways)
        local corridor, child_left = outward + .65, left
        for _, child in ipairs(children[id]) do
            local child_side = side_at(child_left, widths[child], depth + 1)
            corridor = math.max(corridor, math.abs(child_side) * 1.25 + .8)
            child_left = child_left + widths[child]
        end
        for _, child in ipairs(children[id]) do
            arrange(child, left, depth + 1, corridor - .8)
            left = left + widths[child]
        end
    end
    for _, branch in ipairs(branches) do
        local width, entries = 0, {}
        for _, id in ipairs(children[1]) do
            if nodes[id].branch == branch.key then
                width = width + widths[id]; entries[#entries + 1] = id
            end
        end
        -- Two independent origin entrances own opposite half-districts,
        -- even when one contains many more leaves than the other.
        local left = #entries == 2 and -widths[entries[1]] or -width * .5
        for index, id in ipairs(entries) do
            arrange(id, left, 1, 0, (index - (#entries + 1) * .5) * 1.2)
            left = left + widths[id]
        end
    end
    -- Store static connector routes next to presentation coordinates. Alternate
    -- prerequisites use a separate outer-side corridor, not an apparent junction.
    for id = 2, #nodes do
        local node, child = nodes[id], coordinates[id]
        node.routes = {}
        for _, parent_id in ipairs({node.parent, node.alternate_parent}) do
            local parent = coordinates[parent_id] or {0, 0}
            local corridor = parent_id == 1 and .75 or math.max(parent[1] + .65,
                math.max(math.abs(parent[2]), math.abs(child[2])) * 1.25 + .8)
            if parent_id ~= 1 then
                for _, sibling in ipairs(children[parent_id]) do
                    corridor = math.max(corridor, math.abs(coordinates[sibling][2]) * 1.25 + .8)
                end
            end
            if parent_id == node.alternate_parent then corridor = math.max(parent[1], child[1]) + .65 end
            local angle = district_angle[node.branch]
            local function point(outward, sideways)
                return {outward * math.cos(angle) - sideways * math.sin(angle),
                    outward * math.sin(angle) + sideways * math.cos(angle)}
            end
            node.routes[parent_id] = {point(parent[1], parent[2]), point(corridor, parent[2]),
                point(corridor, child[2]), point(child[1], child[2])}
        end
    end

    -- Equal bonuses use equal sizes; stronger bonuses use larger icons,
    -- independently of arbitrary endpoint/notable flags.
    local effect_ranges = {}
    for _, node in ipairs(nodes) do
        if node.effect == "shared_xp" then
            node.description = "All players gain |cffffcc00+2%|r experience rate."
        elseif node.effect == "cooldown_acceleration" then
            node.description = "Recover |cffffcc00" .. string.format("%.2f", node.value)
                .. "|r additional cooldown seconds per second."
            node.icon = ICON_COOLDOWN
        elseif node.effect == "magic_reduction" then
            node.icon = ICON_MAGIC_RESIST
        end
        if node.effect then
            local range = effect_ranges[node.effect] or {min = node.value, max = node.value}
            range.min, range.max = math.min(range.min, node.value), math.max(range.max, node.value)
            effect_ranges[node.effect] = range
        end
    end
    for _, node in ipairs(nodes) do
        local range = effect_ranges[node.effect]
        node.icon_size = not range and .038 or range.max == range.min and .026
            or .023 + .011 * (node.value - range.min) / (range.max - range.min)
    end

    local summaries = {
        { key = "bloodline", name = "Mastery", max_rank = 4 },
        { key = "fellowship", name = "Fellowship", max_rank = 5 },
        { key = "inheritance", name = "Inheritance", max_rank = 5 },
        { key = "huntsmans_favor", name = "Huntsman's Favor", max_rank = 1 },
    }
    local stat_keys = {
        [1] = { "str", "bonus_str" },
        [2] = { "int", "bonus_int" },
        [3] = { "agi", "bonus_agi" },
    }

    local function words(profile)
        profile.perk_node_words = profile.perk_node_words or __jarray(0)
        return profile.perk_node_words
    end

    local function bit_location(id)
        local offset = id - 2
        return offset // BITS_PER_WORD + 1, offset % BITS_PER_WORD
    end

    local function set_allocated(profile, id, allocated)
        if id <= 1 then return end
        local word, bit = bit_location(id)
        local mask = 1 << bit
        local storage = words(profile)
        if allocated then
            storage[word] = (storage[word] or 0) | mask
        else
            storage[word] = (storage[word] or 0) & ~mask
        end
    end

    local function profile_has_node(profile, id)
        if id == 1 then return true end
        if not profile or not nodes[id] then return false end
        local word, bit = bit_location(id)
        return (((words(profile)[word] or 0) >> bit) & 1) ~= 0
    end

    local function notify_changed(pid)
        for index = 1, #changed_actions do changed_actions[index](pid) end
    end

    local function count_milestones(mask)
        local count = 0
        for _, bit in pairs(milestone_bits) do
            if (mask & bit) ~= 0 then count = count + 1 end
        end
        return count
    end

    local function earned_total(profile)
        if not profile then return 0 end
        local total = 0
        for slot = 1, MAX_SLOTS do
            local hero_data = profile.storage[slot]
            if hero_data then
                local points = (hero_data.hardcore or 0) > 0
                    and HARDCORE_POINTS or SOFTCORE_POINTS
                total = total + count_milestones(hero_data.perk_milestones or 0) * points
            end
        end
        return total
    end

    local function aggregate(pid)
        if bonus_cache[pid] then return bonus_cache[pid] end
        local result = {}
        local profile = Profile[pid]
        if not profile then return result end
        for id = 2, #nodes do
            local node = nodes[id]
            if profile_has_node(profile, id) and node.effect then
                result[node.effect] = (result[node.effect] or 0) + (node.value or 0)
            end
        end
        result.shared_xp = math.min(.10, result.shared_xp or 0.)
        bonus_cache[pid] = result
        return result
    end

    local function invalidate(pid)
        bonus_cache[pid] = nil
    end

    ---@return PerkNode[]
    function Perks.getNodes() return nodes end
    function Perks.getBranches() return branches end

    ---@return table[]
    function Perks.getDefinitions() return summaries end

    ---@param pid integer
    ---@return table<string, number>
    function Perks.getBonuses(pid)
        return aggregate(pid)
    end

    ---@param id integer
    ---@return PerkNode?
    function Perks.getNode(id) return nodes[id] end

    ---@param pid integer
    ---@param id integer
    ---@return boolean
    function Perks.hasNode(pid, id)
        return profile_has_node(Profile[pid], id)
    end

    ---@param pid integer
    ---@param key string
    ---@return integer
    function Perks.getRank(pid, key)
        local rank = 0
        for id = 2, #nodes do
            if nodes[id].rank_key == key and Perks.hasNode(pid, id) then rank = rank + 1 end
        end
        return rank
    end

    ---@param pid integer
    ---@return integer
    function Perks.getTotal(pid)
        local profile = Profile[pid]
        if not profile then return 0 end
        return dev_point_total[pid] or earned_total(profile)
    end

    --- Runtime-only budget used by development commands. It is intentionally
    --- excluded from profile serialization and milestone reconciliation.
    ---@param pid integer
    ---@param amount integer
    function Perks.setDevPoints(pid, amount)
        dev_point_total[pid] = math.max(0, amount)
        notify_changed(pid)
    end

    ---@param pid integer
    ---@return integer
    function Perks.getSpent(pid)
        local spent = 0
        for id = 2, #nodes do
            if Perks.hasNode(pid, id) then spent = spent + 1 end
        end
        return spent
    end

    function Perks.getAvailable(pid)
        return math.max(0, Perks.getTotal(pid) - Perks.getSpent(pid))
    end

    function Perks.hasReset(pid)
        local profile = Profile[pid]
        return profile ~= nil and (profile.perk_reset_available or 0) > 0
    end

    ---@param pid integer
    ---@param id integer
    ---@return boolean, string?
    function Perks.canAllocate(pid, id)
        local node = nodes[id]
        local profile = Profile[pid]
        if not node or id == 1 or not profile then return false, "INVALID NODE" end
        if profile_has_node(profile, id) then return false, "ALLOCATED" end
        if Perks.getAvailable(pid) < 1 then return false, "NOT ENOUGH POINTS" end
        if not profile_has_node(profile, node.parent)
            and not profile_has_node(profile, node.alternate_parent) then
            return false, "NOT CONNECTED"
        end
        return true
    end

    local function refresh_all_experience_rates()
        local user = User.first
        while user do
            local profile = Profile[user.id]
            if profile and profile.playing and Hero[user.id] then ExperienceControl(user.id) end
            user = user.next
        end
    end

    function Perks.getSharedXPBonus()
        local total = 0
        local user = User.first
        while user do
            local profile = Profile[user.id]
            if profile and profile.playing then
                total = total + (aggregate(user.id).shared_xp or 0)
            end
            user = user.next
        end
        return total
    end

    local function refresh_bloodline(pid)
        if refreshing_bloodline[pid] then return end
        local hero, profile = Hero[pid], Profile[pid]
        if not hero or not profile or not profile.playing then return end
        local unit = Unit[hero]
        local keys = stat_keys[MainStat(hero)]
        if not unit or not keys then return end

        refreshing_bloodline[pid] = true
        local previous = bloodline_applied[pid]
        local previous_keys = bloodline_stat[pid]
        if previous_keys and previous_keys[2] ~= keys[2] and previous ~= 0 then
            unit[previous_keys[2]] = unit[previous_keys[2]] - previous
            previous = 0
        end
        local total = unit[keys[1]] + unit[keys[2]] - previous
        local current = math.floor(total * (aggregate(pid).primary_percent or 0))
        if current ~= previous then unit[keys[2]] = unit[keys[2]] - previous + current end
        bloodline_applied[pid], bloodline_stat[pid] = current, keys
        refreshing_bloodline[pid] = nil
    end

    local function apply_effects(pid)
        local profile, hero = Profile[pid], Hero[pid]
        local current = aggregate(pid)
        local previous = applied_effects[pid] or {}
        if profile and profile.playing and hero then
            local unit = Unit[hero]
            unit.damage_percent = unit.damage_percent
                + (current.damage_percent or 0) - (previous.damage_percent or 0)
            unit.spellboost = unit.spellboost
                + (current.spellboost or 0) - (previous.spellboost or 0)
            unit.spell_area = unit.spell_area
                + (current.spell_area or 0) - (previous.spell_area or 0)
            unit.spell_duration = unit.spell_duration
                + (current.spell_duration or 0) - (previous.spell_duration or 0)
            unit.cc_flat = unit.cc_flat
                + (current.crit_chance or 0) - (previous.crit_chance or 0)
            unit.cd_flat = unit.cd_flat
                + (current.crit_damage or 0) - (previous.crit_damage or 0)
            unit.ms_flat = unit.ms_flat
                + (current.movespeed or 0) - (previous.movespeed or 0)
            unit.gold_rate = unit.gold_rate
                + (current.gold_rate or 0) - (previous.gold_rate or 0)
            unit.status_resist_flat = unit.status_resist_flat
                + (current.status_resistance or 0) - (previous.status_resistance or 0)
            CooldownAcceleration.setPermanent(hero, current.cooldown_acceleration or 0)
            unit.drop_rate = unit.drop_rate
                + (current.drop_rate or 0) - (previous.drop_rate or 0)
            unit.boss_drop_rate = unit.boss_drop_rate
                + (current.boss_drop_rate or 0) - (previous.boss_drop_rate or 0)

            local old_armor = 1 + (previous.armor_percent or 0)
            local new_armor = 1 + (current.armor_percent or 0)
            unit.armor_percent = unit.armor_percent / old_armor * new_armor
            local old_regen = 1 + (previous.regen_percent or 0)
            local new_regen = 1 + (current.regen_percent or 0)
            unit.regen_percent = unit.regen_percent / old_regen * new_regen
            unit.mana_regen_percent = unit.mana_regen_percent
                / (1 + (previous.mana_regen_percent or 0))
                * (1 + (current.mana_regen_percent or 0))
            local old_dr = 1 - (previous.damage_reduction or 0)
            local new_dr = 1 - (current.damage_reduction or 0)
            unit.dr = unit.dr / old_dr * new_dr
            unit.mr = unit.mr / (1 - (previous.magic_reduction or 0))
                * (1 - (current.magic_reduction or 0))
        end
        applied_effects[pid] = current
        refresh_bloodline(pid)
        refresh_all_experience_rates()
    end

    ---@param pid integer
    ---@param id integer
    ---@return boolean, string?
    function Perks.allocateNode(pid, id)
        local allowed, reason = Perks.canAllocate(pid, id)
        if not allowed then return false, reason end
        set_allocated(Profile[pid], id, true)
        invalidate(pid)
        apply_effects(pid)
        notify_changed(pid)
        return true
    end

    -- Compatibility for callers that request the next named notable rank.
    function Perks.allocate(pid, key)
        for id = 2, #nodes do
            if nodes[id].rank_key == key and not Perks.hasNode(pid, id) then
                return Perks.allocateNode(pid, id)
            end
        end
        return false, "MAX RANK"
    end

    function Perks.reset(pid)
        local profile = Profile[pid]
        if not profile or Perks.getSpent(pid) == 0 then return false, "NO ALLOCATIONS" end
        if not Perks.hasReset(pid) then return false, "NO RESET AVAILABLE" end
        profile.perk_node_words = __jarray(0)
        profile.perk_ranks = __jarray(0)
        profile.perk_reset_available = 0
        invalidate(pid)
        apply_effects(pid)
        notify_changed(pid)
        return true
    end

    local function migrate_legacy_ranks(profile)
        local has_graph = false
        for word = 1, PROFILE_PERK_NODE_WORDS do
            if (words(profile)[word] or 0) ~= 0 then has_graph = true break end
        end
        if has_graph then return end

        -- Carry experimental row allocations into complete connected paths so
        -- an older profile never opens with floating, unreachable nodes.
        local migration = {
            [1] = { 2, 3, 4, 5, 6 },
            [2] = { 24, 25, 26, 27, 28 },
            [3] = { 33, 34, 35, 36, 37 },
            [4] = { 33, 34, 38, 39, 40 },
        }
        for slot, ids in pairs(migration) do
            local rank = profile.perk_ranks[slot] or 0
            if rank > 0 then
                local path_length = slot == 4 and #ids or math.min(#ids, rank + 2)
                for index = 1, path_length do set_allocated(profile, ids[index], true) end
            end
        end
        profile.perk_ranks = __jarray(0)
    end

    function Perks.reconcile(pid)
        local profile = Profile[pid]
        if not profile then return false end
        migrate_legacy_ranks(profile)
        invalidate(pid)
        -- Development point overrides are presentation/testing state and must
        -- never advance the persisted earned-budget/reset bookkeeping.
        local total = earned_total(profile)
        local previous_total = profile.perk_budget_seen or 0
        if total > previous_total then profile.perk_reset_available = 1 end
        profile.perk_budget_seen = total
        for id = 2, #nodes do
            local node = nodes[id]
            if profile_has_node(profile, id) and not profile_has_node(profile, node.parent)
                and not (node.alternate_parent and profile_has_node(profile, node.alternate_parent)) then
                profile.perk_node_words = __jarray(0)
                profile.perk_ranks = __jarray(0)
                profile.perk_reset_available = 1
                invalidate(pid)
                DisplayTextToPlayer(Player(pid - 1), 0., 0.,
                    "Your Perk points were refunded because the prerequisite paths changed.")
                apply_effects(pid)
                notify_changed(pid)
                return true
            end
        end
        if not dev_point_total[pid] and Perks.getSpent(pid) > total then
            profile.perk_node_words = __jarray(0)
            profile.perk_ranks = __jarray(0)
            invalidate(pid)
            DisplayTextToPlayer(Player(pid - 1), 0., 0.,
                "Your Perk allocations were reset because your available point total decreased.")
            apply_effects(pid)
            notify_changed(pid)
            return true
        end
        apply_effects(pid)
        notify_changed(pid)
        return false
    end

    function Perks.completeMilestone(pid, key)
        local bit = milestone_bits[key]
        local profile = Profile[pid]
        local hero_data = profile and profile.hero
        if not bit or not hero_data then return false end
        local mask = hero_data.perk_milestones or 0
        if (mask & bit) ~= 0 then return false end
        hero_data.perk_milestones = mask | bit
        local earned = (hero_data.hardcore or 0) > 0 and HARDCORE_POINTS or SOFTCORE_POINTS
        Perks.reconcile(pid)
        DisplayTextToPlayer(Player(pid - 1), 0., 0.,
            "|cffffcc00Perk milestone complete!|r Earned " .. earned
                .. " Perk Points. (" .. Perks.getAvailable(pid) .. "/"
                .. Perks.getTotal(pid) .. " available)")
        return true
    end

    function Perks.hasEligibleActiveOwner(key, min_level, max_level)
        local user = User.first
        while user do
            local profile, hero = Profile[user.id], Hero[user.id]
            local level = hero and GetHeroLevel(hero) or 0
            if profile and profile.playing and hero and UnitAlive(hero)
                and Perks.getRank(user.id, key) > 0
                and (not min_level or level >= min_level)
                and (not max_level or level <= max_level) then return true end
            user = user.next
        end
        return false
    end

    function Perks.registerChangedAction(action)
        changed_actions[#changed_actions + 1] = action
    end

    local function on_new_character(pid, hero_data)
        local inheritance = aggregate(pid).inheritance or 0
        hero_data.level = math.min(MAX_LEVEL, hero_data.level + 5 * inheritance)
        hero_data.gold = math.min(10000000, hero_data.gold + 25000 * inheritance)
    end

    local function on_stat_changed(unit)
        refresh_bloodline(GetPlayerId(GetOwningPlayer(unit)) + 1)
    end

    local function on_setup(pid)
        if Hero[pid] then EVENT_STAT_CHANGE:register_unit_action(Hero[pid], on_stat_changed) end
        applied_effects[pid] = nil
        apply_effects(pid)
    end

    local function on_cleanup(pid)
        if Hero[pid] then CooldownAcceleration.setPermanent(Hero[pid], 0.) end
        applied_effects[pid] = nil
        bloodline_applied[pid] = 0
        bloodline_stat[pid] = nil
        refreshing_bloodline[pid] = nil
        refresh_all_experience_rates()
    end

    Progression.setSharedXPBonusProvider(Perks.getSharedXPBonus)
    Profile.registerNewCharacterAction(on_new_character)
    Profile.registerStorageChangedAction(Perks.reconcile)
    for pid = 1, PLAYER_CAP do
        EVENT_ON_SETUP:register_action(pid, on_setup)
        EVENT_ON_CLEANUP:register_action(pid, on_cleanup)
    end
end, Debug and Debug.getLine())
