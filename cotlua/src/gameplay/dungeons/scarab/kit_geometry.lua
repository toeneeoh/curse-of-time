-- Pure cave assembly, using measured sockets and floor triangles.
OnInit.global('ScarabKitGeometry', function(Require)
    Require('ScarabKitAssets')
    Require('ScarabKitRenderAssets')
    Require('ScarabLayout')
    ScarabKitGeometry = {}
    local ports = {
        a = {n = {.634, 295.276, math.pi/2}, s = {.634, -295.275, -math.pi/2}},
        b = {n = {17.23, 295.277, math.pi/2}, s = {17.23, -295.274, -math.pi/2}},
        c = {n = {.001, 295.276, math.pi/2}, s = {.001, -295.275, -math.pi/2}},
        D = {n = {.001, 306.563, math.pi/2}},
        f = {s = {-136.224, -306.687, -math.pi/2}, e = {306.688, 136.226, 0}},
        g = {n = {0, 442.914, math.pi/2}, e = {442.914, 0, 0},
            s = {0, -442.913, -math.pi/2}, w = {-442.913, 0, math.pi}},
        h = {s = {8.962, -460.316, -math.pi/2}},
    }
    local function transform(piece, x, y)
        local c, s = math.cos(piece.angle), math.sin(piece.angle)
        return piece.x + piece.scale * (x*c-y*s), piece.y + piece.scale * (x*s+y*c)
    end
    ScarabKitGeometry.transform = transform
    local function piece_bounds(piece)
        local b = ScarabKitAssets[piece.kind].bounds
        local result = {math.huge,math.huge,-math.huge,-math.huge}
        for _,c in ipairs({{b[1],b[2]},{b[1],b[4]},{b[3],b[2]},{b[3],b[4]}}) do
            local x,y = transform(piece,c[1],c[2])
            result[1],result[2],result[3],result[4] = math.min(result[1],x),math.min(result[2],y),math.max(result[3],x),math.max(result[4],y)
        end
        return result
    end
    ScarabKitGeometry.pieceBounds = piece_bounds
    function ScarabKitGeometry.floorRun(seed,count)
        local random = ScarabLayout.random(seed)
        local rooms = {}
        for id = 1,count do rooms[id] = {id = id,seed = random(2147483646),doors = {},floor = true,final = id == count} end
        return {seed = seed,rooms = rooms,start = 1,floors = true}
    end
    function ScarabKitGeometry.assemble(scale,room,center_x,center_y)
        assert(scale >= .75 and scale <= 1.75)
        local random = room and ScarabLayout.random(room.seed)
        local hub,angle = room and 'g' or 'D',0
        local compass = {'e','n','w','s'}
        local function direction(a) return compass[math.floor(a/(math.pi/2)+.5)%4+1] end
        if room then
            local count = 0
            for _ in pairs(room.doors) do count = count+1 end
            if count == 2 then
                for quarter = 0,3 do
                    local a = quarter*math.pi/2
                    if room.doors[direction(a-math.pi/2)] and room.doors[direction(a)] then hub,angle = 'f',a; break end
                end
            end
        end
        local pieces = {{kind = hub, x = 0, y = 0, angle = angle, scale = scale}}
        local portals = {}
        local function attach(parent, outlet, kind, inlet, overlap)
            local a, b = ports[parent.kind][outlet], ports[kind][inlet]
            local x, y = transform(parent, a[1], a[2])
            local child = {kind = kind, x = 0, y = 0, angle = parent.angle+a[3]+math.pi-b[3], scale = scale}
            local bx, by = transform(child, b[1], b[2])
            child.x, child.y = x-bx, y-by
            -- Small model-space overlap closes the wide chamber's visible seam.
            -- Apply it to both the art placement and its measured floor footprint.
            local inset = (overlap or 0) * scale
            child.x = child.x-inset*math.cos(parent.angle+a[3])
            child.y = child.y-inset*math.sin(parent.angle+a[3])
            pieces[#pieces+1] = child
            return child
        end
        if room and room.floor then
            -- Joined modular intersections create a substantially larger floor,
            -- not a larger copy of a single room. Every unused mouth is capped.
            local size = random(2)+1
            local grid = {{pieces[1]}}
            for row = 1,size do
                grid[row] = grid[row] or {}
                if row > 1 then grid[row][1] = attach(grid[row-1][1],'n','g','s') end
                for col = 2,size do grid[row][col] = attach(grid[row][col-1],'e','g','w') end
            end
            local candidates = {}
            for row = 1,size do
                for col = 1,size do
                    for _,d in ipairs(ScarabLayout.directions) do
                        if (d[1] == 'n' and row == size) or (d[1] == 's' and row == 1)
                            or (d[1] == 'e' and col == size) or (d[1] == 'w' and col == 1) then
                            candidates[#candidates+1] = {piece = grid[row][col],direction = d}
                        end
                    end
                end
            end
            local hole_count = room.final and 0 or random(2)+1
            local chosen = {}
            while #chosen < hole_count do
                local index = random(#candidates)
                if not candidates[index].hole then candidates[index].hole = #chosen+1; chosen[#chosen+1] = index end
            end
            for _,edge in ipairs(candidates) do
                local d = edge.direction
                local parent = edge.piece
                local outlet = d[1]
                -- All sockets keep one scale: widening only h also widens its
                -- mouth and makes the connecting tunnel walls fail to meet.
                local wide = random(3) == 1 or edge.hole ~= nil
                local long = random(2) == 1 and size == 2
                if long then parent = attach(parent,outlet,({'a','b','c'})[random(3)],'s'); outlet = 'n' end
                local cap = attach(parent,outlet,wide and 'h' or 'D',wide and 's' or 'n',wide and 4 or 0)
                if wide then
                    local b = piece_bounds(cap)
                    for _,other in ipairs(pieces) do
                        if other ~= cap and other ~= parent then
                            local a = piece_bounds(other)
                            if math.min(a[3],b[3])-math.max(a[1],b[1]) > 8
                                and math.min(a[4],b[4])-math.max(a[2],b[2]) > 8 then
                                table.remove(pieces)
                                cap = attach(parent,outlet,'D','n')
                                wide = false
                                break
                            end
                        end
                    end
                end
                if edge.hole then
                    local x,y = transform(cap,wide and 8.962 or 0,wide and 0 or 100)
                    portals[tostring(edge.hole)] = {x = x,y = y,target = room.id+1,
                        seed = random(2147483646),choice = edge.hole}
                end
            end
            room.cluster = size
        elseif room then
            local sockets = {}
            for key,port in pairs(ports[hub]) do sockets[direction(angle+port[3])] = key end
            for _,d in ipairs(ScarabLayout.directions) do
                local socket = sockets[d[1]]
                if socket then
                    if room.doors[d[1]] then
                        local parent,outlet = pieces[1],socket
                        local count = (d[1] == 'n' or d[1] == 's') and random(2) or 1
                        for _ = 1,count do
                            parent = attach(parent,outlet,({'a','b','c'})[random(3)],'s')
                            outlet = 'n'
                        end
                        local port = ports[parent.kind].n
                        local x,y = transform(parent,port[1],port[2])
                        portals[d[1]] = {x = x-64*scale*d[2],y = y-64*scale*d[3],
                            spawn_x = x-256*scale*d[2],spawn_y = y-256*scale*d[3],
                            target = room.doors[d[1]],opposite = d[4]}
                    else
                        local wide = (d[1] == 'n' or d[1] == 's') and random(3) == 1
                        attach(pieces[1],socket,wide and 'h' or 'D',wide and 's' or 'n',wide and 4 or 0)
                    end
                end
            end
        else
        local a = attach(pieces[1], 'n', 'a', 's')
        local b = attach(a, 'n', 'b', 's')
        local c = attach(b, 'n', 'c', 's')
        local f = attach(c, 'n', 'f', 's')
        local g = attach(f, 'e', 'g', 'w')
        attach(g, 'n', 'h', 's', 4)
        attach(g, 'e', 'D', 'n')
        attach(g, 's', 'D', 'n')
        end
        local bounds = {math.huge, math.huge, -math.huge, -math.huge}
        for _, piece in ipairs(pieces) do
            local box = ScarabKitAssets[piece.kind].bounds
            for _, corner in ipairs({{box[1],box[2]}, {box[1],box[4]}, {box[3],box[2]}, {box[3],box[4]}}) do
                local x,y = transform(piece, corner[1],corner[2])
                bounds[1],bounds[2] = math.min(bounds[1],x),math.min(bounds[2],y)
                bounds[3],bounds[4] = math.max(bounds[3],x),math.max(bounds[4],y)
            end
        end
        local dx,dy = (center_x or -25000)-(bounds[1]+bounds[3])/2,(center_y or 25000)-(bounds[2]+bounds[4])/2
        for _,port in pairs(portals) do
            port.x,port.y = port.x+dx,port.y+dy
            if port.spawn_x then port.spawn_x,port.spawn_y = port.spawn_x+dx,port.spawn_y+dy end
        end
        local triangles,render,buckets,floor_buckets = {},{},{},{}
        for _, piece in ipairs(pieces) do
            piece.x,piece.y = piece.x+dx,piece.y+dy
            for _,part in ipairs(ScarabKitRenderAssets[piece.kind]) do
                local x,y = transform(piece,part.x,part.y)
                local box = part.bounds
                local minx,miny,maxx,maxy = math.huge,math.huge,-math.huge,-math.huge
                for _,corner in ipairs({{box[1],box[2]},{box[1],box[4]},{box[3],box[2]},{box[3],box[4]}}) do
                    local bx,by = transform(piece,part.x+corner[1],part.y+corner[2])
                    minx,miny,maxx,maxy = math.min(minx,bx),math.min(miny,by),math.max(maxx,bx),math.max(maxy,by)
                end
                local entry = {file = part.file,x = x,y = y,angle = piece.angle,scale = piece.scale,bounds = {minx,miny,maxx,maxy}}
                render[#render+1] = entry
                for bx = math.floor(minx/128),math.floor(maxx/128) do
                    for by = math.floor(miny/128),math.floor(maxy/128) do
                        local key = bx..':'..by
                        buckets[key] = buckets[key] or {}
                        buckets[key][#buckets[key]+1] = entry.bounds
                    end
                end
            end
            for _, original in ipairs(ScarabKitAssets[piece.kind].floor) do
                local t = {}
                for i = 1,6,2 do t[i],t[i+1] = transform(piece,original[i],original[i+1]) end
                t.minx,t.maxx = math.min(t[1],t[3],t[5]),math.max(t[1],t[3],t[5])
                t.miny,t.maxy = math.min(t[2],t[4],t[6]),math.max(t[2],t[4],t[6])
                triangles[#triangles+1] = t
                for bx = math.floor(t.minx/128),math.floor(t.maxx/128) do
                    for by = math.floor(t.miny/128),math.floor(t.maxy/128) do
                        local key = bx..':'..by
                        floor_buckets[key] = floor_buckets[key] or {}
                        floor_buckets[key][#floor_buckets[key]+1] = t
                    end
                end
            end
        end
        bounds = {bounds[1]+dx,bounds[2]+dy,bounds[3]+dx,bounds[4]+dy}
        local x,y = transform(pieces[1],hub == 'f' and -136 or 0,hub == 'f' and -180 or 100)
        return {pieces = pieces, triangles = triangles, bounds = bounds, x = x, y = y,render = render,buckets = buckets,floor_buckets = floor_buckets,portals = portals}
    end
    -- Rectangle/triangle separating-axis test: overlapping visual covers must
    -- never obscure a floor, including the uncapped seeded transition mouths.
    function ScarabKitGeometry.intersectsFloor(plan,left,bottom,right,top)
        local cx,cy,hx,hy = (left+right)/2,(bottom+top)/2,(right-left)/2,(top-bottom)/2
        for bx = math.floor(left/128),math.floor(right/128) do
            for by = math.floor(bottom/128),math.floor(top/128) do
                for _,t in ipairs(plan.floor_buckets[bx..':'..by] or {}) do
                    if right >= t.minx and left <= t.maxx and top >= t.miny and bottom <= t.maxy then
                        local separated = false
                        for i = 1,5,2 do
                            local j = i == 5 and 1 or i+2
                            local nx,ny = t[j+1]-t[i+1],t[i]-t[j]
                            local a,b,c = nx*t[1]+ny*t[2],nx*t[3]+ny*t[4],nx*t[5]+ny*t[6]
                            local center,radius = nx*cx+ny*cy,math.abs(nx)*hx+math.abs(ny)*hy
                            if math.max(a,b,c) < center-radius or math.min(a,b,c) > center+radius then separated = true; break end
                        end
                        if not separated then return true end
                    end
                end
            end
        end
        return false
    end
    -- Covers only terrain outside every scenery section, never a floor or wall.
    function ScarabKitGeometry.exterior(plan,x,y,half,half_y)
        half_y = half_y or half
        for bx = math.floor((x-half)/128),math.floor((x+half)/128) do
            for by = math.floor((y-half_y)/128),math.floor((y+half_y)/128) do
                for _,b in ipairs(plan.buckets[bx..':'..by] or {}) do
                    if x+half >= b[1] and x-half <= b[3] and y+half_y >= b[2] and y-half_y <= b[4] then return false end
                end
            end
        end
        return true
    end
    function ScarabKitGeometry.contains(plan,x,y)
        for _,t in ipairs(plan.floor_buckets[math.floor(x/128)..':'..math.floor(y/128)] or {}) do
            if x >= t.minx-.01 and x <= t.maxx+.01 and y >= t.miny-.01 and y <= t.maxy+.01 then
                local a = (x-t[3])*(t[2]-t[4])-(t[1]-t[3])*(y-t[4])
                local b = (x-t[5])*(t[4]-t[6])-(t[3]-t[5])*(y-t[6])
                local c = (x-t[1])*(t[6]-t[2])-(t[5]-t[1])*(y-t[2])
                if not ((a < -.01 or b < -.01 or c < -.01) and (a > .01 or b > .01 or c > .01)) then return true end
            end
        end
        return false
    end
end)
