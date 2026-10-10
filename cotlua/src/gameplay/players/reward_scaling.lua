OnInit.global("RewardScaling", function()
    RewardScaling = {}

    local PRECHAOS_OVERLEVEL_GROWTH = 1.15
    local CHAOS_OVERLEVEL_GROWTH = 1.08
    local TRANSITION_START_LEVEL = 160.
    local TRANSITION_END_LEVEL = 180.

    ---Returns the reward retained when the recipient outlevels the target.
    ---Equal- and under-level recipients retain the full reward. Early targets
    ---fall off sharply (+27 retains about 10.5%); chaos targets retain the
    ---broader window (+50 retains about 9.8%). Blend across target levels
    ---160-180, not recipient levels: leveling up cannot revive obsolete farms.
    ---@param recipient_level number
    ---@param target_level number
    ---@return number
    function RewardScaling.overlevelMultiplier(recipient_level, target_level)
        if target_level <= 0. or recipient_level <= target_level then
            return 1.
        end

        local overlevel = recipient_level - target_level
        local chaos_weight = math.max(0., math.min(1.,
            (target_level - TRANSITION_START_LEVEL) /
                (TRANSITION_END_LEVEL - TRANSITION_START_LEVEL)))
        local growth = PRECHAOS_OVERLEVEL_GROWTH
            + (CHAOS_OVERLEVEL_GROWTH - PRECHAOS_OVERLEVEL_GROWTH) * chaos_weight
        return 5. / (4. + growth ^ overlevel)
    end
end, Debug and Debug.getLine())
