OnInit.global("PersistencePaths", function(Require)
    Require('Variables')
    Require('Users')

    ---@param line integer
    ---@param contents string?
    ---@return string
    function GetLine(line, contents)
        if contents == nil then return "" end

        local count = 0
        for match in contents:gmatch("[^\n]*\n?") do
            if count == line then return match end
            count = count + 1
        end
        return ""
    end

    ---@type fun(pid: integer, slot: integer): string
    function GetCharacterPath(pid, slot)
        return MAP_NAME .. "\\" .. User[pid - 1].name .. "\\slot" .. slot .. ".pld"
    end

    ---@type fun(pid: integer): string
    function GetProfilePath(pid)
        return MAP_NAME .. "\\" .. User[pid - 1].name .. "\\profile.pld"
    end
end)
