OnInit.final("Colosseum", function(Require)
    Require('MainMap')
    Require('BossSchema')
    Require('ItemEventRegistry')
    Require('ALICE')
    Require('SpellTools')
    Require('Currency')

    local GetRectCenterXY = function(whichRect)
        return { x = GetRectCenterX(whichRect), y = GetRectCenterY(whichRect) }
    end
    local valid_damage_target = VALID_DAMAGE_TARGET
    local ARENA_RADIUS = 1500.
    local ticket_id = 'I008'
    local unit_id = FourCC('n002')
    local boss_id = FourCC('N003')
    local colo_x = 21746
    local colo_y = -4347
    local random = math.random
    local colo_spawn = {
        GetRectCenterXY(gg_rct_Colosseum_Monster_Spawn),
        GetRectCenterXY(gg_rct_Colosseum_Monster_Spawn_2),
        GetRectCenterXY(gg_rct_Colosseum_Monster_Spawn_3),
    }
    local Encounter, Augment, BossAffix

    -- Colosseum balance rationale:
    -- This is a paced, 20-wave reward mode rather than the continuous swarm
    -- pressure planned for Struggle. Normal waves use curated formations; the
    -- inverse unit-count multiplier keeps their total baseline health and damage
    -- comparable while role modifiers make hordes, hunters, and bruisers play
    -- differently. Enemy stats snapshot the entrants' average level and stats.
    -- Extra players add 65% health and 10% damage each, enough to require group
    -- effort without repeating the old superlinear party scaling. Every fifth
    -- wave is a boss, where affixes and avoidable mechanics supply the difficulty.
    -- Coins are paid even on failure, so each is worth 25,000 + 8 * level^2 gold:
    -- about 1.305 platinum at level 400 and 2.025 platinum at level 500. A typical
    -- full level-500 run therefore remains below the guaranteed Naga dungeon gold
    -- reward, while an early failure cannot generate hundreds of platinum. Honor
    -- is deliberately separate, character-owned progression awarded only on clear.

    local function colo_get_random_location(inward_offset)
        inward_offset = inward_offset or 0
        local x, y = colo_x + math.random(- ARENA_RADIUS + inward_offset, ARENA_RADIUS - inward_offset), colo_y + math.random(- ARENA_RADIUS + inward_offset, ARENA_RADIUS - inward_offset)

        return x, y
    end

    local melee_skins = {
        "uske",
        "ugho",
        "nmpe",
        "nban",
        "nsty",
        "nwlt",
    }
    local elite_skins = {
        "e000",
        "Nplh",
        "Nfir",
        "Nbst",
        "Nalc",
        "Npbm",
        "Edem",
    }

    local bosses
    local players ---@type integer[]
    local colo_enemies = {} ---@type unit[]
    local wave = 1
    local unit_count = 0
    local is_entry_open = false
    local colo_active = false
    local start_timer ---@type integer?
    local augment_pick_timer ---@type integer?
    local timer_frame ---@type TimerFrame?

    -- formula data
    local total_level = 0
    local average_level = 0
    local party_health_mult = 1
    local party_damage_mult = 1
    local num_spawned = 0
    local base_coins = 0
    local bonus_coins = __jarray(0) ---@type integer[]
    local bonus_drop_chance = __jarray(0) ---@type number[]
    local rewarded = {} ---@type boolean[]
    local advance_wave, end_colosseum, colo_cleanup, colo_on_death ---@type function

    -- constants
    local MAX_WAVES = 20
    local BASE_DAMAGE = 5
    local BASE_HP = 50
    local BASE_ARMOR = 0.75
    local GOLD_DROP_CHANCE = 10

    local BOSS_HP = 500
    local BOSS_DAMAGE = 50
    local BOSS_ARMOR = 2
    local COIN_BASE_GOLD = 25000
    local COIN_LEVEL_SCALING = 8

    -- unit stats
    local stat_hp = 0
    local stat_dmg = 0
    local stat_armor = 0

    local coin_effect

    local wave_formations = {
        {
            name = "Horde",
            roles = {
                { count_min = 8, count_max = 10, hp = 0.75, damage = 0.8, armor = 0.8, speed = 0.08 },
            },
        },
        {
            name = "Hunters",
            roles = {
                { count_min = 5, count_max = 7, hp = 0.9, damage = 1.1, armor = 0.9, speed = 0.2 },
            },
        },
        {
            name = "Bruisers",
            roles = {
                { count_min = 2, count_max = 3, hp = 1.8, damage = 1.35, armor = 1.5, speed = -0.05 },
            },
        },
        {
            name = "Vanguard",
            roles = {
                { count_min = 2, count_max = 2, hp = 1.6, damage = 0.9, armor = 1.5, speed = -0.05 },
                { count_min = 4, count_max = 5, hp = 0.7, damage = 1.2, armor = 0.75, speed = 0.15 },
            },
        },
    }

    do
        local MODEL = "Objects\\InventoryItems\\PotofGold\\PotofGold.mdl"

        local coin_template = {
            interactions = {
                self = {
                    --CAT_OrientProjectile,
                    CAT_MoveBallistic,
                    CAT_CheckTerrainCollision,
                }
            },
            identifier = "missile",
            speed = 900,
            collisionRadius = 0.1,
            destroy = function(self)
                DestroyEffect(self.visual)
            end,
        }
        coin_template.__index = coin_template

        -- gold reward effect
        coin_effect = function(u, num_coins)
            local x = GetUnitX(u)
            local y = GetUnitY(u)
            local z = BlzGetUnitZ(u)
            num_coins = num_coins or random(3, 4)

            for _ = 1, num_coins do
                local coin = setmetatable({}, coin_template)
                coin.visual = AddSpecialEffect(MODEL, x, y)
                BlzSetSpecialEffectScale(coin.visual, 1.5)
                BlzSetSpecialEffectTimeScale(coin.visual, 1.5)
                coin.x = x
                coin.y = y
                coin.z = z
                local dist = random(200, 300)
                local angle = GetRandomReal(0, 2 * bj_PI)
                local targetX = x + dist * math.cos(angle)
                local targetY = y + dist * math.sin(angle)
                local vx, vy, vz = CAT_GetBallisticLaunchSpeedFromAngle(x, y, z, targetX, targetY, GetTerrainZ(targetX, targetY), 70. * bj_DEGTORAD)
                coin.vx = vx * 0.95
                coin.vy = vy * 0.95
                coin.vz = vz * 0.95

                ALICE_Create(coin)
            end
        end
    end

    BossAffix = {}
    do
        local MARKED_FOR_DESTRUCTION = FourCC('A01V')
        local NOVA = FourCC('A01X')
        local UNSTABLE_GROUND = FourCC('A020')
        local RAGE = FourCC('A02E')
        local list = {}
        local active = {}
        local callbacks = {}
        local indicators = {}
        local boss
        local generation = 0

        local function schedule(delay, callback, ...)
            local id = TimerQueue:callDelayed(delay, callback, generation, ...)
            callbacks[#callbacks + 1] = id
            return id
        end

        local function remove_indicator(indicator)
            if indicator.active then
                indicator.active = false
                DestroyEffect(indicator.effect)
            end
        end

        local function damage_area(x, y, radius, health_fraction, tag)
            if not boss then
                return
            end

            for _, pid in ipairs(players) do
                local hero = Hero[pid]
                if hero and UnitAlive(hero) and IsUnitInRangeXY(hero, x, y, radius) then
                    DamageTarget(boss, hero, BlzGetUnitMaxHP(hero) * health_fraction, ATTACK_TYPE_NORMAL, MAGIC, tag)
                end
            end
        end

        local function detonate(expected_generation, indicator, radius, health_fraction, tag, impact_model, impact_scale)
            if expected_generation ~= generation or not indicator.active then
                return
            end

            remove_indicator(indicator)
            local effect = AddSpecialEffect(impact_model, indicator.x, indicator.y)
            BlzSetSpecialEffectScale(effect, impact_scale or math.max(0.75, radius / 250.))
            DestroyEffect(effect)
            damage_area(indicator.x, indicator.y, radius, health_fraction, tag)
        end

        local function warn_area(x, y, radius, delay, health_fraction, tag, impact_model, impact_scale)
            local indicator = {
                active = true,
                effect = AddSpecialEffect("Indicators\\circle.mdl", x, y),
                x = x,
                y = y,
            }
            BlzSetSpecialEffectScale(indicator.effect, radius / 500.)
            indicators[#indicators + 1] = indicator
            schedule(delay, detonate, indicator, radius, health_fraction, tag, impact_model, impact_scale)
        end

        function BossAffix.create(ability_id, name, start, stop)
            list[#list + 1] = {
                ability_id = ability_id,
                name = name,
                start = start,
                stop = stop,
            }
        end

        function BossAffix.stop()
            generation = generation + 1

            for _, id in ipairs(callbacks) do
                TimerQueue:disableCallback(id)
            end
            callbacks = {}

            for _, indicator in ipairs(indicators) do
                remove_indicator(indicator)
            end
            indicators = {}

            for _, affix in ipairs(active) do
                if affix.stop then
                    affix.stop()
                end
                if boss then
                    UnitRemoveAbility(boss, affix.ability_id)
                end
            end
            active = {}
            boss = nil
        end

        function BossAffix.start(which_boss)
            BossAffix.stop()
            boss = which_boss

            local count = wave >= 10 and 2 or 1
            active = pickN(count, list)
            local names = {}

            for _, affix in ipairs(active) do
                UnitAddAbility(boss, affix.ability_id)
                names[#names + 1] = affix.name
                affix.start(schedule, warn_area)
            end

            DisplayTextToTable(players, "|cffffcc00Boss abilities:|r " .. table.concat(names, ", "))
        end

        BossAffix.create(MARKED_FOR_DESTRUCTION, "Marked for Destruction", function(queue, warn)
            local function cast(expected_generation)
                if expected_generation ~= generation or not boss or not UnitAlive(boss) then
                    return
                end
                for _, pid in ipairs(players) do
                    local hero = Hero[pid]
                    if hero and UnitAlive(hero) then
                        warn(
                            GetUnitX(hero), GetUnitY(hero), 225., 2., 0.3,
                            "Marked for Destruction",
                            "Abilities\\Spells\\Undead\\Impale\\ImpaleHitTarget.mdl",
                            1.5
                        )
                    end
                end
                queue(8., cast)
            end
            queue(4., cast)
        end)

        BossAffix.create(NOVA, "Nova", function(queue, warn)
            local function cast(expected_generation)
                if expected_generation ~= generation or not boss or not UnitAlive(boss) then
                    return
                end
                warn(
                    GetUnitX(boss), GetUnitY(boss), 500., 2.5, 0.35,
                    "Colosseum Nova", "war3mapImported\\Death Nova.mdx", 1.5
                )
                queue(10., cast)
            end
            queue(5., cast)
        end)

        BossAffix.create(UNSTABLE_GROUND, "Unstable Ground", function(queue, warn)
            local function cast(expected_generation)
                if expected_generation ~= generation or not boss or not UnitAlive(boss) then
                    return
                end
                for _ = 1, 3 do
                    local x, y = colo_get_random_location(250.)
                    warn(
                        x, y, 275., 3., 0.25, "Unstable Ground",
                        "Abilities\\Spells\\Human\\Thunderclap\\ThunderClapCaster.mdx",
                        1.25
                    )
                end
                queue(12., cast)
            end
            queue(4., cast)
        end)

        do
            local RAGE_DURATION = 6.
            local RAGE_PERIOD = 18.
            local RAGE_DAMAGE_BONUS = 1.5
            local RAGE_ARMOR_BONUS = 2.
            local RAGE_DAMAGE_TAKEN = 0.25
            local RAGE_ATTACK_SPEED = 2.
            local RAGE_MOVE_SPEED_BONUS = 0.35
            local rage_unit ---@type Unit?
            local rage_move_speed = 0.
            local rage_effect ---@type effect?

            local function end_rage()
                if not rage_unit then
                    return
                end

                rage_unit.damage_percent = rage_unit.damage_percent - RAGE_DAMAGE_BONUS
                rage_unit.armor_percent = rage_unit.armor_percent - RAGE_ARMOR_BONUS
                rage_unit.dr = rage_unit.dr / RAGE_DAMAGE_TAKEN
                rage_unit.bonus_bat = rage_unit.bonus_bat * RAGE_ATTACK_SPEED
                rage_unit.ms_percent = rage_unit.ms_percent - rage_move_speed
                rage_unit = nil
                rage_move_speed = 0.

                if rage_effect then
                    DestroyEffect(rage_effect)
                    rage_effect = nil
                end
            end

            local function start_rage(queue)
                local function cast(expected_generation)
                    if expected_generation ~= generation or not boss or not UnitAlive(boss) then
                        return
                    end

                    end_rage()
                    rage_unit = Unit[boss]
                    rage_move_speed = RAGE_MOVE_SPEED_BONUS * math.min(1., rage_unit.ms_percent)
                    rage_unit.damage_percent = rage_unit.damage_percent + RAGE_DAMAGE_BONUS
                    rage_unit.armor_percent = rage_unit.armor_percent + RAGE_ARMOR_BONUS
                    rage_unit.dr = rage_unit.dr * RAGE_DAMAGE_TAKEN
                    rage_unit.bonus_bat = rage_unit.bonus_bat / RAGE_ATTACK_SPEED
                    rage_unit.ms_percent = rage_unit.ms_percent + rage_move_speed
                    rage_effect = AddSpecialEffectTarget(
                        "Abilities\\Spells\\Orc\\Bloodlust\\BloodlustTarget.mdl",
                        boss,
                        "origin"
                    )

                    queue(RAGE_DURATION, end_rage)
                    queue(RAGE_PERIOD, cast)
                end

                queue(6., cast)
            end

            BossAffix.create(RAGE, "Rage", start_rage, end_rage)
        end
    end

    local on_kill = function(killed)
        unit_count = unit_count - 1
        if random() * 100 < GOLD_DROP_CHANCE + (5 / num_spawned) * 18 then
            SoundHandler("Abilities\\Spells\\Items\\ResourceItems\\ReceiveGold.flac", true, nil, killed)
            base_coins = base_coins + 1
            coin_effect(killed)
        end

        for _, pid in ipairs(players) do
            if bonus_drop_chance[pid] > 0 and random() * 100 < bonus_drop_chance[pid] then
                bonus_coins[pid] = bonus_coins[pid] + 1
                coin_effect(killed, 1)
            end
        end

        if unit_count <= 0 then
            wave = wave + 1
            Encounter.call(wave, "end_wave")
            Augment.call("end_wave")

            timer_frame = TimerFrame.create("Wave " .. wave .. " beginning in:", 15, advance_wave, players)
        end
    end

    local on_boss_kill = function(killed)
        BossAffix.stop()
        base_coins = base_coins + 5
        coin_effect(killed, 10)

        wave = wave + 1
        Encounter.call(wave, "end_wave")
        Augment.call("end_wave")

        if wave <= MAX_WAVES then
            Augment.display()

            if augment_pick_timer then
                TimerQueue:disableCallback(augment_pick_timer)
            end
            augment_pick_timer = TimerQueue:callDelayed(59.75, Augment.defaultPick)
            timer_frame = TimerFrame.create("Wave " .. wave .. " beginning in:", 60, advance_wave, players)
        else
            end_colosseum(true)
        end
    end

    local setup_unit = function(u, spawn, skin, dmg, hp, armor)
        SetUnitXBounded(u, colo_spawn[spawn].x)
        SetUnitYBounded(u, colo_spawn[spawn].y)

        BlzSetUnitName(u, GetObjectName(FourCC(skin)))
        BlzSetHeroProperName(u, GetObjectName(FourCC(skin)))

        -- setup stats
        BlzSetUnitBaseDamage(u, dmg, 0)
        BlzSetUnitMaxHP(u, hp)
        BlzSetUnitArmor(u, armor)
        SetWidgetLife(u, BlzGetUnitMaxHP(u))

        -- attack random player
        local p = random(1, #players)
        IssueTargetOrder(u, "smart", Hero[players[p]])

        -- apply any encounter effects
        Encounter.call(wave, "spawn", u)
    end

    local spawn_boss = function()
        local skin = bosses[wave // 5]
        local u = BlzCreateUnitWithSkin(PLAYER_BOSS, boss_id, colo_x, colo_y, 270., FourCC(skin))
        BlzSetUnitSkin(u, FourCC(skin))
        local spawn = 2
        local wave_mult = (0.95 + wave * 0.05)
        local player_count = #players
        local dmg = R2I(stat_dmg / player_count + average_level * BOSS_DAMAGE * wave_mult * party_damage_mult)
        local hp = R2I(stat_hp / player_count + average_level * BOSS_HP * wave_mult * party_health_mult)
        local armor = stat_armor / player_count + average_level * BOSS_ARMOR * wave_mult

        setup_unit(u, spawn, skin, dmg, hp, armor)
        BossAffix.start(u)

        EVENT_ON_UNIT_DEATH:register_unit_action(u, on_boss_kill)
        colo_enemies[#colo_enemies + 1] = u
    end

    local spawn_units = function()
        local formation = wave_formations[random(1, #wave_formations)]
        local spawned_roles = {}
        num_spawned = 0

        for _, role in ipairs(formation.roles) do
            local count = random(role.count_min, role.count_max)
            spawned_roles[#spawned_roles + 1] = { role = role, count = count }
            num_spawned = num_spawned + count
        end

        unit_count = num_spawned
        local num_mult = 10 / num_spawned
        local wave_mult = (0.95 + wave * 0.05)
        DisplayTextToTable(players, "|cffffcc00Wave " .. wave .. ":|r " .. formation.name)

        for _, entry in ipairs(spawned_roles) do
            local role = entry.role
            local skin = melee_skins[random(1, #melee_skins)]

            for _ = 1, entry.count do
                local spawn = random(1, 3)
                local u = BlzCreateUnitWithSkin(PLAYER_BOSS, unit_id, colo_x, colo_y, 270., FourCC(skin))
                local dmg = R2I((stat_dmg / #players + average_level * BASE_DAMAGE * wave_mult * party_damage_mult * num_mult) * role.damage)
                local hp = R2I((stat_hp / #players + average_level * BASE_HP * wave_mult * party_health_mult * num_mult) * role.hp)
                local armor = (stat_armor / #players + average_level * BASE_ARMOR * wave_mult) * role.armor

                setup_unit(u, spawn, skin, dmg, hp, armor)
                Unit[u].ms_percent = Unit[u].ms_percent + 0.05 * wave + role.speed

                EVENT_ON_UNIT_DEATH:register_unit_action(u, on_kill)
                colo_enemies[#colo_enemies + 1] = u
            end
        end
    end

    advance_wave = function()
        if math.fmod(wave, 5) == 0 then
            spawn_boss()
        else
            spawn_units()
        end
        Encounter.call(wave, "start_wave")
        Augment.call("start_wave")
        timer_frame = nil
    end

    local begin_colosseum = function()
        start_timer = nil
        if #players == 0 then
            end_colosseum(false)
            return
        end

        average_level = total_level / #players
        party_health_mult = 1 + 0.65 * (#players - 1)
        party_damage_mult = 1 + 0.1 * (#players - 1)
        colo_active = true
        is_entry_open = false
        SoundHandler("Sound\\Interface\\BattleNetDoorsStereo2.flac", false)

        timer_frame = TimerFrame.create("Wave " .. wave .. " beginning in:", 15, advance_wave, players)
        Augment.pickAugments()
        Encounter.pickEncounters()
        bosses = pickN(4, elite_skins)
    end

    -- reward gold to player at whatever current value is
    local colo_reward = function(pid, cleared)
        if rewarded[pid] then
            return
        end

        rewarded[pid] = true
        local coins = base_coins + bonus_coins[pid]
        local level = math.max(1, math.min(MAX_LEVEL, math.floor(average_level)))
        local gold_per_coin = COIN_BASE_GOLD + level * level * COIN_LEVEL_SCALING
        local gold = math.floor(coins * gold_per_coin)

        if gold > 0 then
            AwardGold(pid, gold, true)
        end

        if cleared then
            AddCurrency(pid, HONOR, 1)
        end

        DisplayTextToPlayer(Player(pid - 1), 0., 0., "Colosseum reward: " .. coins .. " coins" .. (cleared and " and 1 Honor." or "."))
    end

    local function colo_on_cleanup(pid)
        Augment.destroy(pid)
        Encounter.destroy(pid)

        SetCamera(pid, MAIN_MAP.rect)
        RevivePlayer(pid, TOWN_CENTER_X, TOWN_CENTER_Y, 1, 1)
        DisableItems(pid, false)
        colo_reward(pid, false)
        colo_cleanup(pid)
    end

    -- called on grave expire of a player
    colo_on_death = function(killed)
        local pid = GetPlayerId(GetOwningPlayer(killed)) + 1

        Unit[killed].death_exception = true
        colo_on_cleanup(pid)
    end

    colo_cleanup = function(pid)
        TableRemove(players, pid)

        -- no more players, final cleanup
        if #players <= 0 then
            end_colosseum()
        end

        EVENT_ON_CLEANUP:unregister_action(pid, colo_on_cleanup)
        EVENT_GRAVE_DEATH:unregister_unit_action(Hero[pid], colo_on_death)
    end

    local enter_colosseum = function(pid)
        players[#players + 1] = pid

        -- adjust difficulty
        local hero = Hero[pid]
        local unit = Unit[hero]
        local strength = unit.str + unit.bonus_str
        local agility = unit.agi + unit.bonus_agi
        local intelligence = unit.int + unit.bonus_int

        total_level = total_level + GetUnitLevel(hero)
        stat_hp = stat_hp + strength + agility + intelligence
        stat_armor = stat_armor + (agility + intelligence) * 0.1
        stat_dmg = stat_dmg + strength + agility

        -- disable inventory
        DisableItems(pid, true)
        MoveHero(pid, colo_x, colo_y)

        -- skip 60 second wait if all players join
        if #players >= User.AmountPlaying then
            if start_timer then
                TimerQueue:disableCallback(start_timer)
            end
            begin_colosseum()
        end

        EVENT_ON_CLEANUP:register_action(pid, colo_on_cleanup)
        EVENT_GRAVE_DEATH:register_unit_action(Hero[pid], colo_on_death)
    end

    end_colosseum = function(cleared)
        BossAffix.stop()
        if start_timer then
            TimerQueue:disableCallback(start_timer)
            start_timer = nil
        end
        if augment_pick_timer then
            TimerQueue:disableCallback(augment_pick_timer)
            augment_pick_timer = nil
        end
        if timer_frame then
            timer_frame:destroy()
            timer_frame = nil
        end
        Augment.destroy()
        Encounter.destroy()

        colo_active = false
        is_entry_open = false

        -- reenable items and reward remaining players
        for _, pid in ipairs(players) do
            MoveHero(pid, TOWN_CENTER_X, TOWN_CENTER_Y)
            DisableItems(pid, false)
            colo_reward(pid, cleared == true)

            EVENT_ON_CLEANUP:unregister_action(pid, colo_on_cleanup)
            EVENT_GRAVE_DEATH:unregister_unit_action(Hero[pid], colo_on_death)
        end

        wave = 1
        total_level = 0
        stat_hp = 0
        stat_armor = 0
        stat_dmg = 0
        average_level = 0
        party_health_mult = 1
        party_damage_mult = 1

        for _, u in ipairs(colo_enemies) do
            RemoveUnit(u)
        end
        colo_enemies = {}
        players = {}
    end

    ---@class Encounter
    ---@field create function
    ---@field call function
    ---@field pickEncounters function
    Encounter = {}
    do
        --#region frame setup
        local ENCOUNTER_GAP = 0.1259
        local ENCOUNTER_WIDTH = 0.025
        local ENCOUNTER_HEIGHT = 0.025

        local encounter_frame = BlzCreateFrameByType("FRAME", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
        BlzFrameSetSize(encounter_frame, 0.001, 0.001)
        BlzFrameSetAbsPoint(encounter_frame, FRAMEPOINT_TOPLEFT, 0.1475, 0.55)
        BlzFrameSetEnable(encounter_frame, false)
        BlzFrameSetVisible(encounter_frame, false)

        -- prevents losing focus when clicking encounter button
        local on_click_placeholder = function()
            local f = BlzGetTriggerFrame()

            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)
        end

        -- encounter backdrop
        local encounter_backdrop = BlzCreateFrameByType("BACKDROP", "", encounter_frame, "ButtonBackdropTemplate", 0)
        BlzFrameSetTexture(encounter_backdrop, "UI\\ColosseumProgress2.dds", 0, TRUE)
        BlzFrameSetPoint(encounter_backdrop, FRAMEPOINT_TOPLEFT, encounter_frame, FRAMEPOINT_TOPLEFT, -0.025, -0.005)
        BlzFrameSetSize(encounter_backdrop, 0.552, 0.035)
        BlzFrameSetLevel(encounter_backdrop, 1)

        -- progress bar
        local progress_bar = BlzCreateFrameByType("SIMPLESTATUSBAR", "", encounter_frame, "", 0)
        BlzFrameClearAllPoints(progress_bar)
        BlzFrameSetPoint(progress_bar, FRAMEPOINT_TOPLEFT, encounter_backdrop, FRAMEPOINT_TOPLEFT, 0., 0.)
        BlzFrameSetPoint(progress_bar, FRAMEPOINT_BOTTOMRIGHT, encounter_backdrop, FRAMEPOINT_BOTTOMRIGHT, 0., 0.)
        BlzFrameSetTexture(progress_bar, "UI\\ColosseumProgressBar.dds", 0, true)
        BlzFrameSetVertexColor(progress_bar, BlzConvertColor(255, 255, 255, 255))
        BlzFrameSetMinMaxValue(progress_bar, 0, 100)
        BlzFrameSetValue(progress_bar, 0)

        -- wave text
        local wave_text = BlzCreateFrameByType("TEXT", "", encounter_backdrop, "", 0)
        BlzFrameSetPoint(wave_text, FRAMEPOINT_LEFT, encounter_backdrop, FRAMEPOINT_LEFT, 0.0035, 0.001)
        BlzFrameSetEnable(wave_text, false)
        BlzFrameSetSize(wave_text, 0.02, 0)
        BlzFrameSetTextAlignment(wave_text, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
        BlzFrameSetText(wave_text, 1)
        BlzFrameSetScale(wave_text, 1.7)

        local encounter_icons = {}
        for i = 1, 3 do
            encounter_icons[i] = SimpleButton.create(encounter_backdrop, "", ENCOUNTER_WIDTH, ENCOUNTER_HEIGHT, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.0119 + ENCOUNTER_GAP * i, -0.003)
            encounter_icons[i]:makeTooltip(nil, 0.2)
            encounter_icons[i]:point(FRAMEPOINT_TOP, FRAMEPOINT_BOTTOM, 0, -0.055)
            encounter_icons[i]:onClick(on_click_placeholder)
        end
        --#endregion

        local thistype = Encounter
        local list = {}
        local active

        function Encounter.destroy(pid)
            if pid then
                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetVisible(encounter_frame, false)
                    BlzFrameSetAlpha(progress_bar, 0)
                end
            else
                thistype.call(MAX_WAVES, "end_wave")
                BlzFrameSetVisible(encounter_frame, false)
                BlzFrameSetAlpha(progress_bar, 0)
            end
        end

        ---@type fun(n: integer, func: string, ...)
        function thistype.call(n, func, ...)
            -- update wave count text and progress bar on start_wave
            if func == "start_wave" then
                BlzFrameSetText(wave_text, wave)
                BlzFrameSetValue(progress_bar, wave * 4.55 + 4.45)
            end

            for i, v in ipairs(active) do
                -- only execute after appropriate wave count
                if n // (i * 5) > 0 then
                    local f = v[func]
                    if f then
                        f(...)
                    end
                end
            end
        end

        function thistype.pickEncounters()
            active = pickN(3, list)

            -- force bullet_hell
            --active[1] = list[4]

            -- set icon / tooltip
            for i = 1, 3 do
                encounter_icons[i]:icon(active[i].icon)
                encounter_icons[i]:setTooltipIcon(active[i].icon)
                encounter_icons[i]:setTooltipName(active[i].name)
                encounter_icons[i]:setTooltipText(active[i].desc)
            end

            -- display frame
            local pid = GetPlayerId(GetLocalPlayer()) + 1
            if TableHas(players, pid) then
                BlzFrameSetVisible(encounter_frame, true)
                BlzFrameSetAlpha(progress_bar, 255)
            end
        end

        ---@return Encounter
        function thistype.create(name, desc, icon)
            local self = {}

            self.name = name
            self.desc = desc
            self.icon = icon

            list[#list + 1] = self

            return self
        end
    end

    local spikes = Encounter.create("Spikes", "Every |cffffcc0010|r seconds, players will be targeted by spikes that will impale them after |cffffcc002|r seconds for |cffffcc00" .. "99%|r" .. " max health magic damage."
    , "ReplaceableTextures\\CommandButtons\\BTNImpale.blp")
    do
        local callback
        local model = "Indicators\\circle.mdl"
        local function impale(sfx, x, y)
            local ug = CreateGroup()
            MakeGroupInRange(BOSS_ID, ug, x, y, 200., Condition(FilterEnemy))
            for player in each(ug) do
                DamageTarget(DUMMY_UNIT, player, BlzGetUnitMaxHP(player) * 0.99, ATTACK_TYPE_NORMAL, MAGIC, "Spikes")
            end
            DestroyEffect(sfx)
            sfx = AddSpecialEffect("Abilities\\Spells\\Undead\\Impale\\ImpaleHitTarget.mdl", x, y)
            BlzSetSpecialEffectScale(sfx, 2.0)
            DestroyEffect(sfx)
            DestroyGroup(ug)
        end
        local function spike_wave()
            for _, pid in ipairs(players) do
                local x, y = GetUnitX(Hero[pid]), GetUnitY(Hero[pid])
                local sfx = AddSpecialEffect(model, x, y)
                BlzSetSpecialEffectScale(sfx, 0.4)
                TimerQueue:callDelayed(2., impale, sfx, x, y)
            end
            callback = TimerQueue:callDelayed(10., spike_wave)
        end
        spikes.end_wave = function()
            TimerQueue:disableCallback(callback)
        end
        spikes.start_wave = function()
            callback = TimerQueue:callDelayed(10., spike_wave)
        end
    end
    local martyrdom = Encounter.create("Martyrdom", "Enemies explode on death, dealing |cffffcc00" .. "15" .. "%|r max health magic damage to nearby players."
    , "ReplaceableTextures\\CommandButtons\\BTNTemp.blp")
    do
        -- on death function
        local function explode(killed)
            local ug = CreateGroup()
            MakeGroupInRange(BOSS_ID, ug, GetUnitX(killed), GetUnitY(killed), 200., Condition(FilterEnemy))
            DestroyEffect(AddSpecialEffectTarget("Objects\\Spawnmodels\\Undead\\UndeadLargeDeathExplode\\UndeadLargeDeathExplode.mdl", killed, "origin"))

            for player in each(ug) do
                DamageTarget(killed, player, BlzGetUnitMaxHP(player) * 0.15, ATTACK_TYPE_NORMAL, MAGIC, "Martyrdom")
            end

            DestroyGroup(ug)
        end
        martyrdom.spawn = function(u)
            EVENT_ON_UNIT_DEATH:register_unit_action(u, explode)
        end
    end
    local earthquake = Encounter.create("Earthquake", "Players have a |cffffcc00" .. "50%|r" .. " movespeed and healing reduction."
    , "ReplaceableTextures\\CommandButtons\\BTNEarthquake.blp")
    do
        earthquake.end_wave = function()
            for _, v in ipairs(players) do
                EarthquakeDebuff:dispel(nil, Hero[v])
            end
        end
        earthquake.start_wave = function()
            for _, v in ipairs(players) do
                EarthquakeDebuff:add(Hero[v], Hero[v])
            end
        end
    end
    local bullet_hell = Encounter.create("Bullet Hell", "Every |cffffcc00" .. "6|r" .. " seconds, a flurry of projectiles are launched across the arena, dealing |cffffcc00" .. "25%|r" .. " max health magic damage on impact."
    , "ReplaceableTextures\\CommandButtons\\BTNTemp.blp")
    do
        local callback
        local model = "Indicators\\moving arrows.mdl"
        local bullet_template = {
            interactions = {
                unit = CAT_UnitCollisionCheck2D,
                self = {
                    CAT_MoveAutoHeight,
                    CAT_Orient2D,
                    CAT_Decay,
                }
            },
            identifier = "missile",
            speed = 900,
            lifetime = 3.,
            collisionRadius = 50,
            visualZ = 10.,
            friendlyFire = false,
            owner = PLAYER_CREEP,
            onUnitCollision = CAT_UnitImpact2D,
            onUnitCallback = function(self, enemy)
                DamageTarget(DUMMY_UNIT, enemy, BlzGetUnitMaxHP(enemy) * 0.25, ATTACK_TYPE_NORMAL, MAGIC, "Bullet")
            end

        }
        bullet_template.__index = bullet_template

        -- returns start (sx, sy) on the rim and an inward-facing heading theta with 35 degree variance
        local function random_rim_and_inward_theta(cx, cy)
            local startAngle = math.random() * (2 * math.pi)
            local sx = cx + ARENA_RADIUS * math.cos(startAngle)
            local sy = cy + ARENA_RADIUS * math.sin(startAngle)

            -- base inward direction aims to center from (sx, sy)
            local toCenter = math.atan(cy - sy, cx - sx)

            -- +-35 degrees
            local variance = (math.random() * 2.0 - 1.0) * math.rad(35.0)
            local theta = toCenter + variance
            return sx, sy, theta
        end

        local function spawn_missiles(missiles)
            for _, missile in ipairs(missiles) do
                missile.visual = AddSpecialEffect("war3mapImported\\HighSpeedProjectile_ByEpsilon.mdx", missile.x, missile.y)
                ALICE_Create(missile)
            end
        end

        local function bullet_wave()
            local cx = colo_x
            local cy = colo_y

            local missiles = {}

            for _ = 1, math.random(5, 6) do
                local sx, sy, theta = random_rim_and_inward_theta(cx, cy)

                -- place bullet indicators
                local sfx, x, y

                for i = 1, 3 do
                    x = sx + ((300. + i * 475.) * math.cos(theta))
                    y = sy + ((300. + i * 475.) * math.sin(theta))
                    sfx = AddSpecialEffect(model, x, y)
                    BlzSetSpecialEffectTimeScale(sfx, 0.5)
                    BlzSetSpecialEffectScale(sfx, 0.4)
                    BlzSetSpecialEffectYaw(sfx, theta)

                    TimerQueue:callDelayed(2.5, DestroyEffect, sfx)
                end

                -- make missile table
                local missile = setmetatable({}, bullet_template)
                missile.x = sx
                missile.y = sy
                missile.facing = theta
                missile.vx = missile.speed * math.cos(theta)
                missile.vy = missile.speed * math.sin(theta)

                missiles[#missiles + 1] = missile
            end

            -- delay spawning by 2 seconds
            TimerQueue:callDelayed(2., spawn_missiles, missiles)

            callback = TimerQueue:callDelayed(6., bullet_wave)
        end
        bullet_hell.end_wave = function()
            if callback then
                TimerQueue:disableCallback(callback)
                callback = nil
            end
        end
        bullet_hell.start_wave = function()
            callback = TimerQueue:callDelayed(6., bullet_wave)
        end
    end

    ---@class Augment
    ---@field display function
    ---@field create function
    ---@field call function
    ---@field pickAugments function
    ---@field defaultPick function
    Augment = {}
    do
        local thistype = Augment
        local active = {}
        local by_category = {
            offense = {},
            defense = {},
            utility = {},
        }
        local player_choices = {}
        local wave_offset -- lazy augment indexing

        --#region frame setup
        local AUGMENT_WIDTH = 0.175
        local AUGMENT_HEIGHT = 0.2625
        local AUGMENT_GAP = 0.225
        local AUGMENT_MIN_X = -0.315
        local AUGMENT_MIN_Y = 0.2

        local SHOW_HIDE_WIDTH = 0.025
        local SHOW_HIDE_HEIGHT = 0.025

        local frame = BlzCreateFrameByType("FRAME", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
        BlzFrameSetSize(frame, 0.001, 0.001)
        BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOP, 0.4, 0.3)
        BlzFrameSetEnable(frame, false)
        BlzFrameSetVisible(frame, false)

        local augment_container = BlzCreateFrameByType("FRAME", "", frame, "", 0)
        BlzFrameSetSize(augment_container, 0.001, 0.001)
        BlzFrameSetPoint(augment_container, FRAMEPOINT_CENTER, frame, FRAMEPOINT_CENTER, 0., 0.)
        BlzFrameSetEnable(augment_container, false)

        local augment_buttons = {}
        local augment_name = {}
        local augment_desc = {}
        local show_hide_button = Button.create(frame, SHOW_HIDE_WIDTH, SHOW_HIDE_HEIGHT, -0.0125, -0.065, false)
        show_hide_button:icon("war3mapImported\\expand.blp")
        show_hide_button.tooltip:visible(false)

        local on_show_hide = function()
            local f = BlzGetTriggerFrame()

            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)

            local vis = BlzFrameIsVisible(augment_container)

            if GetLocalPlayer() == GetTriggerPlayer() then
                BlzFrameSetVisible(augment_container, not vis)
                show_hide_button:icon("war3mapImported\\" .. (vis and "minimize" or "expand") .. ".blp")
            end
        end
        show_hide_button:onClick(on_show_hide)

        --  reverse map
        local button_map = {}
        local augment_chosen = {}

        local on_pick_augment = function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local f = BlzGetTriggerFrame()
            local index = button_map[f]

            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)

            if not augment_chosen[pid] then
                local choice = player_choices[pid][index + wave_offset]
                -- add choice to active list
                active[pid][#active[pid] + 1] = choice
                augment_chosen[pid] = true

                DisplayTextToForce(FORCE_PLAYING, User[pid - 1].nameColored .. " selected " .. choice.name)
                if choice.on_pick then
                    choice.on_pick(pid)
                end
            end

            -- check if every player has picked an augment already and reduce wait time
            local all_players_selected = true
            for _, p in ipairs(players) do
                if not augment_chosen[p] then
                    all_players_selected = false
                    break
                end
            end
            if all_players_selected and timer_frame then
                if augment_pick_timer then
                    TimerQueue:disableCallback(augment_pick_timer)
                    augment_pick_timer = nil
                end
                timer_frame.time = 5
            end

            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetVisible(frame, false)
            end
        end

        -- augment buttons
        for i = 1, 3 do
            augment_buttons[i] = Button.create(augment_container, AUGMENT_WIDTH, AUGMENT_HEIGHT, AUGMENT_MIN_X + (AUGMENT_GAP * (i - 1)), AUGMENT_MIN_Y, false)
            augment_buttons[i]:onClick(on_pick_augment)
            augment_buttons[i]:icon("augmentcard.dds")
            augment_buttons[i].tooltip:visible(false)
            button_map[augment_buttons[i].frame] = i

            augment_desc[i] = BlzCreateFrameByType("TEXT", "", augment_buttons[i].frame, "", 0)
            BlzFrameSetPoint(augment_desc[i], FRAMEPOINT_TOPLEFT, augment_buttons[i].frame, FRAMEPOINT_TOPLEFT, 0.032, -0.15)
            BlzFrameSetSize(augment_desc[i], AUGMENT_WIDTH - 0.07, 0.)
            BlzFrameSetEnable(augment_desc[i], false)

            augment_name[i] = BlzCreateFrameByType("TEXT", "", augment_buttons[i].frame, "", 0)
            BlzFrameSetScale(augment_name[i], 1.175)
            BlzFrameSetSize(augment_name[i], AUGMENT_WIDTH - 0.075, 0.)
            BlzFrameSetPoint(augment_name[i], FRAMEPOINT_CENTER, augment_buttons[i].frame, FRAMEPOINT_CENTER, -0.001, 0.0015)
            BlzFrameSetTextAlignment(augment_name[i], TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_CENTER)
            BlzFrameSetEnable(augment_name[i], false)
        end
        --#endregion

        function Augment.destroy(pid)
            if pid then
                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetVisible(frame, false)
                end

                -- call cleanup for all active augments for player
                for _, augment in ipairs(active[pid] or {}) do
                    local f = augment["cleanup"]
                    if f then
                        f(pid)
                    end
                end
            else
                thistype.call("end_wave")
                thistype.call("cleanup")
                BlzFrameSetVisible(frame, false)
            end
        end

        -- assigns undecisive players an augment choice
        function thistype.defaultPick()
            augment_pick_timer = nil
            for _, pid in ipairs(players) do
                if not augment_chosen[pid] then
                    local index = math.random(1, 3)

                    active[pid][#active[pid] + 1] = player_choices[pid][index + wave_offset]
                    augment_chosen[pid] = true

                    print("picked", player_choices[pid][index + wave_offset].name)

                    if GetLocalPlayer() == Player(pid - 1) then
                        BlzFrameSetVisible(frame, false)
                    end

                    local choice = player_choices[pid][index + wave_offset]
                    if choice.on_pick then
                        choice.on_pick(pid)
                    end
                end
            end
        end

        function thistype.call(func, ...)
            for _, pid in ipairs(players) do
                for _, augment in ipairs(active[pid]) do
                    local f = augment[func]
                    if f then
                        f(pid, ...)
                    end
                end
            end
        end

        function thistype.pickAugments()
            wave_offset = -3

            for _, pid in ipairs(players) do
                -- initialize / reset active player table
                active[pid] = {}
                player_choices[pid] = {}

                local offense = pickN(3, by_category.offense)
                local defense = pickN(3, by_category.defense)
                local utility = pickN(3, by_category.utility)

                for round = 1, 3 do
                    local choices = pickN(3, { offense[round], defense[round], utility[round] })
                    for _, choice in ipairs(choices) do
                        player_choices[pid][#player_choices[pid] + 1] = choice
                    end
                end
            end
        end

        function thistype.display()
            local pid = GetPlayerId(GetLocalPlayer()) + 1
            augment_chosen = {}

            wave_offset = wave_offset + 3

            if not TableHas(players, pid) then
                return
            end

            BlzFrameSetVisible(frame, true)

            for i = 1, 3 do
                BlzFrameSetText(augment_desc[i], player_choices[pid][i + wave_offset].desc)
                BlzFrameSetText(augment_name[i], player_choices[pid][i + wave_offset].name)
            end
        end

        ---@type fun(name: string, desc: string, icon: string, category?: string): Augment
        function thistype.create(name, desc, icon, category)
            local self = {}

            self.name = name
            self.desc = desc
            self.icon = icon
            self.category = category or "utility"

            by_category[self.category][#by_category[self.category] + 1] = self

            return self
        end
    end

    --#region augment setup
    local punching_bag = Augment.create("Punching Bag", "At the start of each wave, spawn a punching bag in the center of the arena that taunts enemies. Health scaling is based off enemy scaling.", "trans32.blp", "defense")
    do
        local bags = {}
        local callback

        local function taunt_enemies()
            for i = 1, PLAYER_CAP do
                if bags[i] then
                    Taunt(bags[i], ARENA_RADIUS)
                end
            end
            callback = TimerQueue:callDelayed(2., taunt_enemies)
        end

        punching_bag.cleanup = function(pid)
            if bags[pid] then
                RemoveUnit(bags[pid])
            end
            bags[pid] = nil
        end
        punching_bag.end_wave = function(pid)
            if callback then
                TimerQueue:disableCallback(callback)
                callback = nil
            end
        end
        punching_bag.start_wave = function(pid)
            local bag = bags[pid]
            -- heal bag if still alive
            if bag and UnitAlive(bag) then
                SetWidgetLife(bag, BlzGetUnitMaxHP(bag))
            else
                bag = CreateUnit(Player(pid - 1), FourCC("h02D"), -175 + colo_x + (pid * 50), colo_y + 400., 270.)
                bags[pid] = bag
            end

            local hp = R2I(stat_hp / #players + average_level * BASE_HP * party_health_mult * 50)
            BlzSetUnitMaxHP(bag, hp)
            SetWidgetLife(bag, hp)

            if not callback then
                callback = TimerQueue:callDelayed(2., taunt_enemies)
            end
        end
    end
    local radiance = Augment.create("Radiance", "Your hero gains a damaging aura in a |cffffcc00".."900".."|r AoE, dealing |cffffcc00".."1 x Highest Attribute".."|r magic damage every second.", "trans32.blp", "offense")
    do
        radiance.cleanup = function(pid)
            RadianceBuff:dispel(nil, Hero[pid])
        end

        radiance.end_wave = function(pid)
            radiance.cleanup(pid)
        end
        radiance.start_wave = function(pid)
            RadianceBuff:add(Hero[pid], Hero[pid])
        end
    end
    local raining_gold = Augment.create("Raining Gold", "At the start of each wave, |cffffcc00".."1".."|r personal gold drop is given immediately.", "trans32.blp", "utility")
    do
        raining_gold.start_wave = function(pid)
            SoundHandler("Abilities\\Spells\\Items\\ResourceItems\\ReceiveGold.flac", true, nil, Hero[pid])
            bonus_coins[pid] = bonus_coins[pid] + 1
            coin_effect(Hero[pid])
        end
    end
    local speed_demon = Augment.create("Speed Demon", "Your hero's movespeed is always set to |cffffcc00".."600".."|r.", "trans32.blp", "utility")
    do
        speed_demon.cleanup = function(pid)
            SpeedDemonBuff:dispel(nil, Hero[pid])
        end
        speed_demon.start_wave = function(pid)
            SpeedDemonBuff:add(Hero[pid], Hero[pid])
        end
    end
    local attribute_expert = Augment.create("Attribute Expert", "Your hero gains a |cffffcc00" .. "75%|r" .. " increase to your base |cffffcc00Highest Attribute|r.", "trans32.blp", "offense")
    do
        attribute_expert.cleanup = function(pid)
            AttributeExpertBuff:dispel(nil, Hero[pid])
        end
        attribute_expert.start_wave = function(pid)
            AttributeExpertBuff:add(Hero[pid], Hero[pid])
        end
    end
    local battle_trance = Augment.create("Battle Trance", "Your hero gains |cffffcc0025%|r attack damage and |cffffcc0025%|r Spellboost.", "ReplaceableTextures\\CommandButtons\\BTNBloodLust.blp", "offense")
    do
        battle_trance.on_pick = function(pid)
            local unit = Unit[Hero[pid]]
            unit.damage_percent = unit.damage_percent + 0.25
            unit.spellboost = unit.spellboost + 0.25
        end
        battle_trance.cleanup = function(pid)
            local unit = Unit[Hero[pid]]
            unit.damage_percent = unit.damage_percent - 0.25
            unit.spellboost = unit.spellboost - 0.25
        end
    end
    local healing_expert = Augment.create("Healing Expert", "At the end of each wave, fully restore health, mana, and potion charges.", "trans32.blp", "defense")
    do
        healing_expert.end_wave = function(pid)
            HP(Hero[pid], Hero[pid], BlzGetUnitMaxHP(Hero[pid]), "Healing Expert")
            MP(Hero[pid], BlzGetUnitMaxMana(Hero[pid]))

            for i = 0, 1 do
                local pot = Profile[pid].hero.items[POTION_INDEX + i]

                if pot then
                    pot.charges = pot.cached_stats[ITEM_CHARGES]
                end
            end
        end
        healing_expert.on_pick = function(pid)
            healing_expert.end_wave(pid)
        end
    end
    local protector = Augment.create("Protector", "At the start of each wave, grant a stackable |cffffcc00" .. "30%|r" .. " max health shield to all players that lasts |cffffcc00" .. "20|r" .. " minutes.", "trans32.blp", "defense")
    do
        protector.cleanup = function(pid)
            local shield = Shield[Hero[pid]] ---@type Shield

            if shield then
                shield:destroy()
            end
        end

        protector.start_wave = function(pid)
            Shield.add(Hero[pid], BlzGetUnitMaxHP(Hero[pid]) * 0.3, 1200)
        end
    end
    local gambler = Augment.create("Gambler", "Increases your personal chance for an additional coin drop by |cffffcc00" .. "5%|r.", "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp", "utility")
    do
        gambler.on_pick = function(pid)
            bonus_drop_chance[pid] = bonus_drop_chance[pid] + 5
        end
    end
    local defensive_bubble = Augment.create("Defensive Bubble", "At the start of each wave, spawn a defensive bubble in a random location near the center of the arena, providing a |cffffcc00" .. "30%|r" .. " damage reduction buff in a |cffffcc00300|r AoE to allies that stand inside.", "ReplaceableTextures\\CommandButtons\\BTNLightningShield.blp", "defense")
    do
        local model = "war3mapImported\\Ubershield Void.mdl"
        local bubbles = {}
        local callback
        local apply_aura_callback

        local function valid_allied_unit(target)
            return UnitAlive(target) and not IsEnemy(target)
        end

        local function give_aura(target)
            DefensiveBubbleBuff:add(target, target):duration(1.)
        end

        local function apply_aura()
            -- check bubbles for allied units and apply aura
            for _, bubble in ipairs(bubbles) do
                ALICE_ForAllObjectsInRangeDo(give_aura, bubble.x, bubble.y, 300., "unit", valid_allied_unit)
            end

            apply_aura_callback = TimerQueue:callDelayed(0.5, apply_aura)
        end

        defensive_bubble.cleanup = function(pid)
            local bubble = bubbles[pid]
            if bubble then
                DestroyEffect(bubble.sfx)
            end
            bubbles[pid] = nil
        end
        defensive_bubble.end_wave = function(pid)
            defensive_bubble.cleanup(pid)

            if callback then
                TimerQueue:disableCallback(callback)
                callback = nil
            end

            if apply_aura_callback then
                TimerQueue:disableCallback(apply_aura_callback)
                apply_aura_callback = nil
            end
        end
        defensive_bubble.start_wave = function(pid)
            -- create bubble
            local x, y  = colo_get_random_location(800.)
            local bubble = {
                sfx = AddSpecialEffect(model, x, y),
                x = x,
                y = y,
            }

            BlzSetSpecialEffectPosition(bubble.sfx, bubble.x, bubble.y, GetLocZ(bubble.x, bubble.y) + 75.)
            BlzSetSpecialEffectScale(bubble.sfx, 3.5)

            bubbles[pid] = bubble

            if not apply_aura_callback then
                apply_aura_callback = TimerQueue:callDelayed(0.5, apply_aura)
            end
        end
    end
    --#endregion

    ITEM_LOOKUP[FourCC('I0ER')] = function(p, pid)
        -- if colo is already active
        if colo_active then
            DisplayTextToPlayer(p, 0., 0., "Colosseum is already active!")
            return
        end

        if is_entry_open and not TableHas(players, pid) then
            enter_colosseum(pid)
        else
            -- check for ticket
            local itm = GetItemFromPlayer(pid, ticket_id)
            if itm then
                players = {} -- reset players table
                rewarded = {}
                bonus_coins = __jarray(0)
                bonus_drop_chance = __jarray(0)
                base_coins = 0
                DisplayTextToForce(FORCE_PLAYING, User[pid - 1].nameColored .. " has opened the Colosseum for all players to enter. The gate will close in 60 seconds.")
                is_entry_open = true
                itm:destroy()
                start_timer = TimerQueue:callDelayed(60., begin_colosseum)
                enter_colosseum(pid)
            else
                DisplayTextToPlayer(p, 0, 0, "|cffff0000You do not have a Colosseum ticket!")
            end
        end
    end
end, Debug and Debug.getLine())
