-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("OrstedAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue
    local TQ = TimerQueue

    local CLOUD_OF_DESPAIR = Spell.define("A03W")
    do
        local thistype = CLOUD_OF_DESPAIR

        local function periodic(pt)
            pt.time = pt.time + 1.

            if pt.time < pt.dur then
                MakeGroupInRange(BOSS_ID, pt.ug, pt.x, pt.y, 300., Condition(FilterEnemy))

                for target in each(pt.ug) do
                    DamageTarget(pt.source, target, BlzGetUnitMaxHP(target) * 0.05, ATTACK_TYPE_NORMAL, PURE, "Cloud of Despair")
                end

                return true
            end

            return false
        end

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 1.5, 3, 1.2) then
                local pt = TimerList[BOSS_ID]:add(target)
                pt.x = GetRandomReal(GetRectMinX(gg_rct_Crypt) + 200., GetRectMaxX(gg_rct_Crypt) - 200.)
                pt.y = GetRandomReal(GetRectMinY(gg_rct_Crypt) + 200., GetRectMaxY(gg_rct_Crypt) - 200.)
                pt.sfx = AddSpecialEffect("war3mapImported\\SporeCloud025_Priority005.mdx", pt.x, pt.y)
                pt.dur = 8.
                pt.source = target
                pt.ug = CreateGroup()

                BlzSetUnitFacingEx(target, math.atan(pt.y - GetUnitY(target), pt.x - GetUnitX(target)) * bj_RADTODEG)

                pt:startLoop(1., periodic)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SCREAM_OF_DESPAIR = Spell.define("A04Q")
    do
        local thistype = SCREAM_OF_DESPAIR

        local function expire(target)
            if CastSpell(target, 0, 1.8, 5, 1.2) then
                local ug = CreateGroup()

                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 500., Condition(FilterEnemy))
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\HowlOfTerror\\HowlCaster.mdl", target, "origin"))

                for enemy in each(ug) do
                    Fear:add(target, enemy):duration(6.)
                end

                DestroyGroup(ug)
            end
        end

        local function onStruck(target, source)
            if UnitDistance(source, target) <= 300. then
                if CastSpell(target, thistype.id, 2., 1, 1.) then
                    FloatingTextUnit(thistype.tag, target, 3, 100, 0, 13, 255, 255, 255, 0, true)

                    TQ:callDelayed(2, expire)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
