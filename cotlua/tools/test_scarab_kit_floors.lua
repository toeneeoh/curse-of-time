-- Pure layout checks; model seams still require a Warcraft playtest.
OnInit = {global = function(_,cb) cb(function() end) end}
dofile('cotlua/src/gameplay/dungeons/scarab/layout.lua')
dofile('cotlua/src/gameplay/dungeons/scarab/kit_assets.lua')
dofile('cotlua/src/gameplay/dungeons/scarab/kit_render_assets.lua')
dofile('cotlua/src/gameplay/dungeons/scarab/kit_geometry.lua')
local shapes = {}
for seed = 1,50 do
    local run = ScarabKitGeometry.floorRun(seed,6)
    local repeat_run = ScarabKitGeometry.floorRun(seed,6)
    for id,room in ipairs(run.rooms) do
        local p = ScarabKitGeometry.assemble(1.5,room,-25000,25000)
        local q = ScarabKitGeometry.assemble(1.5,repeat_run.rooms[id],-25000,25000)
        assert(#p.pieces == #q.pieces and p.x == q.x and p.y == q.y,'Floor is not deterministic')
        assert(p.bounds[1]-816 > -30000 and p.bounds[3]+816 < -20000
            and p.bounds[2]-816 > 20000 and p.bounds[4]+816 < 30000,
            string.format('Floor exceeds allocation: seed %d floor %d / %.1f x %.1f',seed,id,p.bounds[3]-p.bounds[1],p.bounds[4]-p.bounds[2]))
        local junctions = 0
        local wide = {}
        for i,piece in ipairs(p.pieces) do
            local other = q.pieces[i]
            assert(piece.kind == other.kind and piece.x == other.x and piece.y == other.y and piece.scale == other.scale)
            if piece.kind == 'g' then junctions = junctions+1 end
            assert(piece.scale == 1.5,'A chamber mouth uses a different scale than its tunnel')
            if piece.kind == 'h' then
                local b = ScarabKitGeometry.pieceBounds(piece)
                for _,a in ipairs(wide) do
                    assert(math.min(a[3],b[3])-math.max(a[1],b[1]) <= 8
                        or math.min(a[4],b[4])-math.max(a[2],b[2]) <= 8,'Wide chambers overlap')
                end
                wide[#wide+1] = b
            end
        end
        assert(junctions == 4 or junctions == 9,'Missing composite junction cluster')
        shapes[junctions] = true
        local holes = 0
        for _,port in pairs(p.portals) do
            holes = holes+1
            assert(port.target == id+1 and port.seed and ScarabKitGeometry.contains(p,port.x,port.y))
            assert(q.portals[tostring(port.choice)].seed == port.seed,'Hole route seed is not reproducible')
        end
        if holes > 0 then assert(p.portals['1'].seed ~= p.portals['2'].seed,'Hole choices have identical route seeds') end
        assert((id == 6 and holes == 0) or (id < 6 and holes >= 2 and holes <= 3))
        if seed <= 2 then
            local function snap(v) return math.floor(v/32)*32+16 end
            local function key(x,y) return x..':'..y end
            local frontier = {{snap(p.x),snap(p.y)}}
            local seen = {[key(frontier[1][1],frontier[1][2])] = true}
            local cursor = 1
            while cursor <= #frontier do
                local c = frontier[cursor]; cursor = cursor+1
                for _,d in ipairs({{32,0},{-32,0},{0,32},{0,-32}}) do
                    local x,y = c[1]+d[1],c[2]+d[2]
                    if not seen[key(x,y)] and ScarabKitGeometry.contains(p,x,y)
                        and ScarabKitGeometry.contains(p,x-16,y) and ScarabKitGeometry.contains(p,x+16,y)
                        and ScarabKitGeometry.contains(p,x,y-16) and ScarabKitGeometry.contains(p,x,y+16) then
                        seen[key(x,y)] = true; frontier[#frontier+1] = {x,y}
                    end
                end
            end
            for _,port in pairs(p.portals) do assert(seen[key(snap(port.x),snap(port.y))],'Floor progression hole disconnected') end
        end
    end
end
assert(shapes[4] and shapes[9])
print('PASS: seeded floors, 2x2/3x3 junctions, bounded enlarged chambers, connected progression holes and reserved final floor.')
