-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("SirenAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue
    local TQ = TimerQueue

    local TORNADO_STORM = Spell.define("A085")
    do
        local thistype = TORNADO_STORM

        local function onStruck(target, source)
            if IsUnitInRange(target, source, 500.) then
                if CastSpell(target, thistype.id, 1.5, 5, 1.) then
                    local dummy = CreateUnit(PLAYER_BOSS, FourCC('n001'), GetUnitX(target), GetUnitY(target), 0.)
                    IssuePointOrder(dummy, "move", GetRandomReal(GetUnitX(target) - 250, GetUnitX(target) + 250), GetRandomReal(GetUnitY(target) - 250, GetUnitY(target) + 250))
                    TQ:callDelayed(40., RemoveUnit, dummy)
                    dummy = CreateUnit(PLAYER_BOSS, FourCC('n001'), GetUnitX(target), GetUnitY(target), 0.)
                    IssuePointOrder(dummy, "move", GetRandomReal(GetUnitX(target) - 250, GetUnitX(target) + 250), GetRandomReal(GetUnitY(target) - 250, GetUnitY(target) + 250))
                    TQ:callDelayed(40., RemoveUnit, dummy)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
