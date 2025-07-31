--[[
    orders.lua

    This library handles order events
        (EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER,
        EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER,
        EVENT_PLAYER_UNIT_ISSUED_ORDER)
]]

OnInit.final("Orders", function(Require)
    Require('Frames')
    Require('Items')
    Require('Events')

    local event_on_order = EVENT_ON_ORDER

    -- define frequently used ids
    ORDER_ID_MOVE          = 851986
    ORDER_ID_HOLD_POSITION = 851972
    ORDER_ID_STOP          = 851993
    ORDER_ID_SMART         = 851971
    ORDER_ID_ATTACK        = 851983
    ORDER_ID_UNDEFEND      = 852056
    ORDER_ID_MANA_SHIELD   = 852589
    ORDER_ID_IMMOLATION    = 852177
    ORDER_ID_UNIMMOLATION  = 852178

    function OnOrder()
        local source = GetTriggerUnit() ---@type unit 
        local p      = GetTriggerPlayer()
        local pid    = GetPlayerId(p) + 1 ---@type integer 
        local id     = GetIssuedOrderId() ---@type integer 
        local i      = GetOrderTargetItem()
        local itm    = i and Item[i] or nil
        local x      = GetOrderPointX()
        local y      = GetOrderPointY()
        local target = GetOrderTargetUnit() ---@type unit 
        local targetX = target and GetUnitX(target)
        local targetY = target and GetUnitY(target)

        -- cache issued point / target
        local u = Unit[source]
        if u then
            if target or (x ~= 0 and y ~= 0) then
                u.orderX = targetX or x
                u.orderY = targetY or y
            end

            if pid <= PLAYER_CAP and target and IsUnitEnemy(target, p) then
                u.target = target
            end
        end

        -- event trigger
        event_on_order:trigger(source, target, id, x, y)

        -- item target
        if itm then
            -- prevent other units from attacking a bound item
            if id == ORDER_ID_ATTACK and (itm.owner and itm.owner ~= Player(pid - 1)) then
                IssueImmediateOrderById(source, ORDER_ID_HOLD_POSITION)
            end
        end
    end

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_ISSUED_ORDER, OnOrder)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, OnOrder)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, OnOrder)
end, Debug and Debug.getLine())
