OnInit.final("MinotaurAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")


    local WAR_STOMP = Spell.define("A09J")
    do
        local thistype = WAR_STOMP

        local function onStruck(target, source)
            if UnitDistance(source, target) < 300. then
                if CastSpell(target, thistype.id, 1., 10, 1.) then
                    local pt = TimerList[BOSS_ID]:add(target)
                    pt.dmg = 2000.
                    pt.source = target
                    pt.dur = 8.
                    pt.name = "War Stomp"
                    pt:startLoop(1., StompPeriodic)
                    FloatingTextUnit(pt.name, target, 2., 60., 0, 12, 255, 255, 255, 0, true)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
