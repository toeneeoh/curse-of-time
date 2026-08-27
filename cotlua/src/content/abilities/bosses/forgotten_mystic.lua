-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("ForgottenMysticAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")


    local MANA_SHIELD = Spell.define('A062')
    do
        local thistype = MANA_SHIELD

        local function onStruck(target, source, amount, amount_after_red)
            local taken = amount_after_red / 3.
            local dmg = GetUnitState(target, UNIT_STATE_MANA) - taken

            if dmg >= 0. then
                ArcingTextTag.create(taken, target, 1, 1, 170, 50, 220, 0)
                UnitAddAbility(target, FourCC('A058'))
            else
                UnitRemoveAbility(target, FourCC('A058'))
            end

            SetUnitState(target, UNIT_STATE_MANA, math.max(0., dmg))

            amount.value = math.max(0., 0. - dmg * 3.)
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK_AFTER_REDUCTIONS:register_unit_action(u, onStruck)
        end
    end

    local MANA_DRAIN = Spell.define("A01Z")
    do
        local thistype = MANA_DRAIN

        local function onStruck(target, source)
            if UnitDistance(target, source) < 800. then
                if CastSpell(target, thistype.id, 1.5, 4, 1.) then
                    local ug = CreateGroup()
                    MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 800., Condition(FilterEnemy))

                    for enemy in each(ug) do
                        if not ManaDrainDebuff:has(target, enemy) and not Unit[enemy].nomanaregen then
                            ManaDrainDebuff:add(target, enemy):duration(9999.)
                        end
                    end

                    DestroyGroup(ug)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
