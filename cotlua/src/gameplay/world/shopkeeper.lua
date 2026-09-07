OnInit.global("Shopkeeper", function(Require)
    Require('MainMap')
    Require('Variables')
    Require('TimerQueue')
    Require('ShopRegistry')

    local shop_id = FourCC('n01F')
    local random = math.random

    function MoveShopkeeper()
        local shop = evilshopkeeper

        if not UnitAlive(shop) then
            return
        end

        local x = 0.
        local y = 0.

        repeat
            x = GetRandomReal(MAIN_MAP.minX, MAIN_MAP.maxX)
            y = GetRandomReal(MAIN_MAP.minY, MAIN_MAP.maxY)

            if random(0, 99) < 5 then
                x = GetRandomReal(GetRectMinX(gg_rct_Tavern), GetRectMaxX(gg_rct_Tavern))
                y = GetRandomReal(GetRectMinY(gg_rct_Tavern), GetRectMaxY(gg_rct_Tavern))
            end
        until IsTerrainWalkable(x, y)

        ShopRegistry.setVisible(shop_id, false)
        ShowUnit(shop, false)
        ShowUnit(shop, true)
        SetUnitPosition(shop, x, y)
        BlzStartUnitAbilityCooldown(shop, FourCC('A017'), 300.)

        ShopSetStock(shop_id, 'I02B:0', 1)
        ShopSetStock(shop_id, 'I02C:0', 1)
        ShopSetStock(shop_id, 'I0EY:0', 1)
        ShopSetStock(shop_id, 'I074:0', 1)
        ShopSetStock(shop_id, 'I03U:0', 1)
        ShopSetStock(shop_id, 'I07F:0', 1)
        ShopSetStock(shop_id, 'I03P:0', 1)
        ShopSetStock(shop_id, 'I0F9:0', 1)
        ShopSetStock(shop_id, 'I079:0', 1)
        ShopSetStock(shop_id, 'I0FC:0', 1)
        ShopSetStock(shop_id, 'I00A:0', 1)

        local ghost = FourCC('Agho')
        UnitRemoveAbility(shop, ghost)
        TimerQueue:callDelayed(5., UnitAddAbility, shop, ghost)
        SHOPKEEPER_CALLBACK = TimerQueue:callDelayed(300., MoveShopkeeper)
    end
end, Debug and Debug.getLine())
