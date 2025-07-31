--[[
    bonus.lua

    A module that provides direct modification of a unit's stats using object natives.
]]

OnInit.global("Bonus", function(Require)
    Require('UnitTable')

    BONUS_ARMOR         = 1
    BONUS_DAMAGE        = 2
    BONUS_HERO_STR      = 3
    BONUS_HERO_AGI      = 4
    BONUS_HERO_INT      = 5
    BONUS_LIFE_REGEN    = 6
    BONUS_ATTACK_SPEED  = 7
    BONUS_HERO_BASE_STR = 8
    BONUS_HERO_BASE_AGI = 9
    BONUS_HERO_BASE_INT = 10
    BONUS_MOVE_SPEED    = 11
    BONUS_MANA_REGEN    = 12

    local BONUS_ABIL = { ---@type integer
        [BONUS_ARMOR] = FourCC('Z000'),
        [BONUS_DAMAGE] = FourCC('Z001'),
        [BONUS_HERO_STR] = FourCC('Z002'),
        [BONUS_HERO_AGI] = FourCC('Z002'),
        [BONUS_HERO_INT] = FourCC('Z002'),
        [BONUS_ATTACK_SPEED] = FourCC('Z006')
    }

    local BONUS_IFIELD = { ---@type abilityintegerlevelfield[] 
        ABILITY_ILF_DEFENSE_BONUS_IDEF,
        ABILITY_ILF_ATTACK_BONUS,
        ABILITY_ILF_STRENGTH_BONUS_ISTR,
        ABILITY_ILF_AGILITY_BONUS,
        ABILITY_ILF_INTELLIGENCE_BONUS,
    }

    -- special case behaviors for certain stats
    local bonus_getters = {
        [BONUS_LIFE_REGEN] = function(u) return BlzGetUnitRealField(u, UNIT_RF_HIT_POINTS_REGENERATION_RATE) end,
        [BONUS_MANA_REGEN] = function(u) return BlzGetUnitRealField(u, UNIT_RF_MANA_REGENERATION) end,
        [BONUS_ATTACK_SPEED] = function(u, bonus) return BlzGetAbilityRealLevelField(BlzGetUnitAbility(u, BONUS_ABIL[bonus]), ABILITY_RLF_ATTACK_SPEED_INCREASE_ISX1, 0) end,

        [BONUS_HERO_BASE_STR] = function(u) return GetHeroStr(u, false) end,
        [BONUS_HERO_BASE_AGI] = function(u) return GetHeroAgi(u, false) end,
        [BONUS_HERO_BASE_INT] = function(u) return GetHeroInt(u, false) end,
    }

    local bonus_setters = {
        [BONUS_LIFE_REGEN] = function(u, _, amount) return BlzSetUnitRealField(u, UNIT_RF_HIT_POINTS_REGENERATION_RATE, amount) end,
        [BONUS_MANA_REGEN] = function(u, _, amount) return BlzSetUnitRealField(u, UNIT_RF_MANA_REGENERATION, amount) end,
        [BONUS_ATTACK_SPEED] = function(u, bonus, amount) return BlzSetAbilityRealLevelField(BlzGetUnitAbility(u, BONUS_ABIL[bonus]), ABILITY_RLF_ATTACK_SPEED_INCREASE_ISX1, 0, amount) end,
        [BONUS_HERO_BASE_STR] = function(u, _, amount) return SetHeroStr(u, amount, true) end,
        [BONUS_HERO_BASE_AGI] = function(u, _, amount) return SetHeroAgi(u, amount, true) end,
        [BONUS_HERO_BASE_INT] = function(u, _, amount) return SetHeroInt(u, amount, true) end,
        [BONUS_MOVE_SPEED] = function(u, _, amount)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            local ms = Unit[u].ms_flat * Unit[u].ms_percent

            if u == Hero[pid] then
                -- have backpack move at highest possible speed
                SetUnitMoveSpeed(Backpack[pid], math.max(ms, amount))
            end
            SetUnitMoveSpeed(u, amount)
            MovespeedCheck(u, amount)
        end,
    }

    --default behavior for getters and setters (integer level fields)
    local default_getter = function(u, bonus) return BlzGetAbilityIntegerLevelField(BlzGetUnitAbility(u, BONUS_ABIL[bonus]), BONUS_IFIELD[bonus], 0) end
    setmetatable(bonus_getters, { __index = function() return default_getter end})

    local default_setter = function(u, bonus, amount) return BlzSetAbilityIntegerLevelField(BlzGetUnitAbility(u, BONUS_ABIL[bonus]), BONUS_IFIELD[bonus], 0, R2I(amount)) end
    setmetatable(bonus_setters, { __index = function() return default_setter end})

    ---@type fun(u: unit, bonus: integer): number
    function UnitGetBonus(u, bonus)
        return bonus_getters[bonus](u, bonus)
    end

    ---@type fun(u: unit, bonus: integer, amount: number)
    function UnitSetBonus(u, bonus, amount)
        local abil = BONUS_ABIL[bonus] or 0

        if UnitAddAbility(u, abil) then
            UnitMakeAbilityPermanent(u, true, abil)
        end

        bonus_setters[bonus](u, bonus, amount)

        IncUnitAbilityLevel(u, abil)
        DecUnitAbilityLevel(u, abil)
    end

    ---@type fun(u: unit, bonus: integer, amount: number)
    function UnitAddBonus(u, bonus, amount)
        if amount ~= 0 then
            UnitSetBonus(u, bonus, UnitGetBonus(u, bonus) + amount)
        end
    end
end, Debug and Debug.getLine())
