-- All mutations run on synchronized setup/level/shop/sync paths. UI owns drafts only.
OnInit.final("StatAllocation", function(Require)
    Require('StatAllocationModel')
    Require('Profile')
    Require('Perks')
    Require('WorldAreas')
    Require('UnitTable')
    Require('Events')
    Require('Currency')
    StatAllocation = {}
    local A, M = StatAllocation, StatAllocationModel
    local keys = {"str", "agi", "int"}
    local listeners, live, generations = {}, {}, {}
    local applying = {}
    local function notify(pid)
        for _, callback in ipairs(listeners) do callback(pid) end
    end
    function A.registerChangedAction(callback) listeners[#listeners + 1] = callback end
    function A.get(pid) return live[pid] end
    function A.getGeneration(pid) return generations[pid] or 0 end
    function A.hasAutomation(pid) return (Perks.getBonuses(pid).auto_allocation or 0) > 0 end
    function A.resetCost(pid)
        return Hero[pid] and 100 * GetHeroLevel(Hero[pid]) or 0
    end
    function A.available(pid)
        local data, hero = live[pid], Hero[pid]
        return data and hero and M.available(GetHeroLevel(hero), data) or 0
    end
    function A.apply(pid)
        local data, hero, profile = live[pid], Hero[pid], Profile[pid]
        if not data or not hero or not profile or applying[pid] then return end
        local definition = HERO_STATS[profile.hero.unit_id]
        if not definition.str then return end
        local unit = Unit[hero]
        applying[pid] = true
        local suppressed = unit.suppress_stat_events
        unit.suppress_stat_events = true
        for i, key in ipairs(keys) do
            -- No point-value multiplier, and no changes to gear/buff fields.
            unit[key] = M.value(definition[key], data.flat[i])
        end
        unit.suppress_stat_events = suppressed
        applying[pid] = nil
        EVENT_STAT_CHANGE:trigger(hero)
    end
    local function changed(pid)
        live[pid].revision = live[pid].revision + 1
        A.apply(pid)
        notify(pid)
    end
    local function auto_award(pid, count)
        local data = live[pid]
        if count > 0 and data.automatic == 1 and A.hasAutomation(pid) then
            M.distribute(data, count)
        end
    end
    function A.onLevel(pid)
        local data = live[pid]
        if not data then return end
        local level = GetHeroLevel(Hero[pid])
        local previous = data.last_level or level
        auto_award(pid, math.max(0, M.earned(level) - M.earned(previous)))
        data.last_level = math.max(previous, level)
        changed(pid)
    end
    function A.addPurchased(pid, count)
        local data = live[pid]
        if not data or type(count) ~= "number" or count % 1 ~= 0 or count <= 0
            or data.purchased + count > 10000000 then return false end
        data.purchased = data.purchased + count
        auto_award(pid, count)
        changed(pid)
        return true
    end
    function A.commit(pid, generation, revision, amounts)
        local data = live[pid]
        if not data or generation ~= A.getGeneration(pid) or revision ~= data.revision then
            return false, "Your points changed. Review the allocation again."
        end
        if type(amounts) ~= "table" or #amounts ~= 3 then return false, "Invalid allocation." end
        local spent = 0
        for i = 1, 3 do
            local value = amounts[i]
            if type(value) ~= "number" or value % 1 ~= 0 or value < 0
                or value > 10000000 then return false, "Invalid allocation." end
            spent = spent + value
        end
        if spent > A.available(pid) then return false, "Not enough unspent points." end
        if spent == 0 then return false, "Choose points to allocate first." end
        for i = 1, 3 do data.flat[i] = data.flat[i] + amounts[i] end
        changed(pid)
        -- This runs only after a synchronized, successful manual allocation.
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIam\\AIamTarget.mdl", Hero[pid], "origin"))
        return true
    end
    function A.setPlan(pid, generation, enabled, ratio)
        local data = live[pid]
        if not data or generation ~= A.getGeneration(pid) then return false, "No active hero." end
        if enabled ~= 0 and enabled ~= 1 then return false, "Invalid plan." end
        if enabled == 1 and not A.hasAutomation(pid) then return false, "Requires the Legacy Auto Allocation perk." end
        local sum = 0
        for i = 1, 3 do
            local value = ratio[i]
            if type(value) ~= "number" or value % 1 ~= 0 or value < 0 or value > 100 then
                return false, "Use ratio weights from 0 to 100."
            end
            sum = sum + value
        end
        if sum == 0 and enabled == 1 then return false, "Choose at least one attribute." end
        data.automatic = enabled
        for i = 1, 3 do data.ratio[i] = ratio[i] end
        data.carry = {0, 0, 0}
        changed(pid)
        return true
    end
    function A.canReset(pid)
        if not live[pid] then return false, "NO HERO" end
        if not Town.isPlayerInServiceArea(pid) then return false, "Return to town to reset allocations." end
        local data = live[pid]
        local spent = 0
        for i = 1, 3 do spent = spent + data.flat[i] end
        if spent == 0 then return false, "NO STATS" end
        if GetCurrency(pid, GOLD) + GetCurrency(pid, PLATINUM) * 1000000 < A.resetCost(pid) then
            return false, "Not enough gold to reset allocations."
        end
        return true
    end
    function A.reset(pid, generation, expected_cost)
        if generation ~= A.getGeneration(pid) then return false, "No active hero." end
        if expected_cost and expected_cost ~= A.resetCost(pid) then
            return false, "Reset cost changed. Review the reset again."
        end
        local allowed, reason = A.canReset(pid)
        if not allowed then return false, reason end
        if not ChargePlayer(pid, A.resetCost(pid), "Stat allocations reset.") then
            return false, "Not enough gold to reset allocations."
        end
        local data = live[pid]
        data.flat, data.carry, data.ratio = {0, 0, 0}, {0, 0, 0}, {0, 0, 0}
        -- A reset clears the weights as well as the spent points.
        data.automatic = 0
        changed(pid)
        return true
    end
    local function loaded(pid, hero_data)
        local definition = HERO_STATS[hero_data.unit_id]
        if not definition.str then return end
        local data = hero_data.stat_allocation
        assert(data, "Missing stat-allocation data")
        generations[pid] = (generations[pid] or 0) + 1
        live[pid] = data
        data.last_level, data.revision = GetHeroLevel(Hero[pid]), 0
        A.apply(pid)
        notify(pid)
    end
    Profile.registerHeroLoadedAction(loaded)
    Perks.registerChangedAction(function(pid) notify(pid) end)
    RegisterCurrencyChangedAction(function(pid, currency)
        if live[pid] and (currency == GOLD or currency == PLATINUM) then notify(pid) end
    end)
    for pid = 1, PLAYER_CAP do
        EVENT_ON_CLEANUP:register_action(pid, function()
            live[pid], applying[pid] = nil, nil
            notify(pid)
        end)
    end
end, Debug and Debug.getLine())
