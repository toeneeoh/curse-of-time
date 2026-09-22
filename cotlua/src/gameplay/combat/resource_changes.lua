OnInit.global("ResourceChanges", function(Require)
    Require('TextHelpers')
    Require('FloatingText')

    ResourceChanges = {}

    local heal_actions = {}

    ---@param callback fun(source: unit, target: unit, amount: number, tag: string|nil)
    function ResourceChanges.registerHealAction(callback)
        for index = 1, #heal_actions do
            if heal_actions[index] == callback then return false end
        end
        heal_actions[#heal_actions + 1] = callback
        return true
    end

    ---@type fun(source: unit, target: unit, hp: number, tag: string|nil)
    function HP(source, target, hp, tag)
        if not Unit[target].hit_based_health then
            hp = hp * Unit[target].regen_percent
            local text = RealToString(hp)
            local previous_life = GetWidgetLife(target)

            if UndyingRageBuff:has(target, target) then
                UndyingRageBuff:get(target, target):addRegen(hp)
            else
                SetUnitState(target, UNIT_STATE_LIFE, GetUnitState(target, UNIT_STATE_LIFE) + hp)
                if R2I(hp) ~= 0 then
                    FloatingTextUnit(text, target, 2, 50, 0, 10, 125, 255, 125, 0, true)
                end
            end

            LogDamage(source, target, "|cff7dff7d" .. text .. "|r", true, tag)
            local effective_healing = math.max(0., GetWidgetLife(target) - previous_life)
            if effective_healing > 0. then
                for index = 1, #heal_actions do
                    heal_actions[index](source, target, effective_healing, tag)
                end
            end
        end
    end

    ---@type fun(source: unit, mp: number)
    function MP(source, mp)
        if not Unit[source].nomanaregen then
            SetUnitState(source, UNIT_STATE_MANA, GetUnitState(source, UNIT_STATE_MANA) + mp)
            FloatingTextUnit(RealToString(mp), source, 2, 50, -70, 10, 0, 255, 255, 0, true)
        end
    end
end)
