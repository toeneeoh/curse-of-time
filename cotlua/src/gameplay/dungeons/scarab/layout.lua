-- Pure seeded topology and chamber geometry. No native handles or global RNG.
OnInit.global("ScarabLayout", function()
    ScarabLayout = {}
    local directions = {{"n", 0, 1, "s"}, {"e", 1, 0, "w"}, {"s", 0, -1, "n"}, {"w", -1, 0, "e"}}
    ScarabLayout.directions = directions
    ScarabLayout.width, ScarabLayout.height, ScarabLayout.cell = 41, 49, 64
    function ScarabLayout.random(seed)
        local state = math.floor(seed) % 2147483646 + 1
        return function(limit)
            state = state * 48271 % 2147483647
            return state % limit + 1
        end
    end
    function ScarabLayout.generate(seed, count)
        assert(type(seed) == "number" and seed == seed and math.abs(seed) < 2147483647)
        count = count or 32
        assert(count >= 4 and count <= 40 and count % 1 == 0)
        local random, rooms, occupied = ScarabLayout.random(seed), {}, {}
        local function add(x, y)
            local room = {id = #rooms + 1, x = x, y = y, doors = {}, seed = random(2147483646)}
            rooms[room.id], occupied[x .. ":" .. y] = room, room
            return room
        end
        add(0, 0)
        while #rooms < count do
            local candidates = {}
            for _, room in ipairs(rooms) do
                for _, d in ipairs(directions) do
                    local x, y = room.x + d[2], room.y + d[3]
                    if math.abs(x) <= 3 and math.abs(y) <= 3 and not occupied[x .. ":" .. y] then
                        candidates[#candidates + 1] = {room, d, x, y}
                    end
                end
            end
            local edge = candidates[random(#candidates)]
            local room = add(edge[3], edge[4])
            edge[1].doors[edge[2][1]], room.doors[edge[2][4]] = room.id, edge[1].id
        end
        -- A few loops allow alternate exploration/backtracking, not just a maze tree.
        for _, room in ipairs(rooms) do
            for _, d in ipairs(directions) do
                local neighbor = occupied[(room.x + d[2]) .. ":" .. (room.y + d[3])]
                if neighbor and not room.doors[d[1]] and random(4) == 1 then
                    room.doors[d[1]], neighbor.doors[d[4]] = neighbor.id, room.id
                end
            end
        end
        -- A deep, seeded approach to discover; boss/access mechanics remain separate.
        local distances, queue, cursor, deepest = {[1] = 0}, {1}, 1, 0
        while cursor <= #queue do
            local id = queue[cursor]; cursor = cursor + 1
            for _, direction in ipairs(directions) do
                local target = rooms[id].doors[direction[1]]
                if target and distances[target] == nil then
                    distances[target] = distances[id] + 1
                    deepest = math.max(deepest, distances[target])
                    queue[#queue + 1] = target
                end
            end
        end
        local approaches = {}
        for _, room in ipairs(rooms) do
            room.distance = distances[room.id]
            if room.id ~= 1 and room.distance >= math.max(1, deepest - 1) then approaches[#approaches + 1] = room.id end
        end
        return {seed = seed, rooms = rooms, start = 1, approach = approaches[random(#approaches)]}
    end
    function ScarabLayout.chamber(room)
        local width, height = ScarabLayout.width, ScarabLayout.height
        local floor, portals, random = {}, {}, ScarabLayout.random(room.seed)
        local function carve(cx, cy, rx, ry)
            for y = math.max(3, cy - ry), math.min(height - 2, cy + ry) do
                for x = math.max(3, cx - rx), math.min(width - 2, cx + rx) do
                    if ((x - cx) / rx)^2 + ((y - cy) / ry)^2 <= 1 then floor[(y - 1) * width + x] = true end
                end
            end
        end
        local function tunnel(x, y, tx, ty)
            while x ~= tx or y ~= ty do
                carve(x, y, 2, 2)
                if x ~= tx and (y == ty or random(2) == 1) then x = x + (tx > x and 1 or -1)
                else y = y + (ty > y and 1 or -1) end
            end
            carve(tx, ty, 2, 2)
        end
        carve(21, 25, 6, 7)
        for _ = 1, 5 do
            local x, y = 21 + random(15) - 8, 25 + random(19) - 10
            tunnel(21, 25, x, y); carve(x, y, random(3) + 2, random(3) + 2)
        end
        local positions = {n = {21, 45}, e = {37, 25}, s = {21, 5}, w = {5, 25}}
        for _, d in ipairs(directions) do
            if room.doors[d[1]] then
                local position = positions[d[1]]
                tunnel(21, 25, position[1], position[2])
                portals[d[1]] = {x = position[1], y = position[2], target = room.doors[d[1]], opposite = d[4]}
            end
        end
        local walls = {}
        for y = 2, height - 1 do
            for x = 2, width - 1 do
                local index = (y - 1) * width + x
                if not floor[index] and (floor[index - 1] or floor[index + 1] or floor[index - width] or floor[index + width]) then
                    local nx, ny = 0, 0
                    for _, direction in ipairs(directions) do
                        if floor[(y + direction[3] - 1) * width + x + direction[2]] then
                            nx, ny = nx - direction[2], ny - direction[3]
                        end
                    end
                    local length = math.sqrt(nx * nx + ny * ny)
                    walls[#walls + 1] = {x = x, y = y, nx = length > 0 and nx / length or 0,
                        ny = length > 0 and ny / length or 0}
                end
            end
        end
        return {floor = floor, walls = walls, portals = portals, width = width, height = height}
    end
    -- Seeded combat placements use open floor with clearance, never door mouths.
    function ScarabLayout.encounter(room, layout)
        if room.id == 1 then return {} end -- Safe arrival chamber.
        local random = ScarabLayout.random(room.seed + 719)
        local candidates, enemies = {}, {}
        local function open(x, y)
            for dy = -1, 1 do for dx = -1, 1 do
                if not layout.floor[(y + dy - 1) * layout.width + x + dx] then return false end
            end end
            if (x - 21)^2 + (y - 25)^2 < 6^2 then return false end
            for _, portal in pairs(layout.portals) do
                if (x - portal.x)^2 + (y - portal.y)^2 < 7^2 then return false end
            end
            return true
        end
        for y = 4, layout.height - 3 do for x = 4, layout.width - 3 do
            if open(x, y) then candidates[#candidates + 1] = {x = x, y = y} end
        end end
        local centers = {}
        for _ = 1, 3 do
            local viable = {}
            for _, point in ipairs(candidates) do
                local clear = true
                for _, center in ipairs(centers) do
                    if (point.x - center.x)^2 + (point.y - center.y)^2 < 5^2 then clear = false; break end
                end
                if clear then viable[#viable + 1] = point end
            end
            if #viable == 0 then break end
            local center = viable[random(#viable)]
            centers[#centers + 1] = center
            local offsets = {{0, 0}, {2, 0}, {-2, 0}, {0, 2}}
            local pack = random(3)
            for index, offset in ipairs(offsets) do
                local x, y = center.x + offset[1], center.y + offset[2]
                if open(x, y) then
                    local role = index == 1 and (pack == 2 and 'guard' or pack == 3 and 'spitter' or 'swarm') or 'swarm'
                    enemies[#enemies + 1] = {x = x, y = y, role = role, facing = random(360) - 1}
                end
            end
        end
        return enemies
    end

    function ScarabLayout.buffers()
        local buffers = {}
        for row = 0, 1 do
            for column = 0, 2 do
                -- Move the west edge 640 inward without pushing the eastmost
                -- room out of the allocated corner; buffers still do not overlap.
                buffers[#buffers + 1] = {x = -27712 + column * 2880, y = 22208 + row * 4608}
            end
        end
        return buffers
    end
end, Debug and Debug.getLine())
