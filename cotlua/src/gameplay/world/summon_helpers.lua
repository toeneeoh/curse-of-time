OnInit.global("SummonHelpers", function(Require)
    Require('Variables')
    Require('PlayerTimer')
    Require('TimerQueue')

    local cos, sin = math.cos, math.sin

    ---@param player_timer PlayerTimer
    function HideSummonDelay(player_timer)
        ShowUnit(player_timer.target, false)
        player_timer:destroy()
    end

    ---@param player_timer PlayerTimer
    function HideSummon(player_timer)
        SetUnitXBounded(player_timer.target, 30000)
        SetUnitYBounded(player_timer.target, 30000)
        player_timer:after(1., HideSummonDelay)
    end

    ---@param summon unit
    function SummonExpire(summon)
        local pid = GetPlayerId(GetOwningPlayer(summon)) + 1
        local unit_id = GetUnitTypeId(summon)

        TimerList[pid]:stopAllTimers(summon)

        if not IsUnitHidden(summon) then
            if unit_id == SUMMON_DESTROYER or unit_id == SUMMON_REAVER or unit_id == SUMMON_BRUTE then
                UnitRemoveAbility(summon, FourCC('BNpa'))
                UnitRemoveAbility(summon, FourCC('BNpm'))
                local player_timer = TimerList[pid]:add(summon)
                player_timer.target = summon
                player_timer.autoDestroy = false
                TimerQueue:callDelayed(2., DestroyEffect, AddSpecialEffectTarget(
                    "Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdl",
                    summon,
                    "origin"
                ))
                player_timer:after(2., HideSummon)
            end

            if UnitAlive(summon) then
                KillUnit(summon)
            end
        end
    end

    ---@param player player
    function CleanupSummons(player)
        for i = 1, #PLAYER_SUMMONS do
            local summon = PLAYER_SUMMONS[i]
            if GetOwningPlayer(summon) == player then
                SummonExpire(summon)
            end
        end
    end

    ---@param pid integer
    function RecallSummons(pid)
        local player = Player(pid - 1)
        local facing = bj_DEGTORAD * GetUnitFacing(Hero[pid])
        local x = GetUnitX(Hero[pid]) + 200 * cos(facing)
        local y = GetUnitY(Hero[pid]) + 200 * sin(facing)

        for i = 1, #PLAYER_SUMMONS do
            local summon = PLAYER_SUMMONS[i]
            local unit_id = GetUnitTypeId(summon)

            if GetOwningPlayer(summon) == player
                and (unit_id == SUMMON_REAVER or unit_id == SUMMON_BRUTE or unit_id == SUMMON_DESTROYER)
                and not IsUnitHidden(summon)
            then
                SetUnitPosition(summon, x, y)
                SetUnitPathing(summon, false)
                SetUnitPathing(summon, true)
                BlzSetUnitFacingEx(summon, GetUnitFacing(Hero[pid]))
            end
        end
    end
end, Debug and Debug.getLine())
