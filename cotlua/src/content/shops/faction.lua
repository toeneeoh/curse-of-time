-- Faction shop inventory and prices.

OnInit.final("FactionShop", function(Require)
    Require('ShopRegistry')
    Require('Prices')

    local shop_id = FourCC('n004')
    CreateShop(shop_id, 1000.)
    local misc = ShopAddCategory(shop_id, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous")
    SetItemPrice('I00K', { faction = 100 })
    ShopAddItem(shop_id, 'I00K:0', misc)
end, Debug and Debug.getLine())
