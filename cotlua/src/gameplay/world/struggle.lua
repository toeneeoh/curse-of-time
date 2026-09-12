--[[
    struggle.lua

    Struggle is an endless pressure mode.
    Its waves arrive in 25-40 unit trickles with only a five-second reset, use mixed
    battlefield roles, and grow quadratically in durability while damage grows more slowly.
    Encounter strength snapshots the entrants' level, permanent base attributes, and
    equipped-item attributes.
    Temporary pre-entry buffs are deliberately ignored so buffing before entry cannot raise
    or lower the run's baseline.
    Party size increases durability much more than damage. At the same level
    breakpoints as the late overworld and Colosseum, enemies receive chaos
    defense and attacks; chaos attack damage is divided by the map's native
    multiplier before being written so the type transition is not a 350x jump.
]]

OnInit.final("Struggle", function(Require)
    Require('Variables')
    Require('UnitTable')
    Require('Users')
    Require('Events')
    Require('TimerQueue')
    Require('SimpleButton')
    Require('DialogWindow')
    Require('ItemHelpers')
    Require('ItemEventRegistry')
    Require('PlayerLifecycle')
    Require('Profile')
    Require('StruggleSpecials')

    ---@class StruggleService
    Struggle = {}

    local ENTRY_ITEM = FourCC('I0EW')
    local ENTRY_DURATION = 45.
    local FIRST_WAVE_DELAY = 5.
    local BETWEEN_WAVE_DELAY = 5.
    local CHECKPOINT_INTERVAL = 5
    local CHECKPOINT_DECISION_TIME = 20.
    local MAX_SAVED_WAVE = 0xFFFF
    local TRICKLE_INTERVAL = 1.25
    local TRICKLE_SIZE = 3
    local MIN_WAVE_UNITS = 25
    local MAX_WAVE_UNITS = 40
    local MELEE_ENEMY_TEMPLATE = FourCC('n002')
    local RANGED_ENEMY_TEMPLATE = FourCC('n008')
    local FURY_SWIPES_ABILITY = FourCC('A036')
    local RANGED_ATTACK_RANGE = 1000.
    local RANGED_ACQUISITION_RANGE = 1100.
    local FURY_DAMAGE_PER_STACK = 0.12
    local FURY_MAX_STACKS = 8
    local FURY_RESET_TIME = 6.
    local CHAOS_ARMOR_LEVEL = 200
    local CHAOS_ATTACK_LEVEL = 250
    local STAT_ARMOR_PER_ATTRIBUTE = 0.0003
    local LATE_GAME_DAMAGE_PER_LEVEL = 0.04
    local MAX_ENEMY_HP = 2000000000
    local MAX_ENEMY_DAMAGE = 2000000000

    local center_x = STRUGGLE_CENTER_X
    local center_y = STRUGGLE_CENTER_Y
    local spawn_rects = {
        gg_rct_InfiniteStruggleSpawn1,
        gg_rct_InfiniteStruggleSpawn2,
        gg_rct_InfiniteStruggleSpawn3,
        gg_rct_InfiniteStruggleSpawn4,
    }

    local prechaos_skins = {
        fodder = { FourCC('n0tb'), FourCC('n0ss'), FourCC('n0hh') },
        blocker = { FourCC('n0dm'), FourCC('n01G'), FourCC('n01M') },
        ranged = { FourCC('n024'), FourCC('n028'), FourCC('n0us') },
        disruptor = { FourCC('n0ut'), FourCC('n028'), FourCC('n0tc') },
    }
    local chaos_skins = {
        fodder = { FourCC('n03C'), FourCC('n033'), FourCC('n03E') },
        blocker = { FourCC('n03A'), FourCC('n08N'), FourCC('n031') },
        ranged = { FourCC('n01W'), FourCC('n00W'), FourCC('n02J') },
        disruptor = { FourCC('n034'), FourCC('n02Z'), FourCC('n03T') },
    }

    local formations = {
        {
            name = "The Crush",
            roles = {
                { type = "fodder", weight = 0.75, hp = 0.7, damage = 0.75, armor = 0.7, speed = 0.12 },
                { type = "ranged", weight = 0.25, hp = 0.65, damage = 1.35, armor = 0.65, speed = 0.05 },
            },
        },
        {
            name = "Shield Wall",
            roles = {
                { type = "blocker", weight = 0.5, hp = 1.65, damage = 0.7, armor = 1.5, speed = -0.08 },
                { type = "ranged", weight = 0.5, hp = 0.6, damage = 1.5, armor = 0.6, speed = 0.08 },
            },
        },
        {
            name = "Hunting Pack",
            roles = {
                { type = "fodder", weight = 0.58, hp = 0.8, damage = 0.9, armor = 0.75, speed = 0.18 },
                { type = "disruptor", weight = 0.25, hp = 0.9, damage = 1.15, armor = 0.9, speed = 0.12 },
                { type = "ranged", weight = 0.17, hp = 0.55, damage = 1.65, armor = 0.55, speed = 0.05 },
            },
        },
        {
            name = "Pressure Line",
            roles = {
                { type = "blocker", weight = 0.27, hp = 1.8, damage = 0.75, armor = 1.6, speed = -0.1 },
                { type = "disruptor", weight = 0.36, hp = 0.85, damage = 1.2, armor = 0.85, speed = 0.1 },
                { type = "ranged", weight = 0.37, hp = 0.6, damage = 1.55, armor = 0.6, speed = 0.05 },
            },
        },
    }

    local special_roles = {
        { type = "harpooner", skin_type = "ranged", ranged = true, special = "hook",
            hp = 0.75, damage = 1.1, armor = 0.7, speed = 0.08 },
        { type = "burster", skin_type = "disruptor", special = "rupture",
            hp = 0.6, damage = 1., armor = 0.55, speed = 0.35 },
        { type = "blightcaster", skin_type = "disruptor", ranged = true, special = "miasma",
            hp = 0.7, damage = 0.9, armor = 0.65, speed = 0.05 },
    }

    local players = {} ---@type integer[]
    local enemies = {} ---@type unit[]
    local active_count = 0
    local wave = 0
    local completed_wave = 0
    local average_level = 1.
    local average_power = 1.
    local party_health_multiplier = 1.
    local party_damage_multiplier = 1.
    local entry_open = false
    local active = false
    local entry_callback ---@type integer?
    local wave_callback ---@type integer?
    local trickle_callback ---@type integer?
    local checkpoint_callback ---@type integer?
    local spawn_queue = {}
    local spawn_total = 0
    local exit_button ---@type SimpleButton?
    local fury_state = setmetatable({}, { __mode = 'k' })
    local checkpoint_active = false
    local checkpoint_waiting = 0
    local checkpoint_pending = {} ---@type boolean[]
    local checkpoint_dialogs = {} ---@type DialogWindow[]

    local begin_run, begin_checkpoint, end_run, remove_player, schedule_wave
    local on_grave_death, on_cleanup, on_struggle_fury_hit

    local function set_exit_visible(pid, visible)
        if GetLocalPlayer() == Player(pid - 1) and exit_button then
            exit_button:visible(visible)
        end
    end

    local function random_player_hero()
        if #players == 0 then
            return nil
        end

        local first = math.random(1, #players)
        for offset = 0, #players - 1 do
            local hero = Hero[players[(first + offset - 1) % #players + 1]]
            if hero and UnitAlive(hero) then
                return hero
            end
        end

        return nil
    end

    local function get_wave_multiplier()
        local progress = wave - 1
        return 1. + 0.075 * progress + 0.0015 * progress * progress
    end

    local function get_damage_multiplier()
        local level_multiplier = 1. + math.max(0., average_level - CHAOS_ARMOR_LEVEL) * LATE_GAME_DAMAGE_PER_LEVEL
        return math.sqrt(get_wave_multiplier()) * level_multiplier
    end

    local function get_persistent_power(pid)
        local unit = Unit[Hero[pid]]
        local strength = unit.str
        local agility = unit.agi
        local intelligence = unit.int
        local items = Profile[pid].hero.items

        for slot = 1, 6 do
            local item = items[slot]
            if item and item.equipped then
                local modifier = ItemProfMod(item.id, pid)
                local stats = item.cached_stats
                strength = strength + math.floor(modifier * stats[ITEM_STRENGTH])
                agility = agility + math.floor(modifier * stats[ITEM_AGILITY])
                intelligence = intelligence + math.floor(modifier * stats[ITEM_INTELLIGENCE])
            end
        end

        return math.max(strength, agility, intelligence)
    end

    local function spawn_xy(rect)
        return GetRandomReal(GetRectMinX(rect), GetRectMaxX(rect)), GetRandomReal(GetRectMinY(rect), GetRectMaxY(rect))
    end

    local function configure_enemy(u, role, total_spawned)
        local count_multiplier = math.max(0.55, math.min(0.8, math.sqrt(12. / total_spawned)))
        local base_hp = average_power + average_level * 80.
        local base_damage = average_power + average_level * 5.
        local hp = base_hp * get_wave_multiplier() * party_health_multiplier * role.hp * count_multiplier
        local damage = base_damage * get_damage_multiplier() * party_damage_multiplier * role.damage * count_multiplier
        local armor = (average_power * STAT_ARMOR_PER_ATTRIBUTE + average_level * 0.75 + 1.5 * (wave - 1)) * role.armor

        if average_level >= CHAOS_ARMOR_LEVEL then
            BlzSetUnitIntegerField(u, UNIT_IF_DEFENSE_TYPE, ARMOR_CHAOS)
        end
        if average_level >= CHAOS_ATTACK_LEVEL then
            BlzSetUnitWeaponIntegerField(u, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, ATTACK_CHAOS)
            damage = damage / CHAOS_ATTACK_DAMAGE_MULTIPLIER
        end

        BlzSetUnitMaxHP(u, math.floor(math.min(MAX_ENEMY_HP, math.max(1., hp))))
        BlzSetUnitBaseDamage(u, math.floor(math.min(MAX_ENEMY_DAMAGE, math.max(1., damage))), 0)
        BlzSetUnitArmor(u, armor)
        SetWidgetLife(u, BlzGetUnitMaxHP(u))
        Unit[u].ms_percent = Unit[u].ms_percent + role.speed + math.min(0.35, wave * 0.005)

        local target = random_player_hero()
        if target then
            IssueTargetOrder(u, "attack", target)
        else
            IssuePointOrder(u, "attack", center_x, center_y)
        end
    end

    local function expire_fury(source, target)
        local state = fury_state[source]
        if state and state.target == target then
            fury_state[source] = nil
        end
    end

    local function clear_fury(source)
        local state = fury_state[source]
        if state then
            if state.callback then
                TimerQueue:disableCallback(state.callback)
            end
            fury_state[source] = nil
        end
        EVENT_ON_HIT_MULTIPLIER:unregister_unit_action(source, on_struggle_fury_hit)
    end

    on_struggle_fury_hit = function(source, target, amount)
        local state = fury_state[source]
        if not state then
            state = { target = target, stacks = 0 }
            fury_state[source] = state
        elseif state.target ~= target then
            if state.callback then
                TimerQueue:disableCallback(state.callback)
            end
            state.target = target
            state.stacks = 0
        end

        if state.stacks > 0 then
            amount.value = amount.value * (1. + FURY_DAMAGE_PER_STACK * state.stacks)
        end
        state.stacks = math.min(FURY_MAX_STACKS, state.stacks + 1)

        if state.callback then
            TimerQueue:disableCallback(state.callback)
        end
        state.callback = TimerQueue:callDelayed(FURY_RESET_TIME, expire_fury, source, target)
    end

    local function complete_wave()
        if not active or active_count ~= 0 or #spawn_queue ~= 0 or trickle_callback then
            return
        end

        completed_wave = wave
        if wave % CHECKPOINT_INTERVAL == 0 then
            begin_checkpoint()
        else
            schedule_wave(BETWEEN_WAVE_DELAY)
        end
    end

    local function remove_enemy(killed)
        clear_fury(killed)
        StruggleSpecials.cleanup(killed)
        TableRemove(enemies, killed)
        active_count = math.max(0, active_count - 1)
        TimerQueue:callDelayed(3., RemoveUnit, killed)

        complete_wave()
    end

    local function spawn_enemy(role)
        local skins = average_level >= CHAOS_ARMOR_LEVEL and chaos_skins or prechaos_skins
        local pool = skins[role.skin_type or role.type]
        local rect = spawn_rects[math.random(1, #spawn_rects)]
        local x, y = spawn_xy(rect)
        local skin = pool[math.random(1, #pool)]
        local is_ranged = role.ranged or role.type == "ranged"
        local template = is_ranged and RANGED_ENEMY_TEMPLATE or MELEE_ENEMY_TEMPLATE
        local u = BlzCreateUnitWithSkin(PLAYER_BOSS, template, x, y, GetRandomReal(0., 360.), skin)

        BlzSetUnitSkin(u, skin)
        BlzSetUnitName(u, GetObjectName(skin))
        BlzSetHeroProperName(u, GetObjectName(skin))
        if role.type == "ranged" then
            UnitAddAbility(u, FURY_SWIPES_ABILITY)
        end
        if is_ranged then
            BlzSetUnitWeaponRealField(u, UNIT_WEAPON_RF_ATTACK_RANGE, 0, RANGED_ATTACK_RANGE)
            BlzSetUnitRealField(u, UNIT_RF_ACQUISITION_RANGE, RANGED_ACQUISITION_RANGE)
        end
        if role.type == "ranged" then
            EVENT_ON_HIT_MULTIPLIER:register_unit_action(u, on_struggle_fury_hit)
        end
        enemies[#enemies + 1] = u
        active_count = active_count + 1
        configure_enemy(u, role, spawn_total)
        if role.special then
            StruggleSpecials.setup(u, role.special, random_player_hero)
        end
        EVENT_ON_UNIT_DEATH:register_unit_action(u, remove_enemy)
    end

    local function spawn_batch()
        trickle_callback = nil
        if not active then
            return
        end

        for _ = 1, math.min(TRICKLE_SIZE, #spawn_queue) do
            spawn_enemy(table.remove(spawn_queue))
        end

        if #spawn_queue > 0 then
            trickle_callback = TimerQueue:callDelayed(TRICKLE_INTERVAL, spawn_batch)
        elseif active_count == 0 then
            complete_wave()
        end
    end

    local function spawn_wave()
        wave_callback = nil
        if not active or #players == 0 then
            return
        end

        wave = wave + 1
        local formation = formations[math.random(1, #formations)]
        spawn_total = math.random(MIN_WAVE_UNITS, MAX_WAVE_UNITS)
        spawn_queue = {}
        local assigned = 0

        for index, role in ipairs(formation.roles) do
            local count = index == #formation.roles
                and (spawn_total - assigned)
                or math.floor(spawn_total * role.weight)
            assigned = assigned + count
            for _ = 1, count do
                spawn_queue[#spawn_queue + 1] = role
            end
        end

        if wave >= 2 then
            local special_count = math.min(3, 1 + (wave - 1) // 10)
            for _ = 1, special_count do
                local queue_index = math.random(1, #spawn_queue)
                spawn_queue[queue_index] = special_roles[math.random(1, #special_roles)]
            end
        end

        for index = #spawn_queue, 2, -1 do
            local swap = math.random(1, index)
            spawn_queue[index], spawn_queue[swap] = spawn_queue[swap], spawn_queue[index]
        end

        DisplayTextToTable(players, "|cffffcc00Struggle Wave " .. wave .. ":|r " .. formation.name .. " (" .. spawn_total .. " enemies)")
        spawn_batch()
    end

    schedule_wave = function(delay)
        if wave_callback then
            TimerQueue:disableCallback(wave_callback)
        end
        wave_callback = TimerQueue:callDelayed(delay, spawn_wave)
    end

    local function record_claim(pid, checkpoint_wave)
        local profile = Profile[pid]
        local hero_data = profile and profile.hero
        if not hero_data then
            return false
        end

        checkpoint_wave = math.min(MAX_SAVED_WAVE, checkpoint_wave)
        hero_data.struggle_best_wave = math.max(hero_data.struggle_best_wave or 0, checkpoint_wave)
        hero_data.struggle_claim_wave = math.max(hero_data.struggle_claim_wave or 0, checkpoint_wave)
        DisplayTextToPlayer(Player(pid - 1), 0., 0.,
            "Wave |cffffcc00" .. checkpoint_wave .. "|r Struggle reward secured. Visit the Prize Vendor to redeem it.")
        return true
    end

    local function clear_checkpoint_player(pid)
        if checkpoint_pending[pid] then
            checkpoint_pending[pid] = nil
            checkpoint_waiting = math.max(0, checkpoint_waiting - 1)
        end

        local dialog = checkpoint_dialogs[pid]
        if dialog then
            checkpoint_dialogs[pid] = nil
            dialog:destroy()
        end
    end

    local function resume_after_checkpoint()
        if not checkpoint_active or checkpoint_waiting > 0 then
            return
        end

        checkpoint_active = false
        if checkpoint_callback then
            TimerQueue:disableCallback(checkpoint_callback)
            checkpoint_callback = nil
        end

        if active and #players > 0 then
            DisplayTextToTable(players, "|cffffcc00The Struggle continues.|r The next reward is at wave "
                .. (wave + CHECKPOINT_INTERVAL) .. ".")
            schedule_wave(BETWEEN_WAVE_DELAY)
        end
    end

    local function resolve_checkpoint(pid, claim)
        if not checkpoint_active or not checkpoint_pending[pid] then
            return
        end

        clear_checkpoint_player(pid)
        if claim then
            record_claim(pid, completed_wave)
            remove_player(pid, false, true)
        end
        resume_after_checkpoint()
    end

    local function on_checkpoint_choice(dialog, _, claim)
        resolve_checkpoint(dialog.pid, claim == true)
    end

    local function checkpoint_timeout()
        checkpoint_callback = nil
        local pending = {}
        for pid in pairs(checkpoint_pending) do
            pending[#pending + 1] = pid
        end
        for index = 1, #pending do
            resolve_checkpoint(pending[index], true)
        end
    end

    begin_checkpoint = function()
        checkpoint_active = true
        checkpoint_waiting = #players
        checkpoint_pending = {}
        checkpoint_dialogs = {}

        DisplayTextToTable(players, "|cffffcc00Wave " .. completed_wave
            .. " checkpoint reached.|r Claim the reward or risk it by continuing.")

        for index = 1, #players do
            local pid = players[index]
            checkpoint_pending[pid] = true
            local dialog = DialogWindow.create(pid,
                "Struggle Wave " .. completed_wave .. " Cleared", on_checkpoint_choice, "struggle-checkpoint")
            dialog.cancellable = false
            dialog:addButton("Claim Wave " .. completed_wave .. " Reward and Leave", true,
                "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp")
            dialog:addButton("Continue and Risk Reward", false,
                "ReplaceableTextures\\CommandButtons\\BTNReplay-Play.blp")
            checkpoint_dialogs[pid] = dialog
            dialog:display()
        end

        checkpoint_callback = TimerQueue:callDelayed(CHECKPOINT_DECISION_TIME, checkpoint_timeout)
    end

    remove_player = function(pid, defeated, claimed)
        if not TableHas(players, pid) then
            return
        end

        clear_checkpoint_player(pid)
        TableRemove(players, pid)
        set_exit_visible(pid, false)
        EVENT_ON_CLEANUP:unregister_action(pid, on_cleanup)
        EVENT_GRAVE_DEATH:unregister_unit_action(Hero[pid], on_grave_death)

        DisableBackpackTeleports(pid, false)
        DisableItems(pid, false)
        Unit[Hero[pid]].death_exception = defeated == true

        if defeated or not UnitAlive(Hero[pid]) then
            RevivePlayer(pid, TOWN_CENTER_X, TOWN_CENTER_Y, 1., 1.)
        else
            MoveHero(pid, TOWN_CENTER_X, TOWN_CENTER_Y)
        end
        SetCamera(pid, MAIN_MAP.rect)

        if active and not claimed then
            local message = defeated
                and "You were defeated and lost this Struggle's unclaimed reward."
                or "You fled the Struggle without claiming a reward."
            DisplayTextToPlayer(Player(pid - 1), 0., 0., message)
        end

        if #players == 0 then
            end_run()
        else
            resume_after_checkpoint()
        end
    end

    on_grave_death = function(killed)
        local pid = GetPlayerId(GetOwningPlayer(killed)) + 1
        remove_player(pid, true)
    end

    on_cleanup = function(pid)
        remove_player(pid, false)
    end

    local function enter(pid)
        if TableHas(players, pid) or not Hero[pid] or not UnitAlive(Hero[pid]) then
            return false
        end

        players[#players + 1] = pid
        DisableItems(pid, true)
        DisableBackpackTeleports(pid, true)
        MoveHero(pid, center_x, center_y)
        set_exit_visible(pid, true)
        EVENT_ON_CLEANUP:register_action(pid, on_cleanup)
        EVENT_GRAVE_DEATH:register_unit_action(Hero[pid], on_grave_death)

        if entry_open and #players >= User.AmountPlaying then
            begin_run()
        end

        return true
    end

    begin_run = function()
        if entry_callback then
            TimerQueue:disableCallback(entry_callback)
            entry_callback = nil
        end
        if #players == 0 then
            end_run()
            return
        end

        local total_level = 0.
        local total_power = 0.
        for _, pid in ipairs(players) do
            local hero = Hero[pid]
            total_level = total_level + GetUnitLevel(hero)
            total_power = total_power + get_persistent_power(pid)
        end

        average_level = total_level / #players
        average_power = total_power / #players
        party_health_multiplier = 1. + 0.6 * (#players - 1)
        party_damage_multiplier = 1. + 0.08 * (#players - 1)
        entry_open = false
        active = true
        DisplayTextToTable(players, "|cffffcc00The Infinite Struggle begins.|r Rewards may be claimed every five waves; emergency fleeing forfeits the run.")
        SoundHandler("Sound\\Interface\\BattleNetDoorsStereo2.flac", false)
        schedule_wave(FIRST_WAVE_DELAY)
    end

    end_run = function()
        if entry_callback then
            TimerQueue:disableCallback(entry_callback)
            entry_callback = nil
        end
        if wave_callback then
            TimerQueue:disableCallback(wave_callback)
            wave_callback = nil
        end
        if trickle_callback then
            TimerQueue:disableCallback(trickle_callback)
            trickle_callback = nil
        end
        if checkpoint_callback then
            TimerQueue:disableCallback(checkpoint_callback)
            checkpoint_callback = nil
        end

        for pid, dialog in pairs(checkpoint_dialogs) do
            checkpoint_dialogs[pid] = nil
            dialog:destroy()
        end

        entry_open = false
        active = false
        checkpoint_active = false
        checkpoint_waiting = 0
        checkpoint_pending = {}
        for _, u in ipairs(enemies) do
            clear_fury(u)
            StruggleSpecials.cleanup(u)
            RemoveUnit(u)
        end
        enemies = {}
        active_count = 0
        spawn_queue = {}
        spawn_total = 0
        players = {}
        wave = 0
        completed_wave = 0
        average_level = 1.
        average_power = 1.
        party_health_multiplier = 1.
        party_damage_multiplier = 1.
        checkpoint_dialogs = {}
    end

    local function on_exit_click()
        local player = GetTriggerPlayer()
        local pid = GetPlayerId(player) + 1
        if GetLocalPlayer() == player then
            local frame = BlzGetTriggerFrame()
            BlzFrameSetEnable(frame, false)
            BlzFrameSetEnable(frame, true)
        end
        remove_player(pid, false)
        return false
    end

    exit_button = SimpleButton.create(
        BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0),
        "war3mapImported\\ExitButton.blp",
        0.03,
        0.015,
        FRAMEPOINT_TOP,
        FRAMEPOINT_TOP,
        0.,
        0.015,
        on_exit_click,
        "Flee the Infinite Struggle. Leaving outside a checkpoint forfeits the current reward."
    )
    BlzFrameClearAllPoints(exit_button.frame)
    BlzFrameSetPoint(
        exit_button.frame,
        FRAMEPOINT_CENTER,
        BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0),
        FRAMEPOINT_CENTER,
        0.,
        -0.154
    )
    exit_button:visible(false)

    ITEM_LOOKUP[ENTRY_ITEM] = function(player, pid, _, item)
        if item and item.alive then
            item:destroy()
        end

        if active then
            DisplayTextToPlayer(player, 0., 0., "The Infinite Struggle is already active.")
            return
        end
        if entry_open then
            enter(pid)
            return
        end

        wave = 0
        completed_wave = 0
        players = {}
        entry_open = true
        DisplayTextToForce(FORCE_PLAYING, User[pid - 1].nameColored .. " has opened the Infinite Struggle for 45 seconds.")
        entry_callback = TimerQueue:callDelayed(ENTRY_DURATION, begin_run)
        enter(pid)
    end

    function Struggle.isActive()
        return active
    end

    function Struggle.getWave()
        return wave
    end

    function Struggle.getCompletedWave()
        return completed_wave
    end

    function Struggle.getBestWave(pid)
        local profile = Profile[pid]
        return profile and profile.hero and (profile.hero.struggle_best_wave or 0) or 0
    end

    function Struggle.getClaimWave(pid)
        local profile = Profile[pid]
        return profile and profile.hero and (profile.hero.struggle_claim_wave or 0) or 0
    end

    function Struggle.consumeClaim(pid, expected_wave)
        local profile = Profile[pid]
        local hero_data = profile and profile.hero
        local claim_wave = hero_data and (hero_data.struggle_claim_wave or 0) or 0
        if claim_wave <= 0 or (expected_wave and claim_wave ~= expected_wave) then
            return false
        end

        hero_data.struggle_claim_wave = 0
        return true
    end
end, Debug and Debug.getLine())
