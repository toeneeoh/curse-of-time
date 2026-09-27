-- Registry for shop entries that invoke synchronized gameplay services instead
-- of creating an item.

OnInit.final("ShopActions", function(Require)
    Require('ItemHelpers')

    ShopAction = {}
    local registry = {}
    local changed = {}

    local function key(id)
        return GetItem(id)
    end

    ---@class ShopActionDefinition
    ---@field label string|fun(pid: integer): string
    ---@field availability fun(pid: integer): boolean, string?
    ---@field open fun(pid: integer): boolean
    ---@field cooldown? fun(pid: integer): number, number?

    ---@param id string|integer
    ---@param definition ShopActionDefinition
    function RegisterShopAction(id, definition)
        registry[key(id)] = definition
    end

    ---@param id string|integer
    ---@return ShopActionDefinition?
    function ShopAction.get(id)
        return registry[key(id)]
    end

    ---@param id string|integer
    ---@param pid integer
    ---@return boolean, string?
    function ShopAction.evaluate(id, pid)
        local action = ShopAction.get(id)
        if not action then
            return false
        end

        local available, reason = action.availability(pid)
        return available ~= false, reason
    end

    ---@param id string|integer
    ---@param pid integer
    ---@return string?
    function ShopAction.label(id, pid)
        local action = ShopAction.get(id)
        if not action then
            return nil
        end
        local label = action.label
        if type(label) == "function" then
            return label(pid)
        end
        ---@cast label string
        return label
    end

    ---@param callback fun(pid: integer)
    function RegisterShopActionChangedAction(callback)
        changed[#changed + 1] = callback
    end

    ---Notifies presentation subscribers when action availability changes
    ---without introducing a gameplay-to-UI dependency.
    ---@param pid integer
    function NotifyShopActionChanged(pid)
        for index = 1, #changed do
            changed[index](pid)
        end
    end
end, Debug and Debug.getLine())
