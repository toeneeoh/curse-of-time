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
        count = count or 12
        assert(count >= 4 and count <= 20 and count % 1 == 0)
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
        return {seed = seed, rooms = rooms, start = 1}
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
                    walls[#walls + 1] = {x = x, y = y}
                end
            end
        end
        return {floor = floor, walls = walls, portals = portals, width = width, height = height}
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
