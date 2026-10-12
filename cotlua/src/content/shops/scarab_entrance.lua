-- Existing native merchant plus a virtual entrance service; no new editor item.
OnInit.final('ScarabEntranceShop', function(Require)
    Require('ScarabDungeon')
    Require('ShopRegistry')
    local dungeon = DUNGEON_SCARAB
    local shop_id = FourCC('nmrk') -- Existing native Marketplace placeholder.
    local merchant = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), shop_id,
        dungeon.queue_x, dungeon.queue_y, 270.)
    BlzSetUnitName(merchant, 'Scarab Expedition')
    UnitAddAbility(merchant, ABIL_AVUL)
    -- The custom catalog is the only shop; do not expose native marketplace stock.
    UnitRemoveAbility(merchant, FourCC('Asid'))
    UnitRemoveAbility(merchant, FourCC('Asud'))
    CreateShop(shop_id, 750.)
    ShopAddOffer(shop_id, {
        key = 'scarab_dungeon_entrance', name = 'Enter the Scarab Tunnels',
        icon = 'ReplaceableTextures\\CommandButtons\\BTNCarrionScarabs.blp',
        tooltip = '|cffff0000Level Requirement: 500|r\n|cff3399ffEnter:|r Open the expedition ready check. Nearby players can join before the party sets out.\n|cff808080Beyond the entrance, the hive stretches into darkness.|r',
        price = 0,
        availability = function(pid)
            if not dungeon:isEligible(pid) then return false, 'REQUIRES LEVEL 500 / NEARBY HERO' end
            if dungeon.started then return false, 'IN PROGRESS' end
            return dungeon:canStart()
        end,
        purchase = function(pid)
            local ok, reason = dungeon:queue(pid)
            if not ok then DisplayTextToPlayer(Player(pid - 1), 0, 0, reason or 'Dungeon unavailable.') end
            return ok
        end,
    })
end, Debug and Debug.getLine())
