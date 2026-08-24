--[[
    town.lua
]]

OnInit.final("Town", function(Require)
    Require('Shop')
    Require('Prices')

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

    ITEM_LOOKUP[FourCC('I101')] = function(p, pid, u, itm)
        local lvl = (itm.id == FourCC('I101') and GetUnitAbilityLevel(Backpack[pid], TELEPORT.id)) or GetUnitAbilityLevel(Backpack[pid], FourCC('A0FK'))

        if lvl < 10 then -- 10 upgrade limit
            local dw ---@type DialogWindow
            local index = R2I(400. * Pow(5., lvl - 1.))

            if index > 1000000 then
                dw = DialogWindow.create(pid, "Upgrade cost: |n|cffffffff" .. (index // 1000000) .. " |cffe3e2e2Platinum|r |cffffffffand " .. ModuloInteger(index, 1000000) .. " |cffffcc00Gold|r", BackpackUpgrades)
            else
                dw = DialogWindow.create(pid, "Upgrade cost: |n|cffffffff" .. (index) .. " |cffffcc00Gold|r", BackpackUpgrades)
            end

            if GetCurrency(pid, GOLD) >= ModuloInteger(index, 1000000) and GetCurrency(pid, PLATINUM) >= R2I(index / 1000000) then
                dw.data[0] = itemid
                dw.data[1] = index
                dw:addButton("Upgrade")
            end

            dw:display()
        end
    end

    ITEM_LOOKUP[FourCC('I102')] = ITEM_LOOKUP[FourCC('I101')]

    --#region town general shop
    local general_shop = FourCC('n01A')
    CreateShop(general_shop, 1000.)
    local common = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNRingGreen.blp", "Common")
    local sword = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNThoriumMelee.blp", "Sword")
    local heavy = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNImprovedStrengthOfTheMoon.tga", "Heavy")
    local dagger = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNDaggerOfEscape.blp", "Dagger")
    local bow = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNScoutsBow.blp", "Bow")
    local staff = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNWitchDoctorAdept.blp", "Staff")
    local plate = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNAdvancedMoonArmor.blp", "Plate")
    local fullplate = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNArmorGolem.blp", "Fullplate")
    local leather = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNLeatherUpgradeOne.blp", "Leather")
    local cloth = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNMantleOfIntelligence.blp", "Cloth")
    local shield = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNHumanArmorUpTwo.blp", "Shield")
    local misc = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous")

    -- good shoes
    SetItemPrice('I01D', 90)
    ShopAddItem(general_shop, 'I01D:0', common)
    -- good gloves
    SetItemPrice('I07S', 50)
    ShopAddItem(general_shop, 'I07S:0', common)
    -- good shield
    SetItemPrice('I08X', 400)
    ShopAddItem(general_shop, 'I08X:0', shield)
    -- waug ring
    SetItemPrice('I00P', 1000)
    ShopAddItem(general_shop, 'I00P:0', common)
    -- ring of health
    SetItemPrice('I024', 50)
    ShopAddItem(general_shop, 'I024:0', common)
    -- ring of mana
    SetItemPrice('I026', 50)
    ShopAddItem(general_shop, 'I026:0', common)
    -- belt of the giant
    SetItemPrice('I00Q', 50)
    ShopAddItem(general_shop, 'I00Q:0', common)
    -- slippers of agility
    SetItemPrice('I02T', 50)
    ShopAddItem(general_shop, 'I02T:0', common)
    -- armor of the gods
    SetItemPrice('I01T', 15000)
    ShopAddItem(general_shop, 'I01T:0', common)
    -- axe of smiting
    SetItemPrice('I01M', 1200)
    ShopAddItem(general_shop, 'I01M:0', common)
    -- noble blade
    SetItemPrice('I08Y', 250)
    ShopAddItem(general_shop, 'I08Y:0', common)
    -- warsong battle drums
    SetItemPrice('I06H', 500)
    ShopAddItem(general_shop, 'I06H:0', common)
    -- blood horn
    SetItemPrice('I00H', 300)
    ShopAddItem(general_shop, 'I00H:0', common)
    -- blood shield
    SetItemPrice('I00I', 800)
    ShopAddItem(general_shop, 'I00I:0', common)
    -- blood elf war drums
    SetItemPrice('I00G', 300)
    ShopAddItem(general_shop, 'I00G:0', common)
    -- gem of true sight
    SetItemPrice('I08V', 200)
    ShopAddItem(general_shop, 'I08V:0', common)
    -- crystal ball
    SetItemPrice('I06F', 30)
    ShopAddItem(general_shop, 'I06F:0', common)
    -- dimensional key
    SetItemPrice('I01A', 100)
    ShopAddItem(general_shop, 'I01A:0', common)

    -- iron sword
    SetItemPrice('I01I', 30)
    ShopAddItem(general_shop, 'I01I:0', sword)
    -- steel sword
    SetItemPrice('I03W', 80)
    ShopAddItem(general_shop, 'I03W:0', sword)
    -- mythril sword
    SetItemPrice('I0FK', 500)
    ShopAddItem(general_shop, 'I0FK:0', sword)

    -- iron broadsword
    SetItemPrice('I01F', 30)
    ShopAddItem(general_shop, 'I01F:0', heavy)
    -- steel lance
    SetItemPrice('I03K', 80)
    ShopAddItem(general_shop, 'I03K:0', heavy)
    -- mythril spear
    SetItemPrice('I00F', 500)
    ShopAddItem(general_shop, 'I00F:0', heavy)

    -- iron dagger
    SetItemPrice('I01G', 30)
    ShopAddItem(general_shop, 'I01G:0', dagger)
    -- steel dagger
    SetItemPrice('I03A', 80)
    ShopAddItem(general_shop, 'I03A:0', dagger)
    -- mythril dagger
    SetItemPrice('I010', 500)
    ShopAddItem(general_shop, 'I010:0', dagger)

    -- short bow
    SetItemPrice('I02H', 30)
    ShopAddItem(general_shop, 'I02H:0', bow)
    -- long bow
    SetItemPrice('I01L', 80)
    ShopAddItem(general_shop, 'I01L:0', bow)
    -- blood elven bow
    SetItemPrice('I0FM', 500)
    ShopAddItem(general_shop, 'I0FM:0', bow)

    -- wooden staff
    SetItemPrice('I04O', 30)
    ShopAddItem(general_shop, 'I04O:0', staff)
    -- arcane staff
    SetItemPrice('I00O', 80)
    ShopAddItem(general_shop, 'I00O:0', staff)
    -- blood elven staff
    SetItemPrice('I00N', 500)
    ShopAddItem(general_shop, 'I00N:0', staff)

    -- iron shield
    SetItemPrice('I01H', 30)
    ShopAddItem(general_shop, 'I01H:0', shield)
    -- steel shield
    SetItemPrice('I03S', 90)
    ShopAddItem(general_shop, 'I03S:0', shield)
    -- mythril shield
    SetItemPrice('I0FL', 500)
    ShopAddItem(general_shop, 'I0FL:0', shield)

    -- tattered cloth
    SetItemPrice('I04D', 50)
    ShopAddItem(general_shop, 'I04D:0', cloth)
    -- sigil of magic
    SetItemPrice('I02R', 150)
    ShopAddItem(general_shop, 'I02R:0', cloth)

    -- steel plate
    SetItemPrice('I004', 150)
    ShopAddItem(general_shop, 'I004:0', plate)

    -- leather jacket
    SetItemPrice('I01K', 150)
    ShopAddItem(general_shop, 'I01K:0', leather)

    --#endregion

    --#region upgrade / magic shop
    local magic_shop = FourCC('n01B')
    CreateShop(magic_shop, 1000.)

    ShopAddItem(magic_shop, 'I0TS:0', 0)
    SetItemAvailability('I0TS', true)

    --[[
    I0TS tome of strength
    I0TA tome of agility
    I0TI tome of intelligence
    I0TT tome of knowledge
    I0N0 grimoire of focus
    I0JN tome of retraining

    I0JS recharge reincarnation
    I00J refill potions

    I084 currency converter
    I102 reveal upgrade
    I101 teleport upgrade
    ]]

    --#endregion

    --#region prize vendor
    local vendor = FourCC('n032')
    CreateShop(vendor, 1000.)
    misc = ShopAddCategory(vendor, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous")
    local socketable = ShopAddCategory(vendor, "ReplaceableTextures\\CommandButtons\\BTNChisel.dds", "Socketable")

    --#endregion
end, Debug and Debug.getLine())
