OnInit.final("DeathKnightAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local random = math.random

    local DECAY = Spell.define('A08N')
    do
        local thistype = DECAY

        local function onHit(source, target)
            if random(0, 99) < 20 then
                DamageTarget(source, target, 2500., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", target, "origin"))
            end
        end

        function thistype.onSetup(u)
            EVENT_ON_HIT_EVADE:register_unit_action(u, onHit)
        end
    end

    local DEATH_MARCH = Spell.define("A0AO")
    do
        local thistype = DEATH_MARCH

        local function onStruck(target, source)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and UnitDistance(source, target) > 250. then
                BlzStartUnitAbilityCooldown(target, thistype.id, 20.)
                BossTeleport(source, 1.5)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local DEATH_STRIKES = Spell.define("A088")
    do
        local thistype = DEATH_STRIKES

        local function expire(pt)
            DestroyEffect(AddSpecialEffect("NecroticBlast.mdx", pt.x, pt.y))

            local ug = CreateGroup()

            MakeGroupInRange(BOSS_ID, ug, pt.x, pt.y, 180., Condition(FilterEnemy))

            for target in each(ug) do
                DamageTarget(pt.source, target, 15000., ATTACK_TYPE_NORMAL, MAGIC, DEATHSTRIKE.tag)
            end

            DestroyGroup(ug)
        end

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 0.7, 3, 1.) then
                local ug = CreateGroup()
                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 1250., Condition(FilterEnemy))
                FloatingTextUnit(thistype.tag, target, 2., 60., 0, 12, 255, 255, 255, 0, true)
                local count = 0
                for u in each(ug) do
                    if count >= 3 then
                        break
                    end
                    local pt = TimerList[BOSS_ID]:add(target)
                    pt.x = GetUnitX(u)
                    pt.y = GetUnitY(u)
                    pt.sfx = AddSpecialEffect("CircleOutBuff_Portrait.mdl", pt.x, pt.y)
                    pt.source = target
                    BlzSetSpecialEffectScale(pt.sfx, 4.)
                    BlzSetSpecialEffectZ(pt.sfx, GetLocZ(pt.x, pt.y) + 50.)
                    pt:after(3., expire)
                    count = count + 1
                end
                DestroyGroup(ug)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
