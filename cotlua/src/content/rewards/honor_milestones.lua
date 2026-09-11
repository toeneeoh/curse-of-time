-- Lifetime Honor milestone track. Reward effects can be assigned later without
-- changing the progression service, save data, or Stat View presentation.

OnInit.final("HonorMilestones", function(Require)
    Require('Honor')

    local thresholds = {
        5, 15, 30, 50, 100, 200, 350,
        500, 750, 1000, 1500, 2500, 5000, 10000,
    }

    for index = 1, #thresholds do
        local required = thresholds[index]
        local capstone = required == 5000 or required == 10000
        Honor.registerMilestone({
            key = "lifetime_honor_" .. required,
            honor = required,
            name = capstone and "Prestige Reward" or "Milestone Reward",
            description = capstone
                and "A prestigious cosmetic or title will be assigned to this milestone."
                or "The reward for this milestone has not been assigned yet.",
        })
    end
end, Debug and Debug.getLine())
