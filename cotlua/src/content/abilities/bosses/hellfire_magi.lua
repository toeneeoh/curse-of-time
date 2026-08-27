-- Hellfire Magi abilities and their damage-driven casting behavior.

OnInit.final("HellfireMagiAbilities", function(Require)
    Require("Spells")
    Require("Buffs")
    Require("EnemyAI")

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
            if CastSpell(target, thistype.id, 1., 4, 1.) then
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

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 1, -1, 1, true) then
                IssueTargetOrder(target, "chainlightning", source)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local FLAME_STRIKE = Spell.define("A01T")
    do
        local thistype = FLAME_STRIKE

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 2, -1, 1, true) then
                IssuePointOrder(target, "flamestrike", GetUnitX(source), GetUnitY(source))
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
