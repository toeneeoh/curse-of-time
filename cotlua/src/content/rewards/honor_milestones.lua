-- Lifetime Honor milestone track. Reward effects can be assigned later without
-- changing the progression service, save data, or Stat View presentation.

OnInit.final("HonorMilestones", function(Require)
    Require('Honor')

    local milestones = {
        { 5, "Elemental Whelps", "Unlocks the Black, Red, Green, and Blue Dragon Whelp backpack skins." },
        { 15, "Elemental Mephits", "Unlocks the Shadow, Fire, Venom, and Ice Mephit backpack skins." },
        { 30, "Wyvern", "Unlocks the Wyvern backpack skin." },
        { 50, "Nether Dragon", "Unlocks the Nether Dragon backpack skin." },
        { 100, "Owl", "Unlocks the Owl backpack skin." },
        { 200, "Spirit Owl", "Unlocks the Spirit Owl backpack skin." },
        { 350, "Phase Bat", "Unlocks the Phase Bat backpack skin." },
        { 500, "Yellow Dragon Whelp", "Unlocks the Yellow Dragon Whelp backpack skin." },
        { 750, "Earth Mephit", "Unlocks the Earth Mephit backpack skin." },
        { 1000, "Elder Shadow Dragon", "Unlocks the Elder Shadow Dragon backpack skin." },
        { 1500, "Milestone Reward", "A cosmetic reward will be assigned to this milestone." },
        { 2500, "Milestone Reward", "A cosmetic reward will be assigned to this milestone." },
        { 5000, "Grand Milestone", "A title or special effect will be assigned to this milestone." },
        { 10000, "Sin", "Unlocks the Sin backpack skin. A capstone title or effect may also be assigned here." },
    }

    for index = 1, #milestones do
        local required = milestones[index][1]
        local capstone = required == 5000 or required == 10000
        Honor.registerMilestone({
            key = "lifetime_honor_" .. required,
            honor = required,
            name = milestones[index][2],
            icon = capstone
                and "ReplaceableTextures\\CommandButtons\\BTNMedalionOfCourage.blp"
                or "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp",
            description = milestones[index][3],
        })
    end
end, Debug and Debug.getLine())
