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
local handlers = section('        local function clear_context', '        local on_context_push') ..
    section('        local pick_item = function', '        local function update_context_buttons') ..
    section('        local function on_inventory_action_sync', '        local function on_cleanup') ..
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
    env.DROP_ITEM_COMMAND = 'robogoblin'
    env.Profile = {[3] = {hero = {items = {[1] = {alive = true, obj = 1001, holder = 'hero'}}}}}
    env.GetHandleId = function(handle) return handle end
    env.disabled_for_player, env.move_item_cooldown, env.dragging = {}, {}, {}
    env.context, env.right_click_origin, env.skip_drag_release = {}, {}, {}
    env.ui_mode, env.ctrl_down = {[3] = 0}, {}
    env.slots = {[1] = {texture = 'sword', visible = function() end}}
    env.show_tracker, env.hide_tracker = function() end, function() end
    env.get_local_item_slot, env.get_hovered_slot = function() return hovered end, function() return hovered end
    env.GetMouseX, env.GetMouseY = function() return 150.125 end, function() return -220.5 end
    env.render_inventory = function() local_render = local_render + 1 end
    env.thistype = {refresh = function() native_refresh = native_refresh + 1 end}
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
        return {ok = true, code = 'transferred'}
    end}
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
    env.DevLog = {write = function(category, message) logs[#logs + 1] = category .. ':' .. message end}
    local api = assert(load(handlers, 'inventory handlers', 't', env))()
    return {env = env, api = api, trace = trace, packets = packets, logs = logs,
        hover = function(slot) hovered = slot end,
        sync = function(data) payload = data; api.move() end,
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
    assert(table.concat(host.logs, '|') == table.concat(guest.logs, '|'), 'Move diagnostics diverged')
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
assert(guest.packets[1][2] == '1:9:1001:150.125:-220.500')
local rendered, refreshed = guest.renders()
assert(rendered == 1 and refreshed == 0, 'Local release refreshed native potion/item state')
assert(#host.trace == 0 and #guest.trace == 0, 'Local input scheduled or mutated gameplay')
host.sync(guest.packets[1][2]); guest.sync(guest.packets[1][2]); equal(host, guest)
assert(host.env.Profile[3].hero.items[9].obj == 1001 and guest.env.Profile[3].hero.items[9].obj == 1001)
assert(host.trace[1] == 'move:3:1:9' and #host.trace == 2)
host.sync('9:1:1001:0:0'); guest.sync('9:1:1001:0:0'); equal(host, guest)
assert(#host.trace == 2, 'Cooldown did not reject repeated requests')
host.flush(); guest.flush()
host.sync('9:1:1001:0:0'); guest.sync('9:1:1001:0:0'); equal(host, guest)
assert(#host.trace == 4)

for _, case in ipairs({
    {'1:27:1001:0:0', 'stash:3:1:1'},
    {'1:-1:1001:150.125:-220.500', 'order:hero:robogoblin:150.125:-220.500'},
    {'1:9:9999:0:0', 'error:stale'},
}) do
    host, guest = pair()
    host.sync(case[1]); guest.sync(case[1]); equal(host, guest)
    assert(host.trace[1] == case[2] and #host.trace == 2)
end
for _, data in ipairs({'bad', '0:9:1001:0:0', '27:9:1001:0:0', '1:0:1001:0:0',
    '1:147:1001:0:0', '1:-2:1001:0:0', '1:9:1001:999999:0', '1:9:1001:1..2:0'}) do
    host, guest = pair()
    host.sync(data); guest.sync(data); equal(host, guest)
    assert(#host.trace == 0, 'Invalid packet mutated gameplay or scheduled a timer: ' .. data)
end
host, guest = pair()
host.env.disabled_for_player[3], guest.env.disabled_for_player[3] = true, true
host.sync('1:9:1001:0:0'); guest.sync('1:9:1001:0:0'); equal(host, guest)
assert(#host.trace == 0)
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
print('PASS (mocked clients): atomic equipment/backpack/stash/drop moves, menu divergence, stale/invalid requests, cooldown, Ctrl-click and world double-click.')

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
