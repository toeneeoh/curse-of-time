-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("AbsoluteHorrorAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local random = math.random
    local random = math.random

    local TRUE_STEALTH = Spell.define("A0AC")
    do
        local thistype = TRUE_STEALTH

        local function expire(pt)
            local ug = CreateGroup()

            MakeGroupInRange(BOSS_ID, ug, pt.x, pt.y, 400., Condition(FilterEnemy))

            UnitRemoveAbility(pt.source, FourCC('Amrf'))
            UnitRemoveAbility(pt.source, FourCC('A043'))
            UnitRemoveAbility(pt.source, FourCC('BOwk'))
            UnitRemoveAbility(pt.source, ABIL_AVUL)
            SetUnitXBounded(pt.source, pt.x)
            SetUnitYBounded(pt.source, pt.y)
            SetUnitAnimation(pt.source, "Attack Slam")

            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", pt.x, pt.y))

            local count = BlzGroupGetSize(ug)

            if count > 0 then
                local target = BlzGroupUnitAt(ug, GetRandomInt(0, count - 1))
                local heal = GetWidgetLife(target)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Stampede\\StampedeMissileDeath.mdl", target, "origin"))
                DamageTarget(pt.source, target, 80000. + BlzGetUnitMaxHP(target) * 0.3, ATTACK_TYPE_NORMAL, MAGIC, "True Stealth")
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", pt.source, "chest"))
                heal = math.max(0, heal - GetWidgetLife(target))
                SetUnitState(pt.source, UNIT_STATE_LIFE, GetWidgetLife(pt.source) + heal)
            end

            DestroyGroup(ug)
        end

        local function onStruck(target, source)
            if random(0, 99) < 10 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.8 then
                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 1500., Condition(FilterEnemy))

                local u = FirstOfGroup(ug)
                if u then
                    BlzStartUnitAbilityCooldown(target, thistype.id, 10.)

                    FloatingTextUnit(thistype.tag, target, 1.75, 100, 0, 12, 90, 30, 150, 0, true)
                    Buff.dispelAll(target)
                    UnitAddAbility(target, ABIL_AVUL)
                    UnitAddAbility(target, FourCC('A043'))
                    IssueImmediateOrder(target, "windwalk")

                    local angle = math.atan(GetUnitY(u) - GetUnitY(target), GetUnitX(u) - GetUnitX(target))
                    UnitAddAbility(target, FourCC('Amrf'))
                    IssuePointOrder(target, "move", GetUnitX(u) + 300 * math.cos(angle), GetUnitY(u) + 300 * math.sin(angle))
                    local pt = TimerList[BOSS_ID]:add(target)
                    pt.x = GetUnitX(u) + 150 * math.cos(angle)
                    pt.y = GetUnitY(u) + 150 * math.sin(angle)
                    pt.source = target
                    pt:after(2., expire)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
