OnInit.global("WorldTransitions", function(Require)
    Require('Variables')
    Require('PlayerLifecycle')

    ---@param group_number integer
    ---@return rect
    function SelectGroupedRegion(group_number)
        local region_gap = 25
        local low_bound = group_number * region_gap
        local high_bound = low_bound

        while RegionCount[high_bound] ~= nil do
            high_bound = high_bound + 1
        end

        return RegionCount[GetRandomInt(low_bound, high_bound - 1)]
    end

    ---@param players table
    ---@param x number
    ---@param y number
    function MovePlayers(players, x, y)
        for _, pid in ipairs(players) do
            pid = (type(pid) == "userdata" and GetPlayerId(pid) + 1) or pid
            MoveHero(pid, x, y)
            DestroyEffect(AddSpecialEffectTarget(
                "Abilities\\Spells\\Human\\MassTeleport\\MassTeleportCaster.mdl",
                Hero[pid],
                "origin"
            ))
        end
    end
end, Debug and Debug.getLine())
