--[[
    town.lua
]]

OnInit.final("Town", function()
    local villagers = {
        {x = 181, y = 2353, model = "units\\critters\\VillagerMan\\VillagerMan"},
        {x = -80, y = 1938, model = "units\\critters\\VillagerKid\\VillagerKid"},
        {x = -538, y = 2388, model = "units\\critters\\VillagerKid\\VillagerKid"},
        {x = -727, y = 2041, model = "units\\critters\\VillagerMan\\VillagerMan"},
        {x = 1104, y = 1304, model = "war3mapImported\\Night Elf Villager.mdl"},
        {x = 243, y = 1064, model = "war3mapImported\\Blood Elf Villager.mdl"},
        {x = 314, y = 932, model = "war3mapImported\\blondeTC.mdl"},
        {x = 254, y = 265, model = "war3mapImported\\burnetteTC.mdl"},
        {x = 618, y = 324, model = "war3mapImported\\Blood Elf Villager.mdl"},
        {x = 1778, y = -234, model = "war3mapImported\\HighElfKid_ByEpsilon.mdl"},
        {x = 1342, y = 302, model = "war3mapImported\\GoblinKid.mdl"},
        {x = 711, y = -294, model = "war3mapImported\\BloodElfKid_ByEpsilon.mdl"},
        {x = 711, y = -294, model = "war3mapImported\\BloodElfKid_ByEpsilon.mdl"},
        {x = -920, y = 1034, model = "war3mapImported\\burnetteTC.mdl"},
        {x = -960, y = 1104, model = "war3mapImported\\Night Elf Villager.mdl"},
        {x = -2244, y = 480, model = "units\\critters\\VillagerWoman\\VillagerWoman"},
        {x = -1623, y = -669, model = "units\\critters\\VillagerWoman\\VillagerWoman"},
        {x = -1712, y = -756, model = "war3mapImported\\BloodElfKid_ByEpsilon.mdl"},
    }

    -- create town "villagers" (use special effects)
    for i = 1, #villagers do
        local v = villagers[i]
        v.unit = AddSpecialEffect(v.model, v.x, v.y)
        BlzSetSpecialEffectYaw(v.unit, GetRandomReal(0, 2 * bj_PI))
    end

    KILL_VILLAGERS = function()
        for i = 1, #villagers do
            local v = villagers[i]
            HideEffect(v.unit)
        end
        villagers = nil
    end
end, Debug and Debug.getLine())
