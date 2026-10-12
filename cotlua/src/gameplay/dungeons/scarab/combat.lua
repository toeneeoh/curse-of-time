-- Shared movement/target retention for Scarab chamber enemies and boss brood.
OnInit.final('ScarabCombat', function(Require)
    Require('UnitTable')
    Require('Variables')
    ScarabCombat = {}
    function ScarabCombat.prepare(unit, phase)
        SetUnitCreepGuard(unit, false)
        RemoveGuardPosition(unit)
        -- Native Ghost (Visible), not invisibility or ethereal armor. Applied to
        -- the whole melee swarm so members can overlap each other. Keep terrain
        -- pathing enabled: SetUnitPathing(false) would bypass chamber walls too.
        if phase then UnitAddAbility(unit, FourCC('Aeth')) end
    end
    function ScarabCombat.pursue(unit, heroes)
        local data = Unit[unit]
        local current = data.target and data.target.unit
        local target, distance
        for _, hero in ipairs(heroes) do
            if UnitAlive(hero) and GetUnitAbilityLevel(hero, ABIL_AVUL) == 0
                and IsUnitVisible(hero, GetOwningPlayer(unit)) then
                if hero == current then target = hero; break end
                local d = (GetUnitX(hero) - GetUnitX(unit))^2 + (GetUnitY(hero) - GetUnitY(unit))^2
                if not distance or d < distance then target, distance = hero, d end
            end
        end
        if not target then
            if current then data.target = nil; IssueImmediateOrder(unit, 'stop') end
            return
        end
        local order = GetUnitCurrentOrder(unit)
        if target ~= current or (order ~= ORDER_ID_ATTACK and order ~= ORDER_ID_SMART) then
            data.target = Unit[target]
            IssueTargetOrder(unit, 'attack', target)
        end
    end
end, Debug and Debug.getLine())
