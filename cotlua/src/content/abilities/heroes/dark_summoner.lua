OnInit.final("DarkSummonerSpells", function(Require)
    Require('Spells')
    Require('SpellTools')
    Require('Events')
    Require('Profile')
    Require('SummonAbilities')

    local MAX_TIER = 5
    local ESSENCE_INFO = FourCC('A063')
    local MILESTONES = { 1, 20, 50, 100, 150, 200, 300, 400, 500 }
    local SUMMON_TYPES = { SUMMON_REAVER, SUMMON_GOLEM, SUMMON_DESTROYER }
    local IS_SUMMON_TYPE = {
        [SUMMON_REAVER] = true,
        [SUMMON_GOLEM] = true,
        [SUMMON_DESTROYER] = true,
    }
    local essence_tiers = {} ---@type table<integer, table<integer, integer>>

    local TIER_COMPLETE = "|cff66ff66"
    local TIER_CURRENT = "|cffffcc00"
    local TIER_LOCKED = "|cff777777"
    local COLOR_END = "|r"

    local ESSENCE_TIER_TEXT = {
        [SUMMON_REAVER] = {
            "Tier 1 - +15% STR, +10% AGI/INT, +5 Armor; Cleave: 26% damage / 240 radius.",
            "Tier 2 - +30% STR, +20% AGI/INT, +10 Armor; Cleave: 32% damage / 255 radius.",
            "Tier 3 - +45% STR, +30% AGI/INT, +15 Armor; Cleave: 38% damage / 270 radius.",
            "Tier 4 - +60% STR, +40% AGI/INT, +20 Armor; Cleave: 44% damage / 285 radius.",
            "Tier 5 - +75% STR, +50% AGI/INT, +25 Armor; Cleave: 50% damage / 300 radius.",
        },
        [SUMMON_GOLEM] = {
            "Tier 1 - +20% STR, +10% AGI, and +6 Armor.",
            "Tier 2 - +40% STR, +20% AGI, +12 Armor; unlocks Taunt.",
            "Tier 3 - +60% STR, +30% AGI, +18 Armor; unlocks Thunder Clap.",
            "Tier 4 - +80% STR, +40% AGI, +24 Armor; unlocks Magnetic Force.",
            "Tier 5 - +100% STR, +50% AGI, +30 Armor; gains an ascended appearance.",
        },
        [SUMMON_DESTROYER] = {
            "Tier 1 - +10% STR/INT, +50 AGI, +3 Armor; Annihilation: 12% chance / 1.2x INT.",
            "Tier 2 - +20% STR/INT, +100 AGI, +6 Armor; Blink; Annihilation: 14% / 1.4x INT.",
            "Tier 3 - +30% STR/INT, +150 AGI, +9 Armor; +25% Crit / +200% Crit Damage; Annihilation: 16% / 1.6x INT.",
            "Tier 4 - +40% STR/INT, +200 AGI, +12 Armor; Perfected Annihilation: 18% / 1.8x INT.",
            "Tier 5 - +50% STR, +75% INT, +250 AGI, +15 Armor; Annihilation: 20% / 2x INT.",
        },
    }

    ---@class SummonEssence
    ---@field available fun(pid: integer): integer
    ---@field unspent fun(pid: integer): integer
    ---@field getTier fun(pid: integer, summon: unit|integer): integer
    ---@field infuse fun(pid: integer, summon: unit): boolean
    ---@field reclaim fun(pid: integer, summon: unit): boolean
    ---@field apply fun(pid: integer, summon: unit)
    ---@field refreshTooltips fun(pid: integer)
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

    function SummonEssence.available(pid)
        local hero = Hero[pid]
        local level = hero and GetHeroLevel(hero) or 1
        local points = 0

        for i = 1, #MILESTONES do
            if level < MILESTONES[i] then break end
            points = points + 1
        end
        return points
    end

    function SummonEssence.unspent(pid)
        local state = get_state(pid)
        local spent = state[SUMMON_REAVER] + state[SUMMON_GOLEM] + state[SUMMON_DESTROYER]
        return math.max(0, SummonEssence.available(pid) - spent)
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
            .. "|n|cffb46effUnspent Essence: " .. SummonEssence.unspent(pid) .. COLOR_END .. "|n|n"

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
        unit.bonus_armor = unit.bonus_armor - (unit.essence_armor or 0)
        unit.cc_flat = unit.cc_flat - (unit.essence_cc or 0)
        unit.cd_flat = unit.cd_flat - (unit.essence_cd or 0)

        unit.essence_str = 0
        unit.essence_agi = 0
        unit.essence_int = 0
        unit.essence_armor = 0
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
        UnitDisableAbility(summon, INFUSE_ESSENCE.id, false)
        UnitDisableAbility(summon, RECLAIM_ESSENCE.id, false)
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

        unit.essence_str = R2I(unit.str * 0.1 * tier)
        unit.essence_agi = R2I(unit.agi * 0.1 * tier)
        unit.essence_int = R2I(unit.int * 0.1 * tier)
        unit.essence_armor = tier * 3

        if uid == SUMMON_REAVER then
            unit.essence_str = unit.essence_str + R2I(unit.str * 0.05 * tier)
            unit.essence_armor = unit.essence_armor + tier * 2
            SetUnitScale(summon, 1. + tier * 0.04, 1. + tier * 0.04, 1. + tier * 0.04)
            BlzSetHeroProperName(summon, "Dread Reaver (Tier " .. tier .. ")")
        elseif uid == SUMMON_GOLEM then
            UnitRemoveAbility(summon, FourCC('A0KI'))
            UnitRemoveAbility(summon, THUNDER_CLAP_GOLEM.id)
            UnitRemoveAbility(summon, MAGNETIC_FORCE.id)
            UnitRemoveAbility(summon, FourCC('A0IQ'))

            unit.essence_str = unit.essence_str + R2I(unit.str * 0.1 * tier)
            unit.essence_armor = unit.essence_armor + tier * 3
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

            unit.essence_agi = unit.essence_agi + tier * 50
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
            if tier >= 5 then
                unit.essence_int = unit.essence_int + R2I(unit.int * 0.25)
            end
            BlzSetHeroProperName(summon, "Destroyer (Tier " .. tier .. ")")
        end

        unit.bonus_str = unit.bonus_str + unit.essence_str
        unit.bonus_agi = unit.bonus_agi + unit.essence_agi
        unit.bonus_int = unit.bonus_int + unit.essence_int
        unit.bonus_armor = unit.bonus_armor + unit.essence_armor
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
            message(pid, "|cffffcc00That summon has no Essence to reclaim.|r")
            return false
        end

        state[uid] = state[uid] - 1
        persist(pid)
        SummonEssence.apply(pid, summon)
        refresh_all_essence_tooltips(pid)
        DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Human\\DispelMagic\\DispelMagicTarget.mdl", summon, "origin"))
        message(pid, "|cffb46effEssence reclaimed.|r " .. SummonEssence.unspent(pid) .. " point(s) are available.")
        return true
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
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
        end

        function thistype.onSetup(u)
            local pid = GetPlayerId(GetOwningPlayer(u)) + 1
            essence_tiers[pid] = nil
            get_state(pid)

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
        EVENT_ON_FATAL_DAMAGE:register_unit_action(summon, SummonExpire)
        SetHeroLevel(summon, GetHeroLevel(Hero[pid]), false)
    end

    local function finish_summon(pid, summon)
        SummonEssence.apply(pid, summon)
        SetWidgetLife(summon, BlzGetUnitMaxHP(summon))
        SetUnitState(summon, UNIT_STATE_MANA, BlzGetUnitMaxMana(summon))
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

        thistype.values = {
            str = function(pid) return 0.25 * (GetHeroInt(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            agi = function(pid) return 0.1 * GetHeroInt(Hero[pid], true) end,
            int = function(pid) return 0.2 * GetHeroInt(Hero[pid], true) end,
        }

        local function on_cleanup(pid)
            TableRemove(PLAYER_SUMMONS, reavers[pid])
            reavers[pid] = nil
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
        end

        local function cleave(source, target, amount, amount_after_reduction, damage_type)
            if damage_type ~= PHYSICAL or amount_after_reduction <= 0 then return end

            local pid = GetPlayerId(GetOwningPlayer(source)) + 1
            local tier = SummonEssence.getTier(pid, source)
            local group = CreateGroup()
            local radius = (225. + tier * 15.) * LBOOST[pid]
            local cleave_damage = amount_after_reduction * (0.2 + tier * 0.06)

            MakeGroupInRange(pid, group, GetUnitX(target), GetUnitY(target), radius, Condition(FilterEnemy))
            for enemy in each(group) do
                if enemy ~= target then
                    DamageTarget(source, enemy, cleave_damage, ATTACK_TYPE_NORMAL, PURE, "Dread Cleave")
                end
            end
            DestroyGroup(group)
        end

        function thistype:onCast()
            local angle = GetUnitFacing(self.caster)
            local x = self.x + 150. * math.cos(bj_DEGTORAD * angle)
            local y = self.y + 150. * math.sin(bj_DEGTORAD * angle)
            local summon = reavers[self.pid]

            if not summon then
                summon = CreateUnit(Player(self.pid - 1), SUMMON_REAVER, x, y, angle)
                reavers[self.pid] = summon
            end

            prepare_summon(self.pid, summon, x, y, angle)
            SetUnitVertexColor(summon, 200, 120, 120, 255)
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

        local function on_cleanup(pid)
            TableRemove(PLAYER_SUMMONS, golems[pid])
            golems[pid] = nil
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
        end

        function thistype:onCast()
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

        thistype.values = {
            str = function(pid) return 0.0666 * (GetHeroInt(Hero[pid], true) + GetHeroStr(Hero[pid], true)) end,
            agi = function(pid) return 0.005 * GetHeroInt(Hero[pid], true) end,
            int = function(pid) local ablev = GetUnitAbilityLevel(Hero[pid], thistype.id)
                return 0.5 * GetHeroInt(Hero[pid], true) * ablev end,
        }

        local function on_cleanup(pid)
            TableRemove(PLAYER_SUMMONS, destroyers[pid])
            destroyers[pid] = nil
            EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
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
            local angle = GetUnitFacing(self.caster) + 180.
            local x = self.x + 150. * math.cos(bj_DEGTORAD * angle)
            local y = self.y + 150. * math.sin(bj_DEGTORAD * angle)
            local summon = destroyers[self.pid]

            if not summon then
                summon = CreateUnit(Player(self.pid - 1), SUMMON_DESTROYER, x, y, angle + 180.)
                destroyers[self.pid] = summon
            end

            prepare_summon(self.pid, summon, x, y, angle + 180.)
            SUMMONINGIMPROVEMENT.apply(self.pid, summon,
                R2I(self.str * BOOST[self.pid]), R2I(self.agi * BOOST[self.pid]), R2I(self.int * BOOST[self.pid]))
            Unit[summon].regen_max = 0.02 + 0.0005 * GetUnitAbilityLevel(summon, FourCC('A06Q'))
            EVENT_ON_HIT:register_unit_action(summon, annihilation)
            EVENT_ON_CLEANUP:register_action(self.pid, on_cleanup)
            finish_summon(self.pid, summon)
        end
    end

    ---@class DEMONICSACRIFICE : Spell
    DEMONICSACRIFICE = Spell.define("A0K1")
    do
        local thistype = DEMONICSACRIFICE

        local function can_sacrifice(pid, caster, target, show_message)
            local valid = is_valid_summon(pid, target)
                and GetWidgetLife(target) < BlzGetUnitMaxHP(target)
                and GetWidgetLife(caster) > 1.

            if not valid and show_message then
                DisplayTextToPlayer(Player(pid - 1), 0, 0,
                    "|cffff0000Target a damaged active summon while you have health to sacrifice.|r")
            end
            return valid
        end

        function thistype.preCast(pid, tpid, caster, target)
            if not can_sacrifice(pid, caster, target, true) then
                IssueImmediateOrderById(caster, ORDER_ID_STOP)
            end
        end

        function thistype:onCast()
            if not can_sacrifice(self.pid, self.caster, self.target, false) then return end

            local current_life = GetWidgetLife(self.caster)
            local missing_life = BlzGetUnitMaxHP(self.target) - GetWidgetLife(self.target)
            local payment = math.min(
                BlzGetUnitMaxHP(self.caster) * 0.15,
                current_life - 1.,
                missing_life / 2.)

            if payment <= 0. then return end

            SetWidgetLife(self.caster, current_life - payment)
            HP(self.caster, self.target, payment * 2., thistype.tag)
            DestroyEffect(AddSpecialEffectTarget(
                "Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", self.target, "origin"))
        end
    end
end, Debug and Debug.getLine())
