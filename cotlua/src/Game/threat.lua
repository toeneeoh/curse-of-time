--[[
    threat.lua

    This library handles units behave when they acquire targets and implements a threat system for creeps and bosses.
]]

OnInit.final("Threat", function(Require)
    Require("WorldBounds")
    Require("Damage")

    ACQUIRE_TRIGGER = CreateTrigger()

    local CALL_FOR_HELP_RANGE = 800.

    ---@return boolean
    local function proximity_filter(object)
        return GetUnitAbilityLevel(object, FourCC('Avul')) == 0 and GetPlayerId(GetOwningPlayer(object)) < PLAYER_CAP
    end

    ---@type fun(source: unit, dist: number)
    local function acquire_new_proximity(source, dist)
        local x  = GetUnitX(source)
        local y  = GetUnitY(source)
        local new_target = nil
        local targets = ALICE_EnumObjectsInRange(x, y, dist, "unit", proximity_filter)

        for _, enemy in ipairs(targets) do
            local new_dist = UnitDistance(source, enemy)

            if dist > new_dist then
                dist = new_dist
                new_target = enemy
            end
        end

        if new_target then
            Unit[new_target]:taunt(Unit[source])
        else
            Unit[source].target = nil
            IssuePointOrderById(source, ORDER_ID_MOVE, Unit[source].original_x, Unit[source].original_y)
        end
    end

    ---@type fun(unit: Unit)
    function DropAggro(unit)
        for enemy in each(unit.taunted) do
            if IsEnemy(enemy) then
                -- only for creeps
                TimerQueue:callDelayed(0.05, acquire_new_proximity, enemy, CALL_FOR_HELP_RANGE)
            end
        end

        GroupClear(unit.taunted)
    end

    local function reset_aggro_timer(source)
        source = Unit[source]

        if source.aggro_timer then
            TimerQueue:disableCallback(source.aggro_timer)
        end

        source.aggro_timer = TimerQueue:callDelayed(3., DropAggro, source)
    end

    ---@return boolean
    local function onAcquire()
        local target = GetEventTargetUnit() -- aggro target
        local source = GetTriggerUnit() -- aggro source

        if source and target then
            EVENT_ON_AGGRO:trigger(source, target)
        end

        return false
    end

    local function creep_aggro(source, target)
        if GetPlayerId(GetOwningPlayer(target)) < PLAYER_CAP then
            Unit[target]:taunt(Unit[source])
        end
    end

    local function is_ally(object, source)
        return object ~= source and UnitAlive(object) and IsUnitAlly(object, GetOwningPlayer(source))
    end

    local function call_for_help(target, source, _, _, _)
        -- ignore non-player sources or self aggro (?)
        if GetPlayerId(GetOwningPlayer(source)) < PLAYER_CAP or target == source then
            return
        end

        local allies = ALICE_EnumObjectsInRange(GetUnitX(target), GetUnitY(target), CALL_FOR_HELP_RANGE, "unit", is_ally, target)

        for _, ally in ipairs(allies) do
            if Unit[ally].target == nil then
                Unit[source]:taunt(Unit[ally])
            end
        end
    end

    local function threat_init()
        local u = GetFilterUnit()
        local p = GetOwningPlayer(u)
        local pid = GetPlayerId(p) + 1

        TriggerRegisterUnitEvent(ACQUIRE_TRIGGER, u, EVENT_UNIT_ACQUIRED_TARGET)

        -- creep ai
        if p == PLAYER_CREEP then
            EVENT_ON_STRUCK_FINAL:register_unit_action(u, call_for_help)
            EVENT_ON_AGGRO:register_unit_action(u, creep_aggro)
        -- aggro for players
        elseif pid <= PLAYER_CAP then
            EVENT_ON_HIT:register_unit_action(u, reset_aggro_timer)
            EVENT_ON_CAST:register_unit_action(u, reset_aggro_timer)
        end

        return false
    end

    TriggerAddCondition(ACQUIRE_TRIGGER, Filter(onAcquire))

    local t = CreateTrigger()
    TriggerRegisterEnterRegion(t, WorldBounds.region, Filter(threat_init))

end, Debug and Debug.getLine())
