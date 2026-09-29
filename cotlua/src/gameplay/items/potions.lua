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
    Require('Shield')
    Require('TimerQueue')

    PotionService = {}

    local TQ = TimerQueue
    local DEFAULT_USE_COOLDOWN = 3.
    local EQUIP_COOLDOWN = 10.
    local VAMPIRIC_DURATION = 12.
    local VAMPIRIC_LEECH = 0.05
    local INFUSION_NONE = 0
    local INFUSION_VAMPIRIC = 1
    local INFUSION_STONE = 2
    local INFUSION_TEMPEST = 3
    local INFUSION_AEGIS = 4
    local INFUSION_FURY = 5
    local INFUSION_ARCANE = 6
    local INFUSION_SWIFTNESS = 7
    local INFUSION_PURITY = 8
    local INFUSION_OMNISCIENCE = 9
    local INFUSION_FRENZY = 10
    local INFUSION_PHASING = 11
    local CATALYST_NONE = 0
    local CATALYST_POTENT = 1
    local CATALYST_LINGERING = 2
    local CATALYST_ACCELERANT = 3
    local CATALYST_BOUNTIFUL = 4
    local CATALYST_CONSERVING = 5
    local CATALYST_ECHOING = 6
    local RESTORATION_REROLL_STATE = 1
    local PREFIX_REROLL_STATE = 2
    local SUFFIX_REROLL_STATE = 3
    local REROLL_SEED_STATE = 4
    local COOLDOWN_QUALITY_STATE = 5
    local INFUSION_QUALITY_STATE = 6
    local RESTORATION_MODE_STATE = 7
    local PENDING_REROLL_STATE = 8
    local REROLL_CATEGORY_STATE = 9
    local RESTORATION_HEALTH = 1
    local RESTORATION_MANA = 2
    local RESTORATION_HYBRID = 3
    local REROLL_RESTORATION = 1
    local REROLL_CHARGES = 2
    local REROLL_COOLDOWN = 3
    local REROLL_PREFIX = 4
    local CHAOS_CHARGE_MIN = 4
    local CHAOS_CHARGE_MAX = 8
    local CHAOS_COOLDOWN_MIN = 2.5
    local CHAOS_COOLDOWN_MAX = 5
    local INFUSION_ROLL_MIN = 0.90
    local INFUSION_ROLL_MAX = 1.10
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
    local LEGENDARY_CHAOS_ID = 11
    local FIRST_DONOR_ID = 12
    local BLOOD_FLASK_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNPotionOfVampirism.blp"
    local GREATER_HEALTH_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNPotionGreen.blp"
    local GREATER_MANA_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNPotionBlue.blp"
    local TEMPEST_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNManaPotion.blp"
    local POWER_FLASK_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNredEApotionGS.blp"
    local BLUE_FLASK_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNblueEApotionGS.blp"
    local GREEN_FLASK_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNgreenEApotionGS.blp"
    local PURPLE_FLASK_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNpurpleEApotionGS.blp"
    local YELLOW_FLASK_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNyellowEApotionGS.blp"
    local EMPTY_FLASK_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNnoEApotionGS.blp"
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
    local LEGENDARY_CHAOS_KEY = "legendary_chaos_flask"
    local cooldowns = {}
    local infusions = {}
    local catalysts = {}
    local chaos_donor_keys = {}
    local chaos_prefix_donor_keys = {}
    local chaos_suffix_donor_keys = {}
    local restoration_stats = {
        ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL, ITEM_FLAT_MANA, ITEM_PERCENT_MANA
    }

    local function quality_fraction(quality)
        return math.max(0, math.min(63, quality or 0)) / 63.
    end

    local function rolled_value(minimum, maximum, quality)
        return minimum + (maximum - minimum) * quality_fraction(quality)
    end

    local function concise_number(value)
        local rounded = math.floor(value + 0.5)
        if math.abs(value - rounded) < 0.05 then return tostring(rounded) end
        return string.format("%.1f", value)
    end

    local function effect_amount(base, multiplier, maximum_multiplier)
        local minimum = concise_number(base * multiplier)
        if maximum_multiplier then
            return minimum .. "-" ..
                       concise_number(base * maximum_multiplier)
        end
        return minimum
    end

    local function affix_count(item)
        local count = 0
        if (item.quality[INFUSION_QUALITY_INDEX] or 0) ~= 0 then
            count = count + 1
        end
        if (item.quality[CATALYST_QUALITY_INDEX] or 0) ~= 0 then
            count = count + 1
        end
        return count
    end

    -- Bounty's entire purpose is restoration, so it does not pay the generic
    -- restoration penalty for occupying its own suffix slot. Other affixes,
    -- including a prefix paired with Bounty, retain their normal sacrifice.
    local function restoration_affix_count(item)
        local count = affix_count(item)
        if (item.quality[CATALYST_QUALITY_INDEX] or 0) ==
            CATALYST_BOUNTIFUL then
            count = count - 1
        end
        return math.max(0, count)
    end

    local function restoration_mode(item)
        local mode = item.persistent_state[RESTORATION_MODE_STATE]
        if mode == RESTORATION_HEALTH or mode == RESTORATION_MANA or
            mode == RESTORATION_HYBRID then return mode end
        local behavior = item.runtime_definition and
                             item.runtime_definition.metadata.potion
        mode = behavior and behavior.initial_restoration_mode
        if mode == RESTORATION_HEALTH or mode == RESTORATION_MANA or
            mode == RESTORATION_HYBRID then return mode end
        local has_health = item.data[ITEM_FLAT_HEAL .. "range"] ~= 0 or
                               item.data[ITEM_PERCENT_HEAL .. "range"] ~= 0
        local has_mana = item.data[ITEM_FLAT_MANA .. "range"] ~= 0 or
                             item.data[ITEM_PERCENT_MANA .. "range"] ~= 0
        if has_health and not has_mana then return RESTORATION_HEALTH end
        if has_mana and not has_health then return RESTORATION_MANA end
        return RESTORATION_HYBRID
    end

    local function restoration_stat_enabled(mode, stat)
        return stat == ITEM_CHARGES or mode == RESTORATION_HYBRID or
                   (mode == RESTORATION_HEALTH and
                       (stat == ITEM_FLAT_HEAL or
                           stat == ITEM_PERCENT_HEAL)) or
                   (mode == RESTORATION_MANA and
                       (stat == ITEM_FLAT_MANA or
                           stat == ITEM_PERCENT_MANA))
    end

    local function adjust_restoration_for_affixes(item)
        local count = restoration_affix_count(item)
        local catalyst_id = item.quality[CATALYST_QUALITY_INDEX] or 0
        local catalyst = catalysts[catalyst_id]
        local catalyst_multiplier = catalyst and
                                        catalyst.restoration_multiplier or 1.
        local mode = restoration_mode(item)
        if count == 0 and catalyst_multiplier == 1. and
            mode == RESTORATION_HYBRID then
            item.potion_unmodified_stats = nil
            return nil
        end
        local reduction = count >= 2 and 60 or 30
        local multiplier = (100 - reduction) * 0.01 *
                               catalyst_multiplier
        if count == 0 then multiplier = catalyst_multiplier end
        local original = {}
        for _, stat in ipairs(restoration_stats) do
            original[stat] = item.cached_stats[stat]
            local enabled = restoration_stat_enabled(mode, stat)
            local stat_multiplier = enabled and multiplier or 0.
            item.cached_stats[stat] = math.floor(
                                          item.cached_stats[stat] * stat_multiplier +
                                              0.5)
            item.cached_base[stat] = math.floor(
                                         item.cached_base[stat] * stat_multiplier +
                                             0.5)
            item.cached_lower[stat] = math.floor(
                                          item.cached_lower[stat] * stat_multiplier +
                                              0.5)
            item.cached_upper[stat] = math.floor(
                                          item.cached_upper[stat] * stat_multiplier +
                                              0.5)
        end
        item.potion_unmodified_stats = original
        local adjustments = {}
        for _, stat in ipairs(restoration_stats) do
            if original[stat] ~= 0 and multiplier < 1. then
                adjustments[stat] = math.floor((1. - multiplier) * 100. + 0.5)
            end
        end
        return adjustments
    end

    PotionService.INFUSION_NONE = INFUSION_NONE
    PotionService.INFUSION_VAMPIRIC = INFUSION_VAMPIRIC
    PotionService.INFUSION_STONE = INFUSION_STONE
    PotionService.INFUSION_TEMPEST = INFUSION_TEMPEST
    PotionService.INFUSION_AEGIS = INFUSION_AEGIS
    PotionService.INFUSION_FURY = INFUSION_FURY
    PotionService.INFUSION_ARCANE = INFUSION_ARCANE
    PotionService.INFUSION_SWIFTNESS = INFUSION_SWIFTNESS
    PotionService.INFUSION_PURITY = INFUSION_PURITY
    PotionService.INFUSION_OMNISCIENCE = INFUSION_OMNISCIENCE
    PotionService.INFUSION_FRENZY = INFUSION_FRENZY
    PotionService.INFUSION_PHASING = INFUSION_PHASING
    PotionService.CATALYST_NONE = CATALYST_NONE
    PotionService.CATALYST_POTENT = CATALYST_POTENT
    PotionService.CATALYST_LINGERING = CATALYST_LINGERING
    PotionService.CATALYST_ACCELERANT = CATALYST_ACCELERANT
    PotionService.CATALYST_BOUNTIFUL = CATALYST_BOUNTIFUL
    PotionService.CATALYST_CONSERVING = CATALYST_CONSERVING
    PotionService.CATALYST_ECHOING = CATALYST_ECHOING
    -- Compatibility names for callers written against the first prototype.
    -- Player-facing brewing now treats these as prefix and suffix pools.
    PotionService.PREFIX_NONE = INFUSION_NONE
    PotionService.PREFIX_VAMPIRIC = INFUSION_VAMPIRIC
    PotionService.PREFIX_STONE = INFUSION_STONE
    PotionService.PREFIX_TEMPEST = INFUSION_TEMPEST
    PotionService.SUFFIX_NONE = CATALYST_NONE
    PotionService.DEFAULT_USE_COOLDOWN = DEFAULT_USE_COOLDOWN
    PotionService.EQUIP_COOLDOWN = EQUIP_COOLDOWN
    PotionService.COOLDOWN_QUALITY_STATE = COOLDOWN_QUALITY_STATE
    PotionService.INFUSION_QUALITY_STATE = INFUSION_QUALITY_STATE
    PotionService.RESTORATION_MODE_STATE = RESTORATION_MODE_STATE
    PotionService.PENDING_REROLL_STATE = PENDING_REROLL_STATE
    PotionService.REROLL_CATEGORY_STATE = REROLL_CATEGORY_STATE
    PotionService.RESTORATION_HEALTH = RESTORATION_HEALTH
    PotionService.RESTORATION_MANA = RESTORATION_MANA
    PotionService.RESTORATION_HYBRID = RESTORATION_HYBRID
    PotionService.REROLL_RESTORATION = REROLL_RESTORATION
    PotionService.REROLL_CHARGES = REROLL_CHARGES
    PotionService.REROLL_COOLDOWN = REROLL_COOLDOWN
    PotionService.REROLL_PREFIX = REROLL_PREFIX
    PotionService.GREATER_HEALTH_KEY = GREATER_HEALTH_KEY
    PotionService.GREATER_MANA_KEY = GREATER_MANA_KEY
    PotionService.SUPERIOR_HEALTH_KEY = SUPERIOR_HEALTH_KEY
    PotionService.SUPERIOR_MANA_KEY = SUPERIOR_MANA_KEY
    PotionService.GRAND_HEALTH_KEY = GRAND_HEALTH_KEY
    PotionService.GRAND_MANA_KEY = GRAND_MANA_KEY
    PotionService.STONEBLOOD_KEY = STONEBLOOD_KEY
    PotionService.TEMPEST_KEY = TEMPEST_KEY
    PotionService.HUNTERS_KEY = HUNTERS_KEY
    PotionService.LEGENDARY_CHAOS_KEY = LEGENDARY_CHAOS_KEY
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
    ---@field affix_name string Name fragment used by customized flasks.
    ---@field flavor string Gray in-world flavor text used by donor flasks.
    ---@field on_use? fun(context: PotionUseContext)
    ---@field potency_multiplier? number
    ---@field duration_multiplier? number
    ---@field cooldown_multiplier? number
    ---@field restoration_multiplier? number
    ---@field preserve_charge_chance? number
    ---@field describe? fun(multiplier: number, maximum_multiplier?: number): string

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
    ---@field initial_suffix? integer
    ---@field initial_restoration_mode? integer
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
    ---@field heal number
    ---@field mana number

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
        spec.adjust_cached_stats = adjust_restoration_for_affixes
        spec.append_stats = function(item, text, alt_text)
            local current = PotionService.getUseCooldown(item)
            local lower, upper = PotionService.getUseCooldownRange(item)
            text[#text + 1] = "|n + |cffffcc00" .. concise_number(current) ..
                                  "|r Cooldown"
            if math.abs(lower - upper) > 0.001 then
                alt_text[#alt_text + 1] = "|n + |cffffcc00" ..
                                              concise_number(lower) .. "-" ..
                                              concise_number(upper) ..
                                              "|r Cooldown"
            else
                alt_text[#alt_text + 1] = "|n + |cffffcc00" ..
                                              concise_number(current) ..
                                              "|r Cooldown"
            end
        end
        spec.initialize_item = function(item)
            local potion = spec.metadata.potion
            if potion.initial_prefix then
                item.quality[INFUSION_QUALITY_INDEX] = potion.initial_prefix
            end
            if potion.initial_suffix then
                item.quality[CATALYST_QUALITY_INDEX] = potion.initial_suffix
            end
            if item.data[ITEM_LEVEL_REQUIREMENT] >= 200 then
                item.persistent_state[RESTORATION_REROLL_STATE] = 0
                item.persistent_state[PREFIX_REROLL_STATE] = 0
                item.persistent_state[SUFFIX_REROLL_STATE] = 0
                item.persistent_state[RESTORATION_MODE_STATE] =
                    potion.initial_restoration_mode or RESTORATION_HYBRID
                item.persistent_state[REROLL_CATEGORY_STATE] = 0
                item.persistent_state[REROLL_SEED_STATE] =
                    GetRandomInt(1, 0x7FFFFFFF)
                item.persistent_state[COOLDOWN_QUALITY_STATE] =
                    GetRandomInt(0, 63)
                item.persistent_state[INFUSION_QUALITY_STATE] =
                    GetRandomInt(0, 63)
            end
        end
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
        if roll_optional_affixes ~= false and behavior.suffix_roll_chance and
            item.quality[CATALYST_QUALITY_INDEX] == 0 and
            GetRandomReal(0., 1.) <= behavior.suffix_roll_chance then
            item.quality[CATALYST_QUALITY_INDEX] = GetRandomInt(
                                                       CATALYST_POTENT,
                                                       #catalysts)
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
        PotionService.refreshItem(item)
        local name = GetItemName(item.obj)
        local icon = BlzGetItemIconPath(item.obj)
        -- A catalog represents the item that may be rolled, not the disposable
        -- preview instance created to obtain its native presentation fields.
        local description = item.alt_tooltip or item.tooltip or
                                BlzGetItemDescription(item.obj)
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
            display_rarity = 1,
            health_key = GREATER_HEALTH_KEY,
            mana_key = GREATER_MANA_KEY,
            flat_min = 750,
            flat_max = 1250,
            percent_min = 8,
            percent_max = 12,
            charge_min = 0,
            charge_max = 1,
            flavor = "A dependable flask whose contents remain fresh through the longest journey."
        }, {
            level = 110,
            item_tier = 2,
            display_rarity = 2,
            health_key = SUPERIOR_HEALTH_KEY,
            mana_key = SUPERIOR_MANA_KEY,
            flat_min = 3000,
            flat_max = 5000,
            percent_min = 14,
            percent_max = 18,
            charge_min = 1,
            charge_max = 2,
            flavor = "Its carefully sealed mixture gives off a steady, comforting warmth."
        }, {
            level = 170,
            item_tier = 2,
            display_rarity = 3,
            health_key = GRAND_HEALTH_KEY,
            mana_key = GRAND_MANA_KEY,
            flat_min = 6000,
            flat_max = 9000,
            percent_min = 16,
            percent_max = 20,
            charge_min = 2,
            charge_max = 3,
            flavor = "Concentrated restorative essence glimmers beneath the glass."
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

    local function define_prechaos_flask(key, id, carrier, name, icon, tier,
                                         flat_stat, percent_stat)
        PotionService.define(key, {
            id = id,
            carrier = carrier,
            name = name,
            icon = icon,
            tooltip = "|cff808080" .. tier.flavor .. "|r",
            display_rarity = tier.display_rarity,
            inherit_stats = inherited_potion_stats,
            prepare_data = prepare_prechaos_flask(tier, flat_stat, percent_stat)
        })
    end

    define_prechaos_flask(GREATER_HEALTH_KEY, GREATER_HEALTH_ID,
                          HEALTH_FLASK_ID, "Greater Health Flask",
                          GREATER_HEALTH_ICON,
                          prechaos_tiers[1], ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL)
    define_prechaos_flask(GREATER_MANA_KEY, GREATER_MANA_ID, MANA_FLASK_ID,
                          "Greater Mana Flask", GREATER_MANA_ICON,
                          prechaos_tiers[1],
                          ITEM_FLAT_MANA, ITEM_PERCENT_MANA)
    define_prechaos_flask(SUPERIOR_HEALTH_KEY, SUPERIOR_HEALTH_ID,
                          HEALTH_FLASK_ID, "Superior Health Flask",
                          GREATER_HEALTH_ICON,
                          prechaos_tiers[2], ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL)
    define_prechaos_flask(SUPERIOR_MANA_KEY, SUPERIOR_MANA_ID, MANA_FLASK_ID,
                          "Superior Mana Flask", GREATER_MANA_ICON,
                          prechaos_tiers[2],
                          ITEM_FLAT_MANA, ITEM_PERCENT_MANA)
    define_prechaos_flask(GRAND_HEALTH_KEY, GRAND_HEALTH_ID,
                          HEALTH_FLASK_ID, "Grand Health Flask",
                          GREATER_HEALTH_ICON, prechaos_tiers[3],
                          ITEM_FLAT_HEAL, ITEM_PERCENT_HEAL)
    define_prechaos_flask(GRAND_MANA_KEY, GRAND_MANA_ID, MANA_FLASK_ID,
                          "Grand Mana Flask", GREATER_MANA_ICON,
                          prechaos_tiers[3], ITEM_FLAT_MANA,
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
            data[ITEM_CHARGES] = math.max(CHAOS_CHARGE_MIN,
                                          carrier_data[ITEM_CHARGES])
            data[ITEM_CHARGES .. "range"] = CHAOS_CHARGE_MAX
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

    local function apply_scaled_buff(context, buff_type, field, amount,
                                     duration)
        local buff = buff_type:add(context.hero, context.hero)
        local previous = buff[field] or 0.
        local value = amount * context.potency_multiplier
        local unit = context.unit

        if field == "damage" then
            unit.dm = unit.dm / (1. + previous) * (1. + value)
        elseif field == "spellboost" then
            unit.spellboost = unit.spellboost - previous + value
        elseif field == "movespeed" then
            unit.ms_percent = unit.ms_percent - previous + value
        elseif field == "status_resist" then
            unit.status_resist_flat = unit.status_resist_flat - previous + value
        elseif field == "evasion" then
            unit.evasion = unit.evasion - previous + value
        elseif field == "attack_speed" then
            unit.bonus_bat = unit.bonus_bat * (1. + previous) /
                                 (1. + value)
        end

        buff[field] = value
        buff:duration(duration * context.duration_multiplier)
        UnitRefreshBuff(context.hero, buff)
    end

    PotionService.define(STONEBLOOD_KEY, {
        id = STONEBLOOD_ID,
        carrier = HEALTH_FLASK_ID,
        name = "Stoneblood Flask",
        icon = GREEN_FLASK_ICON,
        tooltip = "|cff808080Heavy mineral sediment settles beneath its green contents.|r",
        display_rarity = 3,
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(30000, 30, 30000, 30)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        initial_prefix = INFUSION_STONE,
        initial_restoration_mode = RESTORATION_HEALTH,
        affix_capacity = 1
    })

    PotionService.define(TEMPEST_KEY, {
        id = TEMPEST_ID,
        carrier = MANA_FLASK_ID,
        name = "Tempest Flask",
        icon = TEMPEST_ICON,
        tooltip = "|cff808080A captive current circles endlessly within the glass.|r",
        display_rarity = 3,
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(30000, 30, 30000, 30)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        initial_prefix = INFUSION_TEMPEST,
        initial_restoration_mode = RESTORATION_MANA,
        affix_capacity = 1
    })

    PotionService.define(HUNTERS_KEY, {
        id = HUNTERS_ID,
        carrier = HEALTH_FLASK_ID,
        name = "Vampiric Flask",
        icon = BLOOD_FLASK_ICON,
        tooltip = "|cff808080Warm to the touch, with a pulse that is almost familiar.|r",
        display_rarity = 3,
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(15000, 15, 15000, 15)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        initial_prefix = INFUSION_VAMPIRIC,
        affix_capacity = 1
    })

    PotionService.define(LEGENDARY_CHAOS_KEY, {
        id = LEGENDARY_CHAOS_ID,
        carrier = HEALTH_FLASK_ID,
        name = "Legendary Flask",
        icon = "ReplaceableTextures\\CommandButtons\\BTNINV_Potion_16.blp",
        tooltip = "|cff808080Two currents spiral through the glass without ever mingling.|r",
        display_rarity = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(40000, 25, 40000, 25)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        affix_capacity = 2
    })

    PotionService.define(BLOOD_FLASK_KEY, {
        id = INFUSION_VAMPIRIC,
        carrier = MANA_FLASK_ID,
        name = "Vampiric Flask",
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
        affix_name = "Vampiric",
        flavor = "The mixture beats against the glass with a borrowed pulse.",
        icon = BLOOD_FLASK_ICON,
        description = "Restores |cffffcc008%|r of damage dealt as Health " ..
            "for |cffffcc0012 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Restores |cffffcc00" ..
                       effect_amount(8., multiplier, maximum_multiplier) ..
                       "%|r of damage dealt as Health for |cffffcc0012 seconds|r."
        end,
        on_use = function(context)
            apply_vampiric_effect(context, 0.08, 12.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_AEGIS,
        key = "aegis",
        name = "Aegis Infusion",
        affix_name = "Aegis",
        flavor = "Its glass remains immaculate, untouched by chip or scratch.",
        icon = YELLOW_FLASK_ICON,
        description = "Grants a shield equal to |cffffcc0020%|r of maximum " ..
            "Health for |cffffcc0010 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Grants a shield equal to |cffffcc00" ..
                       effect_amount(20., multiplier, maximum_multiplier) ..
                       "%|r of maximum Health for |cffffcc0010 seconds|r."
        end,
        on_use = function(context)
            Shield.add(context.hero, context.unit.hp * 0.20 *
                           context.potency_multiplier,
                       10. * context.duration_multiplier)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_FURY,
        key = "fury",
        name = "Fury Infusion",
        affix_name = "Fury",
        flavor = "The crimson mixture seethes even while perfectly still.",
        icon = POWER_FLASK_ICON,
        description = "Increases total damage by |cffffcc0025%|r for " ..
            "|cffffcc0010 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Increases total damage by |cffffcc00" ..
                       effect_amount(25., multiplier, maximum_multiplier) ..
                       "%|r for |cffffcc0010 seconds|r."
        end,
        on_use = function(context)
            apply_scaled_buff(context, FuryFlaskBuff, "damage", 0.25, 10.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_ARCANE,
        key = "arcane",
        name = "Arcane Infusion",
        affix_name = "Arcane",
        flavor = "Violet sparks gather impatiently around the stopper.",
        icon = PURPLE_FLASK_ICON,
        description = "Increases Spell Power by |cffffcc0025%|r for " ..
            "|cffffcc0010 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Increases Spell Power by |cffffcc00" ..
                       effect_amount(25., multiplier, maximum_multiplier) ..
                       "%|r for |cffffcc0010 seconds|r."
        end,
        on_use = function(context)
            apply_scaled_buff(context, ArcaneFlaskBuff, "spellboost", 0.25,
                              10.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_SWIFTNESS,
        key = "swiftness",
        name = "Swiftness Infusion",
        affix_name = "Swiftness",
        flavor = "Its bright contents refuse to settle for even a moment.",
        icon = BLUE_FLASK_ICON,
        description = "Increases movement speed by |cffffcc0025%|r for " ..
            "|cffffcc0010 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Increases movement speed by |cffffcc00" ..
                       effect_amount(25., multiplier, maximum_multiplier) ..
                       "%|r for |cffffcc0010 seconds|r."
        end,
        on_use = function(context)
            apply_scaled_buff(context, SwiftnessFlaskBuff, "movespeed", 0.25,
                              10.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_PURITY,
        key = "purity",
        name = "Purity Infusion",
        affix_name = "Purity",
        flavor = "A clear light gathers beneath the darkened seal.",
        icon = EMPTY_FLASK_ICON,
        description = "Removes negative effects and grants |cffffcc0040%|r " ..
            "Status Resistance for |cffffcc008 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Removes negative effects and grants |cffffcc00" ..
                       effect_amount(40., multiplier, maximum_multiplier) ..
                       "%|r Status Resistance for |cffffcc008 seconds|r."
        end,
        on_use = function(context)
            Buff.dispelType(context.hero, BUFF_NEGATIVE)
            apply_scaled_buff(context, PurityFlaskBuff, "status_resist", 40.,
                              8.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_OMNISCIENCE,
        key = "omniscience",
        name = "Omniscience Infusion",
        affix_name = "Omniscient",
        flavor = "Every drifting mote seems to contain a possible future.",
        icon =
            "ReplaceableTextures\\CommandButtons\\BTNPotionOfOmniscience.blp",
        description = "Grants |cffffcc0015%|r Critical Chance and " ..
            "|cffffcc0030%|r Critical Damage for |cffffcc0010 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Grants |cffffcc00" ..
                       effect_amount(15., multiplier, maximum_multiplier) ..
                       "%|r Critical Chance and |cffffcc00" ..
                       effect_amount(30., multiplier, maximum_multiplier) ..
                       "%|r Critical Damage for |cffffcc0010 seconds|r."
        end,
        on_use = function(context)
            local buff = OmniscienceFlaskBuff:add(context.hero, context.hero)
            local unit = context.unit
            local crit = 15. * context.potency_multiplier
            local crit_damage = 30. * context.potency_multiplier
            unit.cc_flat = unit.cc_flat - (buff.crit or 0.) + crit
            unit.cd_flat = unit.cd_flat - (buff.crit_damage or 0.) +
                               crit_damage
            buff.crit = crit
            buff.crit_damage = crit_damage
            buff:duration(10. * context.duration_multiplier)
            UnitRefreshBuff(context.hero, buff)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_FRENZY,
        key = "frenzy",
        name = "Frenzy Infusion",
        affix_name = "Frenzied",
        flavor = "The contents refuse to remain still, even when untouched.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNStrongDrink.blp",
        description = "Increases attack speed by |cffffcc0025%|r for " ..
            "|cffffcc0010 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Increases attack speed by |cffffcc00" ..
                       effect_amount(25., multiplier, maximum_multiplier) ..
                       "%|r for |cffffcc0010 seconds|r."
        end,
        on_use = function(context)
            apply_scaled_buff(context, FrenzyFlaskBuff, "attack_speed", 0.25,
                              10.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_PHASING,
        key = "phasing",
        name = "Phasing Infusion",
        affix_name = "Phasing",
        flavor = "Its pale surface slips out of focus whenever watched.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNInvulnerable.blp",
        description = "Grants |cffffcc0020%|r Evasion for |cffffcc0010 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Grants |cffffcc00" ..
                       effect_amount(20., multiplier, maximum_multiplier) ..
                       "%|r Evasion for |cffffcc0010 seconds|r."
        end,
        on_use = function(context)
            apply_scaled_buff(context, PhasingFlaskBuff, "evasion", 20., 10.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_STONE,
        key = "stone",
        name = "Stone Infusion",
        affix_name = "Stoneblood",
        flavor = "Mineral sediment swirls through the heavy mixture.",
        icon = GREEN_FLASK_ICON,
        description = "Reduces damage taken by |cffffcc0015%|r for " ..
            "|cffffcc0012 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Reduces damage taken by |cffffcc00" ..
                       effect_amount(15., multiplier, maximum_multiplier) ..
                       "%|r for |cffffcc0012 seconds|r."
        end,
        on_use = function(context)
            apply_stone_effect(context, 0.15, 12.)
        end
    })

    PotionService.registerInfusion({
        id = INFUSION_TEMPEST,
        key = "tempest",
        name = "Tempest Infusion",
        affix_name = "Tempest",
        flavor = "A captive current circles endlessly within the glass.",
        icon = TEMPEST_ICON,
        description = "Ability cooldowns recover |cffffcc00100%|r faster " ..
            "for |cffffcc008 seconds|r.",
        describe = function(multiplier, maximum_multiplier)
            return "Ability cooldowns recover |cffffcc00" ..
                       effect_amount(100., multiplier, maximum_multiplier) ..
                       "%|r faster for |cffffcc008 seconds|r."
        end,
        on_use = function(context)
            apply_tempest_effect(context, 1., 8.)
        end
    })

    PotionService.registerCatalyst({
        id = CATALYST_POTENT,
        key = "potent",
        name = "Potent Catalyst",
        affix_name = "Potency",
        flavor = "A single drop leaves the surrounding air trembling.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNINV_Potion_16.blp",
        description = "Infusion effects are |cffffcc0025%|r stronger.",
        potency_multiplier = 1.25
    })

    PotionService.registerCatalyst({
        id = CATALYST_LINGERING,
        key = "lingering",
        name = "Lingering Catalyst",
        affix_name = "Lingering",
        flavor = "Its fragrance hangs in the air long after the stopper is replaced.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNInvulnerable.blp",
        description = "Infusion effects last |cffffcc0050%|r longer.",
        duration_multiplier = 1.50
    })

    PotionService.registerCatalyst({
        id = CATALYST_ACCELERANT,
        key = "accelerant",
        name = "Accelerant Catalyst",
        affix_name = "Acceleration",
        flavor = "The volatile mixture flashes at the slightest motion.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNBootsOfSpeed.blp",
        description = "Potion cooldown is |cffffcc0033%|r shorter, but " ..
            "infusion effects last |cffffcc0025%|r less time.",
        cooldown_multiplier = 2. / 3.,
        duration_multiplier = 0.75
    })

    PotionService.registerCatalyst({
        id = CATALYST_BOUNTIFUL,
        key = "bountiful",
        name = "Bountiful Catalyst",
        affix_name = "Bounty",
        flavor = "The flask feels impossibly full whenever it is lifted.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNPotionOfRestoration.blp",
        description = "Restores |cffffcc0025%|r more Health and Mana.",
        restoration_multiplier = 1.25
    })

    PotionService.registerCatalyst({
        id = CATALYST_CONSERVING,
        key = "conserving",
        name = "Conserving Catalyst",
        affix_name = "Conservation",
        flavor = "Not a single drop clings to the glass after pouring.",
        icon = "ReplaceableTextures\\CommandButtons\\BTNRestoration.blp",
        description = "Has a |cffffcc0025%|r chance not to consume a charge.",
        preserve_charge_chance = 0.25
    })

    PotionService.registerCatalyst({
        id = CATALYST_ECHOING,
        key = "echoing",
        name = "Echoing Catalyst",
        affix_name = "Echoes",
        flavor = "A second ripple always follows the first.",
        icon = TEMPEST_ICON,
        description = "Repeats |cffffcc0040%|r of the flask's restoration " ..
            "after |cffffcc004 seconds|r.",
        on_use = function(context)
            if context.heal <= 0. and context.mana <= 0. then return end
            TQ:callDelayed(4., function(hero, heal, mana)
                if not UnitAlive(hero) then return end
                if heal > 0. then HP(hero, hero, heal * 0.40, "Echoing Flask") end
                if mana > 0. then MP(hero, mana * 0.40) end
            end, context.hero, context.heal, context.mana)
        end
    })

    local function define_affix_donor(id, key, icon, prefix, suffix)
        local effect = prefix and infusions[prefix] or catalysts[suffix]
        PotionService.define(key, {
            id = id,
            carrier = prefix and HEALTH_FLASK_ID or MANA_FLASK_ID,
            name = prefix and effect.affix_name .. " Flask" or
                "Flask of " .. effect.affix_name,
            icon = icon,
            tooltip = "|cff808080" .. effect.flavor .. "|r",
            display_rarity = 3,
            inherit_stats = chaos_inherited_stats,
            prepare_data = prepare_chaos_flask(6000, 12, 6000, 12)
        }, {
            cooldown = DEFAULT_USE_COOLDOWN,
            initial_prefix = prefix,
            initial_suffix = suffix,
            affix_capacity = 1
        })
        chaos_donor_keys[#chaos_donor_keys + 1] = key
        local pool = prefix and chaos_prefix_donor_keys or
                         chaos_suffix_donor_keys
        pool[#pool + 1] = key
    end

    define_affix_donor(FIRST_DONOR_ID, "aegis_donor_flask", YELLOW_FLASK_ICON,
                       INFUSION_AEGIS)
    define_affix_donor(FIRST_DONOR_ID + 1, "fury_donor_flask",
                       POWER_FLASK_ICON,
                       INFUSION_FURY)
    define_affix_donor(FIRST_DONOR_ID + 2, "arcane_donor_flask",
                       PURPLE_FLASK_ICON,
                       INFUSION_ARCANE)
    define_affix_donor(FIRST_DONOR_ID + 3, "swiftness_donor_flask",
                       BLUE_FLASK_ICON,
                       INFUSION_SWIFTNESS)
    define_affix_donor(FIRST_DONOR_ID + 4, "purity_donor_flask",
                       EMPTY_FLASK_ICON,
                       INFUSION_PURITY)
    define_affix_donor(FIRST_DONOR_ID + 5, "bountiful_donor_flask",
                       "ReplaceableTextures\\CommandButtons\\BTNPotionOfRestoration.blp",
                       nil, CATALYST_BOUNTIFUL)
    define_affix_donor(FIRST_DONOR_ID + 6, "conserving_donor_flask",
                       "ReplaceableTextures\\CommandButtons\\BTNRestoration.blp",
                       nil, CATALYST_CONSERVING)
    define_affix_donor(FIRST_DONOR_ID + 7, "echoing_donor_flask",
                       TEMPEST_ICON,
                       nil, CATALYST_ECHOING)
    define_affix_donor(FIRST_DONOR_ID + 8, "potent_donor_flask",
                       "ReplaceableTextures\\CommandButtons\\BTNINV_Potion_16.blp",
                       nil, CATALYST_POTENT)
    define_affix_donor(FIRST_DONOR_ID + 9, "lingering_donor_flask",
                       "ReplaceableTextures\\CommandButtons\\BTNInvulnerable.blp",
                       nil, CATALYST_LINGERING)
    define_affix_donor(FIRST_DONOR_ID + 10, "accelerant_donor_flask",
                       "ReplaceableTextures\\CommandButtons\\BTNBootsOfSpeed.blp",
                       nil, CATALYST_ACCELERANT)
    define_affix_donor(FIRST_DONOR_ID + 11, "omniscience_donor_flask",
                       "ReplaceableTextures\\CommandButtons\\BTNPotionOfOmniscience.blp",
                       INFUSION_OMNISCIENCE)
    define_affix_donor(FIRST_DONOR_ID + 12, "frenzy_donor_flask",
                       "ReplaceableTextures\\CommandButtons\\BTNStrongDrink.blp",
                       INFUSION_FRENZY)
    define_affix_donor(FIRST_DONOR_ID + 13, "phasing_donor_flask",
                       "ReplaceableTextures\\CommandButtons\\BTNInvulnerable.blp",
                       INFUSION_PHASING)

    ---Creates a non-faction affix donor from the Chaos boss drop pool.
    ---The optional kind remains useful for tests and future targeted rewards.
    function PotionService.createChaosDonor(x, y, expire, kind)
        local pool = kind == "prefix" and chaos_prefix_donor_keys or
                         kind == "suffix" and chaos_suffix_donor_keys or
                         chaos_donor_keys
        if #pool == 0 then return nil end
        local key = pool[GetRandomInt(1, #pool)]
        return PotionService.create(key, x, y, expire)
    end

    function PotionService.getChaosDonorKeys(kind)
        local pool = kind == "prefix" and chaos_prefix_donor_keys or
                         kind == "suffix" and chaos_suffix_donor_keys or
                         chaos_donor_keys
        local result = {}
        for index, key in ipairs(pool) do result[index] = key end
        return result
    end

    ---Returns independent Chaos-boss drop chances. Affix donors remain
    ---obtainable enough to support brewing, while the two-affix legendary
    ---base deliberately ranges from roughly 1:20,000 to 1:1,000 per kill.
    ---Both rewards improve with boss level and selected boss difficulty.
    function PotionService.getChaosBossDropChances(level, difficulty)
        local progress = math.max(0., math.min(1., ((level or 200) - 200.) /
                                                      300.))
        local challenge = math.max(1, math.floor(difficulty or 1))
        local donor = math.min(0.40, 0.08 + 0.12 * progress +
                                   0.02 * (challenge - 1))
        local legendary = math.min(0.0025,
            (0.00005 + 0.00045 * progress * progress) *
                (1. + 0.25 * (challenge - 1)))
        return donor, legendary
    end

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

    ---Returns a potion from any absolute saved inventory slot.
    function PotionService.getStored(pid, slot)
        local profile = Profile[pid]
        local item = profile and profile.hero and profile.hero.items[slot]
        return item and item.alive and item.type == TYPE_POTION_INDEX and item or
                   nil
    end

    ---Returns all flasks available to the Potion Master in inventory order.
    function PotionService.getStoredAll(pid)
        local result = {}
        for slot = 1, MAX_INVENTORY_SLOTS do
            local item = PotionService.getStored(pid, slot)
            if item then result[#result + 1] = {slot = slot, item = item} end
        end
        return result
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

    local function persistent_quality(item, index, salt)
        local state = item.persistent_state
        local quality = state[index]
        if quality == nil then
            local seed = state[REROLL_SEED_STATE] or
                             ((item.runtime_definition and
                                 item.runtime_definition.id or item.id) *
                                 0x45D9F3B)
            quality = (seed ~ salt) & 0x3F
            state[index] = quality
        end
        return math.max(0, math.min(63, math.floor(quality)))
    end

    function PotionService.getCooldownQuality(item)
        if not item or not item.runtime_definition or
            item.data[ITEM_LEVEL_REQUIREMENT] < 200 then return nil end
        return persistent_quality(item, COOLDOWN_QUALITY_STATE, 0x17A2D39)
    end

    function PotionService.getInfusionQuality(item)
        if not item or not item.runtime_definition or
            item.data[ITEM_LEVEL_REQUIREMENT] < 200 then return nil end
        return persistent_quality(item, INFUSION_QUALITY_STATE, 0x2C9277B)
    end

    function PotionService.getInfusionMultiplier(item)
        local quality = PotionService.getInfusionQuality(item)
        if quality == nil then return 1. end
        return rolled_value(INFUSION_ROLL_MIN, INFUSION_ROLL_MAX, quality)
    end

    local function append_customization(item, definition, multiplier)
        if not definition then return end
        local description = definition.describe and
                                definition.describe(multiplier or 1.) or
                                definition.description
        local alt_description = definition.describe and multiplier and
                                    definition.describe(INFUSION_ROLL_MIN,
                                                        INFUSION_ROLL_MAX) or
                                    description
        local line = "|n|cff0080c0" .. definition.name .. ":|r " ..
                         description
        local alt_line = "|n|cff0080c0" .. definition.name .. ":|r " ..
                             alt_description
        item.tooltip = (item.tooltip or "") .. line
        item.alt_tooltip = (item.alt_tooltip or "") .. alt_line
    end

    local function affix_capacity(item)
        local behavior = item and item.runtime_definition and
                             item.runtime_definition.metadata.potion
        return behavior and behavior.affix_capacity or 0
    end

    local function append_affix_slots(item, prefix, suffix)
        local capacity = affix_capacity(item)
        if capacity <= 0 then return end

        local used = (prefix and 1 or 0) + (suffix and 1 or 0)
        local available = capacity - used
        local function status(definition)
            if definition then
                return "|cff0080c0" .. definition.affix_name .. "|r"
            end
            if available > 0 then return "|cff40bf5fOpen|r" end
            return "|cff606060Locked|r"
        end
        local line = "|n|cff808080Prefix:|r " .. status(prefix) ..
                         "   |cff808080Suffix:|r " .. status(suffix)
        item.tooltip = (item.tooltip or "") .. line
        item.alt_tooltip = (item.alt_tooltip or "") .. line
    end

    local function customized_name(item, prefix, suffix)
        if prefix and suffix then
            return prefix.affix_name .. " Flask of " .. suffix.affix_name
        elseif prefix then
            return prefix.affix_name .. " Flask"
        elseif suffix then
            return "Flask of " .. suffix.affix_name
        end
        return item.runtime_definition and item.runtime_definition.data.name or
                   GetItemName(item.obj)
    end

    local function restoration_multiplier(item)
        local count = restoration_affix_count(item)
        local multiplier = count >= 2 and 0.40 or count == 1 and 0.70 or 1.
        local catalyst = selected_customization(item, catalysts,
                                                CATALYST_QUALITY_INDEX)
        return multiplier *
                   (catalyst and catalyst.restoration_multiplier or 1.)
    end

    ---Applies the item's dynamic presentation to its backing native handle.
    ---@param item Item
    function PotionService.refreshItem(item)
        if not item or not item.alive or item.type ~= TYPE_POTION_INDEX then
            return
        end
        item:update(true)
        if not item.runtime_definition then
            local cooldown = concise_number(PotionService.getUseCooldown(item))
            local line = "|n + |cffffcc00" .. cooldown .. "|r Cooldown"
            item.tooltip = (item.tooltip or "") .. line
            item.alt_tooltip = (item.alt_tooltip or "") .. line
        end
        local infusion = selected_customization(item, infusions,
                                                INFUSION_QUALITY_INDEX)
        local catalyst = selected_customization(item, catalysts,
                                                CATALYST_QUALITY_INDEX)
        local behavior = item.runtime_definition and
                             item.runtime_definition.metadata and
                             item.runtime_definition.metadata.potion
        local name_prefix = infusion
        if not name_prefix and behavior and behavior.inherent_infusion then
            name_prefix = infusions[behavior.inherent_infusion]
        end
        append_affix_slots(item, infusion, catalyst)
        append_customization(item, infusion,
                             PotionService.getInfusionMultiplier(item))
        append_customization(item, catalyst)
        local reroll_category = item.persistent_state and math.floor(
                                    item.persistent_state[REROLL_CATEGORY_STATE] or
                                        0) or 0
        local reroll_name = PotionService.REROLL_CATEGORY_NAMES and
                                PotionService.REROLL_CATEGORY_NAMES[reroll_category]
        if reroll_name then
            local line = "|n|cff808080Reroll Property:|r |cff0080c0" ..
                             reroll_name .. "|r"
            item.tooltip = (item.tooltip or "") .. line
            item.alt_tooltip = (item.alt_tooltip or "") .. line
        end
        local name = customized_name(item, name_prefix, catalyst)
        local icon = name_prefix and name_prefix.icon or catalyst and
                         catalyst.icon or
                         (item.runtime_definition and
                             item.runtime_definition.data.path or item.data.path)
        BlzSetItemName(item.obj, name)
        BlzSetItemTooltip(item.obj, name)
        BlzSetItemIconPath(item.obj, icon)
        BlzSetItemDescription(item.obj, item.tooltip)
        BlzSetItemExtendedTooltip(item.obj, item.tooltip)
    end

    ---@param item Item
    ---@param infusion integer
    function PotionService.setInfusion(item, infusion, quality)
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
        if infusion ~= INFUSION_NONE and quality ~= nil then
            item.persistent_state[INFUSION_QUALITY_STATE] =
                math.max(0, math.min(63, math.floor(quality)))
        end
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
            capacity = affix_capacity(item),
            infusion_quality = PotionService.getInfusionQuality(item),
            infusion_multiplier = PotionService.getInfusionMultiplier(item)
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

    ---Applies the anti-chug cooldown when a different flask enters a potion
    ---slot. An existing longer cooldown is never shortened.
    ---@param pid integer
    ---@param index integer Potion button index, 1 or 2.
    ---@param duration number?
    ---@return number remaining
    function PotionService.applyEquipCooldown(pid, index, duration)
        if index ~= 1 and index ~= 2 then return 0. end
        duration = math.max(0., duration or EQUIP_COOLDOWN)
        local current = PotionService.getCooldown(pid, index)
        if current >= duration then return current end

        local player_cooldowns = cooldown_table(pid)
        if player_cooldowns[index] then
            TQ:disableCallback(player_cooldowns[index])
        end
        player_cooldowns[index] = TQ:callDelayed(duration, clear_cooldown,
                                                 pid, index)
        return duration
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

        local cooldown_quality = PotionService.getCooldownQuality(item)
        if cooldown_quality ~= nil then
            cooldown = cooldown *
                           (rolled_value(CHAOS_COOLDOWN_MAX,
                                         CHAOS_COOLDOWN_MIN,
                                         cooldown_quality) /
                               DEFAULT_USE_COOLDOWN)
        end

        local catalyst = selected_customization(item, catalysts,
                                                CATALYST_QUALITY_INDEX)
        cooldown = cooldown *
                       (catalyst and catalyst.cooldown_multiplier or 1.)

        return math.max(0., cooldown)
    end

    ---Returns the displayed roll bounds after any suffix modifier. Ordinary
    ---and pre-Chaos potions expose their fixed cooldown as both bounds.
    function PotionService.getUseCooldownRange(item)
        local behavior = potion_behavior(item)
        local cooldown = behavior and behavior.cooldown or nil
        if type(cooldown) == "function" then cooldown = cooldown(item) end
        if type(cooldown) ~= "number" then cooldown = DEFAULT_USE_COOLDOWN end

        local catalyst = selected_customization(item, catalysts,
                                                CATALYST_QUALITY_INDEX)
        local catalyst_multiplier = catalyst and
                                        catalyst.cooldown_multiplier or 1.
        if PotionService.getCooldownQuality(item) == nil then
            cooldown = math.max(0., cooldown * catalyst_multiplier)
            return cooldown, cooldown
        end
        return math.max(0., cooldown * CHAOS_COOLDOWN_MIN /
                            DEFAULT_USE_COOLDOWN * catalyst_multiplier),
               math.max(0., cooldown * CHAOS_COOLDOWN_MAX /
                            DEFAULT_USE_COOLDOWN * catalyst_multiplier)
    end

    ---Returns the complete potion property set used by future refinement and
    ---crafting UI without exposing cached-stat indexing to those consumers.
    ---@param item Item
    ---@return table?
    function PotionService.getProperties(item)
        if not item or not item.alive or item.type ~= TYPE_POTION_INDEX or
            not item.cached_stats then return nil end

        local stats = item.cached_stats
        local original = item.potion_unmodified_stats or stats
        return {
            charges = item.charges,
            maximum_charges = stats[ITEM_CHARGES],
            level_requirement = item.data[ITEM_LEVEL_REQUIREMENT],
            flat_health = stats[ITEM_FLAT_HEAL],
            percent_health = stats[ITEM_PERCENT_HEAL],
            flat_mana = stats[ITEM_FLAT_MANA],
            percent_mana = stats[ITEM_PERCENT_MANA],
            base_flat_health = original[ITEM_FLAT_HEAL],
            base_percent_health = original[ITEM_PERCENT_HEAL],
            base_flat_mana = original[ITEM_FLAT_MANA],
            base_percent_mana = original[ITEM_PERCENT_MANA],
            restoration_multiplier = restoration_multiplier(item),
            cooldown = PotionService.getUseCooldown(item),
            cooldown_quality = PotionService.getCooldownQuality(item),
            infusion_quality = PotionService.getInfusionQuality(item),
            infusion_multiplier = PotionService.getInfusionMultiplier(item),
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

    PotionService.REROLL_CATEGORY_NAMES = {
        [REROLL_RESTORATION] = "Restoration",
        [REROLL_CHARGES] = "Charges",
        [REROLL_COOLDOWN] = "Cooldown",
        [REROLL_PREFIX] = "Prefix"
    }

    function PotionService.getRerollCategory(item)
        if not item or not item.persistent_state then return nil end
        local category = math.floor(
                             item.persistent_state[REROLL_CATEGORY_STATE] or 0)
        return PotionService.REROLL_CATEGORY_NAMES[category] and category or nil
    end

    function PotionService.canRerollCategory(item, category)
        if not item or item.type ~= TYPE_POTION_INDEX or
            not item.persistent_state then return false end
        local locked = PotionService.getRerollCategory(item)
        if locked and locked ~= category then return false end

        if category == REROLL_RESTORATION then
            for _, stat in ipairs(restoration_stats) do
                local index = refinement_index(item, stat)
                if index and index < INFUSION_QUALITY_INDEX then return true end
            end
            return false
        elseif category == REROLL_CHARGES then
            local index = refinement_index(item, ITEM_CHARGES)
            return index ~= nil and index < INFUSION_QUALITY_INDEX
        elseif category == REROLL_COOLDOWN then
            return PotionService.getCooldownQuality(item) ~= nil
        elseif category == REROLL_PREFIX then
            local customization = PotionService.getCustomization(item)
            return customization ~= nil and customization.prefix ~= nil and
                       customization.infusion_quality ~= nil
        end
        return false
    end

    function PotionService.canReroll(item)
        local locked = PotionService.getRerollCategory(item)
        if locked then return PotionService.canRerollCategory(item, locked) end
        for category = REROLL_RESTORATION, REROLL_PREFIX do
            if PotionService.canRerollCategory(item, category) then return true end
        end
        return false
    end

    -- Compatibility for callers and tests written against the original
    -- all-properties prototype.
    function PotionService.canRerollRestoration(item)
        return PotionService.canRerollCategory(item, REROLL_RESTORATION)
    end

    function PotionService.getRerollCount(item, kind)
        if not item or not item.persistent_state then return 0 end
        local index = RESTORATION_REROLL_STATE
        if kind == "prefix" then
            index = PREFIX_REROLL_STATE
        elseif kind == "suffix" then
            index = SUFFIX_REROLL_STATE
        end
        return math.max(0, math.floor(item.persistent_state[index] or 0))
    end

    local function increment_reroll_count(item, kind)
        local index = RESTORATION_REROLL_STATE
        if kind == "prefix" then
            index = PREFIX_REROLL_STATE
        elseif kind == "suffix" then
            index = SUFFIX_REROLL_STATE
        end
        item.persistent_state[index] = math.min(0x7FFFFFFF,
            PotionService.getRerollCount(item, kind) + 1)
    end

    ---Builds a deterministic permutation using item-local state. This follows
    ---the save code's pseudoRandomPermutation approach without reseeding the
    ---global Lua RNG, which would affect unrelated gameplay randomness.
    local function restoration_permutation(seed)
        local values = {}
        for index = 1, 64 do values[index] = index - 1 end

        local state = (seed ~ 0x45D9F3B) & 0x7FFFFFFF
        for index = 64, 2, -1 do
            state = (state * 1103515245 + 12345) & 0x7FFFFFFF
            local swap = (state % index) + 1
            values[index], values[swap] = values[swap], values[index]
        end
        return values
    end

    ---Produces a candidate from only the fixed item seed, paid attempt,
    ---permanent category, and displayed option. Accepting or rejecting a
    ---choice therefore never alters any later reroll.
    local function next_reroll_rolls(seed, attempt, category, option, count)
        local state = (seed ~ ((attempt + 1) * 0x45D9F3B) ~
                          (category * 0x1F123BB) ~
                          (option * 0x119DE1F3)) & 0x7FFFFFFF
        local rolls = {}
        for index = 1, count do
            local permutation = restoration_permutation(
                                    state ~ (index * 0x45D9F3B))
            rolls[index] = permutation[1]
        end
        return rolls
    end

    local function candidate_value(item, stat, quality)
        local lower = item:calculateValue(stat, 1)
        local upper = item:calculateValue(stat, 2)
        local value = lower + (upper - lower) * 0.015625 * (1 + quality)
        if value >= 1000 then value = (value + 5) // 10 * 10 end
        value = (value < 1 and value) or math.floor(value)
        if stat ~= ITEM_CHARGES then
            value = math.floor(value * restoration_multiplier(item) + 0.5)
        end
        return value
    end

    local function reroll_seed(item)
        local seed = item.persistent_state[REROLL_SEED_STATE] or 0
        if seed == 0 then
            local identity = item.runtime_definition and
                                 item.runtime_definition.id or item.id
            seed = ((identity * 0x45D9F3B) ~ 0x119DE1F3) &
                       0x7FFFFFFF
            item.persistent_state[REROLL_SEED_STATE] = seed
        end
        return seed
    end

    local function restoration_candidates(item, attempt)
        local seed = reroll_seed(item)
        local quality_indices = {}
        local stats = {}
        local has_health = false
        local has_mana = false
        for _, stat in ipairs(restoration_stats) do
            local quality_index = refinement_index(item, stat)
            if quality_index and quality_index < INFUSION_QUALITY_INDEX then
                quality_indices[#quality_indices + 1] = quality_index
                stats[#stats + 1] = stat
                if stat == ITEM_FLAT_HEAL or stat == ITEM_PERCENT_HEAL then
                    has_health = true
                else
                    has_mana = true
                end
            end
        end
        local options = {}
        local modes = has_health and has_mana and {
            RESTORATION_HEALTH, RESTORATION_MANA, RESTORATION_HYBRID
        } or has_health and {
            RESTORATION_HEALTH, RESTORATION_HEALTH, RESTORATION_HEALTH
        } or {
            RESTORATION_MANA, RESTORATION_MANA, RESTORATION_MANA
        }
        local mode_names = has_health and has_mana and
                               {"Health", "Mana", "Hybrid"} or
                               {"Option 1", "Option 2", "Option 3"}
        for option_index, mode in ipairs(modes) do
            local rolls = next_reroll_rolls(seed, attempt,
                                            REROLL_RESTORATION, option_index,
                                            #quality_indices)
            local parts = {}
            for index, stat in ipairs(stats) do
                local show = restoration_stat_enabled(mode, stat)
                if show then
                    local value = candidate_value(item, stat, rolls[index])
                    local suffix = stat == ITEM_FLAT_HEAL and " HP" or
                                       stat == ITEM_PERCENT_HEAL and
                                           "% Max HP" or
                                       stat == ITEM_FLAT_MANA and " MP" or
                                       stat == ITEM_PERCENT_MANA and
                                           "% Max MP" or ""
                    parts[#parts + 1] = tostring(value) .. suffix
                end
            end
            options[#options + 1] = {
                option = option_index,
                category = REROLL_RESTORATION,
                category_name = "Restoration",
                mode = mode,
                mode_name = mode_names[option_index],
                attempt = attempt,
                rolls = rolls,
                quality_indices = quality_indices,
                text = table.concat(parts, ", ")
            }
        end
        return options
    end

    local function single_property_candidates(item, attempt, category)
        local seed = reroll_seed(item)
        local options = {}
        local quality_index = category == REROLL_CHARGES and
                                  refinement_index(item, ITEM_CHARGES) or nil
        for option_index = 1, 3 do
            local quality = next_reroll_rolls(seed, attempt, category,
                                              option_index, 1)[1]
            local text
            if category == REROLL_CHARGES then
                text = tostring(candidate_value(item, ITEM_CHARGES, quality)) ..
                           " Charges"
            elseif category == REROLL_COOLDOWN then
                local lower, upper = PotionService.getUseCooldownRange(item)
                text = concise_number(rolled_value(upper, lower, quality)) ..
                           "s Cooldown"
            else
                text = concise_number(rolled_value(INFUSION_ROLL_MIN,
                                                   INFUSION_ROLL_MAX,
                                                   quality) * 100.) ..
                           "% Prefix Potency"
            end
            options[#options + 1] = {
                option = option_index,
                category = category,
                category_name = PotionService.REROLL_CATEGORY_NAMES[category],
                attempt = attempt,
                rolls = {quality},
                quality_indices = quality_index and {quality_index} or {},
                text = text
            }
        end
        return options
    end

    local function reroll_candidates(item, attempt, category)
        if category == REROLL_RESTORATION then
            return restoration_candidates(item, attempt)
        end
        return single_property_candidates(item, attempt, category)
    end

    function PotionService.getPendingReroll(item)
        if not item or not item.persistent_state then return nil end
        local marker = math.floor(item.persistent_state[PENDING_REROLL_STATE] or
                                      0)
        if marker <= 0 then return nil end
        local category = PotionService.getRerollCategory(item)
        if not category then return nil end
        return reroll_candidates(item, marker - 1, category)
    end

    function PotionService.beginReroll(item, category)
        if not PotionService.canRerollCategory(item, category) then return nil end
        local attempt = PotionService.getRerollCount(item)
        increment_reroll_count(item, "restoration")
        item.persistent_state[REROLL_CATEGORY_STATE] = category
        item.persistent_state[PENDING_REROLL_STATE] = attempt + 1
        if item.pid then NotifyItemChanged(item.pid) end
        return reroll_candidates(item, attempt, category)
    end

    function PotionService.rejectReroll(item)
        if not PotionService.getPendingReroll(item) then return false end
        item.persistent_state[PENDING_REROLL_STATE] = 0
        if item.pid then NotifyItemChanged(item.pid) end
        return true
    end

    function PotionService.acceptReroll(item, attempt, option_index)
        local options = PotionService.getPendingReroll(item)
        if not options or options[1].attempt ~= attempt then return false end
        local selected = options[option_index]
        if not selected then return false end
        if selected.category == REROLL_RESTORATION or
            selected.category == REROLL_CHARGES then
            for index, quality_index in ipairs(selected.quality_indices) do
                item.quality[quality_index] = selected.rolls[index]
            end
        elseif selected.category == REROLL_COOLDOWN then
            item.persistent_state[COOLDOWN_QUALITY_STATE] =
                selected.rolls[1]
        elseif selected.category == REROLL_PREFIX then
            item.persistent_state[INFUSION_QUALITY_STATE] = selected.rolls[1]
        end
        if selected.mode then
            item.persistent_state[RESTORATION_MODE_STATE] = selected.mode
        end
        item.persistent_state[PENDING_REROLL_STATE] = 0
        PotionService.refreshItem(item)
        item.charges = math.min(item.charges, item.cached_stats[ITEM_CHARGES])
        if item.pid then NotifyItemChanged(item.pid) end
        return true
    end

    function PotionService.getRerollResult(item, category)
        if not item or item.type ~= TYPE_POTION_INDEX then return nil end
        local properties = PotionService.getProperties(item)
        if not properties then return nil end

        local presentation = {
            [ITEM_FLAT_HEAL] = {properties.flat_health, " Health"},
            [ITEM_PERCENT_HEAL] = {
                properties.percent_health, "% Max Health"
            },
            [ITEM_FLAT_MANA] = {properties.flat_mana, " Mana"},
            [ITEM_PERCENT_MANA] = {
                properties.percent_mana, "% Max Mana"
            },
            [ITEM_CHARGES] = {properties.maximum_charges, " Charges"}
        }
        local parts = {}
        local minimum_quality = 63
        local count = 0
        local mode = restoration_mode(item)
        if category == REROLL_RESTORATION then
            for _, stat in ipairs(restoration_stats) do
                local quality_index = refinement_index(item, stat)
                if quality_index and restoration_stat_enabled(mode, stat) then
                    local quality = item.quality[quality_index]
                    local shown = presentation[stat]
                    minimum_quality = math.min(minimum_quality, quality)
                    count = count + 1
                    parts[#parts + 1] = tostring(shown[1]) .. shown[2]
                end
            end
        elseif category == REROLL_CHARGES then
            local quality_index = refinement_index(item, ITEM_CHARGES)
            if quality_index then
                minimum_quality = item.quality[quality_index]
                count = 1
                parts[1] = tostring(properties.maximum_charges) .. " Charges"
            end
        elseif category == REROLL_COOLDOWN then
            local cooldown_quality = PotionService.getCooldownQuality(item)
            if cooldown_quality == nil then return nil end
            minimum_quality = math.min(minimum_quality, cooldown_quality)
            count = count + 1
            parts[#parts + 1] = concise_number(properties.cooldown) ..
                                    "s Cooldown"
        elseif category == REROLL_PREFIX then
            local customization = PotionService.getCustomization(item)
            if not customization or not customization.prefix or
                customization.infusion_quality == nil then return nil end
            minimum_quality = math.min(minimum_quality,
                                       customization.infusion_quality)
            count = count + 1
            parts[#parts + 1] = concise_number(
                                    customization.infusion_multiplier * 100.) ..
                                    "% Prefix Potency"
        end
        if count == 0 then return nil end

        return {
            text = table.concat(parts, ", "),
            perfect = minimum_quality == 63,
            near_perfect = minimum_quality >= 60,
            minimum_quality = minimum_quality,
            property_count = count,
            category = category,
            category_name = PotionService.REROLL_CATEGORY_NAMES[category]
        }
    end

    function PotionService.getPendingRestorationReroll(item)
        return PotionService.getPendingReroll(item)
    end

    function PotionService.beginRestorationReroll(item)
        return PotionService.beginReroll(item, REROLL_RESTORATION)
    end

    function PotionService.rejectRestorationReroll(item)
        return PotionService.rejectReroll(item)
    end

    function PotionService.acceptRestorationReroll(item, attempt, mode)
        local options = PotionService.getPendingReroll(item)
        if not options then return false end
        for index, option in ipairs(options) do
            if option.mode == mode then
                return PotionService.acceptReroll(item, attempt, index)
            end
        end
        return false
    end

    function PotionService.getRestorationRollResult(item)
        return PotionService.getRerollResult(item, REROLL_RESTORATION)
    end

    ---@param item Item
    ---@return boolean
    function PotionService.rerollRestoration(item)
        local options = PotionService.beginRestorationReroll(item)
        return options and PotionService.acceptRestorationReroll(
                   item, options[1].attempt, RESTORATION_HYBRID) or false
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
                                               donor_customization.prefix_id,
                                               donor_customization.infusion_quality)
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
        local behavior = potion_behavior(item)
        local customization = PotionService.getCustomization(item)
        local catalyst = customization and customization.catalyst or nil
        local replaces_restoration =
            behavior and behavior.replaces_restoration == true
        local heal =
            replaces_restoration and 0. or stats[ITEM_FLAT_HEAL] + 0.01 *
                stats[ITEM_PERCENT_HEAL] * Unit[hero].hp
        local mana =
            replaces_restoration and 0. or stats[ITEM_FLAT_MANA] + 0.01 *
                stats[ITEM_PERCENT_MANA] * Unit[hero].mana

        local preserve_charge = catalyst and catalyst.preserve_charge_chance and
                                    GetRandomReal(0., 1.) <
                                        catalyst.preserve_charge_chance
        if not preserve_charge then item.charges = item.charges - 1 end
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
            potency_multiplier = PotionService.getInfusionMultiplier(item) *
                (catalyst and catalyst.potency_multiplier or 1.),
            duration_multiplier = catalyst and
                catalyst.duration_multiplier or 1.,
            heal = heal,
            mana = mana
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
        if catalyst and catalyst.on_use then catalyst.on_use(context) end

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
