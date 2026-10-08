OnInit.global("RewardScaling", function()
    RewardScaling = {}

    local OVERLEVEL_GROWTH = 1.05

    ---Returns the reward retained when the recipient outlevels the target.
    ---Equal- and under-level recipients retain the full reward. A fixed level
    ---gap has the same effect throughout progression: +15 retains about 82%,
    ---+50 about 32%, and +100 about 4%.
    ---@param recipient_level number
    ---@param target_level number
    ---@return number
    function RewardScaling.overlevelMultiplier(recipient_level, target_level)
        if target_level <= 0. or recipient_level <= target_level then
            return 1.
        end

        local overlevel = recipient_level - target_level
        return 5. / (4. + OVERLEVEL_GROWTH ^ overlevel)
    end
end, Debug and Debug.getLine())
