-- Development-only architecture regression checks.

OnInit.final("ArchitectureTests", function(Require)
    Require('Events')
    Require('InventoryService')
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
    Require('FactionView')
    Require('FactionMining')
    Require('DropTable')
    Require('StruggleRewards')
    Require('Perks')

    ArchitectureTests = {
        tests = {},
    }

    function ArchitectureTests.register(name, test)
        ArchitectureTests.tests[#ArchitectureTests.tests + 1] = {
            name = name,
            run = test,
        }
    end

    ArchitectureTests.register("event guard suppresses recursion and then clears", function()
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
            return false, "event recursion guard did not clear between dispatches"
        end
        return true
    end)

    ArchitectureTests.register("player event dispatch tolerates callback removal", function()
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

    ArchitectureTests.register("initializer trace is complete and unique", function()
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

        if RuntimeMetrics.initializers.started ~= RuntimeMetrics.initializers.completed then
            return false, "initializer start/completion counters differ"
        end
        return true
    end)

    ArchitectureTests.register("configuration schemas preserve compatibility", function()
        if DUMMY_CASTER ~= FourCC('e011') or SUMMON_BRUTE ~= FourCC('H05G') then
            return false, "rawcode exports changed"
        end
        if ITEM_LEVEL ~= 1 or PLAYER_TIME ~= TOTAL_STATS or TOTAL_STATS ~= 44 then
            return false, "serialized item stat indexes changed"
        end
        if #LIMIT_STRING ~= 28 or TIER_NAME[25] ~= "|cff999999Devourer|r" then
            return false, "item metadata changed"
        end
        if SPRITE_RARITY[0] ~= "war3mapImported\\CommonBorder.dds"
            or SPRITE_RARITY[2] ~= "war3mapImported\\RareBorder.dds"
            or SPRITE_RARITY[MAX_ITEM_RARITY_INDEX] ~= "war3mapImported\\ChaosBorder.dds" then
            return false, "inventory rarity border mapping changed"
        end
        if STAT_TAG[ITEM_DAMAGE].syntax ~= "damage"
            or type(STAT_TAG[ITEM_DAMAGE].getter) ~= "function"
            or type(STAT_TAG[ITEM_DAMAGE_RESIST].breakdown) ~= "function" then
            return false, "stat schema or runtime values are unavailable"
        end
        if HERO_TOTAL ~= 19 or HERO_STATS[HERO_DARK_SUMMONER].skills[6] ~= "A002" then
            return false, "hero definitions changed"
        end
        if BOSS_TAUREN ~= 1 or BOSS_XALLARATH ~= 28 then
            return false, "boss registry indexes changed"
        end
        if MAIN_MAP.rect ~= gg_rct_Main_Map
            or MAIN_MAP.centerX ~= (MAIN_MAP.minX + MAIN_MAP.maxX) / 2.
            or MAIN_MAP.centerY ~= (MAIN_MAP.minY + MAIN_MAP.maxY) / 2. then
            return false, "main map geometry changed"
        end
        if #INFO_STRING ~= 6 or #HINT_TOOLTIP ~= 16 or not FORCE_HINT then
            return false, "help, hint, or progression compatibility changed"
        end
        return true
    end)

    ArchitectureTests.register("owned helper families remain available", function()
        local values = { "first", "second", "third" }
        TableRemove(values, "second")

        if #values ~= 2 or TableHas(values, "second") then
            return false, "table helper compatibility changed"
        end
        if math.abs(DistanceCoords(0., 0., 3., 4.) - 5.) > 0.0001 then
            return false, "geometry helper compatibility changed"
        end
        if type(MakeGroupInRange) ~= "function" or type(FilterEnemy) ~= "function" then
            return false, "group helper exports are unavailable"
        end
        if type(HideEffect) ~= "function" or type(Fade) ~= "function" or type(FadeSFX) ~= "function" then
            return false, "effect helper exports are unavailable"
        end
        if RealToString(1234567) ~= "1,234,567" or HealthGradient(1, true) ~= "|cffFF0000" then
            return false, "text helper compatibility changed"
        end
        if type(GetMainSelectedUnit) ~= "function" or type(FrameAddSimpleTooltip) ~= "function"
            or type(reselect) ~= "function" then
            return false, "frame helper exports are unavailable"
        end
        if type(SoundHandler) ~= "function" or type(DelayAnimation) ~= "function"
            or type(UnitDisableAbility) ~= "function" or type(HighestStat) ~= "function" then
            return false, "unit and audio helper exports are unavailable"
        end
        if type(GetItem) ~= "function" or type(CastSpell) ~= "function"
            or type(PlayerCleanup) ~= "function" or type(SummonExpire) ~= "function" then
            return false, "gameplay helper exports are unavailable"
        end
        return true
    end)

    ArchitectureTests.register("save wire preserves sparse physical slots", function()
        for slot = 1, MAX_SLOTS do
            local payload = slot == 17 and "" or "character-code"
            local decoded_slot, decoded_payload = SaveWire.decodeCharacter(
                SaveWire.encodeCharacter(slot, payload))
            if decoded_slot ~= slot then
                return false, "save wire changed physical slot " .. slot
            end
            if decoded_payload ~= payload then
                return false, "save wire changed slot payload " .. slot
            end
        end

        if SaveWire.decodeCharacter("0:bad") ~= nil then
            return false, "slot zero was accepted"
        end
        if SaveWire.decodeCharacter((MAX_SLOTS + 1) .. ":bad") ~= nil then
            return false, "out-of-range slot was accepted"
        end
        if SaveWire.decodeCharacter("malformed") ~= nil then
            return false, "malformed slot payload was accepted"
        end
        return true
    end)

    ArchitectureTests.register("unknown character version is rejected", function()
        local hero = HeroData.create()
        local ok = hero:propagate({ 271828, CHARACTER_SAVE_VERSION + 1 })
        if ok then
            return false, "unknown character version was accepted"
        end
        return true
    end)

    ArchitectureTests.register("character save extensions are backward compatible", function()
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
        if not decoded:propagate(current)
            or decoded.summon_essence ~= 185
            or decoded.struggle_best_wave ~= 75
            or decoded.struggle_claim_wave ~= 70
            or decoded.perk_milestones ~= 3
            or decoded.experience ~= 4321
            or decoded.faction_id ~= 1
            or decoded.faction_reputation[1] ~= 275
            or decoded.faction_reputation[3] ~= 40
            or decoded.faction_point_balances[1] ~= 35
            or decoded.faction_point_balances[3] ~= 12 then
            return false, "trailing character fields did not round-trip"
        end

        for _ = 1, 13 do
            current[#current] = nil
        end
        local before_factions = HeroData.create()
        if not before_factions:propagate(current)
            or before_factions.experience ~= 4321
            or before_factions.faction_id ~= 0
            or before_factions.faction_reputation[1] ~= 0
            or before_factions.faction_point_balances[1] ~= 0 then
            return false, "pre-Factions character did not default faction progress to zero"
        end

        current[#current] = nil
        local before_experience = HeroData.create()
        if not before_experience:propagate(current)
            or before_experience.perk_milestones ~= 3
            or before_experience.experience ~= 0 then
            return false, "pre-XP character did not preserve Perks and default partial XP to zero"
        end

        current[#current] = nil
        local before_perks = HeroData.create()
        if not before_perks:propagate(current)
            or before_perks.summon_essence ~= 185
            or before_perks.struggle_best_wave ~= 75
            or before_perks.struggle_claim_wave ~= 70
            or before_perks.perk_milestones ~= 0 then
            return false, "pre-Perks character did not default milestone progress to zero"
        end

        current[#current] = nil
        current[#current] = nil
        local before_struggle = HeroData.create()
        if not before_struggle:propagate(current)
            or before_struggle.summon_essence ~= 185
            or before_struggle.struggle_best_wave ~= 0
            or before_struggle.struggle_claim_wave ~= 0 then
            return false, "pre-Struggle character did not default Struggle progress to zero"
        end

        current[#current] = nil
        local previous = HeroData.create()
        if not previous:propagate(current) or previous.summon_essence ~= 0 then
            return false, "pre-extension character did not default summon essence to zero"
        end
        return true
    end)

    ArchitectureTests.register("character inventory DTO preserves sparse slots and sockets", function()
        local function saved_item(id, stats, extra, sockets)
            return {
                encode_id = function() return id end,
                encode_stats = function() return stats end,
                encode_extra = function() return extra end,
                sockets = sockets or {},
            }
        end

        local source = HeroData.create()
        source.id = 1
        source.items[1] = saved_item(101, 102, 103, {
            saved_item(111, 112, 113),
            saved_item(121, 122, 123),
        })
        source.items[MAX_INVENTORY_SLOTS] = saved_item(201, 202, 203)

        local decoded = HeroData.create()
        if not decoded:propagate(source:values()) then
            return false, "inventory DTO payload was rejected"
        end

        local first = decoded.saved_items[1]
        local last = decoded.saved_items[MAX_INVENTORY_SLOTS]
        if not first or first.id ~= 101 or first.stats ~= 102 or first.extra ~= 103
            or #first.sockets ~= 2
            or first.sockets[1].id ~= 111 or first.sockets[1].stats ~= 112
            or first.sockets[1].extra ~= 113
            or first.sockets[2].id ~= 121 or first.sockets[2].stats ~= 122
            or first.sockets[2].extra ~= 123 then
            return false, "socketed inventory item did not round-trip"
        end
        if decoded.saved_items[2] ~= nil then
            return false, "empty inventory slot became occupied"
        end
        if not last or last.id ~= 201 or last.stats ~= 202 or last.extra ~= 203 then
            return false, "last inventory slot did not round-trip"
        end

        local item_count, socket_count = decoded:get_saved_item_counts()
        if item_count ~= 2 or socket_count ~= 2 then
            return false, "saved inventory counts are incorrect"
        end
        return true
    end)

    ArchitectureTests.register("Perk budget is derived from character milestones", function()
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
            storage = { softcore, hardcore },
            perk_ranks = __jarray(0),
            perk_node_words = __jarray(0),
            playing = false,
        }

        local total = Perks.getTotal(test_pid)
        local first = Perks.allocateNode(test_pid, 2)
        local second = Perks.allocateNode(test_pid, 3)
        local spent = Perks.getSpent(test_pid)
        local available = Perks.getAvailable(test_pid)
        Profile[test_pid] = previous

        if not first or not second or total ~= 16 or spent ~= 2 or available ~= 14 then
            return false, "Perk milestone totals or allocation accounting are incorrect"
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

    ArchitectureTests.register("inventory commands reject invalid slots without mutation", function()
        local invalid = {
            InventoryService.move(1, 0, 1),
            InventoryService.move(1, 1, MAX_INVENTORY_SLOTS + 1),
            InventoryService.move(1, 1.5, 2),
        }

        for index = 1, #invalid do
            local response = invalid[index]
            if response.ok or response.code ~= "invalid_slot" then
                return false, "invalid inventory slot was accepted"
            end
            if #response.changed_slots ~= 0 then
                return false, "rejected inventory command reported changed slots"
            end
        end
        return true
    end)

    ArchitectureTests.register("magic shop services are registered as actions", function()
        local ids = {
            'I0TS', 'I0TA', 'I0TI', 'I0TT', 'I0N0', 'I0JN',
            'I0JS', 'I00J', 'I084', 'I101', 'I102',
        }
        for index = 1, #ids do
            if not ShopAction.get(ids[index]) then
                return false, "missing shop action " .. ids[index]
            end
        end
        if TomeService.bundles[1].gold ~= 10000
            or TomeService.bundles[5].platinum ~= 100 then
            return false, "tome bundle prices changed"
        end
        local converter_price = GetItemPrice('I084', 1)
        if not converter_price or converter_price[PLATINUM] ~= 4 then
            return false, "currency converter is not using the shop price contract"
        end
        if not ShopAction.get('I0JS').cooldown then
            return false, "recharge action has no cooldown presentation"
        end
        return true
    end)

    ArchitectureTests.register("shop catalogs are registered independently of their views", function()
        local expected = {
            { 'n01A', 12, 40 },
            { 'n01B', 0, 11 },
            { 'n032', 2, 0 },
            { 'n004', 1, 1 },
            { 'n01F', 10, 11 },
            { 'n02C', 12 },
            { 'n09D', 11 },
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
                return false, values[1] .. " view is bound to the wrong definition"
            end
            if #definition.items > 0 then
                local first_item = definition.items[1]
                if not definition:has(first_item.id) then
                    return false, values[1] .. " item membership index is incomplete"
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
                    return false, "Prize Vendor reward does not use Honor pricing"
                end
            end
        end
        return true
    end)

    ArchitectureTests.register("Struggle uses saved-best brackets and a 100-rank reward curve", function()
        if Struggle.getRecommendedStartWave(0) ~= 1
            or Struggle.getRecommendedStartWave(1) ~= 1
            or Struggle.getRecommendedStartWave(25) ~= 1
            or Struggle.getRecommendedStartWave(26) ~= 26
            or Struggle.getRecommendedStartWave(200) ~= 176
            or Struggle.getRecommendedStartWave(500) ~= 476 then
            return false, "Struggle recommended starting brackets changed"
        end

        if StruggleRewards.getAttributeBonus(1) ~= 10
            or StruggleRewards.getAttributeBonus(100) ~= 19953
            or StruggleRewards.getPercentageBonus(100) ~= 10 then
            return false, "Struggle reward scaling changed"
        end
        return true
    end)

    ArchitectureTests.register("faction presentation is bound through its adapter", function()
        if not Faction.isViewBound() then
            return false, "faction view adapter was not bound"
        end
        return true
    end)

    ArchitectureTests.register("faction reputation ranks use stable thresholds", function()
        if Faction.getRank(0) ~= 1
            or Faction.getRank(99) ~= 1
            or Faction.getRank(100) ~= 2
            or Faction.getRank(3200) ~= 10 then
            return false, "faction reputation threshold changed unexpectedly"
        end
        return true
    end)

    ArchitectureTests.register("faction mining placeholder rawcodes are distinct", function()
        local rawcodes = FactionMining.RAWCODES
        if rawcodes.common == rawcodes.rich
            or rawcodes.common == rawcodes.rare
            or rawcodes.rich == rawcodes.rare
            or rawcodes.guardian == rawcodes.common
            or rawcodes.guardian == rawcodes.rich
            or rawcodes.guardian == rawcodes.rare then
            return false, "faction mining object records overlap"
        end
        return true
    end)

    ArchitectureTests.register("colosseum ticket rewards use the drop table service", function()
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

    ArchitectureTests.register("lifetime Honor milestones are ordered and complete", function()
        local milestones = Honor.getMilestones()
        if #milestones ~= 14 then
            return false, "lifetime Honor milestone count changed"
        end
        if milestones[1].honor ~= 5 or milestones[#milestones].honor ~= 10000 then
            return false, "lifetime Honor milestone bounds changed"
        end
        for index = 2, #milestones do
            if milestones[index - 1].honor >= milestones[index].honor then
                return false, "lifetime Honor milestones are not strictly ordered"
            end
        end
        return true
    end)

    ArchitectureTests.register("naga abilities are registered", function()
        local ids = {
            'A04V', 'A04W', 'A04K', 'A04R', 'A00O', 'A05C', 'A05K', 'A006',
        }

        for index = 1, #ids do
            if not Spells[FourCC(ids[index])] then
                return false, "missing naga ability " .. ids[index]
            end
        end
        return true
    end)

    ArchitectureTests.register("hellfire magi abilities are registered", function()
        local ids = { 'A04A', 'A02M', 'A00G', 'A01T' }

        for index = 1, #ids do
            if not Spells[FourCC(ids[index])] then
                return false, "missing hellfire magi ability " .. ids[index]
            end
        end
        return true
    end)

    ArchitectureTests.register("hellfire magi passive and AI setup are attached", function()
        local boss = Boss[BOSS_HELLFIRE]
        if not boss or not boss.unit then
            return false, "hellfire magi was not created"
        end
        if not EVENT_ENEMY_AI:has_unit_actions(boss.unit) then
            return false, "hellfire magi has no enemy AI actions"
        end

        local expected = HERO_STATS[FourCC('U00G')].magic_resist * 0.35
        if math.abs(Unit[boss.unit].mr - expected) > 0.0001 then
            return false, "hellfire magi magic resistance setup was not applied"
        end
        return true
    end)

    ArchitectureTests.register("remaining boss abilities are registered", function()
        local ids = {
            'A06M', 'A05I', 'A08C',
            'A08N', 'A0AO', 'A088',
            'A00S', 'A062', 'A01Z', 'A085', 'A09J',
            'A0DV', 'A0A2', 'A0FI', 'A065', 'A066',
            'A06T', 'A0A8', 'A05B', 'A05W', 'A08M',
            'A0AX', 'A0AC', 'A03W', 'A04Q', 'A040',
            'A03M', 'A02Q', 'A03R', 'A0BH',
        }

        for index = 1, #ids do
            if not Spells[FourCC(ids[index])] then
                return false, "missing boss ability " .. ids[index]
            end
        end
        return true
    end)

    ArchitectureTests.register("unit and item abilities are registered", function()
        local spell_ids = {
            'A071', 'A06C', 'A06O', 'A0B0', 'A02J', 'A0FV',
            'ACfn', 'A0AJ', 'A01H', 'A015',
            'Aarm', 'Abas', 'Zs00', 'Zs01', 'Zs02', 'Zs03', 'Zs04', 'Zs05', 'Zs06',
            'A07G', 'A0B5', 'A0C0', 'A09O', 'Areg', 'Abon', 'Ahrt',
            'A01F', 'A03D', 'A061', 'AIbk', 'A018', 'A01S',
            'A083', 'A02A', 'A055', 'A0SX', 'A00E', 'A00Q', 'A0B9',
            'A04I', 'A03G', 'Anrv', 'Arrv', 'A00D', 'A01G',
            'Adt1', 'A03F', 'A03H', 'AIcd', 'AIta', 'A0E2', 'A0D3',
        }

        for index = 1, #spell_ids do
            if not Spells[FourCC(spell_ids[index])] then
                return false, "missing unit or item ability " .. spell_ids[index]
            end
        end

        local dispatch_ids = {
            'A00I', 'A0KI', 'A00Y', 'A00B', 'A02T',
            'A031', 'A067', 'A0KX', 'A04N',
        }

        for index = 1, #dispatch_ids do
            if type(UNIT_SPELLS[FourCC(dispatch_ids[index])]) ~= "function" then
                return false, "missing simple ability dispatch " .. dispatch_ids[index]
            end
        end

        return true
    end)

    ArchitectureTests.register("ownership buff modules are registered", function()
        local names = {
            'Disarm', 'FlamingBowBuff', 'InfusedWaterBuff', 'ResurgenceBuff',
            'ArcaneBarrageBuff', 'OverloadBuff', 'InspireBuff', 'MagneticStanceBuff',
            'EarthquakeDebuff', 'MarkedForDeathDebuff', 'RoyalPlateBuff',
            'JusticeAuraBuff', 'BloodMistBuff',
            'ManaDrainDebuff', 'ParryBuff', 'UndyingRageBuff', 'FrostArmorBuff',
            'NerveGasDebuff', 'RighteousMightBuff', 'FireElementBuff', 'HardHatBuff',
            'SingleShotDebuff', 'DarkShieldBuff', 'AstralShieldBuff',
            'ProtectedExistenceBuff', 'DivineLightBuff', 'DemonPrinceBloodlust',
            'SkullBruteThunderClap', 'NagaThorns', 'HolyBlessing', 'Lava', 'WeatherBuff',
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
                failures[#failures + 1] = test.name .. ": " .. tostring(err or "failed")
                DevLog.write("TEST", "FAIL " .. test.name .. ": " .. tostring(err or "failed"))
            else
                DevLog.write("TEST", "PASS " .. test.name)
            end
        end

        RuntimeMetrics.tests = {
            total = #ArchitectureTests.tests,
            failed = #failures,
            failures = failures,
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
            DevLog.write("INIT", index .. " " .. entry.phase .. " " .. entry.name .. " " .. entry.status, true)
        end
        DevLog.snapshot("architecture-tests-passed")
        return true, failures
    end

    if DEV_ENABLED or DevLog.enabled then
        TimerQueue:callDelayed(0., ArchitectureTests.run)
    end
end, Debug and Debug.getLine())
