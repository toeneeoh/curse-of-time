--[[
    unittable.lua

    A library that defines a Unit interface that indexes newly
    created units.
]]

OnInit.final("UnitTable", function(Require)
    Require('TimerQueue')
    Require('WorldBounds')
    Require('Events')
    Require('Spells')

    local MOVESPEED_CAP = 600

    ---@class Unit
    ---@field owner player
    ---@field pid integer
    ---@field unit unit
    ---@field create function
    ---@field destroy function
    ---@field attackCount integer
    ---@field damage integer
    ---@field bonus_damage integer
    ---@field damage_percent number
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
    ---@field casting boolean
    ---@field aggro_timer integer
    ---@field boss Boss
    ---@field nomanaregen boolean
    Unit = {}  ---@type Unit | Unit[]
    do
        local thistype = Unit

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

        local function finish_cast(self)
            self.casting = false
        end

        -- dot method set operators
        local set_operators = {
            str = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_BASE_STR, val)

                -- recalc HP
                local hp = tbl.base_hp + tbl.proxy.bonus_hp + 25 * (val + tbl.proxy.bonus_str)
                BlzSetUnitMaxHP(tbl.unit, hp)
                rawset(tbl.proxy, "hp", hp)

                -- recalc DAMAGE (uses bonus_damage + damage_percent)
                local damage = (BlzGetUnitBaseDamage(tbl.unit, 0) + tbl.proxy.bonus_damage) * tbl.proxy.damage_percent
                UnitSetBonus(tbl.unit, BONUS_DAMAGE, damage - BlzGetUnitBaseDamage(tbl.unit, 0))
                rawset(tbl.proxy, "damage", damage)
            end,
            bonus_str = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_STR, val)

                -- same HP & DAMAGE logic as above
                local hp = tbl.base_hp + tbl.proxy.bonus_hp + 25 * (tbl.proxy.str + val)
                BlzSetUnitMaxHP(tbl.unit, hp)
                rawset(tbl.proxy, "hp", hp)

                local damage = (BlzGetUnitBaseDamage(tbl.unit, 0) + tbl.proxy.bonus_damage) * tbl.proxy.damage_percent
                UnitSetBonus(tbl.unit, BONUS_DAMAGE, damage - BlzGetUnitBaseDamage(tbl.unit, 0))
                rawset(tbl.proxy, "damage", damage)
            end,
            agi = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_BASE_AGI, val)

                local damage = (BlzGetUnitBaseDamage(tbl.unit, 0) + tbl.proxy.bonus_damage) * tbl.proxy.damage_percent
                UnitSetBonus(tbl.unit, BONUS_DAMAGE, damage - BlzGetUnitBaseDamage(tbl.unit, 0))
                rawset(tbl.proxy, "damage", damage)
            end,
            bonus_agi = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_AGI, val)

                local damage = (BlzGetUnitBaseDamage(tbl.unit, 0) + tbl.proxy.bonus_damage) * tbl.proxy.damage_percent
                UnitSetBonus(tbl.unit, BONUS_DAMAGE, damage - BlzGetUnitBaseDamage(tbl.unit, 0))
                rawset(tbl.proxy, "damage", damage)
            end,
            int = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_BASE_INT, val)

                -- recalc MANA
                local mana = tbl.base_mana + tbl.proxy.bonus_mana + 20 * (val + tbl.proxy.bonus_int)
                BlzSetUnitMaxMana(tbl.unit, mana)
                rawset(tbl.proxy, "mana", mana)

                -- recalc MANA_REGEN
                local mregen = (tbl.proxy.nomanaregen and 0) or (tbl.proxy.mana_regen_flat + val * 0.05 + tbl.proxy.mana_regen_max * mana * 0.01) * tbl.proxy.mana_regen_percent
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, mregen)
                rawset(tbl.proxy, "mana_regen", mregen)
            end,
            bonus_int = function(tbl, val)
                UnitSetBonus(tbl.unit, BONUS_HERO_INT, val)

                -- same MANA & MANA_REGEN logic
                local mana = tbl.base_mana + tbl.proxy.bonus_mana + 20 * (tbl.proxy.int + val)
                BlzSetUnitMaxMana(tbl.unit, mana)
                rawset(tbl.proxy, "mana", mana)

                local mregen = (tbl.proxy.nomanaregen and 0) or (tbl.proxy.mana_regen_flat + tbl.proxy.int * 0.05 + tbl.proxy.mana_regen_max * mana * 0.01) * tbl.proxy.mana_regen_percent
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, mregen)
                rawset(tbl.proxy, "mana_regen", mregen)
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
            bonus_hp = function(tbl, val)
                local hp = tbl.base_hp + val + 25 * (tbl.proxy.str + tbl.proxy.bonus_str)
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
                tbl.cc = val * tbl.proxy.cc_percent
            end,
            cd_flat = function(tbl, val)
                tbl.cd = val * tbl.proxy.cd_percent
            end,
            cc_percent = function(tbl, val)
                tbl.cc = tbl.proxy.cc_flat * val
            end,
            cd_percent = function(tbl, val)
                tbl.cd = tbl.proxy.cd_flat * val
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
                local new_regen = (tbl.proxy.noregen and 0) or ( val + tbl.proxy.regen_max * tbl.proxy.hp * 0.01) * tbl.proxy.regen_percent
                UnitSetBonus(tbl.unit, BONUS_LIFE_REGEN, new_regen)
                rawset(tbl.proxy, "regen", new_regen)
            end,
            regen_percent = function(tbl, val)
                local new_regen = (tbl.proxy.noregen and 0) or ( tbl.proxy.regen_flat + tbl.proxy.regen_max * tbl.proxy.hp * 0.01) * val
                UnitSetBonus(tbl.unit, BONUS_LIFE_REGEN, new_regen)
                rawset(tbl.proxy, "regen", new_regen)
            end,
            regen_max = function(tbl, val)
                local new_regen = (tbl.proxy.noregen and 0) or ( tbl.proxy.regen_flat + val * tbl.proxy.hp * 0.01) * tbl.proxy.regen_percent
                UnitSetBonus(tbl.unit, BONUS_LIFE_REGEN, new_regen)
                rawset(tbl.proxy, "regen", new_regen)
            end,
            mana_regen_flat = function(tbl, val)
                local m = (tbl.proxy.nomanaregen and 0) or ( val + tbl.proxy.int * 0.05 + tbl.proxy.mana_regen_max * tbl.proxy.mana * 0.01) * tbl.proxy.mana_regen_percent
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, m)
                rawset(tbl.proxy, "mana_regen", m)
            end,
            mana_regen_percent = function(tbl, val)
                local m = (tbl.proxy.nomanaregen and 0) or ( tbl.proxy.mana_regen_flat + tbl.proxy.int * 0.05 + tbl.proxy.mana_regen_max * tbl.proxy.mana * 0.01) * val
                UnitSetBonus(tbl.unit, BONUS_MANA_REGEN, m)
                rawset(tbl.proxy, "mana_regen", m)
            end,
            mana_regen_max = function(tbl, val)
                local m = (tbl.proxy.nomanaregen and 0) or ( tbl.proxy.mana_regen_flat + tbl.proxy.int * 0.05 + val * tbl.proxy.mana * 0.01) * tbl.proxy.mana_regen_percent
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
            cast_time = function(tbl, val)
                tbl.casting = true

                TimerQueue:callDelayed(val, finish_cast, tbl)
            end,
            hidehp = function(tbl, val)
                if GetMainSelectedUnit() == tbl.unit then
                    BlzFrameSetVisible(HIDE_HEALTH_FRAME, val)
                end
            end,
        }

        local mt = {
                __index = function(tbl, key)
                    return (rawget(thistype, key) or rawget(tbl.proxy, key))
                end,
                __newindex = function(tbl, key, val)
                    if set_operators[key] then
                        if math.type(val) == "float" then
                            -- round to 3 decimals
                            val = math.floor(val * 1000 + 0.5) / 1000.
                        end
                        rawset(tbl.proxy, key, val)
                        set_operators[key](tbl, val)

                        -- trigger stat change event
                        EVENT_STAT_CHANGE:trigger(tbl.unit)
                    else
                        rawset(tbl, key, val)
                    end
                end,
            }

        ---@type fun(u: unit): Unit
        function thistype.create(u)
            local self = {}

            self.owner = GetOwningPlayer(u)
            self.pid = GetPlayerId(self.owner) + 1
            self.unit = u
            self.attackCount = 0
            self.casting = false
            self.can_attack = true
            self.base_hp = BlzGetUnitMaxHP(u)
            self.base_mana = BlzGetUnitMaxMana(u)
            self.proxy = { -- used for __newindex behavior
                damage = BlzGetUnitBaseDamage(u, 0),
                bonus_damage = UnitGetBonus(u, BONUS_DAMAGE),
                damage_percent = 1.,
                hp = self.base_hp,
                bonus_hp = 0,
                regen_flat = BlzGetUnitRealField(u, UNIT_RF_HIT_POINTS_REGENERATION_RATE),
                regen_percent = 1.,
                regen_max = 0, -- percent of max health (0-100)
                regen = BlzGetUnitRealField(u, UNIT_RF_HIT_POINTS_REGENERATION_RATE),
                noregen = false,
                hidehp = false,
                mana = self.base_mana,
                bonus_mana = 0,
                mana_regen_flat = BlzGetUnitRealField(u, UNIT_RF_MANA_REGENERATION),
                mana_regen_percent = 1.,
                mana_regen_max = 0.,
                mana_regen = BlzGetUnitRealField(u, UNIT_RF_MANA_REGENERATION),
                nomanaregen = false,
                evasion = 0,
                str = GetHeroStr(u, false),
                agi = GetHeroAgi(u, false),
                int = GetHeroInt(u, false),
                bonus_str = 0,
                bonus_agi = 0,
                bonus_int = 0,
                dr = 1., -- resists
                mr = 1.,
                pr = 1.,
                dm = 1., -- multipliers
                mm = 1.,
                pm = 1.,
                cc_flat = 0., -- crit
                cc_percent = 1.,
                cd_flat = 0.,
                cd_percent = 1.,
                cc = 0.,
                cd = 1.,
                ms_flat = GetUnitMoveSpeed(u),
                ms_percent = 1.,
                movespeed = GetUnitMoveSpeed(u),
                bat = BlzGetUnitAttackCooldown(u, 0),
                base_bat = BlzGetUnitAttackCooldown(u, 0),
                bonus_bat = 1.,
                x = GetUnitX(u),
                y = GetUnitY(u),
                spellboost = 0.,
                armor_pen_percent = 0.,
            }
            self.original_x = self.proxy.x
            self.original_y = self.proxy.y
            self.orderX = self.proxy.x
            self.orderY = self.proxy.y

            setmetatable(self, mt)

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
                TimerQueue:disableCallback(self.aggro_timer)
            end

            if UnitAlive(self.unit) then
                self.aggro_timer = TimerQueue:callDelayed(3., DropAggro, self)
            else
                self.aggro_timer = nil
            end
        end

        function thistype:destroy()
            if self.taunted then
                DestroyGroup(self.taunted)
            end

            if self.aggro_timer then
                TimerQueue:disableCallback(self.aggro_timer)
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
    function UnitIndex(u)
        if u and not IsDummy(u) and GetUnitAbilityLevel(u, DETECT_LEAVE_ABILITY) == 0 then
            -- first time setup for abilities
            local index = 0
            local abil = BlzGetUnitAbilityByIndex(u, index)

            while abil do
                local id = BlzGetAbilityId(abil)
                if Spells[id] then
                    Spells[id]:setTooltip(u, id)
                    if Spells[id].onSetup then
                        Spells[id].onSetup(u)
                    end
                end

                index = index + 1
                abil = BlzGetUnitAbilityByIndex(u, index)
            end

            UnitAddAbility(u, DETECT_LEAVE_ABILITY)
            UnitMakeAbilityPermanent(u, true, DETECT_LEAVE_ABILITY)

            EVENT_ON_ORDER:register_unit_action(u, on_cleanup)
        end
    end

    ---@return boolean
    local function onIndex()
        UnitIndex(GetFilterUnit())

        return false
    end

    local onEnter = CreateTrigger()

    TriggerRegisterEnterRegion(onEnter, WorldBounds.region, Filter(onIndex))
end, Debug and Debug.getLine())
