--[[
    damage.lua

    A library that handles the damage event (EVENT_PLAYER_UNIT_DAMAGING) and calculates on hit effects,
    multipliers, reductions, mitigations, etc.
]]

OnInit.final("Damage", function(Require)
    Require('Variables')
    Require('UnitTable')
    Require('Events')
    Require('EnemyAI')

    ATTACK_CHAOS     = 5 ---@type integer 
    ARMOR_CHAOS      = 6 ---@type integer 
    ARMOR_CHAOS_BOSS = 7 ---@type integer 

    PHYSICAL = DAMAGE_TYPE_NORMAL ---@type damagetype 
    MAGIC    = DAMAGE_TYPE_MAGIC ---@type damagetype 
    PURE     = DAMAGE_TYPE_DIVINE ---@type damagetype 

    local DAMAGE_CONTEXT = {} ---@type table[]
    local DAMAGE_CONTEXT_DEPTH = 0
    local WEAPON_TYPE_WHOKNOWS = WEAPON_TYPE_WHOKNOWS

    ---@type fun(source: unit, target: unit, dmg: number, attack_type: attacktype, damage_type: damagetype, tag: string|nil)
    function DamageTarget(source, target, dmg, attack_type, damage_type, tag)
        DAMAGE_CONTEXT_DEPTH = DAMAGE_CONTEXT_DEPTH + 1
        DAMAGE_CONTEXT[DAMAGE_CONTEXT_DEPTH] = { tag = tag, consumed = false }
        UnitDamageTarget(source, target, dmg, true, false, attack_type, damage_type, WEAPON_TYPE_WHOKNOWS)
        DAMAGE_CONTEXT[DAMAGE_CONTEXT_DEPTH] = nil
        DAMAGE_CONTEXT_DEPTH = DAMAGE_CONTEXT_DEPTH - 1
    end

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

    local get_event_damage_source = GetEventDamageSource
    local blz_get_event_damage_target = BlzGetEventDamageTarget
    local get_event_damage = GetEventDamage
    local blz_get_event_damage_type = BlzGetEventDamageType
    local get_owning_player = GetOwningPlayer
    local blz_set_event_damage = BlzSetEventDamage

    local EVENT_DUMMY_ON_HIT = EVENT_DUMMY_ON_HIT
    local EVENT_ON_HIT, EVENT_ON_HIT_EVADE, EVENT_ON_HIT_MULTIPLIER, EVENT_ON_HIT_AFTER_REDUCTIONS, EVENT_ON_HIT_FINAL = EVENT_ON_HIT, EVENT_ON_HIT_EVADE, EVENT_ON_HIT_MULTIPLIER, EVENT_ON_HIT_AFTER_REDUCTIONS, EVENT_ON_HIT_FINAL
    local EVENT_ON_STRUCK, EVENT_ON_STRUCK_MULTIPLIER, EVENT_ON_STRUCK_AFTER_REDUCTIONS, EVENT_ON_STRUCK_FINAL = EVENT_ON_STRUCK, EVENT_ON_STRUCK_MULTIPLIER, EVENT_ON_STRUCK_AFTER_REDUCTIONS, EVENT_ON_STRUCK_FINAL
    local EVENT_ON_FATAL_DAMAGE = EVENT_ON_FATAL_DAMAGE
    local evaluate_enemy_ai = EnemyAI.evaluate

    ---@return boolean
    function OnDamage()
        if DEV_ENABLED and RuntimeMetrics then
            RuntimeMetrics.damage.events = RuntimeMetrics.damage.events + 1
        end

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

        local source      = get_event_damage_source()
        local target      = blz_get_event_damage_target()
        ---Final damage callbacks may set `display` when the engine damage is
        ---suppressed but the calculated hit should still be shown.
        ---@type {value: number, display: number?, color: number[]?}
        local amount      = { value = get_event_damage() }
        local damage_type = blz_get_event_damage_type()
        local crit        = 1.
        local context     = DAMAGE_CONTEXT[DAMAGE_CONTEXT_DEPTH]
        local tag
        if context and not context.consumed then
            tag = context.tag
            context.consumed = true
        end
        local source_tbl  = Unit[source]
        local target_tbl  = Unit[target]

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
            blz_set_event_damage(0.00)
            BlzSetUnitWeaponBooleanField(source, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, false) -- prevent dummies from attacking twice

            return false
        end

        -- source and target must be enemies for onhit and onstruck
        if IsUnitEnemy(target, get_owning_player(source)) then

            -- physical damage
            if damage_type == PHYSICAL then
                local evade = target_tbl.evasion

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
                if math.random() * 100. < source_tbl.cc then
                    crit = crit + source_tbl.cd * 0.01
                end

                -- apply crit multiplier
                amount.value = amount.value * crit
            end

            -- any other damage type

            EVENT_ON_STRUCK:trigger(target, source, damage_type)
            EVENT_ON_STRUCK_MULTIPLIER:trigger(target, source, amount, damage_type)

            -- armor pen
            if source_tbl.armor_pen_percent > 0 then
                amount.value = amount.value * ReduceArmorCalc(source, target)
            end

            -- source multipliers and target resistances
            amount.value = amount.value * source_tbl.dm
            amount.value = amount.value * target_tbl.dr

            if damage_type == PHYSICAL then
                amount.value = amount.value * source_tbl.pm
                amount.value = amount.value * target_tbl.pr
            elseif damage_type == MAGIC then
                amount.value = amount.value * source_tbl.mm
                amount.value = amount.value * target_tbl.mr
            end
        end

        -- after reductions
        local armor_multiplier = ApplyArmorMult(source, target, damage_type)
        local amount_after_red = amount.value * armor_multiplier

        -- after reductions
        EVENT_ON_HIT_AFTER_REDUCTIONS:trigger(source, target, amount, amount_after_red, damage_type)
        EVENT_ON_STRUCK_AFTER_REDUCTIONS:trigger(target, source, amount, amount_after_red, damage_type)

        -- pure damage on chaos armor
        if damage_type == PURE and (BlzGetUnitIntegerField(target, UNIT_IF_DEFENSE_TYPE) == ARMOR_CHAOS or BlzGetUnitIntegerField(target, UNIT_IF_DEFENSE_TYPE) == ARMOR_CHAOS_BOSS) then
            BlzSetEventAttackType(ATTACK_TYPE_CHAOS)
        end

        amount_after_red = amount.value * armor_multiplier

        -- final damage callbacks before applying engine damage
        EVENT_ON_HIT_FINAL:trigger(source, target, amount, amount_after_red, damage_type)
        EVENT_ON_STRUCK_FINAL:trigger(target, source, amount, amount_after_red, damage_type)

        -- Final callbacks may mutate the base amount. Keep fatal checks, display,
        -- logging and engine damage derived from the same final value.
        amount_after_red = amount.value * armor_multiplier

        -- fatal damage
        -- TODO: Investigate whether this could be bugged?
        if GetWidgetLife(target) - amount_after_red < MIN_LIFE then
            EVENT_ON_FATAL_DAMAGE:trigger(target, source, amount, damage_type)
        else
            evaluate_enemy_ai(target, source, target_tbl)
            evaluate_enemy_ai(source, target, source_tbl)
        end

        -- Fatal callbacks may prevent or alter the hit. Derive the applied and
        -- displayed amount once more after the last mutating stage.
        amount_after_red = amount.value * armor_multiplier

        -- set final event damage
        blz_set_event_damage(amount.value)

        local display_amount = amount.display or amount_after_red

        -- hit count based health
        if target_tbl.hit_based_health then
            local hit_dmg = source_tbl.hit_damage
            blz_set_event_damage(0.00)
            SetWidgetLife(target, GetWidgetLife(target) - hit_dmg)
            display_amount = hit_dmg
        end

        -- damage numbers
        local colors = amount.color or (crit > 1. and color_tag.crit) or color_tag[damage_type]
        local zeroDamage = display_amount <= 0.

        -- don't log or display zero damage
        if zeroDamage == false and source ~= target then
            -- prevent non-crit physical attacks from appearing if they do not reach a 0.05% max health damage threshold 
            if target == PUNCHING_BAG or damage_type ~= PHYSICAL or crit > 1. or (display_amount >= (BlzGetUnitMaxHP(target) * 0.0005)) then
                ArcingTextTag.create(display_amount, target, 1, 1, colors[1], colors[2], colors[3], 0)
            end

            local damageHex = format("|cff%02X%02X%02X", colors[1], colors[2], colors[3])
            LogDamage(source, target, damageHex .. RealToString(display_amount) .. "|r", false, tag)
        end

        return false
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_DAMAGING, OnDamage)
end, Debug and Debug.getLine())
