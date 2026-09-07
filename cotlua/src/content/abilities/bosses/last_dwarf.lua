OnInit.final("LastDwarfAbilities", function(Require)
    Require('BossSchema')
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")


    local DWARF_AVATAR = Spell.define("A0DV")
    do
        local thistype = DWARF_AVATAR

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(target, source) < 300. then
                IssueImmediateOrder(target, "avatar")
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local THUNDER_CLAP = Spell.define("A0A2")
    do
        local thistype = THUNDER_CLAP

        local function onStruck(target, source)
            if UnitDistance(target, source) < 300. then
                if CastSpell(target, thistype.id, 1., 10, 1.) then
                    local pt = TimerList[BOSS_ID]:add(target)
                    pt.dmg = 4000.
                    pt.source = target
                    pt.dur = 8.
                    pt.name = "Thunder Clap"
                    pt:startLoop(1., StompPeriodic)
                    FloatingTextUnit(pt.name, target, 2., 60., 0, 12, 0, 255, 255, 0, true)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
