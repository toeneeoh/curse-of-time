--[[
    reward_feed.lua

    Fixed, aggregated gold and experience notifications above the hero portrait.
]]

OnInit.final("RewardFeed", function(Require)
    Require('Frames')
    Require('Inspect')
    Require('RewardNotifications')
    Require('TimerQueue')

    local AGGREGATE_PERIOD = 0.20
    local VISIBLE_DURATION = 3.50
    local ROW_COUNT = 3
    local pending = {}
    local scheduled = __jarray(false)
    local generation = __jarray(0)
    local history = {}
    local history_width = {}
    local rows = {}

    local container = BlzCreateFrameByType("BACKDROP", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
    BlzFrameSetPoint(container, FRAMEPOINT_BOTTOM, INSPECT_HUD_ANCHOR, FRAMEPOINT_TOPLEFT, 0.0355, 0.008)
    BlzFrameSetSize(container, 0.12, 0.029)
    BlzFrameSetTexture(container,
        "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp", 0, true)
    BlzFrameSetVertexColor(container, BlzConvertColor(215, 35, 35, 45))
    BlzFrameSetEnable(container, false)
    BlzFrameSetLevel(container, 8)
    BlzFrameSetVisible(container, false)

    for index = 1, ROW_COUNT do
        local row = BlzCreateFrameByType("TEXT", "", container, "", 0)
        BlzFrameSetPoint(row, FRAMEPOINT_BOTTOM, container, FRAMEPOINT_BOTTOM, 0., 0.006 + (index - 1) * 0.02)
        BlzFrameSetSize(row, 0.108, 0.016)
        BlzFrameSetTextAlignment(row, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
        BlzFrameSetFont(row, "MasterFont", 0.012, 0)
        BlzFrameSetEnable(row, false)
        rows[index] = row
        history[index] = ""
        history_width[index] = 0
    end

    local function resize_background()
        local line_count, longest = 0, 0
        for index = 1, ROW_COUNT do
            if history[index] ~= "" then line_count = line_count + 1 end
            longest = math.max(longest, history_width[index])
        end
        local width = math.min(0.25, math.max(0.12, longest * 0.0046 + 0.018))
        local height = 0.012 + line_count * 0.017
        BlzFrameSetSize(container, width, height)
        for index = 1, ROW_COUNT do BlzFrameSetSize(rows[index], width - 0.012, 0.016) end
    end

    local function compact(value)
        if value < 1000 then return tostring(value) end
        local scaled, suffix
        if value >= 1000000000 then
            scaled, suffix = value / 1000000000., "B"
        elseif value >= 1000000 then
            scaled, suffix = value / 1000000., "M"
        else
            scaled, suffix = value / 1000., "K"
        end
        local rounded = math.floor(scaled * 10. + 0.5) / 10.
        if rounded == math.floor(rounded) then
            return math.floor(rounded) .. suffix
        end
        return string.format("%.1f%s", rounded, suffix)
    end

    local function clear(pid, expected_generation)
        if generation[pid] ~= expected_generation or GetLocalPlayer() ~= Player(pid - 1) then return end
        for index = 1, ROW_COUNT do
            history[index] = ""
            history_width[index] = 0
            BlzFrameSetText(rows[index], "")
        end
        BlzFrameSetVisible(container, false)
    end

    local function flush(pid)
        scheduled[pid] = false
        local reward = pending[pid]
        if not reward then return end
        pending[pid] = nil
        RuntimeMetrics.rewards.hud_flushes = RuntimeMetrics.rewards.hud_flushes + 1

        local parts, plain_parts = {}, {}
        if reward.xp > 0 then
            local text = "+" .. compact(reward.xp) .. " XP"
            parts[#parts + 1] = "|cffcc33cc" .. text .. "|r"
            plain_parts[#plain_parts + 1] = text
        end
        if reward.platinum > 0 then
            local text = "+" .. compact(reward.platinum) .. " Platinum"
            parts[#parts + 1] = "|cffdddddd" .. text .. "|r"
            plain_parts[#plain_parts + 1] = text
        end
        if reward.gold > 0 then
            local text = "+" .. compact(reward.gold) .. " Gold"
            parts[#parts + 1] = "|cffffcc00" .. text .. "|r"
            plain_parts[#plain_parts + 1] = text
        end
        if #parts == 0 then return end

        generation[pid] = generation[pid] + 1
        local current_generation = generation[pid]
        if GetLocalPlayer() == Player(pid - 1) then
            for index = ROW_COUNT, 2, -1 do
                history[index] = history[index - 1]
                history_width[index] = history_width[index - 1]
                BlzFrameSetText(rows[index], history[index])
            end
            history[1] = table.concat(parts, "    ")
            history_width[1] = #table.concat(plain_parts, "    ")
            BlzFrameSetText(rows[1], history[1])
            resize_background()
            BlzFrameSetVisible(container, true)
        end
        TimerQueue:callDelayed(VISIBLE_DURATION, clear, pid, current_generation)
    end

    local function queue_reward(pid, reward_type, amount, secondary)
        local reward = pending[pid]
        if not reward then
            reward = { gold = 0, platinum = 0, xp = 0 }
            pending[pid] = reward
        end
        if reward_type == "xp" then
            reward.xp = reward.xp + amount
        else
            reward.gold = reward.gold + amount
            reward.platinum = reward.platinum + secondary
        end
        if not scheduled[pid] then
            scheduled[pid] = true
            TimerQueue:callDelayed(AGGREGATE_PERIOD, flush, pid)
        end
    end

    RewardNotifications.registerRewardAction(queue_reward)
end, Debug and Debug.getLine())
