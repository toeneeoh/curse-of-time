OnInit.final("SlaughterQueenAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue
    local random = math.random

    local SLAUGHTER_AVATAR = Spell.define("A040")
    do
        local thistype = SLAUGHTER_AVATAR

        local function reset(target)
            SetUnitMoveSpeed(target, 300)
        end

        local function avatar(target)
            IssueImmediateOrder(target, "avatar")
            SetUnitMoveSpeed(target, 270)
            TQ:callDelayed(10., reset, target)
        end

        local function onStruck(target, source)
            if math.random(0, 99) < 13 then
                if CastSpell(target, thistype.id, 0., -1, 1.) then
                    FloatingTextUnit("Avatar", target, 3, 100, 0, 13, 255, 255, 255, 0, true)
                    TQ:callDelayed(2., avatar, target)
                end
            end
        end

        function thistype.onSetup(u)
            local boss = IsBoss(u)
            SetUnitAbilityLevel(u, FourCC('A064'), boss.difficulty)
            SetUnitAbilityLevel(u, thistype.id, boss.difficulty)

            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
