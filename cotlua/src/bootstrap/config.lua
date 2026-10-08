--[[
    config.lua

    code that runs for players upon joining a lobby
]]

if LOCAL_JOIN_TIME == 0 then
    LOCAL_JOIN_TIME = os.clock()
end
