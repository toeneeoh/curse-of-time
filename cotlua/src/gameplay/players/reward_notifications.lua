--[[
    reward_notifications.lua

    Publishes synchronized reward and kill-quest progress changes. Gameplay
    owns the values; local HUD modules decide how those values are presented.
]]

OnInit.global("RewardNotifications", function(Require)
    Require('Variables')

    RewardNotifications = {}

    local reward_actions = {}
    local quest_actions = {}
    local eligibility_actions = {}

    local function register(actions, callback)
        for index = 1, #actions do
            if actions[index] == callback then return false end
        end
        actions[#actions + 1] = callback
        return true
    end

    ---@param callback fun(pid: integer, reward_type: string, amount: integer, secondary: integer)
    function RewardNotifications.registerRewardAction(callback)
        return register(reward_actions, callback)
    end

    ---@param callback fun(id: integer, name: string, count: integer, goal: integer, status: string, min_level: integer, target_level: number, contribution_quality: number)
    function RewardNotifications.registerQuestAction(callback)
        return register(quest_actions, callback)
    end

    ---@param hero_level number
    ---@param target_level number
    ---@return number
    function RewardNotifications.questLevelMultiplier(hero_level, target_level)
        if target_level <= 0 or hero_level <= target_level then return 1. end
        local ratio = (hero_level - target_level) / LEVEL_REWARD_FALLOFF
        return 1. / (1. + ratio * ratio)
    end

    ---Registers presentation refreshes for player-state changes which can
    ---alter whether a shared quest is locally relevant.
    ---@param callback fun(pid: integer)
    function RewardNotifications.registerEligibilityAction(callback)
        return register(eligibility_actions, callback)
    end

    ---@param pid integer
    ---@param gold integer
    ---@param platinum integer
    function RewardNotifications.gold(pid, gold, platinum)
        local metrics = RuntimeMetrics.rewards
        metrics.gold_events = metrics.gold_events + 1
        metrics.world_text_tags_removed = metrics.world_text_tags_removed + 1
        for index = 1, #reward_actions do
            reward_actions[index](pid, "gold", gold, platinum)
        end
    end

    ---@param pid integer
    ---@param amount integer
    function RewardNotifications.xp(pid, amount)
        local metrics = RuntimeMetrics.rewards
        metrics.xp_events = metrics.xp_events + 1
        metrics.world_text_tags_removed = metrics.world_text_tags_removed + 1
        for index = 1, #reward_actions do
            reward_actions[index](pid, "xp", amount, 0)
        end
    end

    ---@param id integer
    ---@param name string
    ---@param count integer
    ---@param goal integer
    ---@param status string
    ---@param min_level integer
    ---@param target_level number
    ---@param contribution_quality number
    ---@param replaced_text_tag boolean?
    function RewardNotifications.quest(id, name, count, goal, status, min_level,
        target_level, contribution_quality, replaced_text_tag)
        local metrics = RuntimeMetrics.rewards
        metrics.quest_updates = metrics.quest_updates + 1
        if replaced_text_tag then
            metrics.world_text_tags_removed = metrics.world_text_tags_removed + 1
        end
        for index = 1, #quest_actions do
            quest_actions[index](id, name, count, goal, status, min_level,
                target_level, contribution_quality)
        end
    end

    ---@param pid integer
    function RewardNotifications.eligibility(pid)
        for index = 1, #eligibility_actions do
            eligibility_actions[index](pid)
        end
    end
end)
