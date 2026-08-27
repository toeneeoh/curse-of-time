OnInit.final("SatanAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local random = math.random

    local FLAME_ONSLAUGHT = Spell.define("A03R")
    do
        local thistype = FLAME_ONSLAUGHT

        local function on_hit(source, target)
            if IsUnitEnemy(target, PLAYER_BOSS) then
                DamageTarget(source, target, 10000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end
        end

        local function onStruck(target, source)
            if random(0, 99) < 10 then
                local dummy = Dummy.create(GetUnitX(target), GetUnitY(target), FourCC('A0DN'), 1)
                dummy.source = target
                SetUnitOwner(dummy.unit, PLAYER_BOSS, false)
                IssuePointOrder(dummy.unit, "flamestrike", GetUnitX(source), GetUnitY(source))
                EVENT_DUMMY_ON_HIT:register_unit_action(target, on_hit)
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_STRUCK:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
