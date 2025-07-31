--[[
    damage.lua

    A library that handles the damage event (EVENT_PLAYER_UNIT_DAMAGING) and calculates on hit effects,
    multipliers, reductions, mitigations, etc.
]]

OnInit.final("Damage", function(Require)
    Require('Variables')
    Require('UnitTable')
    Require('Events')

    ATTACK_CHAOS     = 5 ---@type integer 
    ARMOR_CHAOS      = 6 ---@type integer 
    ARMOR_CHAOS_BOSS = 7 ---@type integer 

    PHYSICAL = DAMAGE_TYPE_NORMAL ---@type damagetype 
    MAGIC    = DAMAGE_TYPE_MAGIC ---@type damagetype 
    PURE     = DAMAGE_TYPE_DIVINE ---@type damagetype 

    local format = string.format
    local color_tag = {
        [MAGIC] = {100, 100, 255},
        [PURE] = {255, 255, 100},
        [PHYSICAL] = {200, 50, 50},
        crit = {255, 120, 20},
    }

    ---@type fun(source: unit, target: unit): number
    local function ReduceArmorCalc(source, target)
        local armor       = BlzGetUnitArmor(target) ---@type number 
        local amount      = 1.
        local percent_pen = Unit[source].armor_pen_percent
        local newarmor    = math.min(armor, armor - armor * percent_pen * 0.01)

        --apply new armor
        if newarmor > 0 then
            amount = amount - (amount * (0.05 * newarmor / (1 + 0.05 * newarmor)))
        else
            amount = amount * (2 - 0.94 ^ -newarmor)
        end

        --divide by old armor
        if armor > 0 then
            amount = amount / (1 - (0.05 * armor / (1 + 0.05 * armor)))
        else
            amount = amount / (2 - 0.94 ^ -armor)
        end

        return amount
    end

    ---@type fun(source: unit, target: unit, TYPE: damagetype): number
    function ApplyArmorMult(source, target, TYPE)
        local amount = 1.
        local armor = BlzGetUnitArmor(target) ---@type number 
        local dtype = BlzGetUnitIntegerField(target, UNIT_IF_DEFENSE_TYPE) ---@type integer 
        local atype = BlzGetUnitWeaponIntegerField(source, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0) ---@type integer 

        if TYPE ~= PURE then
            if (dtype == ARMOR_CHAOS or dtype == ARMOR_CHAOS_BOSS) then -- chaos armor
                amount = amount * 0.03
            end

            if TYPE == PHYSICAL then
                if atype == ATTACK_CHAOS then
                    amount = amount * 350.
                end

                if armor >= 0 then
                    amount = amount - (amount * (0.05 * armor / (1. + 0.05 * armor)))
                else
                    amount = amount * (2. - 0.94 ^ -armor)
                end
            end
        end

        return amount
    end

    ---@return string
    local function GetDamageTag()
        local str = DAMAGE_TAG[#DAMAGE_TAG]

        DAMAGE_TAG[#DAMAGE_TAG] = nil

        return str
    end

    ---@return boolean
    function OnDamage()
        --[[
        damage flow:
            handle dummy attacks and return
            onhit & onstruck
            multipliers
            reductions
            fatal damage

        note:
            event library prevents infinite recursion (i.e. for physical attacks that proc physical damage)
        ]]

        local source      = GetEventDamageSource() ---@type unit 
        local target      = BlzGetEventDamageTarget() ---@type unit 
        local amount      = { value = GetEventDamage() }
        local damage_type = BlzGetEventDamageType() ---@type damagetype 
        local pid         = GetPlayerId(GetOwningPlayer(source)) + 1 ---@type integer 
        local tpid        = GetPlayerId(GetOwningPlayer(target)) + 1 ---@type integer 
        local crit        = 1.
        local tag         = GetDamageTag()

        -- prevents 0 damage events from applying debuffs
        if source == nil or target == nil then
            return false
        end

        -- force unknown damage types to be magic
        if damage_type ~= PHYSICAL and damage_type ~= MAGIC and damage_type ~= PURE then
            damage_type = MAGIC
            BlzSetEventDamageType(MAGIC)
        end

        -- dummy onhit
        local dummy = Dummy[source]

        if dummy then
            EVENT_DUMMY_ON_HIT:trigger(dummy.source, target)
            BlzSetEventDamage(0.00)
            BlzSetUnitWeaponBooleanField(source, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, false) -- prevent dummies from attacking twice

            return false
        end

        -- source and target must be enemies for onhit and onstruck
        if IsUnitEnemy(target, GetOwningPlayer(source)) then

            -- physical damage
            if damage_type == PHYSICAL then
                local evade = Unit[target].evasion

                -- evasion
                if math.random(0, 99) < evade then
                    FloatingTextUnit("Dodged!", target, 1, 90, 0, 9, 180, 180, 20, 0, true)
                    amount.value = 0.00
                else
                    EVENT_ON_HIT_EVADE:trigger(source, target, amount)
                end

                EVENT_ON_HIT:trigger(source, target)
                EVENT_ON_HIT_MULTIPLIER:trigger(source, target, amount)

                -- critical strike
                if math.random() * 100. < Unit[source].cc then
                    crit = crit + Unit[source].cd * 0.01
                end

                -- apply crit multiplier
                amount.value = amount.value * crit
            end

            -- any other damage type

            EVENT_ON_STRUCK:trigger(target, source, damage_type)
            EVENT_ON_STRUCK_MULTIPLIER:trigger(target, source, amount, damage_type)

            -- struck or hit
            if IsEnemy(tpid) and not Unit[target].casting then
                EVENT_ENEMY_AI:trigger(target, source)
            elseif IsEnemy(pid) and not Unit[source].casting then
                EVENT_ENEMY_AI:trigger(source, target)
            end

            -- main hero damage taken
            if target == Hero[tpid] then
            end

            -- armor pen
            if Unit[source].armor_pen_percent > 0 then
                amount.value = amount.value * ReduceArmorCalc(source, target)
            end

            -- source multipliers and target resistances
            amount.value = amount.value * Unit[source].dm
            amount.value = amount.value * Unit[target].dr

            if damage_type == PHYSICAL then
                amount.value = amount.value * Unit[source].pm
                amount.value = amount.value * Unit[target].pr
            elseif damage_type == MAGIC then
                amount.value = amount.value * Unit[source].mm
                amount.value = amount.value * Unit[target].mr
            end
        end

        -- after reductions
        local amount_after_red = amount.value * ApplyArmorMult(source, target, damage_type)

        -- after reductions
        EVENT_ON_HIT_AFTER_REDUCTIONS:trigger(source, target, amount, amount_after_red, damage_type)
        EVENT_ON_STRUCK_AFTER_REDUCTIONS:trigger(target, source, amount, amount_after_red, damage_type)

        -- damage numbers
        local colors = amount.color or (crit > 1. and color_tag.crit) or color_tag[damage_type]
        local zeroDamage = (amount_after_red <= 0. or amount.value <= 0.)

        -- don't log or show zero damage
        if zeroDamage == false and source ~= target then
            -- prevent non-crit physical attacks from appearing if they do not reach a 0.05% max health damage threshold 
            if target == PUNCHING_BAG or damage_type ~= PHYSICAL or crit > 1. or (amount_after_red >= (BlzGetUnitMaxHP(target) * 0.0005)) then
                ArcingTextTag.create(amount_after_red, target, 1, 1, colors[1], colors[2], colors[3], 0)
            end

            local damageHex = format("|cff\x2502X\x2502X\x2502X", colors[1], colors[2], colors[3])
            LogDamage(source, target, damageHex .. RealToString(amount_after_red) .. "|r", false, tag)
        end

        -- pure damage on chaos armor
        if damage_type == PURE and (BlzGetUnitIntegerField(target, UNIT_IF_DEFENSE_TYPE) == ARMOR_CHAOS or BlzGetUnitIntegerField(target, UNIT_IF_DEFENSE_TYPE) == ARMOR_CHAOS_BOSS) then
            BlzSetEventAttackType(ATTACK_TYPE_CHAOS)
        end

        -- after displaying damage numbers
        EVENT_ON_HIT_FINAL:trigger(source, target, amount, amount_after_red, damage_type)
        EVENT_ON_STRUCK_FINAL:trigger(target, source, amount, amount_after_red, damage_type)

        -- fatal damage
        -- TODO: Investigate whether this could be bugged?
        if GetWidgetLife(target) - amount_after_red < MIN_LIFE then
            EVENT_ON_FATAL_DAMAGE:trigger(target, source, amount, damage_type)
        end

        -- set final event damage
        BlzSetEventDamage(amount.value)

        -- attack count based health
        if Unit[target].attackCount > 0 then
            Unit[target].attackCount = Unit[target].attackCount - 1
            BlzSetEventDamage(0.00)
            SetWidgetLife(target, GetWidgetLife(target) - 1)
        end

        return false
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_DAMAGING, OnDamage)
end, Debug and Debug.getLine())
