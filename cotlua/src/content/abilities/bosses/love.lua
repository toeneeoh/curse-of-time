OnInit.final("LoveAbilities", function(Require)
    Require('BossSchema')
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue

    local HOLY_WARD = Spell.define("A06T")
    do
        local thistype = HOLY_WARD

        local function holy_ward(holyward)
            if UnitAlive(holyward) then
                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(holyward), GetUnitY(holyward), 2000., Condition(FilterAlly))

                for target in each(ug) do
                    HP(holyward, target, 100000)
                    HolyBlessing:add(target, target):duration(30.)
                    TQ:callDelayed(2, DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\Human\\Resurrect\\ResurrectTarget.mdl", target, "origin"))
                end

                KillUnit(holyward)
                DestroyGroup(ug)
            end
        end

        local function onStruck(target, source)
            if (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 then
                if CastSpell(target, thistype.id, 0.5, 9, 1.5) then
                    local holyward = CreateUnit(PLAYER_BOSS, FourCC('o009'), GetRandomReal(GetRectMinX(gg_rct_Crystal_Spawn) - 500, GetRectMaxX(gg_rct_Crystal_Spawn) + 500), GetRandomReal(GetRectMinY(gg_rct_Crystal_Spawn) - 600, GetRectMaxY(gg_rct_Crystal_Spawn) + 600), 0)
                    local ug = CreateGroup()

                    MakeGroupInRange(BOSS_ID, ug, GetUnitX(holyward), GetUnitY(holyward), 1250., Condition(FilterEnemy))
                    BlzSetUnitMaxHP(holyward, 10 * BlzGroupGetSize(ug))
                    SetWidgetLife(holyward, BlzGetUnitMaxHP(holyward))
                    Unit[holyward].hit_based_health = true

                    TQ:callDelayed(10., holy_ward, holyward)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
