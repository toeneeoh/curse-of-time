--[[
    quest_tracker.lua

    Compact persistent tracker for active repeatable kill quests.
]]

OnInit.final("QuestTracker", function(Require)
    Require('Frames')
    Require('RewardNotifications')
    Require('SimpleButton')
    Require('TimerQueue')
    Require('Multiboard')
    Require('Profile')
    Require('Events')

    local REFRESH_PERIOD = 0.20
    local MAX_ROWS = 10
    local EXPANDED_WIDTH = 0.2
    local COLLAPSED_WIDTH = 0.032
    local ROW_STEP = 0.012
    local states = {}
    local order = {}
    local rows = {}
    local visible_states = {}
    local refresh_scheduled = false
    local minimized = false

    local header = BlzCreateFrame("ListBoxWar3", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    local title = BlzCreateFrameByType("TEXT", "", header, "", 0)
    local body = BlzCreateFrame("ListBoxWar3", header, 0, 0)
    local overflow = BlzCreateFrameByType("TEXT", "", body, "", 0)

    BlzFrameSetSize(header, EXPANDED_WIDTH, 0.035)
    BlzFrameSetLevel(header, 8)
    BlzFrameSetEnable(header, false)
    BlzFrameSetVisible(header, false)

    BlzFrameSetPoint(title, FRAMEPOINT_CENTER, header, FRAMEPOINT_CENTER, -0.008, 0.)
    BlzFrameSetSize(title, 0.17, 0.022)
    BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
    BlzFrameSetText(title, "Quest Tracker")
    BlzFrameSetEnable(title, false)

    BlzFrameSetPoint(body, FRAMEPOINT_TOPLEFT, header, FRAMEPOINT_BOTTOMLEFT, 0., 0.011)
    BlzFrameSetSize(body, EXPANDED_WIDTH, 0.03)
    BlzFrameSetEnable(body, false)

    for index = 1, MAX_ROWS do
        local row = BlzCreateFrameByType("TEXT", "", body, "", 0)
        BlzFrameSetPoint(row, FRAMEPOINT_TOPLEFT, body, FRAMEPOINT_TOPLEFT,
            0.012, -0.01 - (index - 1) * ROW_STEP)
        BlzFrameSetSize(row, EXPANDED_WIDTH - 0.024, 0.014)
        BlzFrameSetTextAlignment(row, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
        BlzFrameSetFont(row, "MasterFont", 0.0105, 0)
        BlzFrameSetEnable(row, false)
        rows[index] = row
    end

    BlzFrameSetPoint(overflow, FRAMEPOINT_BOTTOMLEFT, body, FRAMEPOINT_BOTTOMLEFT, 0.012, 0.009)
    BlzFrameSetSize(overflow, EXPANDED_WIDTH - 0.024, 0.016)
    BlzFrameSetTextAlignment(overflow, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
    BlzFrameSetFont(overflow, "MasterFont", 0.0095, 0)
    BlzFrameSetEnable(overflow, false)

    local minimize_button
    local function toggle()
        if GetTriggerPlayer() ~= GetLocalPlayer() then return end
        local f = BlzGetTriggerFrame()
        BlzFrameSetEnable(f, false)
        BlzFrameSetEnable(f, true)
        minimized = not minimized
        BlzFrameSetSize(header, minimized and COLLAPSED_WIDTH or EXPANDED_WIDTH, 0.032)
        BlzFrameSetVisible(title, not minimized)
        BlzFrameSetVisible(body, not minimized)
        minimize_button:icon(minimized
            and "war3mapImported\\prev.blp"
            or "war3mapImported\\next.blp")
        BlzFrameSetText(minimize_button.tooltip.tooltip, minimized and "Open Quest Tracker" or "Close Quest Tracker")
    end

    minimize_button = SimpleButton.create(header, "war3mapImported\\next.blp", 0.015, 0.015,
        FRAMEPOINT_RIGHT, FRAMEPOINT_RIGHT, -0.009, 0., toggle, "Close Quest Tracker",
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_BOTTOMLEFT, 0., 0.006)

    local function anchor_to_multiboard(pid, body_frame, multiboard_minimized)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        BlzFrameClearAllPoints(header)
        BlzFrameSetPoint(header, FRAMEPOINT_TOPRIGHT,
            multiboard_minimized and MULTIBOARD.main or body_frame,
            FRAMEPOINT_BOTTOMRIGHT, 0., -0.004)
    end

    MULTIBOARD.registerViewChangedAction(anchor_to_multiboard)
    local local_pid = GetPlayerId(GetLocalPlayer()) + 1
    local current_body = MULTIBOARD.bodies[MULTIBOARD.lookingAt[local_pid]]
    anchor_to_multiboard(local_pid, current_body.frame, MULTIBOARD.minimized[local_pid])

    local function refresh()
        refresh_scheduled = false
        RuntimeMetrics.rewards.hud_flushes = RuntimeMetrics.rewards.hud_flushes + 1
        local local_pid = GetPlayerId(GetLocalPlayer()) + 1
        local profile = Profile[local_pid]
        local hero = Hero[local_pid]
        local hero_level = hero and GetHeroLevel(hero) or 0
        local active = 0
        for index = #visible_states, 1, -1 do
            visible_states[index] = nil
        end
        for index = 1, #order do
            local state = states[order[index]]
            local minimum = state and math.max(state.min_level or 0,
                (state.target_level or 0) - LEECH_CONSTANT) or 0
            local eligible = state and profile and profile.playing and hero
                and hero_level >= minimum
            if eligible and state.status ~= "NOT_STARTED" then
                local multiplier = RewardNotifications.questLevelMultiplier(
                    hero_level, state.target_level or 0) * (state.contribution_quality or 1.)
                local reward_percent = math.floor(multiplier * 100. + 0.5)
                if reward_percent > 0 then
                    visible_states[#visible_states + 1] = {
                        state = state,
                        multiplier = multiplier,
                        reward_percent = reward_percent,
                    }
                end
            end
        end

        table.sort(visible_states, function(left, right)
            local left_complete = left.state.status == "COMPLETE"
            local right_complete = right.state.status == "COMPLETE"
            if left_complete ~= right_complete then return left_complete end
            if left.multiplier ~= right.multiplier then
                return left.multiplier > right.multiplier
            end
            local left_level = left.state.target_level or 0
            local right_level = right.state.target_level or 0
            if left_level ~= right_level then
                return left_level > right_level
            end
            return left.state.name < right.state.name
        end)

        active = #visible_states
        for index = 1, math.min(active, MAX_ROWS) do
            local visible = visible_states[index]
            local state = visible.state
            local color = state.status == "COMPLETE" and "|cff40ff40" or "|cff7dc8c8"
            local reduced = visible.multiplier < 0.995
                and " |cffffcc00(" .. visible.reward_percent .. "%)|r" or ""
            BlzFrameSetText(rows[index], color .. state.name .. ":|r "
                .. state.count .. "/" .. state.goal .. reduced)
            BlzFrameSetVisible(rows[index], true)
        end
        for index = active + 1, MAX_ROWS do
            BlzFrameSetText(rows[index], "")
            BlzFrameSetVisible(rows[index], false)
        end
        local hidden = math.max(0, active - MAX_ROWS)
        local shown = math.min(active, MAX_ROWS)
        BlzFrameSetSize(body, EXPANDED_WIDTH,
            0.02 + shown * ROW_STEP + (hidden > 0 and 0.014 or 0.))
        BlzFrameSetText(overflow, hidden > 0 and "+" .. hidden .. " more active quest(s)" or "")
        BlzFrameSetVisible(overflow, hidden > 0)
        BlzFrameSetText(title, "Quest Tracker" .. (active > 0 and " (" .. active .. ")" or ""))
        BlzFrameSetVisible(header, active > 0)
        BlzFrameSetVisible(body, active > 0 and not minimized)
    end

    local function schedule_refresh()
        if not refresh_scheduled then
            refresh_scheduled = true
            TimerQueue:callDelayed(REFRESH_PERIOD, refresh)
        end
    end

    local function update(id, name, count, goal, status, min_level, target_level,
        contribution_quality)
        local state = states[id]
        if not state then
            state = {}
            states[id] = state
            order[#order + 1] = id
        end
        state.name = name
        state.count = count
        state.goal = goal
        state.status = status
        state.min_level = min_level
        state.target_level = target_level
        state.contribution_quality = contribution_quality
        schedule_refresh()
    end

    RewardNotifications.registerQuestAction(update)
    RewardNotifications.registerEligibilityAction(schedule_refresh)
    for pid = 1, PLAYER_CAP do
        EVENT_ON_SETUP:register_action(pid, schedule_refresh)
        EVENT_ON_CLEANUP:register_action(pid, schedule_refresh)
    end
end, Debug and Debug.getLine())
