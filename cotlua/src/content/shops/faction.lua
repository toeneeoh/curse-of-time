-- Separate faction shop catalogs and their faction-exclusive flasks.

OnInit.final("FactionShop", function(Require)
    Require('ItemHelpers')
    Require('FactionConsumables')
    Require('MiningMaterials')
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

    local socket_recipes = {
        {
            key = "craft_vigor_gem_socket",
            item_id = FourCC('I0O1'),
            name = "Vigor Gem",
            icon = "ReplaceableTextures\\CommandButtons\\BTNRed.blp",
            costs = {
                [MiningMaterials.IRONSTONE] = 18,
                [MiningMaterials.PRISMATIC_ORE] = 8,
                [MiningMaterials.FORGOTTEN_CRYSTAL] = 2,
            },
            tooltip = "Forge a Vigor Gem socket.|n|n|cffffcc00Materials:|r 18 Ironstone, 8 Prismatic Ore, 2 Forgotten Crystals.|n|cff808080A setting for strength, endurance, and recovery.|r",
        }, {
            key = "craft_torture_jewel_socket",
            item_id = FourCC('I0OB'),
            name = "Torture Jewel",
            icon = "ReplaceableTextures\\CommandButtons\\BTNGreen.blp",
            costs = {
                [MiningMaterials.IRONSTONE] = 8,
                [MiningMaterials.PRISMATIC_ORE] = 18,
                [MiningMaterials.FORGOTTEN_CRYSTAL] = 2,
            },
            tooltip = "Forge a Torture Jewel socket.|n|n|cffffcc00Materials:|r 8 Ironstone, 18 Prismatic Ore, 2 Forgotten Crystals.|n|cff808080A setting sharpened for speed and ruthless precision.|r",
        }, {
            key = "craft_lexium_crystal_socket",
            item_id = FourCC('I0CH'),
            name = "Lexium Crystal",
            icon = "ReplaceableTextures\\CommandButtons\\BTNBlue.blp",
            costs = {
                [MiningMaterials.IRONSTONE] = 12,
                [MiningMaterials.PRISMATIC_ORE] = 12,
                [MiningMaterials.FORGOTTEN_CRYSTAL] = 3,
            },
            tooltip = "Forge a Lexium Crystal socket.|n|n|cffffcc00Materials:|r 12 Ironstone, 12 Prismatic Ore, 3 Forgotten Crystals.|n|cff808080A setting that channels sorcery through flawless facets.|r",
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


        if shop.faction_id == 1 then
            for recipe_index = 1, #socket_recipes do
                local recipe = socket_recipes[recipe_index]
                ShopAddOffer(shop.id, {
                    key = recipe.key,
                    name = recipe.name,
                    icon = recipe.icon,
                    tooltip = recipe.tooltip,
                    categories = misc,
                    availability = function(pid)
                        local available, reason = availability(pid, 1, 5)
                        if not available then return false, reason end
                        return MiningMaterials.canAfford(pid, recipe.costs)
                    end,
                    purchase = function(pid)
                        if not MiningMaterials.consume(pid, recipe.costs) then
                            return false
                        end
                        PlayerAddItemById(pid, recipe.item_id)
                        return true
                    end,
                })
            end
        end
    end
end, Debug and Debug.getLine())
