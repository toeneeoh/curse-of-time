-- Honor rewards offered by the Colosseum Prize Vendor.

OnInit.final("ColosseumShop", function(Require)
    Require('ShopRegistry')
    Require('Honor')
    Require('StruggleRewards')
    Require('UnitTable')

    local shop_id = FourCC('n032')
    CreateShop(shop_id, 1000.)
    local bonuses = ShopAddCategory(shop_id, "ReplaceableTextures\\CommandButtons\\BTNHeroPaladin.blp", "Bonuses")
    local services = ShopAddCategory(shop_id, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", "Services")
    local struggle = ShopAddCategory(shop_id, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Struggle")

    local reward_data = {
        {
            key = "gladiators_might",
            name = "Colosseum Might",
            icon = "ReplaceableTextures\\CommandButtons\\BTNBattleRoar.blp",
            max_rank = 5,
            detail = "Gain |cffffcc003%|r attack damage and Spellboost per rank while inside the Colosseum.",
            apply = function(pid, old_rank, new_rank)
                local delta = (new_rank - old_rank) * 0.03
                local hero = Hero[pid]
                local unit = hero and Unit[hero]
                if unit then
                    unit.damage_percent = unit.damage_percent + delta
                    unit.spellboost = unit.spellboost + delta
                end
            end,
        },
        {
            key = "gladiators_resolve",
            name = "Colosseum Resolve",
            icon = "ReplaceableTextures\\CommandButtons\\BTNDefend.blp",
            max_rank = 5,
            detail = "Take |cffffcc003%|r less damage per rank while inside the Colosseum.",
            apply = function(pid, old_rank, new_rank)
                local hero = Hero[pid]
                local unit = hero and Unit[hero]
                if unit then
                    unit.dr = unit.dr * (0.97 ^ (new_rank - old_rank))
                end
            end,
        },
        {
            key = "gladiators_stride",
            name = "Colosseum Stride",
            icon = "ReplaceableTextures\\CommandButtons\\BTNBootsOfSpeed.blp",
            max_rank = 5,
            detail = "Gain |cffffcc0010|r movespeed per rank while inside the Colosseum.",
            apply = function(pid, old_rank, new_rank)
                local hero = Hero[pid]
                local unit = hero and Unit[hero]
                if unit then
                    unit.ms_flat = unit.ms_flat + (new_rank - old_rank) * 10
                end
            end,
        },
        {
            key = "colosseum_spoils",
            name = "Colosseum Spoils",
            icon = "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp",
            max_rank = 5,
            detail = "Gain |cffffcc0010%|r more gold from Colosseum rewards per rank.",
            apply = function() end,
        },
    }

    for index = 1, #reward_data do
        local reward = reward_data[index]
        Honor.registerReward(reward)
        ShopAddOffer(shop_id, {
            key = reward.key,
            name = function(pid)
                return reward.name .. " |cff999999(" .. Honor.getRank(pid, reward.key) .. "/" .. reward.max_rank .. ")|r"
            end,
            icon = reward.icon,
            tooltip = function(pid)
                return reward.detail .. "\n\nCurrent Rank: |cffffcc00" .. Honor.getRank(pid, reward.key)
                    .. "|r/|cffffcc00" .. reward.max_rank .. "|r"
            end,
            categories = bonuses,
            price = function(pid)
                return { [HONOR] = Honor.getNextCost(pid, reward.key) }
            end,
            availability = function(pid)
                if Honor.getRank(pid, reward.key) >= reward.max_rank then
                    return false, "MAX RANK"
                end
                return true
            end,
            purchase = function(pid)
                return Honor.allocate(pid, reward.key)
            end,
        })
    end

    ShopAddOffer(shop_id, {
        key = "reset_honor",
        name = "Reset Honor Allocations",
        icon = "ReplaceableTextures\\CommandButtons\\BTNCancel.blp",
        disabled_icon = "ReplaceableTextures\\CommandButtonsDisabled\\DISBTNCancel.blp",
        tooltip = "Refund all Honor allocated to Colosseum bonuses. Honor earned is never lost.",
        categories = services,
        availability = function(pid)
            if Honor.getAllocated(pid) == 0 then
                return false, "NO HONOR"
            end
            return true
        end,
        purchase = function(pid)
            return Honor.reset(pid)
        end,
    })

    local function struggle_tooltip(pid, form)
        local rank = StruggleRewards.getClaimRank(pid)
        local attribute = rank > 0 and StruggleRewards.getAttributeBonus(rank) or 0
        local percentage = rank > 0 and StruggleRewards.getPercentageBonus(rank) or 0
        return "Redeem the highest secured Struggle checkpoint as a " .. form .. "."
            .. " If you already own one, it is upgraded in place, including while socketed."
            .. " Only one Ring of Struggle may be equipped or one Struggle Gem socketed at a time."
            .. "\n\nReward Rank: |cffffcc00" .. rank .. "|r/|cffffcc00100|r"
            .. "\nAll Attributes: |cffffcc00+" .. attribute .. "|r"
            .. "\nSpellboost: |cffffcc00+" .. percentage .. "%|r"
            .. "\nGold Find: |cffffcc00+" .. percentage .. "%|r"
    end

    ShopAddOffer(shop_id, {
        key = "struggle_ring",
        name = function(pid)
            return "Ring of Struggle |cff999999(Rank " .. StruggleRewards.getClaimRank(pid) .. ")|r"
        end,
        icon = "ReplaceableTextures\\CommandButtons\\BTNRingGreen.blp",
        tooltip = function(pid)
            return struggle_tooltip(pid, "ring")
                .. "\n\nAt level |cffffcc00200|r, it can be crystallized into an equivalent socketable gem."
        end,
        categories = struggle,
        availability = function(pid)
            return StruggleRewards.canRedeem(pid, false)
        end,
        purchase = function(pid)
            return StruggleRewards.redeem(pid, false)
        end,
    })

    ShopAddOffer(shop_id, {
        key = "struggle_gem",
        name = function(pid)
            return "Struggle Gem |cff999999(Rank " .. StruggleRewards.getClaimRank(pid) .. ")|r"
        end,
        icon = "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp",
        tooltip = function(pid)
            return struggle_tooltip(pid, "socketable gem")
                .. "\n\nRequires level |cffffcc00200|r. An embedded gem must be extracted before it can be upgraded."
        end,
        categories = struggle,
        availability = function(pid)
            return StruggleRewards.canRedeem(pid, true)
        end,
        purchase = function(pid)
            return StruggleRewards.redeem(pid, true)
        end,
    })

    ShopAddOffer(shop_id, {
        key = "crystallize_struggle_ring",
        name = "Crystallize Ring of Struggle",
        icon = "ReplaceableTextures\\CommandButtons\\BTNOrbOfDarkness.blp",
        tooltip = "Convert a Ring of Struggle into a socketable Struggle Gem of the same rank. This service is free and does not consume a checkpoint claim.",
        categories = struggle,
        availability = function(pid)
            return StruggleRewards.canConvert(pid)
        end,
        purchase = function(pid)
            return StruggleRewards.convert(pid)
        end,
    })
end, Debug and Debug.getLine())
