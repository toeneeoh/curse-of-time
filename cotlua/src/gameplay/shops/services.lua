-- Domain operations used by non-item shop entries. Every commit recomputes its
-- quote so a dialog can never spend against stale currency or character state.

OnInit.final("ShopServices", function(Require)
    Require('Currency')
    Require('ItemEventRegistry')
    Require('Items')
    Require('PotionService')
    Require('Profile')
    Require('Spells')
    Require('TimerQueue')

    FocusService = {}
    RetrainingService = {}
    RechargeService = {}
    PotionRefillService = {}
    PotionBrewingService = {}
    CurrencyConverterService = {}
    BackpackUpgradeService = {}

    local function result(available, reason)
        return { available = available, reason = reason }
    end

    function FocusService.quote(pid)
        if not Hero[pid] or not Unit[Hero[pid]] then
            return result(false, "NO HERO")
        end

        local unit = Unit[Hero[pid]]
        local quote = result(false, "NO STATS")
        quote.strength = math.max(0, math.min(50, unit.str - 20))
        quote.agility = math.max(0, math.min(50, unit.agi - 20))
        quote.intelligence = math.max(0, math.min(50, unit.int - 20))
        -- Preserve the established refund rule: only a complete 50-point
        -- reduction awards 5,000 gold for that attribute.
        quote.refund = (unit.str - 50 > 20 and 5000 or 0)
            + (unit.agi - 50 > 20 and 5000 or 0)
            + (unit.int - 50 > 20 and 5000 or 0)
        quote.available = quote.strength + quote.agility + quote.intelligence > 0
        quote.reason = quote.available and nil or "NO STATS"
        return quote
    end

    function FocusService.commit(pid)
        local quote = FocusService.quote(pid)
        if not quote.available then return quote end
        local unit = Unit[Hero[pid]]
        unit.str = unit.str - quote.strength
        unit.agi = unit.agi - quote.agility
        unit.int = unit.int - quote.intelligence
        if quote.refund > 0 then
            AddCurrency(pid, GOLD, quote.refund)
        end
        return quote
    end

    function RetrainingService.quote(pid)
        return result(Hero[pid] ~= nil, Hero[pid] and nil or "NO HERO")
    end

    function RetrainingService.commit(pid)
        local quote = RetrainingService.quote(pid)
        if quote.available then
            UnitAddItemById(Hero[pid], FourCC('Iret'))
        end
        return quote
    end

    local function recharge_tick(pid)
        if RECHARGE_COOLDOWN[pid] > 0 then
            RECHARGE_COOLDOWN[pid] = RECHARGE_COOLDOWN[pid] - 1
            if RECHARGE_COOLDOWN[pid] > 0 then
                TimerQueue:callDelayed(1., recharge_tick, pid)
            else
                NotifyShopActionChanged(pid)
            end
        end
    end

    function RechargeService.quote(pid)
        if not Profile[pid] or not Profile[pid].hero then
            return result(false, "NO HERO")
        end
        local item = GetResurrectionItem(pid, true)
        if not item then return result(false, "NO ITEM") end
        if item.charges >= MAX_REINCARNATION_CHARGES then return result(false, "FULL") end
        if RECHARGE_COOLDOWN[pid] >= 1 then return result(false, "COOLDOWN") end

        local percentage = Profile[pid].hero.hardcore > 0 and 0.03 or 0.01
        local player_gold = GetCurrency(pid, GOLD)
        local platinum_fraction = GetCurrency(pid, PLATINUM) * percentage
        local quote = result(true)
        quote.item = item
        quote.gold = R2I(ItemData[item.id][ITEM_COST] * 100 * percentage
            + player_gold * percentage
            + (platinum_fraction - R2I(platinum_fraction)) * 1000000)
        quote.platinum = R2I(platinum_fraction)
        if player_gold < quote.gold or GetCurrency(pid, PLATINUM) < quote.platinum then
            quote.available = false
            quote.reason = "currency"
        end
        return quote
    end

    function RechargeService.commit(pid)
        local quote = RechargeService.quote(pid)
        if not quote.available then return quote end
        quote.item.charges = quote.item.charges + 1
        SetItemCharges(quote.item.abilities[ITEM_ABILITY].obj, quote.item.charges)
        RECHARGE_COOLDOWN[pid] = 180
        AddCurrency(pid, GOLD, -quote.gold)
        AddCurrency(pid, PLATINUM, -quote.platinum)
        NotifyItemChanged(pid)
        TimerQueue:callDelayed(1., recharge_tick, pid)
        return quote
    end

    function PotionRefillService.quote(pid)
        if not Profile[pid] or not Profile[pid].hero then
            return result(false, "NO HERO")
        end
        local quote = result(false, "NO POTIONS")
        quote.price = 0
        quote.potions = {}
        local found_potion = false
        for slot = 1, MAX_INVENTORY_SLOTS do
            local potion = PotionService.getStored(pid, slot)
            if potion then
                local properties = PotionService.getProperties(potion)
                if properties then
                    found_potion = true
                end
                if properties and potion.charges <
                    properties.maximum_charges then
                    quote.potions[#quote.potions + 1] = potion
                    quote.price = quote.price +
                                      PotionService.getRefillCost(potion)
                end
            end
        end
        quote.price = math.floor(quote.price)
        if found_potion and #quote.potions == 0 then
            quote.reason = "FULL"
        elseif quote.price > 0 then
            quote.available = GetCurrency(pid, GOLD) + GetCurrency(pid, PLATINUM) * 1000000 >= quote.price
            quote.reason = quote.available and nil or "currency"
        end
        return quote
    end

    function PotionRefillService.commit(pid)
        local quote = PotionRefillService.quote(pid)
        if not quote.available then return quote end
        if not ChargePlayer(pid, quote.price, "Your potions have been refilled.") then
            quote.available = false
            quote.reason = "currency"
            return quote
        end
        for index = 1, #quote.potions do
            PotionService.refill(quote.potions[index])
        end
        NotifyItemChanged(pid)
        return quote
    end

    PotionBrewingService.stat_names = {
        [ITEM_FLAT_HEAL] = "Health Restored",
        [ITEM_PERCENT_HEAL] = "% Max Health Restored",
        [ITEM_FLAT_MANA] = "Mana Restored",
        [ITEM_PERCENT_MANA] = "% Max Mana Restored",
        [ITEM_CHARGES] = "Maximum Charges"
    }

    local function brewing_price(item, operation, value)
        local properties = PotionService.getProperties(item)
        local base = math.max(1000, properties.level_requirement ^ 2)
        if operation == "refine" then return math.floor(base * 0.5) end
        if operation == "reroll" or operation == "prefix" or
            operation == "suffix" then
            -- Repeated work on one base rapidly becomes uneconomical. The
            -- exponent is capped only to keep integer arithmetic safe; the
            -- saved attempt counter continues increasing.
            local attempts = PotionService.getRerollCount(item, operation)
            local multiplier = operation == "reroll" and 0.5 or
                                   operation == "suffix" and 0.75 or 1.
            return math.floor(base * multiplier * (1.85 ^ attempts))
        end
        return math.floor(base)
    end

    ---Quotes a single potion customization operation. Infusions and catalysts
    ---are Chaos brewing; stat refinement remains available to rolled
    ---pre-Chaos flasks.
    ---@param pid integer
    ---@param slot integer Absolute potion or backpack inventory slot.
    ---@param operation string "refine", "reroll", "prefix", or "suffix".
    ---@param value integer Stat index or donor potion slot.
    ---@return table
    function PotionBrewingService.quote(pid, slot, operation, value)
        if not Hero[pid] then return result(false, "NO HERO") end
        local item = PotionService.getStored(pid, slot)
        if not item then return result(false, "NO POTION") end

        local available, reason
        local option
        if operation == "refine" then
            available = PotionService.canRefine(item, value)
            reason = available and nil or "NOT REFINABLE"
        elseif operation == "reroll" then
            available = PotionService.canRerollRestoration(item)
            reason = available and nil or "NOT REFINABLE"
        elseif operation == "prefix" or operation == "suffix" then
            local donor = PotionService.getStored(pid, value)
            available, reason = PotionService.canTransferAffix(item, donor,
                                                               operation)
            if donor then
                local customization = PotionService.getCustomization(donor)
                option = operation == "prefix" and customization.prefix or
                             customization.suffix
            end
        else
            return result(false, "INVALID BREW")
        end

        if available and operation ~= "refine" and
            GetHeroLevel(Hero[pid]) < 200 then
            available, reason = false, "REQUIRES LEVEL 200"
        end

        local quote = result(available, reason)
        quote.item = item
        quote.slot = slot
        quote.operation = operation
        quote.value = value
        quote.option = option
        quote.donor = (operation == "prefix" or operation == "suffix") and
                          PotionService.getStored(pid, value) or nil
        quote.price = brewing_price(item, operation, value)
        if available and GetCurrency(pid, GOLD) +
            GetCurrency(pid, PLATINUM) * 1000000 < quote.price then
            quote.available = false
            quote.reason = "currency"
        end
        return quote
    end

    ---@param pid integer
    ---@param slot integer
    ---@param operation string
    ---@param value integer
    ---@return table
    function PotionBrewingService.commit(pid, slot, operation, value)
        local quote = PotionBrewingService.quote(pid, slot, operation, value)
        if not quote.available then return quote end
        local previous_gold = GetCurrency(pid, GOLD)
        local previous_platinum = GetCurrency(pid, PLATINUM)
        if not ChargePlayer(pid, quote.price, "Potion brewing complete.") then
            quote.available = false
            quote.reason = "currency"
            return quote
        end

        local changed, old_value, new_value
        if operation == "refine" then
            changed, old_value, new_value =
                PotionService.refine(quote.item, value)
        elseif operation == "reroll" then
            changed = PotionService.rerollRestoration(quote.item)
        else
            changed = PotionService.transferAffix(quote.item, quote.donor,
                                                   operation)
        end
        if not changed then
            -- The quote was recomputed immediately before charging, so this is
            -- only a defensive guard against an invalid subsystem mutation.
            SetCurrency(pid, GOLD, previous_gold)
            SetCurrency(pid, PLATINUM, previous_platinum)
            quote.available = false
            quote.reason = "BREW FAILED"
            return quote
        end

        quote.old_value = old_value
        quote.new_value = new_value
        if quote.donor then
            quote.donor_name = GetItemName(quote.donor.obj)
            quote.donor:destroy()
        end
        return quote
    end

    function CurrencyConverterService.quote(pid)
        if HasCurrencyConverter(pid) then return result(false, "OWNED") end
        return result(true)
    end

    function CurrencyConverterService.commit(pid)
        local quote = CurrencyConverterService.quote(pid)
        if not quote.available then return quote end
        GrantCurrencyConverter(pid)
        return quote
    end

    local function upgrade_rawcode(id)
        local _, raw = GetItem(id)
        return raw
    end

    function BackpackUpgradeService.quote(pid, id)
        local raw = upgrade_rawcode(id)
        local ability
        if raw == FourCC('I101') then
            ability = TELEPORT_HOME.id
        elseif raw == FourCC('I102') then
            ability = FourCC('A0FK')
        else
            return result(false, "INVALID")
        end
        if not Backpack[pid] then return result(false, "NO HERO") end
        local level = GetUnitAbilityLevel(Backpack[pid], ability)
        if level >= 10 then return result(false, "MAXED") end
        local price = R2I(400. * Pow(5., level - 1.))
        local quote = result(true)
        quote.id = raw
        quote.level = level
        quote.price = price
        quote.gold = ModuloInteger(price, 1000000)
        quote.platinum = price // 1000000
        if GetCurrency(pid, GOLD) < quote.gold or GetCurrency(pid, PLATINUM) < quote.platinum then
            quote.available = false
            quote.reason = "currency"
        end
        return quote
    end

    function BackpackUpgradeService.commit(pid, id)
        local quote = BackpackUpgradeService.quote(pid, id)
        if not quote.available then return quote end
        AddCurrency(pid, GOLD, -quote.gold)
        AddCurrency(pid, PLATINUM, -quote.platinum)
        local new_level = quote.level + 1
        if quote.id == FourCC('I101') then
            SetUnitAbilityLevel(Backpack[pid], TELEPORT_HOME.id, new_level)
            SetUnitAbilityLevel(Backpack[pid], TELEPORT.id, new_level)
            quote.name = "Teleport"
        else
            SetUnitAbilityLevel(Backpack[pid], FourCC('A0FK'), new_level)
            quote.name = "Reveal"
        end
        quote.new_level = new_level
        return quote
    end
end, Debug and Debug.getLine())
