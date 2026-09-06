OnInit.global("TextHelpers", function(Require)
    Require('Variables')

    local floor, fmod, min, max = math.floor, math.fmod, math.min, math.max
    local tostring, sub, concat = tostring, string.sub, table.concat

    ---Formats a number with comma group separators and no decimals.
    ---@param value number
    ---@return string
    function RealToString(value)
        if value >= INT_32_LIMIT then
            return tostring(value)
        end

        local negative = false
        if value < 0 then
            negative = true
            value = -value
        end

        local value_string = tostring(floor(value + 0.5))
        local length = #value_string
        if length <= 3 then
            return negative and ("-" .. value_string) or value_string
        end

        local first = length % 3
        if first == 0 then first = 3 end

        local parts = {}
        local index = 1
        parts[index] = sub(value_string, 1, first)
        index = index + 1

        for i = first + 1, length, 3 do
            parts[index] = ","
            parts[index + 1] = sub(value_string, i, i + 2)
            index = index + 2
        end

        local result = concat(parts)
        return negative and ("-" .. result) or result
    end

    ---@param position integer
    ---@param return_hex boolean
    ---@return integer|string, integer|nil, integer|nil
    function HealthGradient(position, return_hex)
        position = min(100, max(1, position))

        local color_stops = {
            { 1, { 255, 0, 0 } },
            { 10, { 255, 0, 0 } },
            { 70, { 242, 255, 64 } },
            { 100, { 8, 200, 2 } },
        }
        local start_stop, end_stop

        for i = 1, #color_stops - 1 do
            if position <= color_stops[i + 1][1] then
                start_stop = color_stops[i]
                end_stop = color_stops[i + 1]
                break
            end
        end

        local ratio = (position - start_stop[1]) / (end_stop[1] - start_stop[1])
        local color = {
            floor(start_stop[2][1] + ratio * (end_stop[2][1] - start_stop[2][1])),
            floor(start_stop[2][2] + ratio * (end_stop[2][2] - start_stop[2][2])),
            floor(start_stop[2][3] + ratio * (end_stop[2][3] - start_stop[2][3])),
        }

        if return_hex then
            return string.format("|cff%02X%02X%02X", color[1], color[2], color[3])
        end
        return color[1], color[2], color[3]
    end

    ---@type fun(tbl: table, text: string)
    function DisplayTextToTable(tbl, text)
        for i = 1, #tbl do
            local player = (type(tbl[i]) == "number" and Player(tbl[i] - 1)) or tbl[i]
            DisplayTextToPlayer(player, 0, 0, text)
        end
    end

    ---@type fun(tbl: table, dur: number, text: string)
    function DisplayTimedTextToTable(tbl, dur, text)
        for i = 1, #tbl do
            local player = (type(tbl[i]) == "number" and Player(tbl[i] - 1)) or tbl[i]
            DisplayTimedTextToPlayer(player, 0, 0, dur, text)
        end
    end

    ---@param time number
    ---@return string
    function RemainingTimeString(time)
        local minutes = time // 60
        local seconds = fmod(R2I(time), 60)
        return (minutes > 0 and minutes .. " minutes") or seconds .. " seconds"
    end
end)
