--[[
    unitevent.lua

    This module provide a simple way to register a player unit event to function
    for all players without redundant trigger objects.
]]

OnInit.global("UnitEvent", function()

    local triggers = {} ---@type trigger[] 

    ---@type fun(event: playerunitevent, filterfunc: function)
    function RegisterPlayerUnitEvent(event, filterfunc)
        if triggers[event] == nil then
            triggers[event] = CreateTrigger()
            for k = 0, bj_MAX_PLAYER_SLOTS do
                if GetPlayerController(Player(k)) ~= MAP_CONTROL_NONE then
                    TriggerRegisterPlayerUnitEvent(triggers[event], Player(k), event, nil)
                end
            end
        end
        TriggerAddCondition(triggers[event], Filter(filterfunc))
    end
end, Debug and Debug.getLine())
