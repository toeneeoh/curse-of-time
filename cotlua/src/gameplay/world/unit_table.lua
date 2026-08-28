--[[
    unittable.lua

    A library that defines a Unit interface that indexes newly
    created units.
]]

OnInit.final("UnitTable", function(Require)
    Require('TimerQueue')
    Require('WorldBounds')
    Require('Events')

    local TQ = TimerQueue
    local MOVESPEED_CAP = 600
    local index_listeners = {}
    local indexed_units = setmetatable({}, { __mode = 'k' })
    local mtype, floor, rawset, rawget = math.type, math.floor, rawset, rawget
    local EVENT_STAT_CHANGE = EVENT_STAT_CHANGE
    local INT_REGEN_FACTOR = 0.05

    ---@class Unit
    ---@field owner player
    ---@field pid integer
    ---@field unit unit
    ---@field create function
    ---@field destroy function
    ---@field onIndex fun(callback: fun(u: unit))
    ---@field hit_based_health boolean
    ---@field damage integer
    ---@field bonus_damage integer
    ---@field damage_percent number
    ---@field armor number
    ---@field bonus_armor number
    ---@field armor_percent number
    ---@field evasion integer
    ---@field regen number
    ---@field regen_percent number
    ---@field regen_max number
    ---@field mana_regen number
    ---@field mana_regen_percent number
    ---@field mana_regen_max number
    ---@field noregen boolean
    ---@field dr number
    ---@field dm number
    ---@field pr number
    ---@field mr number
    ---@field pm number
    ---@field mm number
    ---@field cc number
    ---@field cd number
    ---@field borrowed_life number
    ---@field devour_stacks number
    ---@field regen_flat number
    ---@field movespeed number
    ---@field overmovespeed number
    ---@field ms_flat number
    ---@field ms_percent number
    ---@field armor_pen_percent number
    ---@field x number
    ---@field y number
    ---@field original_x number
    ---@field original_y number
    ---@field orderX number
    ---@field orderY number
    ---@field taunt function
    ---@field target Unit
    ---@field can_attack boolean
    ---@field hp number
    ---@field mana number
    ---@field mana_regen_flat number
    ---@field str number
    ---@field agi number
    ---@field int number
    ---@field bat number
    ---@field bonus_str number
    ---@field bonus_int number
    ---@field bonus_agi number
    ---@field bonus_bat number
    ---@field cd_flat number
    ---@field spellboost number
    ---@field ghost effect
    ---@field proxy table
    ---@field hidehp boolean
    ---@field busy boolean
    ---@field _casting boolean
    ---@field aggro_timer integer
    ---@field boss Boss
    ---@field nomanaregen boolean
    ---@field gold_rate number
    ---@field shield_count number
    ---@field xp_rate number
    Unit = {}  ---@type Unit | Unit[]
    do
        local thistype = Unit

        ---Registers a subsystem callback for newly indexed units.
        ---Units indexed before registration are replayed on the next timer tick,
        ---after final initializers have finished registering their definitions.
        ---@param callback fun(u: unit)
        function Unit.onIndex(callback)
            index_listeners[#index_listeners + 1] = callback

            for u in pairs(indexed_units) do
                TQ:callDelayed(0., callback, u)
            end
        end

        setmetatable(Unit, {
            -- create a new unit object
            __index = function(tbl, key)
                if type(key) == "userdata" and not IsDummy(key) then
                    local new = Unit.create(key)

                    rawset(tbl, key, new)
                    return new
                end
            end,
            -- make keys weak for when units are removed
            __mode = 'k'
        })

        local function recalc_armor(tbl)
            local u = tbl.unit
            local proxy = tbl.proxy

            -- engine armor: includes base, agi, bonus agi, items, etc. but NOT our BONUS_ARMOR
            local base_armor = BlzGetUnitArmor(u) - UnitGetBonus(u, BONUS_ARMOR)

            local bonus_armor = proxy.bonus_armor or 0.
            local armor_percent = proxy.armor_percent or 1.

            local new_armor = (base_armor + bonus_armor) * armor_percent

            UnitSetBonus(u, BONUS_ARMOR, new_armor - base_armor)
            rawset(proxy, "armor", new_armor)
        end

        local function recalc_damage(tbl)
            -- recalc DAMAGE (uses bonus_damage + damage_percent)
            local damage = (BlzGetUnitBaseDamage(tbl.unit, 0) + tbl.proxy.bonus_damage) * tbl.proxy.damage_percent
            UnitSetBonus(tbl.unit, BONUS_DAMAGE, damage - BlzGetUnitBaseDamage(tbl.unit, 0))
            rawset(tbl.proxy, "damage", damage)
        end

        -- dot method set operators
        local set_operators = {
            str = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_BASE_STR, val)

                -- recalc HP
                local hp = R2I(tbl.base_hp + tbl.proxy.bonus_hp + 25 * (val + tbl.proxy.bonus_str))
                BlzSetUnitMaxHP(tbl.unit, hp)
                rawset(tbl.proxy, "hp", hp)

                recalc_damage(tbl)
            end,
            bonus_str = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_STR, val)

                -- same HP & DAMAGE logic as above
                local hp = R2I(tbl.base_hp + tbl.proxy.bonus_hp + 25 * (tbl.proxy.str + val))
                BlzSetUnitMaxHP(tbl.unit, hp)
                rawset(tbl.proxy, "hp", hp)

                recalc_damage(tbl)
            end,
            agi = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_BASE_AGI, val)

                recalc_damage(tbl)
                recalc_armor(tbl)
            end,
            bonus_agi = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_AGI, val)

                recalc_damage(tbl)
                recalc_armor(tbl)
            end,
            int = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_BASE_INT, val)

                -- recalc MANA
                local mana = tbl.base_mana + tbl.proxy.bonus_mana + 20 * (val + tbl.proxy.bonus_int)
                BlzSetUnitMaxMana(tbl.unit, mana)
                rawset(tbl.proxy, "mana", mana)

                -- recalc MANA_REGEN
                local mregen = (tbl.proxy.nomanaregen and 0) or (tbl.proxy.mana_regen_flat + (val + tbl.proxy.bonus_int) * INT_REGEN_FACTOR + tbl.proxy.mana_regen_max * mana * 0.01) * tbl.proxy.mana_regen_percent
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, mregen)
                rawset(tbl.proxy, "mana_regen", mregen)

                recalc_damage(tbl)
            end,
            bonus_int = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_INT, val)

                -- same MANA & MANA_REGEN logic
                local mana = tbl.base_mana + tbl.proxy.bonus_mana + 20 * (tbl.proxy.int + val)
                BlzSetUnitMaxMana(tbl.unit, mana)
                rawset(tbl.proxy, "mana", mana)

                local mregen = (tbl.proxy.nomanaregen and 0) or (tbl.proxy.mana_regen_flat + (tbl.proxy.int + val) * INT_REGEN_FACTOR + tbl.proxy.mana_regen_max * mana * 0.01) * tbl.proxy.mana_regen_percent
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, mregen)
                rawset(tbl.proxy, "mana_regen", mregen)

                recalc_damage(tbl)
            end,
            bonus_mana = function(tbl, val)
                local mana = tbl.base_mana + val + 20 * (tbl.proxy.int + tbl.proxy.bonus_int)
                BlzSetUnitMaxMana(tbl.unit, mana)
                rawset(tbl.proxy, "mana", mana)
            end,
            base_bat = function(tbl, val)
                local bat = val * tbl.proxy.bonus_bat
                BlzSetUnitAttackCooldown(tbl.unit, bat, 0)
                rawset(tbl.proxy, "bat", bat)
            end,
            bonus_bat = function(tbl, val)
                local bat = tbl.proxy.base_bat * val
                BlzSetUnitAttackCooldown(tbl.unit, bat, 0)
                rawset(tbl.proxy, "bat", bat)
            end,
            bonus_damage = function(tbl, val)
                local new_dmg = (BlzGetUnitBaseDamage(tbl.unit, 0) + val) * tbl.proxy.damage_percent
                UnitSetBonus(tbl.unit, BONUS_DAMAGE, new_dmg - BlzGetUnitBaseDamage(tbl.unit, 0))
                rawset(tbl.proxy, "damage", new_dmg)
            end,
            damage_percent = function(tbl, val)
                local new_dmg = (BlzGetUnitBaseDamage(tbl.unit, 0) + tbl.proxy.bonus_damage) * val
                UnitSetBonus(tbl.unit, BONUS_DAMAGE, new_dmg - BlzGetUnitBaseDamage(tbl.unit, 0))
                rawset(tbl.proxy, "damage", new_dmg)
            end,
            bonus_armor = function(tbl, val)
                recalc_armor(tbl)
            end,
            armor_percent = function(tbl, val)
                recalc_armor(tbl)
            end,
            bonus_hp = function(tbl, val)
                local hp = R2I(tbl.base_hp + val + 25 * (tbl.proxy.str + tbl.proxy.bonus_str))
                BlzSetUnitMaxHP(tbl.unit, hp)
                rawset(tbl.proxy, "hp", hp)
            end,
            x = function(tbl, val)
                SetUnitXBounded(tbl.unit, val)
            end,
            y = function(tbl, val)
                SetUnitYBounded(tbl.unit, val)
            end,
            cc_flat = function(tbl, val)
                rawset(tbl.proxy, "cc", val * tbl.proxy.cc_percent)
            end,
            cd_flat = function(tbl, val)
                rawset(tbl.proxy, "cd", val * tbl.proxy.cd_percent)
            end,
            cc_percent = function(tbl, val)
                rawset(tbl.proxy, "cc", tbl.proxy.cc_flat * val)
            end,
            cd_percent = function(tbl, val)
                rawset(tbl.proxy, "cd", tbl.proxy.cd_flat * val)
            end,
            ms_flat = function(tbl, val)
                tbl.proxy.movespeed = tbl.proxy.overmovespeed or math.min(MOVESPEED_CAP, math.ceil(val * tbl.proxy.ms_percent))
                UnitSetBonus(tbl.unit, BONUS_MOVE_SPEED, tbl.proxy.movespeed)
            end,
            ms_percent = function(tbl, val)
                tbl.proxy.movespeed = tbl.proxy.overmovespeed or math.min(MOVESPEED_CAP, math.ceil(tbl.proxy.ms_flat * val))
                UnitSetBonus(tbl.unit, BONUS_MOVE_SPEED, tbl.proxy.movespeed)
            end,
            overmovespeed = function(tbl, val)
                tbl.proxy.movespeed = val or math.min(MOVESPEED_CAP, math.ceil(tbl.proxy.ms_flat * tbl.proxy.ms_percent))
                UnitSetBonus(tbl.unit, BONUS_MOVE_SPEED, tbl.proxy.movespeed)
            end,
            regen_flat = function(tbl, val)
                local new_regen = (tbl.proxy.noregen and 0) or (val + tbl.proxy.regen_max * tbl.proxy.hp * 0.01) * tbl.proxy.regen_percent
                UnitSetBonus(tbl.unit, BONUS_LIFE_REGEN, new_regen)
                rawset(tbl.proxy, "regen", new_regen)
            end,
            regen_percent = function(tbl, val)
                local new_regen = (tbl.proxy.noregen and 0) or (tbl.proxy.regen_flat + tbl.proxy.regen_max * tbl.proxy.hp * 0.01) * val
                UnitSetBonus(tbl.unit, BONUS_LIFE_REGEN, new_regen)
                rawset(tbl.proxy, "regen", new_regen)
            end,
            regen_max = function(tbl, val)
                local new_regen = (tbl.proxy.noregen and 0) or (tbl.proxy.regen_flat + val * tbl.proxy.hp * 0.01) * tbl.proxy.regen_percent
                UnitSetBonus(tbl.unit, BONUS_LIFE_REGEN, new_regen)
                rawset(tbl.proxy, "regen", new_regen)
            end,
            mana_regen_flat = function(tbl, val)
                local m = (tbl.proxy.nomanaregen and 0) or (val + (tbl.proxy.int + tbl.proxy.bonus_int) * INT_REGEN_FACTOR + (tbl.proxy.mana_regen_max * tbl.proxy.mana * 0.01)) * tbl.proxy.mana_regen_percent
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, m)
                rawset(tbl.proxy, "mana_regen", m)
            end,
            mana_regen_percent = function(tbl, val)
                local m = (tbl.proxy.nomanaregen and 0) or (tbl.proxy.mana_regen_flat + (tbl.proxy.int + tbl.proxy.bonus_int) * INT_REGEN_FACTOR + (tbl.proxy.mana_regen_max * tbl.proxy.mana * 0.01)) * val
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, m)
                rawset(tbl.proxy, "mana_regen", m)
            end,
            mana_regen_max = function(tbl, val)
                local m = (tbl.proxy.nomanaregen and 0) or (tbl.proxy.mana_regen_flat + (tbl.proxy.int + tbl.proxy.bonus_int) * INT_REGEN_FACTOR + (val * tbl.proxy.mana * 0.01)) * tbl.proxy.mana_regen_percent
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, m)
                rawset(tbl.proxy, "mana_regen", m)
            end,
            nomanaregen = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, val and 0 or tbl.mana_regen)
            end,
            attack = function(tbl, val)
                rawset(tbl, "can_attack", val)

                if not IS_AUTO_ATTACK_OFF[tbl.pid] then
                    BlzSetUnitWeaponBooleanField(tbl.unit, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, val)
                end
            end,
            hidehp = function(tbl, val)
                if GetMainSelectedUnit() == tbl.unit then
                    BlzFrameSetVisible(HIDE_HEALTH_FRAME, val)
                end
            end,
            range = function(tbl, val)
                local current_range = BlzGetUnitWeaponRealField(tbl.unit, UNIT_WEAPON_RF_ATTACK_RANGE, 0) -- index is correct, returned range is correct.
                local current_range_second = BlzGetUnitWeaponRealField(tbl.unit, UNIT_WEAPON_RF_ATTACK_RANGE, 1) -- yes, we should get the 2nd attack range and count it too
                BlzSetUnitWeaponRealField(tbl.unit, UNIT_WEAPON_RF_ATTACK_RANGE, 1, val - current_range + current_range_second)
                rawset(tbl.proxy, "range", val)
                BlzSetUnitRealField(tbl.unit, UNIT_RF_ACQUISITION_RANGE, val + 50)
            end,
        }

        local mt = {
                __index = function(tbl, key)
                    return (rawget(thistype, key) or tbl.proxy[key])
                end,
                __newindex = function(tbl, key, val)
                    local prev = tbl.proxy[key]
                    if set_operators[key] then
                        if mtype(val) == "float" then
                            -- round to 3 decimals
                            val = floor(val * 1000 + 0.5) / 1000.
                        end
                        rawset(tbl.proxy, key, val)
                        set_operators[key](tbl, val)
                    else
                        rawset(tbl.proxy, key, val)
                    end

                    -- trigger stat change event
                    if prev ~= val and not tbl.suppress_stat_events then
                        EVENT_STAT_CHANGE:trigger(tbl.unit, key)
                    end
                end,
            }

        -- default unit data
        local base_proxy = {
            damage_percent = 1.,
            bonus_hp = 0,
            regen_percent = 1.,
            regen_max = 0, -- percent of max health (0-100)
            noregen = false,
            hidehp = false,
            bonus_mana = 0,
            mana_regen_percent = 1.,
            nomanaregen = false,
            evasion = 0,
            bonus_str = 0,
            bonus_agi = 0,
            bonus_int = 0,
            dr = 1., -- resists
            dm = 1., -- multipliers
            mm = 1.,
            cc = 0.,
            cd = 100.,
            cc_percent = 1.,
            cd_percent = 1.,
            ms_percent = 1.,
            bonus_bat = 1.,
            spellboost = 0.,
            armor_pen_percent = 0.,
            bonus_armor = 0.,
            armor_percent = 1.,
            gold_rate = 0.,
            shield_count = 0,
            xp_rate = 0,
        }
        base_proxy.__index = base_proxy

        ---@type fun(u: unit): Unit
        function thistype.create(u)
            local self = {}

            self.owner = GetOwningPlayer(u)
            self.pid = GetPlayerId(self.owner) + 1
            self.id = GetUnitTypeId(u)
            self.unit = u
            self.hit_based_health = false
            self.hit_damage = 1
            self._casting = false
            self.can_attack = true
            self.base_hp = BlzGetUnitMaxHP(u)
            self.base_mana = BlzGetUnitMaxMana(u)

            -- stats that trigger EVENT_STAT_CHANGE
            self.proxy = setmetatable({ -- used for __newindex behavior
                damage = BlzGetUnitBaseDamage(u, 0),
                bonus_damage = UnitGetBonus(u, BONUS_DAMAGE),
                hp = self.base_hp,
                regen_flat = BlzGetUnitRealField(u, UNIT_RF_HIT_POINTS_REGENERATION_RATE),
                regen = BlzGetUnitRealField(u, UNIT_RF_HIT_POINTS_REGENERATION_RATE),
                mana = self.base_mana,
                mana_regen_flat = BlzGetUnitRealField(u, UNIT_RF_MANA_REGENERATION),
                mana_regen_max = 0.,
                mana_regen = BlzGetUnitRealField(u, UNIT_RF_MANA_REGENERATION),
                str = GetHeroStr(u, false),
                agi = GetHeroAgi(u, false),
                int = GetHeroInt(u, false),
                mr = 1.,
                pr = 1.,
                pm = 1.,
                armor = BlzGetUnitArmor(u),
                bonus_armor = 0.,
                armor_percent = 1.,
                cc_flat = 0.,
                cd_flat = 0.,
                ms_flat = GetUnitMoveSpeed(u),
                movespeed = GetUnitMoveSpeed(u),
                bat = BlzGetUnitAttackCooldown(u, 0),
                base_bat = BlzGetUnitAttackCooldown(u, 0),
                x = GetUnitX(u),
                y = GetUnitY(u),
            }, base_proxy)

            self.original_x = self.proxy.x
            self.original_y = self.proxy.y
            self.orderX = self.proxy.x
            self.orderY = self.proxy.y

            setmetatable(self, mt)

            -- trigger set operators
            local default = HERO_STATS[self.id]
            self.cc_flat = default.crit_chance
            self.cd_flat = default.crit_damage
            self.mr = default.magic_resist
            self.pr = default.phys_resist
            self.pm = default.phys_damage
            self.mana_regen_max = default.mana_regen_max

            return self
        end

        function Unit:taunt(enemy)
            local boss = IsBoss(enemy.unit)
            enemy.target = self
            self.taunted = self.taunted or CreateGroup()

            if not boss then
                GroupAddUnit(self.taunted, enemy.unit)
                IssueTargetOrder(enemy.unit, "smart", self.unit)
            else -- use boss deaggro behavior
                boss:switch_target(self)
            end

            if self.aggro_timer then
                -- the act of taunting retains aggro
                TQ:disableCallback(self.aggro_timer)
            end

            if UnitAlive(self.unit) then
                self.aggro_timer = TQ:callDelayed(3., DropAggro, self)
            else
                self.aggro_timer = nil
            end
        end

        local effect_operators = {
            timescale = function(tbl, val)
                BlzSetSpecialEffectTimeScale(tbl.effect, val)
            end,

            anim = function(tbl, val)
                BlzPlaySpecialEffect(tbl.effect, val)
            end,

            color = function(tbl, val)
                BlzSetSpecialEffectColor(tbl.effect, val[1], val[2], val[3])
            end,

            scale = function(tbl, val)
                BlzSetSpecialEffectScale(tbl.effect, val)
            end,
        }

        local effect_trace_id = 0

        ---@param action string
        ---@param unit_data Unit
        ---@param entry table?
        local function trace_effect(action, unit_data, entry)
            if not DevLog or not DevLog.enabled then
                return
            end

            local effect_id = entry and entry.effect and GetHandleId(entry.effect) or 0
            DevLog.write("EFFECT", string.format(
                "%s unit=%d type=%s trace=%d handle=%d model=%s attach=%s morphed=%s",
                action,
                GetHandleId(unit_data.unit),
                GetObjectName(unit_data.id),
                entry and entry.trace_id or 0,
                effect_id,
                entry and entry.model or "-",
                entry and (unit_data.morphed and entry.attach_alternate or entry.attach) or "-",
                tostring(unit_data.morphed == true)
            ), true)
        end

        local mt2 = {
            __index = function(tbl, key)
                local val = rawget(tbl, key)
                if val ~= nil then
                    return val
                end
                return tbl.proxy[key]
            end,
            __newindex = function(tbl, key, val)
                local op = effect_operators[key]
                if op then
                    rawset(tbl.proxy, key, val)

                    if tbl.effect then
                        op(tbl, val)
                    end
                else
                    rawset(tbl, key, val)
                end
            end
        }

        function Unit:addEffect(model, attachPoint, attachPointAlternate)
            self.effects = self.effects or {}

            effect_trace_id = effect_trace_id + 1

            local data = {
                model = model,
                attach = attachPoint,
                effect = AddSpecialEffectTarget(model, self.unit, self.morphed and attachPointAlternate or attachPoint),
                attach_alternate = attachPointAlternate,
                morphed = false,
                trace_id = effect_trace_id,
                proxy = {}
            }

            setmetatable(data, mt2)

            self.effects[#self.effects + 1] = data
            trace_effect("add", self, data)

            return data
        end

        ---Writes the current tracked-effect handles to the development log.
        ---@param reason string
        function Unit:traceEffects(reason)
            if not DevLog or not DevLog.enabled or not self.effects or #self.effects == 0 then
                return
            end

            for _, sfx in ipairs(self.effects) do
                trace_effect(reason, self, sfx)
            end
        end

        function Unit:destroyEffects()
            if not self.effects then
                return
            end

            for _, sfx in ipairs(self.effects) do
                if sfx.effect then
                    trace_effect("destroy", self, sfx)
                    DestroyEffect(sfx.effect)
                    sfx.effect = nil
                end
            end
        end

        function Unit:applyEffects()
            if not self.effects then
                return
            end

            for _, sfx in ipairs(self.effects) do
                if not sfx.effect then
                    local effect = self.morphed and sfx.attach_alternate or sfx.attach
                    sfx.effect = AddSpecialEffectTarget(sfx.model, self.unit, effect)
                    trace_effect("recreate", self, sfx)

                    -- reapply attributes
                    for key, val in pairs(sfx.proxy) do
                        local op = effect_operators[key]
                        if op then
                            op(sfx, val)
                        end
                    end
                end
            end
        end

        function Unit:removeEffect(entry)
            local effects = self.effects

            if not effects then
                return
            end

            if entry.effect then
                trace_effect("remove", self, entry)
                DestroyEffect(entry.effect)
                entry.effect = nil
            end

            for i = 1, #effects do
                if effects[i] == entry then
                    effects[i] = effects[#effects]
                    effects[#effects] = nil
                    break
                end
            end
        end

        function Unit:morph(skin)
            self:traceEffects("morph-before")
            self:destroyEffects()

            BlzSetUnitSkin(self.unit, skin)
            self.morphed = not self.morphed

            trace_effect("morph-skin", self)

            TQ:callDelayed(0., Unit.applyEffects, self)
        end

        function thistype:destroy()
            if self.taunted then
                DestroyGroup(self.taunted)
            end

            if self.aggro_timer then
                TQ:disableCallback(self.aggro_timer)
            end

            if self.effects then
                for i = 1, #self.effects do
                    trace_effect("unit-destroy", self, self.effects[i])
                    DestroyEffect(self.effects[i].effect)
                end
            end
        end
    end

    local function on_cleanup(source, _, id)
        -- if unit is removed
        if id == ORDER_ID_UNDEFEND then
            Unit[source]:destroy()
        end
    end

    ---@type fun(u: unit)
    local function index_unit(u)
        if u and not IsDummy(u) and GetUnitAbilityLevel(u, DETECT_LEAVE_ABILITY) == 0 then
            indexed_units[u] = true

            for index = 1, #index_listeners do
                index_listeners[index](u)
            end

            UnitAddAbility(u, DETECT_LEAVE_ABILITY)
            UnitMakeAbilityPermanent(u, true, DETECT_LEAVE_ABILITY)

            EVENT_ON_ORDER:register_unit_action(u, on_cleanup)
        end
    end

    ---@return boolean
    local function onIndex()
        index_unit(GetFilterUnit())

        return false
    end

    local onEnter = CreateTrigger()

    TriggerRegisterEnterRegion(onEnter, WorldBounds.region, Filter(onIndex))
end, Debug and Debug.getLine())
