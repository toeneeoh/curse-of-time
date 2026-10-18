-- One point always grants one base stat. Later levels award more points.
OnInit.global("StatAllocationModel", function()
    StatAllocationModel = {POINTS_PER_LEVEL = 8, GROWTH_START = 100,
        GROWTH_INTERVAL = 10, SAVE_FIELDS = 12}
    local M = StatAllocationModel
    local function integer(value, maximum)
        return type(value) == "number" and value == value and value % 1 == 0
            and value >= 0 and value <= maximum
    end
    function M.create()
        return {purchased = 0, flat = {0, 0, 0}, automatic = 0,
            ratio = {1, 1, 8}, carry = {0, 0, 0}, revision = 0}
    end
    function M.pointsPerLevel(level)
        local step = math.max(0, (level - M.GROWTH_START) // M.GROWTH_INTERVAL)
        return M.POINTS_PER_LEVEL + 27 * step // 10
    end
    function M.earned(level)
        local total = math.max(0, level - 1) * M.POINTS_PER_LEVEL
        local steps = math.max(0, (level - M.GROWTH_START) // M.GROWTH_INTERVAL)
        for step = 1, steps do
            local levels = math.min(M.GROWTH_INTERVAL, level - M.GROWTH_START - step * M.GROWTH_INTERVAL + 1)
            total = total + levels * (27 * step // 10)
        end
        return total
    end
    function M.value(starting, assigned)
        return starting + assigned
    end
    function M.budget(level, data)
        return M.earned(level) + data.purchased
    end
    function M.available(level, data)
        local a = data.flat
        return M.budget(level, data) - a[1] - a[2] - a[3]
    end
    function M.validate(data, level)
        if not integer(data.purchased, 10000000) or not integer(data.automatic, 1) then return false end
        local weight = 0
        for i = 1, 3 do
            if not integer(data.flat[i], 10000000)
                or not integer(data.ratio[i], 100) then return false end
            weight = weight + data.ratio[i]
            if not integer(data.carry[i] + 300, 600) then return false end
        end
        return (weight > 0 or data.automatic == 0) and M.available(level, data) >= 0
    end
    -- Smooth weighted assignment retains integer remainders between awards.
    -- A 1:1:8 plan awards exactly 1/1/8 over ten points, not 1/1/6 every level.
    function M.distribute(data, count)
        local weight = data.ratio[1] + data.ratio[2] + data.ratio[3]
        local carry = data.carry
        for _ = 1, count do
            local best
            for i = 1, 3 do
                carry[i] = carry[i] + data.ratio[i]
                if data.ratio[i] > 0 and (not best or carry[i] > carry[best]) then best = i end
            end
            carry[best] = carry[best] - weight
            data.flat[best] = data.flat[best] + 1
        end
    end
    function M.append(result, data)
        assert(data, "Missing stat-allocation data")
        result[#result + 1] = 2
        result[#result + 1] = data.purchased
        for i = 1, 3 do result[#result + 1] = data.flat[i] end
        result[#result + 1] = data.automatic
        for i = 1, 3 do result[#result + 1] = data.ratio[i] end
        for i = 1, 3 do result[#result + 1] = data.carry[i] + 300 end
    end
    function M.decode(values, index, level)
        if values[index] ~= 2 then return nil, "Unsupported stat-allocation save data. Create a new character." end
        local data = M.create()
        data.purchased = values[index + 1]
        local cursor = index + 2
        for i = 1, 3 do data.flat[i] = values[cursor]; cursor = cursor + 1 end
        data.automatic = values[cursor]; cursor = cursor + 1
        for i = 1, 3 do data.ratio[i] = values[cursor]; cursor = cursor + 1 end
        for i = 1, 3 do
            if type(values[cursor]) ~= "number" then return nil, "Incomplete stat-allocation save data." end
            data.carry[i] = values[cursor] - 300; cursor = cursor + 1
        end
        if not M.validate(data, level) then return nil, "Invalid stat-allocation save data." end
        return data
    end
end)
