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

    ---@class HonorRewardDefinition
    ---@field key string
    ---@field max_rank integer
    ---@field cost? integer|fun(rank: integer): integer
    ---@field apply fun(pid: integer, old_rank: integer, new_rank: integer)

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
    end

    local function on_setup(pid)
        allocations[pid] = __jarray(0)
        active[pid] = nil
        Honor.setTotal(pid, Profile[pid].hero.honor or 0)
    end

    local function on_cleanup(pid)
        allocations[pid] = nil
        active[pid] = nil
        totals[pid] = 0
    end

    local user = User.first
    while user do
        EVENT_ON_SETUP:register_action(user.id, on_setup)
        EVENT_ON_CLEANUP:register_action(user.id, on_cleanup)
        user = user.next
    end
end, Debug and Debug.getLine())
