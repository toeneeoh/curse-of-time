-- Boss-owned abilities extracted from the legacy unit spell registry.

OnInit.final("HateAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")


    local SPELL_REFLECT = Spell.define('A00S')
    do
        local thistype = SPELL_REFLECT

        local function onStruck(target, source, amount)
            if BlzGetUnitAbilityCooldownRemaining(target, thistype.id) <= 0 and amount.value > 10000. then
                local angle = math.atan(GetUnitY(source) - GetUnitY(target), GetUnitX(source) - GetUnitX(target))
                local sfx = AddSpecialEffect("war3mapImported\\BoneArmorCasterTC.mdx", GetUnitX(target) + 75. * math.cos(angle), GetUnitY(target) + 75. * math.sin(angle))

                BlzSetSpecialEffectZ(sfx, BlzGetUnitZ(target) + 80.)
                BlzSetSpecialEffectColorByPlayer(sfx, Player(0))
                BlzSetSpecialEffectYaw(sfx, angle)
                BlzSetSpecialEffectScale(sfx, 0.9)
                BlzSetSpecialEffectTimeScale(sfx, 3.)

                DestroyEffect(sfx)

                BlzStartUnitAbilityCooldown(target, thistype.id, 5.)
                --call DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\ManaShield\\ManaShieldCaster.mdl", target, "origin"))
                DamageTarget(target, source, math.min(amount.value, 2500), ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)

                amount.value = math.max(0, amount.value - 20000)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
