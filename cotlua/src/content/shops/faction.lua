-- Separate faction shop catalogs and their faction-exclusive flasks.

OnInit.final("FactionShop", function(Require)
    Require('ItemHelpers')
    Require('PotionService')
    Require('Prices')
    Require('ShopRegistry')

    local REQUIRED_LEVEL = 200
    local REQUIRED_RANK = 4
    local FLASK_PRICE = 150
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

    local function availability(pid, faction_id)
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
        if rank < REQUIRED_RANK then
            return false, "REQUIRES RANK " .. REQUIRED_RANK
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
    end
end, Debug and Debug.getLine())
