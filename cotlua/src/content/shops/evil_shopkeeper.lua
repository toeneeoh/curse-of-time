-- Roaming evil shopkeeper inventory.

OnInit.final("EvilShopkeeperShop", function(Require)
    Require('PotionService')
    Require('ShopRegistry')

    local shop_id = FourCC('n01F')
    CreateShop(shop_id, 1000.)

    local function prechaos() return not CHAOS_MODE end
    local function chaos() return CHAOS_MODE end

    local sword = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNThoriumMelee.blp", "Sword",
        prechaos)
    local heavy = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNImprovedStrengthOfTheMoon.tga",
        "Heavy", prechaos)
    local dagger = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNDaggerOfEscape.blp", "Dagger",
        prechaos)
    local bow = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNScoutsBow.blp", "Bow",
        prechaos)
    local staff = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNWitchDoctorAdept.blp", "Staff",
        prechaos)
    local plate = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNAdvancedMoonArmor.blp", "Plate",
        prechaos)
    ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNArmorGolem.blp", "Fullplate",
        prechaos)
    ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNLeatherUpgradeOne.blp", "Leather",
        prechaos)
    local cloth = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNMantleOfIntelligence.blp", "Cloth",
        prechaos)
    local misc = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous",
        prechaos)

    local prechaos_stock = {
        'I02B:0', 'I02C:0', 'I0EY:0', 'I074:0', 'I03U:0', 'I07F:0',
        'I03P:0', 'I0F9:0', 'I079:0', 'I0FC:0', 'I00A:0',
    }
    ShopAddItem(shop_id, 'I02B:0', sword, prechaos)
    ShopAddItem(shop_id, 'I02C:0', plate, prechaos)
    ShopAddItem(shop_id, 'I0EY:0', bow, prechaos)
    ShopAddItem(shop_id, 'I074:0', dagger, prechaos)
    ShopAddItem(shop_id, 'I03U:0', staff, prechaos)
    ShopAddItem(shop_id, 'I07F:0', cloth, prechaos)
    ShopAddItem(shop_id, 'I03P:0', heavy, prechaos)
    ShopAddItem(shop_id, 'I0F9:0', misc, prechaos)
    ShopAddItem(shop_id, 'I079:0', heavy, prechaos)
    ShopAddItem(shop_id, 'I0FC:0', heavy, prechaos)
    ShopAddItem(shop_id, 'I00A:0', misc, prechaos)

    local potions = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNPotionGreenSmall.blp", "Potions",
        chaos)
    local name, icon, tooltip = PotionService.getChaosDonorPresentation()
    ShopAddOffer(shop_id, {
        key = "evil_mystery_epic_flask",
        name = name,
        icon = icon,
        tooltip = tooltip,
        categories = potions,
        catalog_visible = chaos,
        price = { platinum = 30 },
        availability = function()
            return CHAOS_MODE, "AVAILABLE IN CHAOS"
        end,
        purchase = function(pid)
            local hero = Hero[pid]
            if not hero then return false end
            local item = PotionService.createChaosDonor(
                GetUnitX(hero), GetUnitY(hero))
            if not item then return false end
            PlayerAddItem(pid, item)
            return true
        end,
    })

    function RefreshEvilShopkeeperCatalog()
        local old_stock = CHAOS_MODE and 0 or 1
        for index = 1, #prechaos_stock do
            ShopSetStock(shop_id, prechaos_stock[index], old_stock)
        end
        ShopSetStock(shop_id, "offer:evil_mystery_epic_flask",
                     CHAOS_MODE and 1 or 0)
        ShopRegistry.refreshCatalog(shop_id)
    end

    RefreshEvilShopkeeperCatalog()
end, Debug and Debug.getLine())
