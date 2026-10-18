-- Pure synchronized record storage: no native handles, frames, or local input.
OnInit.global("LootModel", function()
    LootModel = {}
    local M = LootModel
    local function cell(x, y) return x .. ":" .. y end
    function M.create(threshold, radius)
        return {threshold = threshold, radius = radius, cells = {}, piles = {}, entries = {}, serial = 0, heap = {}}
    end
    local function heap_swap(heap, a, b)
        heap[a], heap[b] = heap[b], heap[a]
        heap[a].heap_index, heap[b].heap_index = a, b
    end
    local function heap_up(heap, index)
        while index > 1 do
            local parent = index // 2
            if heap[parent].deadline <= heap[index].deadline then break end
            heap_swap(heap, index, parent); index = parent
        end
    end
    local function heap_down(heap, index)
        while index * 2 <= #heap do
            local child = index * 2
            if child < #heap and heap[child + 1].deadline < heap[child].deadline then child = child + 1 end
            if heap[index].deadline <= heap[child].deadline then break end
            heap_swap(heap, index, child); index = child
        end
    end
    function M.unschedule(state, entry)
        local heap, index = state.heap, entry.heap_index
        if not index then return end
        local last = table.remove(heap)
        entry.heap_index = nil
        if index <= #heap then
            heap[index] = last; last.heap_index = index
            heap_up(heap, index); heap_down(heap, last.heap_index)
        end
    end
    function M.add(state, item, x, y, scope, deadline)
        assert(not state.entries[item.sync_id], "Duplicate loot record")
        local cx, cy, best, distance = math.floor(x / state.radius), math.floor(y / state.radius), nil, math.huge
        for dx = -1, 1 do for dy = -1, 1 do
            for _, pile in ipairs(state.cells[cell(cx + dx, cy + dy)] or {}) do
                local d = (pile.x - x)^2 + (pile.y - y)^2
                if pile.scope == scope and d <= state.radius^2 and
                    (not best or pile.bundled and not best.bundled or pile.bundled == best.bundled and
                        (d < distance or d == distance and pile.id < best.id)) then
                    best, distance = pile, d
                end
            end
        end end
        if not best then
            state.serial = state.serial + 1
            best = {id = state.serial, x = x, y = y, scope = scope, entries = {}, revision = 0, bundled = false,
                cell = cell(cx, cy)}
            state.piles[best.id] = best
            local list = state.cells[best.cell] or {}; state.cells[best.cell] = list; list[#list + 1] = best
        end
        item.loot_revision = (item.loot_revision or 0) + 1
        local entry = {id = item.sync_id, item = item, pile = best, revision = item.loot_revision, deadline = deadline}
        entry.index = #best.entries + 1; best.entries[entry.index] = entry
        state.entries[entry.id] = entry; best.revision = best.revision + 1
        if deadline then
            entry.heap_index = #state.heap + 1; state.heap[entry.heap_index] = entry
            heap_up(state.heap, entry.heap_index)
        end
        if #best.entries >= state.threshold then best.bundled = true end
        return entry
    end
    function M.remove(state, entry)
        if state.entries[entry.id] ~= entry then return end
        M.unschedule(state, entry)
        local pile = entry.pile
        local last = table.remove(pile.entries)
        if last ~= entry then pile.entries[entry.index] = last; last.index = entry.index end
        state.entries[entry.id] = nil; pile.revision = pile.revision + 1
        if #pile.entries == 0 then
            state.piles[pile.id] = nil
            local list = state.cells[pile.cell]
            for i, value in ipairs(list) do if value == pile then table.remove(list, i); break end end
            if #list == 0 then state.cells[pile.cell] = nil end
        end
        return pile
    end
    function M.due(state, now)
        local entry = state.heap[1]
        if entry and entry.deadline <= now then M.unschedule(state, entry); return entry end
    end
end)
