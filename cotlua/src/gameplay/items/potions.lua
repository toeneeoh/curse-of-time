-- Refillable potion use, infusion metadata, and synchronized cooldown state.
OnInit.final("PotionService", function(Require)
    Require('BuffsItems')
    Require('CooldownAcceleration')
    Require('Events')
    Require('ItemEventRegistry')
    Require('Items')
    Require('Profile')
    Require('ResourceChanges')
    Require('RuntimeItemDefinitions')
    Require('TimerQueue')

    PotionService = {}

    local TQ = TimerQueue
    local DEFAULT_USE_COOLDOWN = 3.
    local VAMPIRIC_DURATION = 12.
    local VAMPIRIC_LEECH = 0.05
    local INFUSION_NONE = 0
    local INFUSION_VAMPIRIC = 1
    local INFUSION_STONE = 2
    local INFUSION_TEMPEST = 3
    local CATALYST_NONE = 0
    local CATALYST_POTENT = 1
    local CATALYST_LINGERING = 2
    local CATALYST_ACCELERANT = 3
    -- Potion definitions currently roll at most five properties. The final two
    -- six-bit quality slots are therefore stable, already-saved customization
    -- storage that does not compete with logical identity or item charges.
    local INFUSION_QUALITY_INDEX = 6
    local CATALYST_QUALITY_INDEX = 7
    local GREATER_HEALTH_ID = 2
    local GREATER_MANA_ID = 3
    local SUPERIOR_HEALTH_ID = 4
    local SUPERIOR_MANA_ID = 5
    local GRAND_HEALTH_ID = 6
    local GRAND_MANA_ID = 7
    local STONEBLOOD_ID = 8
    local TEMPEST_ID = 9
    local HUNTERS_ID = 10
    local BLOOD_FLASK_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNPotionOfVampirism.blp"
    local HEALTH_FLASK_ID = FourCC('I02F')
    local MANA_FLASK_ID = FourCC('I00E')
    local BASE_FLASK_CHARGES = 3
    local BLOOD_FLASK_KEY = "blood_flask"
    local GREATER_HEALTH_KEY = "greater_health_flask"
    local GREATER_MANA_KEY = "greater_mana_flask"
    local SUPERIOR_HEALTH_KEY = "superior_health_flask"
    local SUPERIOR_MANA_KEY = "superior_mana_flask"
    local GRAND_HEALTH_KEY = "grand_health_flask"
    local GRAND_MANA_KEY = "grand_mana_flask"
    local STONEBLOOD_KEY = "stoneblood_flask"
    local TEMPEST_KEY = "tempest_flask"
    local HUNTERS_KEY = "hunters_flask"
    local cooldowns = {}
    local infusions = {}
    local catalysts = {}

    PotionService.INFUSION_NONE = INFUSION_NONE
    PotionService.INFUSION_VAMPIRIC = INFUSION_VAMPIRIC
    PotionService.INFUSION_STONE = INFUSION_STONE
    PotionService.INFUSION_TEMPEST = INFUSION_TEMPEST
    PotionService.CATALYST_NONE = CATALYST_NONE
    PotionService.CATALYST_POTENT = CATALYST_POTENT
    PotionService.CATALYST_LINGERING = CATALYST_LINGERING
    PotionService.CATALYST_ACCELERANT = CATALYST_ACCELERANT
    -- Compatibility names for callers written against the first prototype.
    -- Player-facing brewing now treats these as prefix and suffix pools.
    PotionService.PREFIX_NONE = INFUSION_NONE
    PotionService.PREFIX_VAMPIRIC = INFUSION_VAMPIRIC
    PotionService.PREFIX_STONE = INFUSION_STONE
    PotionService.PREFIX_TEMPEST = INFUSION_TEMPEST
    PotionService.SUFFIX_NONE = CATALYST_NONE
    PotionService.DEFAULT_USE_COOLDOWN = DEFAULT_USE_COOLDOWN
    PotionService.GREATER_HEALTH_KEY = GREATER_HEALTH_KEY
    PotionService.GREATER_MANA_KEY = GREATER_MANA_KEY
    PotionService.SUPERIOR_HEALTH_KEY = SUPERIOR_HEALTH_KEY
    PotionService.SUPERIOR_MANA_KEY = SUPERIOR_MANA_KEY
    PotionService.GRAND_HEALTH_KEY = GRAND_HEALTH_KEY
    PotionService.GRAND_MANA_KEY = GRAND_MANA_KEY
    PotionService.STONEBLOOD_KEY = STONEBLOOD_KEY
    PotionService.TEMPEST_KEY = TEMPEST_KEY
    PotionService.HUNTERS_KEY = HUNTERS_KEY
    PotionService.ROLLABLE_STATS = {
        ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL, ITEM_FLAT_MANA, ITEM_PERCENT_MANA,
        ITEM_CHARGES
    }

    ---@class PotionCustomizationEffect
    ---@field id integer
    ---@field key string
    ---@field name string
    ---@field description string
    ---@field icon string
    ---@field on_use? fun(context: PotionUseContext)
    ---@field potency_multiplier? number
    ---@field duration_multiplier? number
    ---@field cooldown_multiplier? number

    local function register_customization(registry, definition)
        if type(definition) ~= "table" or type(definition.id) ~= "number" or
            definition.id <= 0 or definition.id > 63 or
            registry[definition.id] then return false end
        registry[definition.id] = definition
        return true
    end

    ---@param definition PotionCustomizationEffect
    ---@return boolean
    function PotionService.registerInfusion(definition)
        return register_customization(infusions, definition)
    end

    ---@param definition PotionCustomizationEffect
    ---@return boolean
    function PotionService.registerCatalyst(definition)
        return register_customization(catalysts, definition)
    end

    ---@return PotionCustomizationEffect[]
    function PotionService.getInfusions() return infusions end

    ---@return PotionCustomizationEffect[]
    function PotionService.getCatalysts() return catalysts end

    function PotionService.getPrefixes() return infusions end

    function PotionService.getSuffixes() return catalysts end

    ---@class PotionBehavior
    ---@field cooldown? number|fun(item: Item): number
    ---@field replaces_restoration? boolean Suppress formula healing and mana.
    ---@field inherent_infusion? integer
    ---@field initial_prefix? integer
    ---@field affix_capacity? integer
    ---@field suffix_roll_chance? number
    ---@field on_use? fun(context: PotionUseContext)

    ---@class PotionUseContext
    ---@field pid integer
    ---@field item Item
    ---@field hero unit
    ---@field unit UnitTable
    ---@field potency_multiplier number
    ---@field duration_multiplier number

    ---Defines a logical potion while keeping gameplay behavior out of the
    ---generic runtime-item catalog. Ordinary restoration remains driven by
    ---the standard fheal/pheal/fmana/pmana/charges formula tags.
    ---@param key string
    ---@param spec RuntimeLogicalItemSpec
    ---@param behavior PotionBehavior?
    ---@return RuntimeLogicalItemDefinition?
    function PotionService.define(key, spec, behavior)
        spec.item_type = TYPE_POTION_INDEX
        if not spec.world_skin then
            local carrier = type(spec.carrier) == "string" and
                                FourCC(spec.carrier) or spec.carrier
            spec.world_skin = carrier == MANA_FLASK_ID and FourCC('pman') or
                                  FourCC('phea')
        end
        spec.metadata = spec.metadata or {}
        spec.metadata.potion = behavior or {}
        return RuntimeItemDefinitions.define(key, spec)
    end

    ---@param key string
    ---@param x number?
    ---@param y number?
    ---@param expire number?
    ---@param roll_optional_affixes boolean? Defaults to true; previews disable it.
    ---@return Item?
    function PotionService.create(key, x, y, expire, roll_optional_affixes)
        local item = RuntimeItemDefinitions.create(key, x, y, expire)
        if not item then return nil end
        local behavior = item.runtime_definition.metadata.potion
        if behavior.initial_prefix and item.quality[INFUSION_QUALITY_INDEX] == 0 then
            item.quality[INFUSION_QUALITY_INDEX] = behavior.initial_prefix
        end
        if item.data[ITEM_LEVEL_REQUIREMENT] >= 200 and
            item.quality[5] == 0 then
            item.quality[5] = GetRandomInt(1, 63)
        end
        if roll_optional_affixes ~= false and behavior.suffix_roll_chance and
            item.quality[CATALYST_QUALITY_INDEX] == 0 and
            GetRandomReal(0., 1.) <= behavior.suffix_roll_chance then
            item.quality[CATALYST_QUALITY_INDEX] = GetRandomInt(
                                                       CATALYST_POTENT,
                                                       CATALYST_ACCELERANT)
        end
        PotionService.refreshItem(item)
        return item
    end

    ---Builds the same name, icon, and generated tooltip shown by an inventory
    ---instance for use by catalogs that sell logical potions.
    ---@param key string
    ---@return string? name
    ---@return string? icon
    ---@return string? description
    function PotionService.getCatalogPresentation(key)
        local item = PotionService.create(key, 30000., 30000., nil, false)
        if not item then return nil end
        local name, icon, description = PotionService.describe(item)
        item:destroy()
        return name, icon, description
    end

    ---Applies a non-stacking, temporary cooldown-acceleration effect. The
    ---potion use cooldown is tracked separately and is never accelerated.
    ---@param context PotionUseContext
    ---@param rate number Additional cooldown seconds recovered per second.
    ---@param duration number
    ---@return boolean
    function PotionService.accelerateCooldowns(context, rate, duration)
        return CooldownAcceleration.apply(context.hero, rate, duration)
    end

    local inherited_potion_stats = {
        ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL, ITEM_FLAT_MANA, ITEM_PERCENT_MANA,
        ITEM_CHARGES, ITEM_RARITY, ITEM_LIMIT, ITEM_NOCRAFT
    }

    local prechaos_tiers = {
        {
            level = 50,
            item_tier = 2,
            health_key = GREATER_HEALTH_KEY,
            mana_key = GREATER_MANA_KEY,
            flat_min = 750,
            flat_max = 1250,
            percent_min = 8,
            percent_max = 12,
            charge_min = 0,
            charge_max = 1
        }, {
            level = 110,
            item_tier = 2,
            health_key = SUPERIOR_HEALTH_KEY,
            mana_key = SUPERIOR_MANA_KEY,
            flat_min = 3000,
            flat_max = 5000,
            percent_min = 14,
            percent_max = 18,
            charge_min = 1,
            charge_max = 2
        }, {
            level = 170,
            item_tier = 2,
            health_key = GRAND_HEALTH_KEY,
            mana_key = GRAND_MANA_KEY,
            flat_min = 8000,
            flat_max = 12000,
            percent_min = 20,
            percent_max = 25,
            charge_min = 2,
            charge_max = 3
        }
    }

    PotionService.PRECHAOS_TIERS = prechaos_tiers

    ---Returns the health or mana flask appropriate for a pre-chaos enemy.
    ---The lower bound is inclusive; level 200 begins the chaos item economy.
    ---@param level integer
    ---@return string?
    function PotionService.getPrechaosDropKey(level)
        local tier
        for index = #prechaos_tiers, 1, -1 do
            if level >= prechaos_tiers[index].level then
                tier = prechaos_tiers[index]
                break
            end
        end

        if not tier or level >= 200 then return nil end
        return GetRandomInt(0, 1) == 0 and tier.health_key or tier.mana_key
    end

    local function prepare_prechaos_flask(tier, flat_stat, percent_stat)
        return function(data, carrier_data)
            data[ITEM_TIER] = tier.item_tier
            data[ITEM_LEVEL_REQUIREMENT] = tier.level
            data[flat_stat] = tier.flat_min
            data[flat_stat .. "range"] = tier.flat_max
            data[flat_stat .. "fixed"] = 1
            data[percent_stat] = tier.percent_min
            data[percent_stat .. "range"] = tier.percent_max
            data[percent_stat .. "fixed"] = 1

            -- Both basic refillable flasks currently carry three charges.
            -- Keep a concrete fallback here so a presentation-only carrier or
            -- an object-data regression can never create an unusable flask.
            local charges = carrier_data[ITEM_CHARGES]
            if charges <= 0 then charges = BASE_FLASK_CHARGES end
            data[ITEM_CHARGES] = charges + tier.charge_min
            data[ITEM_CHARGES .. "range"] = charges + tier.charge_max
            data[ITEM_CHARGES .. "fixed"] = 1
        end
    end

    local function define_prechaos_flask(key, id, carrier, name, tier,
                                         flat_stat, percent_stat)
        PotionService.define(key, {
            id = id,
            carrier = carrier,
            name = name,
            icon = BlzGetAbilityIcon(carrier),
            tooltip = "A refillable flask found throughout the pre-chaos world.",
            inherit_stats = inherited_potion_stats,
            prepare_data = prepare_prechaos_flask(tier, flat_stat, percent_stat)
        })
    end

    define_prechaos_flask(GREATER_HEALTH_KEY, GREATER_HEALTH_ID,
                          HEALTH_FLASK_ID, "Greater Health Flask",
                          prechaos_tiers[1], ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL)
    define_prechaos_flask(GREATER_MANA_KEY, GREATER_MANA_ID, MANA_FLASK_ID,
                          "Greater Mana Flask", prechaos_tiers[1],
                          ITEM_FLAT_MANA, ITEM_PERCENT_MANA)
    define_prechaos_flask(SUPERIOR_HEALTH_KEY, SUPERIOR_HEALTH_ID,
                          HEALTH_FLASK_ID, "Superior Health Flask",
                          prechaos_tiers[2], ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL)
    define_prechaos_flask(SUPERIOR_MANA_KEY, SUPERIOR_MANA_ID, MANA_FLASK_ID,
                          "Superior Mana Flask", prechaos_tiers[2],
                          ITEM_FLAT_MANA, ITEM_PERCENT_MANA)
    define_prechaos_flask(GRAND_HEALTH_KEY, GRAND_HEALTH_ID, HEALTH_FLASK_ID,
                          "Grand Health Flask", prechaos_tiers[3],
                          ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL)
    define_prechaos_flask(GRAND_MANA_KEY, GRAND_MANA_ID, MANA_FLASK_ID,
                          "Grand Mana Flask", prechaos_tiers[3], ITEM_FLAT_MANA,
                          ITEM_PERCENT_MANA)

    local function prepare_chaos_flask(flat_health, percent_health, flat_mana,
                                       percent_mana)
        return function(data, carrier_data)
            data[ITEM_TIER] = 12
            data[ITEM_LEVEL_REQUIREMENT] = 200
            local function restoration(stat, maximum)
                if maximum <= 0 then return end
                data[stat] = math.max(1, math.floor(maximum * 0.5))
                data[stat .. "range"] = maximum
                data[stat .. "fixed"] = 1
            end
            restoration(ITEM_FLAT_HEAL, flat_health)
            restoration(ITEM_PERCENT_HEAL, percent_health)
            restoration(ITEM_FLAT_MANA, flat_mana)
            restoration(ITEM_PERCENT_MANA, percent_mana)
            data[ITEM_CHARGES] = math.max(6, carrier_data[ITEM_CHARGES])
            data[ITEM_CHARGES .. "fixed"] = 1
        end
    end

    local chaos_inherited_stats = {
        ITEM_RARITY, ITEM_LIMIT, ITEM_NOCRAFT
    }

    local function apply_vampiric_effect(context, leech, duration)
        local buff = VampiricPotion:add(context.hero, context.hero)
        buff.leech = leech * context.potency_multiplier
        buff:duration(duration * context.duration_multiplier)
        UnitRefreshBuff(context.hero, buff)
    end

    local function apply_stone_effect(context, reduction, duration)
        local buff = StonebloodFlaskBuff:add(context.hero, context.hero)
        local previous = buff.dr or 1.
        local multiplier = math.max(0.01, 1. - reduction *
                                        context.potency_multiplier)
        if previous ~= multiplier then
            context.unit.dr = context.unit.dr / previous * multiplier
            buff.dr = multiplier
        end
        buff:duration(duration * context.duration_multiplier)
        UnitRefreshBuff(context.hero, buff)
    end

    local function apply_tempest_effect(context, rate, duration)
        local adjusted_rate = rate * context.potency_multiplier
        local buff = TempestFlaskBuff:add(context.hero, context.hero)
        buff.rate = adjusted_rate
        PotionService.accelerateCooldowns(context, adjusted_rate,
                                          duration *
                                              context.duration_multiplier)
        buff:duration(duration * context.duration_multiplier)
        UnitRefreshBuff(context.hero, buff)
    end

    PotionService.define(STONEBLOOD_KEY, {
        id = STONEBLOOD_ID,
        carrier = HEALTH_FLASK_ID,
        name = "Stoneblood Flask",
        icon = "ReplaceableTextures\\CommandButtons\\BTNStone.blp",
        tooltip = "A legendary Cave Voyagers flask with room for a prefix " ..
            "and suffix.",
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(15000, 30, 0, 0)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        initial_prefix = INFUSION_STONE,
        affix_capacity = 2,
        suffix_roll_chance = 0.25
    })

    PotionService.define(TEMPEST_KEY, {
        id = TEMPEST_ID,
        carrier = MANA_FLASK_ID,
        name = "Tempest Flask",
        icon = "ReplaceableTextures\\CommandButtons\\BTNMonsoon.blp",
        tooltip = "A legendary Stormwatch flask with room for a prefix " ..
            "and suffix.",
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(0, 0, 15000, 30)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        initial_prefix = INFUSION_TEMPEST,
        affix_capacity = 2,
        suffix_roll_chance = 0.25
    })

    PotionService.define(HUNTERS_KEY, {
        id = HUNTERS_ID,
        carrier = HEALTH_FLASK_ID,
        name = "Hunter's Flask",
        icon = BLOOD_FLASK_ICON,
        tooltip = "A legendary Ashen Vanguard flask with room for a prefix " ..
            "and suffix.",
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(7500, 15, 7500, 15)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        initial_prefix = INFUSION_VAMPIRIC,
        affix_capacity = 2,
        suffix_roll_chance = 0.25
    })

    PotionService.define(BLOOD_FLASK_KEY, {
        id = INFUSION_VAMPIRIC,
        carrier = MANA_FLASK_ID,
        name = "Blood Flask",
        icon = BLOOD_FLASK_ICON,
        tooltip = "|cff0080c0Vampirism:|r Restores |cffffcc005%|r of " ..
            "damage dealt as Health for |cffffcc0012 seconds|r.",
        inherit_stats = {
            ITEM_CHARGES, ITEM_TIER, ITEM_RARITY, ITEM_LEVEL_REQUIREMENT,
            ITEM_LIMIT, ITEM_NOCRAFT
        }
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        replaces_restoration = true,
        inherent_infusion = INFUSION_VAMPIRIC,
        on_use = function(context)
            apply_vampiric_effect(context, VAMPIRIC_LEECH,
                                   VAMPIRIC_DURATION)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_VAMPIRIC,
        key = "vampiric",
        name = "Vampiric Infusion",
        icon = BLOOD_FLASK_ICON,
        description = "Restores |cffffcc008%|r of damage dealt as Health " ..
            "for |cffffcc0012 seconds|r.",
        on_use = function(context)
            apply_vampiric_effect(context, 0.08, 12.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_STONE,
        key = "stone",
        name = "Stone Infusion",
        icon = "ReplaceableTextures\\CommandButtons\\BTNStone.blp",
        description = "Reduces damage taken by |cffffcc0015%|r for " ..
            "|cffffcc0012 seconds|r.",
        on_use = function(context)
            apply_stone_effect(context, 0.15, 12.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_TEMPEST,
        key = "tempest",
        name = "Tempest Infusion",
        icon = "ReplaceableTextures\\CommandButtons\\BTNMonsoon.blp",
        description = "Ability cooldowns recover |cffffcc00100%|r faster " ..
            "for |cffffcc008 seconds|r.",
        on_use = function(context)
            apply_tempest_effect(context, 1., 8.)
        end
    })

    PotionService.registerCatalyst({
        id = CATALYST_POTENT,
        key = "potent",
        name = "Potent Catalyst",
        icon = "ReplaceableTextures\\CommandButtons\\BTNStrongDrink.blp",
        description = "Infusion effects are |cffffcc0025%|r stronger.",
        potency_multiplier = 1.25
    })

    PotionService.registerCatalyst({
        id = CATALYST_LINGERING,
        key = "lingering",
        name = "Lingering Catalyst",
        icon = "ReplaceableTextures\\CommandButtons\\BTNCloudOfFog.blp",
        description = "Infusion effects last |cffffcc0050%|r longer.",
        duration_multiplier = 1.50
    })

    PotionService.registerCatalyst({
        id = CATALYST_ACCELERANT,
        key = "accelerant",
        name = "Accelerant Catalyst",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBootsOfSpeed.blp",
        description = "Potion cooldown is |cffffcc0033%|r shorter, but " ..
            "infusion effects last |cffffcc0025%|r less time.",
        cooldown_multiplier = 2. / 3.,
        duration_multiplier = 0.75
    })

    local function potion_at(pid, index)
        local profile = Profile[pid]
        return profile and profile.hero and
                   profile.hero.items[POTION_INDEX + index - 1] or nil
    end

    ---@param pid integer
    ---@param index integer
    ---@return Item?
    function PotionService.getEquipped(pid, index)
        if index ~= 1 and index ~= 2 then return nil end
        return potion_at(pid, index)
    end

    local function cooldown_table(pid)
        cooldowns[pid] = cooldowns[pid] or {}
        return cooldowns[pid]
    end

    local function clear_cooldown(pid, index)
        local player_cooldowns = cooldowns[pid]
        if player_cooldowns then player_cooldowns[index] = nil end
    end

    ---Returns presentation data for a potion without giving UI ownership of
    ---its gameplay behavior.
    ---@param item Item
    ---@return string name
    ---@return string icon
    ---@return string description
    function PotionService.describe(item)
        -- Potion buttons mirror the ordinary inventory-slot presentation.
        -- Item:info() is the detailed inspection view and appends bookkeeping
        -- such as current charges, saveability, sale value, and sockets.
        PotionService.refreshItem(item)
        return GetItemName(item.obj), BlzGetItemIconPath(item.obj),
               item.tooltip or BlzGetItemDescription(item.obj)
    end

    local function selected_customization(item, registry, quality_index)
        local id = item and item.quality and item.quality[quality_index] or 0
        return registry[id], id
    end

    local function append_customization(item, definition)
        if not definition then return end
        local line = "|n|cff0080c0" .. definition.name .. ":|r " ..
                         definition.description
        item.tooltip = (item.tooltip or "") .. line
        item.alt_tooltip = (item.alt_tooltip or "") .. line
    end

    local function affix_capacity(item)
        local behavior = item and item.runtime_definition and
                             item.runtime_definition.metadata.potion
        return behavior and behavior.affix_capacity or 0
    end

    local function occupied_affixes(item)
        local count = 0
        if selected_customization(item, infusions, INFUSION_QUALITY_INDEX) then
            count = count + 1
        end
        if selected_customization(item, catalysts, CATALYST_QUALITY_INDEX) then
            count = count + 1
        end
        return count
    end

    local function restoration_multiplier(item)
        local count = occupied_affixes(item)
        if count >= 2 then return 0.40 end
        if count == 1 then return 0.70 end
        return 1.
    end

    ---Applies the item's dynamic presentation to its backing native handle.
    ---@param item Item
    function PotionService.refreshItem(item)
        if not item or not item.alive or item.type ~= TYPE_POTION_INDEX then
            return
        end
        local behavior = item.runtime_definition and
                             item.runtime_definition.metadata.potion
        if behavior and behavior.initial_prefix and
            item.quality[INFUSION_QUALITY_INDEX] == 0 then
            -- Migrates faction flasks saved before affixes became transferable.
            item.quality[INFUSION_QUALITY_INDEX] = behavior.initial_prefix
        end
        item:update(true)
        local infusion = selected_customization(item, infusions,
                                                INFUSION_QUALITY_INDEX)
        local catalyst = selected_customization(item, catalysts,
                                                CATALYST_QUALITY_INDEX)
        append_customization(item, infusion)
        append_customization(item, catalyst)
        local multiplier = restoration_multiplier(item)
        if multiplier < 1. then
            local line = "|n|cff808080Restoration Effectiveness:|r " ..
                             math.floor(multiplier * 100) .. "%"
            item.tooltip = (item.tooltip or "") .. line
            item.alt_tooltip = (item.alt_tooltip or "") .. line
        end
        BlzSetItemDescription(item.obj, item.tooltip)
        BlzSetItemExtendedTooltip(item.obj, item.tooltip)
    end

    ---@param item Item
    ---@param infusion integer
    function PotionService.setInfusion(item, infusion)
        if not item or item.type ~= TYPE_POTION_INDEX then return false end
        if infusion ~= INFUSION_NONE and not infusions[infusion] then
            return false
        end

        -- Preserve the original Vampire conversion for the basic mana flask.
        -- Logical flasks keep their base definition and use the saved infusion
        -- slot, which is what makes brewing composable.
        if not item.runtime_definition and item.id == MANA_FLASK_ID and
            infusion == INFUSION_VAMPIRIC then
            return RuntimeItemDefinitions.apply(item, BLOOD_FLASK_KEY, false)
        end
        if RuntimeItemDefinitions.is(item, BLOOD_FLASK_KEY) and
            infusion == INFUSION_NONE and
            item.quality[INFUSION_QUALITY_INDEX] == INFUSION_NONE then
            RuntimeItemDefinitions.clear(item)
            PotionService.refreshItem(item)
            if item.pid then NotifyItemChanged(item.pid) end
            return true
        end

        local behavior = item.runtime_definition and
                             item.runtime_definition.metadata and
                             item.runtime_definition.metadata.potion or nil
        if behavior and behavior.inherent_infusion == infusion and
            infusion ~= INFUSION_NONE then return false end

        local changed = item.quality[INFUSION_QUALITY_INDEX] ~= infusion
        item.quality[INFUSION_QUALITY_INDEX] = infusion
        PotionService.refreshItem(item)
        if item.pid then NotifyItemChanged(item.pid) end
        return changed
    end

    ---@param item Item
    ---@param catalyst integer
    ---@return boolean
    function PotionService.setCatalyst(item, catalyst)
        if not item or item.type ~= TYPE_POTION_INDEX or
            (catalyst ~= CATALYST_NONE and not catalysts[catalyst]) then
            return false
        end
        local changed = item.quality[CATALYST_QUALITY_INDEX] ~= catalyst
        item.quality[CATALYST_QUALITY_INDEX] = catalyst
        PotionService.refreshItem(item)
        if item.pid then NotifyItemChanged(item.pid) end
        return changed
    end

    ---@param item Item
    ---@return table?
    function PotionService.getCustomization(item)
        if not item or item.type ~= TYPE_POTION_INDEX then return nil end
        local infusion, infusion_id = selected_customization(
                                            item, infusions,
                                            INFUSION_QUALITY_INDEX)
        local catalyst, catalyst_id = selected_customization(
                                            item, catalysts,
                                            CATALYST_QUALITY_INDEX)
        return {
            infusion_id = infusion and infusion_id or INFUSION_NONE,
            infusion = infusion,
            catalyst_id = catalyst and catalyst_id or CATALYST_NONE,
            catalyst = catalyst,
            prefix_id = infusion and infusion_id or INFUSION_NONE,
            prefix = infusion,
            suffix_id = catalyst and catalyst_id or CATALYST_NONE,
            suffix = catalyst,
            capacity = affix_capacity(item)
        }
    end

    ---@param item Item
    ---@param infusion integer
    ---@return boolean
    ---@return string?
    function PotionService.canSetInfusion(item, infusion)
        if not item or item.type ~= TYPE_POTION_INDEX or
            (infusion ~= INFUSION_NONE and not infusions[infusion]) then
            return false, "INVALID INFUSION"
        end
        local customization = PotionService.getCustomization(item)
        if customization.infusion_id == infusion then
            return false, "ALREADY APPLIED"
        end
        if infusion ~= INFUSION_NONE then
            if customization.capacity <= 0 or
                (customization.capacity == 1 and
                    customization.suffix_id ~= CATALYST_NONE) then
                return false, "NO AFFIX SLOT"
            end
        end
        local behavior = item.runtime_definition and
                             item.runtime_definition.metadata and
                             item.runtime_definition.metadata.potion
        if behavior and behavior.inherent_infusion == infusion and
            infusion ~= INFUSION_NONE then
            return false, "INHERENT"
        end
        return true
    end

    ---@param item Item
    ---@param catalyst integer
    ---@return boolean
    ---@return string?
    function PotionService.canSetCatalyst(item, catalyst)
        if not item or item.type ~= TYPE_POTION_INDEX or
            (catalyst ~= CATALYST_NONE and not catalysts[catalyst]) then
            return false, "INVALID CATALYST"
        end
        if PotionService.getCustomization(item).catalyst_id == catalyst then
            return false, "ALREADY APPLIED"
        end
        local customization = PotionService.getCustomization(item)
        if catalyst ~= CATALYST_NONE and
            (customization.capacity <= 0 or
                (customization.capacity == 1 and
                    customization.prefix_id ~= INFUSION_NONE)) then
            return false, "NO AFFIX SLOT"
        end
        return true
    end

    PotionService.setPrefix = PotionService.setInfusion
    PotionService.setSuffix = PotionService.setCatalyst
    PotionService.canSetPrefix = PotionService.canSetInfusion
    PotionService.canSetSuffix = PotionService.canSetCatalyst

    ---@param pid integer
    ---@param index integer
    ---@return number
    function PotionService.getCooldown(pid, index)
        local callback = cooldowns[pid] and cooldowns[pid][index]
        return callback and math.max(0., TQ:getRemaining(callback) or 0.) or 0.
    end

    local function potion_behavior(item)
        local definition = item.runtime_definition
        local metadata = definition and definition.metadata or nil
        return metadata and metadata.potion or nil
    end

    ---Returns the item's use cooldown. Runtime definitions may provide either
    ---a fixed number or a resolver function for future quality-based potions.
    ---Object-editor potions use the shared default.
    ---@param item Item
    ---@return number
    function PotionService.getUseCooldown(item)
        local behavior = potion_behavior(item)
        local cooldown = behavior and behavior.cooldown or nil

        if type(cooldown) == "function" then cooldown = cooldown(item) end

        if type(cooldown) ~= "number" then
            cooldown = DEFAULT_USE_COOLDOWN
        end

        local catalyst = selected_customization(item, catalysts,
                                                CATALYST_QUALITY_INDEX)
        cooldown = cooldown *
                       (catalyst and catalyst.cooldown_multiplier or 1.)

        return math.max(0., cooldown)
    end

    ---Returns the complete potion property set used by future refinement and
    ---crafting UI without exposing cached-stat indexing to those consumers.
    ---@param item Item
    ---@return table?
    function PotionService.getProperties(item)
        if not item or not item.alive or item.type ~= TYPE_POTION_INDEX or
            not item.cached_stats then return nil end

        local stats = item.cached_stats
        local multiplier = restoration_multiplier(item)
        return {
            charges = item.charges,
            maximum_charges = stats[ITEM_CHARGES],
            level_requirement = item.data[ITEM_LEVEL_REQUIREMENT],
            flat_health = stats[ITEM_FLAT_HEAL] * multiplier,
            percent_health = stats[ITEM_PERCENT_HEAL] * multiplier,
            flat_mana = stats[ITEM_FLAT_MANA] * multiplier,
            percent_mana = stats[ITEM_PERCENT_MANA] * multiplier,
            base_flat_health = stats[ITEM_FLAT_HEAL],
            base_percent_health = stats[ITEM_PERCENT_HEAL],
            base_flat_mana = stats[ITEM_FLAT_MANA],
            base_percent_mana = stats[ITEM_PERCENT_MANA],
            restoration_multiplier = multiplier,
            cooldown = PotionService.getUseCooldown(item),
            behavior = potion_behavior(item)
        }
    end

    ---Returns the established full-refill price using the logical potion's
    ---level requirement and rolled restoration values rather than its native
    ---carrier definition.
    ---@param item Item
    ---@return integer
    function PotionService.getRefillCost(item)
        local properties = PotionService.getProperties(item)
        if not properties then return 0 end

        return math.floor(properties.level_requirement ^ 2 +
                              properties.flat_health * 0.5 +
                              properties.flat_mana * 0.5)
    end

    ---Refills one potion to its rolled maximum.
    ---@param item Item
    ---@return boolean changed
    function PotionService.refill(item)
        local properties = PotionService.getProperties(item)
        if not properties or properties.maximum_charges <= 0 then return false end

        local changed = item.charges < properties.maximum_charges
        item.charges = properties.maximum_charges
        return changed
    end

    local function refinement_index(item, stat)
        if not item or item.type ~= TYPE_POTION_INDEX then return nil end

        local allowed = false
        for _, rollable_stat in ipairs(PotionService.ROLLABLE_STATS) do
            if stat == rollable_stat then
                allowed = true
                break
            end
        end
        if not allowed then return nil end

        local data = item.data
        if data[stat .. "range"] == 0 then return nil end
        return data.quality_index[stat]
    end

    ---Returns whether a potion definition gives this property a random range.
    ---@param item Item
    ---@param stat integer
    ---@return boolean
    function PotionService.canRefine(item, stat)
        local quality_index = refinement_index(item, stat)
        return quality_index ~= nil and
                   quality_index < INFUSION_QUALITY_INDEX
    end

    ---Rerolls one eligible potion property. The brewing transaction owns
    ---currency checks and calls this only after committing its quoted cost.
    ---@param item Item
    ---@param stat integer
    ---@return boolean success
    ---@return number? old_value
    ---@return number? new_value
    function PotionService.refine(item, stat)
        local quality_index = refinement_index(item, stat)
        if not quality_index or quality_index >= INFUSION_QUALITY_INDEX then
            return false
        end

        local old_value = item.cached_stats[stat]
        item.quality[quality_index] = GetRandomInt(0, 63)
        PotionService.refreshItem(item)

        if stat == ITEM_CHARGES then
            item.charges = math.min(item.charges,
                                    item.cached_stats[ITEM_CHARGES])
        end

        if item.pid then NotifyItemChanged(item.pid) end
        return true, old_value, item.cached_stats[stat]
    end

    ---Chaos restoration is rerolled as one deterministic property group. The
    ---next result is derived only from the flask seed and committed attempt,
    ---so reloading a save cannot produce a different candidate.
    ---@param item Item
    ---@return boolean
    function PotionService.canRerollRestoration(item)
        if not item or item.type ~= TYPE_POTION_INDEX or
            item.data[ITEM_LEVEL_REQUIREMENT] < 200 or
            not item.runtime_definition then return false end
        for _, stat in ipairs({ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL,
                               ITEM_FLAT_MANA, ITEM_PERCENT_MANA}) do
            if refinement_index(item, stat) then return true end
        end
        return false
    end

    function PotionService.getRerollCount(item, kind)
        local metadata = RuntimeItemDefinitions.getMetadata(item)
        if kind == "prefix" then return (metadata >> 3) & 0x03 end
        if kind == "suffix" then return (metadata >> 5) & 0x03 end
        return metadata & 0x07
    end

    local function increment_reroll_count(item, kind)
        local metadata = RuntimeItemDefinitions.getMetadata(item)
        local shift, mask = 0, 0x07
        if kind == "prefix" then
            shift, mask = 3, 0x03
        elseif kind == "suffix" then
            shift, mask = 5, 0x03
        end
        local count = (metadata >> shift) & mask
        count = math.min(mask, count + 1)
        metadata = (metadata & ~(mask << shift)) | (count << shift)
        RuntimeItemDefinitions.setMetadata(item, metadata)
    end

    ---@param item Item
    ---@return boolean
    function PotionService.rerollRestoration(item)
        if not PotionService.canRerollRestoration(item) then return false end
        local attempt = PotionService.getRerollCount(item)
        local seed = item.quality[5]
        if seed == 0 then
            seed = ((item.runtime_definition.id * 29) % 63) + 1
            item.quality[5] = seed
        end

        local changed = false
        local roll = seed + attempt * 67
        for _, stat in ipairs({ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL,
                               ITEM_FLAT_MANA, ITEM_PERCENT_MANA}) do
            local quality_index = refinement_index(item, stat)
            if quality_index then
                roll = (roll * 37 + stat * 17 + 11) % 64
                item.quality[quality_index] = roll
                changed = true
            end
        end
        if not changed then return false end
        increment_reroll_count(item, "restoration")
        PotionService.refreshItem(item)
        if item.pid then NotifyItemChanged(item.pid) end
        return true
    end

    ---Transfers one affix from a donor. Consumption is owned by the brewing
    ---transaction so this function remains reversible until payment succeeds.
    function PotionService.canTransferAffix(target, donor, kind)
        if not target or not donor or target == donor then
            return false, "NO DONOR"
        end
        local donor_customization = PotionService.getCustomization(donor)
        if not donor_customization then return false, "NO DONOR" end
        if kind == "prefix" then
            if donor_customization.prefix_id == INFUSION_NONE then
                return false, "NO DONOR AFFIX"
            end
            return PotionService.canSetPrefix(target,
                                               donor_customization.prefix_id)
        elseif kind == "suffix" then
            if donor_customization.suffix_id == CATALYST_NONE then
                return false, "NO DONOR AFFIX"
            end
            return PotionService.canSetSuffix(target,
                                               donor_customization.suffix_id)
        end
        return false, "INVALID AFFIX"
    end

    function PotionService.transferAffix(target, donor, kind)
        local available = PotionService.canTransferAffix(target, donor, kind)
        if not available then return false end
        local donor_customization = PotionService.getCustomization(donor)
        local changed
        if kind == "prefix" then
            changed = PotionService.setPrefix(target,
                                               donor_customization.prefix_id)
        else
            changed = PotionService.setSuffix(target,
                                               donor_customization.suffix_id)
        end
        if changed then increment_reroll_count(target, kind) end
        return changed
    end

    ---Consumes one potion charge and applies its restoration and infusion.
    ---@param pid integer
    ---@param index integer Potion button index, 1 or 2.
    ---@return table result
    function PotionService.use(pid, index)
        if index ~= 1 and index ~= 2 then
            return {success = false, reason = "INVALID SLOT"}
        end

        local item = potion_at(pid, index)
        local hero = Hero[pid]
        if not item then return {success = false, reason = "NO POTION"} end
        if not hero or not UnitAlive(hero) then
            return {success = false, reason = "NO HERO"}
        end
        if item.charges <= 0 then
            return {success = false, reason = "NO CHARGES"}
        end

        local remaining = PotionService.getCooldown(pid, index)
        if remaining > 0. then
            return {success = false, reason = "COOLDOWN", cooldown = remaining}
        end

        local stats = item.cached_stats
        local restoration = restoration_multiplier(item)
        local behavior = potion_behavior(item)
        local customization = PotionService.getCustomization(item)
        local catalyst = customization and customization.catalyst or nil
        local replaces_restoration =
            behavior and behavior.replaces_restoration == true
        local heal =
            replaces_restoration and 0. or restoration *
                (stats[ITEM_FLAT_HEAL] + 0.01 *
                    stats[ITEM_PERCENT_HEAL] * Unit[hero].hp)
        local mana =
            replaces_restoration and 0. or restoration *
                (stats[ITEM_FLAT_MANA] + 0.01 *
                    stats[ITEM_PERCENT_MANA] * Unit[hero].mana)

        item.charges = item.charges - 1
        if heal > 0 then
            local name = PotionService.describe(item)
            HP(hero, hero, heal, name)
        end
        if mana > 0 then MP(hero, mana) end

        local context = {
            pid = pid,
            item = item,
            hero = hero,
            unit = Unit[hero],
            potency_multiplier = catalyst and
                catalyst.potency_multiplier or 1.,
            duration_multiplier = catalyst and
                catalyst.duration_multiplier or 1.
        }
        if behavior and behavior.on_use then
            behavior.on_use(context)
        end
        if customization and customization.infusion and
            customization.infusion.on_use and
            (not behavior or behavior.inherent_infusion ~=
                customization.infusion_id) then
            customization.infusion.on_use(context)
        end

        local use_cooldown = PotionService.getUseCooldown(item)
        local player_cooldowns = cooldown_table(pid)
        player_cooldowns[index] = TQ:callDelayed(use_cooldown, clear_cooldown,
                                                 pid, index)
        NotifyItemChanged(pid)

        return {success = true, cooldown = use_cooldown}
    end

    local function prepare_vampire_flask(pid)
        local hero = Hero[pid]
        if not hero or GetUnitTypeId(hero) ~= HERO_VAMPIRE then return end

        local second = potion_at(pid, 2)
        if second and second.id == MANA_FLASK_ID and
            (second.extra[2] or INFUSION_NONE) == INFUSION_NONE and
            (second.quality[INFUSION_QUALITY_INDEX] or INFUSION_NONE) ==
                INFUSION_NONE then
            PotionService.setInfusion(second, INFUSION_VAMPIRIC)
        elseif second and second.id == MANA_FLASK_ID and
            RuntimeItemDefinitions.is(second, BLOOD_FLASK_KEY) then
            PotionService.refreshItem(second)
        end
    end

    local function on_setup(pid)
        prepare_vampire_flask(pid)
        for index = 1, 2 do
            local item = potion_at(pid, index)
            if item then PotionService.refreshItem(item) end
        end
    end

    local function on_cleanup(pid)
        local player_cooldowns = cooldowns[pid]
        if player_cooldowns then
            for index = 1, 2 do
                if player_cooldowns[index] then
                    TQ:disableCallback(player_cooldowns[index])
                end
            end
            cooldowns[pid] = nil
        end
    end

    local user = User.first
    while user do
        EVENT_ON_SETUP:register_action(user.id, on_setup)
        EVENT_ON_CLEANUP:register_action(user.id, on_cleanup)
        user = user.next
    end
end, Debug and Debug.getLine())
