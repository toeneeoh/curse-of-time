-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("DragoonAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")


    local MINK_LUCK = Spell.define("A0BH")
    do
        local thistype = MINK_LUCK

        function thistype.onSetup(u)
            Unit[u].evasion = Unit[u].evasion + 50
        end
    end
end, Debug and Debug.getLine())
