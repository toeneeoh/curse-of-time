--[[
    town.lua
]]

OnInit.final("Town", function(Require)
    Require('Currency')
    Require('DialogWindow')
    Require('ItemEventRegistry')
    Require('ItemHelpers')
    Require('ItemSchema')
    Require('Profile')

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

    --#region upgrade item anvil
    ---@return boolean
    local function confirm_upgrade_item(self, index, data)
        if index ~= -1 then
            local pid = self.pid
            local itm = data

            AddCurrency(pid, GOLD, -self.data[1])
            AddCurrency(pid, PLATINUM, -self.data[2])
            AddCurrency(pid, CRYSTAL, -self.data[3])

            itm:lvl(itm.level + 1)
            DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 20, "You successfully upgraded to: " .. itm:name())

            self:destroy()
        end

        return false
    end

    ---@return boolean
    local function upgrade_item(self, index, data)
        if index ~= -1 then
            local pid = self.pid
            local itm = data

            self:destroy()

            if itm then
                local goldCost = ModuloInteger(itm.cached_stats[ITEM_COST], 1000000)
                local platCost = itm.cached_stats[ITEM_COST] // 1000000
                local crystalCost = CRYSTAL_PRICE[itm.level]
                local s = "Upgrade cost: |n" ---@type string

                if platCost > 0 then
                    s = s .. "|cffffffff" .. (platCost) .. "|r |cffe3e2e2Platinum|r|n"
                end

                if goldCost > 0 then
                    s = s .. "|cffffffff" .. (goldCost) .. "|r |cffffcc00Gold|r|n"
                end

                if crystalCost > 0 then
                    s = s .. "|cffffffff" .. (crystalCost) .. "|r |cff6969FFCrystals|r|n"
                end

                local dw = DialogWindow.create(pid, s, confirm_upgrade_item)
                dw.data[1] = goldCost
                dw.data[2] = platCost
                dw.data[3] = crystalCost

                if GetCurrency(pid, GOLD) >= goldCost and GetCurrency(pid, PLATINUM) >= platCost and GetCurrency(pid, CRYSTAL) >= crystalCost then
                    dw:addButton("Upgrade", itm)
                end

                dw:display()
            end
        end

        return false
    end

    ITEM_LOOKUP[FourCC('I100')] = function(p, pid, u, itm)
        local dw = DialogWindow.create(pid, "Choose an item to upgrade", upgrade_item) ---@type DialogWindow

        for index = 1, MAX_INVENTORY_SLOTS do
            local it = Profile[pid].hero.items[index]

            if it and ItemIsUpgradeable(it) then
                dw:addButton(it:name(), it)
            end
        end

        dw:display()
    end
    --#endregion

end, Debug and Debug.getLine())
