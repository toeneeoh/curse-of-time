--[[
    prices.lua

    Set static or dynamic prices for use in the shop.lua UI
]]

OnInit.final("Prices", function(Require)
    Require('Currency')
    Require('ItemHelpers')

    local PRICES = {}
    local AVAILABILITY = {}

    -- Per-item vendor payouts for prechaos drops without a formula/shop price.
    -- These do not add items to shops or alter purchase prices. Ordinary early
    -- trinkets retain their native half-cost value; equipment rises by region.
    ---@type table<integer, integer>
    ITEM_SELL_PRICES = {}
    local function drop_sell_value(value, ...)
        for _, id in ipairs({...}) do ITEM_SELL_PRICES[FourCC(id)] = value end
    end
    drop_sell_value(25, 'I01V', 'I02D') -- courage medallion, regeneration ring
    drop_sell_value(40, 'I021') -- vitality medallion
    drop_sell_value(55, 'I03Q') -- Horse Boost, comparable to Seven League Boots
    drop_sell_value(100, 'I025') -- Greater Mask of Death
    drop_sell_value(250, 'I02L') -- Great Circlet
    drop_sell_value(300, 'I06T', 'I034', 'I0FG', 'I06R', 'I0FT') -- Ursa weapons
    drop_sell_value(350, 'I035', 'I0FO', 'I07O') -- bear armor
    drop_sell_value(400, 'I0FQ') -- mammoth fullplate
    drop_sell_value(500, 'I08I', 'I0FE', 'I07W', 'I08B', 'I0FD', 'I08R',
        'I08E', 'I08F', 'I07Y') -- ogre / tauren equipment
    drop_sell_value(750, 'I0FS', 'I0FR', 'I0FY', 'I01W', 'I0MB') -- unbroken
    drop_sell_value(1000, 'I00Z', 'I00S', 'I011', 'I02E', 'I023', 'I0MA') -- hellfire
    drop_sell_value(1250, 'I06J', 'I06I', 'I06L', 'I06K', 'I07H') -- centaur weapons
    drop_sell_value(1500, 'I01Q', 'I01N', 'I015', 'I019') -- magnataur / forgotten
    drop_sell_value(2500, 'I02W', 'I00W', 'I017', 'I013', 'I02I', 'I01P',
        'I006', 'I02V', 'I009') -- devourer equipment
    drop_sell_value(250, 'I04X', 'I05Z') -- dragon bone / scale, per stack unit
    drop_sell_value(500, 'I056') -- dragon heart, per stack unit
    drop_sell_value(750, 'I07N') -- hydra crafting fang; quest head stays unsellable
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
