-- Host-only execution of the real row allocator and roster initialization.
local file = assert(io.open('cotlua/src/ui/hud/multiboard.lua', 'rb'))
local source = file:read('*a'):gsub('\r\n', '\n')
file:close()
local function section(first, last)
    local start = assert(source:find(first, 1, true))
    local finish = assert(source:find(last, start + #first, true))
    return source:sub(start, finish - 1)
end
local function run(slots, live_count)
    local env = setmetatable({}, {__index = _G})
    env.PLAYER_CAP, env.ICON_SIZE, env.User = 6, .02, {AmountPlaying = live_count}
    for _, slot in ipairs(slots) do
        env.User[slot] = {nameColored = 'player', isPlaying = true}
    end
    env.Profile, env.IS_DONATOR, env.ROW_WIDTH, env.mt = {}, {}, .3, {}
    env.FRAMEPOINT_TOPLEFT = 0
    env.BlzCreateFrameByType = function() return {} end
    env.BlzFrameSetTexture, env.BlzFrameSetSize, env.BlzFrameSetEnable = function() end, function() end, function() end
    env.BlzFrameSetText = function() end
    env.__jarray = function(value) return setmetatable({}, {__index = function() return value end}) end
    local template = assert(load(section('        local body_template = {', '        body_template.__index') ..
        '\nreturn body_template', 'real multiboard template', 't', env))()
    template.__index = template
    env.MB = {create = function(columns)
        return setmetatable({rows = {}, anchors = {}, frame = {}, columnCount = columns}, template)
    end}
    local init = section('        -- create bodies', '        -- damage log variables / functions')
    local main, boss, refresh = assert(load(init .. '\nreturn main, boss, refresh_multiboard',
        'real multiboard roster', 't', env))()
    assert(#main.rows == #slots, 'Main rows must follow the roster, not live count')
    for index = 1, #slots do
        for column = 1, 6 do assert(main:get(index, column)) end
    end
    refresh()
    local expression = assert(source:match('boss:addRows%((3 %+ #main%.rows)%)'))
    assert(load('return function(boss, main) boss:addRows(' .. expression .. ') end',
        'boss allocation', 't', env))()(boss, main)
    assert(#boss.rows == 3 + #slots, 'Boss contributor capacity must follow roster')
end
run({0}, 1)
run({0, 4}, 1) -- Departed users remain in the roster; slot gaps are valid.
run({0, 2, 5}, 0) -- Zero/stale live counter must not abort initialization.
run({}, 0)
print('PASS (offline): main and boss rows follow retained, sparse player rosters even with a stale live-player count.')
