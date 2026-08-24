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

    local gtu, gtp, gpi, gioi, goti, gox, goy, gotu, gux, guy = GetTriggerUnit, GetTriggerPlayer, GetPlayerId, GetIssuedOrderId, GetOrderTargetItem, GetOrderPointX, GetOrderPointY, GetOrderTargetUnit, GetUnitX, GetUnitY

    local function on_order()
        local source = gtu() ---@type unit 
        local p      = gtp()
        local pid    = gpi(p) + 1 ---@type integer 
        local id     = gioi() ---@type integer 
        local i      = goti()
        local itm    = i and Item[i] or nil
        local x      = gox()
        local y      = goy()
        local target = gotu() ---@type unit 
        local targetX = target and gux(target)
        local targetY = target and guy(target)

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

    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_ISSUED_ORDER, on_order)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_ISSUED_TARGET_ORDER, on_order)
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_ISSUED_POINT_ORDER, on_order)
end, Debug and Debug.getLine())
