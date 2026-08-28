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
            'A071', 'A06C', 'A04Z', 'A06O', 'A0B0', 'A02J', 'A0FV',
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
            'DemonicSacrificeBuff', 'JusticeAuraBuff', 'BloodMistBuff',
            'ManaDrainDebuff', 'ParryBuff', 'UndyingRageBuff', 'FrostArmorBuff',
            'NerveGasDebuff', 'RighteousMightBuff', 'FireElementBuff', 'HardHatBuff',
            'SingleShotDebuff', 'DarkShieldBuff', 'AstralShieldBuff',
            'ProtectedExistenceBuff', 'DivineLightBuff', 'DemonPrinceBloodlust',
            'MeatGolemThunderClap', 'NagaThorns', 'HolyBlessing', 'Lava', 'WeatherBuff',
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
