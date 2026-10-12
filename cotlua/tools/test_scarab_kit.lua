-- Offline native mocks only; seams and model rendering still need in-game tests.
OnInit = {global = function(_,cb) cb(function() end) end,final = function(_,cb) cb(function() end) end}
dofile('cotlua/src/gameplay/dungeons/scarab/layout.lua')
dofile('cotlua/src/gameplay/dungeons/scarab/kit_assets.lua')
dofile('cotlua/src/gameplay/dungeons/scarab/kit_render_assets.lua')
dofile('cotlua/src/gameplay/dungeons/scarab/kit_geometry.lua')
for _,scale in ipairs({.75,1,1.25,1.5,1.75}) do
    local plan = ScarabKitGeometry.assemble(scale)
    assert(#plan.pieces == 9 and #plan.triangles > 200)
    assert(#plan.render > 800 and #plan.render < 1200)
    assert(plan.bounds[1] > -30000 and plan.bounds[3] < -20000)
    assert(plan.bounds[2] > 20000 and plan.bounds[4] < 30000)
    assert(ScarabKitGeometry.contains(plan,plan.x,plan.y))
    assert(not ScarabKitGeometry.exterior(plan,plan.x,plan.y,16))
    assert(ScarabKitGeometry.exterior(plan,plan.bounds[1]-64,plan.bounds[2]-64,16))
    assert(not ScarabKitGeometry.contains(plan,plan.bounds[1]-32,plan.bounds[2]-32))
    local junction,chamber = plan.pieces[6],plan.pieces[7]
    local jx,jy = ScarabKitGeometry.transform(junction,0,442.914)
    local hx,hy = ScarabKitGeometry.transform(chamber,8.962,-460.316)
    assert(math.abs(jx-hx) < .001 and math.abs(jy-hy-4*scale) < .001,'Wide chamber seam overlap changed')
    for distance = -20,20,4 do
        assert(ScarabKitGeometry.contains(plan,jx,jy+distance*scale),'Disconnected wide chamber seam')
    end
    -- Every socket seam and nearby passage must lie inside the union of floors.
    for _,piece in ipairs(plan.pieces) do
        local x,y = ScarabKitGeometry.transform(piece,0,100)
        if piece.kind == 'a' or piece.kind == 'b' or piece.kind == 'c' or piece.kind == 'D' then
            assert(ScarabKitGeometry.contains(plan,x,y),'Missing tunnel floor')
        end
    end
    local a = plan.pieces[2]
    for distance = -20,20,4 do
        local x,y = ScarabKitGeometry.transform(a,.634,-295.275+distance)
        assert(ScarabKitGeometry.contains(plan,x,y),'Disconnected start seam')
    end
end
local queue = {}
TimerQueue = {callDelayed = function(_,_,cb,...) queue[#queue+1] = {cb,...} end}
local function drain(until_ready)
    for _ = 1,8000 do
        if until_ready and (ScarabKitPreview.status():find('ready,',1,true) or ScarabKitPreview.status():find('| ready',1,true)) then return end
        if #queue == 0 then return end
        local call = table.remove(queue,1); call[1](table.unpack(call,2))
    end
    error('Unexpected persistent timer')
end
-- Pure seeded chamber generation: stable recipes, reachable mouths and buffers
-- that remain separated after adding the wider preview sight margin.
local recipes = {}
for seed = 1,30 do
    local graph = ScarabLayout.generate(seed,8)
    for _,room in ipairs(graph.rooms) do
        local p = ScarabKitGeometry.assemble(1.5,room,-27500,25000)
        assert(p.bounds[1]-656 > -30000 and p.bounds[3]+656 < -25000,'Seeded rooms overlap physical buffers')
        assert(p.bounds[2]-656 > 20000 and p.bounds[4]+656 < 30000)
        assert(ScarabKitGeometry.contains(p,p.x,p.y),'Seeded hub spawn is blocked')
        for _,d in ipairs(ScarabLayout.directions) do
            local port = p.portals[d[1]]
            assert((port ~= nil) == (room.doors[d[1]] ~= nil),'Recipe lost a logical exit')
            if port then
                assert(ScarabKitGeometry.contains(p,port.x,port.y),'Exit ring is off floor')
                assert(ScarabKitGeometry.contains(p,port.spawn_x,port.spawn_y),'Arrival is off floor')
            end
        end
        if seed <= 3 then
            local function cell(v) return math.floor(v/32)*32+16 end
            local function key(x,y) return x..':'..y end
            local frontier = {{cell(p.x),cell(p.y)}}
            local reached = {[key(frontier[1][1],frontier[1][2])] = true}
            local cursor = 1
            while cursor <= #frontier do
                local c = frontier[cursor]; cursor = cursor+1
                for _,delta in ipairs({{32,0},{-32,0},{0,32},{0,-32}}) do
                    local x,y = c[1]+delta[1],c[2]+delta[2]
                    if not reached[key(x,y)] and ScarabKitGeometry.contains(p,x,y)
                        and ScarabKitGeometry.contains(p,x-16,y) and ScarabKitGeometry.contains(p,x+16,y)
                        and ScarabKitGeometry.contains(p,x,y-16) and ScarabKitGeometry.contains(p,x,y+16) then
                        reached[key(x,y)] = true; frontier[#frontier+1] = {x,y}
                    end
                end
            end
            for _,port in pairs(p.portals) do
                assert(reached[key(cell(port.x),cell(port.y))],'Seeded exit raster is disconnected')
                assert(reached[key(cell(port.spawn_x),cell(port.spawn_y))],'Seeded arrival raster is disconnected')
            end
        end
        local function recipe(plan)
            local values = {}
            for _,piece in ipairs(plan.pieces) do values[#values+1] = piece.kind..':'..string.format('%.2f:%.2f:%.2f',piece.x,piece.y,piece.angle) end
            return table.concat(values,'|')
        end
        local key = recipe(p)
        assert(key == recipe(ScarabKitGeometry.assemble(1.5,room,-27500,25000)),'Seed is not reproducible')
        recipes[key] = true
    end
end
local recipe_count = 0
for _ in pairs(recipes) do recipe_count = recipe_count+1 end
assert(recipe_count > 25,'Seeded chambers lack variation')
local owner, writes, effects, removed = nil,0,0,0
ScarabCrawl = {
    vision = {dark = 192,lamp = 384},art = {lamp = 'LightYellow30.mdx'},
    reserveArea = function(state) if owner then return false,'occupied' end owner = state; return true end,
    releaseArea = function(state) assert(owner == state); owner = nil end,
}
PATHING_TYPE_WALKABILITY,PATHING_TYPE_FLYABILITY = 1,2
PLAYER_CAP = 2
Hero = {{x = 100,y = 200,alive = true,sight = 1800}}
Backpack = {{x = 110,y = 220,sight = 900}}
Hero[2] = {x = 300,y = 400,alive = true,sight = 1600}
Backpack[2] = {x = 310,y = 420,sight = 800}
UNIT_RF_SIGHT_RADIUS = 'sight'
BlzGetUnitRealField = function(u,field) return u[field] end
BlzSetUnitRealField = function(u,field,value) u[field] = value end
local lighting
SetPlayerLightingOverride = function(_,value) lighting = value end
IsFogEnabled = function() return true end
IsFogMaskEnabled = function() return true end
Unit = {[Hero[1]] = {busy = false}}
Unit[Hero[2]] = {busy = false}
IsUnitPaused = function(u) return u.paused == true end
PauseUnit = function(u,value) u.paused = value end
REGION_DATA = {}
UnitAlive = function(u) return u.alive end
GetUnitX = function(u) return u.x end
GetUnitY = function(u) return u.y end
SetUnitX = function(u,x) u.x = x end
SetUnitY = function(u,y) u.y = y end
MoveHero = function(pid,x,y) Hero[pid].x,Hero[pid].y = x,y end
DisableBackpackTeleports = function(pid,value) Backpack[pid].disabled = value end
Player = function(id) return id end
DisplayTimedTextToPlayer = function() end
Rect = function(a,b,c,d) return {a,b,c,d} end
RemoveRect = function() end
RectContainsCoords = function(r,x,y) return x>=r[1] and x<=r[3] and y>=r[2] and y<=r[4] end
local camera = false
PreviewPlayerCamera = function() camera = true end
RestorePlayerCameraPreview = function() camera = false end
local changed = {}
local function key(x,y,t) return x..':'..y..':'..t end
-- Initially all walkable, but not flyable: restoration must retain both flags.
IsTerrainPathable = function(x,y,t)
    local value = changed[key(x,y,t)]
    if value == nil then value = t == 1 end
    return not value
end
SetTerrainPathable = function(x,y,t,value) writes = writes+1; changed[key(x,y,t)] = value end
Location = function(x,y) return {x,y} end
MoveLocation = function(l,x,y) l[1],l[2] = x,y end
GetLocationZ = function() return 0 end
RemoveLocation = function() end
AddSpecialEffect = function(path,x,y)
    assert(path:match('war3mapImported\\ScarabKit\\Cave01_') or path == ScarabKitRenderAssets.blocker.model
        or path == 'buildings\\other\\CircleOfPower\\CircleOfPower.mdl')
    effects = effects+1
    return {x=x,y=y,path=path}
end
local masks = 0
local mask_plan = ScarabKitGeometry.assemble(1.5)
local seeded_plans = {}
local original_assemble = ScarabKitGeometry.assemble
ScarabKitGeometry.assemble = function(scale,room,x,y)
    local plan = original_assemble(scale,room,x,y)
    if room then seeded_plans[x] = plan end
    return plan
end
BlzSetSpecialEffectColor = function(e,r,g,b)
    assert(e.path == ScarabKitRenderAssets.blocker.model and r == 0 and g == 0 and b == 0)
    masks = masks+1
end
BlzSetSpecialEffectMatrixScale = function(e,sx,sy,sz)
    local b = ScarabKitRenderAssets.blocker.bounds
    local halfx,halfy = (b[4]-b[1])*sx/2,(b[5]-b[2])*sy/2
    local test_plan = seeded_plans[-25000] or (next(seeded_plans) and seeded_plans[e.x < -25000 and -27500 or -22500]) or mask_plan
    local overlap = 36*test_plan.pieces[1].scale/1.25
    assert(halfx <= 128+overlap+.001 and halfy <= 128+overlap+.001,'Large cover slab could cull')
    local cx,cy = e.x+(b[1]+b[4])/2*sx,e.y+(b[2]+b[5])/2*sy
    assert(ScarabKitGeometry.exterior(test_plan,cx,cy,halfx-overlap,halfy-overlap), 'Mask core intersects cave')
    for x = cx-halfx,cx+halfx,16 do
        for y = cy-halfy,cy+halfy,16 do
            assert(not ScarabKitGeometry.contains(test_plan,x,y),string.format('Overlapping cover hides playable floor at %.1f,%.1f (mask %.1f,%.1f / %.1f,%.1f)',x,y,cx,cy,halfx,halfy))
        end
    end
    assert(sz > 0)
end
BlzSetSpecialEffectScale = function(e,s) e.scale = s end
BlzSetSpecialEffectYaw = function(e,a) e.angle = a end
BlzSetSpecialEffectZ = function(e,z) e.z = z end
local lamp_count = 0
AddSpecialEffectTarget = function(path,u,point)
    assert(path == ScarabCrawl.art.lamp and (u == Hero[1] or u == Hero[2]) and point == 'origin')
    lamp_count = lamp_count+1
    return {lamp = true}
end
BlzRemoveEffect = function(effect)
    if effect.lamp then lamp_count = lamp_count-1 else removed = removed+1 end
end
local cleanup
EVENT_ON_CLEANUP = {register_action = function(_,_,cb) cleanup = cb end}
dofile('cotlua/src/gameplay/dungeons/scarab/kit_preview.lua')
assert(writes == 0 and effects == 0 and owner == nil,'Preview mutated map at initialization')
assert(not ScarabKitPreview.enter(1,2,3))
assert(ScarabKitPreview.enter(1))
assert(ScarabKitPreview.settings.default_scale == 1.25*1.2)
assert(owner and Unit[Hero[1]].busy and Backpack[1].disabled)
drain(true)
assert(effects > 800 and masks > 0 and camera and Hero[1].x < -20000)
local built_effects = effects
assert(lighting == 'blacklight.mdx' and Hero[1].sight == 800 and Backpack[1].sight == 0 and lamp_count == 1)
assert(ScarabCrawl.vision.lamp == 384 and ScarabCrawl.vision.dark == 192,'Preview changed gameplay sight')
assert(ScarabKitPreview.containsPlayer(1))
assert(ScarabKitPreview.setLamp(1,false))
assert(Hero[1].sight == 800 and lamp_count == 0)
assert(ScarabKitPreview.setLamp(1))
assert(Hero[1].sight == 800 and lamp_count == 1)
local plan = ScarabKitGeometry.assemble(1.5)
local function snap(v) return math.floor(v/32)*32+16 end
local frontier = {{snap(plan.x),snap(plan.y)}}
local visited = {[key(frontier[1][1],frontier[1][2],1)] = true}
local index = 1
while index <= #frontier do
    local c = frontier[index]; index = index+1
    for _,offset in ipairs({{32,0},{-32,0},{0,32},{0,-32}}) do
        local x,y = c[1]+offset[1],c[2]+offset[2]
        local k = key(x,y,1)
        if x >= plan.bounds[1]-64 and x <= plan.bounds[3]+64 and y >= plan.bounds[2]-64 and y <= plan.bounds[4]+64
            and not visited[k] and not IsTerrainPathable(x,y,1) then
            visited[k] = true; frontier[#frontier+1] = {x,y}
        end
    end
end
for _,piece in ipairs(plan.pieces) do
    local x,y = ScarabKitGeometry.transform(piece,piece.kind == 'f' and -136 or 0,piece.kind == 'f' and -200 or 100)
    assert(visited[key(snap(x),snap(y),1)],'Raster disconnected piece '..piece.kind)
end
ScarabKitPreview.leave(1)
drain()
assert(owner == nil and removed == built_effects and not camera)
assert(lighting == nil and Hero[1].sight == 1800 and Backpack[1].sight == 900 and lamp_count == 0)
assert(not ScarabKitPreview.containsPlayer(1) and not ScarabKitPreview.setLamp(1))
assert(Hero[1].x == 100 and Hero[1].y == 200)
assert(Backpack[1].x == 110 and Backpack[1].y == 220 and not Backpack[1].disabled)
for k,value in pairs(changed) do assert(value == (k:sub(-1) == '1'),'Pathing not restored') end
-- Cancel a partly-built preview; stale build callbacks must not spawn art.
assert(ScarabKitPreview.enter(1))
local call = table.remove(queue,1); call[1](table.unpack(call,2))
call = table.remove(queue,1); call[1](table.unpack(call,2))
cleanup(1)
assert(not ScarabKitPreview.enter(1),'Allowed entry during restoration')
drain()
assert(owner == nil and effects == built_effects and not Unit[Hero[1]].busy)
assert(lighting == nil and Hero[1].sight == 1800 and Backpack[1].sight == 900 and lamp_count == 0)
-- Death/repick cleanup also restores sight and removes the attached lamp.
assert(ScarabKitPreview.enter(1)); drain(true)
cleanup(1); drain()
assert(owner == nil and lighting == nil and lamp_count == 0)
assert(Hero[1].sight == 1800 and Backpack[1].sight == 900)
-- The larger overlap must also leave floors uncovered at the scale limits.
for _,scale in ipairs({.75,1.75}) do
    mask_plan = ScarabKitGeometry.assemble(scale)
    assert(ScarabKitPreview.enter(1,scale)); drain(true)
    ScarabKitPreview.leave(1); drain()
end
assert(not ScarabKitPreview.enterSeeded(1,math.huge,8))
assert(not ScarabKitPreview.enterSeeded(1,123,3))
Hero[1].x,Hero[1].y = 100,200
assert(ScarabKitPreview.enterSeeded(1,123,8))
assert(ScarabKitPreview.enterSeeded(2,123,8))
drain(true)
assert(ScarabKitPreview.status():find('Chamber 1',1,true))
assert(Hero[1].x == Hero[2].x and Hero[1].y == Hero[2].y,'Party did not enter together')
local graph = ScarabLayout.generate(123,8)
local exit
for _,d in ipairs(ScarabLayout.directions) do if graph.rooms[1].doors[d[1]] then exit = d; break end end
local destination = graph.rooms[1].doors[exit[1]]
assert(not ScarabKitPreview.travel(1,'bad'))
assert(ScarabKitPreview.travel(1,exit[1]))
assert(Hero[1].paused and Hero[2].paused,'Uncached transition must safely hold the party')
drain(true)
assert(ScarabKitPreview.status():find('Chamber '..destination..' |',1,true))
assert(not Hero[1].paused and not Hero[2].paused)
assert(Hero[1].x == Hero[2].x and Hero[1].y == Hero[2].y)
-- Returning to the still-cached chamber is immediate and does not bounce.
assert(ScarabKitPreview.travel(1,exit[4]))
assert(ScarabKitPreview.status():find('Chamber 1 |',1,true))
local first_plan = seeded_plans[-27500]
local port = first_plan.portals[exit[1]]
Hero[1].x,Hero[1].y = port.x,port.y
for _ = 1,2000 do
    if ScarabKitPreview.status():find('Chamber '..destination..' |',1,true) then break end
    local call = table.remove(queue,1); assert(call); call[1](table.unpack(call,2))
end
assert(ScarabKitPreview.status():find('Chamber '..destination..' |',1,true),'Walking onto a rune did not transition')
ScarabKitPreview.stop(); drain()
assert(owner == nil and not Unit[Hero[1]].busy and not Unit[Hero[2]].busy)
assert(Hero[1].x == 100 and Hero[2].x == 300 and not Hero[1].paused and not Hero[2].paused)
assert(lamp_count == 0 and effects == removed,'Seeded scene/rune effects leaked')
for k,value in pairs(changed) do assert(value == (k:sub(-1) == '1'),'Seeded pathing not restored') end
-- Stop during a held transition, including stale prefetch/build callbacks.
assert(ScarabKitPreview.enterSeeded(1,123,8)); drain(true)
assert(ScarabKitPreview.travel(1,exit[1]))
assert(Hero[1].paused)
ScarabKitPreview.stop(); drain()
assert(owner == nil and not Hero[1].paused and Hero[1].x == 100)
assert(effects == removed and lamp_count == 0 and not Unit[Hero[1]].busy)
local tags = 0
CreateTextTag = function() tags = tags+1; return {} end
DestroyTextTag = function() tags = tags-1 end
SetTextTagText = function(tag,text) tag.text = text end
SetTextTagPos = function() end
SetTextTagColor = function() end
SetTextTagPermanent = function() end
assert(not ScarabKitPreview.enterFloors(1,42,4))
assert(ScarabKitPreview.enterFloors(1,42,5))
assert(ScarabKitPreview.enterFloors(2,42,5)); drain(true)
assert(ScarabKitPreview.status():find('Floor 1 |',1,true))
assert(ScarabKitPreview.status():find('streaming scenery',1,true),'Entry waited for the entire floor')
assert(not ScarabKitPreview.enterSeeded(2,42,5),'Mixed floor and room modes')
assert(not ScarabKitPreview.travel(1,'1'),'Allowed descent without regrouping')
local floor_plan = seeded_plans[-25000]
local hole = floor_plan.portals['1']
-- Rushing into an unfinished sector prioritizes it without letting players
-- walk around invisible/unpathable future scenery.
local safe_x,safe_y = Hero[1].x,Hero[1].y
Hero[1].x,Hero[1].y = hole.x,hole.y
for _ = 1,4 do local call = table.remove(queue,1); call[1](table.unpack(call,2)) end
assert(Hero[1].x == safe_x and Hero[1].y == safe_y,'Rush escaped into an unfinished sector')
local function finish_floor()
    for _ = 1,8000 do
        if not ScarabKitPreview.status():find('streaming scenery',1,true) then return end
        local call = table.remove(queue,1); assert(call); call[1](table.unpack(call,2))
    end
    error('Floor streaming never completed')
end
finish_floor()
assert(hole and tags >= 2)
Hero[1].x,Hero[1].y,Hero[2].x,Hero[2].y = hole.x,hole.y,hole.x,hole.y
assert(ScarabKitPreview.travel(1,'1'))
assert(Hero[1].paused and Hero[2].paused and Hero[1].x == 100 and Hero[2].x == 300,'Party not safely staged before rebuilding')
drain(true)
assert(ScarabKitPreview.status():find('Floor 2 |',1,true))
assert(not Hero[1].paused and not Hero[2].paused and Hero[1].x == Hero[2].x)
local expected_floor = ScarabKitGeometry.assemble(1.5,{id = 2,seed = hole.seed,doors = {},floor = true},-25000,25000)
assert(seeded_plans[-25000].x == expected_floor.x,'Selected hole did not determine the next floor')
finish_floor()
-- Cancellation while staged must not leak pause, scenery, labels or pathing.
hole = seeded_plans[-25000].portals['2']
Hero[1].x,Hero[1].y,Hero[2].x,Hero[2].y = hole.x,hole.y,hole.x,hole.y
assert(ScarabKitPreview.travel(2,'2')); ScarabKitPreview.stop(); drain()
assert(owner == nil and tags == 0 and effects == removed and lamp_count == 0)
assert(Hero[1].x == 100 and Hero[2].x == 300 and not Hero[1].paused and not Hero[2].paused)
for k,value in pairs(changed) do assert(value == (k:sub(-1) == '1'),'Floor pathing not restored') end
print('Scarab kit geometry, batched pathing, cancellation and cleanup passed (offline mocks).')
