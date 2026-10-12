-- Host-only Lua 5.3 callback replay. This is NOT a Warcraft multiplayer test.
-- Two isolated clients see different local selections/UI but the same inputs.
local function read(path)
    local file = assert(io.open('cotlua/src/' .. path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n')
    file:close()
    return source
end
local mouse_source = read('gameplay/players/mouse_input.lua')
local keys_source = read('gameplay/players/hotkeys.lua')
local controls_source = read('gameplay/players/ability_controls.lua')
local button_source = read('framework/ui/glue_button.lua')
local helper_source = read('framework/ui/frame_helpers.lua')
local buff_source = read('ui/hud/buff_bar.lua')
local function replay(local_pid)
    local env = setmetatable({}, {__index = _G})
    local allocations, deferred, timers, trace = 0, {}, {}, {}
    local function handle() allocations = allocations + 1; return {} end
    local event, trigger_player, trigger_unit, mouse_button
    env.Player, env.GetPlayerId = function(p) return p end, function(p) return p end
    env.GetLocalPlayer = function() return local_pid - 1 end
    env.GetTriggerPlayer = function() return trigger_player end
    env.GetTriggerUnit = function() return trigger_unit end
    env.BlzGetTriggerPlayerMouseButton = function() return mouse_button end
    env.BlzGetTriggerPlayerMouseX, env.BlzGetTriggerPlayerMouseY = function() return 150 end, function() return 200 end
    env.__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
    env.array2d = function(value) return setmetatable({}, {__index = function(t, key)
        local row = env.__jarray(value); rawset(t, key, row); return row
    end}) end
    env.PLAYER_CAP, env.FPS_32 = 2, 1 / 32
    env.Debug = nil
    env.OnInit = {global = function(_, callback) callback(function() end) end,
        final = function(name, callback) (callback or name)(function() end) end}
    env.TimerQueue = {callDelayed = function(_, delay, callback, ...)
        deferred[#deferred + 1] = {callback = callback, args = table.pack(...), delay = delay}
    end, disableCallback = function() error('UI touched the shared callback queue') end}
    local function flush()
        local tasks = deferred; deferred = {}
        for _, task in ipairs(tasks) do task.callback(table.unpack(task.args, 1, task.args.n)) end
        assert(#deferred == 0, 'Presentation scheduled additional gameplay callbacks')
    end
    env.CreateTimer = function() local timer = handle(); timers[#timers + 1] = timer; return timer end
    env.TimerStart = function(timer, period, _, callback) timer.period, timer.callback = period, callback end
    env.PauseTimer, env.TimerGetElapsed = function() end, function() return 0 end
    env.CreateTrigger, env.CreateGroup = handle, handle
    env.DestroyTrigger = function() end
    env.Filter, env.Condition = function(callback) allocations = allocations + 1; return callback end,
        function(callback) allocations = allocations + 1; return callback end
    env.TriggerAddAction, env.TriggerAddCondition = function(t, callback) t.callback = callback end,
        function(t, callback) t.callback = callback end
    local triggers = {}
    env.TriggerRegisterPlayerEvent = function(t, _, kind) triggers[kind] = t end
    env.TriggerRegisterPlayerUnitEvent = env.TriggerRegisterPlayerEvent
    env.BlzTriggerRegisterFrameEvent = function() end
    env.User = {first = {id = 1, player = 0, next = {id = 2, player = 1}}}
    for _, name in ipairs({'EVENT_PLAYER_UNIT_SELECTED', 'EVENT_PLAYER_UNIT_DESELECTED', 'EVENT_PLAYER_MOUSE_MOVE',
        'EVENT_PLAYER_MOUSE_DOWN', 'EVENT_PLAYER_MOUSE_UP', 'MOUSE_BUTTON_TYPE_LEFT',
        'MOUSE_BUTTON_TYPE_RIGHT'}) do env[name] = name end
    local function player_event(name)
        return {actions = {}, register_action = function(self, pid, callback) self.actions[pid] = callback end,
            trigger = function(self, pid, unit)
                trace[#trace + 1] = name .. ':' .. pid .. ':' .. (unit and unit.name or '-')
                if self.actions[pid] then self.actions[pid](pid, unit) end
            end}
    end
    for _, name in ipairs({'EVENT_ON_SELECT', 'EVENT_ON_M1_UP', 'EVENT_ON_M2_UP',
        'EVENT_ON_M1_DOWN', 'EVENT_ON_M2_DOWN', 'EVENT_ON_MOUSE_MOVE', 'EVENT_ON_CLEANUP'}) do
        env[name] = player_event(name)
    end
    env.EVENT_ON_UNIT_SELECT = {trigger = function(_, unit, pid)
        trace[#trace + 1] = 'unit_select:' .. pid .. ':' .. unit.name
    end}
    env.BlzFrameSetVisible = function(frame, visible) frame.visible = visible end
    env.BlzFrameSetText = function(frame, text) frame.text = text end
    env.BlzFrameSetValue = function(frame, value) frame.value = value end
    env.BlzFrameSetTexture = function() end
    for _, name in ipairs({'BlzFrameSetSize', 'BlzFrameSetAbsPoint', 'BlzFrameSetEnable',
        'BlzFrameSetScale', 'BlzFrameClearAllPoints', 'BlzFrameSetPoint', 'BlzFrameSetLevel'}) do env[name] = function() end end
    env.BlzCreateFrameByType = handle
    env.BlzGetFrameByName, env.BlzGetOriginFrame, env.BlzGetFrameById = handle, handle, handle
    env.BlzFrameGetParent, env.BlzFrameGetChild = handle, handle
    env.BlzFrameGetChildrenCount = function() return 0 end
    env.BlzFrameIsVisible = function(frame) return frame.visible end
    env.HIDE_HEALTH_FRAME, env.bj_lastCreatedGroup = {}, {sentinel = true}
    local local_unit = local_pid == 1 and {name = 'host local selection'} or nil
    env.GroupEnumUnitsSelected = function(group) group.first = local_unit end
    env.FirstOfGroup = function(group) return group.first end
    local function load_module(source, name) assert(load(source, name, 't', env))() end
    load_module(helper_source, 'FrameHelpers')
    flush() -- Native frame getters are warmed on both clients, not on first use.
    local before_lookup = allocations
    assert(env.GetMainSelectedUnit() == local_unit)
    assert(allocations == before_lookup, 'Local selection lookup allocated native handles')
    assert(env.bj_lastCreatedGroup.first == nil, 'Local selection polluted the shared BJ group')
    env.GetMainSelectedUnit = function() error('Shared input read local selection') end
    load_module(button_source, 'Gluebutton')
    local ui_timer
    for _, timer in ipairs(timers) do if timer.period == env.FPS_32 then ui_timer = timer end end
    assert(ui_timer and ui_timer.callback, 'UI cooldown timer was not pre-created')
    local button = setmetatable({cooldownFrame = {}, cooldownText = {}}, {__index = env.Button})
    button:use_cooldowns()
    local before_cooldown = allocations
    button:cooldown(2, 2)
    assert(#deferred == 0 and allocations == before_cooldown, 'Local cooldown changed shared queue/handles')
    ui_timer.callback()
    if local_pid == 2 then
        assert(button.cooldown_time[2] == 2 - env.FPS_32 and button.cooldownFrame.visible)
        button:cooldown(1, 2) -- Replace, rather than stack, the existing countdown.
        for _ = 1, 32 do ui_timer.callback() end
        assert(button.cooldown_time[2] == 0 and not button.cooldownFrame.visible)
        button:cooldown(0, 2, 0)
        assert(button.cooldownFrame.value == button.cooldownFrame.value, 'Zero duration produced NaN')
    else
        assert(button.cooldown_time[2] == 0 and button.cooldownFrame.visible == nil)
    end
    assert(#deferred == 0 and allocations == before_cooldown)
    local buff_buttons = {}
    env.Button.create = function()
        local b = setmetatable({frame = handle(), iconFrame = handle(), cooldownFrame = handle(),
            cooldownText = handle(), chargeFrame = handle(), chargeText = handle(), tooltip = {
                point = function() end, icon = function() end, text = function() end, name = function() end}},
            {__index = env.Button})
        buff_buttons[#buff_buttons + 1] = b
        return b
    end
    env.Unit, env.BUFF_NEGATIVE = {}, 'negative'
    env.UnitAlive = function() return true end
    local change_buff
    env.Buff = {onChange = function(callback) change_buff = callback end}
    load_module(buff_source, 'BuffBar')
    local tester_hero = {name = 'tester hero'}
    local buff = {index = 1, NAME = 'Test buff', DESC = '', ICON = 'icon', target = tester_hero,
        remaining = function() return 5 end, timeout = function() return 5 end}
    env.Unit[tester_hero] = {unit = tester_hero, buffs = {buff}, hidehp = false}
    env.Hero, env.IS_M2_DOWN = {[2] = tester_hero}, {}
    load_module(mouse_source, 'Mouse')
    trigger_player, trigger_unit = 1, tester_hero
    triggers.EVENT_PLAYER_UNIT_SELECTED.callback()
    flush()
    mouse_button = env.MOUSE_BUTTON_TYPE_LEFT
    triggers.EVENT_PLAYER_MOUSE_UP.callback()
    flush()
    local before_buff = allocations
    change_buff(tester_hero)
    ui_timer.callback()
    assert(#deferred == 0 and allocations == before_buff, 'Buff display changed shared queue/handles')
    buff.AURA = true
    change_buff(tester_hero)
    ui_timer.callback()
    if local_pid == 2 then assert(not buff_buttons[1].cooldownFrame.visible, 'Aura retained old countdown') end
    -- Execute the actual control-group refresh handler without loading unrelated keybindings.
    local first = assert(keys_source:find('    local function update_ui', 1, true))
    local last = assert(keys_source:find('    local function on_rebind', first, true))
    local update_ui = assert(load(keys_source:sub(first, last - 1) .. '\nreturn update_ui', 'hotkey refresh', 't', env))()
    update_ui(2, true); flush()
    -- Actual movement handler: native selection intentionally differs by client.
    env.IsUnitSelected = function() return local_pid == 2 end
    env.DistanceCoords = function() return 10 end
    env.GroupEnumUnitsInRange, env.DestroyGroup = function() end, function() end
    env.ishostile = function() return false end
    env.IssuePointOrder = function(unit, order, x, y) trace[#trace + 1] = unit.name .. ':' .. order .. ':' .. x .. ':' .. y end
    local move_first = assert(controls_source:find('    local mouse_move = function', 1, true))
    local move_last = assert(controls_source:find('    local function unselect_bp', move_first, true))
    local movement = assert(load(controls_source:sub(move_first, move_last - 1) .. '\nreturn mouse_move', 'movement', 't', env))()
    env.IS_M2_DOWN[2] = true
    movement(2, 150, 200, 140, 190)
    assert(trace[#trace] == 'tester hero:smart:150:200', 'Right-click movement was not synchronized')
    -- Group selection retains the hero; deselection prevents stale move orders.
    trigger_unit = {name = 'tester backpack'}
    env.Unit[trigger_unit] = {unit = trigger_unit}
    triggers.EVENT_PLAYER_UNIT_SELECTED.callback(); flush()
    assert(env.IsPlayerUnitSelected(2, tester_hero))
    local orders_before = #trace
    movement(2, 150, 200, 140, 190)
    assert(#trace == orders_before + 1, 'Group selection lost hero movement')
    trigger_unit = tester_hero
    triggers.EVENT_PLAYER_UNIT_DESELECTED.callback(); flush()
    orders_before = #trace
    movement(2, 150, 200, 140, 190)
    assert(#trace == orders_before, 'Deselected hero still received move orders')
    assert(#deferred == 0)
    return table.concat(trace, '\n'), allocations
end
local host_trace, host_handles = replay(1)
local guest_trace, guest_handles = replay(2)
assert(host_trace == guest_trace, 'Same input dispatched different shared callbacks/orders')
assert(host_handles == guest_handles, 'Client-local UI exposed different native handle counts')
print('PASS (offline callback replay only): selection, control-group refresh and movement agree across clients with different local selections.')
print('PASS (offline native mocks only): button/buff cooldowns allocate no local handles and never touch the shared TimerQueue.')
