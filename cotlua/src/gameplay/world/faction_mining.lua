-- Cave Voyagers deposit spawning, extraction channels, and guardian encounters.

OnInit.final("FactionMining", function(Require)
    Require('Faction')
    Require('MainMap')
    Require('Events')
    Require('TimerQueue')
    Require('Users')
    Require('Currency')
    Require('UnitTable')
    Require('Damage')

    FactionMining = {}

    -- Common, rich, and ancient deposits share one object-editor record. Their
    -- names and presentation are assigned from deposit_types when they spawn.
    FactionMining.RAWCODES = {
        deposit = FourCC('n0MD'),
        guardian = FourCC('n0MG'),
    }

    local CAVE_VOYAGERS_ID = 1
    local INTERACTION_RANGE = 350.
    local CHANNEL_MOVE_TOLERANCE = 24.
    local CHANNEL_TICK = 0.1
    local DEPOSIT_RESPAWN = 180.
    local GUARDIAN_SHARE_RANGE = 1800.
    local GUARDIAN_POINT_REWARD = 2
    local GUARDIAN_REPUTATION_REWARD = 2
    local deposits = setmetatable({}, { __mode = 'k' })
    local active_mining = {}
    local guardians = setmetatable({}, { __mode = 'k' })
    local active = false
    local warned_missing_data = false

    local deposit_types = {
        common = {
            key = "common",
            name = "Common Deposit",
            duration = 4.,
            reputation = 1,
            ore = 1,
            required_rank = 1,
            guardian_chance = 15,
            color = { 210, 210, 210 },
            scale = 1.,
        },
        rich = {
            key = "rich",
            name = "Rich Deposit",
            duration = 8.,
            reputation = 3,
            ore = 3,
            required_rank = 2,
            guardian_chance = 35,
            color = { 255, 210, 70 },
            scale = 1.15,
        },
        rare = {
            key = "rare",
            name = "Ancient Deposit",
            duration = 30.,
            reputation = 8,
            ore = 8,
            required_rank = 5,
            guardian_chance = 0,
            color = { 90, 160, 255 },
            scale = 1.35,
            ambush_times = { 5., 12., 20. },
        },
    }

    -- Deposits deliberately use existing late-game overworld regions instead
    -- of arbitrary map coordinates. This keeps them reachable and lets future
    -- terrain revisions move the mining routes without changing this system.
    local mining_regions = {
        gg_rct_Hell_1,
        gg_rct_Hell_3,
        gg_rct_Centaur_Nightmare_2,
        gg_rct_Centaur_Nightmare_4,
        gg_rct_Magnataur_Despair_1,
        gg_rct_Dragon_Astral_2,
        gg_rct_Dragon_Astral_5,
        gg_rct_Devourer_Existence_1,
    }

    local function current_faction_id(pid)
        local faction = Faction.getFaction(pid)
        return faction and faction.id or 0
    end

    local function valid_spawn_point(x, y)
        return RectContainsCoords(MAIN_MAP.rect, x, y)
            and not RectContainsCoords(gg_rct_Town_Main, x, y)
            and IsTerrainWalkable(x, y)
    end

    local function random_location()
        local first = math.random(1, #mining_regions)
        for offset = 0, #mining_regions - 1 do
            local region_index = (first + offset - 1) % #mining_regions + 1
            local rect = mining_regions[region_index]
            for _ = 1, 12 do
                local x = GetRandomReal(GetRectMinX(rect) + 96., GetRectMaxX(rect) - 96.)
                local y = GetRandomReal(GetRectMinY(rect) + 96., GetRectMaxY(rect) - 96.)
                if valid_spawn_point(x, y) then
                    return x, y, region_index
                end
            end
        end
        return nil
    end

    local spawn_deposit

    local function show_missing_data_warning()
        if warned_missing_data then return end
        warned_missing_data = true
        print("|cffffcc00FactionMining:|r deposit or guardian object data is missing.")
    end

    local function respawn_deposit(kind)
        if active then
            spawn_deposit(kind)
        end
    end

    local function remove_deposit(deposit, respawn)
        local unit = deposit.unit
        if unit then
            EVENT_ON_UNIT_SELECT:unregister_unit_action(unit)
            deposits[unit] = nil
            RemoveUnit(unit)
            deposit.unit = nil
        end
        if respawn then
            TimerQueue:callDelayed(DEPOSIT_RESPAWN, respawn_deposit, deposit.kind)
        end
    end

    local function guardian_death(killed)
        local data = guardians[killed]
        if not data then return end
        guardians[killed] = nil
        local x, y = GetUnitX(killed), GetUnitY(killed)

        local user = User.first
        while user do
            local pid = user.id
            local hero = Hero[pid]
            if hero and UnitAlive(hero)
                and current_faction_id(pid) == CAVE_VOYAGERS_ID
                and DistanceCoords(x, y, GetUnitX(hero), GetUnitY(hero)) <= GUARDIAN_SHARE_RANGE then
                AddCurrency(pid, FACTION, GUARDIAN_POINT_REWARD)
                Faction.addReputation(pid, GUARDIAN_REPUTATION_REWARD)
                Quest.progress(pid, "mining_guardian")
                if data.rare then
                    Quest.progress(pid, "rare_guardian")
                end
                local level = math.max(1, GetHeroLevel(hero))
                AwardGold(pid, 5000 + level * level * 100, true)
            end
            user = user.next
        end

        TimerQueue:callDelayed(3., RemoveUnit, killed)
    end

    local function spawn_guardian(x, y, pid, rare)
        local angle = math.random() * 2. * bj_PI
        local distance = math.random(325, 475)
        local guardian = CreateUnit(PLAYER_CREEP, FactionMining.RAWCODES.guardian,
            x + distance * math.cos(angle), y + distance * math.sin(angle), angle * bj_RADTODEG + 180.)
        if not guardian or GetUnitTypeId(guardian) == 0 then
            show_missing_data_warning()
            return nil
        end

        local level = Hero[pid] and GetHeroLevel(Hero[pid]) or 1
        local hp = math.min(2000000000, 5000 + level * level * 200)
        BlzSetUnitMaxHP(guardian, math.floor(hp))
        SetWidgetLife(guardian, hp)
        local desired_damage = 500. + level * level * 0.5
        BlzSetUnitBaseDamage(guardian,
            math.max(1, math.floor(desired_damage / CHAOS_ATTACK_DAMAGE_MULTIPLIER)), 0)
        BlzSetUnitWeaponBooleanField(guardian, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, true)
        SetUnitAcquireRange(guardian, 800.)
        BlzSetUnitArmor(guardian, level * 0.75)
        BlzSetUnitIntegerField(guardian, UNIT_IF_DEFENSE_TYPE, ARMOR_CHAOS)
        BlzSetUnitWeaponIntegerField(guardian,
            UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, ATTACK_CHAOS)
        BlzSetUnitIntegerField(guardian, UNIT_IF_LEVEL, level)
        SetUnitColor(guardian, rare and PLAYER_COLOR_PURPLE or PLAYER_COLOR_YELLOW)
        SetUnitScale(guardian, rare and 1.35 or 1.1, rare and 1.35 or 1.1, rare and 1.35 or 1.1)
        guardians[guardian] = { rare = rare == true }
        EVENT_ON_UNIT_DEATH:register_unit_action(guardian, guardian_death)
        if Hero[pid] then
            IssueTargetOrder(guardian, "attack", Hero[pid])
        end
        return guardian
    end

    local function destroy_progress_tag(state)
        if state.tag then
            DestroyTextTag(state.tag)
            state.tag = nil
        end
    end

    local function finish_mining_state(state)
        local deposit = state.deposit
        if deposit and deposit.miner_pid == state.pid then
            deposit.miner_pid = nil
        end
        active_mining[state.pid] = nil
        EVENT_ON_STRUCK_FINAL:unregister_unit_action(state.hero, state.damage_action)
        destroy_progress_tag(state)
        if UnitAlive(state.hero) then
            SetUnitAnimation(state.hero, "stand")
        end
    end

    local function cancel_mining(state, message)
        if active_mining[state.pid] ~= state then return end
        finish_mining_state(state)
        if message then
            DisplayTextToPlayer(Player(state.pid - 1), 0., 0., message)
        end
    end

    local function complete_mining(state)
        if active_mining[state.pid] ~= state then return end
        local deposit = state.deposit
        local config = deposit.config
        local x, y = GetUnitX(deposit.unit), GetUnitY(deposit.unit)
        finish_mining_state(state)

        Faction.addReputation(state.pid, config.reputation)
        Quest.progress(state.pid, "mine_any")
        Quest.progress(state.pid, "mine_" .. config.key)
        Quest.progress(state.pid, "mine_ore", config.ore)
        Quest.progressUnique(state.pid, "mining_region", deposit.region_index)
        if config.key == "rare" then
            Quest.progress(state.pid, "rare_extraction")
        end

        DisplayTextToPlayer(Player(state.pid - 1), 0., 0., "Mined " .. config.name
            .. ": |cffffcc00+" .. config.reputation .. " Reputation|r and "
            .. config.ore .. " ore sample" .. (config.ore == 1 and "." or "s."))
        DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Other\\Transmute\\PileofGold.mdl", x, y))

        remove_deposit(deposit, true)
        if config.guardian_chance > 0 and math.random(1, 100) <= config.guardian_chance then
            spawn_guardian(x, y, state.pid, false)
        end
    end

    local function update_progress_tag(state)
        local remaining = math.max(0., state.deposit.config.duration - state.elapsed)
        SetTextTagText(state.tag, string.format("Mining %.1fs", remaining), 0.022)
        SetTextTagPosUnit(state.tag, state.hero, 40.)
    end

    local function mining_tick(state)
        if active_mining[state.pid] ~= state then return end
        local hero = state.hero
        local deposit = state.deposit
        if not UnitAlive(hero) or not deposit.unit or GetUnitTypeId(deposit.unit) == 0 then
            cancel_mining(state)
            return
        end
        if current_faction_id(state.pid) ~= CAVE_VOYAGERS_ID then
            cancel_mining(state, "Mining interrupted: you are no longer a Cave Voyager.")
            return
        end
        if state.interrupted then
            cancel_mining(state, "Mining interrupted by damage.")
            return
        end
        if DistanceCoords(state.start_x, state.start_y, GetUnitX(hero), GetUnitY(hero)) > CHANNEL_MOVE_TOLERANCE
            or not IsUnitInRange(hero, deposit.unit, INTERACTION_RANGE + 75.) then
            cancel_mining(state, "Mining interrupted by movement.")
            return
        end

        state.elapsed = state.elapsed + CHANNEL_TICK
        local ambush_times = deposit.config.ambush_times
        if ambush_times and state.next_ambush <= #ambush_times
            and state.elapsed >= ambush_times[state.next_ambush] then
            spawn_guardian(GetUnitX(deposit.unit), GetUnitY(deposit.unit), state.pid, true)
            state.next_ambush = state.next_ambush + 1
            deposit.next_ambush = state.next_ambush
        end
        if state.elapsed + 0.001 >= deposit.config.duration then
            complete_mining(state)
            return
        end

        update_progress_tag(state)
        state.callback = TimerQueue:callDelayed(CHANNEL_TICK, mining_tick, state)
    end

    local function start_mining(deposit, pid)
        local hero = Hero[pid]
        if not hero or not UnitAlive(hero) then return end
        if current_faction_id(pid) ~= CAVE_VOYAGERS_ID then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "Only active Cave Voyagers may mine deposits.")
            return
        end
        local rank = Faction.getRank(Faction.getReputation(pid, CAVE_VOYAGERS_ID))
        if rank < deposit.config.required_rank then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., deposit.config.name
                .. " requires Cave Voyagers Rank " .. deposit.config.required_rank .. ".")
            return
        end
        if not IsUnitInRange(hero, deposit.unit, INTERACTION_RANGE) then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "Move closer to the deposit before mining it.")
            return
        end
        if deposit.miner_pid and deposit.miner_pid ~= pid then
            DisplayTextToPlayer(Player(pid - 1), 0., 0., "Another player is already mining this deposit.")
            return
        end
        if active_mining[pid] then
            cancel_mining(active_mining[pid], "Previous mining attempt cancelled.")
        end

        local state = {
            pid = pid,
            hero = hero,
            deposit = deposit,
            elapsed = 0.,
            next_ambush = deposit.next_ambush or 1,
            start_x = GetUnitX(hero),
            start_y = GetUnitY(hero),
        }
        state.damage_action = function(_, _, _, final_amount)
            if final_amount > BlzGetUnitMaxHP(hero) * 0.001 then
                state.interrupted = true
            end
        end
        state.tag = CreateTextTag()
        SetTextTagColor(state.tag, 255, 220, 80, 255)
        SetTextTagPermanent(state.tag, true)
        SetTextTagVisibility(state.tag, GetLocalPlayer() == Player(pid - 1))
        deposit.miner_pid = pid
        active_mining[pid] = state
        EVENT_ON_STRUCK_FINAL:register_unit_action(hero, state.damage_action)
        SetUnitAnimation(hero, "spell")
        update_progress_tag(state)
        state.callback = TimerQueue:callDelayed(CHANNEL_TICK, mining_tick, state)
    end

    local function on_deposit_selected(selected, pid)
        local deposit = deposits[selected]
        if not deposit then return end
        if GetLocalPlayer() == Player(pid - 1) then
            SelectUnit(selected, false)
            if Hero[pid] then SelectUnit(Hero[pid], true) end
        end
        start_mining(deposit, pid)
    end

    spawn_deposit = function(kind, x, y, region_index)
        local config = deposit_types[kind]
        if not x then
            x, y, region_index = random_location()
        end
        if not config or not x then return false end
        local unit = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), FactionMining.RAWCODES.deposit,
            x, y, math.random(0, 359))
        if not unit or GetUnitTypeId(unit) == 0 then
            show_missing_data_warning()
            return false
        end

        PauseUnit(unit, true)
        SetUnitPathing(unit, false)
        SetUnitInvulnerable(unit, true)
        SetUnitAcquireRange(unit, 0.)
        BlzSetUnitWeaponBooleanField(unit, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, false)
        Unit[unit].hidehp = true
        BlzSetUnitName(unit, config.name)
        SetUnitVertexColor(unit, config.color[1], config.color[2], config.color[3], 255)
        SetUnitScale(unit, config.scale, config.scale, config.scale)
        local deposit = {
            unit = unit,
            kind = kind,
            config = config,
            region_index = region_index,
            next_ambush = 1,
        }
        deposits[unit] = deposit
        EVENT_ON_UNIT_SELECT:register_unit_action(unit, on_deposit_selected)
        return true
    end

    local function cleanup_player(pid)
        if active_mining[pid] then
            cancel_mining(active_mining[pid])
        end
    end

    ---Spawns the initial rotating deposit population after Chaos begins.
    function FactionMining.activate()
        if active then return false end
        active = true
        for _ = 1, 8 do spawn_deposit("common") end
        for _ = 1, 3 do spawn_deposit("rich") end
        spawn_deposit("rare")
        return true
    end

    if DEV_ENABLED then
        ---Spawns a deposit immediately for object-data and interaction testing.
        ---@param kind "common"|"rich"|"rare"
        function FactionMining.spawn(kind, x, y)
            return spawn_deposit(kind, x, y, 0)
        end
    end

    local user = User.first
    while user do
        EVENT_ON_CLEANUP:register_action(user.id, cleanup_player)
        user = user.next
    end

    if CHAOS_MODE then
        FactionMining.activate()
    end
end, Debug and Debug.getLine())
