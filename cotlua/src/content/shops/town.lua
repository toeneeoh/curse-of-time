-- Town shop inventory and prices.

OnInit.final("TownShops", function(Require)
    Require('ShopRegistry')
    Require('Prices')

    local general_shop = FourCC('n01A')
    CreateShop(general_shop, 1000.)
    local common = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNRingGreen.blp", "Common")
    local sword = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNThoriumMelee.blp", "Sword")
    local heavy = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNImprovedStrengthOfTheMoon.tga", "Heavy")
    local dagger = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNDaggerOfEscape.blp", "Dagger")
    local bow = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNScoutsBow.blp", "Bow")
    local staff = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNWitchDoctorAdept.blp", "Staff")
    local plate = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNAdvancedMoonArmor.blp", "Plate")
    ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNArmorGolem.blp", "Fullplate")
    local leather = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNLeatherUpgradeOne.blp", "Leather")
    local cloth = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNMantleOfIntelligence.blp", "Cloth")
    local shield = ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNHumanArmorUpTwo.blp", "Shield")
    ShopAddCategory(general_shop, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous")

    ---@class TownShopItem
    ---@field [1] string
    ---@field [2] number
    ---@field [3] integer
    ---@type TownShopItem[]
    local items = {
        {'I01D', 90, common}, {'I07S', 50, common}, {'I08X', 400, shield},
        {'I00P', 1000, common}, {'I024', 50, common}, {'I026', 50, common},
        {'I00Q', 50, common}, {'I02T', 50, common}, {'I01T', 15000, common},
        {'I01M', 1200, common}, {'I08Y', 250, common}, {'I06H', 500, common},
        {'I00H', 300, common}, {'I00I', 800, common}, {'I00G', 300, common},
        {'I08V', 200, common}, {'I06F', 30, common}, {'I01A', 100, common},
        {'I01I', 30, sword}, {'I03W', 80, sword}, {'I0FK', 500, sword},
        {'I01F', 30, heavy}, {'I03K', 80, heavy}, {'I00F', 500, heavy},
        {'I01G', 30, dagger}, {'I03A', 80, dagger}, {'I010', 500, dagger},
        {'I02H', 30, bow}, {'I01L', 80, bow}, {'I0FM', 500, bow},
        {'I04O', 30, staff}, {'I00O', 80, staff}, {'I00N', 500, staff},
        {'I01H', 30, shield}, {'I03S', 90, shield}, {'I0FL', 500, shield},
        {'I04D', 50, cloth}, {'I02R', 150, cloth}, {'I004', 150, plate},
        {'I01K', 150, leather},
    }
    for index = 1, #items do
        local item = items[index]
        SetItemPrice(item[1], item[2])
        ShopAddItem(general_shop, item[1] .. ':0', item[3])
    end

    local magic_shop = FourCC('n01B')
    CreateShop(magic_shop, 1000.)
    ShopAddItem(magic_shop, 'I0TS:0', 0)
    ShopAddItem(magic_shop, 'I0TA:0', 0)
    ShopAddItem(magic_shop, 'I0TI:0', 0)
    ShopAddItem(magic_shop, 'I0TT:0', 0)
    ShopAddItem(magic_shop, 'I0N0:0', 0)
    ShopAddItem(magic_shop, 'I0JN:0', 0)
    ShopAddItem(magic_shop, 'I0JS:0', 0)
    ShopAddItem(magic_shop, 'I00J:0', 0)
    SetItemPrice('I084', { platinum = 4 })
    ShopAddItem(magic_shop, 'I084:0', 0)
    ShopAddItem(magic_shop, 'I102:0', 0)
    ShopAddItem(magic_shop, 'I101:0', 0)

    local vendor = FourCC('n032')
    CreateShop(vendor, 1000.)
    ShopAddCategory(vendor, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous")
    ShopAddCategory(vendor, "ReplaceableTextures\\CommandButtons\\BTNChisel.dds", "Socketable")
end, Debug and Debug.getLine())
