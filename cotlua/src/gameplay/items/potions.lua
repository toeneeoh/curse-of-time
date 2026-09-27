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

    PotionService.INFUSION_NONE = INFUSION_NONE
    PotionService.INFUSION_VAMPIRIC = INFUSION_VAMPIRIC
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

    ---@class PotionBehavior
    ---@field cooldown? number|fun(item: Item): number
    ---@field replaces_restoration? boolean Suppress formula healing and mana.
    ---@field on_use? fun(context: PotionUseContext)

    ---@class PotionUseContext
    ---@field pid integer
    ---@field item Item
    ---@field hero unit
    ---@field unit UnitTable

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
    ---@return Item?
    function PotionService.create(key, x, y, expire)
        return RuntimeItemDefinitions.create(key, x, y, expire)
    end

    ---Builds the same name, icon, and generated tooltip shown by an inventory
    ---instance for use by catalogs that sell logical potions.
    ---@param key string
    ---@return string? name
    ---@return string? icon
    ---@return string? description
    function PotionService.getCatalogPresentation(key)
        local item = PotionService.create(key, 30000., 30000.)
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
            data[ITEM_FLAT_HEAL] = flat_health
            data[ITEM_FLAT_HEAL .. "fixed"] = 1
            data[ITEM_PERCENT_HEAL] = percent_health
            data[ITEM_PERCENT_HEAL .. "fixed"] = 1
            data[ITEM_FLAT_MANA] = flat_mana
            data[ITEM_FLAT_MANA .. "fixed"] = 1
            data[ITEM_PERCENT_MANA] = percent_mana
            data[ITEM_PERCENT_MANA .. "fixed"] = 1
            data[ITEM_CHARGES] = math.max(6, carrier_data[ITEM_CHARGES])
            data[ITEM_CHARGES .. "fixed"] = 1
        end
    end

    local chaos_inherited_stats = {
        ITEM_RARITY, ITEM_LIMIT, ITEM_NOCRAFT
    }

    PotionService.define(STONEBLOOD_KEY, {
        id = STONEBLOOD_ID,
        carrier = HEALTH_FLASK_ID,
        name = "Stoneblood Flask",
        icon = "ReplaceableTextures\\CommandButtons\\BTNStone.blp",
        tooltip = "|cff0080c0Stoneblood:|r Reduces damage taken by " ..
            "|cffffcc0015%|r for |cffffcc0012 seconds|r.|n" ..
            "A Cave Voyagers flask.",
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(15000, 30, 0, 0)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        on_use = function(context)
            local buff = StonebloodFlaskBuff:add(context.hero, context.hero)
            buff:duration(12.)
        end
    })

    PotionService.define(TEMPEST_KEY, {
        id = TEMPEST_ID,
        carrier = MANA_FLASK_ID,
        name = "Tempest Flask",
        icon = "ReplaceableTextures\\CommandButtons\\BTNMonsoon.blp",
        tooltip = "|cff0080c0Tempest:|r Ability cooldowns recover " ..
            "|cffffcc00100%|r faster for |cffffcc008 seconds|r.|n" ..
            "A Stormwatch flask.",
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(0, 0, 15000, 30)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        on_use = function(context)
            local buff = TempestFlaskBuff:add(context.hero, context.hero)
            PotionService.accelerateCooldowns(context, 1., 8.)
            buff:duration(8.)
        end
    })

    PotionService.define(HUNTERS_KEY, {
        id = HUNTERS_ID,
        carrier = HEALTH_FLASK_ID,
        name = "Hunter's Flask",
        icon = BLOOD_FLASK_ICON,
        tooltip = "|cff0080c0Hunter's Instinct:|r Restores " ..
            "|cffffcc008%|r of damage dealt as Health for " ..
            "|cffffcc0012 seconds|r.|nAn Ashen Vanguard flask.",
        faction_rank_requirement = 4,
        inherit_stats = chaos_inherited_stats,
        prepare_data = prepare_chaos_flask(7500, 15, 7500, 15)
    }, {
        cooldown = DEFAULT_USE_COOLDOWN,
        on_use = function(context)
            local buff = VampiricPotion:add(context.hero, context.hero)
            buff.leech = 0.08
            buff:duration(12.)
            UnitRefreshBuff(context.hero, buff)
        end
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
        on_use = function(context)
            local buff = VampiricPotion:add(context.hero, context.hero)
            buff.leech = VAMPIRIC_LEECH
            buff:duration(VAMPIRIC_DURATION)
            UnitRefreshBuff(context.hero, buff)
        end
    })

    local function potion_at(pid, index)
        local profile = Profile[pid]
        return profile and profile.hero and
                   profile.hero.items[POTION_INDEX + index - 1] or nil
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
        return GetItemName(item.obj), BlzGetItemIconPath(item.obj),
               item.tooltip or BlzGetItemDescription(item.obj)
    end

    ---Applies the item's dynamic presentation to its backing native handle.
    ---@param item Item
    function PotionService.refreshItem(item)
        if not item or not item.alive or item.type ~= TYPE_POTION_INDEX then
            return
        end
        item:update(true)
    end

    ---@param item Item
    ---@param infusion integer
    function PotionService.setInfusion(item, infusion)
        if not item or item.type ~= TYPE_POTION_INDEX then return false end
        local changed
        if infusion == INFUSION_VAMPIRIC then
            changed = RuntimeItemDefinitions.apply(item, BLOOD_FLASK_KEY, false)
        else
            RuntimeItemDefinitions.clear(item)
            changed = true
        end
        if item.pid then NotifyItemChanged(item.pid) end
        return changed
    end

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
        return {
            charges = item.charges,
            maximum_charges = stats[ITEM_CHARGES],
            level_requirement = item.data[ITEM_LEVEL_REQUIREMENT],
            flat_health = stats[ITEM_FLAT_HEAL],
            percent_health = stats[ITEM_PERCENT_HEAL],
            flat_mana = stats[ITEM_FLAT_MANA],
            percent_mana = stats[ITEM_PERCENT_MANA],
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
        return refinement_index(item, stat) ~= nil
    end

    ---Rerolls one eligible potion property. Currency/material consumption is
    ---intentionally left to the future brewing transaction that calls this.
    ---@param item Item
    ---@param stat integer
    ---@return boolean success
    ---@return number? old_value
    ---@return number? new_value
    function PotionService.refine(item, stat)
        local quality_index = refinement_index(item, stat)
        if not quality_index or quality_index > QUALITY_SAVED then
            return false
        end

        local old_value = item.cached_stats[stat]
        item.quality[quality_index] = GetRandomInt(0, 63)
        item:update(true)

        if stat == ITEM_CHARGES then
            item.charges = math.min(item.charges,
                                    item.cached_stats[ITEM_CHARGES])
        end

        if item.pid then NotifyItemChanged(item.pid) end
        return true, old_value, item.cached_stats[stat]
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
        local replaces_restoration =
            behavior and behavior.replaces_restoration == true
        local heal =
            replaces_restoration and 0. or stats[ITEM_FLAT_HEAL] + 0.01 *
                stats[ITEM_PERCENT_HEAL] * Unit[hero].hp
        local mana =
            replaces_restoration and 0. or stats[ITEM_FLAT_MANA] + 0.01 *
                stats[ITEM_PERCENT_MANA] * Unit[hero].mana

        item.charges = item.charges - 1
        if heal > 0 then
            local name = PotionService.describe(item)
            HP(hero, hero, heal, name)
        end
        if mana > 0 then MP(hero, mana) end
        if behavior and behavior.on_use then
            behavior.on_use({
                pid = pid,
                item = item,
                hero = hero,
                unit = Unit[hero]
            })
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
            (second.extra[2] or INFUSION_NONE) == INFUSION_NONE then
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
