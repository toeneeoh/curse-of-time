-- Catalog entries for purchases that do not require Warcraft item object data.

OnInit.global("ShopOffers", function()
    ShopOffer = {}

    local mt = { __index = ShopOffer }

    ---@class ShopOfferDefinition
    ---@field key string Stable identifier, unique across all virtual offers.
    ---@field name string|fun(pid: integer): string
    ---@field icon string
    ---@field disabled_icon? string
    ---@field tooltip string|fun(pid: integer): string
    ---@field categories? integer
    ---@field price? number|table|fun(pid: integer): number|table
    ---@field availability? fun(pid: integer): boolean, string?
    ---@field purchase fun(pid: integer): boolean
    ---@field cooldown? fun(pid: integer): number, number?

    ---@class ShopOffer : ShopOfferDefinition
    ---@field id string
    ---@field virtual boolean
    ---@field relation table

    local currency_by_name = {
        gold = 0,
        platinum = 1,
        crystal = 2,
        honor = 3,
        faction = 4,
    }

    local function resolve(value, pid)
        if type(value) == "function" then
            return value(pid)
        end
        return value
    end

    ---@param definition ShopOfferDefinition
    ---@return ShopOffer?
    function ShopOffer.create(definition)
        if type(definition) ~= "table"
            or type(definition.key) ~= "string"
            or definition.key == ""
            or type(definition.icon) ~= "string"
            or type(definition.purchase) ~= "function" then
            return nil
        end

        definition.id = "offer:" .. definition.key
        definition.virtual = true
        definition.categories = definition.categories or 0
        definition.relation = __jarray(0)
        ---@cast definition ShopOffer
        return setmetatable(definition, mt)
    end

    ---@return integer
    function ShopOffer:components()
        return 0
    end

    ---@param pid integer
    ---@return string
    function ShopOffer:getName(pid)
        return resolve(self.name, pid) or ""
    end

    ---@param pid integer
    ---@return string
    function ShopOffer:getTooltip(pid)
        return resolve(self.tooltip, pid) or ""
    end

    ---@param pid integer
    ---@return boolean, string?
    function ShopOffer:isAvailable(pid)
        if not self.availability then
            return true
        end
        local available, reason = self.availability(pid)
        return available ~= false, reason
    end

    ---@param pid integer
    ---@return PriceQuote
    function ShopOffer:getPrice(pid)
        local definition = resolve(self.price, pid)
        local price = __jarray(0)

        if type(definition) == "number" then
            price[GOLD] = definition
        elseif type(definition) == "table" then
            for key, value in pairs(definition) do
                local currency = type(key) == "number" and key or currency_by_name[key]
                value = resolve(value, pid)
                if currency ~= nil and value ~= nil then
                    price[currency] = value
                end
            end
        end

        return price
    end
end)
