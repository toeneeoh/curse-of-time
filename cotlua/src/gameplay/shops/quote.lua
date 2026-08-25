-- Authoritative, read-only shop purchase evaluation.

OnInit.final("ShopQuote", function(Require)
    Require('Currency')
    Require('Prices')
    Require('Profile')
    Require('Helper')
    Require('Items')
    Require('ShopCatalog')
    Require('ShopActions')

    ShopQuote = {}

    ---@type fun(id: string|integer, pid: integer): boolean
    function IsBuyable(id, pid)
        local available = GetItemAvailability(id, pid)
        if not available then
            return false
        end
        if ShopAction.get(id) then
            return ShopAction.evaluate(id, pid)
        end
        return GetItemPrice(id, pid) ~= nil
    end

    local function inventory_components(pid)
        local inventory = __jarray(0)
        for slot = 1, MAX_INVENTORY_SLOTS do
            local owned = Profile[pid].hero.items[slot]
            if owned and not owned.nocraft then
                local id = GetItem(owned.id)
                inventory[id] = inventory[id] + math.max(1, owned.charges)
            end
        end
        return inventory
    end

    local function evaluate_components(shop, item, pid, inventory, quote)
        local remaining = __jarray(0)
        for id, count in pairs(inventory) do
            remaining[id] = count
        end
        for index = 0, item:components() - 1 do
            local component = ShopItem.get(item.component[index])
            if remaining[component.id] > 0 then
                remaining[component.id] = remaining[component.id] - 1
                if quote then
                    quote.consume[component.id] = quote.consume[component.id] + 1
                end
            elseif not shop:has(component.id) or not IsBuyable(component.id, pid) then
                return false
            elseif quote then
                local component_price = GetItemPrice(component.id, pid)
                for currency = 0, CURRENCY_COUNT - 1 do
                    quote.cost[currency] = quote.cost[currency] + component_price[currency]
                end
            end
        end
        return true
    end

    function ShopQuote.isCraftable(shop, item, pid)
        return evaluate_components(shop, item, pid, inventory_components(pid))
    end

    ---@class PurchaseQuote
    ---@field can_buy boolean
    ---@field reason string?
    ---@field label string?
    ---@field cost PriceQuote
    ---@field inventory table
    ---@field consume table
    ---@field action ShopActionDefinition?

    ---@return PurchaseQuote
    function ShopQuote.evaluate(shop, item, pid)
        local quote = {
            can_buy = false,
            reason = "invalid",
            cost = __jarray(0),
            inventory = inventory_components(pid),
            consume = __jarray(0),
        }
        if item == 0 or not item then return quote end
        if not shop.current[pid] or not IsUnitInRange(Hero[pid], shop.current[pid], shop.aoe) then
            quote.reason = "range"
            return quote
        end
        local stock = shop.stock[item.id]
        if stock == nil or stock == 0 then
            quote.reason = "stock"
            return quote
        end
        local available, label = GetItemAvailability(item.id, pid)
        if not available then
            quote.reason = "unavailable"
            quote.label = label
            return quote
        end
        local price = GetItemPrice(item.id, pid)
        local action = ShopAction.get(item.id)
        if action then
            local action_available, action_reason = ShopAction.evaluate(item.id, pid)
            if not action_available then
                quote.reason = "unavailable"
                quote.label = action_reason
                return quote
            end
            quote.can_buy = true
            quote.reason = nil
            quote.action = action
            return quote
        end
        if not price then
            quote.reason = "unpriced"
            return quote
        end
        for currency = 0, CURRENCY_COUNT - 1 do
            quote.cost[currency] = price[currency]
        end
        if not evaluate_components(shop, item, pid, quote.inventory, quote) then
            quote.reason = "components"
            return quote
        end
        for currency = 0, CURRENCY_COUNT - 1 do
            if GetCurrency(pid, currency) < quote.cost[currency] then
                quote.reason = "currency"
                return quote
            end
        end
        quote.can_buy = true
        quote.reason = nil
        return quote
    end
end, Debug and Debug.getLine())
