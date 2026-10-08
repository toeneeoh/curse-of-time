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

        RefreshEvilShopkeeperCatalog()

        local ghost = FourCC('Agho')
        UnitRemoveAbility(shop, ghost)
        TimerQueue:callDelayed(5., UnitAddAbility, shop, ghost)
        SHOPKEEPER_CALLBACK = TimerQueue:callDelayed(300., MoveShopkeeper)
    end
end, Debug and Debug.getLine())
