OnInit.global("Taunt", function(Require)
    Require('Variables')
    Require('Groups')

    ---@type fun(hero: unit, aoe: number)
    function Taunt(hero, aoe)
        local pid = GetPlayerId(GetOwningPlayer(hero)) + 1
        if IS_TAUNT_DISABLED[pid] then return end

        local group = CreateGroup()
        MakeGroupInRange(pid, group, GetUnitX(hero), GetUnitY(hero), aoe, Condition(FilterEnemy))
        for enemy in each(group) do
            Unit[hero]:taunt(Unit[enemy])
        end
        DestroyGroup(group)
    end
end)
