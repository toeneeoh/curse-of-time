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
load_source('cotlua/src/gameplay/dungeons/scarab/layout.lua')
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
    assert(#graph.rooms == 32 and fingerprint(graph) == fingerprint(ScarabLayout.generate(seed)))
    assert(graph.approach ~= graph.start and graph.approach == ScarabLayout.generate(seed).approach)
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
        local encounter = ScarabLayout.encounter(room, shape)
        local repeated = ScarabLayout.encounter(room, shape)
        assert(#encounter == #repeated and #encounter <= 12)
        if room.id == 1 then assert(#encounter == 0) else assert(#encounter > 0, 'Empty combat chamber') end
        for index, enemy in ipairs(encounter) do
            local same = repeated[index]
            assert(enemy.x == same.x and enemy.y == same.y and enemy.role == same.role and enemy.facing == same.facing)
            for dy = -1, 1 do for dx = -1, 1 do
                assert(shape.floor[(enemy.y + dy - 1) * shape.width + enemy.x + dx], 'Enemy placed in a wall/narrow passage')
            end end
            for _, portal in pairs(shape.portals) do
                assert((enemy.x - portal.x)^2 + (enemy.y - portal.y)^2 >= 7^2, 'Enemy blocks a door mouth')
            end
        end
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
    local deepest = 0
    for _, room in ipairs(graph.rooms) do deepest = math.max(deepest, room.distance) end
    assert(graph.rooms[graph.approach].distance >= deepest - 1, 'Approach was placed near the entrance')
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
print('PASS: 200 reproducible graphs/encounter plans, clear spawn footprints and door mouths, reachable floors, and six buffers in the allocated corner.')
PLAYER_CAP, PATHING_TYPE_WALKABILITY, PATHING_TYPE_FLYABILITY = 6, 'walk', 'fly'
FourCC = function(value) return value end
UNIT_RF_SIGHT_RADIUS = 'sight'
UNIT_RF_FOG_OF_WAR_SAMPLE_RADIUS = 'fog_sample'
local fog_enabled, fog_mask_enabled = true, true
IsFogEnabled = function() return fog_enabled end
IsFogMaskEnabled = function() return fog_mask_enabled end
UNIT_RF_ACQUISITION_RANGE, UNIT_WEAPON_RF_ATTACK_RANGE = 'acquisition', 'range'
BlzGetUnitRealField = function(unit, field) return unit[field] or (field == 'sight' and 1800 or 0) end
BlzSetUnitRealField = function(unit, field, value) assert(field, 'Undefined unit real field'); unit[field] = value end
local lighting = {}
SetPlayerLightingOverride = function(pid, model) lighting[pid] = model end
SetTerrainType = function() error('Room transitions must not repaint terrain textures') end
local delayed, periodic, cleanup, pathing, baseline = {}, nil, {}, {}, {}
local native_calls, effects, destroyed, restored_camera = 0, 0, 0, 0
local rock_positions = {}
TimerQueue = {callDelayed = function(_, _, callback, ...) delayed[#delayed + 1] = {callback, {...}} end,
    callPeriodically = function(_, _, _, callback) periodic = callback end}
local clocks = {}
Stopwatch = {create = function()
    local watch = {getElapsed = function() return 75 end, destroy = function(self) self.destroyed = true end}
    clocks[#clocks + 1] = watch
    return watch
end}
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
local crawl_messages = {}
DisplayTimedTextToPlayer = function(_, _, _, _, text) crawl_messages[#crawl_messages + 1] = text end
MoveHero = function(pid, x, y) Hero[pid].x, Hero[pid].y = x, y end
SetUnitXBounded, SetUnitYBounded = function(u, x) u.x = x end, function(u, y) u.y = y end
Rect = function(a, b, c, d) return {a, b, c, d} end
SetRect = function(rect, a, b, c, d) assert(a < c and b < d); rect[1], rect[2], rect[3], rect[4] = a, b, c, d end
RemoveRect = function(rect) rect.removed = true end
RectContainsCoords = function(r, x, y) return x >= r[1] and y >= r[2] and x <= r[3] and y <= r[4] end
PreviewPlayerCamera = function(_, rect, _, _, instant)
    assert(instant == true, 'Scarab traversal must request an instant camera snap')
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
AddSpecialEffect = function(model, x, y)
    assert(model == 'Doodads\\LordaeronSummer\\Rocks\\Lords_Rock\\Lords_Rock0.mdx' or model == 'LightYellow30.mdx')
    if model:find('Lords_Rock', 1, true) then rock_positions[#rock_positions + 1] = {x = x, y = y} end
    effects = effects + 1; return {model = model}
end
AddSpecialEffectTarget = AddSpecialEffect
DestroyEffect = function(effect) assert(not effect.destroyed); effect.destroyed = true; destroyed = destroyed + 1 end
BlzSetSpecialEffectAlpha = function(effect, alpha) assert(alpha == 0); effect.hidden = true end
BlzSetSpecialEffectZ = function(effect, z) assert(z == -10000); effect.buried = true end
BlzRemoveEffect = function(effect) DestroyEffect(effect) end
BlzSetSpecialEffectScale, BlzSetSpecialEffectYaw = function(_, scale) assert(scale == 1.49) end, function() end
local enemy_units, death_callbacks = {}, {}
PLAYER_CREEP, ORDER_ID_STOP = 'creeps', 'stop'
Unit = setmetatable({}, {__index = function(t, unit)
    -- Proxy assignments must update native health in this mock too.
    local proxy = {bonus_hp = 0, bonus_damage = 0, unit = unit}
    local data = setmetatable({}, {__index = proxy, __newindex = function(_, field, value)
        proxy[field] = value
        if field == 'bonus_hp' then unit.max_hp = 100 + value end
        if field == 'base_bat' then unit.attack_time = value end
        if field == 'ms_flat' then unit.speed = value end
    end})
    rawset(t, unit, data); return data
end})
CreateUnit = function(owner, id, x, y, facing)
    assert(owner == PLAYER_CREEP and (id == 'n0sl' or id == 'n0ss'))
    local unit = {x = x, y = y, facing = facing, alive = true, max_hp = 100, life = 100, pathing = true}
    enemy_units[#enemy_units + 1] = unit
    return unit
end
BlzCreateUnitWithSkin = function(owner, id, x, y, facing, skin)
    assert(skin == 'u002', 'Encounter still uses a spider skin')
    local unit = CreateUnit(owner, id, x, y, facing)
    unit.skin = skin
    return unit
end
BlzGetUnitMaxHP, GetWidgetLife = function(unit) return unit.max_hp end, function(unit) return unit.life end
BlzGetUnitBaseDamage = function() return 10 end
SetWidgetLife = function(unit, life) unit.life = life end
BlzSetUnitName = function(unit, name) unit.name = name end
SetUnitScale = function(unit, scale) unit.scale = scale end
ARMOR_CHAOS, ATTACK_CHAOS = 6, 5
UNIT_IF_DEFENSE_TYPE, UNIT_WEAPON_IF_ATTACK_ATTACK_TYPE = 'defense', 'attack_type'
BlzSetUnitIntegerField = function(unit, field, value) unit[field] = value end
BlzSetUnitWeaponIntegerField = function(unit, field, _, value) unit[field] = value end
BlzSetUnitWeaponRealField = function(unit, field, _, value) unit[field] = value end
UNIT_WEAPON_SF_ATTACK_PROJECTILE_ART = 'projectile'
BlzSetUnitWeaponStringField = function(unit, field, _, value)
    assert(field == 'projectile' and value == 'Abilities\\Weapons\\ChimaeraAcidMissile\\ChimaeraAcidMissile.mdl')
    unit[field] = value
end
BlzSetUnitArmor = function(unit, armor) unit.armor = armor end
BlzSetUnitAttackCooldown = function(unit, cooldown) unit.attack_time = cooldown end
SetUnitMoveSpeed = function(unit, speed) unit.speed = speed end
SetUnitPathing = function(unit, enabled) unit.pathing = enabled end
IssueImmediateOrderById = function(unit, order) unit.order = order end
RemoveUnit = function(unit) assert(not unit.removed); unit.removed, unit.alive = true, false end
EVENT_ON_UNIT_DEATH = {
    register_unit_action = function(_, unit, callback) death_callbacks[unit] = callback end,
    unregister_unit_action = function(_, unit, callback)
        assert(death_callbacks[unit] == callback); death_callbacks[unit] = nil
    end
}
EVENT_ON_CLEANUP = {register_action = function(_, pid, callback) cleanup[pid] = callback end}
SetUnitCreepGuard, RemoveGuardPosition = function() end, function() end
UnitAddAbility = function(u, id) u.abilities = u.abilities or {}; u.abilities[id] = true end
GetUnitAbilityLevel = function(u, id) return u.abilities and u.abilities[id] and 1 or 0 end
GetUnitCurrentOrder = function(u) return u.order or 0 end
GetOwningPlayer, IsUnitVisible = function() return PLAYER_CREEP end, function() return true end
ORDER_ID_ATTACK, ORDER_ID_SMART, ABIL_AVUL = 'attack', 'smart', 'invulnerable'
IssueTargetOrder = function(u, order, target) u.order, u.target = order, target end
IssueImmediateOrder = function(u) u.order = 0 end
load_source('cotlua/src/gameplay/dungeons/scarab/combat.lua')
load_source('cotlua/src/gameplay/dungeons/scarab/crawl.lua')
assert(native_calls == 0 and effects == 0 and not ScarabCrawl.enter(1, 1), 'Startup or unprepared area changed the map')
assert(ScarabCrawl.setPrepared(true))
local kit_owner = {}
assert(ScarabCrawl.reserveArea(kit_owner))
assert(not ScarabCrawl.canStart() and not ScarabCrawl.enter(1,1))
assert(not ScarabCrawl.setPrepared(false) and not ScarabCrawl.reserveArea({}))
assert(not ScarabCrawl.releaseArea({}))
assert(ScarabCrawl.releaseArea(kit_owner) and ScarabCrawl.canStart())
assert(not ScarabCrawl.enter(1, math.huge))
assert(ScarabCrawl.enter(1, 1)); drain()
assert(ScarabCrawl.status():find('Visited 1/32', 1, true) and ScarabCrawl.status():find('1:15', 1, true))
assert(#enemy_units == 0, 'Entrance chamber must be safe')
assert(effects == #ScarabLayout.chamber(ScarabLayout.generate(1).rooms[1]).walls,
    'Some collision boundary cells have no visible rock')
assert(Hero[1].sight == 192 and lighting[1] == 'blacklight.mdx')
assert(ScarabCrawl.setLamp(1, true)); assert(Hero[1].sight == 384)
assert(ScarabCrawl.visibility(1):find('Lamp ON | Intended sight 384 | Native sight 384', 1, true))
assert(ScarabCrawl.setLamp(1)); assert(Hero[1].sight == 192)
local first_x, first_y = Hero[1].x, Hero[1].y
for index, wall in ipairs(ScarabLayout.chamber(ScarabLayout.generate(1).rooms[1]).walls) do
    assert(rock_positions[index].x == first_x + (wall.x - 21) * 64 + wall.nx * 48)
    assert(rock_positions[index].y == first_y + (wall.y - 25) * 64 + wall.ny * 48)
end
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
for _, unit in ipairs(enemy_units) do assert(unit.removed and not death_callbacks[unit], 'Leaked encounter unit/callback') end
-- Older installations: hide the model before its ordinary death animation.
BlzRemoveEffect = nil
local destroy_native = DestroyEffect
DestroyEffect = function(effect) assert(effect.hidden and effect.buried); destroy_native(effect) end
load_source('cotlua/src/gameplay/dungeons/scarab/crawl.lua')
assert(ScarabCrawl.setPrepared(true))
local before = native_calls
fog_enabled = false
local messages_before = #crawl_messages
assert(ScarabCrawl.enter(1, 2)); drain()
local warned = false
for i = messages_before + 1, #crawl_messages do
    if crawl_messages[i]:find('Use -novision', 1, true) then warned = true end
end
assert(warned and not fog_enabled and fog_mask_enabled,
    'Disabled fog must warn without changing global visibility for other players')
fog_enabled = true
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
assert(ScarabCrawl.enter(1, 2))
assert(not ScarabCrawl.setEncounters(false), 'Live encounters can be toggled away')
local before_spawn = #enemy_units
assert(ScarabCrawl.travel(1, exit))
assert(#delayed == 0, 'Room transition queued artificial build delays')
local pack_count = #enemy_units - before_spawn
assert(pack_count >= 2 and pack_count <= 12)
assert(ScarabCrawl.setLamp(1, true))
local saved_positions = {}
for index = before_spawn + 1, #enemy_units do
    local u = enemy_units[index]
    saved_positions[u] = {u.x, u.y}
    u.x, u.y = Hero[1].x + 1000, Hero[1].y
end
local probe = enemy_units[before_spawn + 1]
probe.x, probe.fog_sample = Hero[1].x + 500, 64
local visible_native = IsUnitVisible
IsUnitVisible = function(unit) return unit ~= probe end
local visibility_report = ScarabCrawl.visibility(1)
assert(visibility_report:find('Distance 500 | OUTSIDE sight radius | HIDDEN | Fog sample 64', 1, true),
    'Visibility diagnostics must report actual distance and native visibility separately')
IsUnitVisible = visible_native
for u, position in pairs(saved_positions) do u.x, u.y = position[1], position[2] end
for index = before_spawn + 1, #enemy_units do
    local unit = enemy_units[index]
    assert(unit.defense == ARMOR_CHAOS and unit.attack_type == ATTACK_CHAOS and unit.armor >= 550)
    assert(unit.max_hp >= 40000000 and Unit[unit].dr == .9 and unit.pathing)
    if unit.name == 'Scarab Broodling' then
        assert(unit.pathing and unit.speed == 340 and unit.range == 90 and unit.abilities.Aeth)
    end
    assert(Unit[unit].regen_flat == 0)
end
local killed, wounded = enemy_units[before_spawn + 1], enemy_units[before_spawn + 2]
killed.alive, killed.life = false, 0
death_callbacks[killed](); death_callbacks[killed]() -- Duplicate dispatch is harmless.
assert(killed.pathing == false)
wounded.life = wounded.max_hp * .25
local home_x, home_y = wounded.x, wounded.y
wounded.x, wounded.y = 0, 0; periodic()
assert(wounded.x == home_x and wounded.y == home_y and wounded.order == ORDER_ID_STOP, 'Enemy escaped staging room')
local opposite
for _, direction in ipairs(ScarabLayout.directions) do if direction[1] == exit then opposite = direction[4] end end
assert(ScarabCrawl.travel(1, opposite))
local revisit_start = #enemy_units
assert(ScarabCrawl.travel(1, exit))
assert(#enemy_units - revisit_start == pack_count - 1, 'Killed enemy respawned on revisit')
assert(enemy_units[revisit_start + 1].life == enemy_units[revisit_start + 1].max_hp * .25,
    'Survivor healed when physical buffer was recycled')
local joined_start = #enemy_units
assert(ScarabCrawl.enter(2, 2)); assert(ScarabCrawl.travel(2, exit))
assert(#enemy_units == joined_start, 'Joining an occupied room duplicated its enemies')
assert(Unit[enemy_units[revisit_start + 1]].dr == .8, 'Joining player did not apply Naga-style party resistance')
assert(Unit[enemy_units[revisit_start + 1]].bonus_damage >= 500000 - 10, 'Joining player did not increase party damage')
assert(enemy_units[revisit_start + 1].life == enemy_units[revisit_start + 1].max_hp * .25, 'Scaling healed survivor')
assert(ScarabCrawl.leave(2))
assert(Unit[enemy_units[revisit_start + 1]].dr == .8, 'Leaving reduced established run difficulty')
ScarabCrawl.stop(); drain()
for _, unit in ipairs(enemy_units) do assert(unit.removed and not death_callbacks[unit]) end
assert(ScarabCrawl.status() == 'No active Scarab crawl.')
for _, clock in ipairs(clocks) do assert(clock.destroyed, 'Run stopwatch leaked') end
assert(ScarabCrawl.setEncounters(false))
assert(ScarabCrawl.enter(1, 2)); assert(ScarabCrawl.travel(1, exit))
assert(#enemy_units == joined_start, 'Geometry-only mode spawned enemies')
graph = ScarabLayout.generate(2)
for _, step in ipairs(route_to(first_room.doors[exit], graph.approach)) do assert(ScarabCrawl.travel(1, step)) end
assert(ScarabCrawl.status():find('Approach found at 75s', 1, true), 'Approach discovery/timing not recorded')
ScarabCrawl.stop(); drain()
for _, clock in ipairs(clocks) do assert(clock.destroyed, 'Stopwatch survived stop') end
print('PASS: immediate transitions, safe entrance, shared encounters, persistent kills/health, buffer leashing, cleanup, and geometry-only mode.')
print('PASS (mocked natives): bounded delta pathing, no tile repainting, standard rock palette, silent optional native detection, camera/minimap/lamp cleanup, exact pathing restoration, immediate/fallback removal, and interrupted builds.')
