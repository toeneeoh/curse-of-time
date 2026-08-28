-- Hellfire Magi abilities and their damage-driven casting behavior.

OnInit.final("HellfireMagiAbilities", function(Require)
    Require("Spells")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue

    local MAGIC_RESIST = Spell.define('A04A')
    do
        function MAGIC_RESIST.onSetup(u)
            Unit[u].mr = Unit[u].mr * 0.7
        end
    end

    local FROST_ARMOR = Spell.define("A02M")
    do
        local thistype = FROST_ARMOR

        local function onStruck(target)
            if not FrostArmorBuff:has(nil, target) and CastSpell(target, thistype.id, 1., 4, 1.) then
                FrostArmorBuff:add(target, target):duration(10.)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local CHAIN_LIGHTNING = Spell.define("A00G")
    do
        local thistype = CHAIN_LIGHTNING

        local function cast(caster, target, level)
            if UnitAlive(caster) and UnitAlive(target) then
                Dummy.create(GetUnitX(caster), GetUnitY(caster), thistype.id, level, 8.)
                    :cast(PLAYER_BOSS, "chainlightning", target, nil, caster, thistype.tag)
            end
        end

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 1., 4, 1.) then
                TQ:callDelayed(1., cast, target, source, GetUnitAbilityLevel(target, thistype.id))
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local FLAME_STRIKE = Spell.define("A01T")
    do
        local thistype = FLAME_STRIKE

        local function cast(caster, x, y, level)
            if UnitAlive(caster) then
                Dummy.create(GetUnitX(caster), GetUnitY(caster), thistype.id, level, 15.)
                    :cast(PLAYER_BOSS, "flamestrike", x, y, caster, thistype.tag)
            end
        end

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 2., 4, 1.) then
                TQ:callDelayed(2., cast, target, GetUnitX(source), GetUnitY(source), GetUnitAbilityLevel(target, thistype.id))
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
