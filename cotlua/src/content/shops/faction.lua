-- Separate faction shop catalogs and their faction-exclusive flasks.

OnInit.final("FactionShop", function(Require)
    Require('ItemHelpers')
    Require('FactionConsumables')
    Require('PotionService')
    Require('Prices')
    Require('ShopRegistry')

    local REQUIRED_LEVEL = 200
    local REQUIRED_RANK = 4
    local FLASK_PRICE = 150
    local STORMWISE_BEACON_PRICE = 40
    local SPACE_LASER_PRICE = 15
    local POTION_ICON =
        "ReplaceableTextures\\CommandButtons\\BTNPotionGreenSmall.blp"

    local shops = {
        {
            id = FourCC('n004'),
            faction_id = 1,
            potion = PotionService.STONEBLOOD_KEY
        }, {
            id = FourCC('n0P0'),
            faction_id = 2,
            potion = PotionService.TEMPEST_KEY
        }, {
            id = FourCC('n0P1'),
            faction_id = 3,
            potion = PotionService.HUNTERS_KEY
        }
    }

    local function availability(pid, faction_id, required_rank)
        local hero = Hero[pid]
        if not hero then return false, "NO HERO" end
        if GetHeroLevel(hero) < REQUIRED_LEVEL then
            return false, "REQUIRES LEVEL " .. REQUIRED_LEVEL
        end

        local faction = Faction.getFaction(pid)
        if not faction or faction.id ~= faction_id then
            return false, "WRONG FACTION"
        end

        local rank = Faction.getRank(Faction.getReputation(pid, faction_id))
        required_rank = required_rank or REQUIRED_RANK
        if rank < required_rank then
            return false, "REQUIRES RANK " .. required_rank
        end
        return true
    end

    local function purchase(pid, key)
        local hero = Hero[pid]
        if not hero then return false end
        local item = PotionService.create(key, GetUnitX(hero), GetUnitY(hero))
        if not item then return false end
        PlayerAddItem(pid, item)
        return true
    end

    for index = 1, #shops do
        local shop = shops[index]
        CreateShop(shop.id, 1000.)
        ShopSetAccess(shop.id, function(pid)
            local faction = Faction.getFaction(pid)
            return faction ~= nil and faction.id == shop.faction_id,
                   "WRONG FACTION"
        end)
        local misc = ShopAddCategory(shop.id,
            "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp",
            "Miscellaneous")
        local potions = ShopAddCategory(shop.id, POTION_ICON, "Potions")

        SetItemPrice('I00K', {faction = 100})
        ShopAddItem(shop.id, 'I00K:0', misc)

        local name, icon, tooltip =
            PotionService.getCatalogPresentation(shop.potion)
        ShopAddOffer(shop.id, {
            key = "faction_" .. shop.potion,
            name = name,
            icon = icon,
            tooltip = tooltip,
            categories = potions,
            price = {faction = FLASK_PRICE},
            availability = function(pid)
                return availability(pid, shop.faction_id)
            end,
            purchase = function(pid)
                return purchase(pid, shop.potion)
            end
        })

        if shop.faction_id == 2 then
            local beacon_name, beacon_icon, beacon_tooltip =
                FactionConsumables.getCatalogPresentation(
                    FactionConsumables.STORMWISE_BEACON_KEY)
            ShopAddOffer(shop.id, {
                key = "stormwatch_stormwise_beacon",
                name = beacon_name,
                icon = beacon_icon,
                tooltip = beacon_tooltip ..
                    "|n|cffff0000Faction Rank Requirement: |r4",
                categories = misc,
                price = {faction = STORMWISE_BEACON_PRICE},
                availability = function(pid)
                    return availability(pid, shop.faction_id, 4)
                end,
                purchase = function(pid)
                    return FactionConsumables.create(
                               FactionConsumables.STORMWISE_BEACON_KEY, pid)
                end
            })
            local laser_name, laser_icon, laser_tooltip =
                FactionConsumables.getCatalogPresentation(
                    FactionConsumables.GOBLIN_SPACE_LASER_KEY)
            ShopAddOffer(shop.id, {
                key = "stormwatch_goblin_space_laser",
                name = laser_name,
                icon = laser_icon,
                tooltip = laser_tooltip ..
                    "|n|cffff0000Faction Rank Requirement: |r2",
                categories = misc,
                price = {faction = SPACE_LASER_PRICE},
                availability = function(pid)
                    return availability(pid, shop.faction_id, 2)
                end,
                purchase = function(pid)
                    return FactionConsumables.create(
                               FactionConsumables.GOBLIN_SPACE_LASER_KEY, pid)
                end
            })
        end
    end
end, Debug and Debug.getLine())
