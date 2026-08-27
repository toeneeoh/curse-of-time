OnInit.final("VengefulPaladinAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")


    local HOLY_LIGHT = Spell.define("A0FI")
    do
        local thistype = HOLY_LIGHT

        local function onStruck(target, source)
            if UnitAlive(target) then
                IssueTargetOrder(target, "holybolt", target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
