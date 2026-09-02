OnInit.final("DarkSummonerSpells", function(Require)
    Require('Spells')
    Require('SpellTools')
    Require('Events')
    Require('Profile')
    Require('SummonAbilities')
    Require('BuffsSummons')

    local MAX_TIER = 5
    local ESSENCE_INFO = FourCC('A063')
    local REAVER_WAR_CRY = FourCC('A01M')
    local ROSTER_COST = 2
    local INITIAL_ESSENCE = 3
    local SUMMON_DEATH_COOLDOWN = 30.
    local MILESTONES = { 15, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500 }
    local SUMMON_TYPES = { SUMMON_REAVER, SUMMON_GOLEM, SUMMON_DESTROYER }
    local IS_SUMMON_TYPE = {
        [SUMMON_REAVER] = true,
        [SUMMON_GOLEM] = true,
        [SUMMON_DESTROYER] = true,
    }
    local SUMMON_SPELL = {
        [SUMMON_REAVER] = FourCC('A0KF'),
        [SUMMON_GOLEM] = FourCC('A0KH'),
        [SUMMON_DESTROYER] = FourCC('A0KG'),
    }
    local essence_tiers = {} ---@type table<integer, table<integer, integer>>
    local essence_roster = {} ---@type table<integer, table<integer, boolean>>

    local REAVER_STR_BY_TIER = { 0.10, 0.22, 0.37, 0.55, 0.75 }
    local REAVER_ARMOR_BY_TIER = { 0.03, 0.07, 0.12, 0.18, 0.25 }
    local GOLEM_STR_BY_TIER = { 0.12, 0.28, 0.48, 0.72, 1.00 }
    local GOLEM_ARMOR_BY_TIER = { 0.04, 0.09, 0.15, 0.22, 0.30 }
    local DESTROYER_STR_BY_TIER = { 0.06, 0.14, 0.24, 0.36, 0.50 }
    local DESTROYER_INT_BY_TIER = { 0.06, 0.14, 0.24, 0.40, 0.75 }
    local DESTROYER_AGI_BY_TIER = { 30, 70, 120, 180, 250 }
    local DESTROYER_ARMOR_BY_TIER = { 0.02, 0.05, 0.08, 0.11, 0.15 }

    local TIER_COMPLETE = "|cff66ff66"
    local TIER_CURRENT = "|cffffcc00"
    local TIER_LOCKED = "|cff777777"
    local COLOR_END = "|r"

    local ESSENCE_TIER_TEXT = {
        [SUMMON_REAVER] = {
            "Tier 1 - +10% STR and +3% Armor. Cleave: 26% damage.",
            "Tier 2 - +22% STR and +7% Armor; unlocks War Cry. Cleave: 32% damage.",
            "Tier 3 - +37% STR and +12% Armor. Cleave: 38% damage. Sacrifice: +10-30% base attack speed, +10-50% cleave damage, and +20-100 end width.",
            "Tier 4 - +55% STR and +18% Armor. Cleave: 44% damage and improves Dreadful Wounds to -10% damage.",
            "Tier 5 - +75% STR and +25% Armor. Cleave: 50% damage and heals up to 3% Max Health per attack. Sacrifice: +15-40% base attack speed, +15-75% cleave damage, and +30-150 end width.",
        },
        [SUMMON_GOLEM] = {
            "Tier 1 - +12% STR and +4% Armor.",
            "Tier 2 - +28% STR and +9% Armor; unlocks Taunt.",
            "Tier 3 - +48% STR and +15% Armor; unlocks Thunder Clap and doubles Sacrifice healing.",
            "Tier 4 - +72% STR and +22% Armor; unlocks Magnetic Force.",
            "Tier 5 - +100% STR and +30% Armor; Sacrifice grants 10% damage healing, capped at 1% Max Health per attack.",
        },
        [SUMMON_DESTROYER] = {
            "Tier 1 - +6% STR/INT, +30 AGI, and +2% Armor. Annihilation: 12% chance / 1.2x INT damage.",
            "Tier 2 - +14% STR/INT, +70 AGI, and +5% Armor; unlocks Blink. Annihilation: 14% chance / 1.4x INT damage.",
            "Tier 3 - +24% STR/INT, +120 AGI, and +8% Armor; +25% Crit / +200% Crit Damage. Annihilation: 16% chance / 1.6x INT damage. Sacrifice blocks 1 fatal hit.",
            "Tier 4 - +36% STR, +40% INT, +180 AGI, and +11% Armor. Annihilation: 18% chance / 1.8x INT damage. Sacrifice blocks 2 fatal hits at 60%+ cost.",
            "Tier 5 - +50% STR, +75% INT, +250 AGI, and +15% Armor. Annihilation: 20% chance / 2x INT damage. Sacrifice blocks 1/2/3 fatal hits at 20/40/80%+ cost.",
        },
    }

    ---@class SummonEssence
    ---@field available fun(pid: integer): integer
    ---@field bound fun(pid: integer): integer
    ---@field unspent fun(pid: integer): integer
    ---@field reserve fun(pid: integer, summon_type: integer): boolean
    ---@field dismiss fun(pid: integer, summon: unit): boolean
    ---@field getTier fun(pid: integer, summon: unit|integer): integer
    ---@field infuse fun(pid: integer, summon: unit): boolean
    ---@field reclaim fun(pid: integer, summon: unit): boolean
    ---@field apply fun(pid: integer, summon: unit)
    ---@field refreshTooltips fun(pid: integer)
    ---@field onFatalDamage fun(summon: unit, source: unit, amount: table)
    ---@field pack fun(pid: integer): integer
    ---@field load fun(pid: integer, packed: integer)
    SummonEssence = {}

    local function get_state(pid)
        local state = essence_tiers[pid]
        if not state then
            state = {
                [SUMMON_REAVER] = 0,
                [SUMMON_GOLEM] = 0,
                [SUMMON_DESTROYER] = 0,
            }
            essence_tiers[pid] = state
        end
        return state
    end

    local function get_roster(pid)
        local roster = essence_roster[pid]
        if not roster then
            roster = {}
            essence_roster[pid] = roster
        end
        return roster
    end

    local function get_summon_type(summon)
        if type(summon) == "number" then
            return summon
        elseif summon then
            return GetUnitTypeId(summon)
        end
        return 0
    end

    local function is_valid_summon(pid, summon)
        return summon ~= nil
            and IS_SUMMON_TYPE[GetUnitTypeId(summon)] == true
            and GetOwningPlayer(summon) == Player(pid - 1)
            and UnitAlive(summon)
            and not IsUnitHidden(summon)
    end

    local function is_respec_area(pid)
        local hero = Hero[pid]
        return hero ~= nil and (
            RectContainsUnit(gg_rct_Town_Main, hero)
            or RectContainsUnit(gg_rct_Church, hero)
            or RectContainsUnit(gg_rct_Tavern, hero))
    end

    local function persist(pid)
        local profile = Profile[pid]
        if profile and profile.hero then
            profile.hero.summon_essence = SummonEssence.pack(pid)
        end
    end

    local function message(pid, value)
        DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 8., value)
    end

    local function dev_log(value)
        if DevLog and DevLog.enabled then
            DevLog.write("SUMMONER", value, true)
        end
    end

    ---@param spell Spell
    ---@param count integer
    ---@param make_tooltip fun(level: integer): string
    local function set_extended_tooltips(spell, count, make_tooltip)
        for level = 1, count do
            Spell.TOOLTIPS[spell.id][level] = make_tooltip(level)
        end
    end

    function SummonEssence.available(pid)
        local hero = Hero[pid]
        local level = hero and GetHeroLevel(hero) or 1
        local points = INITIAL_ESSENCE

        for i = 1, #MILESTONES do
            if level < MILESTONES[i] then break end
            points = points + 1
        end
        return points
    end

    function SummonEssence.bound(pid)
        local roster = get_roster(pid)
        local count = 0
        for i = 1, #SUMMON_TYPES do
            if roster[SUMMON_TYPES[i]] then
                count = count + 1
            end
        end
        return count * ROSTER_COST
    end

    function SummonEssence.unspent(pid)
        local state = get_state(pid)
        local spent = state[SUMMON_REAVER] + state[SUMMON_GOLEM] + state[SUMMON_DESTROYER]
        return math.max(0, SummonEssence.available(pid) - SummonEssence.bound(pid) - spent)
    end

    function SummonEssence.reserve(pid, summon_type)
        local roster = get_roster(pid)
        if roster[summon_type] then return true end

        if SummonEssence.unspent(pid) < ROSTER_COST then
            message(pid, "|cffff0000You need " .. ROSTER_COST
                .. " unallocated Essence to summon that creature.|r")
            return false
        end

        roster[summon_type] = true
        if SummonEssence.refreshTooltips then
            SummonEssence.refreshTooltips(pid)
        end
        dev_log("reserve pid=" .. pid .. " summon=" .. GetObjectName(summon_type)
            .. " total=" .. SummonEssence.available(pid) .. " bound=" .. SummonEssence.bound(pid)
            .. " unspent=" .. SummonEssence.unspent(pid))
        message(pid, "|cffb46eff" .. ROSTER_COST .. " Essence bound to summon. "
            .. SummonEssence.unspent(pid) .. " point(s) remain.|r")
        return true
    end

    function SummonEssence.getTier(pid, summon)
        return get_state(pid)[get_summon_type(summon)] or 0
    end

    local function tier_color(current_tier, displayed_tier)
        if displayed_tier < current_tier then
            return TIER_COMPLETE
        elseif displayed_tier == current_tier then
            return TIER_CURRENT
        end
        return TIER_LOCKED
    end

    local function refresh_essence_tooltip(pid, summon)
        local uid = GetUnitTypeId(summon)
        local lines = ESSENCE_TIER_TEXT[uid]
        if not lines then return end

        UnitAddAbility(summon, ESSENCE_INFO)
        UnitMakeAbilityPermanent(summon, true, ESSENCE_INFO)

        local ability = BlzGetUnitAbility(summon, ESSENCE_INFO)
        if not ability then return end

        local tier = SummonEssence.getTier(pid, uid)
        local tooltip = "|cffffcc00Current Tier: " .. tier .. "/" .. MAX_TIER .. COLOR_END
            .. "|n|cffb46effTotal Essence: " .. SummonEssence.available(pid)
            .. " | Bound: " .. SummonEssence.bound(pid)
            .. " | Unspent: " .. SummonEssence.unspent(pid) .. COLOR_END .. "|n|n"

        for displayed_tier = 1, MAX_TIER do
            tooltip = tooltip .. tier_color(tier, displayed_tier) .. lines[displayed_tier] .. COLOR_END
            if displayed_tier < MAX_TIER then
                tooltip = tooltip .. "|n"
            end
        end

        BlzSetAbilityStringLevelField(ability, ABILITY_SLF_TOOLTIP_NORMAL, 0,
            "Summon Essence - Tier " .. tier .. "/" .. MAX_TIER)
        BlzSetAbilityStringLevelField(ability, ABILITY_SLF_TOOLTIP_NORMAL_EXTENDED, 0, tooltip)
    end

    local function refresh_all_essence_tooltips(pid)
        for i = 1, #PLAYER_SUMMONS do
            local summon = PLAYER_SUMMONS[i]
            if summon and GetOwningPlayer(summon) == Player(pid - 1)
                and IS_SUMMON_TYPE[GetUnitTypeId(summon)] then
                refresh_essence_tooltip(pid, summon)
            end
        end
    end

    SummonEssence.refreshTooltips = refresh_all_essence_tooltips

    function SummonEssence.pack(pid)
        local state = get_state(pid)
        return state[SUMMON_REAVER] + state[SUMMON_GOLEM] * 6 + state[SUMMON_DESTROYER] * 36
    end

    function SummonEssence.load(pid, packed)
        packed = math.max(0, math.floor(packed or 0))

        local state = get_state(pid)
        state[SUMMON_REAVER] = math.min(MAX_TIER, packed % 6)
        packed = packed // 6
        state[SUMMON_GOLEM] = math.min(MAX_TIER, packed % 6)
        packed = packed // 6
        state[SUMMON_DESTROYER] = math.min(MAX_TIER, packed % 6)

        local overflow = state[SUMMON_REAVER] + state[SUMMON_GOLEM]
            + state[SUMMON_DESTROYER] - SummonEssence.available(pid)

        for i = #SUMMON_TYPES, 1, -1 do
            if overflow <= 0 then break end
            local uid = SUMMON_TYPES[i]
            local removed = math.min(overflow, state[uid])
            state[uid] = state[uid] - removed
            overflow = overflow - removed
        end
        persist(pid)
    end

    local function remove_tier_bonuses(summon)
        local unit = Unit[summon]

        unit.bonus_str = unit.bonus_str - (unit.essence_str or 0)
        unit.bonus_agi = unit.bonus_agi - (unit.essence_agi or 0)
        unit.bonus_int = unit.bonus_int - (unit.essence_int or 0)
        unit.armor_percent = unit.armor_percent - (unit.essence_armor_percent or 0.)
        unit.cc_flat = unit.cc_flat - (unit.essence_cc or 0)
        unit.cd_flat = unit.cd_flat - (unit.essence_cd or 0)

        unit.essence_str = 0
        unit.essence_agi = 0
        unit.essence_int = 0
        unit.essence_armor_percent = 0.
        unit.essence_cc = 0
        unit.essence_cd = 0
    end

    local function add_allocation_controls(summon)
        UnitAddAbility(summon, INFUSE_ESSENCE.id)
        UnitAddAbility(summon, RECLAIM_ESSENCE.id)
        UnitMakeAbilityPermanent(summon, true, INFUSE_ESSENCE.id)
        UnitMakeAbilityPermanent(summon, true, RECLAIM_ESSENCE.id)
        SetUnitAbilityLevel(summon, INFUSE_ESSENCE.id, 1)
        SetUnitAbilityLevel(summon, RECLAIM_ESSENCE.id, 1)
        BlzUnitDisableAbility(summon, INFUSE_ESSENCE.id, false, false)
        BlzUnitDisableAbility(summon, RECLAIM_ESSENCE.id, false, false)
        BlzUnitHideAbility(summon, INFUSE_ESSENCE.id, false)
        BlzUnitHideAbility(summon, RECLAIM_ESSENCE.id, false)
        UnitAddAbility(summon, ESSENCE_INFO)
        UnitMakeAbilityPermanent(summon, true, ESSENCE_INFO)
    end

    function SummonEssence.apply(pid, summon)
        if not summon or not IS_SUMMON_TYPE[GetUnitTypeId(summon)] then return end

        local uid = GetUnitTypeId(summon)
        local tier = SummonEssence.getTier(pid, uid)
        local unit = Unit[summon]

        remove_tier_bonuses(summon)
        add_allocation_controls(summon)

        if uid == SUMMON_REAVER then
            UnitRemoveAbility(summon, REAVER_WAR_CRY)

            unit.essence_str = R2I(unit.str * (REAVER_STR_BY_TIER[tier] or 0.))
            unit.essence_armor_percent = REAVER_ARMOR_BY_TIER[tier] or 0.
            if tier >= 2 then UnitAddAbility(summon, REAVER_WAR_CRY) end
            SetUnitScale(summon, 0.75 + tier * 0.04, 1. + tier * 0.04, 1. + tier * 0.04)
            BlzSetHeroProperName(summon, "Dread Reaver (Tier " .. tier .. ")")
        elseif uid == SUMMON_GOLEM then
            UnitRemoveAbility(summon, FourCC('A0KI'))
            UnitRemoveAbility(summon, THUNDER_CLAP_GOLEM.id)
            UnitRemoveAbility(summon, MAGNETIC_FORCE.id)
            UnitRemoveAbility(summon, FourCC('A0IQ'))

            unit.essence_str = R2I(unit.str * (GOLEM_STR_BY_TIER[tier] or 0.))
            unit.essence_armor_percent = GOLEM_ARMOR_BY_TIER[tier] or 0.
            SetUnitScale(summon, 1. + tier * 0.05, 1. + tier * 0.05, 1. + tier * 0.05)
            BlzSetHeroProperName(summon, "Meat Golem (Tier " .. tier .. ")")

            if tier >= 2 then UnitAddAbility(summon, FourCC('A0KI')) end
            if tier >= 3 then UnitAddAbility(summon, THUNDER_CLAP_GOLEM.id) end
            if tier >= 4 then UnitAddAbility(summon, MAGNETIC_FORCE.id) end
            if tier >= 5 then UnitAddAbility(summon, FourCC('A0IQ')) end
        elseif uid == SUMMON_DESTROYER then
            UnitRemoveAbility(summon, FourCC('A061'))
            UnitRemoveAbility(summon, FourCC('A03B'))
            UnitRemoveAbility(summon, FourCC('A0IQ'))
            SetUnitAbilityLevel(summon, FourCC('A02D'), 1)

            unit.essence_str = R2I(unit.str * (DESTROYER_STR_BY_TIER[tier] or 0.))
            unit.essence_agi = DESTROYER_AGI_BY_TIER[tier] or 0
            unit.essence_int = R2I(unit.int * (DESTROYER_INT_BY_TIER[tier] or 0.))
            unit.essence_armor_percent = DESTROYER_ARMOR_BY_TIER[tier] or 0.
            if tier >= 2 then UnitAddAbility(summon, FourCC('A061')) end
            if tier >= 3 then
                UnitAddAbility(summon, FourCC('A03B'))
                unit.essence_cc = 25
                unit.essence_cd = 200
            end
            if tier >= 4 then
                SetUnitAbilityLevel(summon, FourCC('A02D'), 2)
                UnitAddAbility(summon, FourCC('A0IQ'))
            end
            BlzSetHeroProperName(summon, "Destroyer (Tier " .. tier .. ")")
        end

        unit.bonus_str = unit.bonus_str + unit.essence_str
        unit.bonus_agi = unit.bonus_agi + unit.essence_agi
        unit.bonus_int = unit.bonus_int + unit.essence_int
        unit.armor_percent = unit.armor_percent + unit.essence_armor_percent
        unit.cc_flat = unit.cc_flat + unit.essence_cc
        unit.cd_flat = unit.cd_flat + unit.essence_cd
        refresh_essence_tooltip(pid, summon)
    end

    function SummonEssence.infuse(pid, summon)
        if not is_valid_summon(pid, summon) then
            message(pid, "|cffff0000You must target one of your active summons.|r")
            return false
        end

        local uid = GetUnitTypeId(summon)
        local state = get_state(pid)
        if state[uid] >= MAX_TIER then
            message(pid, "|cffffcc00That summon is already tier 5.|r")
            return false
        elseif SummonEssence.unspent(pid) <= 0 then
            message(pid, "|cffffcc00You have no unallocated Essence points.|r")
            return false
        end

        state[uid] = state[uid] + 1
        persist(pid)
        SummonEssence.apply(pid, summon)
        refresh_all_essence_tooltips(pid)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Charm\\CharmTarget.mdl", summon, "chest"))
        FloatingTextUnit("Tier " .. state[uid], summon, 1, 75, 50, 12., 180, 110, 255, 0, true)
        message(pid, "|cffb46effEssence infused.|r " .. SummonEssence.unspent(pid) .. " point(s) remain.")
        return true
    end

    function SummonEssence.reclaim(pid, summon)
        if not is_valid_summon(pid, summon) then
            message(pid, "|cffff0000You must target one of your active summons.|r")
            return false
        elseif not is_respec_area(pid) then
            message(pid, "|cffff0000Essence can only be reclaimed in town, the church, or the tavern.|r")
            return false
        end

        local uid = GetUnitTypeId(summon)
        local state = get_state(pid)
        if state[uid] <= 0 then
            return SummonEssence.dismiss(pid, summon)
        end

        state[uid] = state[uid] - 1
        persist(pid)
        SummonEssence.apply(pid, summon)
        refresh_all_essence_tooltips(pid)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\DispelMagic\\DispelMagicTarget.mdl", summon, "origin"))
        message(pid, "|cffb46effEssence reclaimed.|r " .. SummonEssence.unspent(pid) .. " point(s) are available.")
        return true
    end

    local summon_cooldown_started = setmetatable({}, { __mode = 'k' })
    local summon_dismissing = setmetatable({}, { __mode = 'k' })

    function SummonEssence.dismiss(pid, summon)
        if not is_valid_summon(pid, summon) then
            message(pid, "|cffff0000You must target one of your active summons.|r")
            return false
        end

        local uid = GetUnitTypeId(summon)
        local roster = get_roster(pid)
        local hero = Hero[pid]
        local spell_id = SUMMON_SPELL[uid]

        roster[uid] = nil
        summon_dismissing[summon] = true
        SummonExpire(summon)
        summon_dismissing[summon] = nil
        summon_cooldown_started[summon] = nil
        TableRemove(PLAYER_SUMMONS, summon)

        if hero and spell_id then
            BlzUnitDisableAbility(hero, spell_id, false, false)
            BlzEndUnitAbilityCooldown(hero, spell_id)
        end

        refresh_all_essence_tooltips(pid)
        dev_log("dismiss pid=" .. pid .. " summon=" .. GetObjectName(uid)
            .. " total=" .. SummonEssence.available(pid) .. " bound=" .. SummonEssence.bound(pid)
            .. " unspent=" .. SummonEssence.unspent(pid))
        message(pid, "|cffb46effSummon dismissed. " .. ROSTER_COST
            .. " bound Essence refunded; " .. SummonEssence.unspent(pid) .. " point(s) remain.|r")
        return true
    end

    local function start_summon_death_cooldown(summon)
        if summon_dismissing[summon] or summon_cooldown_started[summon] then return end

        local pid = GetPlayerId(GetOwningPlayer(summon)) + 1
        local hero = Hero[pid]
        local spell_id = SUMMON_SPELL[GetUnitTypeId(summon)]

        if hero and spell_id and GetUnitAbilityLevel(hero, spell_id) > 0 then
            summon_cooldown_started[summon] = true
            BlzUnitDisableAbility(hero, spell_id, false, false)
            BlzStartUnitAbilityCooldown(hero, spell_id, SUMMON_DEATH_COOLDOWN)
            dev_log("death-cooldown pid=" .. pid .. " spell=" .. GetObjectName(spell_id)
                .. " seconds=" .. SUMMON_DEATH_COOLDOWN)
        end
    end

    function SummonEssence.onFatalDamage(summon, source, amount)
        if GetUnitTypeId(summon) == SUMMON_DESTROYER then
            local guard = DestroyerContinuityBuff:get(nil, summon)
            if guard and guard:consume() then
                amount.value = 0.
                amount.display = 0.
                DestroyEffect(AddSpecialEffectTarget(
                    "Abilities\\Spells\\Human\\DivineShield\\DivineShieldTarget.mdl", summon, "origin"))
                FloatingTextUnit("Blocked!", summon, 1, 90, 0, 10., 130, 190, 255, 0, true)
                dev_log("fatal-block pid=" .. (GetPlayerId(GetOwningPlayer(summon)) + 1)
                    .. " remaining=" .. guard.charges)
                return
            end
        end

        start_summon_death_cooldown(summon)
        SummonExpire(summon)
    end

    local function on_summon_death(summon)
        if summon_dismissing[summon] then return end
        start_summon_death_cooldown(summon)
    end

    local function on_character_setup(pid)
        if Hero[pid] and GetUnitTypeId(Hero[pid]) == HERO_DARK_SUMMONER then
            SummonEssence.load(pid, Profile[pid].hero.summon_essence or 0)
        end
    end

    for pid = 1, PLAYER_CAP do
        EVENT_ON_SETUP:register_action(pid, on_character_setup)
    end

    ---@class SUMMONINGIMPROVEMENT : Spell
    ---@field apply fun(pid: integer, summon: unit, str: integer, agi: integer, int: integer)
    SUMMONINGIMPROVEMENT = Spell.define("A022")
    do
        local thistype = SUMMONINGIMPROVEMENT

        local function update_level(u, level)
            SetUnitAbilityLevel(u, thistype.id, level // 10 + 1)

            for i = 1, #MILESTONES do
                local pid = GetPlayerId(GetOwningPlayer(u)) + 1
                if level == MILESTONES[i] and Profile[pid] and Profile[pid].playing then
                    refresh_all_essence_tooltips(pid)
                    message(pid, "|cffb46effYou gained a Summon Essence point.|r "
                        .. SummonEssence.unspent(pid) .. " point(s) are unallocated.")
                    break
                end
            end
        end

        local function on_cleanup(pid)
            essence_tiers[pid] = nil
            essence_roster[pid] = nil
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
        end

        function thistype.onSetup(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            essence_tiers[pid] = nil
            essence_roster[pid] = nil
            get_state(pid)
            get_roster(pid)

            EVENT_HERO_LEVEL_CHANGED:register_unit_action(u, update_level)
            EVENT_ON_CLEANUP:register_action(pid, on_cleanup)
            update_level(u, GetHeroLevel(u))
        end

        function thistype.apply(pid, summon, str, agi, int)
            local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id) - 1
            local unit = Unit[summon]

            unit.bonus_armor = unit.bonus_armor - (unit.summoning_improvement_armor or 0)
            unit.summoning_improvement_armor = 0
            unit.str = str

            if GetUnitTypeId(summon) == SUMMON_DESTROYER then
                BlzSetUnitArmor(summon, agi)
            else
                unit.agi = agi
            end
            unit.int = int

            if ablev > 0 then
                SetUnitMoveSpeed(summon, GetUnitDefaultMoveSpeed(summon) + ablev * 10.)
                unit.summoning_improvement_armor = R2I(
                    (Pow(ablev, 1.2) + (Pow(ablev, 4.) - Pow(ablev, 3.9)) / 90.) / 2. + ablev + 6.5)
                UnitAddAbility(summon, FourCC('A06Q'))
                SetUnitAbilityLevel(summon, FourCC('A06Q'), ablev)
            else
                SetUnitMoveSpeed(summon, GetUnitDefaultMoveSpeed(summon))
                UnitRemoveAbility(summon, FourCC('A06Q'))
            end

            unit.bonus_armor = unit.bonus_armor + unit.summoning_improvement_armor
        end

        function thistype:onCast()
            RecallSummons(self.pid)
        end
    end

    local function prepare_summon(pid, summon, x, y, angle)
        TimerList[pid]:stopAllTimers(summon)
        ShowUnit(summon, true)
        ReviveHero(summon, x, y, false)
        SetUnitPosition(summon, x, y)
        BlzSetUnitFacingEx(summon, angle)
        Buff.dispelAll(summon)
        TableRemove(PLAYER_SUMMONS, summon)
        PLAYER_SUMMONS[#PLAYER_SUMMONS + 1] = summon
        EVENT_ON_FATAL_DAMAGE:register_unit_action(summon, SummonEssence.onFatalDamage)
        EVENT_ON_UNIT_DEATH:register_unit_action(summon, on_summon_death)
        SetHeroLevel(summon, GetHeroLevel(Hero[pid]), false)
        summon_cooldown_started[summon] = nil

        local spell_id = SUMMON_SPELL[GetUnitTypeId(summon)]
        if spell_id then
            BlzUnitDisableAbility(Hero[pid], spell_id, true, false)
        end
    end

    local function finish_summon(pid, summon)
        SummonEssence.apply(pid, summon)
        SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
        SetUnitState(summon, UNIT_STATE_MANA, BlzGetUnitMaxMana(summon))
        SetUnitAnimation(summon, "birth")
        QueueUnitAnimation(summon, "stand")
        TimerQueue:callDelayed(2., DestroyEffect,
            AddSpecialEffectTarget("Abilities\\Spells\\Undead\\Darksummoning\\DarkSummonTarget.mdl", summon, "origin"))
    end

    ---@class SUMMONREAVER : Spell
    ---@field str function
    ---@field agi function
    ---@field int function
    SUMMONREAVER = Spell.define("A0KF")
    do
        local thistype = SUMMONREAVER
        local reavers = {} ---@type unit[]
        local CLEAVE_LENGTH = 650.
        local CLEAVE_START_WIDTH = 150.
        local CLEAVE_EFFECT = "UnbrilliantGloryWhite.mdx"
        local CLEAVE_EFFECT_FORWARD_OFFSET = 75.
        local CLEAVE_EFFECT_HEIGHT = 75.
        local CLEAVE_DAMAGE_OPTIONS = {
            attack = false,
            pre_scaled_source = true,
            suppress_source_events = true,
        }

        thistype.values = {
            str = function(pid) return 0.25 * (GetHeroInt(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            agi = function(pid) return 0.1 * GetHeroInt(Hero[pid], true) end,
            int = function(pid) return 0.2 * GetHeroInt(Hero[pid], true) end,
        }

        local tooltip = "Summons a permanent melee off-tank whose attributes scale with the Dark Summoner."
            .. "\n\n|c00ff0b11Strength:|r [str=|c00ffcc0025%|r of the Summoner's Strength and Intelligence]"
            .. "\n|c0000d23fAgility:|r [agi=|c00ffcc0010%|r of the Summoner's Intelligence]"
            .. "\n|c000080ffIntelligence:|r [int=|c00ffcc0020%|r of the Summoner's Intelligence]"
            .. "\n\n|cffffcc00Dread Cleave:|r Attacks cleave in a widening 650-range cone."
            .. "\n|cffffcc00Dreadful Wounds:|r Attacks reduce enemy damage by 5% for 4 seconds."
            .. "\n|c000080c030 second death cooldown.|r"
        set_extended_tooltips(thistype, 6, function() return tooltip end)

        local function on_cleanup(pid)
            TableRemove(PLAYER_SUMMONS, reavers[pid])
            reavers[pid] = nil
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
        end

        local function cleave(source, target, amount, amount_after_reduction, damage_type, attack_amount)
            if damage_type ~= PHYSICAL or amount_after_reduction <= 0 then return end

            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local tier = SummonEssence.getTier(pid, source)
            local frenzy = ReaverBloodFrenzyBuff:get(nil, source)
            local group = CreateGroup()
            local end_width = 225. + tier * 15.
            local cleave_damage = (attack_amount or amount.value) * (0.2 + tier * 0.06)
            local dreadful_wounds = (tier >= 4 and 0.10) or 0.05
            local dreadful_duration = 4. * LBOOST[pid]
            local healing = 0.
            local source_x, source_y = GetUnitX(source), GetUnitY(source)
            local dx, dy = GetUnitX(target) - source_x, GetUnitY(target) - source_y
            local distance = math.sqrt(dx * dx + dy * dy)
            local facing

            if frenzy then
                end_width = end_width + frenzy.width
                cleave_damage = cleave_damage * frenzy.cleave_multiplier
            end

            if distance > 0.001 then
                dx, dy = dx / distance, dy / distance
                facing = math.atan(dy, dx)
            else
                facing = GetUnitFacing(source) * bj_DEGTORAD
                dx, dy = math.cos(facing), math.sin(facing)
            end

            local length = CLEAVE_LENGTH * LBOOST[pid]
            local start_width = CLEAVE_START_WIDTH * LBOOST[pid]
            end_width = end_width * LBOOST[pid]
            local center_x = source_x + dx * length * 0.5
            local center_y = source_y + dy * length * 0.5
            local enum_radius = math.sqrt(length * length * 0.25 + end_width * end_width)

            local effect = AddSpecialEffect(CLEAVE_EFFECT,
                GetUnitX(target) + dx * CLEAVE_EFFECT_FORWARD_OFFSET,
                GetUnitY(target) + dy * CLEAVE_EFFECT_FORWARD_OFFSET)
            BlzSetSpecialEffectZ(effect, GetUnitZ(source) + CLEAVE_EFFECT_HEIGHT)
            BlzSetSpecialEffectYaw(effect, facing)
            DestroyEffect(effect)

            DreadfulWoundsDebuff:add(source, target):update(dreadful_wounds, dreadful_duration)

            MakeGroupInRange(pid, group, center_x, center_y, enum_radius, Condition(FilterEnemy))
            for enemy in each(group) do
                local enemy_dx = GetUnitX(enemy) - source_x
                local enemy_dy = GetUnitY(enemy) - source_y
                local forward = enemy_dx * dx + enemy_dy * dy
                local lateral = math.abs(enemy_dx * dy - enemy_dy * dx)
                local allowed_width = start_width

                if length > 0. then
                    allowed_width = start_width + (end_width - start_width) * forward / length
                end

                if enemy ~= target and forward >= 0. and forward <= length and lateral <= allowed_width then
                    DamageTarget(source, enemy, cleave_damage, ATTACK_TYPE_NORMAL, PHYSICAL,
                        "Dread Cleave", CLEAVE_DAMAGE_OPTIONS)
                    DreadfulWoundsDebuff:add(source, enemy):update(dreadful_wounds, dreadful_duration)
                    if tier >= 5 then
                        healing = healing + cleave_damage * 0.1
                    end
                end
            end
            DestroyGroup(group)

            if healing > 0. then
                HP(source, source, math.min(healing, BlzGetUnitMaxHP(source) * 0.03), "Endless Carnage")
            end
        end

        function thistype:onCast()
            if not SummonEssence.reserve(self.pid, SUMMON_REAVER) then
                BlzEndUnitAbilityCooldown(self.caster, thistype.id)
                return
            end

            local angle = GetUnitFacing(self.caster)
            local x = self.x + 150. * math.cos(bj_DEGTORAD * angle)
            local y = self.y + 150. * math.sin(bj_DEGTORAD * angle)
            local summon = reavers[self.pid]

            if not summon then
                summon = CreateUnit(Player(self.pid - 1), SUMMON_REAVER, x, y, angle)
                reavers[self.pid] = summon
            end

            prepare_summon(self.pid, summon, x, y, angle)
            SetUnitVertexColor(summon, 200, 200, 200, 255)
            SUMMONINGIMPROVEMENT.apply(self.pid, summon,
                R2I(self.str * BOOST[self.pid]), R2I(self.agi * BOOST[self.pid]), R2I(self.int * BOOST[self.pid]))
            Unit[summon].regen_max = 0.02 + 0.0005 * GetUnitAbilityLevel(summon, FourCC('A06Q'))
            EVENT_ON_HIT_AFTER_REDUCTIONS:register_unit_action(summon, cleave)
            EVENT_ON_CLEANUP:register_action(self.pid, on_cleanup)
            finish_summon(self.pid, summon)
        end
    end

    SUMMONDEMONHOUND = SUMMONREAVER

    ---@class SUMMONMEATGOLEM : Spell
    ---@field str function
    ---@field agi function
    SUMMONMEATGOLEM = Spell.define("A0KH")
    do
        local thistype = SUMMONMEATGOLEM
        local golems = {} ---@type unit[]

        thistype.values = {
            str = function(pid) return 0.4 * (GetHeroInt(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            agi = function(pid) return 0.6 * GetHeroInt(Hero[pid], true) end,
        }

        local tooltip = "Summons a permanent melee tank whose attributes scale with the Dark Summoner."
            .. "\n\n|c00ff0b11Strength:|r [str=|c00ffcc0040%|r of the Summoner's Strength and Intelligence]"
            .. "\n|c0000d23fAgility:|r [agi=|c00ffcc0060%|r of the Summoner's Intelligence]"
            .. "\n\n|cffffcc00Regeneration:|r Gains half the Max Health regeneration granted by Summoning Improvement"
            .. "\n|c000080c030 second death cooldown.|r"
        set_extended_tooltips(thistype, 1, function() return tooltip end)

        local function on_cleanup(pid)
            TableRemove(PLAYER_SUMMONS, golems[pid])
            golems[pid] = nil
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
        end

        function thistype:onCast()
            if not SummonEssence.reserve(self.pid, SUMMON_GOLEM) then
                BlzEndUnitAbilityCooldown(self.caster, thistype.id)
                return
            end

            local angle = GetUnitFacing(self.caster)
            local x = self.x + 150. * math.cos(bj_DEGTORAD * angle)
            local y = self.y + 150. * math.sin(bj_DEGTORAD * angle)
            local summon = golems[self.pid]

            if not summon then
                summon = CreateUnit(Player(self.pid - 1), SUMMON_GOLEM, x, y, angle)
                golems[self.pid] = summon
            end

            prepare_summon(self.pid, summon, x, y, angle)
            SUMMONINGIMPROVEMENT.apply(self.pid, summon,
                R2I(self.str * BOOST[self.pid]), R2I(self.agi * BOOST[self.pid]), 0)
            Unit[summon].regen_max = 0.02 + 0.00025 * GetUnitAbilityLevel(summon, FourCC('A06Q'))
            EVENT_ON_CLEANUP:register_action(self.pid, on_cleanup)
            finish_summon(self.pid, summon)
        end
    end

    ---@class SUMMONDESTROYER : Spell
    ---@field str function
    ---@field agi function
    ---@field int function
    SUMMONDESTROYER = Spell.define("A0KG")
    do
        local thistype = SUMMONDESTROYER
        local destroyers = {} ---@type unit[]
        local frenzy = setmetatable({}, { __mode = 'k' })
        local FRENZY_AGILITY_PER_SECOND = 50
        local FRENZY_MAX_AGILITY = 400
        local FRENZY_POSITION_TOLERANCE_SQUARED = 32. * 32.

        thistype.values = {
            str = function(pid) return 0.0666 * (GetHeroInt(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            agi = function(pid) return 0.005 * GetHeroInt(Hero[pid], true) end,
            int = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id)
                return 0.5 * GetHeroInt(Hero[pid], true) * ablev end,
        }

        set_extended_tooltips(thistype, 5, function(level)
            return "Summons a permanent ranged attacker whose attributes scale with the Dark Summoner."
                .. "\n\n|c00ff0b11Strength:|r [str=|c00ffcc006.66%|r of the Summoner's Strength and Intelligence]"
                .. "\n|cff9B9BEDArmor:|r [agi=|c00ffcc000.5%|r of the Summoner's Intelligence]"
                .. "\n|c000080ffIntelligence:|r [int=|c00ffcc00" .. (level * 50)
                .. "%|r of the Summoner's Intelligence]"
                .. "\n\n|cffffcc00Annihilation:|r Attacks have a chance to deal bonus Magic damage based on Intelligence."
                .. "\n|c000080c030 second death cooldown.|r"
        end)

        local function on_cleanup(pid)
            TableRemove(PLAYER_SUMMONS, destroyers[pid])
            destroyers[pid] = nil
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
        end

        local function set_frenzy_agility(summon, state, agility)
            local unit = Unit[summon]
            unit.bonus_agi = unit.bonus_agi - state.agility
            state.agility = agility
            unit.bonus_agi = unit.bonus_agi + state.agility
        end

        local function frenzy_moved(summon, state)
            local dx = GetUnitX(summon) - state.x
            local dy = GetUnitY(summon) - state.y
            return dx * dx + dy * dy > FRENZY_POSITION_TOLERANCE_SQUARED
        end

        local function frenzy_tick(summon)
            local state = frenzy[summon]
            if not state then return end

            if not UnitAlive(summon) or IsUnitHidden(summon) or not UnitAlive(state.target)
                or frenzy_moved(summon, state)
            then
                set_frenzy_agility(summon, state, 0)
                frenzy[summon] = nil
                return
            end

            if state.attacks > 0 then
                set_frenzy_agility(summon, state,
                    math.min(FRENZY_MAX_AGILITY, state.agility + FRENZY_AGILITY_PER_SECOND))
                state.attacks = 0
                state.idle_seconds = 0
            else
                state.idle_seconds = state.idle_seconds + 1
                if state.idle_seconds > math.max(1., Unit[summon].bat + 0.25) then
                    set_frenzy_agility(summon, state, 0)
                    frenzy[summon] = nil
                    return
                end
            end

            state.callback = TimerQueue:callDelayed(1., frenzy_tick, summon)
        end

        local function reset_frenzy(summon)
            local state = frenzy[summon]
            if not state then return end

            if state.callback then
                TimerQueue:disableCallback(state.callback)
            end
            set_frenzy_agility(summon, state, 0)
            frenzy[summon] = nil
        end

        local function on_attack(source, target)
            local state = frenzy[source]
            if state and (state.target ~= target or frenzy_moved(source, state)) then
                reset_frenzy(source)
                state = nil
            end

            if not state then
                state = {
                    target = target,
                    attacks = 0,
                    agility = 0,
                    idle_seconds = 0,
                    x = GetUnitX(source),
                    y = GetUnitY(source),
                }
                frenzy[source] = state
                state.callback = TimerQueue:callDelayed(1., frenzy_tick, source)
            end

            state.attacks = state.attacks + 1
            state.idle_seconds = 0
        end

        local function annihilation(source, target)
            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local tier = SummonEssence.getTier(pid, source)

            if GetRandomInt(0, 99) < 10 + tier * 2 then
                DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilSpecialArt.mdl",
                    GetUnitX(target), GetUnitY(target)))
                DamageTarget(source, target, GetHeroInt(source, true) * (1. + tier * 0.2) * LBOOST[pid],
                    ATTACK_TYPE_NORMAL, MAGIC, "Annihilation Strike")
            end
        end

        function thistype:onCast()
            if not SummonEssence.reserve(self.pid, SUMMON_DESTROYER) then
                BlzEndUnitAbilityCooldown(self.caster, thistype.id)
                return
            end

            local angle = GetUnitFacing(self.caster) + 180.
            local x = self.x + 150. * math.cos(bj_DEGTORAD * angle)
            local y = self.y + 150. * math.sin(bj_DEGTORAD * angle)
            local summon = destroyers[self.pid]

            if not summon then
                summon = CreateUnit(Player(self.pid - 1), SUMMON_DESTROYER, x, y, angle + 180.)
                destroyers[self.pid] = summon
            end

            prepare_summon(self.pid, summon, x, y, angle + 180.)
            reset_frenzy(summon)
            UnitAddAbility(summon, FourCC('A06J'))
            UnitMakeAbilityPermanent(summon, true, FourCC('A06J'))
            SetUnitAbilityLevel(summon, FourCC('A06J'), 1)
            SUMMONINGIMPROVEMENT.apply(self.pid, summon,
                R2I(self.str * BOOST[self.pid]), R2I(self.agi * BOOST[self.pid]), R2I(self.int * BOOST[self.pid]))
            Unit[summon].regen_max = 0.02 + 0.0005 * GetUnitAbilityLevel(summon, FourCC('A06Q'))
            EVENT_ON_HIT:register_unit_action(summon, annihilation)
            EVENT_ON_ATTACK:register_unit_action(summon, on_attack)
            EVENT_ON_CLEANUP:register_action(self.pid, on_cleanup)
            finish_summon(self.pid, summon)
        end
    end

    ---@class DEMONICSACRIFICE : Spell
    DEMONICSACRIFICE = Spell.define("A0K1")
    do
        local thistype = DEMONICSACRIFICE
        local MAX_DEBT = 8
        local HEAL_BY_LEVEL = { 1.5, 1.6, 1.7, 1.8, 1.9, 2. }
        local AOE_BY_LEVEL = { 1000., 1100., 1200., 1300., 1400., 1500. }

        local function ability_level(caster)
            return math.max(1, math.min(6, GetUnitAbilityLevel(caster, thistype.id)))
        end

        local function sacrifice_cost_percent(caster)
            local debt_buff = BloodDebtBuff:get(nil, caster)
            local debt = (debt_buff and debt_buff.charges) or 0
            return math.min(100., 20. + math.min(MAX_DEBT, debt) * 10.)
        end

        local function heal_multiplier(caster)
            return HEAL_BY_LEVEL[ability_level(caster)]
        end

        thistype.values = {
            heal = function(_, caster)
                local payment = math.min(GetWidgetLife(caster),
                    BlzGetUnitMaxHP(caster) * sacrifice_cost_percent(caster) * 0.01)
                return payment * heal_multiplier(caster)
            end,
            aoe = function(_, caster)
                return AOE_BY_LEVEL[ability_level(caster)]
            end,
            dur = 12.,
        }

        for level = 1, 6 do
            Spell.TOOLTIPS[thistype.id][level] = string.gsub(
                Spell.TOOLTIPS[thistype.id][level], "%]x", "x]")
        end

        local function collect_summons(pid, caster, radius)
            local result = {}
            local x, y = GetUnitX(caster), GetUnitY(caster)

            for i = 1, #PLAYER_SUMMONS do
                local summon = PLAYER_SUMMONS[i]
                if is_valid_summon(pid, summon)
                    and IsUnitInRangeXY(summon, x, y, radius) then
                    result[#result + 1] = summon
                end
            end

            return result
        end

        local function fatal_blocks(tier, cost_percent)
            if tier < 3 then
                return 0
            elseif tier == 3 then
                return 1
            elseif tier == 4 then
                return (cost_percent >= 60. and 2) or 1
            elseif cost_percent >= 80. then
                return 3
            elseif cost_percent >= 40. then
                return 2
            end
            return 1
        end

        local function apply_specialization(caster, summon, tier, cost_percent, dur)
            if tier < 3 then return end

            local uid = GetUnitTypeId(summon)
            if uid == SUMMON_REAVER then
                ReaverBloodFrenzyBuff:add(caster, summon):update(cost_percent, tier, dur)
            elseif uid == SUMMON_GOLEM then
                if tier >= 5 then
                    GolemBloodforgedBuff:add(caster, summon):duration(dur)
                end
            elseif uid == SUMMON_DESTROYER then
                local charges = fatal_blocks(tier, cost_percent)
                DestroyerContinuityBuff:add(caster, summon):grant(charges, dur)
            end
        end

        local sacrifice_missile_template = {
            selfInteractions = {
                CAT_MoveArcedHoming,
                CAT_Orient3D,
                CAT_Decay,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            identifier = "missile",
            collisionRadius = 10.,
            onlyTarget = true,
            collideZ = true,
            visualZ = 70.,
            speed = 900.,
            arc = 0.15,
            lifetime = 5.,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, summon)
                if not is_valid_summon(self.pid, summon) then return end

                HP(self.source, summon, self.healing, thistype.tag)
                apply_specialization(self.source, summon, self.tier, self.cost_percent, self.duration)
                DestroyEffect(AddSpecialEffectTarget(
                    "Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", summon, "origin"))
            end,
        }
        sacrifice_missile_template.__index = sacrifice_missile_template

        local function launch_sacrifice_missile(caster, summon, pid, healing, tier, cost_percent, dur)
            local missile = setmetatable({}, sacrifice_missile_template)
            missile.x = GetUnitX(caster)
            missile.y = GetUnitY(caster)
            missile.z = GetUnitZ(caster)
            missile.visual = AddSpecialEffect(
                "Abilities\\Spells\\Undead\\DeathCoil\\DeathCoilMissile.mdl", missile.x, missile.y)
            missile.source = caster
            missile.target = summon
            missile.owner = Player(pid - 1)
            missile.pid = pid
            missile.healing = healing
            missile.tier = tier
            missile.cost_percent = cost_percent
            missile.duration = dur

            ALICE_Create(missile)
        end

        local function cast_radius(pid, caster)
            return AOE_BY_LEVEL[ability_level(caster)] * LBOOST[pid]
        end

        function thistype.preCast(pid, tpid, caster)
            if #collect_summons(pid, caster, cast_radius(pid, caster)) == 0 then
                message(pid, "|cffff0000Demonic Sacrifice requires an active summon within range.|r")
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
            end
        end

        function thistype:onCast()
            local summons = collect_summons(self.pid, self.caster, self.aoe * LBOOST[self.pid])
            if #summons == 0 then
                BlzEndUnitAbilityCooldown(self.caster, thistype.id)
                return
            end

            local debt_buff = BloodDebtBuff:get(nil, self.caster)
            local debt = (debt_buff and debt_buff.charges) or 0
            local cost_percent = sacrifice_cost_percent(self.caster)
            local current_life = GetWidgetLife(self.caster)
            local payment = math.min(current_life, BlzGetUnitMaxHP(self.caster) * cost_percent * 0.01)
            local dur = self.dur * LBOOST[self.pid]
            local lethal = payment >= current_life

            debt_buff = debt_buff or BloodDebtBuff:add(self.caster, self.caster)
            debt_buff:addStack()

            if lethal then
                -- Create every outgoing projectile before Warcraft runs the
                -- caster's death callbacks. The missiles then resolve independently.
                SetWidgetLife(self.caster, 1.)
            else
                SetWidgetLife(self.caster, current_life - payment)
            end

            for i = 1, #summons do
                local summon = summons[i]
                local tier = SummonEssence.getTier(self.pid, summon)
                local healing_multiplier = heal_multiplier(self.caster) * BOOST[self.pid]

                if GetUnitTypeId(summon) == SUMMON_GOLEM and tier >= 3 then
                    healing_multiplier = healing_multiplier * 2.
                end

                launch_sacrifice_missile(
                    self.caster, summon, self.pid, payment * healing_multiplier, tier, cost_percent, dur)
            end

            if lethal then
                KillUnit(self.caster)
            end

            dev_log(string.format(
                "sacrifice pid=%d level=%d debt=%d cost=%.0f paid=%.0f targets=%d radius=%.0f duration=%.2f lethal=%s",
                self.pid, self.ablev, debt, cost_percent, payment, #summons,
                self.aoe * LBOOST[self.pid], dur, tostring(lethal)))
        end
    end
end, Debug and Debug.getLine())
