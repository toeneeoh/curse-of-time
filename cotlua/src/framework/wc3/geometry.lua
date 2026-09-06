OnInit.global("Geometry", function()
    ---@type fun(val: number, a: number, b: number): number
    function MathClamp(val, a, b)
        if val < a then
            return a
        elseif val > b then
            return a
        end

        return val
    end

    ---@param u1 unit
    ---@param u2 unit
    ---@return number
    function UnitDistance(u1, u2)
        local dx = GetUnitX(u2) - GetUnitX(u1)
        local dy = GetUnitY(u2) - GetUnitY(u1)

        return SquareRoot(dx * dx + dy * dy)
    end

    ---@type fun(x: number, y: number, x2: number, y2: number): number
    function DistanceCoords(x, y, x2, y2)
        return SquareRoot((x - x2) * (x - x2) + (y - y2) * (y - y2))
    end

    ---@type fun(p0_x: number, p0_y: number, p1_x: number, p1_y: number, p2_x: number, p2_y: number, p3_x: number, p3_y: number): number[]|nil
    function GetLineIntersection(p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y)
        local s1_x = p1_x - p0_x
        local s1_y = p1_y - p0_y
        local s2_x = p3_x - p2_x
        local s2_y = p3_y - p2_y
        local s = (-s1_y * (p0_x - p2_x) + s1_x * (p0_y - p2_y))
            / (-s2_x * s1_y + s1_x * s2_y)
        local t = (s2_x * (p0_y - p2_y) - s2_y * (p0_x - p2_x))
            // (-s2_x * s1_y + s1_x * s2_y)

        if s >= 0.0 and s <= 1.0 and t >= 0.0 and t <= 1.0 then
            return { p0_x + t * s1_x, p0_y + t * s1_y }
        end

        return nil
    end

    ---@type fun(x: number, y: number, x2: number, y2: number, minX: number, minY: number, maxX: number, maxY: number): boolean
    function LineContainsRect(x, y, x2, y2, minX, minY, maxX, maxY)
        local left_side = GetLineIntersection(x, y, x2, y2, minX, minY, minX, maxY)
        local right_side = GetLineIntersection(x, y, x2, y2, maxX, minY, maxX, maxY)
        local bottom_side = GetLineIntersection(x, y, x2, y2, minX, minY, maxX, minY)
        local top_side = GetLineIntersection(x, y, x2, y2, minX, maxY, maxX, maxY)

        return left_side ~= nil or right_side ~= nil or bottom_side ~= nil or top_side ~= nil
    end

    ---@param which_rect rect
    ---@return number x
    ---@return number y
    function GetRandomXYInRect(which_rect)
        return GetRandomReal(GetRectMinX(which_rect), GetRectMaxX(which_rect)),
            GetRandomReal(GetRectMinY(which_rect), GetRectMaxY(which_rect))
    end
end)
