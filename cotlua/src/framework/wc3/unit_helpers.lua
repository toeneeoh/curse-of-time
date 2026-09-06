OnInit.global("UnitHelpers", function()
    ---@type fun(u: unit, id: integer, disable: boolean)
    function UnitDisableAbility(u, id, disable)
        local level = GetUnitAbilityLevel(u, id)
        if level == 0 then return end

        UnitRemoveAbility(u, id)
        UnitAddAbility(u, id)
        SetUnitAbilityLevel(u, id, level)
        BlzUnitDisableAbility(u, id, disable, false)
        BlzUnitHideAbility(u, id, true)
    end

    ---@param u unit
    ---@param show boolean
    function ToggleCommandCard(u, show)
        local classification = BlzGetUnitIntegerField(u, UNIT_IF_UNIT_CLASSIFICATION)
        local ward = GetHandleId(UNIT_CATEGORY_WARD)

        if (BlzBitAnd(classification, ward) > 0 and show)
            or (BlzBitAnd(classification, ward) == 0 and not show) then
            BlzSetUnitIntegerField(u, UNIT_IF_UNIT_CLASSIFICATION,
                BlzBitXor(classification, ward))
        end
    end

    local stat_names = { "str", "int", "agi" }
    local literal_stat_names = { "Strength", "Intelligence", "Agility" }

    ---@param hero unit
    ---@param include_bonus boolean
    ---@return integer
    function HighestStat(hero, include_bonus)
        local strength = GetHeroStr(hero, include_bonus)
        local intelligence = GetHeroInt(hero, include_bonus)
        local agility = GetHeroAgi(hero, include_bonus)

        if strength >= agility and strength >= intelligence then
            return 1
        elseif intelligence >= strength and intelligence >= agility then
            return 2
        end
        return 3
    end

    ---@param hero unit
    ---@param literal boolean
    ---@param include_bonus boolean
    ---@return string
    function HighestStatName(hero, literal, include_bonus)
        if literal then
            return literal_stat_names[HighestStat(hero, include_bonus)]
        end
        return stat_names[HighestStat(hero, include_bonus)]
    end

    ---@param hero unit
    ---@return integer
    function MainStat(hero)
        return BlzGetUnitIntegerField(hero, UNIT_IF_PRIMARY_ATTRIBUTE)
    end
end)
