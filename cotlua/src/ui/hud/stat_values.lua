OnInit.final("StatValues", function(Require)
    Require('StatSchema')
    Require('HeroDefinitions')
    Require('Progression')
    Require('TextHelpers')
    Require('UnitTable')
    Require('Profile')
    Require('WorldUnitQueries')

    local format = string.format

    STAT_TAG[ITEM_LEVEL].breakdown = function(u)
        local level = GetUnitLevel(u)
        if IsUnitType(u, UNIT_TYPE_HERO) then
            return "XP: " .. Progression.getXPIntoLevel(u) .. "/" ..
                       RequiredXP(level)
        end
        return ""
    end
    STAT_TAG[ITEM_LEVEL].getter = function(u)
        return RealToString(GetUnitLevel(u))
    end

    STAT_TAG[ITEM_HEALTH].getter = function(u)
        return RealToString(GetWidgetLife(u)) .. " / " ..
                   RealToString(Unit[u].hp)
    end
    STAT_TAG[ITEM_MANA].getter = function(u)
        return RealToString(GetUnitState(u, UNIT_STATE_MANA)) .. " / " ..
                   RealToString(GetUnitState(u, UNIT_STATE_MAX_MANA))
    end
    STAT_TAG[ITEM_DAMAGE].getter = function(u)
        return RealToString(Unit[u].damage + 1)
    end -- Include the damage die.
    STAT_TAG[ITEM_DAMAGE].breakdown = function(u)
        return "|cffffcc00Base Damage:|r " .. BlzGetUnitBaseDamage(u, 0) ..
                   "\n|cffffcc00Spell/Item Bonus:|r " .. Unit[u].bonus_damage ..
                   "\n|cffffcc00Percent Bonus:|r " ..
                   format("%.3f", (Unit[u].damage_percent - 1.) * 100.) .. "%" ..
                   " (" .. format("%.3f",
                                  Unit[u].damage - Unit[u].bonus_damage -
                                      BlzGetUnitBaseDamage(u, 0)) .. ")" ..
                   "\n|cffffcc00Total Damage:|r " .. (Unit[u].damage + 1)
    end
    STAT_TAG[ITEM_ARMOR].getter = function(u)
        return RealToString(BlzGetUnitArmor(u))
    end
    STAT_TAG[ITEM_STRENGTH].getter = function(u)
        return RealToString(GetHeroStr(u, true))
    end
    STAT_TAG[ITEM_AGILITY].getter = function(u)
        return RealToString(GetHeroAgi(u, true))
    end
    STAT_TAG[ITEM_INTELLIGENCE].getter = function(u)
        return RealToString(GetHeroInt(u, true))
    end
    STAT_TAG[ITEM_REGENERATION].getter = function(u)
        return RealToString(Unit[u].regen)
    end
    STAT_TAG[ITEM_REGENERATION].breakdown = function(u)
        return "|cffffcc00Flat Regeneration:|r " .. Unit[u].regen_flat ..
                   "\n|cffffcc00Percent Regeneration:|r " ..
                   format("%.3f", Unit[u].regen_max) .. "%" .. " (" ..
                   format("%.3f", Unit[u].regen_max * Unit[u].hp * 0.01) .. ")" ..
                   "\n|cffffcc00Healing Received:|r " ..
                   format("%.3f", Unit[u].regen_percent * 100.) .. "%" ..
                   "\n|cffffcc00Total Regeneration:|r " .. Unit[u].regen
    end
    STAT_TAG[ITEM_MANA_REGENERATION].getter = function(u)
        return RealToString(Unit[u].mana_regen)
    end
    STAT_TAG[ITEM_MANA_REGENERATION].breakdown = function(u)
        return "|cffffcc00Flat Regeneration:|r " .. Unit[u].mana_regen_flat ..
                   "\n|cffffcc00Intelligence Regeneration:|r " ..
                   GetHeroInt(u, true) * 0.05 ..
                   "\n|cffffcc00Percent Regeneration:|r " ..
                   format("%.2f", Unit[u].mana_regen_max) .. "%" .. " (" ..
                   Unit[u].mana_regen_max * Unit[u].mana * 0.01 .. ")" ..
                   "\n|cffffcc00Mana Received:|r " ..
                   format("%.2f", Unit[u].mana_regen_percent * 100.) .. "%" ..
                   "\n|cffffcc00Total Regeneration:|r " .. Unit[u].mana_regen
    end

    STAT_TAG[ITEM_DAMAGE_RESIST].breakdown = function(u)
        local defense_type = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduction = (defense_type == ARMOR_CHAOS or defense_type ==
                                    ARMOR_CHAOS_BOSS) and 0.03 or 1.
        local chaos = (chaos_reduction == 0.03 and
                          "\n|cffffcc00Chaos Reduction:|r " ..
                          format("%.3f", (1. - chaos_reduction) * 100) .. "%" or
                          "")
        return "|cffffcc00Base Reduction:|r " ..
                   format("%.3f",
                          100. - HERO_STATS[GetType(u)].phys_resist * 100.) ..
                   "%" .. "\n|cffffcc00Spell/Item Reduction:|r " ..
                   format("%.3f", 100. - (Unit[u].dr * Unit[u].pr) /
                              HERO_STATS[GetType(u)].phys_resist * 100.) .. "%" ..
                   "\n|cffffcc00Armor Reduction:|r " .. format("%.3f", ((0.05 *
                                                                   BlzGetUnitArmor(
                                                                       u)) /
                                                                   (1. + 0.05 *
                                                                       BlzGetUnitArmor(
                                                                           u))) *
                                                                   100.) .. "%" ..
                   chaos .. "\n|cffffcc00Total Reduction:|r " ..
                   format("%.3f", 100. - (Unit[u].dr * Unit[u].pr) * 100. *
                              (1. -
                                  ((0.05 * BlzGetUnitArmor(u)) /
                                      (1. + 0.05 * BlzGetUnitArmor(u)))) *
                              chaos_reduction) .. "%"
    end

    STAT_TAG[ITEM_DAMAGE_RESIST].getter = function(u)
        local defense_type = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduction = (defense_type == ARMOR_CHAOS or defense_type ==
                                    ARMOR_CHAOS_BOSS) and 0.03 or 1.
        return format("%.3f", (Unit[u].dr * Unit[u].pr) * 100. *
                          (1. -
                              ((0.05 * BlzGetUnitArmor(u)) /
                                  (1. + 0.05 * BlzGetUnitArmor(u)))) *
                          chaos_reduction)
    end

    STAT_TAG[ITEM_MAGIC_RESIST].breakdown = function(u)
        local defense_type = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduction = (defense_type == ARMOR_CHAOS or defense_type ==
                                    ARMOR_CHAOS_BOSS) and 0.03 or 1.
        local chaos = (chaos_reduction == 0.03 and
                          "\n|cffffcc00Chaos Reduction:|r " ..
                          format("%.3f", (1. - chaos_reduction) * 100) .. "%" or
                          "")
        return "|cffffcc00Base Reduction:|r " ..
                   format("%.3f",
                          100. - HERO_STATS[GetType(u)].magic_resist * 100.) ..
                   "%" .. "\n|cffffcc00Spell/Item Reduction:|r " ..
                   format("%.3f", 100. - (Unit[u].dr * Unit[u].mr) /
                              HERO_STATS[GetType(u)].magic_resist * 100.) .. "%" ..
                   chaos .. "\n|cffffcc00Total Reduction:|r " ..
                   format("%.3f", 100. - (Unit[u].dr * Unit[u].mr) * 100. *
                              chaos_reduction) .. "%"
    end

    STAT_TAG[ITEM_MAGIC_RESIST].getter = function(u)
        local defense_type = BlzGetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE)
        local chaos_reduction = (defense_type == ARMOR_CHAOS or defense_type ==
                                    ARMOR_CHAOS_BOSS) and 0.03 or 1.
        return
            format("%.3f", (Unit[u].dr * Unit[u].mr) * 100. * chaos_reduction)
    end

    STAT_TAG[ITEM_DAMAGE_MULT].getter = function(u)
        return format("%.3f", (Unit[u].dm * Unit[u].pm) * 100.)
    end
    STAT_TAG[ITEM_MAGIC_MULT].getter = function(u)
        return format("%.3f", (Unit[u].dm * Unit[u].mm) * 100.)
    end
    STAT_TAG[ITEM_MOVESPEED].getter = function(u)
        return RealToString(Unit[u].movespeed)
    end
    STAT_TAG[ITEM_EVASION].getter = function(u)
        return math.min(100, Unit[u].evasion)
    end
    STAT_TAG[ITEM_SPELLBOOST].getter = function(u)
        return format("%.3f", Unit[u].spellboost * 100.)
    end
    STAT_TAG[ITEM_SPELLBOOST].breakdown = function(u)
        return "|cffffcc00Spell Power:|r " .. format("%.3f", Unit[u].spellboost * 100.) ..
            "%\n|cff999999Increases supported spell damage, healing,\n" ..
            "shield strength, and other spell bonuses.\n" ..
            "Spell Power retains random variance.\n" ..
            "Area and duration have no random variance.|r"
    end
    STAT_TAG[ITEM_SPELL_AREA].getter = function(u)
        return format("%.3f", Unit[u].spell_area * 100.)
    end
    STAT_TAG[ITEM_SPELL_AREA].breakdown = function(u)
        return "|cffffcc00Radius/Range Multiplier:|r x" ..
            format("%.3f", math.max(0., 1. + Unit[u].spell_area)) ..
            "\nApplies to supported spell radii and distances, not every cast range."
    end
    STAT_TAG[ITEM_SPELL_DURATION].getter = function(u)
        return format("%.3f", Unit[u].spell_duration * 100.)
    end
    STAT_TAG[ITEM_SPELL_DURATION].breakdown = function(u)
        return "|cffffcc00Duration Multiplier:|r x" ..
            format("%.3f", math.max(0., 1. + Unit[u].spell_duration)) ..
            "\nApplies to supported effect durations, not ability cooldowns."
    end
    STAT_TAG[ITEM_CRIT_CHANCE].getter = function(u)
        return format("%.2f", Unit[u].cc)
    end
    STAT_TAG[ITEM_CRIT_CHANCE].breakdown = function(u)
        local unit = Unit[u]
        local base = HERO_STATS[GetType(u)].crit_chance
        local cap = unit.cc > 100 and
            "\n|cffffcc00Effective Roll Chance:|r 100.00% (cap)" or ""
        return "|cffffcc00Base Chance:|r " .. format("%.2f", base) .. "%" ..
            "\n|cffffcc00Spell/Item Flat Bonus:|r " .. format("%.2f", unit.cc_flat - base) .. "%" ..
            "\n|cffffcc00Critical Chance Multiplier:|r x" .. format("%.2f", unit.cc_percent) ..
            " (" .. format("%.2f", unit.cc_percent * 100.) .. "%)" ..
            "\n|cffffcc00Total Critical Chance:|r " .. format("%.2f", unit.cc) .. "%" .. cap
    end
    STAT_TAG[ITEM_CRIT_DAMAGE].getter = function(u)
        return format("%.2f", Unit[u].cd)
    end
    STAT_TAG[ITEM_CRIT_CHANCE_MULT].getter = function(u)
        return format("%.2f", Unit[u].cc_percent * 100.)
    end
    STAT_TAG[ITEM_CRIT_DAMAGE_MULT].getter = function(u)
        return format("%.2f", Unit[u].cd * 100.)
    end
    STAT_TAG[ITEM_BASE_ATTACK_SPEED].getter = function(u)
        local attack_speed = BlzGetUnitWeaponBooleanField(u,
                                                          UNIT_WEAPON_BF_ATTACKS_ENABLED,
                                                          0) and 1. /
                                 Unit[u].bat or 0
        return format("%.2f", attack_speed) .. " attacks per second"
    end
    STAT_TAG[ITEM_GOLD_GAIN].getter = function(u)
        local rate = Unit[u].gold_rate
        -- Lua preserves the sign bit on floating-point zero. Normalizing here
        -- prevents reversible stat updates from rendering Gold Find as -0.0%.
        return math.abs(rate) < 0.0005 and 0 or rate
    end
    STAT_TAG[TOTAL_ATTACK_SPEED].getter = function(u)
        local attack_speed = BlzGetUnitWeaponBooleanField(u,
                                                          UNIT_WEAPON_BF_ATTACKS_ENABLED,
                                                          0) and
                                 (1. / Unit[u].bat) *
                                 (1 + math.min(GetHeroAgi(u, true), 400) * 0.01) or
                                 0
        return format("%.2f", attack_speed) .. " attacks per second"
    end
    STAT_TAG[TOTAL_ATTACK_SPEED].breakdown = function(u)
        local unit = Unit[u]
        local agility_bonus = math.min(GetHeroAgi(u, true), 400)
        local disabled = not BlzGetUnitWeaponBooleanField(u,
            UNIT_WEAPON_BF_ATTACKS_ENABLED, 0) and
            "\n|cffff8080Attacks are currently disabled.|r" or ""
        return "|cffffcc00Base Attack Time:|r " .. format("%.3f", unit.base_bat) .. " seconds" ..
            "\n|cffffcc00Attack Time Multiplier:|r x" .. format("%.3f", unit.bonus_bat) ..
            "\n|cffffcc00Effective Attack Time:|r " .. format("%.3f", unit.bat) .. " seconds" ..
            "\n|cffffcc00Agility Bonus:|r +" .. format("%.2f", agility_bonus) .. "% (cap +400%)" ..
            "\n|cffffcc00Total Attack Speed:|r " .. STAT_TAG[TOTAL_ATTACK_SPEED].getter(u) .. disabled
    end
    STAT_TAG[XP_RATE].getter = function(u)
        return format("%.2f", Unit[u].xp_rate)
    end
    STAT_TAG[STATUS_RESISTANCE].getter = function(u)
        return format("%.2f", Unit[u].status_resist * 100.)
    end
    STAT_TAG[COOLDOWN_ACCELERATION].getter = function(u)
        local value = Unit[u].cooldown_acceleration
        -- Avoid displaying floating-point residue as a misleading -0.00.
        return format("%.2f", math.abs(value) < .005 and 0. or value)
    end
    STAT_TAG[DROP_RATE].getter = function(u)
        return format("%.0f", Unit[u].drop_rate * 100.)
    end
    STAT_TAG[BOSS_DROP_RATE].getter = function(u)
        return format("%.0f", Unit[u].boss_drop_rate * 100.)
    end
    STAT_TAG[HERO_TIME].getter = function(u)
        local pid = GetPlayerId(GetOwningPlayer(u)) + 1
        return (Profile[pid].hero.time // 60) .. " hours and " ..
                   ModuloInteger(Profile[pid].hero.time, 60) .. " minutes"
    end
    STAT_TAG[PLAYER_TIME].getter = function(u)
        local pid = GetPlayerId(GetOwningPlayer(u)) + 1
        return (Profile[pid].total_time // 60) .. " hours and " ..
                   ModuloInteger(Profile[pid].total_time, 60) .. " minutes"
    end
end, Debug and Debug.getLine())
