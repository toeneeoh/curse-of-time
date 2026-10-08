--[[
    environment.lua

    This file is intended to be gitignored and contains temporary debug flags
]]

OnInit.final("environment", function()
    WRITE_HEIGHT_MAP = false
    VALIDATE_HEIGHT_MAP = false
end, Debug and Debug.getLine())
