OnInit.global("CombatStatus", function(Require)
    Require('Variables')

    ---@param u unit
    ---@return boolean
    function IsUnitStunned(u)
        return Stun:has(nil, u) or Freeze:has(nil, u) or KnockUp:has(nil, u)
            or GetUnitAbilityLevel(u, FourCC('BPSE')) > 0
            or GetUnitAbilityLevel(u, FourCC('BSTN')) > 0
    end

    ---@type fun(pid: integer, target: unit, duration: number)
    function StunUnit(pid, target, duration)
        local stun = Stun:add(Hero[pid], target)
        if IsUnitType(target, UNIT_TYPE_HERO) then
            stun:duration(duration * 0.5)
        else
            stun:duration(duration)
        end
    end
end)
