-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("DemonPrinceAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")


    local BLOODLUST = Spell.define("A0AX")
    do
        local thistype = BLOODLUST

        local function onStruck(target, source)
            if UnitAlive(target) and (GetWidgetLife(target) / BlzGetUnitMaxHP(target)) <= 0.5 and BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 then
                BlzStartUnitAbilityCooldown(target, thistype.id, 60.)
                DemonPrinceBloodlust:add(target, target):duration(60.)
                Dummy.create(GetUnitX(target), GetUnitY(target), FourCC('A041'), 1):cast(PLAYER_BOSS, "bloodlust", target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
