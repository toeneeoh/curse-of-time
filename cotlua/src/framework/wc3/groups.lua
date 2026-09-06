OnInit.global("Groups", function(Require)
    Require('Variables')

    local passed_value = {}
    local ABIL_AVUL = ABIL_AVUL
    local ABIL_ALOC = ABIL_ALOC

    ---@type fun(pid: integer, g: group, r: rect, filter: boolexpr)
    function MakeGroupInRect(pid, g, r, filter)
        passed_value[#passed_value + 1] = pid
        GroupEnumUnitsInRect(g, r, filter)
        passed_value[#passed_value] = nil
    end

    ---@type fun(pid: integer, g: group, x: number, y: number, radius: number, filter: boolexpr)
    function MakeGroupInRange(pid, g, x, y, radius, filter)
        passed_value[#passed_value + 1] = pid
        GroupEnumUnitsInRange(g, x, y, radius, filter)
        passed_value[#passed_value] = nil
    end

    ---@type fun(pid: integer, g: group, x: number, y: number, radius: number, filter: boolexpr)
    function GroupEnumUnitsInRangeEx(pid, g, x, y, radius, filter)
        local enumerated = CreateGroup()

        MakeGroupInRange(pid, enumerated, x, y, radius, filter)
        BlzGroupAddGroupFast(enumerated, g)
        DestroyGroup(enumerated)
    end

    ---@type fun(u: unit): boolean
    function IsDummy(u)
        local id = GetUnitTypeId(u)
        return id == DUMMY_CASTER or id == DUMMY_VISION
    end

    ---@return boolean
    function ischar()
        local pid = GetPlayerId(GetOwningPlayer(GetFilterUnit())) + 1
        return GetFilterUnit() == Hero[pid] and UnitAlive(Hero[pid])
    end

    ---@return boolean
    function ishostile()
        local pid = GetPlayerId(GetOwningPlayer(GetFilterUnit()))
        return UnitAlive(GetFilterUnit())
            and GetUnitAbilityLevel(GetFilterUnit(), ABIL_AVUL) == 0
            and (pid == 10 or pid == 11 or pid == PLAYER_NEUTRAL_AGGRESSIVE)
    end

    ---@return boolean
    function isplayerAlly()
        local u = GetFilterUnit()
        return UnitAlive(u) and GetPlayerId(GetOwningPlayer(u)) <= PLAYER_CAP
            and IsUnitType(u, UNIT_TYPE_HERO) and GetUnitTypeId(u) ~= BACKPACK
    end

    ---@return boolean
    function isplayerunitRegion()
        local u = GetFilterUnit()
        return UnitAlive(u) and GetPlayerId(GetOwningPlayer(u)) <= PLAYER_CAP and not IsDummy(u)
    end

    ---@return boolean
    function isplayerunit()
        local u = GetFilterUnit()
        return UnitAlive(u) and GetPlayerId(GetOwningPlayer(u)) <= PLAYER_CAP
            and GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and not IsDummy(u)
    end

    ---@return boolean
    function ishostileEnemy()
        local u = GetFilterUnit()
        return UnitAlive(u) and GetUnitAbilityLevel(u, ABIL_AVUL) == 0
            and GetPlayerId(GetOwningPlayer(u)) <= PLAYER_CAP and not IsDummy(u)
    end

    ---@return boolean
    function isalive()
        local u = GetFilterUnit()
        return UnitAlive(u) and GetUnitAbilityLevel(u, ABIL_AVUL) == 0 and not IsDummy(u)
    end

    ---@return boolean
    function FilterEnemyDead()
        local u = GetFilterUnit()
        return GetUnitAbilityLevel(u, ABIL_AVUL) == 0
            and GetUnitAbilityLevel(u, ABIL_ALOC) == 0
            and not IsDummy(u)
            and not IsUnitAlly(u, Player(passed_value[#passed_value] - 1))
    end

    ---@return boolean
    function FilterEnemy()
        local u = GetFilterUnit()
        return UnitAlive(u)
            and IsUnitEnemy(u, Player(passed_value[#passed_value] - 1))
            and GetUnitAbilityLevel(u, ABIL_AVUL) == 0
            and GetUnitAbilityLevel(u, ABIL_ALOC) == 0
            and not IsDummy(u)
    end

    ---@return boolean
    function FilterAllyHero()
        local u = GetFilterUnit()
        return UnitAlive(u)
            and IsUnitAlly(u, Player(passed_value[#passed_value] - 1))
            and IsUnitType(u, UNIT_TYPE_HERO)
            and GetUnitAbilityLevel(u, ABIL_AVUL) == 0
            and GetUnitAbilityLevel(u, ABIL_ALOC) == 0
            and not IsDummy(u)
    end

    ---@return boolean
    function FilterAlly()
        local u = GetFilterUnit()
        return UnitAlive(u)
            and GetUnitAbilityLevel(u, ABIL_AVUL) == 0
            and GetUnitAbilityLevel(u, ABIL_ALOC) == 0
            and not IsDummy(u)
            and IsUnitAlly(u, Player(passed_value[#passed_value] - 1))
    end

    ---@return boolean
    function FilterEnemyAwake()
        local u = GetFilterUnit()
        return UnitAlive(u)
            and GetUnitAbilityLevel(u, ABIL_AVUL) == 0
            and GetUnitAbilityLevel(u, ABIL_ALOC) == 0
            and not IsDummy(u)
            and not IsUnitAlly(u, Player(passed_value[#passed_value] - 1))
            and not UnitIsSleeping(u)
    end

    ---@return boolean
    function FilterAlive()
        local u = GetFilterUnit()
        return UnitAlive(u)
            and GetUnitAbilityLevel(u, ABIL_AVUL) == 0
            and GetUnitAbilityLevel(u, ABIL_ALOC) == 0
            and not IsDummy(u)
    end
end)
