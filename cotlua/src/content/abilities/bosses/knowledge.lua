OnInit.final("KnowledgeAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue

    local GHOST_SHROUD = Spell.define("A0A8")
    do
        local thistype = GHOST_SHROUD

        local function ghost_shroud(target)
            if IsUnitType(target, UNIT_TYPE_ETHEREAL) then
                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 500., Condition(FilterEnemy))

                for enemy in each(ug) do
                    local dmg = math.max(0, GetHeroInt(target, true) - GetHeroInt(enemy, true))

                    DamageTarget(target, enemy, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyGroup(ug)

                TQ:callDelayed(1., ghost_shroud, target)
            end
        end

        local function onStruck(target, source)
            if (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 then
                if CastSpell(target, thistype.id, 0.25, 8, 1.5) then
                    Dummy.create(GetUnitX(target), GetUnitY(target), thistype.id, 1):cast(PLAYER_BOSS, "banish", target)
                    TQ:callDelayed(1., ghost_shroud, target)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local SILENCE = Spell.define("A05B")
    do
        local thistype = SILENCE

        local function onStruck(target, source)
            if (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 then
                if CastSpell(target, thistype.id, 1., 8, 1.5) then
                    local ug = CreateGroup()

                    MakeGroupInRange(BOSS_ID, ug, GetUnitX(source), GetUnitY(source), 1000., Condition(FilterEnemy))
                    DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Silence\\SilenceAreaBirth.mdl", GetUnitX(source), GetUnitY(source)))

                    for enemy in each(ug) do
                        Silence:add(target, enemy):duration(10.)
                    end

                    DestroyGroup(ug)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local DISARM = Spell.define("A05W")
    do
        local thistype = DISARM

        local function onStruck(target, source)
            if (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.9 then
                if CastSpell(target, thistype.id, 1., 8, 1.5) then
                    Disarm:add(target, source):duration(6.)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
