--[[
    movespeed.lua

    A module that implements unit movespeeds above the 522 game limit.
]]

OnInit.final("Movespeed", function(Require)
    Require('Events')

    local CONST     = { MAX = 522 }
    local PERIOD    = 0.00625
    local MARGIN_SQ = (0.01) ^ 2

    -- Engine locals
    local GetX, GetY    = GetUnitX, GetUnitY
    local GetOrder      = GetUnitCurrentOrder
    local IsPaused      = IsUnitPaused
    local IssueOrder    = IssueImmediateOrderById
    local SetXBounded   = SetUnitXBounded
    local SetYBounded   = SetUnitYBounded
    local UnitTypeId    = GetUnitTypeId
    local RAD2DEG       = bj_RADTODEG
    local atan, sqrt    = math.atan, math.sqrt

    -- Order IDs
    local MOVE, SMART, HOLD = ORDER_ID_MOVE, ORDER_ID_SMART, ORDER_ID_HOLD_POSITION

    -- Tracked units: fast lookup + packed list
    local tracked = setmetatable({}, { __mode = "k" }) -- [unit] = data
    local list    = {}  -- array of data entries
    local count   = 0
    local timer   = CreateTimer()

    local function update_metrics()
        if RuntimeMetrics then
            RuntimeMetrics.movespeed = RuntimeMetrics.movespeed or {}
            RuntimeMetrics.movespeed.active = count
        end
    end

    local function remove_active_at(index)
        local removed = list[index]
        local last = list[count]

        list[index] = last
        if last then
            last.index = index
        end
        list[count] = nil
        count = count - 1
        removed.index = nil
        removed.active = false

        if count == 0 then
            PauseTimer(timer)
        end
        update_metrics()
    end

    -- Update facing on aggro
    local function on_aggro(u, target)
        local d = tracked[u]
        if d and d.active then
            local dy = GetY(target) - GetY(u)
            local dx = GetX(target) - GetX(u)
            BlzSetUnitFacingEx(u, RAD2DEG * atan(dy, dx))
        end
    end

    -- Update target / facing on order
    local function on_order(u, _, id, tx, ty)
        if tx == 0 and ty == 0 then return end
        local d = tracked[u]
        if not d then return end
        d.ox, d.oy = tx, ty
        if d.active then
            local dy = ty - GetY(u)
            local dx = tx - GetX(u)
            BlzSetUnitFacingEx(u, RAD2DEG * atan(dy, dx))
        end
    end

    -- Movement loop
    local function update()
        for i = count, 1, -1 do
            local d = list[i]
            local u = d.unit

            -- check for removed units
            if UnitTypeId(u) == 0 then
                remove_active_at(i)
                tracked[u] = nil
                EVENT_ON_AGGRO:unregister_unit_action(u, on_aggro)
                EVENT_ON_ORDER:unregister_unit_action(u, on_order)
            else
                local x, y = GetX(u), GetY(u)
                local dx, dy = x - d.x, y - d.y

                -- only move if outside margin and not paused
                if dx*dx + dy*dy > MARGIN_SQ and not IsPaused(u) then
                    local dist = sqrt(dx*dx + dy*dy)
                    local step = d.speed * PERIOD
                    dx, dy = dx/dist * step, dy/dist * step

                    local ord = GetOrder(u)
                    local ox, oy = d.ox, d.oy

                    -- check for overshoot → snap & hold
                    if (ord == MOVE or ord == SMART)
                       and (ox-x)*(ox-x) <= dx*dx
                       and (oy-y)*(oy-y) <= dy*dy then

                        SetXBounded(u, ox)
                        SetYBounded(u, oy)
                        d.x, d.y = ox, oy
                        IssueOrder(u, HOLD)
                    else
                        local nx, ny = x + dx, y + dy
                        SetXBounded(u, nx)
                        SetYBounded(u, ny)
                        d.x, d.y = nx, ny
                    end
                end
            end
        end
    end

    -- call whenever a unit's movespeed changes
    function MovespeedCheck(u, amount)
        local over = amount - CONST.MAX
        local d    = tracked[u]

        if over > 0 then
            if not d then
                -- start tracking this unit
                d = {
                    unit  = u,
                    x     = GetX(u),
                    y     = GetY(u),
                    ox    = GetX(u),
                    oy    = GetY(u),
                    speed = over,
                    active = false,
                }
                tracked[u]   = d

                -- register per‑unit events
                EVENT_ON_AGGRO:register_unit_action(u, on_aggro)
                EVENT_ON_ORDER:register_unit_action(u, on_order)
            end

            d.speed = over

            if not d.active then
                d.x, d.y = GetX(u), GetY(u)
                d.ox, d.oy = d.x, d.y
                count = count + 1
                list[count] = d
                d.index = count
                d.active = true

                if count == 1 then
                    TimerStart(timer, PERIOD, true, update)
                end
                update_metrics()
            end

        elseif d and d.active then
            remove_active_at(d.index)
        end
    end
end, Debug and Debug.getLine())
