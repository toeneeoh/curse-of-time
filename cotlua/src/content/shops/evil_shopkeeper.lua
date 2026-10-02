-- Roaming evil shopkeeper inventory.

OnInit.final("EvilShopkeeperShop", function(Require)
    Require('PotionService')
    Require('ShopRegistry')

    local shop_id = FourCC('n01F')
    CreateShop(shop_id, 1000.)

    local potions = ShopAddCategory(shop_id,
        "ReplaceableTextures\\CommandButtons\\BTNPotionGreenSmall.blp", "Potions")
    local name, icon, tooltip = PotionService.getChaosDonorPresentation()
    ShopAddOffer(shop_id, {
        key = "evil_mystery_epic_flask",
        name = name,
        icon = icon,
        tooltip = tooltip,
        categories = potions,
        price = { platinum = 30 },
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
    ShopSetStock(shop_id, "offer:evil_mystery_epic_flask", 1)
end, Debug and Debug.getLine())
