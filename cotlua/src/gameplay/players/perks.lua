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
    local ICON_REGEN = "ReplaceableTextures\\CommandButtons\\BTNHealingRays1.blp"
    local ICON_MOVEMENT = "ReplaceableTextures\\CommandButtons\\BTNAdventure Road.blp"
    local ICON_GOLD = "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp"
    local ICON_EXPERIENCE = "ReplaceableTextures\\CommandButtons\\BTNblueBook.blp"
    local ICON_MASTERY = "ReplaceableTextures\\CommandButtons\\BTNManual3.blp"
    local ICON_INHERITANCE = "ReplaceableTextures\\CommandButtons\\BTNTreasureChest.blp"
    local ICON_QUEST = "ReplaceableTextures\\CommandButtons\\BTNImprovedBows.blp"

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

    local nodes = {}
    local nodes_by_key = {}
    local function add(id, key, name, x, y, parent, effect, value, description, icon, flags)
        local node = {
            id = id, key = key, name = name, x = x, y = y, parent = parent,
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

    add(1, "root", "Legacy", 0, 0, nil, nil, nil,
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
    add(10, "arcane_spark", "Arcane Spark", 3, -1, 4, "spellboost", .01, "Gain |cffffcc001%|r Spellboost.", ICON_SPELL)
    add(11, "potency", "Potency", 4, -1.35, 10, "spellboost", .02, "Gain |cffffcc002%|r Spellboost.", ICON_SPELL)
    add(12, "overwhelming_magic", "Overwhelming Magic", 5, -1.55, 11, "spellboost", .03, "Gain |cffffcc003%|r Spellboost.", ICON_SPELL, { notable = true })

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
    add(26, "fellowship_1", "Fellowship I", 0, 3, 25, "shared_xp", .05,
        "All eligible players gain |cffffcc005%|r experience. Only the strongest active Fellowship applies.", ICON_EXPERIENCE, { notable = true, rank_key = "fellowship" })
    add(27, "fellowship_2", "Fellowship II", 0, 4, 26, "shared_xp", .05,
        "All eligible players gain another |cffffcc005%|r experience.", ICON_EXPERIENCE, { notable = true, rank_key = "fellowship" })
    add(28, "fellowship_3", "Fellowship III", 0, 5, 27, "shared_xp", .05,
        "All eligible players gain another |cffffcc005%|r experience.", ICON_EXPERIENCE, { keystone = true, rank_key = "fellowship" })
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
    add(43, "quick_study", "Quick Study", 1, -4, 36, "shared_xp", .02, "All eligible players gain |cffffcc002%|r experience.", ICON_EXPERIENCE)
    add(44, "mentorship", "Mentorship", 2, -4.5, 43, "shared_xp", .03, "All eligible players gain |cffffcc003%|r experience.", ICON_EXPERIENCE, { notable = true })
    add(45, "heirloom", "Heirloom", 3, -3.5, 42, "gold_rate", 5, "Gain |cffffcc005%|r Gold Find.", ICON_GOLD, { notable = true, alternate_parent = 44 })

    local summaries = {
        { key = "bloodline", name = "Mastery", max_rank = 3 },
        { key = "fellowship", name = "Fellowship", max_rank = 3 },
        { key = "inheritance", name = "Inheritance", max_rank = 3 },
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
        bonus_cache[pid] = result
        return result
    end

    local function invalidate(pid)
        bonus_cache[pid] = nil
    end

    ---@return PerkNode[]
    function Perks.getNodes() return nodes end

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
        local strongest = 0
        local user = User.first
        while user do
            local profile = Profile[user.id]
            if profile and profile.playing then
                strongest = math.max(strongest, aggregate(user.id).shared_xp or 0)
            end
            user = user.next
        end
        return strongest
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
            unit.cc_flat = unit.cc_flat
                + (current.crit_chance or 0) - (previous.crit_chance or 0)
            unit.cd_flat = unit.cd_flat
                + (current.crit_damage or 0) - (previous.crit_damage or 0)
            unit.ms_flat = unit.ms_flat
                + (current.movespeed or 0) - (previous.movespeed or 0)
            unit.gold_rate = unit.gold_rate
                + (current.gold_rate or 0) - (previous.gold_rate or 0)

            local old_armor = 1 + (previous.armor_percent or 0)
            local new_armor = 1 + (current.armor_percent or 0)
            unit.armor_percent = unit.armor_percent / old_armor * new_armor
            local old_regen = 1 + (previous.regen_percent or 0)
            local new_regen = 1 + (current.regen_percent or 0)
            unit.regen_percent = unit.regen_percent / old_regen * new_regen
            local old_dr = 1 - (previous.damage_reduction or 0)
            local new_dr = 1 - (current.damage_reduction or 0)
            unit.dr = unit.dr / old_dr * new_dr
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
