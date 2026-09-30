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

    local faction_consumables = {
        [1] = {
            {
                offer_key = "cave_voyagers_reinforced_pit_prop",
                item_key = FactionConsumables.REINFORCED_PIT_PROP_KEY,
                price = 100,
                rank = 4,
            }, {
                offer_key = "cave_voyagers_seismic_survey_charge",
                item_key = FactionConsumables.SEISMIC_SURVEY_CHARGE_KEY,
                price = 20,
                rank = 2,
            },
        },
        [2] = {
            {
                offer_key = "stormwatch_stormwise_beacon",
                item_key = FactionConsumables.STORMWISE_BEACON_KEY,
                price = 100,
                rank = 4,
            }, {
                offer_key = "stormwatch_goblin_space_laser",
                item_key = FactionConsumables.GOBLIN_SPACE_LASER_KEY,
                price = 50,
                rank = 2,
            },
        },
        [3] = {
            {
                offer_key = "ashen_vanguard_campaign_standard",
                item_key = FactionConsumables.CAMPAIGN_STANDARD_KEY,
                price = 40,
                rank = 4,
            }, {
                offer_key = "ashen_vanguard_bounty",
                item_key = FactionConsumables.VANGUARD_BOUNTY_KEY,
                price = 150,
                rank = 4,
            },
        },
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

        local extras = faction_consumables[shop.faction_id]
        for offer_index = 1, #extras do
            local offer = extras[offer_index]
            local offer_name, offer_icon, offer_tooltip =
                FactionConsumables.getCatalogPresentation(offer.item_key)
            ShopAddOffer(shop.id, {
                key = offer.offer_key,
                name = offer_name,
                icon = offer_icon,
                tooltip = offer_tooltip,
                categories = misc,
                price = {faction = offer.price},
                availability = function(pid)
                    return availability(pid, shop.faction_id, offer.rank)
                end,
                purchase = function(pid)
                    return FactionConsumables.create(offer.item_key, pid)
                end
            })
        end
    end
end, Debug and Debug.getLine())
