-- Development-only architecture regression checks.
OnInit.final("ArchitectureTests", function(Require)
    Require('Events')
    Require('InventoryService')
    Require('StashService')
    Require('ShopTransaction')
    Require('ShopRegistry')
    Require('TownShops')
    Require('ColosseumShop')
    Require('Honor')
    Require('HonorMilestones')
    Require('FactionShop')
    Require('EvilShopkeeperShop')
    Require('Recipe')
    Require('TimerQueue')
    Require('Profile')
    Require('Progression')
    Require('RewardNotifications')
    Require('SaveSchema')
    Require('DevRuntimeLog')
    Require('ShopServiceDialogs')
    Require('Town')
    Require('BossAbilities')
    Require('Buffs')
    Require('TableHelpers')
    Require('Geometry')
    Require('Effects')
    Require('Groups')
    Require('TextHelpers')
    Require('FrameHelpers')
    Require('Audio')
    Require('UnitAnimation')
    Require('UnitHelpers')
    Require('ItemHelpers')
    Require('AbilityCasting')
    Require('PlayerLifecycle')
    Require('SummonHelpers')
    Require('Rawcodes')
    Require('ItemSchema')
    Require('StatSchema')
    Require('StatValues')
    Require('HeroDefinitions')
    Require('BossSchema')
    Require('MainMap')
    Require('HelpText')
    Require('HintConfig')
    Require('CurrencyDisplay')
    Require('ResourceChanges')
    Require('Faction')
    Require('FactionView')
    Require('FactionMining')
    Require('FactionEvents')
    Require('CaveVoyagers')
    Require('Stormwatch')
    Require('AshenVanguard')
    Require('DropTable')
    Require('StruggleRewards')
    Require('Perks')
    Require('PotionService')
    Require('ShopServices')
    Require('FactionConsumables')
    Require('ItemUse')

    ArchitectureTests = {tests = {}}

    function ArchitectureTests.register(name, test)
        ArchitectureTests.tests[#ArchitectureTests.tests + 1] = {
            name = name,
            run = test
        }
    end

    ArchitectureTests.register(
        "event guard suppresses recursion and then clears", function()
            local event = EVENT.create()
            local subject = {}
            local calls = 0
            local function recurse_once()
                calls = calls + 1
                event:trigger(subject)
            end

            event:register_unit_action(subject, recurse_once)
            event:trigger(subject)
            event:trigger(subject)
            if calls ~= 2 then
                return false,
                       "event recursion guard did not clear between dispatches"
            end
            return true
        end)

    ArchitectureTests.register(
        "player event dispatch tolerates callback removal", function()
            local event = PLAYER_EVENT.create()
            local first_calls = 0
            local second_calls = 0
            local remove_self

            remove_self = function(pid)
                first_calls = first_calls + 1
                event:unregister_action(pid, remove_self)
            end
            local function remain_registered()
                second_calls = second_calls + 1
            end

            event:register_action(1, remove_self)
            event:register_action(1, remain_registered)
            event:trigger(1)
            event:trigger(1)

            if first_calls ~= 1 or second_calls ~= 2 then
                return false, "player event mutation changed callback dispatch"
            end
            return true
        end)

    ArchitectureTests.register("initializer trace is complete and unique",
                               function()
        local seen = {}

        for index = 1, #InitTrace do
            local entry = InitTrace[index]
            if seen[entry.name] then
                return false, "initializer ran more than once: " .. entry.name
            end
            if entry.status ~= "completed" then
                return false, "initializer did not complete: " .. entry.name
            end
            seen[entry.name] = true
        end

        if RuntimeMetrics.initializers.started ~=
            RuntimeMetrics.initializers.completed then
            return false, "initializer start/completion counters differ"
        end
        return true
    end)

    ArchitectureTests.register("configuration schemas preserve compatibility",
                               function()
        if DUMMY_CASTER ~= FourCC('e011') or SUMMON_BRUTE ~= FourCC('H05G') then
            return false, "rawcode exports changed"
        end
        if ITEM_LEVEL ~= 1 or PLAYER_TIME ~= 44 or STATUS_RESISTANCE ~= 45 or
            TOTAL_STATS ~= 45 or COOLDOWN_ACCELERATION ~= 46 or
            DROP_RATE ~= 47 or BOSS_DROP_RATE ~= 48 then
            return false, "serialized item stat indexes changed"
        end
        if #LIMIT_STRING ~= 28 or TIER_NAME[25] ~= "|cff999999Devourer|r" then
            return false, "item metadata changed"
        end
        if SPRITE_RARITY[0] ~= "war3mapImported\\CommonBorder.dds" or
            SPRITE_RARITY[2] ~= "war3mapImported\\RareBorder.dds" or
            SPRITE_RARITY[MAX_ITEM_RARITY_INDEX] ~=
            "war3mapImported\\ChaosBorder.dds" then
            return false, "inventory rarity border mapping changed"
        end
        if STAT_TAG[ITEM_DAMAGE].syntax ~= "damage" or
            type(STAT_TAG[ITEM_DAMAGE].getter) ~= "function" or
            type(STAT_TAG[ITEM_DAMAGE_RESIST].breakdown) ~= "function" or
            type(STAT_TAG[DROP_RATE].getter) ~= "function" or
            type(STAT_TAG[BOSS_DROP_RATE].getter) ~= "function" then
            return false, "stat schema or runtime values are unavailable"
        end
        if math.abs(Unit.calculateStatusDuration(10., 0.25) - 7.5) > 0.001 or
            math.abs(Unit.calculateStatusDuration(10., 10.) - 2.5) > 0.001 then
            return false, "status resistance duration formula changed"
        end
        if HERO_TOTAL ~= 19 or HERO_STATS[HERO_DARK_SUMMONER].skills[6] ~=
            "A002" then return false, "hero definitions changed" end
        if BOSS_TAUREN ~= 1 or BOSS_XALLARATH ~= 28 then
            return false, "boss registry indexes changed"
        end
        if MAIN_MAP.rect ~= gg_rct_Main_Map or MAIN_MAP.centerX ~=
            (MAIN_MAP.minX + MAIN_MAP.maxX) / 2. or MAIN_MAP.centerY ~=
            (MAIN_MAP.minY + MAIN_MAP.maxY) / 2. then
            return false, "main map geometry changed"
        end
        if #INFO_STRING ~= 6 or #HINT_TOOLTIP ~= 16 or not FORCE_HINT then
            return false, "help, hint, or progression compatibility changed"
        end
        return true
    end)

    ArchitectureTests.register("pre-chaos potion definitions are usable",
                               function()
        local cases = {
            {PotionService.GREATER_HEALTH_KEY, FourCC('I02F'), 50, 3, 4,
             ITEM_FLAT_HEAL},
            {PotionService.GREATER_MANA_KEY, FourCC('I00E'), 50, 3, 4,
             ITEM_FLAT_MANA},
            {PotionService.SUPERIOR_HEALTH_KEY, FourCC('I02F'), 110, 4, 5,
             ITEM_FLAT_HEAL},
            {PotionService.SUPERIOR_MANA_KEY, FourCC('I00E'), 110, 4, 5,
             ITEM_FLAT_MANA},
            {PotionService.GRAND_HEALTH_KEY, FourCC('I02F'), 170, 5, 6,
             ITEM_FLAT_HEAL},
            {PotionService.GRAND_MANA_KEY, FourCC('I00E'), 170, 5, 6,
             ITEM_FLAT_MANA}
        }

        for index = 1, #cases do
            local case = cases[index]
            local item = PotionService.create(case[1], 30000., 30000.)
            local properties = PotionService.getProperties(item)
            local customization = PotionService.getCustomization(item)
            local expected_skin = case[2] == FourCC('I00E') and
                                      FourCC('pman') or FourCC('phea')
            local expected_icon = case[2] == FourCC('I00E') and
                                      "ReplaceableTextures\\CommandButtons\\BTNPotionBlue.blp" or
                                      "ReplaceableTextures\\CommandButtons\\BTNPotionGreen.blp"
            local valid = item and item.id == case[2] and properties and
                              customization and customization.capacity == 0 and
                              customization.prefix == nil and
                              customization.suffix == nil and
                              item.runtime_definition.world_skin_id ==
                              expected_skin and
                              BlzGetItemIconPath(item.obj) == expected_icon and
                              properties.level_requirement == case[3] and
                              properties.maximum_charges >= case[4] and
                              properties.maximum_charges <= case[5] and
                              properties.charges ==
                              properties.maximum_charges and
                              item.cached_stats[case[6]] > 0

            if valid then
                item.charges = 0
                valid = PotionService.refill(item) and
                            item.charges == properties.maximum_charges
            end

            if item then item:destroy() end
            if not valid then
                return false, "invalid potion definition " .. tostring(case[1])
            end
        end

        local starter = ItemRuntime.create(FourCC('I02F'), 30000., 30000.)
        PotionService.refreshItem(starter)
        local starter_valid = starter and starter.tooltip and
                                  starter.tooltip:find(
                                      "+ |cffffcc003|r Cooldown", 1, true)
        if starter then starter:destroy() end
        if not starter_valid then
            return false, "starter flask tooltip is missing its cooldown"
        end

        local grand = PotionService.PRECHAOS_TIERS[3]
        if not grand or grand.flat_min ~= 6000 or grand.flat_max ~= 9000 or
            grand.percent_min ~= 16 or grand.percent_max ~= 20 then
            return false, "Grand Flask restoration range changed"
        end

        return true
    end)

    ArchitectureTests.register("faction potion definitions are usable",
                               function()
        local cases = {
            {PotionService.STONEBLOOD_KEY, FourCC('I02F'), 21000, 0},
            {PotionService.TEMPEST_KEY, FourCC('I00E'), 0, 21000},
            {PotionService.HUNTERS_KEY, FourCC('I02F'), 10500, 10500}
        }

        for index = 1, #cases do
            local case = cases[index]
            local item = PotionService.create(case[1], 30000., 30000.)
            local properties = PotionService.getProperties(item)
            local expected_skin = case[2] == FourCC('I00E') and
                                      FourCC('pman') or FourCC('phea')
            local valid = item and item.id == case[2] and properties and
                              item.runtime_definition.world_skin_id ==
                              expected_skin and
                              properties.level_requirement == 200 and
                              properties.maximum_charges >= 4 and
                              properties.maximum_charges <= 8 and
                              properties.charges ==
                              properties.maximum_charges and
                              properties.flat_health >= 0 and
                              properties.flat_health <= case[3] and
                              properties.flat_mana >= 0 and
                              properties.flat_mana <= case[4] and
                              item.tooltip:find(
                                  "|cffff0000Level Requirement: |r200", 1,
                                  true) and item.tooltip:find(
                                  "|cffff0000Faction Rank Requirement: |r4",
                                  1, true) and item.tooltip:find(
                                  "|cff0080c0", 1, true) and
                              (item.alt_tooltip:find(
                                  "|cffff5555(-30%)|r", 1, true) or
                                  item.alt_tooltip:find(
                                      "|cffff5555(-60%)|r", 1, true)) and
                              not item.tooltip:find(
                                  "Restoration Effectiveness", 1, true)

            if valid then
                item.charges = 0
                valid = PotionService.refill(item) and
                            item.charges == properties.maximum_charges
            end

            if valid and properties.percent_health > 0 then
                valid = item.tooltip:find("Max Health Restored", 1, true) ~= nil
            end
            if item then item:destroy() end
            if not valid then
                return false, "invalid faction potion " .. tostring(case[1])
            end
        end

        local shop_ids = {'n004', 'n0P0', 'n0P1'}
        local expected_offer_counts = {3, 3, 3}
        local restoration_ranges = {
            "10500-21000", "10500-21000", "5250-10500"
        }
        for index = 1, #shop_ids do
            local shop = ShopRegistry.get(FourCC(shop_ids[index]))
            if not shop or #shop.offers ~= expected_offer_counts[index] then
                return false, "Faction Shop offers are missing from " ..
                           shop_ids[index]
            end
            if type(shop.access) ~= "function" then
                return false, "Faction Shop access gate is missing from " ..
                           shop_ids[index]
            end
            local tooltip = shop.offers[1]:getTooltip(1)
            if not tooltip:find("|cff0080c0", 1, true) then
                return false, "Faction Shop tooltip lost its flask affix"
            end
            if not tooltip:find(restoration_ranges[index], 1, true) or
                not tooltip:find("2.5-5|r Cooldown", 1, true) then
                return false, "Faction Shop tooltip does not show roll ranges"
            end
            local faction = Faction[index]
            if not faction or GetUnitTypeId(faction.shop) ~=
                FourCC(shop_ids[index]) then
                return false, "Faction uses the wrong shop unit type"
            end
        end
        return true
    end)

    ArchitectureTests.register(
        "direct-use faction items preserve runtime identity", function()
            local cases = {
                {
                    FactionConsumables.STORMWISE_BEACON_KEY,
                    "Stormwise Beacon", "Stormwise Beacon", 4,
                    "Shares your current Stormwatch blessing"
                }, {
                    FactionConsumables.GOBLIN_SPACE_LASER_KEY,
                    "Goblin Space Laser", "Atmospheric Correction", 2,
                    "Rerolls the current weather"
                }, {
                    FactionConsumables.REINFORCED_PIT_PROP_KEY,
                    "Reinforced Pit Prop", "Reinforced Support", 4,
                    "Shares your current Cave Voyagers blessing"
                }, {
                    FactionConsumables.SEISMIC_SURVEY_CHARGE_KEY,
                    "Seismic Survey Charge", "Seismic Survey", 2,
                    "Relocates every unclaimed ore deposit"
                }, {
                    FactionConsumables.CAMPAIGN_STANDARD_KEY,
                    "Campaign Standard", "Rallying Standard", 4,
                    "Shares your current Ashen Vanguard blessing"
                }, {
                    FactionConsumables.VANGUARD_BOUNTY_KEY,
                    "Vanguard Bounty", "Marked Quarry", 4,
                    "Boss Drop Rate"
                }
            }

            for index = 1, #cases do
                local case = cases[index]
                local item = RuntimeItemDefinitions.create(case[1], 30000.,
                                                           30000.)
                if not item then
                    return false, "could not create " .. case[1]
                end
                local saved_id = item:encode_id()
                local saved_stats = item:encode_stats()
                local saved_extra = item:encode_extra()
                local saved_state = item:encode_state()
                item:destroy()

                local restored = Item.decode(saved_id, saved_stats,
                                             saved_extra, saved_state)
                local valid = restored and
                                  RuntimeItemDefinitions.is(restored, case[1]) and
                                  ItemUse.isUsable(restored) and
                                  restored.type == TYPE_CONSUMABLE_INDEX and
                                  restored.runtime_definition.data[ITEM_TIER] == 1 and
                                  GetItemName(restored.obj) == case[2] and
                                  restored.tooltip:find(
                                      "|cffff0000Faction Rank Requirement: |r" ..
                                          case[4], 1, true) and
                                  restored.tooltip:find(
                                      "|cff0080c0" .. case[3] .. ":|r", 1,
                                      true) and
                                  restored.tooltip:find(case[5], 1, true) and
                                  restored.tooltip:find("|cff808080", 1, true)
                if restored then restored:destroy() end
                if not valid then
                    return false, case[1] ..
                               " did not retain its direct-use presentation"
                end
            end

            local basic = ItemRuntime.create(FourCC('I00K'), 30000., 30000.)
            local advanced = ItemRuntime.create(FourCC('I00U'), 30000.,
                                                30000.)
            local chisels_are_usable = ItemUse.isUsable(basic) and
                                           ItemUse.isUsable(advanced) and
                                           basic.type == TYPE_CONSUMABLE_INDEX and
                                           advanced.type == TYPE_CONSUMABLE_INDEX
            if basic then basic:destroy() end
            if advanced then advanced:destroy() end
            if not chisels_are_usable then
                return false, "socketing chisels lack direct Use handlers"
            end

            local stormwatch_shop = ShopRegistry.get(FourCC('n0P0'))
            local offer_keys = {}
            for index = 1, #stormwatch_shop.offers do
                offer_keys[stormwatch_shop.offers[index].key] = true
            end
            if not offer_keys.stormwatch_stormwise_beacon or
                not offer_keys.stormwatch_goblin_space_laser then
                return false, "Stormwatch consumable offers are missing"
            end
            local cave_shop = ShopRegistry.get(FourCC('n004'))
            local ashen_shop = ShopRegistry.get(FourCC('n0P1'))
            if #cave_shop.offers ~= 3 or #ashen_shop.offers ~= 3 then
                return false, "faction consumable shop offers are missing"
            end
            local expected_prices = {
                cave_voyagers_reinforced_pit_prop = 100,
                cave_voyagers_seismic_survey_charge = 20,
                stormwatch_stormwise_beacon = 100,
                stormwatch_goblin_space_laser = 50,
                ashen_vanguard_bounty = 150,
            }
            for _, shop in ipairs({ cave_shop, stormwatch_shop, ashen_shop }) do
                for index = 1, #shop.offers do
                    local offer = shop.offers[index]
                    local expected = expected_prices[offer.key]
                    if expected and offer:getPrice(1)[FACTION] ~= expected then
                        return false, offer.key .. " has the wrong price"
                    end
                    expected_prices[offer.key] = nil
                end
            end
            if next(expected_prices) then
                return false, "a priced faction consumable offer is missing"
            end
            if type(FactionMining.refreshDeposits) ~= "function" or
                type(CaveVoyagersServices.shareBlessing) ~= "function" or
                type(AshenVanguardServices.shareBlessing) ~= "function" or
                type(AshenVanguardServices.hasBounty) ~= "function" or
                type(AshenVanguardServices.armBounty) ~= "function" or
                type(AshenVanguardServices.consumeBountyForBoss) ~= "function" or
                type(Faction.registerQuestCompletionAction) ~= "function" or
                type(Faction.leaveForTesting) ~= "function" then
                return false, "faction consumable services are unavailable"
            end
            local bounty_offer
            for index = 1, #ashen_shop.offers do
                if ashen_shop.offers[index].key == "ashen_vanguard_bounty" then
                    bounty_offer = ashen_shop.offers[index]
                    break
                end
            end
            if not bounty_offer or bounty_offer:getPrice(1)[FACTION] ~= 150 or
                bounty_offer:getName(1) ~= "Vanguard Bounty" or
                not bounty_offer:getTooltip(1):find("Boss Drop Rate", 1, true) then
                return false, "Vanguard Bounty shop offer is invalid"
            end
            return true
        end)

    ArchitectureTests.register("Chaos affix donor flasks are saveable",
                               function()
        local keys = PotionService.getChaosDonorKeys()
        local prefix_keys = PotionService.getChaosDonorKeys("prefix")
        local suffix_keys = PotionService.getChaosDonorKeys("suffix")
        if #keys ~= 14 or #prefix_keys ~= 8 or #suffix_keys ~= 6 then
            return false, string.format(
                "Chaos donor pools have %d/%d/%d total/prefix/suffix entries",
                #keys, #prefix_keys, #suffix_keys)
        end

        for _, key in ipairs(keys) do
            local item = PotionService.create(key, 30000., 30000.)
            local customization = PotionService.getCustomization(item)
            local properties = PotionService.getProperties(item)
            local occupied = customization and
                                 ((customization.prefix and 1 or 0) +
                                 (customization.suffix and 1 or 0)) or 0
            local expected_name = customization and customization.prefix and
                                      customization.prefix.affix_name ..
                                          " Flask" or
                                      customization and customization.suffix and
                                          "Flask of " ..
                                              customization.suffix.affix_name
            local charge_position = item and item.tooltip and
                                        item.tooltip:find("Charges", 1, true)
            local cooldown_position = item and item.tooltip and
                                          item.tooltip:find("Cooldown", 1, true)
            local flavor_position = item and item.tooltip and
                                        item.tooltip:find("|cff808080", 1,
                                                          true)
            local infusion_range_valid = key ~= "aegis_donor_flask" or
                                               (item and item.alt_tooltip and
                                                   item.alt_tooltip:find(
                                                       "18-22%", 1, true))
            local cooldown_range_valid = item and item.alt_tooltip and
                                             item.alt_tooltip:find(
                                                 "%d[%d%.]*%-%d[%d%.]*|r Cooldown")
            if not item or not customization or not properties or
                customization.capacity ~= 1 or occupied ~= 1 or
                properties.level_requirement ~= 200 or
                properties.maximum_charges < 4 or
                properties.maximum_charges > 8 or
                GetItemName(item.obj) ~= expected_name or
                GetItemName(item.obj):find("Infusion", 1, true) or
                GetItemName(item.obj):find("Catalyst", 1, true) or
                not flavor_position or not charge_position or
                not cooldown_position or cooldown_position < charge_position or
                not cooldown_range_valid or
                not infusion_range_valid then
                local details = string.format(
                    "name=%s/%s capacity=%s occupied=%s level=%s charges=%s positions=%s/%s/%s cooldown_range=%s infusion_range=%s",
                    tostring(item and GetItemName(item.obj)),
                    tostring(expected_name),
                    tostring(customization and customization.capacity),
                    tostring(occupied),
                    tostring(properties and properties.level_requirement),
                    tostring(properties and properties.maximum_charges),
                    tostring(charge_position), tostring(cooldown_position),
                    tostring(flavor_position),
                    tostring(cooldown_range_valid ~= nil and
                        cooldown_range_valid ~= false),
                    tostring(infusion_range_valid ~= nil and
                        infusion_range_valid ~= false))
                if item then item:destroy() end
                return false, "invalid Chaos donor " .. tostring(key) ..
                           ": " .. details
            end

            local saved_id = item:encode_id()
            local saved_stats = item:encode_stats()
            local saved_extra = item:encode_extra()
            local saved_state = item:encode_state()
            local expected_prefix = customization.prefix_id
            local expected_suffix = customization.suffix_id
            local expected_infusion_quality = customization.infusion_quality
            item:destroy()

            local restored = Item.decode(saved_id, saved_stats, saved_extra,
                                         saved_state)
            local restored_customization =
                PotionService.getCustomization(restored)
            local valid = restored and restored_customization and
                              restored.runtime_definition.key == key and
                              restored_customization.prefix_id ==
                              expected_prefix and
                              restored_customization.suffix_id ==
                              expected_suffix and
                              restored_customization.infusion_quality ==
                              expected_infusion_quality
            if restored then restored:destroy() end
            if not valid then
                return false, "Chaos donor did not round trip " ..
                           tostring(key)
            end
        end
        return true
    end)

    ArchitectureTests.register(
        "searched legendary flasks retain open affix presentation", function()
            local item = PotionService.create(
                             PotionService.LEGENDARY_CHAOS_KEY, 30000.,
                             30000., nil, false)
            if not item then return false, "could not create legendary flask" end
            item:lvl(0)
            PotionService.refreshItem(item)
            local valid = item.tooltip and
                              item.tooltip:find(
                                  "|cff808080Prefix:|r |cff40bf5fOpen|r", 1,
                                  true) and
                              item.tooltip:find(
                                  "|cff808080Suffix:|r |cff40bf5fOpen|r", 1,
                                  true) and
                              item.runtime_definition.world_skin_id ==
                                  FourCC('phea')
            item:destroy()
            if not valid then
                return false,
                       "Legendary Flask lost open affixes or potion world skin after search leveling"
            end
            return true
        end)

    ArchitectureTests.register("Bounty suffix increases restoration",
                               function()
        local item = PotionService.create(
                         PotionService.LEGENDARY_CHAOS_KEY, 30000., 30000.)
        if not item then return false, "could not create legendary flask" end
        if item.cached_lower[ITEM_FLAT_HEAL] ~= 20000 or
            item.cached_upper[ITEM_FLAT_HEAL] ~= 40000 or
            item.cached_lower[ITEM_FLAT_MANA] ~= 20000 or
            item.cached_upper[ITEM_FLAT_MANA] ~= 40000 then
            item:destroy()
            return false, "Legendary Flask flat restoration range changed"
        end
        local before = PotionService.getProperties(item)
        local applied = PotionService.setSuffix(
                            item, PotionService.CATALYST_BOUNTIFUL)
        local after = PotionService.getProperties(item)
        local expected_health = math.floor(before.flat_health * 1.25 + 0.5)
        local expected_mana = math.floor(before.flat_mana * 1.25 + 0.5)
        local valid = applied and after and
                          after.flat_health == expected_health and
                          after.flat_mana == expected_mana and
                          math.abs(after.restoration_multiplier - 1.25) < 0.001
        item:destroy()
        if not valid then
            return false, string.format(
                "Bounty restoration was %s/%s at multiplier %s; expected %s/%s at 1.25",
                tostring(after and after.flat_health),
                tostring(after and after.flat_mana),
                tostring(after and after.restoration_multiplier),
                tostring(expected_health), tostring(expected_mana))
        end
        return true
    end)

    ArchitectureTests.register("Chaos potion boss odds scale upward",
                               function()
        local low_donor, low_legendary =
            PotionService.getChaosBossDropChances(200, 1)
        local high_donor, high_legendary =
            PotionService.getChaosBossDropChances(500, 1)
        local challenge_donor, challenge_legendary =
            PotionService.getChaosBossDropChances(500, 5)
        local valid = math.abs(low_donor - 0.08) < 0.000001 and
                          math.abs(low_legendary - 0.00005) < 0.000001 and
                          high_donor > low_donor and
                          high_legendary > low_legendary and
                          challenge_donor > high_donor and
                          challenge_legendary > high_legendary and
                          challenge_donor <= 0.40 and
                          challenge_legendary <= 0.0025
        if not valid then
            return false, "Chaos boss potion odds are not level/difficulty scaled"
        end
        return true
    end)

    ArchitectureTests.register("runtime potion saves preserve identity and charges",
                               function()
        local cases = {
            {
                PotionService.STONEBLOOD_KEY, 0, FourCC('phea'),
                PotionService.INFUSION_TEMPEST, 0, "Tempest Flask"
            },
            {
                PotionService.LEGENDARY_CHAOS_KEY, 2, FourCC('phea'),
                PotionService.INFUSION_STONE,
                PotionService.CATALYST_ACCELERANT,
                "Stoneblood Flask of Acceleration"
            }
        }

        for index = 1, #cases do
            local case = cases[index]
            local item = PotionService.create(case[1], 30000., 30000.)
            if not item then
                return false, "could not create saved potion " ..
                           tostring(case[1])
            end

            item.charges = case[2]
            if not PotionService.setInfusion(item, case[4]) or
                (case[5] ~= 0 and
                    not PotionService.setCatalyst(item, case[5])) then
                item:destroy()
                return false, "could not customize saved potion " ..
                           tostring(case[1])
            end
            local expected = PotionService.getProperties(item)
            local maximum_charges = item.cached_stats[ITEM_CHARGES]
            local saved_id = item:encode_id()
            local saved_stats = item:encode_stats()
            local saved_extra = item:encode_extra()
            local saved_state = item:encode_state()
            item:destroy()

            local restored = Item.decode(saved_id, saved_stats, saved_extra,
                                         saved_state)
            local properties = PotionService.getProperties(restored)
            local customization = PotionService.getCustomization(restored)
            local valid = restored and properties and
                              RuntimeItemDefinitions.is(restored, case[1]) and
                              restored.runtime_definition.world_skin_id ==
                              case[3] and restored.charges == case[2] and
                              properties.charges == case[2] and
                              properties.maximum_charges == maximum_charges and
                              properties.flat_health == expected.flat_health and
                              properties.percent_health == expected.percent_health and
                              properties.flat_mana == expected.flat_mana and
                              properties.percent_mana == expected.percent_mana and
                              customization and
                              customization.infusion_id == case[4] and
                              customization.catalyst_id == case[5] and
                              GetItemName(restored.obj) == case[6] and
                              math.abs(properties.cooldown - expected.cooldown) <
                                  0.001 and
                              properties.cooldown_quality ==
                                  expected.cooldown_quality and
                              properties.infusion_quality ==
                                  expected.infusion_quality and
                              restored.tooltip:find(
                                  customization.infusion.name .. ":", 1,
                                  true) and
                              restored.tooltip:find("Prefix:", 1, true) and
                              restored.tooltip:find("Suffix:", 1, true) and
                              (not customization.catalyst or
                                  restored.tooltip:find(
                                      customization.catalyst.name .. ":", 1,
                                      true))

            if restored then restored:destroy() end
            if not valid then
                local actual = properties and string.format(
                    "identity=%s skin=%s charges=%s/%s restoration=%s/%s/%s/%s expected=%s/%s/%s/%s affixes=%s/%s cooldown=%s tooltip=%s/%s",
                    tostring(restored and RuntimeItemDefinitions.is(restored,
                        case[1])), tostring(restored and
                        restored.runtime_definition.world_skin_id == case[3]),
                    tostring(restored and restored.charges),
                    tostring(properties.maximum_charges),
                    tostring(properties.flat_health),
                    tostring(properties.percent_health),
                    tostring(properties.flat_mana),
                    tostring(properties.percent_mana),
                    tostring(expected.flat_health),
                    tostring(expected.percent_health),
                    tostring(expected.flat_mana),
                    tostring(expected.percent_mana),
                    tostring(customization and customization.infusion_id),
                    tostring(customization and customization.catalyst_id),
                    tostring(properties.cooldown),
                    tostring(restored and customization and
                        customization.infusion and
                        restored.tooltip:find(
                            customization.infusion.name .. ":", 1, true) ~= nil),
                    tostring(restored and customization and
                        (not customization.catalyst or
                            restored.tooltip:find(
                                customization.catalyst.name .. ":", 1,
                                true) ~= nil))) or "no properties"
                return false, "saved potion did not round trip " ..
                           tostring(case[1]) .. ": " .. actual
            end
        end

        return true
    end)

    ArchitectureTests.register("potion rerolls are save deterministic",
                               function()
        local source = PotionService.create(PotionService.HUNTERS_KEY,
                                            30000., 30000.)
        if not source then return false, "could not create chaos flask" end
        local saved_id = source:encode_id()
        local saved_stats = source:encode_stats()
        local saved_extra = source:encode_extra()
        local saved_state = source:encode_state()
        source:destroy()

        local first = Item.decode(saved_id, saved_stats, saved_extra,
                                  saved_state)
        local second = Item.decode(saved_id, saved_stats, saved_extra,
                                   saved_state)
        local initial_price = PotionBrewingService.getPrice(first, "reroll")
        local first_ok = PotionService.rerollRestoration(first)
        local second_ok = PotionService.rerollRestoration(second)
        local second_price = PotionBrewingService.getPrice(first, "reroll")
        local a = PotionService.getProperties(first)
        local b = PotionService.getProperties(second)
        local valid = first_ok and second_ok and a and b and
                          a.base_flat_health == b.base_flat_health and
                          a.base_percent_health == b.base_percent_health and
                          a.base_flat_mana == b.base_flat_mana and
                          a.base_percent_mana == b.base_percent_mana and
                          a.maximum_charges == b.maximum_charges and
                          math.abs(a.cooldown - b.cooldown) < 0.001 and
                          PotionService.getRerollCount(first) == 1 and
                          PotionService.getRerollCount(second) == 1 and
                          math.abs(second_price / initial_price - 1.35) < 0.002
        local failure_stage = valid and nil or "first reroll"

        -- Advance the persistent counter, save that state, and ensure the
        -- following candidate is also identical after a load. This catches
        -- seed-only implementations whose first roll is stable but whose
        -- sequence position is not actually persisted.
        local advanced_id = first:encode_id()
        local advanced_stats = first:encode_stats()
        local advanced_extra = first:encode_extra()
        local advanced_state = first:encode_state()
        local restored = Item.decode(advanced_id, advanced_stats,
                                     advanced_extra, advanced_state)
        local next_first_ok = PotionService.rerollRestoration(first)
        local next_restored_ok = PotionService.rerollRestoration(restored)
        local next_a = PotionService.getProperties(first)
        local next_b = PotionService.getProperties(restored)
        local continuation_valid = next_first_ok and next_restored_ok and
                                       next_a and next_b and
                                       next_a.base_flat_health ==
                                           next_b.base_flat_health and
                                       next_a.base_percent_health ==
                                           next_b.base_percent_health and
                                       next_a.base_flat_mana ==
                                           next_b.base_flat_mana and
                                       next_a.base_percent_mana ==
                                           next_b.base_percent_mana and
                                       next_a.maximum_charges ==
                                           next_b.maximum_charges and
                                       math.abs(next_a.cooldown -
                                           next_b.cooldown) < 0.001 and
                                       PotionService.getRerollCount(first) == 2 and
                                       PotionService.getRerollCount(restored) == 2
        if not continuation_valid and not failure_stage then
            failure_stage = "save continuation"
        end
        valid = valid and continuation_valid

        -- Run well past the old three-bit limit and require both identical
        -- copies to retain their full count and advance to a visible result.
        for roll = 3, 12 do
            local previous = PotionService.getProperties(first)
            local first_advanced = PotionService.rerollRestoration(first)
            local restored_advanced =
                PotionService.rerollRestoration(restored)
            local advanced_a = PotionService.getProperties(first)
            local advanced_b = PotionService.getProperties(restored)
            local visibly_changed = previous and advanced_a and
                                        (previous.base_flat_health ~=
                                            advanced_a.base_flat_health or
                                            previous.base_percent_health ~=
                                            advanced_a.base_percent_health or
                                            previous.base_flat_mana ~=
                                            advanced_a.base_flat_mana or
                                            previous.base_percent_mana ~=
                                                advanced_a.base_percent_mana or
                                            previous.maximum_charges ~=
                                                advanced_a.maximum_charges or
                                            math.abs(previous.cooldown -
                                                advanced_a.cooldown) > 0.001)
            local roll_valid = first_advanced and restored_advanced and
                                   advanced_a and advanced_b and
                                   visibly_changed and
                                   advanced_a.base_flat_health ==
                                       advanced_b.base_flat_health and
                                   advanced_a.base_percent_health ==
                                       advanced_b.base_percent_health and
                                   advanced_a.base_flat_mana ==
                                       advanced_b.base_flat_mana and
                                   advanced_a.base_percent_mana ==
                                       advanced_b.base_percent_mana and
                                   advanced_a.maximum_charges ==
                                       advanced_b.maximum_charges and
                                   math.abs(advanced_a.cooldown -
                                       advanced_b.cooldown) < 0.001 and
                                   PotionService.getRerollCount(first) == roll
            if not roll_valid and not failure_stage then
                failure_stage = "reroll " .. roll
            end
            valid = valid and roll_valid
        end

        local twelfth_price = PotionBrewingService.getPrice(first, "reroll")
        local price_valid = math.abs(twelfth_price / initial_price -
                                         1.35 ^ 12) < 0.002
        if not price_valid and not failure_stage then
            failure_stage = "twelfth price"
        end
        valid = valid and price_valid

        local capped_id = first:encode_id()
        local capped_stats = first:encode_stats()
        local capped_extra = first:encode_extra()
        local capped_state = first:encode_state()
        local capped_restore = Item.decode(capped_id, capped_stats,
                                           capped_extra, capped_state)
        local capped_first_ok = PotionService.rerollRestoration(first)
        local capped_restore_ok =
            PotionService.rerollRestoration(capped_restore)
        local capped_a = PotionService.getProperties(first)
        local capped_b = PotionService.getProperties(capped_restore)
        local continued_valid = capped_first_ok and capped_restore_ok and
                                    capped_a and capped_b and
                                    capped_a.base_flat_health ==
                                        capped_b.base_flat_health and
                                    capped_a.base_percent_health ==
                                        capped_b.base_percent_health and
                                    capped_a.base_flat_mana ==
                                        capped_b.base_flat_mana and
                                    capped_a.base_percent_mana ==
                                        capped_b.base_percent_mana and
                                    capped_a.maximum_charges ==
                                        capped_b.maximum_charges and
                                    math.abs(capped_a.cooldown -
                                        capped_b.cooldown) < 0.001
        if not continued_valid and not failure_stage then
            failure_stage = "post-twelve save continuation"
        end
        valid = valid and continued_valid

        for _, stat in ipairs(PotionService.ROLLABLE_STATS) do
            local quality_index = first.data.quality_index[stat]
            if quality_index then first.quality[quality_index] = 63 end
        end
        first.persistent_state[PotionService.COOLDOWN_QUALITY_STATE] = 63
        first.persistent_state[PotionService.INFUSION_QUALITY_STATE] = 63
        PotionService.refreshItem(first)
        local perfect = PotionService.getRestorationRollResult(first)
        valid = valid and perfect and perfect.perfect and
                    perfect.near_perfect and perfect.text ~= ""

        for _, stat in ipairs(PotionService.ROLLABLE_STATS) do
            local quality_index = first.data.quality_index[stat]
            if quality_index then first.quality[quality_index] = 60 end
        end
        first.persistent_state[PotionService.COOLDOWN_QUALITY_STATE] = 60
        first.persistent_state[PotionService.INFUSION_QUALITY_STATE] = 60
        PotionService.refreshItem(first)
        local near_perfect = PotionService.getRestorationRollResult(first)
        valid = valid and near_perfect and not near_perfect.perfect and
                    near_perfect.near_perfect
        if first then first:destroy() end
        if second then second:destroy() end
        if restored then restored:destroy() end
        if capped_restore then capped_restore:destroy() end
        if not valid then
            return false, "identical saves produced different rerolls at " ..
                       tostring(failure_stage) .. " (counts " ..
                       PotionService.getRerollCount(first) .. "/" ..
                       PotionService.getRerollCount(restored) .. ", prices " ..
                       initial_price .. "/" .. twelfth_price .. ")"
        end
        return true
    end)

    ArchitectureTests.register("potion reroll choices preserve their sequence",
                               function()
        local source = PotionService.create(PotionService.STONEBLOOD_KEY,
                                            30000., 30000.)
        if not source then return false, "could not create chaos flask" end
        local saved_id = source:encode_id()
        local saved_stats = source:encode_stats()
        local saved_extra = source:encode_extra()
        local saved_state = source:encode_state()
        source:destroy()

        local health_flask = Item.decode(saved_id, saved_stats, saved_extra,
                                         saved_state)
        local mana_flask = Item.decode(saved_id, saved_stats, saved_extra,
                                       saved_state)
        if not health_flask or not mana_flask then
            if health_flask then health_flask:destroy() end
            if mana_flask then mana_flask:destroy() end
            return false, "could not restore choice test flasks"
        end

        local function same_options(first, second)
            if not first or not second or #first ~= #second then return false end
            for option_index = 1, #first do
                local a = first[option_index]
                local b = second[option_index]
                if a.mode ~= b.mode or a.attempt ~= b.attempt or
                    a.text ~= b.text or #a.rolls ~= #b.rolls then
                    return false
                end
                for roll_index = 1, #a.rolls do
                    if a.rolls[roll_index] ~= b.rolls[roll_index] then
                        return false
                    end
                end
            end
            return true
        end

        local first_health = PotionService.beginRestorationReroll(health_flask)
        local first_mana = PotionService.beginRestorationReroll(mana_flask)
        local valid = same_options(first_health, first_mana)

        -- A generated but unanswered choice must survive save/load verbatim.
        local pending_id = health_flask:encode_id()
        local pending_stats = health_flask:encode_stats()
        local pending_extra = health_flask:encode_extra()
        local pending_state = health_flask:encode_state()
        local pending_restore = Item.decode(pending_id, pending_stats,
                                            pending_extra, pending_state)
        local restored_options = pending_restore and
                                     PotionService.getPendingRestorationReroll(
                                         pending_restore)
        valid = valid and same_options(first_health, restored_options)

        local attempt = first_health and first_health[1].attempt
        valid = valid and attempt ~= nil and
                    PotionService.acceptRestorationReroll(
                        health_flask, attempt, PotionService.RESTORATION_HEALTH) and
                    PotionService.acceptRestorationReroll(
                        mana_flask, attempt, PotionService.RESTORATION_MANA)
        local health = PotionService.getProperties(health_flask)
        local mana = PotionService.getProperties(mana_flask)
        valid = valid and health and mana and health.flat_health > 0 and
                    health.percent_health > 0 and health.flat_mana == 0 and
                    health.percent_mana == 0 and mana.flat_health == 0 and
                    mana.percent_health == 0 and mana.flat_mana > 0 and
                    mana.percent_mana > 0

        -- Different accepted choices must not perturb any future candidate.
        local next_health = PotionService.beginRestorationReroll(health_flask)
        local next_mana = PotionService.beginRestorationReroll(mana_flask)
        valid = valid and same_options(next_health, next_mana)

        health_flask:destroy()
        mana_flask:destroy()
        if pending_restore then pending_restore:destroy() end
        if not valid then
            return false, "choice, pending save, or future sequence diverged"
        end
        return true
    end)

    ArchitectureTests.register("potion rerolls permanently lock one property",
                               function()
        local item = PotionService.create(PotionService.STONEBLOOD_KEY,
                                          30000., 30000.)
        if not item then return false, "could not create category test flask" end

        local restoration_before = PotionService.getProperties(item)
        local cooldown_before = PotionService.getCooldownQuality(item)
        local prefix_before = PotionService.getInfusionQuality(item)
        local charges_index = item.data.quality_index[ITEM_CHARGES]
        local all_available =
            PotionService.canRerollCategory(
                item, PotionService.REROLL_RESTORATION) and
                PotionService.canRerollCategory(
                    item, PotionService.REROLL_CHARGES) and
                PotionService.canRerollCategory(
                    item, PotionService.REROLL_COOLDOWN) and
                PotionService.canRerollCategory(
                    item, PotionService.REROLL_PREFIX)
        local options = PotionService.beginReroll(
                            item, PotionService.REROLL_CHARGES)
        local accepted = options and PotionService.acceptReroll(
                             item, options[1].attempt, options[1].option)
        local restoration_after = PotionService.getProperties(item)
        local locked = PotionService.getRerollCategory(item) ==
                           PotionService.REROLL_CHARGES and
                           PotionService.canRerollCategory(
                               item, PotionService.REROLL_CHARGES) and
                           not PotionService.canRerollCategory(
                               item, PotionService.REROLL_RESTORATION) and
                           not PotionService.canRerollCategory(
                               item, PotionService.REROLL_COOLDOWN) and
                           not PotionService.canRerollCategory(
                               item, PotionService.REROLL_PREFIX)
        local isolated = restoration_before and restoration_after and
                             restoration_before.base_flat_health ==
                                 restoration_after.base_flat_health and
                             restoration_before.base_percent_health ==
                                 restoration_after.base_percent_health and
                             restoration_before.base_flat_mana ==
                                 restoration_after.base_flat_mana and
                             restoration_before.base_percent_mana ==
                                 restoration_after.base_percent_mana and
                             PotionService.getCooldownQuality(item) ==
                                 cooldown_before and
                             PotionService.getInfusionQuality(item) ==
                                 prefix_before and charges_index and options and
                             item.quality[charges_index] == options[1].rolls[1]
        item:destroy()
        if not (all_available and accepted and locked and isolated) then
            return false, "category was unavailable, mutable, or changed another property"
        end
        return true
    end)

    ArchitectureTests.register("charged items preserve charges when saved",
                               function()
        -- Sword of Revival exercises the ordinary managed-item path rather
        -- than the runtime potion-definition path above. Zero is included so
        -- rechargeable resurrection items remain empty after loading.
        local saved_charge_counts = {0, 2}
        for index = 1, #saved_charge_counts do
            local charges = saved_charge_counts[index]
            local item = ItemRuntime.create(FourCC('I01X'), 30000., 30000.)
            if not item then return false, "could not create charged item" end

            item.charges = charges
            local saved_id = item:encode_id()
            local saved_stats = item:encode_stats()
            local saved_extra = item:encode_extra()
            item:destroy()

            local restored = Item.decode(saved_id, saved_stats, saved_extra)
            local valid = restored and restored.id == FourCC('I01X') and
                              restored.charges == charges
            if restored then restored:destroy() end

            if not valid then
                return false, "charged item did not retain " .. charges ..
                           " charges"
            end
        end

        local legacy = ItemRuntime.create(FourCC('I01X'), 30000., 30000.)
        if not legacy then return false, "could not create legacy charged item" end
        local default_charges = legacy.charges
        local legacy_id = legacy:encode_id()
        local legacy_stats = legacy:encode_stats()
        legacy:destroy()

        -- Unmarked saves predate charge persistence and must keep the item's
        -- object-data default rather than being interpreted as zero charges.
        local restored_legacy = Item.decode(legacy_id, legacy_stats, 0)
        local legacy_valid = restored_legacy and
                                 restored_legacy.charges == default_charges
        if restored_legacy then restored_legacy:destroy() end
        if not legacy_valid then
            return false, "legacy charged item lost its default charges"
        end
        return true
    end)

    ArchitectureTests.register("owned helper families remain available",
                               function()
        local values = {"first", "second", "third"}
        TableRemove(values, "second")

        if #values ~= 2 or TableHas(values, "second") then
            return false, "table helper compatibility changed"
        end
        if math.abs(DistanceCoords(0., 0., 3., 4.) - 5.) > 0.0001 then
            return false, "geometry helper compatibility changed"
        end
        if type(MakeGroupInRange) ~= "function" or type(FilterEnemy) ~=
            "function" then
            return false, "group helper exports are unavailable"
        end
        if type(HideEffect) ~= "function" or type(Fade) ~= "function" or
            type(FadeSFX) ~= "function" then
            return false, "effect helper exports are unavailable"
        end
        if RealToString(1234567) ~= "1,234,567" or HealthGradient(1, true) ~=
            "|cffFF0000" then
            return false, "text helper compatibility changed"
        end
        if type(GetMainSelectedUnit) ~= "function" or
            type(FrameAddSimpleTooltip) ~= "function" or type(reselect) ~=
            "function" then
            return false, "frame helper exports are unavailable"
        end
        if type(SoundHandler) ~= "function" or type(DelayAnimation) ~=
            "function" or type(UnitDisableAbility) ~= "function" or
            type(HighestStat) ~= "function" then
            return false, "unit and audio helper exports are unavailable"
        end
        if type(GetItem) ~= "function" or type(CastSpell) ~= "function" or
            type(PlayerCleanup) ~= "function" or type(SummonExpire) ~=
            "function" then
            return false, "gameplay helper exports are unavailable"
        end
        return true
    end)

    ArchitectureTests.register("save wire preserves sparse physical slots",
                               function()
        local long_code = string.rep("0123456789", 73)
        for slot = 1, MAX_SLOTS do
            local payload = slot == 17 and "" or long_code
            local messages = SaveWire.encodeCharacter(slot, payload)
            local assembly = {}
            local decoded_payload
            -- Deliberately assemble in reverse order to ensure receipt order
            -- is not part of the wire contract.
            for message_index = #messages, 1, -1 do
                local decoded_slot, index, total, chunk =
                    SaveWire.decodeCharacter(messages[message_index])
                if decoded_slot ~= slot then
                    return false, "save wire changed physical slot " .. slot
                end
                local valid
                decoded_payload, valid = SaveWire.accept(assembly, slot,
                                                          index, total, chunk)
                if not valid then
                    return false, "save wire rejected valid chunks"
                end
            end
            if decoded_payload ~= payload then
                return false, "save wire changed slot payload " .. slot
            end
        end

        local profile = SaveWire.encodeProfile(long_code)
        local profile_assembly = {}
        local decoded_profile
        for index = 1, #profile do
            local part, total, chunk = SaveWire.decodeProfile(profile[index])
            decoded_profile = SaveWire.accept(profile_assembly, 1, part, total,
                                               chunk)
        end
        if decoded_profile ~= long_code then
            return false, "profile chunks did not round-trip"
        end

        if SaveWire.decodeCharacter("0:1:1:bad") ~= nil then
            return false, "slot zero was accepted"
        end
        if SaveWire.decodeCharacter((MAX_SLOTS + 1) .. ":1:1:bad") ~= nil then
            return false, "out-of-range slot was accepted"
        end
        if SaveWire.decodeCharacter("malformed") ~= nil then
            return false, "malformed slot payload was accepted"
        end
        return true
    end)

    ArchitectureTests.register("unknown character version is rejected",
                               function()
        local hero = HeroData.create()
        local ok = hero:propagate({271828, CHARACTER_SAVE_VERSION + 1})
        if ok then return false, "unknown character version was accepted" end
        return true
    end)

    ArchitectureTests.register("oversized item state is rejected", function()
        local source = HeroData.create()
        source.id = 1
        local values = source:values()
        -- Header and the sixteen scalar fields precede inventory slot one.
        local first_item = 19
        values[first_item] = 1
        values[first_item + 1] = 0
        values[first_item + 2] = 0
        values[first_item + 3] = 17
        local decoded = HeroData.create()
        local ok = decoded:propagate(values)
        if ok then return false, "oversized item state was accepted" end
        return true
    end)

    ArchitectureTests.register(
        "save codec supports long explicitly framed checksums", function()
            local source = {}
            for index = 1, 2500 do source[index] = 0x7FFFFFFF end
            local code = Compile(1, source)
            local decoded, err = Decompile(code, Player(0))
            if err or not decoded or #decoded ~= #source then
                return false, "long save payload did not decode"
            end
            for index = 1, #source do
                if decoded[index] ~= source[index] then
                    return false, "long save payload changed value " .. index
                end
            end
            return true
        end)

    ArchitectureTests.register(
        "character save extensions are backward compatible", function()
            local source = HeroData.create()
            source.id = 1
            source.summon_essence = 185
            source.struggle_best_wave = 75
            source.struggle_claim_wave = 70
            source.perk_milestones = 3
            source.experience = 4321
            source.faction_id = 1
            source.faction_reputation[1] = 275
            source.faction_reputation[3] = 40
            source.faction_point_balances[1] = 35
            source.faction_point_balances[3] = 12

            local current = source:values()
            local decoded = HeroData.create()
            if not decoded:propagate(current) or decoded.summon_essence ~= 185 or
                decoded.struggle_best_wave ~= 75 or decoded.struggle_claim_wave ~=
                70 or decoded.perk_milestones ~= 3 or decoded.experience ~= 4321 or
                decoded.faction_id ~= 1 or decoded.faction_reputation[1] ~= 275 or
                decoded.faction_reputation[3] ~= 40 or
                decoded.faction_point_balances[1] ~= 35 or
                decoded.faction_point_balances[3] ~= 12 then
                return false, "trailing character fields did not round-trip"
            end

            -- The following compatibility checks target the older optional
            -- character fields, so first remove the complete stash extension.
            for _ = 1, MAX_STASH_SLOTS + 1 do current[#current] = nil end

            for _ = 1, 13 do current[#current] = nil end
            local before_factions = HeroData.create()
            if not before_factions:propagate(current) or
                before_factions.experience ~= 4321 or before_factions.faction_id ~=
                0 or before_factions.faction_reputation[1] ~= 0 or
                before_factions.faction_point_balances[1] ~= 0 then
                return false,
                       "pre-Factions character did not default faction progress to zero"
            end

            current[#current] = nil
            local before_experience = HeroData.create()
            if not before_experience:propagate(current) or
                before_experience.perk_milestones ~= 3 or
                before_experience.experience ~= 0 then
                return false,
                       "pre-XP character did not preserve Perks and default partial XP to zero"
            end

            current[#current] = nil
            local before_perks = HeroData.create()
            if not before_perks:propagate(current) or
                before_perks.summon_essence ~= 185 or
                before_perks.struggle_best_wave ~= 75 or
                before_perks.struggle_claim_wave ~= 70 or
                before_perks.perk_milestones ~= 0 then
                return false,
                       "pre-Perks character did not default milestone progress to zero"
            end

            current[#current] = nil
            current[#current] = nil
            local before_struggle = HeroData.create()
            if not before_struggle:propagate(current) or
                before_struggle.summon_essence ~= 185 or
                before_struggle.struggle_best_wave ~= 0 or
                before_struggle.struggle_claim_wave ~= 0 then
                return false,
                       "pre-Struggle character did not default Struggle progress to zero"
            end

            current[#current] = nil
            local previous = HeroData.create()
            if not previous:propagate(current) or previous.summon_essence ~= 0 then
                return false,
                       "pre-extension character did not default summon essence to zero"
            end
            return true
        end)

    ArchitectureTests.register(
        "character inventory DTO preserves sparse slots and sockets", function()
            local function saved_item(id, stats, extra, sockets, state)
                return {
                    encode_id = function() return id end,
                    encode_stats = function() return stats end,
                    encode_extra = function() return extra end,
                    encode_state = function() return state or {} end,
                    sockets = sockets or {}
                }
            end

            local source = HeroData.create()
            source.id = 1
            source.items[1] = saved_item(101, 102, 103, {
                saved_item(111, 112, 113, nil, {11, 12}),
                saved_item(121, 122, 123, nil, {21})
            }, {7, 8, 9})
            source.items[MAX_INVENTORY_SLOTS] =
                saved_item(201, 202, 203, nil, {31, 32, 33, 34})
            source.stash_rows = STASH_MAX_ROWS
            source.stash[MAX_STASH_SLOTS] =
                saved_item(301, 302, 303, {
                    saved_item(311, 312, 313, nil, {41, 42})
                }, {35, 36})

            local decoded = HeroData.create()
            if not decoded:propagate(source:values()) then
                return false, "inventory DTO payload was rejected"
            end

            local first = decoded.saved_items[1]
            local last = decoded.saved_items[MAX_INVENTORY_SLOTS]
            if not first or first.id ~= 101 or first.stats ~= 102 or first.extra ~=
                103 or #first.sockets ~= 2 or first.sockets[1].id ~= 111 or
                first.sockets[1].stats ~= 112 or first.sockets[1].extra ~= 113 or
                first.state[1] ~= 7 or first.state[3] ~= 9 or
                first.sockets[1].state[2] ~= 12 or
                first.sockets[2].id ~= 121 or first.sockets[2].stats ~= 122 or
                first.sockets[2].extra ~= 123 or
                first.sockets[2].state[1] ~= 21 then
                return false, "socketed inventory item did not round-trip"
            end
            if decoded.saved_items[2] ~= nil then
                return false, "empty inventory slot became occupied"
            end
            if not last or last.id ~= 201 or last.stats ~= 202 or last.extra ~=
                203 or last.state[4] ~= 34 then
                return false, "last inventory slot did not round-trip"
            end

            local stash_last = decoded.saved_stash[MAX_STASH_SLOTS]
            if decoded.stash_rows ~= STASH_MAX_ROWS or not stash_last or
                stash_last.id ~= 301 or stash_last.stats ~= 302 or
                stash_last.extra ~= 303 or stash_last.state[2] ~= 36 or
                #stash_last.sockets ~= 1 or stash_last.sockets[1].id ~= 311 or
                stash_last.sockets[1].state[2] ~= 42 then
                return false, "last stash slot did not round-trip"
            end

            local item_count, socket_count, stash_count, stash_socket_count =
                decoded:get_saved_item_counts()
            if item_count ~= 2 or socket_count ~= 2 or stash_count ~= 1 or
                stash_socket_count ~= 1 then
                return false, "saved inventory counts are incorrect"
            end
            return true
        end)

    ArchitectureTests.register(
        "stash capacity and row prices remain stable", function()
            local hero = HeroData.create()
            if hero.stash_rows ~= 1 or MAX_STASH_SLOTS ~= 36 or
                StashService.getRowPrice(2) ~= 1000000 or
                StashService.getRowPrice(3) ~= 5000000 or
                StashService.getRowPrice(4) ~= 25000000 or
                StashService.getRowPrice(5) ~= 125000000 or
                StashService.getRowPrice(6) ~= 625000000 then
                return false, "stash defaults or row price curve changed"
            end
            return true
        end)

    ArchitectureTests.register(
        "Perk budget is derived from character milestones", function()
            local test_pid = PLAYER_CAP + 1
            local previous = Profile[test_pid]
            local softcore = HeroData.create()
            local hardcore = HeroData.create()
            softcore.hardcore = 0
            softcore.perk_milestones = 0x1
            hardcore.hardcore = 1
            hardcore.perk_milestones = 0x3
            ---@diagnostic disable-next-line: missing-fields
            Profile[test_pid] = {
                storage = {softcore, hardcore},
                perk_ranks = __jarray(0),
                perk_node_words = __jarray(0),
                playing = false
            }

            local total = Perks.getTotal(test_pid)
            local first = Perks.allocateNode(test_pid, 2)
            local second = Perks.allocateNode(test_pid, 3)
            local spent = Perks.getSpent(test_pid)
            local available = Perks.getAvailable(test_pid)
            Profile[test_pid] = previous

            if not first or not second or total ~= 16 or spent ~= 2 or available ~=
                14 then
                return false,
                       "Perk milestone totals or allocation accounting are incorrect"
            end
            return true
        end)

    ArchitectureTests.register("item lifecycle counters balance", function()
        local items = RuntimeMetrics.items
        if items.live ~= items.created - items.destroyed then
            return false, "live item count differs from created minus destroyed"
        end
        if items.live < 0 then
            return false, "live item counter is negative"
        end
        if RuntimeMetrics.timer_queue.active < 0 then
            return false, "timer queue active counter is negative"
        end
        return true
    end)

    ArchitectureTests.register(
        "equipment maximum changes use the more punitive resource value",
        function()
            local calculate = ItemRuntime.minimumResourceAfterMaxChange
            local equipped = calculate(100000, 1000000, 10000000, 1)
            if equipped ~= 100000 then
                return false, "equipping maximum health granted current health: " ..
                           tostring(equipped)
            end
            local unequipped = calculate(5000000, 10000000, 1000000, 1)
            if math.floor(unequipped + 0.5) ~= 500000 then
                return false,
                       "unequipping maximum health did not preserve the lower percentage: " ..
                           tostring(unequipped)
            end
            local mana = calculate(0, 1000, 10000, 0)
            if mana ~= 0 then
                return false, "equipping maximum mana granted current mana: " ..
                           tostring(mana)
            end
            return true
        end)

    ArchitectureTests.register(
        "inventory commands reject invalid slots without mutation", function()
            local invalid = {
                InventoryService.move(1, 0, 1),
                InventoryService.move(1, 1, MAX_INVENTORY_SLOTS + 1),
                InventoryService.move(1, 1.5, 2)
            }

            for index = 1, #invalid do
                local response = invalid[index]
                if response.ok or response.code ~= "invalid_slot" then
                    return false, "invalid inventory slot was accepted"
                end
                if #response.changed_slots ~= 0 then
                    return false,
                           "rejected inventory command reported changed slots"
                end
            end
            return true
        end)

    ArchitectureTests.register("shop services are registered",
                               function()
        local ids = {
            'I0TS', 'I0TA', 'I0TI', 'I0TT', 'I0N0', 'I0JN', 'I0JS', 'I084',
            'I101', 'I102'
        }
        for index = 1, #ids do
            if not ShopAction.get(ids[index]) then
                return false, "missing shop action " .. ids[index]
            end
        end
        if TomeService.bundles[1].gold ~= 10000 or
            TomeService.bundles[5].platinum ~= 100 then
            return false, "tome bundle prices changed"
        end
        local converter_price = GetItemPrice('I084', 1)
        if not converter_price or converter_price[PLATINUM] ~= 4 then
            return false,
                   "currency converter is not using the shop price contract"
        end
        if not ShopAction.get('I0JS').cooldown then
            return false, "recharge action has no cooldown presentation"
        end
        if not ShopAction.get('I101').handles_price or
            not ShopAction.get('I102').handles_price then
            return false, "backpack upgrades can be charged twice"
        end
        if type(PotionBrewingService.quote) ~= "function" or
            type(PotionBrewingService.commit) ~= "function" or
            type(PotionMasterServices.addToShop) ~= "function" then
            return false, "potion brewing service is not registered"
        end
        return true
    end)

    ArchitectureTests.register(
        "shop catalogs are registered independently of their views", function()
            local expected = {
                {'n01A', 12, 40}, {'n01B', 0, 10}, {'n0P2', 1, 0},
                {'n032', 2, 0},
                {'n004', 2, 1}, {'n0P0', 2, 1}, {'n0P1', 2, 1},
                {'n01F', 10, 11}, {'n02C', 12}, {'n09D', 11}
            }

            for index = 1, #expected do
                local values = expected[index]
                local definition = ShopRegistry.get(FourCC(values[1]))
                if not definition then
                    return false, "missing shop definition " .. values[1]
                end
                if #definition.categories ~= values[2] then
                    return false, values[1] .. " category count changed"
                end
                if values[3] and #definition.items ~= values[3] then
                    return false, values[1] .. " item count changed"
                end
                if not definition.view then
                    return false, values[1] .. " has no bound shop view"
                end
                if definition.view.definition ~= definition then
                    return false, values[1] ..
                               " view is bound to the wrong definition"
                end
                if #definition.items > 0 then
                    local first_item = definition.items[1]
                    if not definition:has(first_item.id) then
                        return false, values[1] ..
                                   " item membership index is incomplete"
                    end
                    if definition:getStock(first_item.id) == nil then
                        return false, values[1] .. " stock state is missing"
                    end
                end
                if values[1] == 'n032' then
                    if #definition.offers ~= 8 then
                        return false, "Prize Vendor virtual offer count changed"
                    end
                    local offer = definition.offers[1]
                    if not offer.virtual or not definition:has(offer.id) then
                        return false, "Prize Vendor offer index is incomplete"
                    end
                    local price = offer:getPrice(1)
                    if price[HONOR] ~= 5 then
                        return false,
                               "Prize Vendor reward does not use Honor pricing"
                    end
                end
            end

            local potion_master = ShopRegistry.get(FourCC('n0P2'))
            if not potion_master or #potion_master.offers ~= 4 then
                return false, "Potion Master service offers are incomplete"
            end
            return true
        end)

    ArchitectureTests.register(
        "Struggle uses saved-best brackets and a 100-rank reward curve",
        function()
            if Struggle.getRecommendedStartWave(0) ~= 1 or
                Struggle.getRecommendedStartWave(1) ~= 1 or
                Struggle.getRecommendedStartWave(25) ~= 1 or
                Struggle.getRecommendedStartWave(26) ~= 26 or
                Struggle.getRecommendedStartWave(200) ~= 176 or
                Struggle.getRecommendedStartWave(500) ~= 476 then
                return false, "Struggle recommended starting brackets changed"
            end

            if StruggleRewards.getAttributeBonus(1) ~= 10 or
                StruggleRewards.getAttributeBonus(100) ~= 19953 or
                StruggleRewards.getPercentageBonus(100) ~= 10 then
                return false, "Struggle reward scaling changed"
            end
            return true
        end)

    ArchitectureTests.register(
        "faction presentation is bound through its adapter", function()
            if not Faction.isViewBound() then
                return false, "faction view adapter was not bound"
            end
            return true
        end)

    ArchitectureTests.register("faction reputation ranks use stable thresholds",
                               function()
        if Faction.getRank(0) ~= 1 or Faction.getRank(99) ~= 1 or
            Faction.getRank(100) ~= 2 or Faction.getRank(3200) ~= 10 or
            Faction.getMaxRank() ~= 10 or Faction.getNextRankThreshold(0) ~= 100 or
            Faction.getNextRankThreshold(3200) ~= nil then
            return false, "faction reputation threshold changed unexpectedly"
        end
        return true
    end)

    ArchitectureTests.register("faction mining object records are configured",
                               function()
        local rawcodes = FactionMining.RAWCODES
        if rawcodes.deposit == 0 or rawcodes.guardian == 0 or rawcodes.guardian ==
            rawcodes.deposit then
            return false, "faction mining object records overlap"
        end
        return true
    end)

    ArchitectureTests.register("faction hourly event service is available",
                               function()
        if type(FactionEvents.activate) ~= "function" or
            type(FactionEvents.register) ~= "function" or
            type(FactionEvents.getStatus) ~= "function" or
            type(FactionEvents.getHudStatus) ~= "function" then
            return false, "faction hourly event API is incomplete"
        end
        return true
    end)

    ArchitectureTests.register("faction generic quest hooks are available",
                               function()
        local required = {
            kill_units = false,
            heal_allies = false,
            kill_bosses = false
        }
        local faction = Faction[1]
        if not faction or type(Faction.addGenericQuests) ~= "function" or
            type(Quest.formatProgress) ~= "function" or
            type(RewardNotifications.registerKillAction) ~= "function" or
            type(ResourceChanges.registerHealAction) ~= "function" then
            return false, "generic faction quest API is incomplete"
        end
        for index = 1, #faction.quests do
            if required[faction.quests[index].kind] ~= nil then
                required[faction.quests[index].kind] = true
            end
        end
        for kind, present in pairs(required) do
            if not present then
                return false, "missing generic faction quest: " .. kind
            end
        end
        return true
    end)

    ArchitectureTests.register(
        "colosseum ticket rewards use the drop table service", function()
            if type(DropTable.rollColosseumTicket) ~= "function" then
                return false, "colosseum ticket roll API is missing"
            end
            return true
        end)

    ArchitectureTests.register("vampire retains leather proficiency", function()
        local definition = HERO_STATS[HERO_VAMPIRE]
        if not definition or BlzBitAnd(definition.prof, PROF_LEATHER) == 0 then
            return false, "Vampire is missing PROF_LEATHER"
        end
        return true
    end)

    ArchitectureTests.register(
        "overlevel rewards use exponential fixed-gap falloff", function()
            local epsilon = 0.0001
            local low = Progression.getLevelDifferenceMultiplier(150, 100)
            local high = Progression.getLevelDifferenceMultiplier(450, 400)
            local quest = RewardNotifications.questLevelMultiplier(450, 400)

            if math.abs(low - 0.3233) > epsilon or math.abs(high - 0.3233) >
                epsilon or math.abs(quest - 0.3233) > epsilon or
                math.abs(
                    Progression.getLevelDifferenceMultiplier(115, 100) - 0.8225) >
                epsilon or
                math.abs(
                    Progression.getLevelDifferenceMultiplier(200, 100) - 0.0369) >
                epsilon or Progression.getLevelDifferenceMultiplier(100, 100) ~=
                1. or Progression.getLevelDifferenceMultiplier(100, 120) ~= 1.5 then
                return false,
                       "overlevel rewards do not follow the shared exponential curve"
            end
            return true
        end)

    ArchitectureTests.register(
        "lifetime Honor milestones are ordered and complete", function()
            local milestones = Honor.getMilestones()
            if #milestones ~= 14 then
                return false, "lifetime Honor milestone count changed"
            end
            if milestones[1].honor ~= 5 or milestones[#milestones].honor ~=
                10000 then
                return false, "lifetime Honor milestone bounds changed"
            end
            for index = 2, #milestones do
                if milestones[index - 1].honor >= milestones[index].honor then
                    return false,
                           "lifetime Honor milestones are not strictly ordered"
                end
            end
            return true
        end)

    ArchitectureTests.register("naga abilities are registered", function()
        local ids = {
            'A04V', 'A04W', 'A04K', 'A04R', 'A00O', 'A05C', 'A05K', 'A006'
        }

        for index = 1, #ids do
            if not Spells[FourCC(ids[index])] then
                return false, "missing naga ability " .. ids[index]
            end
        end
        return true
    end)

    ArchitectureTests.register("hellfire magi abilities are registered",
                               function()
        local ids = {'A04A', 'A02M', 'A00G', 'A01T'}

        for index = 1, #ids do
            if not Spells[FourCC(ids[index])] then
                return false, "missing hellfire magi ability " .. ids[index]
            end
        end
        return true
    end)

    ArchitectureTests.register(
        "hellfire magi passive and AI setup are attached", function()
            local boss = Boss[BOSS_HELLFIRE]
            if not boss or not boss.unit then
                return false, "hellfire magi was not created"
            end
            if not EVENT_ENEMY_AI:has_unit_actions(boss.unit) then
                return false, "hellfire magi has no enemy AI actions"
            end

            local expected = HERO_STATS[FourCC('U00G')].magic_resist * 0.35
            if math.abs(Unit[boss.unit].mr - expected) > 0.0001 then
                return false,
                       "hellfire magi magic resistance setup was not applied"
            end
            return true
        end)

    ArchitectureTests.register("remaining boss abilities are registered",
                               function()
        local ids = {
            'A06M', 'A05I', 'A08C', 'A08N', 'A0AO', 'A088', 'A00S', 'A062',
            'A01Z', 'A085', 'A09J', 'A0DV', 'A0A2', 'A0FI', 'A065', 'A066',
            'A06T', 'A0A8', 'A05B', 'A05W', 'A08M', 'A0AX', 'A0AC', 'A03W',
            'A04Q', 'A040', 'A03M', 'A02Q', 'A03R', 'A0BH'
        }

        for index = 1, #ids do
            if not Spells[FourCC(ids[index])] then
                return false, "missing boss ability " .. ids[index]
            end
        end
        return true
    end)

    ArchitectureTests.register("unit and item abilities are registered",
                               function()
        local spell_ids = {
            'A071', 'A06C', 'A06O', 'A0B0', 'A02J', 'A0FV', 'ACfn', 'A0AJ',
            'A01H', 'A015', 'Aarm', 'Abas', 'Zs00', 'Zs01', 'Zs02', 'Zs03',
            'Zs04', 'Zs05', 'Zs06', 'A07G', 'A0B5', 'A0C0', 'A09O', 'Areg',
            'Abon', 'Ahrt', 'A01F', 'A03D', 'A061', 'AIbk', 'A018', 'A01S',
            'A083', 'A02A', 'A055', 'A0SX', 'A00E', 'A00Q', 'A0B9', 'A04I',
            'A03G', 'Anrv', 'Arrv', 'A00D', 'A01G', 'Adt1', 'A03F', 'A03H',
            'AIcd', 'AIta', 'A0E2', 'A0D3'
        }

        for index = 1, #spell_ids do
            if not Spells[FourCC(spell_ids[index])] then
                return false,
                       "missing unit or item ability " .. spell_ids[index]
            end
        end

        local dispatch_ids = {
            'A00I', 'A0KI', 'A00Y', 'A00B', 'A02T', 'A031', 'A067', 'A0KX',
            'A04N'
        }

        for index = 1, #dispatch_ids do
            if type(UNIT_SPELLS[FourCC(dispatch_ids[index])]) ~= "function" then
                return false, "missing simple ability dispatch " ..
                           dispatch_ids[index]
            end
        end

        return true
    end)

    ArchitectureTests.register("ownership buff modules are registered",
                               function()
        local names = {
            'Disarm', 'FlamingBowBuff', 'InfusedWaterBuff', 'ResurgenceBuff',
            'ArcaneBarrageBuff', 'OverloadBuff', 'InspireBuff',
            'MagneticStanceBuff', 'EarthquakeDebuff', 'MarkedForDeathDebuff',
            'RoyalPlateBuff', 'JusticeAuraBuff', 'BloodMistBuff',
            'ManaDrainDebuff', 'ParryBuff', 'UndyingRageBuff', 'FrostArmorBuff',
            'NerveGasDebuff', 'RighteousMightBuff', 'FireElementBuff',
            'HardHatBuff', 'SingleShotDebuff', 'DarkShieldBuff',
            'AstralShieldBuff', 'ProtectedExistenceBuff', 'DivineLightBuff',
            'DemonPrinceBloodlust', 'SkullBruteThunderClap', 'NagaThorns',
            'HolyBlessing', 'Lava', 'WeatherBuff', 'SharedHardHatBuff',
            'SharedStormwatchBuff', 'SharedAshenVanguardBuff'
        }

        for index = 1, #names do
            if type(_G[names[index]]) ~= "table" then
                return false, "missing buff definition " .. names[index]
            end
        end
        return true
    end)

    ---Runs registered safe assertions. Stateful shop, inventory, save and damage
    ---scenarios can register additional tests from development map commands.
    ---@return boolean, table
    function ArchitectureTests.run()
        local failures = {}

        for index = 1, #ArchitectureTests.tests do
            local test = ArchitectureTests.tests[index]
            local ok, err = test.run()
            if not ok then
                failures[#failures + 1] =
                    test.name .. ": " .. tostring(err or "failed")
                DevLog.write("TEST", "FAIL " .. test.name .. ": " ..
                                 tostring(err or "failed"))
            else
                DevLog.write("TEST", "PASS " .. test.name)
            end
        end

        RuntimeMetrics.tests = {
            total = #ArchitectureTests.tests,
            failed = #failures,
            failures = failures
        }

        if #failures > 0 then
            for index = 1, #failures do
                print("ARCH TEST FAILED: " .. failures[index])
            end
            DevLog.snapshot("architecture-tests-failed")
            return false, failures
        end

        print("Architecture tests passed: " .. #ArchitectureTests.tests)
        for index = 1, #InitTrace do
            local entry = InitTrace[index]
            DevLog.write("INIT", index .. " " .. entry.phase .. " " ..
                             entry.name .. " " .. entry.status, true)
        end
        DevLog.snapshot("architecture-tests-passed")
        return true, failures
    end

    if DEV_ENABLED or DevLog.enabled then
        TimerQueue:callDelayed(0., ArchitectureTests.run)
    end
end, Debug and Debug.getLine())
