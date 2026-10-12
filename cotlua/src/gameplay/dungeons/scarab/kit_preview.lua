-- Command-only visual/pathing test. Does not replace the procedural crawl.
OnInit.final('ScarabKitPreview', function(Require)
    Require('ScarabKitGeometry')
    Require('ScarabKitRenderAssets')
    Require('ScarabLayout')
    Require('ScarabCrawl')
    Require('PlayerLifecycle')
    Require('PlayerCamera')
    Require('TimerQueue')
    Require('Events')
    Require('UnitTable')
    ScarabKitPreview = {}
    -- Preview-only rendering headroom. Gameplay crawl sight remains unchanged.
    ScarabKitPreview.settings = {default_scale = 1.5, sight = 800, sight_padding = 256, cover_span = 256, cover_overlap = 36}
    local active, closing
    local walk, fly = PATHING_TYPE_WALKABILITY, PATHING_TYPE_FLYABILITY
    local remove_effect = rawget(_G, 'BlzRemoveEffect')
    local build,prepare,prefetch,complete_transition
    local function exits(state)
        return state.room and state.room.floor and {{'1'},{'2'},{'3'}} or ScarabLayout.directions
    end
    local function message(pid,text) DisplayTimedTextToPlayer(Player(pid-1),0,0,10,text) end
    local function remove(effect)
        if remove_effect then remove_effect(effect) else
            BlzSetSpecialEffectAlpha(effect,0)
            BlzSetSpecialEffectZ(effect,-10000)
            DestroyEffect(effect)
        end
    end
    function ScarabKitPreview.containsPlayer(pid)
        return active ~= nil and active.members[pid] ~= nil
    end
    function ScarabKitPreview.setLamp(pid,enabled)
        local member = active and active.members[pid]
        if not member then return false,'Enter the cave-kit preview before testing a lamp.' end
        if enabled == nil then enabled = not member.lamp_enabled end
        member.lamp_enabled = enabled
        if member.lamp then remove(member.lamp); member.lamp = nil end
        if member.arrived then
            BlzSetUnitRealField(member.hero,UNIT_RF_SIGHT_RADIUS,
                ScarabKitPreview.settings.sight)
            if enabled then member.lamp = AddSpecialEffectTarget(ScarabCrawl.art.lamp,member.hero,'origin') end
        end
        return true,enabled and 'Cave-kit lamp ON.' or 'Cave-kit lamp OFF.'
    end
    local function arrive(state,pid)
        local member = state.members[pid]
        if not member or Hero[pid] ~= member.hero or not UnitAlive(member.hero) then return end
        local scene = state.current or state
        local portal = member.entering and scene.plan.portals[member.entering]
        local x,y = portal and portal.spawn_x or scene.plan.x,portal and portal.spawn_y or scene.plan.y
        PreviewPlayerCamera(pid,scene.rect,x,y,true)
        MoveHero(pid,x,y)
        if Backpack[pid] then
            SetUnitX(Backpack[pid],x); SetUnitY(Backpack[pid],y)
        end
        PreviewPlayerCamera(pid,scene.rect,x,y,true)
        if member.held then PauseUnit(member.hero,member.was_paused); member.held = nil end
        member.entering = nil
        member.arrived = true
        if scene.safe then scene.safe[pid] = {x,y} end
        SetPlayerLightingOverride(pid,'blacklight.mdx')
        if member.backpack then BlzSetUnitRealField(member.backpack,UNIT_RF_SIGHT_RADIUS,0) end
        ScarabKitPreview.setLamp(pid,member.lamp_enabled)
        if not IsFogEnabled() or not IsFogMaskEnabled() then
            message(pid,'Fog is disabled: use -novision to test cave visibility. Darkness alone does not hide unexplored pieces.')
        end
        if state.graph then
            local exits = {}
            for _,d in ipairs(scene.room.floor and {{'1'},{'2'},{'3'}} or ScarabLayout.directions) do if scene.plan.portals[d[1]] then exits[#exits+1] = d[1]:upper() end end
            if state.graph.floors then
                message(pid,'Seed '..state.graph.seed..' | Floor '..scene.room.id..'/'..#state.graph.rooms..' | Holes: '..table.concat(exits,', ')..'. Gather the party at a rune, then -scarab descend <number>. '..(scene.room.final and 'Final floor: boss placement reserved. ' or '')..'No enemies or rewards yet.')
            else
                message(pid,'Seed '..state.graph.seed..' | Chamber '..scene.room.id..'/'..#state.graph.rooms..' | Exits: '..table.concat(exits,', ')..'. Walk onto a rune or use -scarab n/e/s/w. The party travels together; no enemies or rewards.')
            end
        else
            message(pid,'Cave-kit test: walk north through a/b/c, then east through the bend. Junction: wide chamber north, narrow caps east/south. -lamp toggles the light; -scarab kitleave returns you.')
        end
    end
    function ScarabKitPreview.leave(pid,relocate)
        local state = active
        local member = state and state.members[pid]
        if not member then return end
        state.members[pid] = nil
        if Hero[pid] == member.hero then
            if member.held then PauseUnit(member.hero,member.was_paused); member.held = nil end
            Unit[member.hero].busy = false
            if Backpack[pid] then DisableBackpackTeleports(pid,false) end
            if member.arrived and relocate ~= false then
                MoveHero(pid,member.x,member.y)
                if Backpack[pid] and member.bx then
                    SetUnitX(Backpack[pid],member.bx); SetUnitY(Backpack[pid],member.by)
                end
            end
        end
        if member.arrived then
            RestorePlayerCameraPreview(pid)
            if member.lamp then remove(member.lamp) end
            BlzSetUnitRealField(member.hero,UNIT_RF_SIGHT_RADIUS,member.sight)
            if member.backpack then BlzSetUnitRealField(member.backpack,UNIT_RF_SIGHT_RADIUS,member.backpack_sight) end
            SetPlayerLightingOverride(pid,nil)
        end
        if not next(state.members) and not state.stopping then ScarabKitPreview.stop() end
    end
    local function close_scene(state,callback)
        if state.closed then callback(); return end
        state.close_callbacks = state.close_callbacks or {}
        state.close_callbacks[#state.close_callbacks+1] = callback
        if state.closing then return end
        state.alive,state.closing = false,true
        for _,tag in ipairs(state.tags) do DestroyTextTag(tag) end
        REGION_DATA[state.rect] = nil
        RemoveRect(state.rect)
        local index = 1
        local function restore()
            local last = math.min(index+(state.room and state.room.floor and 4095 or 255),#state.original)
            for i = index,last do
                local c = state.original[i]
                SetTerrainPathable(c[1],c[2],walk,c[3])
                SetTerrainPathable(c[1],c[2],fly,c[4])
            end
            index = last+1
            if index <= #state.original then TimerQueue:callDelayed(state.room and state.room.floor and .01 or .02,restore)
            else
                state.closed = true
                for _,done in ipairs(state.close_callbacks) do done() end
                state.close_callbacks = nil
            end
        end
        if state.room and state.room.floor then
            -- Large floors can contain thousands of chunks. The party has
            -- already left, so teardown can be paced instead of a removal spike.
            local art_index = 1
            local function clear_art()
                local last = math.min(art_index+255,#state.effects)
                for i = art_index,last do remove(state.effects[i]) end
                art_index = last+1
                if art_index <= #state.effects then TimerQueue:callDelayed(.01,clear_art) else restore() end
            end
            clear_art()
        else
            for _,effect in ipairs(state.effects) do remove(effect) end
            restore()
        end
    end
    function ScarabKitPreview.stop()
        local state = active
        if not state then return end
        state.stopping = true
        local ids = {}
        for pid in pairs(state.members) do ids[#ids+1] = pid end
        for _,pid in ipairs(ids) do ScarabKitPreview.leave(pid) end
        active,closing = nil,true
        local scenes = {}
        if state.slots then for _,scene in pairs(state.slots) do scenes[#scenes+1] = scene end
        else scenes[1] = state end
        local pending = #scenes
        local function done()
            pending = pending-1
            if pending == 0 then ScarabCrawl.releaseArea(state); closing = false end
        end
        for _,scene in ipairs(scenes) do close_scene(scene,done) end
    end
    local function poll(state)
        if active ~= state then return end
        local ids = {}
        for pid,member in pairs(state.members) do
            if Hero[pid] ~= member.hero or not UnitAlive(member.hero) then ids[#ids+1] = pid
            elseif member.arrived and not state.transition and not RectContainsCoords((state.current or state).rect,GetUnitX(member.hero),GetUnitY(member.hero)) then
                ids[#ids+1] = pid
            elseif state.graph and not state.graph.floors and state.current and state.current.ready and member.arrived and not state.transition then
                for _,d in ipairs(ScarabLayout.directions) do
                    local port = state.current.plan.portals[d[1]]
                    if port and (GetUnitX(member.hero)-port.x)^2+(GetUnitY(member.hero)-port.y)^2 <= 80^2 then
                        ScarabKitPreview.travel(pid,d[1]); break
                    end
                end
            end
        end
        for _,pid in ipairs(ids) do ScarabKitPreview.leave(pid,false) end
        if active == state then TimerQueue:callDelayed(.25,poll,state) end
    end
    local function finish_masks(state)
        local previous = {}
        local rectangles = {}
        for _,row in ipairs(state.mask_rows) do
            local next_row = {}
            for _,run in ipairs(row.runs) do
                local key = run[1]..':'..run[2]
                local rect = previous[key]
                if rect then rect[4] = row.y+16 else
                    rect = {run[1]-16,row.y-16,run[2]+16,row.y+16}
                    rectangles[#rectangles+1] = rect
                end
                next_row[key] = rect
            end
            previous = next_row
        end
        -- Wider preview sight lets us use fewer, longer covers. Keep their
        -- origins bounded: unbounded slabs can still disappear while partly lit.
        local span = ScarabKitPreview.settings.cover_span
        -- Scale the inset with the cave walls, not just the fixed world grid:
        -- a full-size inset on a .75-scale wall can spill onto its floor.
        local overlap = ScarabKitPreview.settings.cover_overlap*state.plan.pieces[1].scale/1.25
        for _,rect in ipairs(rectangles) do
            for x = rect[1],rect[3]-1,span do
                for y = rect[2],rect[4]-1,span do
                    -- Overlap the outer wall skirt and adjacent covers slightly,
                    -- rather than leaving a thin illuminated line between them.
                    local right,top = math.min(x+span,rect[3]),math.min(y+span,rect[4])
                    local inset = overlap
                    if ScarabKitGeometry.intersectsFloor(state.plan,x-inset,y-inset,right+inset,top+inset) then
                        local low,high = 0,inset
                        for _ = 1,8 do
                            local middle = (low+high)/2
                            if ScarabKitGeometry.intersectsFloor(state.plan,x-middle,y-middle,right+middle,top+middle) then high = middle else low = middle end
                        end
                        inset = low
                    end
                    state.masks[#state.masks+1] = {x-inset,y-inset,right+inset,top+inset}
                end
            end
        end
        state.mask_rows = nil
    end
    local function build_art(state)
        if not state.alive or (state.streamparent and not state.streamparent.alive) then return end
        local location = Location(0,0)
        local block = ScarabKitRenderAssets.blocker
        local b = block.bounds
        for _ = 1,state.art_budget or 12 do
            local part = (state.render or state.plan.render)[state.art_index]
            local effect
            if part then
                MoveLocation(location,part.x,part.y)
                effect = AddSpecialEffect('war3mapImported\\ScarabKit\\'..part.file,part.x,part.y)
                BlzSetSpecialEffectScale(effect,part.scale)
                BlzSetSpecialEffectYaw(effect,part.angle)
                BlzSetSpecialEffectZ(effect,GetLocationZ(location)+state.lift)
                state.art_index = state.art_index+1
            else
                local mask = state.masks[state.mask_index]
                if not mask then
                    RemoveLocation(location)
                    state.ready = true
                    if state.room then
                        for _,d in ipairs(exits(state)) do
                            local port = state.plan.portals[d[1]]
                            if port then
                            local ring = AddSpecialEffect('buildings\\other\\CircleOfPower\\CircleOfPower.mdl',port.x,port.y)
                            BlzSetSpecialEffectScale(ring,.65)
                            state.effects[#state.effects+1] = ring
                            if state.room.floor then
                                local tag = CreateTextTag()
                                SetTextTagText(tag,'Hole '..d[1],.024)
                                SetTextTagPos(tag,port.x,port.y,20)
                                SetTextTagColor(tag,255,220,100,255)
                                SetTextTagPermanent(tag,true)
                                state.tags[#state.tags+1] = tag
                            end
                            end
                        end
                    end
                    if state.on_ready then state.on_ready(state) else
                        for pid in pairs(state.members) do arrive(state,pid) end
                        poll(state)
                    end
                    return
                end
                -- Reproduce D00H's model/RGB, with custom rectangular dimensions.
                -- It is visual cover, not a light-occlusion or vision modifier.
                local sx,sy,sz = (mask[3]-mask[1])/(b[4]-b[1]),(mask[4]-mask[2])/(b[5]-b[2]),140/(b[6]-b[3])
                local x,y = (mask[1]+mask[3])/2-(b[1]+b[4])/2*sx,(mask[2]+mask[4])/2-(b[2]+b[5])/2*sy
                MoveLocation(location,x,y)
                effect = AddSpecialEffect(block.model,x,y)
                BlzSetSpecialEffectColor(effect,0,0,0)
                BlzSetSpecialEffectMatrixScale(effect,sx,sy,sz)
                BlzSetSpecialEffectZ(effect,GetLocationZ(location)-b[3]*sz)
                state.mask_index = state.mask_index+1
            end
            state.effects[#state.effects+1] = effect
        end
        RemoveLocation(location)
        if not state.manual then TimerQueue:callDelayed(.02,build_art,state) end
    end
    -- Floor sectors own both pathing and scenery. Priorities use synchronized
    -- hero positions only; no local camera/mouse state affects generation.
    local function stream_floor(state,root)
        local span = 512
        local jobs,lookup = {},{}
        local function key(x,y) return math.floor(x/span)..':'..math.floor(y/span) end
        for x = math.floor(state.minx/span)*span,state.maxx,span do
            for y = math.floor(state.y/span)*span,state.maxy,span do
                local job = {plan = state.plan,lift = state.lift,effects = state.effects,tags = {},alive = true,
                    streamparent = state,render = {},mask_rows = {},masks = {},art_index = 1,mask_index = 1,
                    manual = true,art_budget = 64,x = x,y = y}
                job.on_ready = function()
                    job.done = true
                    for _,d in ipairs(exits(state)) do
                        local port = state.plan.portals[d[1]]
                        if port and key(port.x,port.y) == key(job.x,job.y) then
                            local ring = AddSpecialEffect('buildings\\other\\CircleOfPower\\CircleOfPower.mdl',port.x,port.y)
                            BlzSetSpecialEffectScale(ring,.65); state.effects[#state.effects+1] = ring
                            local tag = CreateTextTag()
                            SetTextTagText(tag,'Hole '..d[1],.024); SetTextTagPos(tag,port.x,port.y,20)
                            SetTextTagColor(tag,255,220,100,255); SetTextTagPermanent(tag,true)
                            state.tags[#state.tags+1] = tag
                        end
                    end
                end
                lookup[key(x,y)] = job; jobs[#jobs+1] = job
            end
        end
        for _,part in ipairs(state.plan.render) do
            local job = lookup[key(part.x,part.y)]
            if job then job.render[#job.render+1] = part end
        end
        state.sectors,state.sector_span = lookup,span
        local function tick()
            if not state.alive or active ~= root then return end
            state.stream_tick = (state.stream_tick or 0)+1
            local points = {{state.plan.x,state.plan.y}}
            if root.current == state and state.usable then
                points = {}
                for pid = 1,PLAYER_CAP do
                    local member = root.members[pid]
                    if member and member.arrived and UnitAlive(member.hero) then
                        local x,y = GetUnitX(member.hero),GetUnitY(member.hero)
                        points[#points+1] = {x,y}
                        local complete = true
                        for bx = math.floor((x-900)/span),math.floor((x+900)/span) do
                            for by = math.floor((y-900)/span),math.floor((y+900)/span) do
                                local job = lookup[bx..':'..by]
                                if job and not job.done then complete = false end
                            end
                        end
                        if complete then state.safe[pid] = {x,y}
                        elseif state.safe[pid] then
                            if x ~= state.safe[pid][1] or y ~= state.safe[pid][2] then
                                state.requests[pid] = {x,y,until_tick = state.stream_tick+100}
                            end
                            MoveHero(pid,state.safe[pid][1],state.safe[pid][2])
                        end
                        local request = state.requests[pid]
                        if request and request.until_tick >= state.stream_tick then points[#points+1] = request end
                    end
                end
                if #points == 0 then points[1] = {state.plan.x,state.plan.y} end
            end
            local best,score,remaining
            local spawn_complete = true
            for _,job in ipairs(jobs) do
                if not job.done then
                    remaining = true
                    local dx = math.max(job.x-state.plan.x,0,state.plan.x-job.x-span)
                    local dy = math.max(job.y-state.plan.y,0,state.plan.y-job.y-span)
                    if dx <= 1100 and dy <= 1100 then spawn_complete = false end
                    local distance = math.huge
                    for _,point in ipairs(points) do
                        local px = math.max(job.x-point[1],0,point[1]-job.x-span)
                        local py = math.max(job.y-point[2],0,point[2]-job.y-span)
                        distance = math.min(distance,px*px+py*py)
                    end
                    if not score or distance < score then best,score = job,distance end
                end
            end
            if not state.usable and spawn_complete and state.entry_delay_elapsed then
                state.usable = true
                state.on_ready(state)
            end
            if not remaining then
                state.ready = true
                if not state.usable then TimerQueue:callDelayed(.01,tick) end
                return
            end
            if not best.path_done then
                for y = math.max(best.y+16,state.miny),math.min(best.y+span-16,state.maxy),32 do
                    local row = {y = y,runs = {}}; best.mask_rows[#best.mask_rows+1] = row
                    for x = math.max(best.x+16,state.minx),math.min(best.x+span-16,state.maxx),32 do
                        if ScarabKitGeometry.exterior(state.plan,x,y,16) then
                            local tail = row.runs[#row.runs]
                            if tail and tail[2] == x-32 then tail[2] = x else row.runs[#row.runs+1] = {x,x} end
                        end
                        local open = ScarabKitGeometry.contains(state.plan,x,y)
                            and ScarabKitGeometry.contains(state.plan,x-16,y) and ScarabKitGeometry.contains(state.plan,x+16,y)
                            and ScarabKitGeometry.contains(state.plan,x,y-16) and ScarabKitGeometry.contains(state.plan,x,y+16)
                        local w,f = not IsTerrainPathable(x,y,walk),not IsTerrainPathable(x,y,fly)
                        if w ~= open or f ~= open then
                            state.original[#state.original+1] = {x,y,w,f}
                            SetTerrainPathable(x,y,walk,open); SetTerrainPathable(x,y,fly,open)
                        end
                    end
                end
                finish_masks(best); best.path_done = true
            end
            build_art(best)
            TimerQueue:callDelayed(.01,tick)
        end
        TimerQueue:callDelayed(2,function() if state.alive then state.entry_delay_elapsed = true end end)
        tick()
    end
    build = function(state)
        if not state.alive then return end
        local plan = state.plan
        for _ = 1,256 do
            if state.y > state.maxy then
                finish_masks(state)
                build_art(state)
                return
            end
            local x,y = state.x,state.y
            local row = state.mask_rows[#state.mask_rows]
            if not row or row.y ~= y then row = {y = y,runs = {}}; state.mask_rows[#state.mask_rows+1] = row end
            if ScarabKitGeometry.exterior(plan,x,y,16) then
                local tail = row.runs[#row.runs]
                if tail and tail[2] == x-32 then tail[2] = x else row.runs[#row.runs+1] = {x,x} end
            end
            -- A little inward clearance keeps hero centers away from wall faces.
            local open = ScarabKitGeometry.contains(plan,x,y)
                and ScarabKitGeometry.contains(plan,x-16,y) and ScarabKitGeometry.contains(plan,x+16,y)
                and ScarabKitGeometry.contains(plan,x,y-16) and ScarabKitGeometry.contains(plan,x,y+16)
            local w,f = not IsTerrainPathable(x,y,walk),not IsTerrainPathable(x,y,fly)
            if w ~= open or f ~= open then
                state.original[#state.original+1] = {x,y,w,f}
                SetTerrainPathable(x,y,walk,open); SetTerrainPathable(x,y,fly,open)
            end
            state.x = x+32
            if state.x > state.maxx then state.x,state.y = state.minx,y+32 end
        end
        TimerQueue:callDelayed(.02,build,state)
    end
    local function scene(plan,lift,margin)
        local state = {plan = plan,lift = lift,effects = {},tags = {},safe = {},requests = {},original = {},alive = true,
            mask_rows = {},masks = {},art_index = 1,mask_index = 1}
        local b = plan.bounds
        margin = margin or ScarabKitPreview.settings.sight
        state.minx,state.maxx = math.floor((b[1]-margin)/32)*32+16,math.ceil((b[3]+margin)/32)*32+16
        state.y,state.maxy = math.floor((b[2]-margin)/32)*32+16,math.ceil((b[4]+margin)/32)*32+16
        state.miny = state.y
        state.x = state.minx
        state.rect = Rect(state.minx-16,state.y-16,state.maxx+16,state.maxy+16)
        REGION_DATA[state.rect] = {vision = state.rect,hide_minimap = true}
        return state
    end
    prepare = function(state,index,room_id)
        state.generations[index] = (state.generations[index] or 0)+1
        local generation = state.generations[index]
        local function create()
            if active ~= state or state.generations[index] ~= generation then return end
            local x = state.graph.floors and -25000 or (index == 1 and -27500 or -22500)
            local room = state.graph.rooms[room_id]
            -- Keep the legacy half-width pathing buffers non-overlapping even
            -- though preview sight is now 800. Full floors use the wider margin.
            local next_scene = scene(ScarabKitGeometry.assemble(state.scale,room,x,25000),state.lift,
                state.graph.floors and ScarabKitPreview.settings.sight or 640)
            next_scene.room,next_scene.index = room,index
            next_scene.on_ready = function(ready)
                if active ~= state then return end
                if not state.current or (state.transition and state.transition.target == ready.room.id) then
                    complete_transition(state,ready)
                end
            end
            state.slots[index] = next_scene
            if room.floor then TimerQueue:callDelayed(0.,stream_floor,next_scene,state)
            else TimerQueue:callDelayed(0.,build,next_scene) end
        end
        local old = state.slots[index]
        if old then close_scene(old,create) else create() end
    end
    prefetch = function(state)
        if active ~= state or state.transition or state.graph.floors then return end
        local current = state.current
        for _,d in ipairs(ScarabLayout.directions) do
            local port = current.plan.portals[d[1]]
            if port and not state.visited[port.target] then
                local index = 3-current.index
                local cached = state.slots[index]
                if not cached or cached.closing or cached.room.id ~= port.target then prepare(state,index,port.target) end
                return
            end
        end
    end
    complete_transition = function(state,target)
        local transition = state.transition
        state.current,state.transition = target,nil
        state.visited[target.room.id] = true
        for pid,member in pairs(state.members) do
            member.entering = transition and transition.opposite or nil
            arrive(state,pid)
        end
        if not state.poll_started then
            state.poll_started = true
            TimerQueue:callDelayed(.25,poll,state)
        end
        -- Build the first unexplored neighbor while the party explores this room.
        TimerQueue:callDelayed(0.,prefetch,state)
    end
    function ScarabKitPreview.travel(pid,direction)
        local state = active
        local member = state and state.members[pid]
        if not member or not state.graph or not state.current then return false,'Not in a ready seeded cave-kit room.' end
        if state.transition then return false,'The next chamber is preparing.' end
        if not UnitAlive(member.hero) then return false,'A living hero is required.' end
        local port = state.current.plan.portals[direction]
        if not port then return false,state.graph.floors and 'There is no progression hole with that number (or this is the final floor).' or 'There is no exit in that direction.' end
        if state.graph.floors then
            local sector = state.current.sectors and state.current.sectors[math.floor(port.x/512)..':'..math.floor(port.y/512)]
            if sector and not sector.done then return false,'That hole is still being constructed.' end
            for _,participant in pairs(state.members) do
                if not UnitAlive(participant.hero) or (GetUnitX(participant.hero)-port.x)^2+(GetUnitY(participant.hero)-port.y)^2 > 600^2 then
                    return false,'Gather every participant within 600 of the selected hole before descending.'
                end
            end
            state.graph.rooms[port.target].seed = port.seed
        end
        state.transition = {target = port.target,opposite = port.opposite}
        local index = state.graph.floors and 1 or 3-state.current.index
        local cached = state.slots[index]
        if cached and not cached.closing and cached.ready and cached.room.id == port.target then
            complete_transition(state,cached)
        else
            for id,participant in pairs(state.members) do
                participant.was_paused = IsUnitPaused(participant.hero)
                participant.held = true
                PauseUnit(participant.hero,true)
                if state.graph.floors then
                    -- A full-corner floor cannot coexist with its replacement.
                    -- Stage safely outside it before any scenery is removed.
                    if participant.lamp then remove(participant.lamp); participant.lamp = nil end
                    MoveHero(id,participant.x,participant.y)
                    if Backpack[id] and participant.bx then SetUnitX(Backpack[id],participant.bx); SetUnitY(Backpack[id],participant.by) end
                    RestorePlayerCameraPreview(id)
                    SetPlayerLightingOverride(id,nil)
                    BlzSetUnitRealField(participant.hero,UNIT_RF_SIGHT_RADIUS,participant.sight)
                end
                message(id,'Preparing chamber '..port.target..'… The party will move together when it is ready.')
            end
            if not cached or cached.closing or cached.room.id ~= port.target then prepare(state,index,port.target) end
        end
        return true,'Moving the party to chamber '..port.target..'.'
    end
    function ScarabKitPreview.enter(pid,scale,lift,seed,count,floor_mode)
        if closing then return false,'Cave-kit pathing is still being restored.' end
        if not Hero[pid] or not UnitAlive(Hero[pid]) or Unit[Hero[pid]].busy then
            return false,'A living, unoccupied hero is required.'
        end
        if floor_mode and GetUnitX(Hero[pid]) >= -30000 and GetUnitX(Hero[pid]) <= -20000
            and GetUnitY(Hero[pid]) >= 20000 and GetUnitY(Hero[pid]) <= 30000 then
            return false,'Enter floor mode from outside the reserved cave corner so transitions have a safe staging position.'
        end
        scale,lift = scale or ScarabKitPreview.settings.default_scale,lift or 3
        if scale ~= scale or scale < .75 or scale > 1.75 or lift ~= lift or lift < 0 or lift > 16 then
            return false,'Use scale .75–1.75 and floor lift 0–16.'
        end
        if seed then
            if type(seed) ~= 'number' or seed ~= seed or seed%1 ~= 0 or math.abs(seed) >= 2147483647 then return false,'Invalid cave-kit seed.' end
            count = count or 12
            if count ~= count or count%1 ~= 0 or count < 4 or count > 40 then return false,'Use 4–40 rooms.' end
            if floor_mode and (count < 5 or count > 10) then return false,'Use 5–10 floors.' end
            if scale > 1.5 then return false,'Seeded rooms support scales up to 1.5 to fit the two physical buffers.' end
        end
        if active and ((seed ~= nil) ~= (active.graph ~= nil)) then return false,'Stop the existing preview before changing modes.' end
        if active and seed and ((floor_mode == true) ~= (active.graph.floors == true)) then return false,'Stop the existing preview before changing between rooms and floors.' end
        if active and active.transition then return false,'Wait for the room transition before joining.' end
        if active and seed and (active.graph.seed ~= seed or #active.graph.rooms ~= count) then return false,'That lobby already has a different seeded kit run; stop it first.' end
        if not active then
            local state = seed and {graph = floor_mode and ScarabKitGeometry.floorRun(seed,count) or ScarabLayout.generate(seed,count),members = {},slots = {},generations = {},visited = {},scale = scale,lift = lift}
                or {members = {}}
            local ok,reason = ScarabCrawl.reserveArea(state)
            if not ok then return false,reason end
            active = state
            if seed then prepare(state,1,state.graph.start) else
                local render_scene = scene(ScarabKitGeometry.assemble(scale),lift)
                for key,value in pairs(render_scene) do state[key] = value end
                TimerQueue:callDelayed(0.,build,state)
            end
        end
        local member = {hero = Hero[pid],backpack = Backpack[pid],x = GetUnitX(Hero[pid]),y = GetUnitY(Hero[pid]),
            sight = BlzGetUnitRealField(Hero[pid],UNIT_RF_SIGHT_RADIUS),
            backpack_sight = Backpack[pid] and BlzGetUnitRealField(Backpack[pid],UNIT_RF_SIGHT_RADIUS),lamp_enabled = true}
        if Backpack[pid] then member.bx,member.by = GetUnitX(Backpack[pid]),GetUnitY(Backpack[pid]) end
        active.members[pid] = member
        Unit[member.hero].busy = true
        if Backpack[pid] then DisableBackpackTeleports(pid,true) end
        if active.ready or (active.current and (active.current.ready or active.current.usable)) then arrive(active,pid) end
        return true,'Cave-kit preview preparing (no terrain edits, enemies or rewards).'
    end
    function ScarabKitPreview.enterSeeded(pid,seed,count)
        seed = seed or (active and active.graph and active.graph.seed) or 1
        count = count or (active and active.graph and #active.graph.rooms) or 12
        return ScarabKitPreview.enter(pid,nil,nil,seed,count)
    end
    function ScarabKitPreview.enterFloors(pid,seed,count)
        seed = seed or (active and active.graph and active.graph.seed) or 1
        count = count or (active and active.graph and #active.graph.rooms) or 6
        return ScarabKitPreview.enter(pid,nil,nil,seed,count,true)
    end
    function ScarabKitPreview.status()
        if closing then return 'Cave-kit preview closing; restoring pathing.' end
        if not active then return 'No cave-kit preview is running.' end
        if active.graph then
            local count = 0
            for _ in pairs(active.visited) do count = count+1 end
            return string.format('Cave-kit seed %d | '..(active.graph.floors and 'Floor' or 'Chamber')..' %s | Visited %d/%d | %s',active.graph.seed,
                active.current and tostring(active.current.room.id) or '-',count,#active.graph.rooms,
                active.transition and 'preparing transition' or (active.current and (active.current.sectors and not active.current.ready and 'ready (streaming scenery)' or 'ready') or 'building'))
        end
        return string.format('Cave-kit: %s, 9 pieces, scale %.2f, floor lift %.1f.',active.ready and 'ready' or 'building',active.plan.pieces[1].scale,active.lift)
    end
    for pid = 1,PLAYER_CAP do
        EVENT_ON_CLEANUP:register_action(pid,function(id) ScarabKitPreview.leave(id,false) end)
    end
end)
