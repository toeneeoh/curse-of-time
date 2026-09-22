-- Stormwatch membership, weather progression, quests, and hourly event.

OnInit.final("Stormwatch", function(Require)
    Require('Faction')
    Require('FactionEvents')
    Require('Currency')
    Require('Events')
    Require('MainMap')
    Require('Pathing')
    Require('TimerQueue')
    Require('UnitTable')
    Require('Weather')
    Require('Users')
    Require('Variables')

    local STORMWATCH_ID = 2
    local QUEST_DIFF_EASY = 1
    local QUEST_DIFF_MEDIUM = 2
    local QUEST_DIFF_HARD = 3

    local stormwatch = Faction.create(
        STORMWATCH_ID,
        "Stormwatch",
        0.,
        15400.,
        StormwatchBuff,
        "The Stormwatch study the skies and turn volatile weather to their advantage.|n|n|cffffcc00Membership, reputation, and unspent Faction Points are saved with this character.|r|n|nWill you join us?"
    )

    stormwatch:addQuest(Quest.create(
        "Changing Skies",
        "Witness 3 changes in weather.\n\n|cffffcc00Reward:|r 5 Faction Points and 5 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNCloudOfFog.blp",
        QUEST_DIFF_EASY,
        "weather_change", 3, 5, 5
    ))
    stormwatch:addQuest(Quest.create(
        "Fair Forecast",
        "Witness 2 changes to beneficial weather.\n\n|cffffcc00Reward:|r 10 Faction Points and 10 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNWispSplode.blp",
        QUEST_DIFF_MEDIUM,
        "weather_fair", 2, 10, 10
    ))
    stormwatch:addQuest(Quest.create(
        "Storm Chaser",
        "Endure 2 changes to harmful weather.\n\n|cffffcc00Reward:|r 20 Faction Points and 20 Reputation",
        "ReplaceableTextures\\CommandButtons\\BTNTornado.blp",
        QUEST_DIFF_HARD,
        "weather_harmful", 2, 20, 20, 3
    ))
    stormwatch:addGenericQuests()

    local function is_member(pid)
        local faction = Faction.getFaction(pid)
        return faction and faction.id == STORMWATCH_ID
    end

    -- Each completed weather transition provides slow, reliable background
    -- progression while quests and hourly events remain the primary source.
    Weather.registerChangeAction(function(_weather, definition)
        local harmful = definition.bad == 1
        local user = User.first
        while user do
            if is_member(user.id) and Hero[user.id] and UnitAlive(Hero[user.id]) then
                Faction.addReputation(user.id, 1)
                Quest.progress(user.id, "weather_change")
                Quest.progress(user.id, harmful and "weather_harmful" or "weather_fair")
            end
            user = user.next
        end
    end)

    StormwatchBuff.getEffectMultiplier = function(target, harmful)
        local pid = GetPlayerId(GetOwningPlayer(target)) + 1
        if pid > PLAYER_CAP or not is_member(pid) then
            return 1.
        end
        local rank = Faction.getRank(Faction.getReputation(pid, STORMWATCH_ID))
        if harmful then
            if rank >= 7 then return 0.65 end
            if rank >= 4 then return 0.75 end
            return 0.85
        end
        if rank >= 7 then return 1.30 end
        if rank >= 4 then return 1.20 end
        return 1.10
    end

    WeatherBuff.getEffectMultiplier = function(target, harmful)
        if StormwatchBuff:get(nil, target) then
            return StormwatchBuff.getEffectMultiplier(target, harmful)
        end
        return 1.
    end

    local EVENT_RADIUS = 2600.
    local STABILIZE_RADIUS = 325.
    local STABILIZE_TIME = 12.
    local EVENT_TIMEOUT = 600.
    local POINT_REWARD = 30
    local REPUTATION_REWARD = 30
    local AVATAR_TEMPLATE = FourCC('n002')
    local AVATAR_SKIN = FourCC('n01W')
    local NODE_MODEL = "Abilities\\Spells\\Other\\Tornado\\TornadoElementalSmall.mdl"
    local active = false
    local phase = "idle"
    local nodes = {}
    local stabilized = 0
    local avatar ---@type unit?
    local tick_callback ---@type integer?
    local timeout_callback ---@type integer?
    local contribution = {}

    local finish_event

    local function format_time(time)
        local total = math.max(0, math.ceil(time))
        return string.format("%d:%02d", total // 60, total % 60)
    end

    local function event_center()
        return GetUnitX(stormwatch.leader), GetUnitY(stormwatch.leader)
    end

    local function announce(message, sound)
        local user = User.first
        while user do
            if is_member(user.id) then
                DisplayTextToPlayer(user.player, 0., 0., message)
                if sound then
                    StartSoundForPlayerBJ(user.player, sound)
                end
            end
            user = user.next
        end
    end

    local function cleanup()
        if tick_callback then TimerQueue:disableCallback(tick_callback) end
        if timeout_callback then TimerQueue:disableCallback(timeout_callback) end
        tick_callback = nil
        timeout_callback = nil
        for index = 1, #nodes do
            if nodes[index].effect then
                DestroyEffect(nodes[index].effect)
            end
        end
        nodes = {}
        if avatar then
            RemoveUnit(avatar)
            avatar = nil
        end
    end

    local function nearby_members(radius)
        local result = {}
        local x, y = event_center()
        local user = User.first
        while user do
            local hero = Hero[user.id]
            if is_member(user.id) and hero and UnitAlive(hero)
                and DistanceCoords(x, y, GetUnitX(hero), GetUnitY(hero)) <= radius then
                result[#result + 1] = user.id
            end
            user = user.next
        end
        return result
    end

    local function spawn_avatar()
        phase = "avatar"
        local x, y = event_center()
        local members = nearby_members(EVENT_RADIUS)
        local party_size = math.max(1, #members)
        local total_level = 0
        for index = 1, #members do
            total_level = total_level + GetHeroLevel(Hero[members[index]])
        end
        local level = #members > 0 and math.max(1, math.floor(total_level / #members)) or 200
        avatar = BlzCreateUnitWithSkin(PLAYER_BOSS, AVATAR_TEMPLATE,
            x, y + 650., 270., AVATAR_SKIN)
        BlzSetUnitSkin(avatar, AVATAR_SKIN)
        BlzSetUnitName(avatar, "Storm Avatar")
        BlzSetHeroProperName(avatar, "Storm Avatar")
        local health = math.min(2000000000.,
            (150000. + level * level * 1800.) * (1. + (party_size - 1) * 0.65))
        local damage = (350. + level * level * 0.85) * (1. + (party_size - 1) * 0.22)
        BlzSetUnitMaxHP(avatar, math.floor(health))
        SetWidgetLife(avatar, health)
        BlzSetUnitBaseDamage(avatar,
            math.max(1, math.floor(damage / CHAOS_ATTACK_DAMAGE_MULTIPLIER)), 0)
        BlzSetUnitArmor(avatar, level * 0.75)
        BlzSetUnitIntegerField(avatar, UNIT_IF_DEFENSE_TYPE, ARMOR_CHAOS)
        BlzSetUnitWeaponIntegerField(avatar,
            UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE, 0, ATTACK_CHAOS)
        BlzSetUnitIntegerField(avatar, UNIT_IF_LEVEL, level)
        EVENT_ON_UNIT_DEATH:register_unit_action(avatar, function()
            if active then finish_event(true) end
        end)
        announce("|cff80dfffEye of the Storm:|r The storm has taken form. Destroy its avatar!",
            bj_questUpdatedSound)
        if members[1] then
            IssueTargetOrder(avatar, "attack", Hero[members[1]])
        end
    end

    local function event_tick()
        tick_callback = nil
        if not active then return end
        local members = nearby_members(EVENT_RADIUS)
        for index = 1, #members do
            local pid = members[index]
            contribution[pid] = (contribution[pid] or 0) + 1
        end

        if phase == "stabilize" then
            for node_index = 1, #nodes do
                local node = nodes[node_index]
                if not node.complete then
                    local occupied = false
                    for member_index = 1, #members do
                        local hero = Hero[members[member_index]]
                        if DistanceCoords(node.x, node.y,
                            GetUnitX(hero), GetUnitY(hero)) <= STABILIZE_RADIUS then
                            occupied = true
                            break
                        end
                    end
                    if occupied then
                        node.progress = node.progress + 1
                        if node.progress >= STABILIZE_TIME then
                            node.complete = true
                            stabilized = stabilized + 1
                            DestroyEffect(node.effect)
                            node.effect = nil
                            DestroyEffect(AddSpecialEffect(
                                "Abilities\\Spells\\Other\\Monsoon\\MonsoonBoltTarget.mdl",
                                node.x, node.y))
                            announce("|cff80dfffStorm anomaly stabilized:|r "
                                .. stabilized .. " / " .. #nodes)
                        end
                    end
                end
            end
            if stabilized >= #nodes then
                spawn_avatar()
            end
        end
        tick_callback = TimerQueue:callDelayed(1., event_tick)
    end

    finish_event = function(success)
        if not active then return false end
        active = false
        if success then
            local rewarded = 0
            for pid, seconds in pairs(contribution) do
                if is_member(pid) and seconds >= 30 then
                    AddCurrency(pid, FACTION, POINT_REWARD)
                    Faction.addReputation(pid, REPUTATION_REWARD)
                    Quest.progress(pid, "faction_event")
                    StartSoundForPlayerBJ(Player(pid - 1), bj_questCompletedSound)
                    rewarded = rewarded + 1
                end
            end
            announce("|cff80ff80Eye of the Storm complete!|r " .. rewarded
                .. " participant" .. (rewarded == 1 and " was" or "s were") .. " rewarded.")
        else
            announce("|cffff4040Eye of the Storm failed.|r The anomalies became unstable.",
                bj_questFailedSound)
        end
        cleanup()
        phase = "idle"
        contribution = {}
        stabilized = 0
        return true
    end

    local function start_event()
        if active or not CHAOS_MODE then return false end
        active = true
        phase = "stabilize"
        contribution = {}
        stabilized = 0
        local x, y = event_center()
        for index = 1, 4 do
            local angle = (index - 1) * bj_PI * 0.5
            local node_x = x + 700. * math.cos(angle)
            local node_y = y + 700. * math.sin(angle)
            local effect = AddSpecialEffect(NODE_MODEL, node_x, node_y)
            BlzSetSpecialEffectScale(effect, 1.35)
            nodes[index] = {
                x = node_x,
                y = node_y,
                progress = 0,
                complete = false,
                effect = effect,
            }
        end
        announce("|cffffcc00Faction Event: Eye of the Storm|r\n"
            .. "Stand near each storm anomaly for 12 seconds, then destroy the avatar.",
            bj_questDiscoveredSound)
        tick_callback = TimerQueue:callDelayed(1., event_tick)
        timeout_callback = TimerQueue:callDelayed(EVENT_TIMEOUT, finish_event, false)
        return true
    end

    local function event_status(_pid, remaining)
        if active then
            if phase == "avatar" then
                return "|cff80dfffEye of the Storm|r\n\nThe storm avatar has formed. Destroy it before the event expires."
            end
            return "|cff80dfffEye of the Storm|r\n\nStand near the anomalies to stabilize them.\n\n|cffffcc00Progress:|r "
                .. stabilized .. " / " .. #nodes
        end
        return "|cff80dfffEye of the Storm|r\n\nStabilize four anomalies, then destroy the storm avatar.\n\n|cffffcc00Begins in:|r "
            .. format_time(remaining or 0.)
    end

    local function hud_status(pid)
        if not active or not is_member(pid) then return nil end
        local remaining = timeout_callback and TimerQueue:getRemaining(timeout_callback) or 0.
        if phase == "avatar" then
            local health = avatar and math.max(0., GetWidgetLife(avatar)) or 0.
            local maximum = avatar and math.max(1., BlzGetUnitMaxHP(avatar)) or 1.
            return "|cff80dfffEye of the Storm|r  |  Storm Avatar: "
                .. math.floor(health / maximum * 100.) .. "%\nTime: " .. format_time(remaining)
        end
        return "|cff80dfffEye of the Storm|r  |  Anomalies: "
            .. stabilized .. " / " .. #nodes .. "\nTime: " .. format_time(remaining)
    end

    local function warn_event()
        announce("|cffffcc00Faction Event:|r Eye of the Storm begins in 5 minutes.",
            bj_questWarningSound)
    end

    local start_now
    if DEV_ENABLED then
        start_now = function()
            if active then finish_event(false) end
            return start_event()
        end
    end

    FactionEvents.register(STORMWATCH_ID, {
        activate = function() return true end,
        start = start_event,
        warning = warn_event,
        isActive = function() return active end,
        getStatus = event_status,
        getHudStatus = hud_status,
        startNow = start_now,
    })
end, Debug and Debug.getLine())
