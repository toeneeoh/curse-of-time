-- Synchronized shop definitions. Catalog content can register shops without
-- constructing or depending on local frame state.

OnInit.global("ShopRegistry", function(Require)
    Require('ItemHelpers')

    ---@class ShopDefinition
    ---@field id integer
    ---@field aoe number
    ---@field categories table[]
    ---@field items table[]
    ---@field stock table[]
    ---@field stock_by_key table<string, table>
    ---@field stock_count table<string, integer>
    ---@field item_by_id table<string, table>
    ---@field current unit[]
    ---@field visibility boolean
    ---@field view Shop?
    local ShopDefinition = {}
    ShopDefinition.__index = ShopDefinition

    ShopRegistry = {
        definitions = {},
        order = {},
        adapter = nil,
    }

    ---@param item_id string|integer
    ---@return boolean
    function ShopDefinition:has(item_id)
        local key = GetItem(item_id)
        return self.item_by_id[key] ~= nil
    end

    ---@param item_id string|integer
    ---@return integer?
    function ShopDefinition:getStock(item_id)
        return self.stock_count[GetItem(item_id)]
    end

    ---@param pid integer
    ---@param shop_unit unit?
    function ShopDefinition:setCurrent(pid, shop_unit)
        self.current[pid] = shop_unit
    end

    ---@param pid integer
    ---@return boolean
    function ShopDefinition:isInRange(pid)
        local shop_unit = self.current[pid]
        return shop_unit ~= nil and IsUnitInRange(Hero[pid], shop_unit, self.aoe)
    end

    ---@param id integer
    ---@return ShopDefinition?
    function ShopRegistry.get(id)
        return ShopRegistry.definitions[id]
    end

    ---@param id integer
    ---@param aoe number
    ---@return ShopDefinition
    function ShopRegistry.create(id, aoe)
        local definition = ShopRegistry.definitions[id]
        if definition then return definition end

        definition = setmetatable({
            id = id,
            aoe = aoe,
            categories = {},
            items = {},
            item_by_id = {},
            stock = {},
            stock_by_key = {},
            stock_count = {},
            current = {},
            visibility = false,
        }, ShopDefinition)
        ShopRegistry.definitions[id] = definition
        ShopRegistry.order[#ShopRegistry.order + 1] = definition

        if ShopRegistry.adapter then
            definition.view = ShopRegistry.adapter.create(id, aoe, definition)
            ShopRegistry.adapter.setVisible(definition, definition.visibility)
        end
        return definition
    end

    ---@param id integer
    ---@param icon string
    ---@param description string
    ---@return integer
    function ShopRegistry.addCategory(id, icon, description)
        local definition = ShopRegistry.definitions[id]
        if not definition then return 0 end

        local value = 2 ^ #definition.categories
        definition.categories[#definition.categories + 1] = {
            icon = icon,
            description = description,
            value = value,
        }
        if ShopRegistry.adapter then
            return ShopRegistry.adapter.addCategory(id, icon, description)
        end
        return value
    end

    ---@param id integer
    ---@param item_id string|integer
    ---@param categories integer
    function ShopRegistry.addItem(id, item_id, categories)
        local definition = ShopRegistry.definitions[id]
        if not definition then return end

        local key = GetItem(item_id)
        if definition.item_by_id[key] then return end

        local item = {
            id = item_id,
            key = key,
            categories = categories,
        }
        definition.items[#definition.items + 1] = item
        definition.item_by_id[key] = item
        definition.stock_count[key] = -1
        if ShopRegistry.adapter then
            ShopRegistry.adapter.addItem(id, item_id, categories)
        end
    end

    ---@param id integer
    ---@param item_id string|integer
    ---@param count integer
    function ShopRegistry.setStock(id, item_id, count)
        local definition = ShopRegistry.definitions[id]
        if not definition then return end

        local key = GetItem(item_id)
        definition.stock_count[key] = count
        local stock = definition.stock_by_key[key]
        if stock then
            stock.count = count
        else
            stock = { id = item_id, count = count }
            definition.stock_by_key[key] = stock
            definition.stock[#definition.stock + 1] = stock
        end
        if ShopRegistry.adapter then
            ShopRegistry.adapter.setStock(id, item_id, count)
        end
    end

    ---@param definition ShopDefinition
    ---@param item_id string|integer
    function ShopRegistry.consumeStock(definition, item_id)
        local count = definition:getStock(item_id)
        if count and count ~= -1 then
            ShopRegistry.setStock(definition.id, item_id, count - 1)
        end
    end

    ---@param id integer
    ---@param visible boolean
    ---@return boolean
    function ShopRegistry.setVisible(id, visible)
        local definition = ShopRegistry.definitions[id]
        if not definition then return false end

        definition.visibility = visible
        if ShopRegistry.adapter then
            ShopRegistry.adapter.setVisible(definition, visible)
        end
        return visible
    end

    ---@param adapter table
    function ShopRegistry.bind(adapter)
        ShopRegistry.adapter = adapter
        for index = 1, #ShopRegistry.order do
            local definition = ShopRegistry.order[index]
            definition.view = adapter.create(definition.id, definition.aoe, definition)
            adapter.setVisible(definition, definition.visibility)
            for category_index = 1, #definition.categories do
                local category = definition.categories[category_index]
                adapter.addCategory(definition.id, category.icon, category.description)
            end
            for item_index = 1, #definition.items do
                local item = definition.items[item_index]
                adapter.addItem(definition.id, item.id, item.categories)
            end
            for stock_index = 1, #definition.stock do
                local stock = definition.stock[stock_index]
                adapter.setStock(definition.id, stock.id, stock.count)
            end
        end
    end

    -- Compatibility registration API retained for existing map content.
    CreateShop = ShopRegistry.create
    ShopAddCategory = ShopRegistry.addCategory
    ShopAddItem = ShopRegistry.addItem
    ShopSetStock = ShopRegistry.setStock
end, Debug and Debug.getLine())
