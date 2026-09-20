-- Shared scheduling and runtime for faction-wide hourly events.

OnInit.final("FactionEvents", function(Require)
    Require('Faction')
    Require('FactionMining')
    Require('Currency')
    Require('Events')
    Require('MainMap')
    Require('Pathing')
    Require('TimerQueue')
    Require('UnitTable')
    Require('Users')
    Require('Variables')

    FactionEvents = {}

    local CAVE_VOYAGERS_ID = 1
    local EVENT_INTERVAL = 3600.
    local EVENT_WARNING = 300.
    local EVENT_TIMEOUT = 720.
    local EVENT_RADIUS = 2600.
    local SPAWN_MIN_RADIUS = 1400.
    local SPAWN_MAX_RADIUS = 1900.
    local WAVE_INTERVAL = 60.
    local TOTAL_WAVES = 5
    local PRESENCE_REWARD_THRESHOLD = 30
    local POINT_REWARD = 30
    local REPUTATION_REWARD = 30
    local MELEE_TEMPLATE = FourCC('n002')
    local RANGED_TEMPLATE = FourCC('n008')
    local CACHE_MODEL = "Objects\\InventoryItems\\TreasureChest\\treasurechest.mdl"
    local skins = {
        melee = { FourCC('n03C'), FourCC('n033'), FourCC('n03E'), FourCC('n03A') },
        ranged = { FourCC('n01W'), FourCC('n00W'), FourCC('n02J') },
    }

    local activated = false
    local active = false
    local wave = 0
    local objective ---@type unit?
    local objective_effect ---@type effect?
    local enemies = setmetatable({}, { __mode = 'k' })
    local enemy_count = 0
    local contribution = {}
    local next_event_callback ---@type integer?
    local warning_callback ---@type integer?
    local wave_callback ---@type integer?
    local timeout_callback ---@type integer?
    local presence_callback ---@type integer?

    local start_event, finish_event

    local function format_time(time)
        local total = math.max(0, math.ceil(time))
        local hours = total // 3600
        local minutes = (total % 3600) // 60
        local seconds = total % 60
        if hours > 0 then
            return string.format("%d:%02d:%02d", hours, minutes, seconds)
        end
        return string.format("%d:%02d", minutes, seconds)
    end

    local function member_faction(pid)
        local faction = Faction.getFaction(pid)
        return faction and faction.id == CAVE_VOYAGERS_ID
    end

    local function announce(message, sound)
        local user = User.first
        while user do
            if member_faction(user.id) then
                DisplayTextToPlayer(user.player, 0., 0., message)
                if sound then
                    StartSoundForPlayerBJ(user.player, sound)
                end
            end
            user = user.next
        end
    end

    local function disable_callback(callback)
        if callback then
            TimerQueue:disableCallback(callback)
        end
    end

    local function clear_runtime_callbacks()
        disable_callback(wave_callback)
        disable_callback(timeout_callback)
        disable_callback(presence_callback)
        wave_callback = nil
        timeout_callback = nil
        presence_callback = nil
    end

    local function cleanup_units()
        for enemy in pairs(enemies) do
            RemoveUnit(enemy)
        end
        enemies = setmetatable({}, { __mode = 'k' })
        enemy_count = 0
        if objective then
            RemoveUnit(objective)
            objective = nil
        end
        if objective_effect then
            DestroyEffect(objective_effect)
            objective_effect = nil
        end
    end

    local function schedule_event()
        disable_callback(next_event_callback)
        disable_callback(warning_callback)
        next_event_callback = TimerQueue:callDelayed(EVENT_INTERVAL, start_event)
        warning_callback = TimerQueue:callDelayed(EVENT_INTERVAL - EVENT_WARNING, function()
            warning_callback = nil
            announce("|cffffcc00Faction Event:|r Hold the Line begins in 5 minutes.",
                bj_questWarningSound)
        end)
    end

    local function event_center()
        local faction = Faction[CAVE_VOYAGERS_ID]
        if not faction or not faction.leader then return nil end
        return GetUnitX(faction.leader), GetUnitY(faction.leader)
    end

    local function event_members(nearby_only)
        local members = {}
        local x, y = event_center()
        local user = User.first
        while user do
            local hero = Hero[user.id]
            if member_faction(user.id) and hero and UnitAlive(hero)
                and (not nearby_only
                    or DistanceCoords(x, y, GetUnitX(hero), GetUnitY(hero)) <= EVENT_RADIUS) then
                members[#members + 1] = user.id
            end
            user = user.next
        end
        return members
    end

    local function event_strength()
        local members = event_members(true)
        local total_level = 0
        for index = 1, #members do
            total_level = total_level + GetHeroLevel(Hero[members[index]])
        end
        return math.max(1, #members),
            #members > 0 and math.max(1, math.floor(total_level / #members)) or 200
    end

    local function spawn_location(center_x, center_y)
        for _ = 1, 24 do
            local angle = math.random() * 2. * bj_PI
            local distance = GetRandomReal(SPAWN_MIN_RADIUS, SPAWN_MAX_RADIUS)
            local x = center_x + distance * math.cos(angle)
            local y = center_y + distance * math.sin(angle)
            if RectContainsCoords(MAIN_MAP.rect, x, y) and IsTerrainWalkable(x, y) then
                return x, y
            end
        end
        return center_x - SPAWN_MIN_RADIUS, center_y
    end

    local function record_kill(killer)
        if not killer then return end
        local pid = GetPlayerId(GetOwningPlayer(killer)) + 1
        if pid <= PLAYER_CAP and member_faction(pid) then
            local data = contribution[pid] or { presence = 0, kills = 0 }
            contribution[pid] = data
            data.kills = data.kills + 1
        end
    end

    local function on_enemy_death(killed, killer)
        if not enemies[killed] then return end
        enemies[killed] = nil
        enemy_count = math.max(0, enemy_count - 1)
        record_kill(killer)
        TimerQueue:callDelayed(3., RemoveUnit, killed)
        if active and wave >= TOTAL_WAVES and enemy_count == 0 then
            finish_event(true)
        end
    end

    local function configure_enemy(unit, level, party_size, count, ranged)
        local extra_players = math.max(0, party_size - 1)
        local wave_multiplier = 0.8 + wave * 0.2
        local count_multiplier = math.max(0.6, math.sqrt(10. / math.max(1, count)))
        -- Twenty times less health than the first prototype. A level-400 solo
        -- wave now starts near 2.2 million health per enemy instead of 44m;
        -- party size, wave pressure, and enemy count still scale separately.
        local hp = (15000. + level * level * 15.)
            * (1. + extra_players * 0.55) * wave_multiplier * count_multiplier
        local damage = (250. + level * level * 0.45)
            * (1. + extra_players * 0.18) * wave_multiplier * count_multiplier
        local armor = level * (0.55 + wave * 0.08)

        BlzSetUnitMaxHP(unit, math.floor(math.min(2000000000., hp)))
        SetWidgetLife(unit, BlzGetUnitMaxHP(unit))
        BlzSetUnitBaseDamage(unit, math.max(1,
            math.floor(damage / CHAOS_ATTACK_DAMAGE_MULTIPLIER)), 0)
        BlzSetUnitArmor(unit, armor)
        BlzSetUnitIntegerField(unit, UNIT_IF_DEFENSE_TYPE, ARMOR_CHAOS)
        BlzSetUnitWeaponIntegerField(unit,
            UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, ATTACK_CHAOS)
        BlzSetUnitIntegerField(unit, UNIT_IF_LEVEL, level)
        Unit[unit].ms_percent = Unit[unit].ms_percent + 0.08 + wave * 0.02
        if ranged then
            SetUnitVertexColor(unit, 130, 170, 255, 255)
            SetUnitScale(unit, 1.12, 1.12, 1.12)
        end
    end

    local function spawn_enemy(center_x, center_y, level, party_size, count, index)
        local ranged = index % 4 == 0
        local pool = ranged and skins.ranged or skins.melee
        local skin = pool[math.random(1, #pool)]
        local x, y = spawn_location(center_x, center_y)
        local unit = BlzCreateUnitWithSkin(PLAYER_BOSS,
            ranged and RANGED_TEMPLATE or MELEE_TEMPLATE,
            x, y, bj_RADTODEG * Atan2(center_y - y, center_x - x), skin)
        BlzSetUnitSkin(unit, skin)
        BlzSetUnitName(unit, GetObjectName(skin))
        BlzSetHeroProperName(unit, GetObjectName(skin))
        configure_enemy(unit, level, party_size, count, ranged)
        enemies[unit] = true
        enemy_count = enemy_count + 1
        EVENT_ON_UNIT_DEATH:register_unit_action(unit, on_enemy_death)
        IssueTargetOrder(unit, "attack", objective)
    end

    local function spawn_wave()
        wave_callback = nil
        if not active or not objective or not UnitAlive(objective) then return end
        wave = wave + 1
        local party_size, level = event_strength()
        local count = 7 + wave * 2 + party_size * 3
        local x, y = GetUnitX(objective), GetUnitY(objective)
        announce("|cffffcc00Hold the Line:|r Wave " .. wave .. " / " .. TOTAL_WAVES)
        for index = 1, count do
            spawn_enemy(x, y, level, party_size, count, index)
        end
        if wave < TOTAL_WAVES then
            wave_callback = TimerQueue:callDelayed(WAVE_INTERVAL, spawn_wave)
        elseif enemy_count == 0 then
            finish_event(true)
        end
    end

    local function presence_tick()
        presence_callback = nil
        if not active then return end
        local members = event_members(true)
        for index = 1, #members do
            local pid = members[index]
            local data = contribution[pid] or { presence = 0, kills = 0 }
            contribution[pid] = data
            data.presence = data.presence + 1
        end
        presence_callback = TimerQueue:callDelayed(1., presence_tick)
    end

    local function on_objective_death()
        if active then
            finish_event(false)
        end
    end

    finish_event = function(success)
        if not active then return false end
        active = false
        clear_runtime_callbacks()

        if success then
            local rewarded = 0
            for pid, data in pairs(contribution) do
                if member_faction(pid)
                    and (data.presence >= PRESENCE_REWARD_THRESHOLD or data.kills > 0) then
                    AddCurrency(pid, FACTION, POINT_REWARD)
                    Faction.addReputation(pid, REPUTATION_REWARD)
                    Quest.progress(pid, "faction_event")
                    StartSoundForPlayerBJ(Player(pid - 1), bj_questCompletedSound)
                    rewarded = rewarded + 1
                end
            end
            announce("|cff80ff80Hold the Line complete!|r " .. rewarded
                .. " participant" .. (rewarded == 1 and " was" or "s were") .. " rewarded.")
        else
            announce("|cffff4040Hold the Line failed.|r The Cave Voyagers' supply cache was destroyed.",
                bj_questFailedSound)
        end

        cleanup_units()
        contribution = {}
        wave = 0
        schedule_event()
        return true
    end

    start_event = function()
        next_event_callback = nil
        disable_callback(warning_callback)
        warning_callback = nil
        if active or not CHAOS_MODE then
            schedule_event()
            return false
        end

        local faction = Faction[CAVE_VOYAGERS_ID]
        local center_x, center_y = event_center()
        if not faction or not center_x then
            schedule_event()
            return false
        end

        active = true
        wave = 0
        contribution = {}
        local party_size, level = event_strength()
        objective = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE),
            FactionMining.RAWCODES.deposit, center_x + 250., center_y, 270.)
        BlzSetUnitName(objective, "Cave Voyagers Supply Cache")
        SetUnitPathing(objective, false)
        PauseUnit(objective, true)
        SetUnitInvulnerable(objective, false)
        BlzSetUnitWeaponBooleanField(objective, UNIT_WEAPON_BF_ATTACKS_ENABLED, 0, false)
        SetUnitVertexColor(objective, 255, 255, 255, 0)
        objective_effect = AddSpecialEffect(CACHE_MODEL,
            GetUnitX(objective), GetUnitY(objective))
        BlzSetSpecialEffectScale(objective_effect, 1.75)
        local max_health = math.min(2000000000.,
            (100000. + level * level * 800.) * (1. + math.max(0, party_size - 1) * 0.4))
        BlzSetUnitMaxHP(objective, math.floor(max_health))
        SetWidgetLife(objective, max_health)
        EVENT_ON_UNIT_DEATH:register_unit_action(objective, on_objective_death)

        announce("|cffffcc00Faction Event: Hold the Line|r\nDefend the Cave Voyagers' supply cache against five assault waves.",
            bj_questDiscoveredSound)
        presence_tick()
        timeout_callback = TimerQueue:callDelayed(EVENT_TIMEOUT, finish_event, false)
        wave_callback = TimerQueue:callDelayed(10., spawn_wave)
        return true
    end

    function FactionEvents.activate()
        if activated then return false end
        activated = true
        schedule_event()
        return true
    end

    ---@param pid integer
    ---@return string
    function FactionEvents.getStatus(pid)
        if not activated then
            return "|cff808080Events become available after Chaos.|r"
        end
        if active then
            return "|cffffcc00Hold the Line|r\n\nDefend the Cave Voyagers' supply cache "
                .. "against five assault waves.\n\n|cff80ff80Event in progress.|r"
        end
        local remaining = next_event_callback and TimerQueue:getRemaining(next_event_callback) or 0.
        return "|cffffcc00Hold the Line|r\n\nDefend the Cave Voyagers' supply cache "
            .. "against five assault waves.\n\n|cffffcc00Begins in:|r "
            .. format_time(remaining or 0.)
    end

    ---@param pid integer
    ---@return string?
    function FactionEvents.getHudStatus(pid)
        if not active or not member_faction(pid) then return nil end
        local health = objective and GetWidgetLife(objective) or 0.
        local max_health = objective and BlzGetUnitMaxHP(objective) or 1.
        local remaining = timeout_callback and TimerQueue:getRemaining(timeout_callback) or 0.
        local progress = wave > 0 and ("Wave " .. wave .. " / " .. TOTAL_WAVES)
            or "First wave incoming"
        return "|cffffcc00Hold the Line|r  |  " .. progress
            .. "\nSupply Cache: " .. math.max(0, math.floor(health / max_health * 100.)) .. "%"
            .. "  |  " .. format_time(remaining or 0.)
    end

    if DEV_ENABLED then
        function FactionEvents.startNow()
            disable_callback(next_event_callback)
            disable_callback(warning_callback)
            next_event_callback = nil
            warning_callback = nil
            if active then
                finish_event(false)
                disable_callback(next_event_callback)
                disable_callback(warning_callback)
                next_event_callback = nil
                warning_callback = nil
            end
            return start_event()
        end
    end

    if CHAOS_MODE then
        FactionEvents.activate()
    end
end, Debug and Debug.getLine())
