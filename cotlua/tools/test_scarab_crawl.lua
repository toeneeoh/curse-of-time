-- Offline native mocks; this does not establish WC3 pathing/camera visuals.
local host = _G
local env = setmetatable({}, {__index = function(_, key)
    assert(key ~= 'BlzRemoveEffect', 'Optional native lookup triggered strict-global logging')
    return host[key]
end})
env._G = env
local _ENV = env
local function load_source(path)
    local file = assert(io.open(path, 'rb')); local source = file:read('*a'); file:close()
    assert(load(source, path, 't', env))()
end
OnInit = {global = function(_, callback) callback(function() end) end,
    final = function(_, callback) callback(function() end) end}
load_source('cotlua/src/gameplay/world/scarab_layout.lua')
local function fingerprint(graph)
    local result = {}
    for _, room in ipairs(graph.rooms) do
        result[#result + 1] = room.x .. ':' .. room.y .. ':' .. room.seed
        for _, d in ipairs(ScarabLayout.directions) do result[#result + 1] = tostring(room.doors[d[1]]) end
    end
    return table.concat(result, '|')
end
for seed = 1, 200 do
    local graph = ScarabLayout.generate(seed)
    assert(#graph.rooms == 12 and fingerprint(graph) == fingerprint(ScarabLayout.generate(seed)))
    local visited, queue, index = {[1] = true}, {1}, 1
    while index <= #queue do
        local room = graph.rooms[queue[index]]; index = index + 1
        for _, d in ipairs(ScarabLayout.directions) do
            local id = room.doors[d[1]]
            if id then
                local neighbor = graph.rooms[id]
                assert(neighbor.doors[d[4]] == room.id and neighbor.x == room.x + d[2] and neighbor.y == room.y + d[3])
                if not visited[id] then visited[id] = true; queue[#queue + 1] = id end
            end
        end
        local shape = ScarabLayout.chamber(room)
        local floor_seen, tiles, cursor = {[25 * 41 - 20] = true}, {25 * 41 - 20}, 1
        while cursor <= #tiles do
            local tile = tiles[cursor]; cursor = cursor + 1
            for _, offset in ipairs({-1, 1, -41, 41}) do
                local next_tile = tile + offset
                if shape.floor[next_tile] and not floor_seen[next_tile] then
                    floor_seen[next_tile] = true; tiles[#tiles + 1] = next_tile
                end
            end
        end
        for tile in pairs(shape.floor) do assert(floor_seen[tile], 'Disconnected chamber floor') end
        for _, portal in pairs(shape.portals) do assert(floor_seen[(portal.y - 1) * 41 + portal.x]) end
    end
    assert(#queue == #graph.rooms)
end
assert(fingerprint(ScarabLayout.generate(1)) ~= fingerprint(ScarabLayout.generate(2)))
for _, slot in ipairs(ScarabLayout.buffers()) do
    assert(slot.x - 41 * 32 >= -29024, 'West room buffer did not move inward')
    assert(slot.x - 41 * 32 >= -30000 and slot.x + 41 * 32 <= -20000)
    assert(slot.y - 49 * 32 >= 20000 and slot.y + 49 * 32 <= 30000)
end
local buffers = ScarabLayout.buffers()
for index, slot in ipairs(buffers) do
    for other = 1, index - 1 do
        assert(math.abs(slot.x - buffers[other].x) >= 41 * 64 or math.abs(slot.y - buffers[other].y) >= 49 * 64,
            'Inward-shifted physical room buffers overlap')
    end
end
print('PASS: 200 reproducible connected room graphs, reciprocal exits, reachable generated floors, and six buffers inside the allocated corner.')
PLAYER_CAP, PATHING_TYPE_WALKABILITY, PATHING_TYPE_FLYABILITY = 6, 'walk', 'fly'
FourCC = function(value) return value end
UNIT_RF_SIGHT_RADIUS = 'sight'
BlzGetUnitRealField = function(unit) return unit.sight or 1800 end
BlzSetUnitRealField = function(unit, _, value) unit.sight = value end
local lighting = {}
SetPlayerLightingOverride = function(pid, model) lighting[pid] = model end
SetTerrainType = function() error('Room transitions must not repaint terrain textures') end
local delayed, periodic, cleanup, pathing, baseline = {}, nil, {}, {}, {}
local native_calls, effects, destroyed, restored_camera = 0, 0, 0, 0
TimerQueue = {callDelayed = function(_, _, callback, ...) delayed[#delayed + 1] = {callback, {...}} end,
    callPeriodically = function(_, _, _, callback) periodic = callback end}
local function drain()
    local ticks = 0
    while #delayed > 0 do
        local writes = native_calls
        local job = table.remove(delayed, 1); job[1](table.unpack(job[2]))
        assert(native_calls - writes <= 512, 'Native pathing budget exceeded in one callback')
        ticks = ticks + 1; assert(ticks < 2000)
    end
end
Hero, Backpack, REGION_DATA = {}, {}, {}
for pid = 1, 6 do Hero[pid] = {x = pid * 100, y = 100, alive = true} end
Player, GetUnitX, GetUnitY = function(id) return id end, function(u) return u.x end, function(u) return u.y end
UnitAlive = function(u) return u and u.alive end
DisplayTimedTextToPlayer = function() end
MoveHero = function(pid, x, y) Hero[pid].x, Hero[pid].y = x, y end
SetUnitXBounded, SetUnitYBounded = function(u, x) u.x = x end, function(u, y) u.y = y end
Rect = function(a, b, c, d) return {a, b, c, d} end
SetRect = function(rect, a, b, c, d) assert(a < c and b < d); rect[1], rect[2], rect[3], rect[4] = a, b, c, d end
RemoveRect = function(rect) rect.removed = true end
RectContainsCoords = function(r, x, y) return x >= r[1] and y >= r[2] and x <= r[3] and y <= r[4] end
PreviewPlayerCamera = function(_, rect)
    assert(not rect.removed)
    local data = REGION_DATA[rect]
    assert(data.hide_minimap and not data.minimap and data.vision ~= rect)
    assert(data.vision[1] > rect[1] and data.vision[3] < rect[3])
end
RestorePlayerCameraPreview = function() restored_camera = restored_camera + 1 end
local function key(x, y, kind) return x .. '/' .. y .. '/' .. kind end
IsTerrainPathable = function(x, y, kind)
    local k = key(x, y, kind)
    if pathing[k] == nil then pathing[k] = kind == 'walk'; baseline[k] = pathing[k] end
    return not pathing[k]
end
SetTerrainPathable = function(x, y, kind, flag)
    assert(x >= -30000 and x <= -20000 and y >= 20000 and y <= 30000)
    native_calls = native_calls + 1; pathing[key(x, y, kind)] = flag
end
AddSpecialEffect = function(model)
    assert(model == 'Doodads\\LordaeronSummer\\Rocks\\Lords_Rock\\Lords_Rock0.mdx' or model == 'LightYellow30.mdx')
    effects = effects + 1; return {model = model}
end
AddSpecialEffectTarget = AddSpecialEffect
DestroyEffect = function(effect) assert(not effect.destroyed); effect.destroyed = true; destroyed = destroyed + 1 end
BlzSetSpecialEffectAlpha = function(effect, alpha) assert(alpha == 0); effect.hidden = true end
BlzSetSpecialEffectZ = function(effect, z) assert(z == -10000); effect.buried = true end
BlzRemoveEffect = function(effect) DestroyEffect(effect) end
BlzSetSpecialEffectScale, BlzSetSpecialEffectYaw = function(_, scale) assert(scale == 1.7) end, function() end
EVENT_ON_CLEANUP = {register_action = function(_, pid, callback) cleanup[pid] = callback end}
load_source('cotlua/src/gameplay/world/scarab_crawl.lua')
assert(native_calls == 0 and effects == 0 and not ScarabCrawl.enter(1, 1), 'Startup or unprepared area changed the map')
assert(ScarabCrawl.setPrepared(true))
assert(not ScarabCrawl.enter(1, math.huge))
assert(ScarabCrawl.enter(1, 1)); drain()
assert(effects == #ScarabLayout.chamber(ScarabLayout.generate(1).rooms[1]).walls,
    'Some collision boundary cells have no visible rock')
assert(Hero[1].sight == 192 and lighting[1] == 'blacklight.mdx')
assert(ScarabCrawl.setLamp(1, true)); assert(Hero[1].sight == 700)
assert(ScarabCrawl.setLamp(1)); assert(Hero[1].sight == 192)
local first_x, first_y = Hero[1].x, Hero[1].y
assert(ScarabCrawl.enter(2, 999)); drain()
assert(Hero[2].x == first_x and Hero[2].y == first_y, 'Players joining one logical room got different physical rooms')
local graph = ScarabLayout.generate(1)
local function route_to(from, target)
    local queue, seen, index = {{from, {}}}, {[from] = true}, 1
    while index <= #queue do
        local entry = queue[index]; index = index + 1
        if entry[1] == target then return entry[2] end
        for _, d in ipairs(ScarabLayout.directions) do
            local id = graph.rooms[entry[1]].doors[d[1]]
            if id and not seen[id] then
                seen[id] = true; local path = {}; for i, step in ipairs(entry[2]) do path[i] = step end
                path[#path + 1] = d[1]; queue[#queue + 1] = {id, path}
            end
        end
    end
    error('Unreachable test target')
end
for pid = 1, 6 do
    if pid > 2 then assert(ScarabCrawl.enter(pid, 1)); drain() end
    for _, step in ipairs(route_to(1, pid + 1)) do assert(ScarabCrawl.travel(pid, step)); drain() end
end
local occupied = {}
for _, hero in pairs(Hero) do
    local k = hero.x .. ':' .. hero.y; assert(not occupied[k]); occupied[k] = true
end
for _, step in ipairs(route_to(2, 8)) do assert(ScarabCrawl.travel(1, step)); drain() end
assert(ScarabCrawl.leave(2)); assert(Hero[2].x == 200 and Hero[2].y == 100)
ScarabCrawl.stop()
assert(not ScarabCrawl.enter(1, 2), 'Run started during asynchronous restoration')
drain()
for k, original in pairs(baseline) do assert(pathing[k] == original, 'Pathing baseline was not restored') end
for pid = 1, 6 do
    assert(Hero[pid].x == pid * 100 and Hero[pid].y == 100 and Hero[pid].sight == 1800 and not lighting[pid])
end
assert(effects == destroyed and not next(REGION_DATA) and restored_camera >= 6)
-- Older installations: hide the model before its ordinary death animation.
BlzRemoveEffect = nil
local destroy_native = DestroyEffect
DestroyEffect = function(effect) assert(effect.hidden and effect.buried); destroy_native(effect) end
load_source('cotlua/src/gameplay/world/scarab_crawl.lua')
assert(ScarabCrawl.setPrepared(true))
local before = native_calls
assert(ScarabCrawl.enter(1, 2)); drain()
local initial_writes = native_calls - before
local first_room = ScarabLayout.generate(2).rooms[1]
local exit
for direction in pairs(first_room.doors) do exit = direction; break end
before = native_calls
assert(ScarabCrawl.travel(1, exit)); drain()
assert(native_calls - before < initial_writes / 2, 'Recycling rewrote unchanged pathing')
ScarabCrawl.stop(); drain()
assert(effects == destroyed)
assert(ScarabCrawl.enter(1, 2)); ScarabCrawl.stop(); drain()
assert(Hero[1].x == 100, 'Stale build moved a player after stop')
assert(ScarabCrawl.enter(1, 3)); Hero[1].alive = false; periodic(); drain(); ScarabCrawl.stop(); drain()
Hero[1].alive = true
print('PASS (mocked natives): bounded delta pathing, no tile repainting, standard rock palette, silent optional native detection, camera/minimap/lamp cleanup, exact pathing restoration, immediate/fallback removal, and interrupted builds.')
