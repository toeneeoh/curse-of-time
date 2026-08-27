-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("GoddessesAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue
    local TQ = TimerQueue

    local SUN_STRIKE = Spell.define("A08M")
    do
        local thistype = SUN_STRIKE

        local function sun_strike(source, x, y)
            local ug = CreateGroup()

            MakeGroupInRange(BOSS_ID, ug, x, y, 150., Condition(FilterEnemy))

            DestroyEffect(AddSpecialEffect("war3mapImported\\OrbitalRay.mdx", x, y))

            for target in each(ug) do
                DamageTarget(source, target, 25000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end

        local function onStruck(target, source)
            if UnitAlive(target) and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                local ug = CreateGroup()
                BlzStartUnitAbilityCooldown(target, thistype.id, 20.)

                GroupEnumUnitsInRange(ug, GetUnitX(target), GetUnitY(target), 1250., Condition(isplayerAlly))

                local count = 0

                for u in each(ug) do
                    if count >= 3 then break end
                    local dummy = Dummy.create(GetUnitX(u), GetUnitY(u), 0, 0, 3.).unit
                    SetUnitScale(dummy, 4., 4., 4.)
                    BlzSetUnitFacingEx(dummy, 270)
                    BlzSetUnitSkin(dummy, FourCC('e01F'))
                    SetUnitVertexColor(dummy, 200, 200, 0, 255)

                    TQ:callDelayed(3., sun_strike, target, GetUnitX(u), GetUnitY(u))

                    count = count + 1
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
