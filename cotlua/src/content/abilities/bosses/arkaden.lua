OnInit.final("ArkadenAbilities", function(Require)
    Require("Spells")
    Require("SpellTools")
    Require("Buffs")
    Require("EnemyAI")
    Require("TimerQueue")

    local TQ = TimerQueue

    local METAMORPHOSIS = Spell.define("A065")
    do
        local thistype = METAMORPHOSIS

        local function onStruck(target, source)
            if GetWidgetLife(target) < BlzGetUnitMaxHP(target) * 0.5 then
                local u = Unit[target]
                u:morph(FourCC('E007'))
                u.base_bat = 3.0
                BlzSetUnitBaseDamage(target, -5200, 0)
                BlzSetUnitWeaponIntegerField(target, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, ATTACK_CHAOS)
                UnitAddAbility(target, RAISE_SKELETON.id)
                RAISE_SKELETON.onSetup(target)
                EVENT_ENEMY_AI:unregister_unit_action(target, onStruck)
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end

    local FROST_NOVA = Spell.define("A066")
    do
        local thistype = FROST_NOVA

        local function nova(target)
            if UnitAlive(target) then
                local ug = CreateGroup()

                MakeGroupInRange(BOSS_ID, ug, GetUnitX(target), GetUnitY(target), 700., Condition(FilterEnemy))
                DestroyEffect(AddSpecialEffect("war3mapImported\\FrostNova.mdx", GetUnitX(target), GetUnitY(target)))

                for enemy in each(ug) do
                    Freeze:add(target, enemy):duration(3.)
                    DamageTarget(target, enemy, 15000., ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
                end

                DestroyGroup(ug)
            end
        end

        local function onStruck(target, source)
            if IsUnitInRange(target, source, 700.) then
                local anim = GetUnitTypeId(target) == FourCC('E007') and 8 or 2

                if CastSpell(target, thistype.id, 1., anim, 1.) then
                    FloatingTextUnit(thistype.tag, target, 1.75, 100, 0, 12, 255, 255, 255, 0, true)
                    TQ:callDelayed(1., nova, target)
                end
            end
        end

        function thistype.onSetup(u)
            EVENT_ENEMY_AI:register_unit_action(u, onStruck)
        end
    end
end, Debug and Debug.getLine())
