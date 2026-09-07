-- Synchronized shop definitions. Catalog content can register shops without
-- constructing or depending on local frame state.

OnInit.global("ShopRegistry", function()
    ---@class ShopDefinition
    ---@field id integer
    ---@field aoe number
    ---@field categories table[]
    ---@field items table[]
    ---@field stock table[]
    ---@field stock_by_key table<string, table>
    ---@field view Shop?
    local ShopDefinition = {}
    ShopDefinition.__index = ShopDefinition

    ShopRegistry = {
        definitions = {},
        order = {},
        adapter = nil,
    }

    ---@param visible boolean
    ---@return boolean
    function ShopDefinition:visible(visible)
        if self.view then
            return self.view:visible(visible)
        end
        return false
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
            stock = {},
            stock_by_key = {},
        }, ShopDefinition)
        ShopRegistry.definitions[id] = definition
        ShopRegistry.order[#ShopRegistry.order + 1] = definition

        if ShopRegistry.adapter then
            definition.view = ShopRegistry.adapter.create(id, aoe)
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

        definition.items[#definition.items + 1] = {
            id = item_id,
            categories = categories,
        }
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

        local key = type(item_id) .. ":" .. tostring(item_id)
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

    ---@param adapter table
    function ShopRegistry.bind(adapter)
        ShopRegistry.adapter = adapter
        for index = 1, #ShopRegistry.order do
            local definition = ShopRegistry.order[index]
            definition.view = adapter.create(definition.id, definition.aoe)
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
