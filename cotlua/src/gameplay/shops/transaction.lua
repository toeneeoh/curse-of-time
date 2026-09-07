-- Authoritative synchronized shop purchase commit.

OnInit.final("ShopTransaction", function(Require)
    Require('Currency')
    Require('Profile')
    Require('Items')
    Require('ShopQuote')
    Require('ShopActions')
    Require('ShopRegistry')

    ShopTransaction = {}

    ---Re-evaluates immediately before committing synchronized state changes.
    ---@param shop ShopDefinition
    ---@param item ShopItem
    ---@param pid integer
    ---@return PurchaseQuote
    function ShopTransaction.commit(shop, item, pid)
        local quote = ShopQuote.evaluate(shop, item, pid)
        if not quote.can_buy then return quote end

        if quote.action then
            if not quote.action.open(pid) then
                quote.can_buy = false
                quote.reason = "action"
                return quote
            end
            for currency = 0, CURRENCY_COUNT - 1 do
                if quote.cost[currency] > 0 then
                    AddCurrency(pid, currency, -quote.cost[currency])
                end
            end
            return quote
        end

        for currency = 0, CURRENCY_COUNT - 1 do
            if quote.cost[currency] > 0 then
                AddCurrency(pid, currency, -quote.cost[currency])
            end
        end

        for slot = 1, MAX_INVENTORY_SLOTS do
            local owned = Profile[pid].hero.items[slot]
            if owned then
                local id = GetItem(owned.id)
                local needed = quote.consume[id]
                local count = math.min(math.max(1, owned.charges), needed)
                for _ = 1, count do
                    owned:consumeCharge()
                end
                quote.consume[id] = needed - count
            end
        end

        PlayerAddItemById(pid, item.id)
        ShopRegistry.consumeStock(shop, item.id)
        return quote
    end
end, Debug and Debug.getLine())
