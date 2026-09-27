-- Temporary cooldown acceleration shared by consumables and future effects.
OnInit.final("CooldownAcceleration", function(Require)
    Require('TimerQueue')
    Require('UnitTable')

    CooldownAcceleration = {}

    local PERIOD = 0.25
    local active = {}
    local active_count = 0
    local ticking = false

    CooldownAcceleration.PERIOD = PERIOD

    local function clear(u)
        if not active[u] then return end

        active[u] = nil
        active_count = active_count - 1

        local data = Unit[u]
        if data then data.cooldown_acceleration = 0. end
    end

    local function tick()
        for u, state in pairs(active) do
            if not UnitAlive(u) then
                clear(u)
            else
                local index = 0
                local ability = BlzGetUnitAbilityByIndex(u, index)

                while ability do
                    local id = BlzGetAbilityId(ability)
                    if id ~= 0 and
                        BlzGetUnitAbilityCooldownRemaining(u, id) > 0. then
                        BlzAdjustUnitAbilityCooldownRemaining(
                            u, id, -state.rate * PERIOD)
                    end

                    index = index + 1
                    ability = BlzGetUnitAbilityByIndex(u, index)
                end

                state.remaining = state.remaining - PERIOD
                if state.remaining <= 0. then clear(u) end
            end
        end

        if active_count == 0 then ticking = false end
    end

    local function finished() return active_count == 0 end

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

        if not active[u] then active_count = active_count + 1 end
        active[u] = {rate = rate, remaining = duration}
        data.cooldown_acceleration = rate

        if not ticking then
            ticking = true
            TimerQueue:callPeriodically(PERIOD, finished, tick)
        end

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
