--[[
    attacked.lua

    This library registers and triggers the EVENT_PLAYER_UNIT_ATTACKED event
]]

OnInit.final("Attacked", function(Require)
    Require('Variables')
    Require('UnitEvent')
    Require('Events')

    local function on_attack()
        local source = GetAttacker()
        local target = GetTriggerUnit()
        local pid    = GetPlayerId(GetOwningPlayer(source)) + 1
        local tpid   = GetPlayerId(GetOwningPlayer(target)) + 1

        -- prevent team killing
        if (pid <= PLAYER_CAP and tpid <= PLAYER_CAP and pid ~= tpid and IsUnitAlly(source, GetOwningPlayer(target))) then
            IssueImmediateOrder(source, "stop")
        end

        -- trigger attack event
        EVENT_ON_ATTACK:trigger(source, target)

        return false
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_ATTACKED, on_attack)
end, Debug and Debug.getLine())
