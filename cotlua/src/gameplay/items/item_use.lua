-- Registry for inventory items that may be activated directly from the
-- custom inventory without first occupying an equipment slot.
OnInit.final("ItemUse", function(Require)
    Require('ItemHelpers')
    Require('Profile')

    ItemUse = {}
    local handlers = {}
    local runtime_handlers = {}

    ---@class ItemUseHandler
    ---@field available? fun(pid: integer, item: Item): boolean, string?
    ---@field use fun(pid: integer, item: Item): boolean

    local function key(id)
        if type(id) == "string" then
            local _, rawcode = GetItem(id)
            return rawcode
        end
        return id
    end

    ---@param id string|integer
    ---@param handler ItemUseHandler
    function ItemUse.register(id, handler)
        if not handler or type(handler.use) ~= "function" then return false end
        handlers[key(id)] = handler
        return true
    end

    ---@param key string Runtime item definition key.
    ---@param handler ItemUseHandler
    function ItemUse.registerRuntime(key, handler)
        if type(key) ~= "string" or not handler or
            type(handler.use) ~= "function" then return false end
        runtime_handlers[key] = handler
        return true
    end

    local function handler_for(item)
        local definition = item and item.runtime_definition
        return definition and runtime_handlers[definition.key] or
                   (item and handlers[item.id])
    end

    ---@param item Item?
    ---@return boolean
    function ItemUse.isUsable(item)
        return item ~= nil and handler_for(item) ~= nil
    end

    ---@param pid integer
    ---@param item Item?
    ---@return boolean, string?
    function ItemUse.canUse(pid, item)
        if not item or not item.alive then return false, "That item is gone." end
        local handler = handler_for(item)
        if not handler then return false, "That item cannot be used." end
        if handler.available then return handler.available(pid, item) end
        return true
    end

    ---@param pid integer
    ---@param slot integer
    ---@return table
    function ItemUse.use(pid, slot)
        local profile = Profile[pid]
        local item = profile and profile.hero and profile.hero.items[slot]
        local available, reason = ItemUse.canUse(pid, item)
        if not available then
            return {ok = false, code = "not_usable", message = reason}
        end
        local handler = handler_for(item)
        if not handler or not handler.use(pid, item) then
            return {ok = false, code = "use_failed"}
        end
        return {ok = true, code = "used", item = item, changed_slots = {slot}}
    end
end, Debug and Debug.getLine())
