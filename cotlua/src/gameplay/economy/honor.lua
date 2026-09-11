-- Character-bound Honor totals and reallocatable reward ranks.

OnInit.final("Honor", function(Require)
    Require('Currency')
    Require('Profile')
    Require('Users')

    Honor = {}

    local totals = __jarray(0)
    local MAX_HONOR = 100000
    local allocations = {}
    local active = {}
    local rewards = {}
    local reward_order = {}
    local milestones = {}
    local applied_milestones = {}
    local changed_actions = {}

    ---@class HonorRewardDefinition
    ---@field key string
    ---@field max_rank integer
    ---@field cost? integer|fun(rank: integer): integer
    ---@field apply fun(pid: integer, old_rank: integer, new_rank: integer)

    ---@class HonorMilestoneDefinition
    ---@field honor integer
    ---@field key string
    ---@field name string
    ---@field description string
    ---@field apply? fun(pid: integer)

    local function notify_changed(pid)
        for index = 1, #changed_actions do
            changed_actions[index](pid)
        end
    end

    ---@param callback fun(pid: integer)
    function Honor.registerChangedAction(callback)
        changed_actions[#changed_actions + 1] = callback
    end

    ---@param definition HonorMilestoneDefinition
    ---@return boolean
    function Honor.registerMilestone(definition)
        if type(definition) ~= "table"
            or type(definition.key) ~= "string"
            or type(definition.name) ~= "string"
            or type(definition.description) ~= "string"
            or (definition.apply ~= nil and type(definition.apply) ~= "function")
            or (definition.honor or 0) < 1 then
            return false
        end
        for index = 1, #milestones do
            if milestones[index].key == definition.key
                or milestones[index].honor == definition.honor then
                return false
            end
        end
        milestones[#milestones + 1] = definition
        table.sort(milestones, function(a, b) return a.honor < b.honor end)
        return true
    end

    ---@return HonorMilestoneDefinition[]
    function Honor.getMilestones()
        return milestones
    end

    ---@param pid integer
    ---@param milestone HonorMilestoneDefinition
    ---@return boolean
    function Honor.isMilestoneUnlocked(pid, milestone)
        return totals[pid] >= milestone.honor
    end

    ---@param pid integer
    ---@return HonorMilestoneDefinition?
    function Honor.getNextMilestone(pid)
        for index = 1, #milestones do
            if totals[pid] < milestones[index].honor then
                return milestones[index]
            end
        end
        return nil
    end

    local function update_milestones(pid)
        local applied = applied_milestones[pid]
        if not applied then
            applied = {}
            applied_milestones[pid] = applied
        end
        for index = 1, #milestones do
            local milestone = milestones[index]
            if totals[pid] >= milestone.honor and not applied[milestone.key] then
                applied[milestone.key] = true
                if milestone.apply then milestone.apply(pid) end
            end
        end
    end

    local function allocation(pid)
        if not allocations[pid] then allocations[pid] = __jarray(0) end
        return allocations[pid]
    end

    local function rank_cost(reward, rank)
        if type(reward.cost) == "function" then
            return reward.cost(rank)
        end
        return reward.cost or 5
    end

    ---@param definition HonorRewardDefinition
    ---@return boolean
    function Honor.registerReward(definition)
        if type(definition) ~= "table"
            or type(definition.key) ~= "string"
            or rewards[definition.key]
            or type(definition.apply) ~= "function"
            or (definition.max_rank or 0) < 1 then
            return false
        end
        rewards[definition.key] = definition
        reward_order[#reward_order + 1] = definition
        return true
    end

    ---@param pid integer
    ---@param key string
    ---@return integer
    function Honor.getRank(pid, key)
        return allocation(pid)[key]
    end

    ---@param pid integer
    ---@param key string
    ---@return integer
    function Honor.getNextCost(pid, key)
        local reward = rewards[key]
        if not reward then return 0 end
        return rank_cost(reward, Honor.getRank(pid, key) + 1)
    end

    ---@param pid integer
    ---@return integer
    function Honor.getTotal(pid)
        return totals[pid]
    end

    ---@param pid integer
    ---@return integer
    function Honor.getAllocated(pid)
        local spent = 0
        local ranks = allocation(pid)
        for index = 1, #reward_order do
            local reward = reward_order[index]
            for rank = 1, ranks[reward.key] do
                spent = spent + rank_cost(reward, rank)
            end
        end
        return spent
    end

    ---Called by the shop transaction before it deducts the displayed Honor cost.
    ---@param pid integer
    ---@param key string
    ---@return boolean
    function Honor.allocate(pid, key)
        local reward = rewards[key]
        if not reward then return false end

        local ranks = allocation(pid)
        local old_rank = ranks[key]
        if old_rank >= reward.max_rank
            or GetCurrency(pid, HONOR) < rank_cost(reward, old_rank + 1) then
            return false
        end

        local new_rank = old_rank + 1
        if active[pid] then
            reward.apply(pid, old_rank, new_rank)
        end
        ranks[key] = new_rank
        return true
    end

    ---Applies the selected loadout when a player enters the Colosseum.
    ---@param pid integer
    function Honor.activate(pid)
        if active[pid] then return end
        active[pid] = true
        local ranks = allocation(pid)
        for index = 1, #reward_order do
            local reward = reward_order[index]
            local rank = ranks[reward.key]
            if rank > 0 then reward.apply(pid, 0, rank) end
        end
    end

    ---Removes all loadout effects without changing their allocated ranks.
    ---@param pid integer
    function Honor.deactivate(pid)
        if not active[pid] then return end
        local ranks = allocation(pid)
        for index = 1, #reward_order do
            local reward = reward_order[index]
            local rank = ranks[reward.key]
            if rank > 0 then reward.apply(pid, rank, 0) end
        end
        active[pid] = nil
    end

    ---@param pid integer
    ---@return boolean
    function Honor.reset(pid)
        local ranks = allocation(pid)
        local changed = false
        for index = 1, #reward_order do
            local reward = reward_order[index]
            local rank = ranks[reward.key]
            if rank > 0 then
                if active[pid] then reward.apply(pid, rank, 0) end
                ranks[reward.key] = 0
                changed = true
            end
        end
        SetCurrency(pid, HONOR, totals[pid])
        return changed
    end

    ---@param pid integer
    ---@param amount integer
    function Honor.setTotal(pid, amount)
        amount = math.min(MAX_HONOR, math.max(0, math.floor(amount)))
        totals[pid] = amount
        if Profile[pid] and Profile[pid].hero then
            Profile[pid].hero.honor = amount
        end
        SetCurrency(pid, HONOR, math.max(0, amount - Honor.getAllocated(pid)))
        update_milestones(pid)
        notify_changed(pid)
    end

    ---@param pid integer
    ---@param amount integer
    function Honor.award(pid, amount)
        amount = math.max(0, math.floor(amount))
        if amount == 0 then return end
        local previous = totals[pid]
        totals[pid] = math.min(MAX_HONOR, totals[pid] + amount)
        if Profile[pid] and Profile[pid].hero then
            Profile[pid].hero.honor = totals[pid]
        end
        AddCurrency(pid, HONOR, totals[pid] - previous)
        update_milestones(pid)
        notify_changed(pid)
    end

    local function on_setup(pid)
        allocations[pid] = __jarray(0)
        active[pid] = nil
        applied_milestones[pid] = {}
        Honor.setTotal(pid, Profile[pid].hero.honor or 0)
    end

    local function on_cleanup(pid)
        allocations[pid] = nil
        active[pid] = nil
        applied_milestones[pid] = nil
        totals[pid] = 0
    end

    local user = User.first
    while user do
        EVENT_ON_SETUP:register_action(user.id, on_setup)
        EVENT_ON_CLEANUP:register_action(user.id, on_cleanup)
        user = user.next
    end
end, Debug and Debug.getLine())
