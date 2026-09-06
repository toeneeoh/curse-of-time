OnInit.global("AbilityCasting", function(Require)
    Require('Variables')
    Require('TimerQueue')
    Require('UnitAnimation')

    local function finish_cast(u)
        Unit[u]._casting = false
    end

    local function finish_pause(u, pause_override)
        if not pause_override then PauseUnit(u, false) end
        TimerQueue:callDelayed(3., finish_cast, u)
    end

    function SpellboostVariance()
        return math.random() * (MAX_SPELLBOOST_VARIANCE * 2) + MIN_SPELLBOOST_VARIANCE
    end

    ---@type fun(u: unit, id: integer, dur: number, anim: integer, timescale: number, pause_override: boolean?): boolean
    function CastSpell(u, id, dur, anim, timescale, pause_override)
        if Unit[u]._casting or BlzGetUnitAbilityCooldownRemaining(u, id) > 0. or not UnitAlive(u) then
            return false
        end

        Unit[u]._casting = true
        BlzStartUnitAbilityCooldown(u, id,
            BlzGetUnitAbilityCooldown(u, id, GetUnitAbilityLevel(u, id) - 1))
        DelayAnimation(BOSS_ID, u, dur, 0, 1., true)
        if anim ~= -1 then
            SetUnitTimeScale(u, timescale)
            SetUnitAnimationByIndex(u, anim)
        end

        if not pause_override then PauseUnit(u, true) end
        TimerQueue:callDelayed(dur, finish_pause, u, pause_override)
        return true
    end
end)
