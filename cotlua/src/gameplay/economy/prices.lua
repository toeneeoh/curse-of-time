--[[
    prices.lua

    Set static or dynamic prices for use in the shop.lua UI
]]

OnInit.final("Prices", function(Require)
    Require('Currency')
    Require('Helper')

    local PRICES = {}
    local AVAILABILITY = {}
    local CURRENCY = {
        gold = GOLD,
        platinum = PLATINUM,
        crystal = CRYSTAL,
        honor = HONOR,
        faction = FACTION,
    }

    local function resolve(value, pid)
        if type(value) == "function" then
            return value(pid)
        end

        return value
    end

    ---@type fun(id: string|number, price: number|table|function)
    function SetItemPrice(id, price)
        if type(price) == "number" then
            price = {gold = price}
        end

        id = GetItem(id)
        PRICES[id] = price
    end

    ---Resolves an item's price for a specific player into numeric currency indices.
    ---The entire price or any individual currency value may be a function of pid.
    ---@class PriceQuote
    ---@field [integer] number Resolved amount indexed by GOLD/PLATINUM/etc.

    ---@type fun(id: string|number, pid: number): PriceQuote?
    function GetItemPrice(id, pid)
        id = GetItem(id)
        local definition = resolve(PRICES[id], pid)

        if definition == nil then
            return nil
        end

        if type(definition) == "number" then
            definition = {gold = definition}
        end

        local price = __jarray(0)

        for key, value in pairs(definition) do
            local currency = type(key) == "number" and key or CURRENCY[key]

            if currency ~= nil then
                value = resolve(value, pid)
                if value ~= nil then
                    price[currency] = value
                end
            end
        end

        return price
    end

    ---Sets whether an item may be purchased by a player.
    ---A function may return false plus a UI label, e.g. `return false, "MAXED"`.
    ---@type fun(id: string|number, availability: boolean|function, label: string?)
    function SetItemAvailability(id, availability, label)
        id = GetItem(id)
        AVAILABILITY[id] = {value = availability, label = label}
    end

    ---@type fun(id: string|number, pid: number): boolean, string?
    function GetItemAvailability(id, pid)
        id = GetItem(id)
        local definition = AVAILABILITY[id]

        if not definition then
            return true
        end

        if type(definition.value) == "function" then
            local available, label = definition.value(pid)
            return available ~= false, label or definition.label
        end

        return definition.value ~= false, definition.label
    end

    -- sword of revival
    SetItemPrice('I01X', 1000)
    -- talisman of evasion
    SetItemPrice('I06G', 40)
    -- sparky orb
    SetItemPrice('I090', 30)
    -- axe of speed
    SetItemPrice('I00B', 1500)
    -- claws of lightning
    SetItemPrice('I01Z', 25)
    -- boots of the ranger
    SetItemPrice('I00R', 70)
    -- chipped shield
    SetItemPrice('I0FJ', 15)
    -- gauntlets of strength
    SetItemPrice('I01C', 35)
    -- seven league boots
    SetItemPrice('I01S', 110)

end, Debug and Debug.getLine())
