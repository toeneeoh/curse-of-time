OnInit.final("ItemEquipmentProcs", function(Require)
    Require("Spells")

    local TQ = TimerQueue

    local ARMOR_OF_THE_GODS = Spell.define('Aarm')
    do
        local thistype = ARMOR_OF_THE_GODS

        function thistype.onEquip(itm, id, index)
            BlzSetAbilityRealLevelField(BlzGetUnitAbility(itm.holder, id), ABILITY_RLF_ARMOR_BONUS_HAD1, 0, itm.cached_stats[index])
        end
    end

    local BASH = Spell.define('Abas')
    do
        local thistype = BASH

        function thistype.onEquip(itm, id, index)
            BlzSetAbilityRealLevelField(BlzGetUnitAbility(itm.holder, id), ABILITY_RLF_CHANCE_TO_BASH, 0, itm.cached_stats[index])
            BlzSetAbilityRealLevelField(BlzGetUnitAbility(itm.holder, id), ABILITY_RLF_DURATION_NORMAL, 0, itm:getAbilityArgument(index, 1))
            BlzSetAbilityRealLevelField(BlzGetUnitAbility(itm.holder, id), ABILITY_RLF_DURATION_HERO, 0, itm:getAbilityArgument(index, 1))
        end
    end

    local SHIELD_BLOCK = Spell.define('Zs00', 'Zs01', 'Zs02', 'Zs03', 'Zs04', 'Zs05', 'Zs06')
    do
        local thistype = SHIELD_BLOCK
        function thistype.onUnequip(itm, id, index, orig_holder)
            local runtime = itm.abilities[index]

            if runtime and runtime.callback then
                EVENT_ON_STRUCK_MULTIPLIER:unregister_unit_action(orig_holder, runtime.callback)
            end
        end

        function thistype.onEquip(itm, id, index)
            local runtime = itm.abilities[index]

            runtime.block_chance = itm.cached_stats[index]
            runtime.damage_reduction = itm:getAbilityArgument(index, 1)
            runtime.callback = runtime.callback or function(target, source, amount, damage_type)
                local block_chance = runtime.block_chance or 0
                local damage_reduction = runtime.damage_reduction or 0

                if damage_type == PHYSICAL and math.random(0, 99) < block_chance then
                    amount.value = amount.value * (1. - damage_reduction * 0.01)
                end
            end

            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(itm.holder, runtime.callback)
        end
    end

    local AZAZOTH_BLADE_STORM = Spell.define('A07G')
    do
        local thistype = AZAZOTH_BLADE_STORM

        ---@type fun(pt: PlayerTimer): boolean
        local function periodic(pt)
            pt.dur = pt.dur - 0.05 --tick rate

            if pt.dur > 0. then
                -- spawn effect
                local x, y = GetUnitX(pt.source), GetUnitY(pt.source)
                local sfx = AddSpecialEffect("war3mapImported\\Ephemeral Slash Purple.mdl", x, y)
                BlzSetSpecialEffectTimeScale(sfx, GetRandomReal(0.8, 1.1))
                BlzSetSpecialEffectZ(sfx, GetUnitZ(pt.source) + 50.)
                BlzSetSpecialEffectScale(sfx, 1.3)
                BlzSetSpecialEffectYaw(sfx, math.random() * 2 * bj_PI)
                TQ:callDelayed(0.75, DestroyEffect, sfx)

                sfx = AddSpecialEffect("war3mapImported\\Ephemeral Slash Purple.mdl", x, y)
                BlzSetSpecialEffectTimeScale(sfx, GetRandomReal(0.8, 1.1))
                BlzSetSpecialEffectZ(sfx, GetUnitZ(pt.source) + 50.)
                BlzSetSpecialEffectScale(sfx, 0.7)
                BlzSetSpecialEffectYaw(sfx, math.random() * 2 * bj_PI)
                TQ:callDelayed(0.75, DestroyEffect, sfx)

                if pt.dur < 4.85 and ModuloReal(pt.dur, 0.25) < 0.05 then --do damage every 0.25 second
                    MakeGroupInRange(pt.pid, pt.ug, GetUnitX(pt.source), GetUnitY(pt.source), 300., Condition(FilterEnemy))

                    for target in each(pt.ug) do
                        DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\Critters\\Albatross\\CritterBloodAlbatross.mdl", target, "chest"))
                        DamageTarget(pt.source, target, (UnitGetBonus(pt.source, BONUS_DAMAGE) + GetHeroStr(pt.source, true)) * 0.25 * BOOST[pt.pid], ATTACK_TYPE_NORMAL, MAGIC, "Blade Storm")
                    end
                end

                return true
            end

            return false
        end

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()
            pt.dur = 5.
            pt.source = self.caster
            pt.ug = CreateGroup()
            pt:startLoop(0.05, periodic)
        end
    end

    local AZAZOTH_STOMP = Spell.define('A0B5')
    do
        local thistype = AZAZOTH_STOMP

        function thistype:onCast()
            local ug = CreateGroup()
            MakeGroupInRange(self.pid, ug, self.x, self.y, 550.00, Condition(FilterEnemy))

            for target in each(ug) do
                AzazothHammerStomp:add(self.caster, target):duration(15.)
                DamageTarget(self.caster, target, 15.00 * GetHeroStr(self.caster, true) * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end
    end

    local MANA_FLOW = Spell.define('A0C0')
    do
        local thistype = MANA_FLOW

        function thistype.onUnequip(itm, id, index, orig_holder)
            Unit[itm.holder].mana_regen_percent = Unit[orig_holder].mana_regen_percent - 2
        end

        function thistype.onEquip(itm, id, index)
            Unit[itm.holder].mana_regen_percent = Unit[itm.holder].mana_regen_percent + 2
        end
    end

    local HORSE_BOOST = Spell.define('A09O')
    do
        local thistype = HORSE_BOOST

        function thistype.onUnequip(itm, id, index, orig_holder)
            Unit[itm.holder].mana_regen_max = Unit[orig_holder].mana_regen_max - 0.7
        end

        function thistype.onEquip(itm, id, index)
            Unit[itm.holder].mana_regen_max = Unit[itm.holder].mana_regen_max + 0.7
        end
    end

    local RESURGENCE = Spell.define('Areg')
    do
        local thistype = RESURGENCE

        function thistype.onUnequip(itm, id, index, orig_holder)
            local b = ResurgenceBuff:get(orig_holder, orig_holder)
            b:remove()
        end

        function thistype.onEquip(itm, id, index)
            local b = ResurgenceBuff:create(itm.holder, itm.holder)

            b.item = itm
            b = b:check(itm.holder, itm.holder)
        end
    end

    local POWERFULSTRIKE = Spell.define('Abon')
    do
        local thistype = POWERFULSTRIKE

        function thistype.onUnequip(itm, id, index, orig_holder)
            local runtime = itm.abilities[index]

            if runtime and runtime.callback then
                EVENT_ON_HIT:unregister_unit_action(orig_holder, runtime.callback)
            end
        end

        function thistype.onEquip(itm, id, index)
            local runtime = itm.abilities[index]

            runtime.damage = itm.cached_stats[index]
            runtime.callback = runtime.callback or function(source, target)
                DamageTarget(source, target, runtime.damage or 0, ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            EVENT_ON_HIT:register_unit_action(itm.holder, runtime.callback)
        end
    end

    local SIPHONBLOOD = Spell.define('Ahrt')
    do
        local thistype = SIPHONBLOOD

        local function update_tooltip(itm)
            if itm.nocraft then
                local s = ""
                --heart of the demon prince
                if itm.blood >= 2000 then
                    itm.nocraft = false
                    s = "|c0000ff40"
                end

                local abil_text = "|cff0099ffBlood Accumulated:|r (" .. s .. (IMinBJ(2000, itm.blood)) .. "/2000|r)"
                local s2 = "|cffff5050Chaotic Quest|r\n|c00ff0000Level Requirement: |r190\n\n" .. abil_text .. "\n\n|cff808080Deal or take damage to fill the heart with blood (Level 170+ enemies).\n|cffff0000WARNING! This item does not save!\n|cff808080Limit: 1|r"

                itm.tooltip = s2
                itm.alt_tooltip = s2

                BlzSetItemDescription(itm.obj, itm.tooltip)
                BlzSetItemExtendedTooltip(itm.obj, itm.tooltip)
                BlzSetItemExtendedTooltip(itm.abilities[ITEM_ABILITY].obj, abil_text)

                INVENTORY.refresh(itm.pid)
            end
        end

        local function onHit(source, target)
            if GetUnitLevel(target) >= 170 then
                local pid = GetPlayerId(GetOwningPlayer(source)) + 1
                local itm = GetItemFromPlayer(pid, 'I04Q')

                itm.blood = itm.blood + 1
                update_tooltip(itm)
            end
        end

        local function onStruck(target, source, amount)
            if amount.value > 0.00 and GetUnitLevel(source) >= 170 then
                local pid = GetPlayerId(GetOwningPlayer(target)) + 1
                local itm = GetItemFromPlayer(pid, 'I04Q')

                itm.blood = itm.blood + 1
                update_tooltip(itm)
            end
        end

        function thistype.onUnequip(itm, id, index, orig_holder)
            EVENT_ON_HIT:unregister_unit_action(orig_holder, onHit)
            EVENT_ON_STRUCK_MULTIPLIER:unregister_unit_action(orig_holder, onStruck)
            for _, v in ipairs(PLAYER_SUMMONS) do
                if itm.owner == GetOwningPlayer(v) then
                    EVENT_ON_HIT:unregister_unit_action(v, onHit)
                end
            end
        end

        function thistype.onEquip(itm, id, index)
            EVENT_ON_HIT:register_unit_action(itm.holder, onHit)
            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(itm.holder, onStruck)
            for _, v in ipairs(PLAYER_SUMMONS) do
                if itm.owner == GetOwningPlayer(v) then
                    EVENT_ON_HIT:register_unit_action(v, onHit)
                end
            end
            itm.blood = itm.blood or 0
            update_tooltip(itm)
        end
    end
end, Debug and Debug.getLine())

