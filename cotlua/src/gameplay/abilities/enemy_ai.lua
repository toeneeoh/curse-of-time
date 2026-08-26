-- Damage-driven enemy spell evaluation with a per-unit internal delay.
-- Units without registered AI actions never allocate cooldown timers.

OnInit.final("EnemyAI", function(Require)
    Require('Events')
    Require('TimerQueue')
    Require('UnitTable')
    Require('Variables')

    EnemyAI = {}

    local ready_at = setmetatable({}, { __mode = 'k' })
    local event = EVENT_ENEMY_AI
    local clock = Stopwatch.create(true)

    ---Evaluates registered spell behaviors once, then applies the shared
    ---internal spacing before that unit may evaluate another spell.
    ---@param u unit
    ---@param opponent unit
    ---@param unit_data Unit?
    ---@return boolean dispatched
    function EnemyAI.evaluate(u, opponent, unit_data)
        if DEV_ENABLED and RuntimeMetrics then
            RuntimeMetrics.enemy_ai.evaluations = RuntimeMetrics.enemy_ai.evaluations + 1
        end

        if not event:has_unit_actions(u) then
            return false
        end

        unit_data = unit_data or Unit[u]
        local now = clock:getElapsed()
        if not unit_data or unit_data._casting or now < (ready_at[u] or 0.) or not UnitAlive(u) then
            return false
        end

        -- Advance the timestamp before dispatch so scripted damage inside an AI
        -- action cannot recursively start another decision for the same unit.
        ready_at[u] = now + INTERNAL_AI_COOLDOWN
        event:trigger(u, opponent)

        if DEV_ENABLED and RuntimeMetrics then
            RuntimeMetrics.enemy_ai.dispatches = RuntimeMetrics.enemy_ai.dispatches + 1
        end

        return true
    end
end, Debug and Debug.getLine())
