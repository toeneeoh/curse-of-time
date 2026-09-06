OnInit.global("TableHelpers", function()
    local random = math.random

    ---@type fun(n: integer, t: table): table
    function pickN(n, t)
        local seen = {}
        local out = {}
        while #out < n do
            local r = random(1, #t)
            if not seen[r] then
                seen[r] = true
                out[#out + 1] = t[r]
            end
        end
        return out
    end

    ---Returns the array index when found, otherwise false.
    ---@type fun(tbl: table, val: any): integer|false
    function TableHas(tbl, val)
        for i = 1, #tbl do
            if tbl[i] == val then
                return i
            end
        end

        return false
    end

    ---Removes a value from an unordered packed array.
    ---@type fun(tbl: table, val: any)
    function TableRemove(tbl, val)
        for i = 1, #tbl do
            if tbl[i] == val then
                tbl[i] = tbl[#tbl]
                tbl[#tbl] = nil
                break
            end
        end
    end
end)
