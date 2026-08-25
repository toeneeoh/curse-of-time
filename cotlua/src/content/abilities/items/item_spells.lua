--[[
    itemspells.lua

    Defines any item spells (no dynamic tooltips)
]]

OnInit.final("ItemSpells", function(Require)
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

    local THANATOS_WINGS = Spell.define('A01F')
    do
        local thistype = THANATOS_WINGS

        function thistype:onCast()
            local wings = GetItemFromPlayer(self.pid, 'I04E:-1')

            if wings then
                local max = wings.cached_stats[ITEM_ABILITY]

                if wings.sfx_index then
                    wings.sfx_index = ((wings.sfx_index + 1) > max and 1) or wings.sfx_index + 1
                else
                    wings.sfx_index = 1
                end

                local tbl = ItemData[wings.id].sfx[wings.sfx_index]

                Unit[self.caster]:removeEffect(wings.sfx)
                wings.sfx = Unit[self.caster]:addEffect(tbl.path, tbl.attach)
            end
        end

        function thistype.onUnequip(itm, id, index, orig_holder)
            Unit[orig_holder]:removeEffect(itm.sfx)
            itm.sfx = nil
        end

        function thistype.onEquip(itm, id, index)
            local sfx = ItemData[itm.id].sfx[itm.sfx_index or itm.cached_stats[index]]

            if not itm.sfx then
                itm.sfx = Unit[itm.holder]:addEffect(sfx.path, sfx.attach)
            end
        end
    end

    local SHORT_BLINK = Spell.define('A03D', 'A061', 'AIbk')
    do
        local thistype = SHORT_BLINK

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if r ~= r2 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "You can't blink there.")
            end
        end
    end

    local GOD_BLINK = Spell.define('A018')
    do
        local thistype = GOD_BLINK

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if CHAOS_MODE then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 20.00, "With the Gods dead, these items no longer have the ability to move around the map with free will. Their powers are dead, however their innate fighting powers are left unscathed.")
            elseif r ~= r2 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 5., "You can't blink there.")
            end
        end

        function thistype.onEquip(itm, id, index)
            BlzSetAbilityRealLevelField(BlzGetUnitAbility(itm.holder, id), ABILITY_RLF_MAXIMUM_RANGE, 0, itm.cached_stats[index])
        end
    end

    local THANATOS_BOOTS = Spell.define('A01S')
    do
        local thistype = THANATOS_BOOTS

        function thistype.preCast(pid, tpid, caster, target, x, y, targetX, targetY)
            local r = GetRectFromCoords(x, y)
            local r2 = GetRectFromCoords(targetX, targetY)

            if r ~= r2 then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "You can't blink there.")
            end
        end

        function thistype.onUnequip(itm, id, index, orig_holder)
            Unit[orig_holder]:removeEffect(itm.sfx)
            Unit[orig_holder]:removeEffect(itm.sfx2)
            itm.sfx = nil
        end

        function thistype.onEquip(itm, id, index)
            local tbl = ItemData[itm.id].sfx

            if not itm.sfx then
                itm.sfx = Unit[itm.holder]:addEffect(tbl[1].path, tbl[1].attach)
                itm.sfx2 = Unit[itm.holder]:addEffect(tbl[2].path, tbl[2].attach)
            end

            BlzSetAbilityRealLevelField(BlzGetUnitAbility(itm.holder, id), ABILITY_RLF_MAXIMUM_RANGE, 0, itm.cached_stats[index])
        end
    end

    local PALADIN_BOOK = Spell.define('A083')
    do
        local thistype = PALADIN_BOOK

        function thistype:onCast()
            local heal = 3 * GetHeroInt(self.caster, true) * BOOST[self.pid]
            if GetUnitTypeId(self.target) == BACKPACK then
                HP(self.caster, Hero[self.tpid], heal, thistype.tag)
            else
                HP(self.caster, self.target, heal, thistype.tag)
            end
        end
    end

    local INSTILL_FEAR = Spell.define('A02A')
    do
        local thistype = INSTILL_FEAR

        local missile_template = {
            selfInteractions = {
                CAT_MoveHoming3D,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            visualZ = 70.,
            identifier = "missile",
            collisionRadius = 1.,
            onlyTarget = true,
            speed = 1400.,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                InstillFearDebuff:add(self.source, enemy):duration(7.)
            end,
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.z = GetUnitZ(self.caster)
            missile.visual = AddSpecialEffect("Abilities\\Spells\\NightElf\\shadowstrike\\ShadowStrikeMissile.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 1.1)
            missile.source = self.caster
            missile.target = self.target
            missile.owner = Player(self.pid - 1)

            ALICE_Create(missile)
        end
    end

    local DARKEST_OF_DARKNESS = Spell.define('A055')
    do
        local thistype = DARKEST_OF_DARKNESS

        function thistype:onCast()
            DarkestOfDarknessBuff:add(self.caster, self.caster):duration(20.)
        end
    end

    local ASTRAL_FREEZE_ITEM = Spell.define('A0SX')
    do
        local thistype = ASTRAL_FREEZE_ITEM

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()
            pt.source = self.caster
            pt.dmg = 40. * GetHeroInt(self.caster, true) * BOOST[self.pid]
            pt.angle = bj_RADTODEG * self.angle

            pt:after(0., ASTRAL_FREEZE.effect)
        end
    end

    local FINAL_BLAST = Spell.define('A00E')
    do
        local thistype = FINAL_BLAST

        function thistype:onCast()
            local ug = CreateGroup()
            MakeGroupInRange(self.pid, ug, self.x, self.y, 600.00, Condition(FilterEnemy))
            local x, y

            for i = 1, 12 do
                if i < 7 then
                    x = self.x + 200 * math.cos(60.00 * i * bj_DEGTORAD)
                    y = self.y + 200 * math.sin(60.00 * i * bj_DEGTORAD)
                    DestroyEffect(AddSpecialEffect("war3mapImported\\NeutralExplosion.mdx", x, y))
                end
                x = self.x + 400 * math.cos(60.00 * i * bj_DEGTORAD)
                y = self.y + 400 * math.sin(60.00 * i * bj_DEGTORAD)
                DestroyEffect(AddSpecialEffect("war3mapImported\\NeutralExplosion.mdx", x, y))
                x = self.x + 600 * math.cos(60.00 * i * bj_DEGTORAD)
                y = self.y + 600 * math.sin(60.00 * i * bj_DEGTORAD)
                DestroyEffect(AddSpecialEffect("war3mapImported\\NeutralExplosion.mdx", x, y))
            end

            for target in each(ug) do
                DamageTarget(self.caster, target, 10.00 * (GetHeroInt(self.caster, true) + GetHeroAgi(self.caster, true) + GetHeroStr(self.caster, true)) * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end
    end

    local BANISH_DEMON = Spell.define('A00Q')
    do
        local thistype = BANISH_DEMON

        local quotes = {
            [BOSS_LEGION] = "|cffffcc00Legion:|r Fool! Did you really think splashing water on me would do anything?",
            [BOSS_DEATH_KNIGHT] = "|cffffcc00Death Knight:|r ...???",
        }

        function thistype:onCast()
            local itm = GetItemFromPlayer(self.pid, FourCC('I0OU'))
            local boss = IsBoss(self.target)

            if boss and quotes[boss.index] then
                itm:destroy()
                if not boss.disable_respawn then
                    boss.disable_respawn = true
                    DisplayTimedTextToForce(FORCE_PLAYING, 30., quotes[boss.index])
                end
            else
                DisplayTimedTextToPlayer(Player(self.pid - 1), 0., 0., 30., "Maybe you shouldn't waste this...")
            end
        end
    end

    local INTENSE_FOCUS = Spell.define('A0B9')
    do
        local thistype = INTENSE_FOCUS

        function thistype.onUnequip(itm, id, index, orig_holder)
            IntenseFocusBuff:dispel(orig_holder, orig_holder)
        end

        function thistype.onEquip(itm, id, index)
            IntenseFocusBuff:add(itm.holder, itm.holder)
        end
    end

    local EMPYREAN_SONG = Spell.define('A04I')
    do
        local thistype = EMPYREAN_SONG

        local function periodic(itm, holder)
            if itm and itm.holder then
                local ug = CreateGroup()
                MakeGroupInRange(itm.pid, ug, GetUnitX(holder), GetUnitY(holder), 900. * LBOOST[itm.pid], Condition(FilterAlly))

                for ally in each(ug) do
                    EmpyreanSongBuff:add(holder, ally):duration(2.)
                end

                DestroyGroup(ug)
                TQ:callDelayed(1., periodic, itm, holder)
            end
        end

        function thistype.onEquip(itm, id, index)
            periodic(itm, itm.holder)
        end
    end

    local UNHOLY_AURA = Spell.define('A03G')
    do
        local thistype = UNHOLY_AURA

        local function periodic(itm, holder)
            if itm and itm.holder then
                local ug = CreateGroup()
                MakeGroupInRange(itm.pid, ug, GetUnitX(holder), GetUnitY(holder), 900. * LBOOST[itm.pid], Condition(FilterAlly))

                for ally in each(ug) do
                    BloodHornBuff:add(holder, ally):duration(2.)
                end

                DestroyGroup(ug)
                TQ:callDelayed(1., periodic, itm, holder)
            end
        end

        function thistype.onEquip(itm, id, index)
            periodic(itm, itm.holder)
        end
    end

    local REINCARNATION_NORECHARGE = Spell.define('Anrv')
    do
        local thistype = REINCARNATION_NORECHARGE
        thistype.ACTIVE = false

        function thistype:onCast(itm)
            local heal = itm.cached_stats[ITEM_ABILITY] * 0.01

            itm:consumeCharge()

            local dummy = itm.abilities[ITEM_ABILITY].obj

            RevivePlayer(itm.pid, GetUnitX(HeroGrave[itm.pid]), GetUnitY(HeroGrave[itm.pid]), heal, heal)
            SetItemCharges(dummy, itm.charges)
            INVENTORY.refresh(itm.pid)
        end

        function thistype.onEquip(itm, id, index)
            SetItemCharges(itm.abilities[index].obj, itm.charges)
        end
    end

    local REINCARNATION_RECHARGE = Spell.define('Arrv')
    do
        local thistype = REINCARNATION_RECHARGE
        thistype.ACTIVE = false

        function thistype:onCast(itm)
            local heal = itm.cached_stats[ITEM_ABILITY] * 0.01

            itm.charges = itm.charges - 1
            local dummy = itm.abilities[ITEM_ABILITY].obj

            RevivePlayer(itm.pid, GetUnitX(HeroGrave[itm.pid]), GetUnitY(HeroGrave[itm.pid]), heal, heal)
            SetItemCharges(dummy, itm.charges)
            INVENTORY.refresh(itm.pid)
        end

        function thistype.onEquip(itm, id, index)
            SetItemCharges(itm.abilities[index].obj, itm.charges)
        end
    end

    local SOCKET_ITEM_CHISEL = Spell.define('A00D')
    do
        local thistype = SOCKET_ITEM_CHISEL
        local TYPE_SOCKETABLE = 12
        local TARGET_DIALOG_KIND = "socket_item_target"
        local GEM_DIALOG_KIND = "socket_item_gem"

        ---@param itm Item?
        ---@return boolean
        local function is_socketable(itm)
            return itm ~= nil and itm.type == TYPE_SOCKETABLE and not itm.socketed
        end

        ---@param itm Item?
        ---@param socket_limit integer
        ---@return boolean
        local function is_socket_target(itm, socket_limit)
            return itm ~= nil
                and itm.type ~= TYPE_SOCKETABLE
                and ItemIsUpgradeable(itm)
                and #itm.sockets < socket_limit
        end

        ---@param pid integer
        ---@param socket_limit integer
        ---@return boolean, boolean
        local function get_socket_options(pid, socket_limit)
            local has_target = false
            local has_socketable = false
            local items = Profile[pid].hero.items

            for i = 1, MAX_INVENTORY_SLOTS do
                local itm = items[i]
                has_target = has_target or is_socket_target(itm, socket_limit)
                has_socketable = has_socketable or is_socketable(itm)

                if has_target and has_socketable then
                    break
                end
            end

            return has_target, has_socketable
        end

        local function confirm_socket_item(self, index, socketable)
            if index ~= -1 then
                local to_socket = self.data[200]
                local chisel = self.data[100]
                local socket_limit = self.data[300]

                if chisel
                    and is_socketable(socketable)
                    and is_socket_target(to_socket, socket_limit)
                then
                    if to_socket:socket(socketable) then
                        chisel:destroy()
                    else
                        DisplayTextToPlayer(Player(self.pid - 1), 0., 0., "The socketable item could not be transferred.")
                    end
                else
                    DisplayTextToPlayer(Player(self.pid - 1), 0., 0., "The selected items are no longer valid for socketing.")
                end

                self:destroy()
            end

            return false
        end

        local function choose_socketable(self, index, to_socket)
            if index ~= -1 then
                local pid = self.pid
                local chisel = self.data[100]
                local socket_limit = self.data[300]
                local items = Profile[pid].hero.items

                self:destroy()

                if not is_socket_target(to_socket, socket_limit) then
                    DisplayTextToPlayer(Player(pid - 1), 0., 0., "That item can no longer be socketed.")
                    return false
                end

                local dw = DialogWindow.create(pid, "Choose a socketable item to use", confirm_socket_item, GEM_DIALOG_KIND)

                for i = 1, MAX_INVENTORY_SLOTS do
                    local itm = items[i]

                    if is_socketable(itm) then
                        dw:addButton(GetItemName(itm.obj), itm, BlzGetItemIconPath(itm.obj))
                    end
                end

                if dw.count > 0 then
                    dw.data[100] = chisel
                    dw.data[200] = to_socket
                    dw.data[300] = socket_limit
                    if not dw:display() then
                        dw:destroy()
                    end
                else
                    DisplayTextToPlayer(Player(pid - 1), 0., 0., "You have no socketable items to use.")
                    dw:destroy()
                end
            end

            return false
        end

        ---Shared entry point for chisel variants.
        ---A limit of 1 only accepts unsocketed targets; 3 accepts 0-2 sockets.
        ---@param spell table
        ---@param chisel_id string
        ---@param socket_limit integer
        local function cast_socket_chisel(spell, chisel_id, socket_limit)
            local pid = spell.pid
            local chisel = GetItemFromPlayer(pid, chisel_id)

            if not chisel then
                return
            end

            socket_limit = math.min(socket_limit, MAX_SOCKETS)

            local has_target, has_socketable = get_socket_options(pid, socket_limit)

            if not has_target then
                DisplayTextToPlayer(spell.owner, 0., 0., "You have no items that can receive sockets.")
                return
            elseif not has_socketable then
                DisplayTextToPlayer(spell.owner, 0., 0., "You have no socketable items to use.")
                return
            end

            local dw = DialogWindow.create(pid, "Choose an item to socket", choose_socketable, TARGET_DIALOG_KIND)
            local items = Profile[pid].hero.items

            for i = 1, MAX_INVENTORY_SLOTS do
                local itm = items[i]

                if is_socket_target(itm, socket_limit) then
                    dw:addButton(GetItemName(itm.obj), itm, BlzGetItemIconPath(itm.obj))
                end
            end

            dw.data[100] = chisel
            dw.data[300] = socket_limit
            if not dw:display() then
                dw:destroy()
            end
        end

        function thistype:onCast()
            cast_socket_chisel(self, 'I00K:-1', 1)
        end

        local ADVANCED_SOCKET_ITEM_CHISEL = Spell.define('A01G')
        function ADVANCED_SOCKET_ITEM_CHISEL:onCast()
            cast_socket_chisel(self, 'I00U:-1', 3)
        end
    end

    local DETECTION = Spell.define('Adt1')
    local ENDURANCE_AURA = Spell.define('A03F')
    local VAMPIRIC_AURA = Spell.define('A03H')
    local WAR_DRUM_AURA = Spell.define('AIcd')
    local CRYSTAL_BALL = Spell.define('AIta')
    local SEA_WARDS = Spell.define('A0E2')
    local JEWEL_OF_THE_HORDE = Spell.define('A0D3')

end, Debug and Debug.getLine())
