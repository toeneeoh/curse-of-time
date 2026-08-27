-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("EssenceOfDarknessAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue
    local random = math.random

    ---@type fun(boss: unit, baseDamage: integer, hgroup: integer, speffect: string, tag: string)
    local function BossPlusSpell(boss, baseDamage, hgroup, speffect, tag)
        local castx = GetUnitX(boss) ---@type number
        local casty = GetUnitY(boss) ---@type number
        local dx ---@type number
        local dy ---@type number

        if UnitAlive(boss) then
            for i = -8, 8 do
                DestroyEffect(AddSpecialEffect(speffect, castx + 80 * i, casty - 75))
                DestroyEffect(AddSpecialEffect(speffect, castx + 80 * i, casty + 75))
                DestroyEffect(AddSpecialEffect(speffect, castx - 75, casty + 80 * i))
                DestroyEffect(AddSpecialEffect(speffect, castx + 75, casty + 80 * i))
            end

            local ug = CreateGroup()

            GroupEnumUnitsInRange(ug, castx, casty, 750, Condition(ishostileEnemy))

            for target in each(ug) do
                --call DestroyEffect(AddSpecialEffect("Abilities\\Weapons\\LordofFlameMissile\\LordofFlameMissile.mdl", GetUnitX(target), GetUnitY(target)))
                dx = RAbsBJ(GetUnitX(target) - castx)
                dy = RAbsBJ(GetUnitY(target) - casty)
                if dx < 150 and dy < 700 then
                    DamageTarget(boss, target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
                elseif dx < 700 and dy < 150 then
                    DamageTarget(boss, target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
                end
            end

            DestroyGroup(ug)
        end
    end

    ---@type fun(boss: unit, baseDamage: integer, hgroup: integer, speffect: string, tag: string)
    local function BossXSpell(boss, baseDamage, hgroup, speffect, tag)
        local castx      = GetUnitX(boss) ---@type number
        local casty      = GetUnitY(boss) ---@type number
        local dx ---@type number
        local dy ---@type number

        if UnitAlive(boss) then
            for i = -8, 8 do
                DestroyEffect(AddSpecialEffect(speffect, castx + 75 * i, casty + 75 * i))
                DestroyEffect(AddSpecialEffect(speffect, castx + 75 * i, casty - 75 * i))
            end

            local ug = CreateGroup()
            GroupEnumUnitsInRange(ug, castx, casty, 750, Condition(ishostileEnemy))

            for target in each(ug) do
                dx = RAbsBJ(GetUnitX(target) - castx)
                dy = RAbsBJ(GetUnitY(target) - casty)
                if RAbsBJ(dx - dy) < 200 then
                    DamageTarget(boss, target, baseDamage, ATTACK_TYPE_NORMAL, MAGIC, tag)
                end
            end

            DestroyGroup(ug)
        end
    end

    local MORTIFY_TERRIFY = Spell.define("A03M")
    do
        local thistype = MORTIFY_TERRIFY

        local function expire(pt)
            if pt.spell == 1 then
                BossPlusSpell(pt.source, 1000000, 1, "Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", "Mortify")
            elseif pt.spell == 2 then
                BossXSpell(pt.source, 1000000,1, "Abilities\\Spells\\Undead\\AnimateDead\\AnimateDeadTarget.mdl", "Terrify")
            end
        end

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 2., 0, 1) then
                BlzStartUnitAbilityCooldown(target, FourCC('A05U'), 5.)
                local pt = TimerList[BOSS_ID]:add(target)
                pt.source = target
                if random(1, 2) == 1 then
                    FloatingTextUnit("+ MORTIFY +", target, 3, 70, 0, 11, 255, 255, 255, 0, true)
                    pt.spell = 1
                else
                    FloatingTextUnit("x TERRIFY x", target, 3, 70, 0, 11, 255, 255, 255, 0, true)
                    pt.spell = 2
                end

                pt:after(4., expire)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local FREEZE = Spell.define("A02Q")
    do
        local thistype = FREEZE

        local function expire(target)
            if UnitAlive(target) then
                local ug = CreateGroup()

                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 300., Condition(FilterEnemy))
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdl", GetUnitX(target), GetUnitY(target)))

                for enemy in each(ug) do
                    Stun:add(target, enemy):duration(5.)
                end

                DestroyGroup(ug)
            end
        end

        local function onStruck(target, source)
            if CastSpell(target, thistype.id, 2., 5, 1.) then
                FloatingTextUnit("||||| FREEZE |||||", target, 3, 70, 0, 11, 255, 255, 255, 0, true)
                TQ:callDelayed(4., expire, target)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
