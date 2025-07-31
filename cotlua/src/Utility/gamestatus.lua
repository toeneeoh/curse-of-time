--[[
    gamestatus.lua

    A library that determines whether the game is in a single-player, replay, or multi-player state
]]

OnInit.final("GameStatus", function(Require)
    Require('Users')

    GAME_STATE = 0 ---@type integer 

    -- find an actual player
    local firstPlayer = User.first.player
    -- force the player to select a dummy unit
    local u = CreateUnit(firstPlayer, DUMMY_VISION, 0, 0, 0)
    SelectUnit(u, true)
    local selected = IsUnitSelected(u, firstPlayer)
    RemoveUnit(u)

    -- 0 = single-player, 1 = replay, 2 = multi-player
    if (selected) then
        GAME_STATE = (ReloadGameCachesFromDisk() and 0) or 1
    else
        -- if the unit wasn't selected instantly, the game is online
        GAME_STATE = 2
    end

end, Debug and Debug.getLine())
