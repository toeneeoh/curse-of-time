-- Development-only architecture regression checks.

OnInit.final("ArchitectureTests", function(Require)
    Require('Events')
    Require('InventoryService')
    Require('ShopTransaction')
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
        if STAT_TAG[ITEM_DAMAGE].syntax ~= "damage"
            or type(STAT_TAG[ITEM_DAMAGE].getter) ~= "function"
            or type(STAT_TAG[ITEM_DAMAGE_RESIST].breakdown) ~= "function" then
            return false, "stat schema or runtime values are unavailable"
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

    ArchitectureTests.register("summon essence save extension is backward compatible", function()
        local source = HeroData.create()
        source.id = 1
        source.summon_essence = 185

        local current = source:values()
        local decoded = HeroData.create()
        if not decoded:propagate(current) or decoded.summon_essence ~= 185 then
            return false, "summon essence did not round-trip"
        end

        current[#current] = nil
        local previous = HeroData.create()
        if not previous:propagate(current) or previous.summon_essence ~= 0 then
            return false, "pre-extension character did not default summon essence to zero"
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
            'ACfn', 'A0AJ', 'A02L', 'A01H', 'A015',
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
