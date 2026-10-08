-- Immutable shop item descriptors and recipe-component relationships.

OnInit.final("ShopCatalog", function(Require)
    Require('ItemHelpers')
    Require('Items')
    Require('RuntimeItemDefinitions')
    Require('Variables')

    ---@class ShopItem
    ---@field name string
    ---@field icon string
    ---@field tooltip string
    ---@field id integer
    ---@field charges integer
    ---@field recharge integer
    ---@field categories integer
    ---@field componentCount integer
    ---@field component integer[]
    ---@field counter table
    ---@field relation integer[]
    ShopItem = {}

    local mt = { __index = ShopItem }
    ShopItem.itempool = __jarray(0)

    function ShopItem:components()
        return self.componentCount
    end

    ---@param id integer
    ---@return integer
    function ShopItem:count(id)
        return self.counter[id]
    end

    ---@param id integer
    ---@return ShopItem
    function ShopItem.get(id)
        return ShopItem.itempool[id]
    end

    ---@param id integer
    ---@param component string
    function ShopItem.save(id, component)
        if component == id then
            return
        end

        local self = ShopItem.create(id, 0)
        local part = ShopItem.create(component, 0)

        self.component[self.componentCount] = component
        self.componentCount = self.componentCount + 1
        self.counter[component] = self.counter[component] + 1

        local index = 0
        while part.relation[index] ~= id do
            if part.relation[index] == 0 then
                part.relation[index] = id
                break
            end
            index = index + 1
        end
    end

    ---@param id integer
    ---@param component_string string
    function ShopItem.addComponents(id, component_string)
        local self = ShopItem.create(id, 0)
        self.componentCount = 0
        self.component = {}
        self.counter = __jarray(0)

        for tag in component_string:gmatch("%S+") do
            if tag:len() > 4 then
                ShopItem.save(id, tag)
            elseif FourCC(tag) ~= 0 then
                ShopItem.save(id, tag .. ":0")
            end
        end
    end

    ---@param which_item string|integer
    ---@param component_string string
    function ItemAddComponents(which_item, component_string)
        ShopItem.addComponents(which_item, component_string)
    end

    ---@param id integer|string
    ---@param category integer
    ---@param max_level boolean?
    ---@return ShopItem|0
    function ShopItem.create(id, category, max_level)
        if type(id) == "string" and id:sub(1, 1) == "@" then
            local existing = ShopItem.itempool[id]
            if existing ~= 0 then return existing end
            local key, required_level = id:match("^@([^:]+):?(%d*)$")
            local definition = key and RuntimeItemDefinitions.get(key) or nil
            if not definition then return 0 end
            local runtime_item = RuntimeItemDefinitions.create(definition,
                30000., -30000.)
            if not runtime_item then return 0 end
            required_level = tonumber(required_level) or 0
            if required_level > 0 then runtime_item:lvl(required_level) end
            local self = setmetatable({
                id = id,
                categories = category,
                lvl = required_level,
                name = GetItemName(runtime_item.obj),
                icon = BlzGetItemIconPath(runtime_item.obj),
                tooltip = runtime_item.alt_tooltip or runtime_item.tooltip or
                    BlzGetItemExtendedTooltip(runtime_item.obj) or "",
                charges = GetItemCharges(runtime_item.obj),
                recharge = -1,
                relation = __jarray(0),
                counter = __jarray(0),
                component = {},
                componentCount = 0,
                runtime_definition = definition,
                minimum_level = required_level,
            }, mt)
            ShopItem.itempool[id] = self
            runtime_item:destroy()
            return self
        end
        local index, rawcode, level = GetItem(id)
        local existing = ShopItem.itempool[index]

        if existing ~= 0 then
            if category > 0 then
                existing.categories = category
            end
            return existing
        end

        local runtime_item = ItemRuntime.create(rawcode, 30000., -30000.)
        if not runtime_item then
            return 0
        end

        if max_level then
            level = ItemData[rawcode][ITEM_UPGRADE_MAX]
        end
        runtime_item:lvl(level)

        local self = setmetatable({
            id = index,
            categories = category,
            lvl = level,
            name = GetItemName(runtime_item.obj),
            icon = BlzGetItemIconPath(runtime_item.obj),
            tooltip = runtime_item.alt_tooltip or runtime_item.tooltip or BlzGetItemExtendedTooltip(runtime_item.obj) or "",
            charges = GetItemCharges(runtime_item.obj),
            recharge = -1,
            relation = __jarray(0),
            counter = __jarray(0),
            component = {},
            componentCount = 0,
        }, mt)

        ShopItem.itempool[index] = self
        runtime_item:destroy()
        return self
    end
end, Debug and Debug.getLine())
