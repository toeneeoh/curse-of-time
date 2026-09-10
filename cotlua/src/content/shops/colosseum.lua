-- Honor rewards offered by the Colosseum Prize Vendor.

OnInit.final("ColosseumShop", function(Require)
    Require('ShopRegistry')
    Require('Honor')
    Require('UnitTable')

    local shop_id = FourCC('n032')
    CreateShop(shop_id, 1000.)
    local bonuses = ShopAddCategory(shop_id, "ReplaceableTextures\\CommandButtons\\BTNHeroPaladin.blp", "Bonuses")
    local services = ShopAddCategory(shop_id, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", "Services")

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
end, Debug and Debug.getLine())
