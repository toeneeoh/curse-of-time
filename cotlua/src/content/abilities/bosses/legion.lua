OnInit.final("LegionAbilities", function(Require)
    Require('BossSchema')
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue

    local REALITY_RIP = Spell.define('A06M')
    do
        local thistype = REALITY_RIP

        local function onHit(source, target)
            local dmg = (IsUnitIllusion(source) and BlzGetUnitMaxHP(target) * 0.0025) or BlzGetUnitMaxHP(target) * 0.005
            DamageTarget(source, target, dmg, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
        end

        function thistype.onSetup(u)
            EVENT_ON_HIT_EVADE:register_unit_action(u, onHit)
        end
    end

    local SHADOW_STEP = Spell.define("A05I")
    do
        local thistype = SHADOW_STEP

        local function onStruck(target, source)
            if UnitDistance(source, target) > 250. then
                if CastSpell(target, thistype.id, 0., 1, 1.) then
                    BossTeleport(source, 1.5)
                end
            end
        end

        function thistype.onSetup(u)
            if not IsUnitIllusion(u) then
                EVENT_ENEMY_AI:register_unit_action(u, onStruck)
            end
        end
    end

    local LEGION = Spell.define("A08C")
    do
        local thistype = LEGION

        local function spawn(target)
            if UnitAlive(target) then
                for _ = 0, 6 do
                    UnitAddItemById(target, FourCC('I06V'))
                end
            end
        end

        local function onStruck(target, source)
            if IsUnitInRange(target, source, 800.) then
                if CastSpell(target, thistype.id, 0.5, 12, 1.) then
                    TQ:callDelayed(2, DestroyEffect, AddSpecialEffect("Abilities\\Spells\\Orc\\MirrorImage\\MirrorImageCaster.mdl", GetUnitX(target), GetUnitY(target)))
                    Boss[BOSS_LEGION].loc_x = GetUnitX(source)
                    Boss[BOSS_LEGION].loc_y = GetUnitY(source)
                    TQ:callDelayed(0.5, spawn, target)
                end
            end
        end

        function thistype.onSetup(u)
            if not IsUnitIllusion(u) then
                EVENT_ENEMY_AI:register_unit_action(u, onStruck)
            end
        end
    end
end, Debug and Debug.getLine())
