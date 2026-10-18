-- Host-side Lua 5.3 replay of actual handlers in isolated mocked clients.
-- Not an in-game multiplayer/desync test; never loaded by the map.
local function read(path)
    local file = assert(io.open('cotlua/src/' .. path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n')
    file:close()
    return source
end
local source = read('ui/inventory/inventory.lua')
local function section(first, last)
    local start = assert(source:find(first, 1, true), first)
    local finish = assert(source:find(last, start + #first, true), last)
    return source:sub(start, finish - 1)
end
assert(not source:find('coroutine.', 1, true), 'Moves must not depend on local suspended threads')
assert(not source:find('SyncCallback("context"', 1, true))
assert(not source:find('SyncCallback("target"', 1, true))
local handlers = section('        function thistype.hasPendingMoves', '        ---@param itm Item') ..
    section('        function thistype.renderLocalPreview', '        INVENTORY.refresh =') ..
    section('        local function clear_context', '        local on_context_push') ..
    section('        local pick_item = function', '        local function update_context_buttons') ..
    section('        local function log_inventory_sync', '        local function on_cleanup') ..
    [[return {move = on_inventory_move_sync, action = on_inventory_action_sync,
        down = on_m1_down, up = on_m1_up, right_down = on_m2_down, right_up = on_m2_up}]]
local function client(local_pid)
    local env = setmetatable({}, {__index = _G})
    local trace, packets, deferred, logs = {}, {}, {}, {}
    local hovered, payload, local_render, native_refresh = 0, '', 0, 0
    env.Player, env.GetPlayerId = function(p) return p end, function(p) return p end
    env.GetLocalPlayer, env.GetTriggerPlayer = function() return local_pid - 1 end, function() return 2 end
    env.BlzGetTriggerSyncData = function() return payload end
    env.BlzSendSyncData = function(prefix, data) packets[#packets + 1] = {prefix, data} end
    env.MAX_INVENTORY_SLOTS, env.MAX_STASH_SLOTS = 26, 120
    env.OnInit = {global = function(_, init) init() end}
    assert(loadfile('cotlua/src/ui/inventory/preview.lua', 't', env))()
    env.pending_moves, env.last_move_request = env.InventoryPreview.create(), {}
    env.ITEM_STACK = 1
    env.RuntimeItemDefinitions = {sameIdentity = function(a, b) return a.id == b.id end}
    env.DROP_ITEM_COMMAND = 'robogoblin'
    local native_item = 1000000 + local_pid * 47 + 1001
    env.Profile = {[3] = {hero = {stash = {}, items = {[1] = {
        alive = true, obj = native_item, sync_id = 1001, id = 1010, holder = 'hero', cached_stats = {[1] = 0}}}}}}
    env.Hero = {[3] = 'hero'}
    env.UnitItemInSlot = function(_, slot) return 1100000 + local_pid * 47 + slot end
    env.GetHandleId = function(handle) return handle end
    env.disabled_for_player, env.move_item_cooldown, env.dragging = {}, {}, {}
    env.context, env.right_click_origin, env.skip_drag_release = {}, {}, {}
    env.ui_mode, env.ctrl_down = {[3] = 0}, {}
    env.slots, env.viewing = {}, {[local_pid] = 3}
    for slot = 1, 26 do
        env.slots[slot] = {texture = 'item:' .. slot, visible = function(self, value) self.shown = value end}
    end
    env.show_tracker, env.hide_tracker = function() end, function() end
    env.get_local_item_slot = function()
        return hovered > 0 and env.thistype.getPresentedItem(3, hovered) and hovered or 0
    end
    env.get_hovered_slot = function() return hovered end
    env.GetMouseX, env.GetMouseY = function() return 150.125 end, function() return -220.5 end
    env.render_inventory = function() local_render = local_render + 1 end
    env.thistype = {refresh = function() native_refresh = native_refresh + 1; env.render_inventory(3) end,
        renderItemButton = function(button, item, _, charges)
            local_render = local_render + 1
            button.item, button.charges = item, charges
        end}
    env.cost_frame, env.transparent_placeholder = {}, {}
    env.BlzFrameIsVisible = function() return false end
    env.open_context_menu = function(pid, open) env.ui_mode[pid] = open and 1 or 0 end
    env.TimerQueue = {callDelayed = function(_, delay, callback, pid)
        trace[#trace + 1] = 'timer:' .. delay .. ':' .. pid
        deferred[#deferred + 1] = function() callback(pid) end
    end}
    env.InventoryService = {move = function(pid, from, to)
        trace[#trace + 1] = string.format('move:%d:%d:%d', pid, from, to)
        local items = env.Profile[pid].hero.items
        items[from], items[to] = items[to], items[from]
        return {ok = true, code = 'moved'}
    end}
    env.StashService = {transfer = function(pid, from, to)
        trace[#trace + 1] = string.format('stash:%d:%d:%d', pid, from, to)
        local hero = env.Profile[pid].hero
        hero.items[from], hero.stash[to] = hero.stash[to], hero.items[from]
        return {ok = true, code = 'transferred'}
    end}
    env.StashService.move = function(pid, from, to)
        trace[#trace + 1] = 'stash-move:' .. pid .. ':' .. from .. ':' .. to
        local stash = env.Profile[pid].hero.stash
        stash[from], stash[to] = stash[to], stash[from]
        return {ok = true}
    end
    env.StashService.drop = function(pid, from) trace[#trace + 1] = 'stash-drop:' .. pid .. ':' .. from; env.Profile[pid].hero.stash[from] = nil; return {ok = true} end
    env.IssuePointOrder = function(holder, order, x, y)
        trace[#trace + 1] = string.format('order:%s:%s:%.3f:%.3f', holder, order, x, y)
    end
    env.context_functions = {[1] = function(pid, slot)
        trace[#trace + 1] = 'equip:' .. pid .. ':' .. slot
        return {ok = true, code = 'equipped'}
    end}
    env.render_inventory_result = function(_, response)
        -- Error sounds can allocate native handles: they must occur identically.
        if response and not response.ok then trace[#trace + 1] = 'error:' .. response.code end
    end
    env.DevLog = {enabled = true, write = function(category, message, defer_flush)
        assert(defer_flush == (not env.DevLog.inventory_immediate_flush), 'Incorrect inventory trace flush policy')
        logs[#logs + 1] = category .. ':' .. message
    end}
    local api = assert(load(handlers, 'inventory handlers', 't', env))()
    assert(load(section('        render_inventory = function(pid)', '        function thistype.renderLocalPreview'), 'real local renderer', 't', env))()
    local function stash_inputs()
        local stash_source = read('ui/inventory/stash.lua')
        local function piece(first, last)
            local a = assert(stash_source:find(first, 1, true))
            local b = assert(stash_source:find(last, a + #first, true))
            return stash_source:sub(a, b - 1)
        end
        local stash_env = setmetatable({open_for = {[3] = true}, ctrl_down = {},
            dragging = setmetatable({}, {__index = function() return 0 end}),
            slots = {}, INVENTORY = env.thistype, close_context = function() end}, {__index = env})
        local stash_hover = 0
        stash_env.StashUI = {isReadOnly = function() return false end, refresh = function() end,
            getLocalHoveredSlot = function() return stash_hover end}
        for slot = 1, 120 do stash_env.slots[slot] = {visible = function() end} end
        env.BlzGetItemIconPath = function(item) return 'icon:' .. item end
        env.thistype.showDragTracker, env.thistype.hideDragTracker = function() end, function() end
        env.thistype.getLocalInventoryHoveredSlot = function() return hovered end
        local inputs = assert(load(piece('    local function on_m1_down()', '    local function on_m2_down()') ..
            piece('    local function on_m1_up()', '    function StashUI.close(pid)') ..
            'return {down = on_m1_down, up = on_m1_up}', 'real stash input', 't', stash_env))()
        inputs.hover = function(slot) stash_hover = slot end
        return inputs
    end
    local serial = 0
    -- Legacy-shaped test fixtures are expanded to the actual seven-field wire
    -- format; the production handler accepts only the new complete request.
    local function synchronize(data)
        local from, to, identity, x, y = data:match('^(%d+):(%-?%d+):(%d+):([%d%.%-]+):([%d%.%-]+)$')
        if from then
            serial = serial + 1
            local hero = env.Profile[3] and env.Profile[3].hero
            local slot = tonumber(to)
            local target = hero and (slot <= 26 and hero.items[slot] or hero.stash and hero.stash[slot - 26])
            data = string.format('%d:%s:%s:%s:%d:%s:%s', serial, from, to, identity, target and target.sync_id or 0, x, y)
        else
            serial = math.max(serial, tonumber(data:match('^(%d+):')) or 0)
        end
        payload = data; api.move()
    end
    return {env = env, api = api, trace = trace, packets = packets, logs = logs, stashInputs = stash_inputs,
        hover = function(slot) hovered = slot end,
        sync = synchronize,
        action = function(data) payload = data; api.action() end,
        flush = function() for _, callback in ipairs(deferred) do callback() end; deferred = {} end,
        renders = function() return local_render, native_refresh end}
end
local function pair()
    local host, guest = client(1), client(3)
    host.env.ui_mode[3] = 1 -- remote client's locally open menu differs
    return host, guest
end
local function equal(host, guest)
    assert(table.concat(host.trace, '|') == table.concat(guest.trace, '|'), 'Shared traces diverged')
    -- The native diagnostics intentionally expose client-specific handle IDs.
    -- Compare request/result, rawcodes and logical identities, not those IDs.
    local function logical_logs(logs)
        return table.concat(logs, '|'):gsub('source=%d+/', 'source=HANDLE/')
            :gsub('target=%d+/', 'target=HANDLE/'):gsub('carriers=[%d,]+', 'carriers=HANDLES')
    end
    assert(logical_logs(host.logs) == logical_logs(guest.logs), 'Logical move diagnostics diverged')
end
local host, guest = pair()
host.hover(0); guest.hover(1)
host.api.down(3); guest.api.down(3)
assert(not host.env.dragging[3] and guest.env.dragging[3])
assert(#host.packets == 0 and #guest.packets == 0, 'Picking a source sent a partial request')
guest.hover(9)
host.api.up(3); guest.api.up(3)
assert(#host.packets == 0 and #guest.packets == 1)
assert(guest.packets[1][1] == 'inventory_move')
assert(guest.packets[1][2] == '1:1:9:1001:0:150.125:-220.500')
local rendered, refreshed = guest.renders()
assert(rendered >= 1 and refreshed == 0, 'Local release refreshed native potion/item state')
assert(#host.trace == 0 and #guest.trace == 0, 'Local input scheduled or mutated gameplay')
host.sync(guest.packets[1][2]); guest.sync(guest.packets[1][2]); equal(host, guest)
assert(host.env.Profile[3].hero.items[9].sync_id == 1001 and guest.env.Profile[3].hero.items[9].sync_id == 1001)
assert(host.env.Profile[3].hero.items[9].obj ~= guest.env.Profile[3].hero.items[9].obj,
    'Regression must exercise different native handles for the same logical item')
assert(host.trace[1] == 'move:3:1:9' and #host.trace == 1)
host.sync(guest.packets[1][2]); guest.sync(guest.packets[1][2]); equal(host, guest)
assert(#host.trace == 1, 'Replayed request mutated gameplay')
host.sync('9:1:1001:0:0'); guest.sync('9:1:1001:0:0'); equal(host, guest)
assert(#host.trace == 2, 'Distinct consecutive request was delayed by a movement lockout')

-- Exact reported case: host drags backpack slot 10 into empty slot 16.
-- It must also work when another same-type item already occupies that slot.
for _, occupied in ipairs({false, true}) do
    host, guest = pair()
    for _, c in ipairs({host, guest}) do
        local items = c.env.Profile[3].hero.items
        items[10], items[1] = items[1], nil
        if occupied then
            items[16] = {alive = true, sync_id = 1002, obj = items[10].obj + 10,
                id = items[10].id, holder = 'hero'}
        end
    end
    host.sync('10:16:1001:0:0'); guest.sync('10:16:1001:0:0'); equal(host, guest)
    assert(host.trace[1] == 'move:3:10:16')
    for _, c in ipairs({host, guest}) do
        assert(c.env.Profile[3].hero.items[16].sync_id == 1001)
        assert((c.env.Profile[3].hero.items[10] and c.env.Profile[3].hero.items[10].sync_id)
            == (occupied and 1002 or nil))
    end
end

-- Replacing a slot with another instance of the SAME rawcode still invalidates
-- an older draft; removing the identity check entirely would be unsafe.
host, guest = pair()
host.env.Profile[3].hero.items[1].sync_id = 1002
guest.env.Profile[3].hero.items[1].sync_id = 1002
host.sync('1:9:1001:0:0'); guest.sync('1:9:1001:0:0'); equal(host, guest)
assert(host.trace[1] == 'error:stale' and host.env.Profile[3].hero.items[9] == nil)

for _, case in ipairs({
    {'1:27:1001:0:0', 'stash:3:1:1'},
    {'1:-1:1001:150.125:-220.500', 'order:hero:robogoblin:150.125:-220.500'},
    {'1:9:9999:0:0', 'error:stale'},
}) do
    host, guest = pair()
    host.sync(case[1]); guest.sync(case[1]); equal(host, guest)
    assert(host.trace[1] == case[2] and #host.trace == 1)
end
for _, data in ipairs({'bad', '1:9:0:0:0', '0:9:1001:0:0', '147:9:1001:0:0', '1:0:1001:0:0',
    '1:147:1001:0:0', '1:-2:1001:0:0', '1:9:1001:999999:0', '1:9:1001:1..2:0'}) do
    host, guest = pair()
    host.sync(data); guest.sync(data); equal(host, guest)
    assert(#host.trace == 0, 'Invalid packet mutated gameplay or scheduled a timer: ' .. data)
end
host, guest = pair()
host.env.disabled_for_player[3], guest.env.disabled_for_player[3] = true, true
host.sync('1:9:1001:0:0'); guest.sync('1:9:1001:0:0'); equal(host, guest)
assert(host.trace[1] == 'error:stale')
host, guest = pair()
host.env.Profile[3], guest.env.Profile[3] = nil, nil
host.sync('1:9:1001:0:0'); guest.sync('1:9:1001:0:0'); equal(host, guest)
assert(host.trace[1] == 'error:stale')

-- Double-clicking a world unit/backpack is not an inventory drag.
host, guest = pair()
for _ = 1, 2 do
    host.api.down(3); guest.api.down(3); host.api.up(3); guest.api.up(3)
end
assert(#host.packets == 0 and #guest.packets == 0 and #guest.trace == 0)
for _, end_slot in ipairs({0, 1}) do
    host, guest = pair(); guest.hover(1); guest.api.down(3)
    guest.hover(end_slot); guest.api.up(3)
    assert(#guest.packets == 0 and #guest.trace == 0, 'Cancelled drag sent a gameplay request')
end
host, guest = pair()
guest.env.ctrl_down[3] = true
guest.env.StashUI = {isOpen = function() return true end, isReadOnly = function() return false end}
guest.hover(1); guest.api.down(3); guest.api.up(3)
assert(#guest.packets == 1 and guest.packets[1][1] == 'stash_action' and guest.packets[1][2] == 'deposit:1')
assert(#guest.trace == 0 and not guest.env.dragging[3])
host, guest = pair()
host.action('1:9'); guest.action('1:9'); equal(host, guest)
assert(host.trace[1] == 'equip:3:9')
host, guest = pair()
host.hover(1); guest.hover(1)
host.api.right_down(3); guest.api.right_down(3); host.api.right_up(3); guest.api.right_up(3)
assert(not host.env.right_click_origin[3] and guest.env.ui_mode[3] == 1)
assert(#host.packets == 0 and #guest.packets == 0)
-- Focused diagnostics can restore eager persistence without affecting moves.
host, guest = pair()
host.env.DevLog.inventory_immediate_flush, guest.env.DevLog.inventory_immediate_flush = true, true
host.sync('1:9:1001:0:0'); guest.sync('1:9:1001:0:0'); equal(host, guest)
assert(host.env.Profile[3].hero.items[9].sync_id == 1001)

-- Rapid chained drags immediately redraw real slot frames, while the actual
-- profile and gameplay/native traces remain untouched until sync is delivered.
host, guest = pair()
guest.hover(1); guest.api.down(3); guest.hover(9); guest.api.up(3)
assert(guest.env.slots[9].item.sync_id == 1001 and not guest.env.slots[1].item)
assert(guest.env.Profile[3].hero.items[1].sync_id == 1001 and not guest.env.Profile[3].hero.items[9])
guest.hover(9); guest.api.down(3); guest.hover(10); guest.api.up(3)
assert(#guest.packets == 2 and #guest.trace == 0)
assert(guest.env.slots[10].item.sync_id == 1001 and not guest.env.slots[9].item)
assert(not guest.env.thistype.getPresentedItems(3)[9])
-- Context actions/quick deposits cannot target projected slots before commit.
guest.env.ctrl_down[3] = true
guest.env.StashUI = {isOpen = function() return true end, isReadOnly = function() return false end}
guest.hover(10); guest.api.down(3); guest.api.up(3)
assert(#guest.packets == 2)
guest.env.StashUI = nil
for _, packet in ipairs(guest.packets) do
    host.sync(packet[2]); guest.sync(packet[2]); equal(host, guest)
    assert(guest.env.slots[10].item.sync_id == 1001, 'Intermediate acknowledgement flashed the old layout')
end
assert(not guest.env.thistype.hasPendingMoves(3))
assert(host.env.Profile[3].hero.items[10].sync_id == 1001)
-- Run the actual domain's stack commits, including its synchronous change
-- notification. Acknowledging after that notification would double-project
-- the first merge and momentarily display the wrong remainder.
for _, source_charges in ipairs({7, 2}) do
    host, guest = pair()
    for _, client in ipairs({host, guest}) do
        local env = client.env
        local items = env.Profile[3].hero.items
        items[1].charges, items[1].level, items[1].slot = source_charges, 1, 1
        items[1].cached_stats[env.ITEM_STACK] = 10
        items[9] = {alive = true, sync_id = 1002, obj = 99, id = 1010,
            charges = 8, level = 1, slot = 9, cached_stats = {[env.ITEM_STACK] = 10}}
        items[1].destroy = function(self) self.alive = false; items[self.slot] = nil end
        env.ValidateItemSlot = function() return true end
        env.ItemRuntime = {commit_slot = function(item, slot)
            items[item.slot], items[slot], item.slot = nil, item, slot
        end}
        local domain = read('gameplay/items/inventory.lua')
        local start = assert(domain:find('    local function result', 1, true))
        local finish = assert(domain:find('    local function find_empty_target', start, true))
        assert(load(domain:sub(start, finish - 1), 'actual inventory domain', 't', env))()
    end
    guest.env.NotifyItemChanged = function()
        guest.env.render_inventory(3)
        assert(not guest.env.slots[1].item, 'Merge notification replayed an acknowledged preview')
        assert(guest.env.slots[10].charges == (source_charges == 7 and 5 or 10))
    end
    host.env.NotifyItemChanged = function() end
    assert(guest.env.thistype.requestMove(3, 1, 9, 1001))
    assert(guest.env.slots[9].charges == 10 and guest.env.Profile[3].hero.items[9].charges == 8)
    local next_from = source_charges == 7 and 1 or 9
    local next_identity = source_charges == 7 and 1001 or 1002
    assert(guest.env.thistype.requestMove(3, next_from, 10, next_identity))
    for _, packet in ipairs(guest.packets) do host.sync(packet[2]); guest.sync(packet[2]); equal(host, guest) end
    assert(not guest.env.thistype.hasPendingMoves(3))
    assert(host.env.Profile[3].hero.items[10].charges == (source_charges == 7 and 5 or 10))
end
-- Another item arriving in the target slot invalidates the whole requested
-- pair. Both clients reject it, and the local preview rolls back correctly.
host, guest = pair()
guest.hover(1); guest.api.down(3); guest.hover(9); guest.api.up(3)
for _, client in ipairs({host, guest}) do
    client.env.Profile[3].hero.items[9] = {alive = true, sync_id = 1002, obj = 42, id = 1010}
end
host.sync(guest.packets[1][2]); guest.sync(guest.packets[1][2]); equal(host, guest)
assert(host.trace[1] == 'error:stale')
assert(guest.env.slots[1].item.sync_id == 1001 and guest.env.slots[9].item.sync_id == 1002)
assert(not guest.env.thistype.hasPendingMoves(3))
-- Service rejection (level/type/binding/etc.) also rolls back; accepting an
-- independent later request does not require trusting any preview contents.
host, guest = pair()
for _, client in ipairs({host, guest}) do
    client.env.InventoryService.move = function() return {ok = false, code = 'invalid_target'} end
end
guest.hover(1); guest.api.down(3); guest.hover(9); guest.api.up(3)
host.sync(guest.packets[1][2]); guest.sync(guest.packets[1][2]); equal(host, guest)
assert(guest.env.slots[1].item.sync_id == 1001 and not guest.env.slots[9].item)
-- Stash/inventory swaps share the exact same identity-checked request path.
host, guest = pair()
for _, client in ipairs({host, guest}) do
    client.env.Profile[3].hero.stash[1] = {alive = true, sync_id = 2001, obj = 43, id = 2020}
end
assert(guest.env.thistype.requestMove(3, 1, 27, 1001))
assert(guest.env.thistype.requestMove(3, 27, 9, 1001))
assert(guest.env.thistype.getPresentedItem(3, 1).sync_id == 2001)
assert(guest.env.slots[9].item.sync_id == 1001 and #guest.trace == 0)
for _, packet in ipairs(guest.packets) do host.sync(packet[2]); guest.sync(packet[2]); equal(host, guest) end
assert(host.env.Profile[3].hero.items[9].sync_id == 1001)
assert(host.env.Profile[3].hero.items[1].sync_id == 2001)
assert(not host.env.Profile[3].hero.stash[1])
-- Actual stash mouse handlers use projected identities and the same atomic
-- packet; stash chrome must never become inventory slot 26 accidentally.
host, guest = pair()
for _, client in ipairs({host, guest}) do
    client.env.Profile[3].hero.stash[1] = {alive = true, sync_id = 2001, obj = 44, id = 2020}
end
local stash_input = guest.stashInputs()
stash_input.hover(0); stash_input.down(); stash_input.up()
assert(#guest.packets == 0)
stash_input.hover(1); stash_input.down()
stash_input.hover(-1); guest.hover(9); stash_input.up()
assert(#guest.packets == 1 and #guest.trace == 0)
assert(guest.env.slots[9].item.sync_id == 2001 and guest.env.Profile[3].hero.stash[1].sync_id == 2001)
host.sync(guest.packets[1][2]); guest.sync(guest.packets[1][2]); equal(host, guest)
assert(host.env.Profile[3].hero.items[9].sync_id == 2001 and not host.env.Profile[3].hero.stash[1])
print('PASS (mocked clients): different native handles, empty backpack move, same-type swap/replacement, atomic equipment/stash/drop moves, menu divergence, stale/invalid/replayed requests, chained visual moves/rollback, real stash input, deferred logging, Ctrl-click and world double-click.')

-- Execute the actual center calculation and hit-test, independently of moves.
local env = setmetatable({slot_centers = {}, INVENTORY_FRAME_X = 0.575, INVENTORY_FRAME_Y = 0.408,
    INVENTORY_ROW_X = 0.02, INVENTORY_ROW_Y = -0.06, INVENTORY_WIDTH = 0.1981,
    INVENTORY_HEIGHT = 0.232, INVENTORY_SLOT_SIZE = 0.0266, INVENTORY_GAPY = 0.0312}, {__index = _G})
local center_code = section('                local parent_x = INVENTORY_FRAME_X', '                slots[id] = Button.create')
local build_center = assert(load(center_code, 'slot center calculation', 't', env))
for id = 1, 26 do
    env.id = id
    env.kind = id <= 6 and 'main' or id == 7 and 'potion1' or id == 8 and 'potion2' or 'unequip'
    local col = id <= 6 and id or id <= 8 and 1 or ((id - 9) % 6 + 1)
    env.offx = 0.0032 + env.INVENTORY_WIDTH / 6 * (col - 1)
    env.offy = id >= 7 and id <= 8 and -0.0032 or -0.0033
    build_center()
end
local x, y
env.get_mouse_frame_position = function() return x, y end
local hit = assert(load(section('        local get_inventory_hovered_slot = function()',
    '        local function get_hovered_slot()') .. 'return get_inventory_hovered_slot', 'slot hit-test', 't', env))()
for id, center in ipairs(env.slot_centers) do
    x, y = center[1], center[2]; assert(hit() == id)
    x, y = center[1], center[2] - 0.01329; assert(hit() == id, 'Visible bottom edge missed slot ' .. id)
end
assert(math.abs(env.slot_centers[1][2] - 0.3314) < 0.000001)
assert(math.abs(env.slot_centers[9][2] - 0.2736) < 0.000001)
x, y = 0.612, 0.31; assert(hit() == 0)
x, y = 0.3, 0.3; assert(hit() == -1)
print('PASS (mocked layout): hitboxes follow actual equipment, potion and backpack icon centers and edges.')

-- The logged -color exception must be rejected before mutating player state.
local command_source = read('gameplay/players/commands.lua')
local first = assert(command_source:find('["-color"] = ', 1, true)) + #'["-color"] = '
local last = assert(command_source:find(',\n        ["-roll"]', first, true))
local writes = 0
local command_env = setmetatable({OriginalHex = {}, User = {[0] = {colorUnits = function() writes = writes + 1 end}},
    ConvertPlayerColor = function(p) return p end, GetPlayerName = function() return 'tester' end,
    SetPlayerColor = function() writes = writes + 1 end}, {__index = _G})
for i = 1, 24 do command_env.OriginalHex[i] = 'color' .. i end
local color = assert(load('return ' .. command_source:sub(first, last - 1), 'color command', 't', command_env))()
for _, value in ipairs({'25', '1.5', '0', '-1', 'oops'}) do color(0, 1, {'-color', value}) end
assert(writes == 0 and command_env.User[0].hex == nil)
color(0, 1, {'-color', '24'})
assert(writes == 2 and command_env.User[0].hex == 'color24')
print('PASS: unsupported/fractional player colors rejected before mutation; last supported color accepted.')
