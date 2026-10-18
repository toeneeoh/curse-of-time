-- Offline Lua 5.3 callback checks, not proof of Warcraft native/network safety.
local function read(path)
    local file = assert(io.open('cotlua/src/' .. path, 'rb'))
    local source = file:read('*a'):gsub('\r\n', '\n')
    file:close()
    return source
end
local function excerpt(source, first, last)
    local start = assert(source:find(first, 1, true))
    local finish = assert(source:find(last, start, true))
    return source:sub(start, finish - 1)
end
local button_code = excerpt(read('framework/ui/glue_button.lua'),
    '        function thistype.uiTime()', '        function thistype.onClicked()')
local shop_code = excerpt(read('ui/shop/shop.lua'),
    '        function thistype.onScroll() --shop', '        function thistype.onSelect()')
local function replay(local_player)
    local env = setmetatable({}, {__index = _G})
    local now, button_calls, shop_calls = 0, 0, 0
    local frame, clock = {}, {}
    env.SCROLL_DELAY = .01
    env.GetLocalPlayer = function() return local_player end
    env.GetTriggerPlayer = function() return 4 end
    env.GetPlayerId = function(player) return player end
    env.BlzGetTriggerFrame = function() return frame end
    env.BlzGetTriggerFrameValue = function() return -1 end
    env.TimerGetElapsed = function(timer) assert(timer == clock); return now end
    for _, name in ipairs({'CreateTimer', 'TimerStart', 'PauseTimer', 'DestroyTimer', 'CreateTrigger', 'Condition'}) do
        env[name] = function() error('Local scroll touched native lifecycle: ' .. name) end
    end
    env.TimerQueue = {callDelayed = function() error('Local scroll touched the shared queue') end}
    env.thistype = {double = clock, scrollReadyAt = {}, table = {[frame] = {scroll = {}}}}
    env.TriggerEvaluate = function(trigger)
        assert(trigger == env.thistype.table[frame].scroll)
        button_calls = button_calls + 1
    end
    assert(load(button_code, 'actual button scroll callback', 't', env))()
    local button = env.thistype
    button.onScrolled()
    now = .001; button.onScrolled()
    now = .011; button.onScrolled()
    assert(button_calls == (local_player == 4 and 2 or 0))
    local shop_env = setmetatable({Button = button, thistype = {scrollReadyAt = {}}}, {__index = env})
    shop_env.registry = {[frame] = {[0] = {scroll = function(_, down)
        assert(down); shop_calls = shop_calls + 1
    end}}}
    assert(load(shop_code, 'actual shop scroll callback', 't', shop_env))()
    now = 1; shop_env.thistype.onScroll()
    now = 1.001; shop_env.thistype.onScroll()
    now = 1.011; shop_env.thistype.onScroll()
    assert(shop_calls == (local_player == 4 and 2 or 0))
    assert(not button.timer and not shop_env.thistype.timer)
end
replay(0)
replay(4)
print('PASS (offline callbacks): local button/shop scrolling throttles without allocating, starting or pausing timers or touching TimerQueue.')
