-- Pure presentation model. It never mutates Items, profiles, native handles,
-- currency or gameplay. Callers own local input and synchronize each request.
OnInit.global("InventoryPreview", function()
    InventoryPreview = {}
    local M = InventoryPreview
    local MAX_PENDING = 16

    function M.create() return {serial = 0, queue = {}} end
    function M.pending(state) return #state.queue > 0 end
    function M.clear(state) state.queue = {} end
    function M.next(state)
        state.serial = state.serial + 1
        return state.serial
    end

    local function entry(item)
        if item and item.alive then
            return {item = item, identity = item.sync_id, charges = item.charges or 0}
        end
    end
    local function identity(value) return value and value.identity or 0 end

    local function apply(view, operation)
        local source, target = view[operation.from], view[operation.to]
        if not source or identity(source) ~= operation.identity or
            identity(target) ~= operation.target_identity then return false end
        if operation.stack_limit then
            local moved = math.min(source.charges, operation.stack_limit - target.charges)
            if moved <= 0 then return false end
            source.charges, target.charges = source.charges - moved, target.charges + moved
            if source.charges <= 0 then view[operation.from] = nil end
        else
            view[operation.from], view[operation.to] = target, source
        end
        return true
    end

    function M.project(state, items, stash, inventory_size, stash_size)
        local view = {}
        for slot = 1, inventory_size do view[slot] = entry(items and items[slot]) end
        for slot = 1, stash_size do view[inventory_size + slot] = entry(stash and stash[slot]) end
        for _, operation in ipairs(state.queue) do apply(view, operation) end
        return view
    end

    function M.push(state, view, from, to, stack_limit)
        local source, target = view[from], view[to]
        if #state.queue >= MAX_PENDING or not source or from == to then return nil end
        local operation = {serial = M.next(state), from = from, to = to,
            identity = source.identity, target_identity = identity(target)}
        if stack_limit and target and target.charges < stack_limit then
            operation.stack_limit = stack_limit
        end
        state.queue[#state.queue + 1] = operation
        return operation
    end

    function M.ack(state, serial)
        for index, operation in ipairs(state.queue) do
            if operation.serial == serial then table.remove(state.queue, index); return true end
        end
        return false
    end
end)
