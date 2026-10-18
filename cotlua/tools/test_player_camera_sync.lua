-- Host Lua 5.3 diagnostics only; not proof of Warcraft native/network safety.
local file = assert(io.open('cotlua/src/gameplay/world/player_camera.lua', 'rb'))
local source = file:read('*a')
file:close()
local function client(local_player, local_only, with_hero, preserve_minimap)
    local env = setmetatable({}, {__index = _G})
    local poll, trace, presentation = nil, {}, {}
    local region = {}
    env.Debug = nil
    env.OnInit = {global = function(_, callback) callback(function() end) end, final = function() end}
    env.Player, env.GetPlayerId = function(id) return id end, function(id) return id end
    env.GetLocalPlayer = function() return local_player end
    env.__jarray = function(default) return setmetatable({}, {__index = function() return default end}) end
    env.REGION_DATA = {[region] = {vision = {}, minimap = 'main.dds'}}
    env.Hero, env.ZOOM = with_hero and {[5] = {}} or {}, {}
    env.TimerQueue = {callDelayed = function() error('Camera touched shared gameplay queue') end}
    env.CreateTimer = function() trace[#trace + 1] = 'create'; return {} end
    env.TimerStart = function(_, delay, periodic, callback)
        assert(delay == .03 and periodic and not poll)
        trace[#trace + 1] = 'start'; poll = callback
    end
    env.GetCameraBoundMinX, env.GetCameraBoundMinY = function() return -10 end, function() return -20 end
    env.GetCameraBoundMaxX, env.GetCameraBoundMaxY = function() return 10 end, function() return 20 end
    env.GetCameraTargetPositionX, env.GetCameraTargetPositionY = function() return 100 end, function() return 200 end
    env.GetRectMinX, env.GetRectMinY = function() return -1000 end, function() return -2000 end
    env.GetRectMaxX, env.GetRectMaxY = function() return 1000 end, function() return 2000 end
    env.SetCameraBounds = function(...) presentation[#presentation + 1] = {kind = 'bounds', ...} end
    env.PanCameraToTimed = function(...) presentation[#presentation + 1] = {kind = 'pan', ...} end
    env.BlzChangeMinimapTerrainTex = function(...) presentation[#presentation + 1] = {kind = 'texture', ...} end
    for _, name in ipairs({'UnitAddAbility', 'UnitRemoveAbility', 'CreateUnit', 'SetUnitX', 'SetUnitY',
        'UnitDamageTarget', 'PauseTimer', 'DestroyTimer'}) do
        env[name] = function() error('Camera preview changed gameplay/native timer lifecycle: ' .. name) end
    end
    assert(load(source, 'actual player camera', 't', env))()
    local function preview(x, y)
        if not local_only or local_player == 4 then env.PreviewPlayerCamera(5, region, x, y, false, preserve_minimap) end
    end
    local function flush()
        poll(); poll()
    end
    local function pan_count()
        local count = 0
        for _, call in ipairs(presentation) do if call.kind == 'pan' then count = count + 1 end end
        return count
    end
    -- Cover synchronized requests as well as calls made only by local UI.
    preview(-270, 320)
    assert(pan_count() == 0, 'Smooth pan started before bounds correction')
    flush()
    assert(pan_count() == (local_player == 4 and 1 or 0))
    -- Back/Skip must cancel the pending pan, with local camera restoration only.
    preview(666, -543)
    env.RestorePlayerCameraPreview(5)
    local restored = pan_count()
    flush()
    assert(pan_count() == restored, 'Restored view was changed by a stale callback')
    -- Only the newest page is allowed to pan when Next is pressed rapidly.
    preview(-270, 320)
    preview(890, 887)
    local before = pan_count()
    flush()
    assert(pan_count() == before + (local_player == 4 and 1 or 0))
    if local_player == 4 then
        local last = presentation[#presentation]
        assert(last.kind == 'pan' and last[1] == 890 and last[2] == 887)
    else
        assert(#presentation == 0, 'Another player camera preview changed this client view')
    end
    env.RestorePlayerCameraPreview(5)
    if local_player == 4 then
        local textures = 0
        for _, call in ipairs(presentation) do if call.kind == 'texture' then textures = textures + 1 end end
        assert(textures == (preserve_minimap and 0 or 1), 'Unexpected minimap texture reload')
    end
    assert(table.concat(trace, ',') == 'create,start', 'Camera actions changed native timer lifecycle')
    return table.concat(trace, ',')
end
for _, local_only in ipairs({false, true}) do
    for _, with_hero in ipairs({false, true}) do
        for _, preserve_minimap in ipairs({false, true}) do
            assert(client(0, local_only, with_hero, preserve_minimap) == client(4, local_only, with_hero, preserve_minimap), 'Camera timer lifecycle differs across clients')
        end
    end
end
print('PASS (offline mocks): camera timer starts once on all clients; local preview/restore never touches shared timers, coalesces stale pans, and avoids duplicate minimap loads.')
