-- Persistent and temporary cooldown acceleration share one ticker per unit.
OnInit.final("CooldownAcceleration", function(Require)
    Require('TimerQueue')
    Require('UnitTable')

    CooldownAcceleration = {}

    local PERIOD = 0.25
    local active = {}
    local active_count = 0
    local ticking = false

    CooldownAcceleration.PERIOD = PERIOD

    local function publish(u, state)
        local data = Unit[u]
        if data then data.cooldown_acceleration = state.permanent + state.rate end
        if state.permanent == 0. and state.rate == 0. then
            active[u] = nil
            active_count = active_count - 1
        end
    end

    local function clear(u)
        local state = active[u]
        if not state then return end
        state.rate, state.remaining = 0., 0.
        publish(u, state)
    end

    local function tick()
        for u, state in pairs(active) do
            if not Unit[u] then
                active[u] = nil
                active_count = active_count - 1
            elseif not UnitAlive(u) then
                clear(u)
            else
                local index = 0
                local ability = BlzGetUnitAbilityByIndex(u, index)

                while ability do
                    local id = BlzGetAbilityId(ability)
                    if id ~= 0 and
                        BlzGetUnitAbilityCooldownRemaining(u, id) > 0. then
                        BlzAdjustUnitAbilityCooldownRemaining(
                            u, id, -(state.permanent + state.rate) * PERIOD)
                    end

                    index = index + 1
                    ability = BlzGetUnitAbilityByIndex(u, index)
                end

                if state.rate > 0. then
                    state.remaining = state.remaining - PERIOD
                    if state.remaining <= 0. then clear(u) end
                end
            end
        end

        if active_count == 0 then ticking = false end
    end

    local function finished()
        if active_count == 0 then
            ticking = false
            return true
        end
        return false
    end

    local function state_for(u)
        if not active[u] then
            active[u] = {permanent = 0., rate = 0., remaining = 0.}
            active_count = active_count + 1
        end
        return active[u]
    end

    local function start_ticking()
        if not ticking and active_count > 0 then
            ticking = true
            TimerQueue:callPeriodically(PERIOD, finished, tick)
        end
    end

    ---Sets persistent acceleration without overwriting temporary effects.
    ---@param u unit
    ---@param rate number Additional cooldown seconds recovered per second.
    function CooldownAcceleration.setPermanent(u, rate)
        if not u or not Unit[u] then return end
        local state = state_for(u)
        state.permanent = math.max(0., rate or 0.)
        publish(u, state)
        start_ticking()
    end

    ---Starts or refreshes acceleration on a unit. A new application replaces
    ---the current rate and duration rather than stacking another ticker.
    ---@param u unit
    ---@param rate number Additional cooldown seconds recovered per second.
    ---@param duration number
    ---@return boolean
    function CooldownAcceleration.apply(u, rate, duration)
        rate = math.max(0., rate or 0.)
        duration = math.max(0., duration or 0.)

        local data = u and Unit[u] or nil
        if not data or rate == 0. or duration == 0. or not UnitAlive(u) then
            return false
        end

        local state = state_for(u)
        state.rate, state.remaining = rate, duration
        publish(u, state)
        start_ticking()

        return true
    end

    ---@param u unit
    ---@return number
    function CooldownAcceleration.getRemaining(u)
        local state = active[u]
        return state and state.remaining or 0.
    end

    ---@param u unit
    function CooldownAcceleration.remove(u)
        clear(u)
    end
end, Debug and Debug.getLine())
