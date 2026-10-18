-- Host Lua 5.3 only; actual drag tracker code with two isolated client mocks.
local file = assert(io.open('cotlua/src/ui/inventory/inventory.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n')
file:close()
local first = assert(source:find('        local tracker = BlzCreateFrameByType', 1, true))
local last = assert(source:find('        --#endregion', first, true))
local code = source:sub(first, last - 1)
local function client(local_player)
    local env = setmetatable({}, {__index = _G})
    local trace, callback, icon, moves = {}, nil, nil, 0
    env.Player = function(id) return id end
    env.GetLocalPlayer = function() return local_player end
    env.BlzGetFrameByName = function() return {} end
    env.BlzCreateFrameByType = function() icon = {}; return icon end
    env.CreateTimer = function() trace[#trace + 1] = 'create'; return {} end
    env.TimerStart = function(_, period, periodic, fn)
        assert(period == 1 / 128 and periodic)
        trace[#trace + 1] = 'start'; callback = fn
    end
    env.PauseTimer, env.DestroyTimer = function() error('Local drag mutated native timer lifecycle') end,
        function() error('Local drag destroyed its native timer') end
    env.BlzFrameSetTexture = function(frame, texture) frame.texture = texture end
    env.BlzFrameSetEnable, env.BlzFrameSetSize, env.BlzFrameSetLevel = function() end, function() end, function() end
    env.get_mouse_frame_position = function() return .5, .4 end
    env.setabspoint = function() moves = moves + 1 end
    env.INVENTORY_SLOT_SIZE, env.TRACKER_FOLLOW, env.FRAMEPOINT_CENTER = .0266, .82, 0
    env.thistype = {}
    assert(load(code, 'actual tracker', 't', env))()
    callback(); assert(moves == 0, 'Idle tracker performed local work')
    for _ = 1, 3 do
        env.thistype.showDragTracker(5, 'sword')
        callback()
        if local_player == 4 then
            assert(icon.texture == 'sword' and moves > 0)
        else
            assert(icon.texture == 'trans32.blp' and moves == 0)
        end
        env.thistype.hideDragTracker(5)
        local before = moves
        callback(); assert(moves == before, 'Hidden tracker still updated position')
        assert(icon.texture == 'trans32.blp')
    end
    assert(#trace == 2, 'Drag started additional native timers')
    return table.concat(trace, ',')
end
assert(client(0) == client(4), 'Tracker timer lifecycle differs across clients')
print('PASS (offline mocks): tutorial/real drag tracker starts once on all clients; local show/hide never starts or pauses timers.')
