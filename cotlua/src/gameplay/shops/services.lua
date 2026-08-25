-- Domain operations used by non-item shop entries. Every commit recomputes its
-- quote so a dialog can never spend against stale currency or character state.

OnInit.final("ShopServices", function(Require)
    Require('Currency')
    Require('ItemEventRegistry')
    Require('Items')
    Require('Profile')
    Require('Spells')
    Require('TimerQueue')

    FocusService = {}
    RetrainingService = {}
    RechargeService = {}
    PotionRefillService = {}
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
            TimerQueue:callDelayed(1., recharge_tick, pid)
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
        AddCurrency(pid, GOLD, -quote.gold)
        AddCurrency(pid, PLATINUM, -quote.platinum)
        NotifyItemChanged(pid)
        RECHARGE_COOLDOWN[pid] = 180
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
        local needs_refill = false
        for slot = POTION_INDEX, POTION_INDEX + 1 do
            local potion = Profile[pid].hero.items[slot]
            if potion then
                quote.potions[#quote.potions + 1] = potion
                quote.price = quote.price + ItemData[potion.id][ITEM_LEVEL_REQUIREMENT] ^ 2
                    + potion.cached_stats[ITEM_FLAT_HEAL] * 0.5
                    + potion.cached_stats[ITEM_FLAT_MANA] * 0.5
                if potion.charges < potion.cached_stats[ITEM_CHARGES] then
                    needs_refill = true
                end
            end
        end
        quote.price = math.floor(quote.price)
        if #quote.potions > 0 and not needs_refill then
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
            local potion = quote.potions[index]
            potion.charges = potion.cached_stats[ITEM_CHARGES]
        end
        NotifyItemChanged(pid)
        return quote
    end

    function CurrencyConverterService.quote(pid)
        if HasCurrencyConverter(pid) then return result(false, "OWNED") end
        local available = GetCurrency(pid, GOLD) + GetCurrency(pid, PLATINUM) * 1000000 >= 4000000
        return result(available, available and nil or "currency")
    end

    function CurrencyConverterService.commit(pid)
        local quote = CurrencyConverterService.quote(pid)
        if not quote.available then return quote end
        if ChargePlayer(pid, 4000000, "You have purchased a Currency Converter.") then
            GrantCurrencyConverter(pid)
        else
            quote.available = false
            quote.reason = "currency"
        end
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
