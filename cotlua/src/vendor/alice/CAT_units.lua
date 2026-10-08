if Debug then Debug.beginFile "CAT Units" end
do
    --[[
    =============================================================================================================================================================
                                                                Complementary ALICE Template

                                    ALICE                       https://www.hiveworkshop.com/threads/a-l-i-c-e-interaction-engine.353126/
                                    TotalInitialization         https://www.hiveworkshop.com/threads/total-initialization.317099/
                                    Knockback Item ('Ikno')     Required for unit knockback.

    =============================================================================================================================================================
                                                                         U N I T S
    =============================================================================================================================================================

    This template contains a knockback system and various functions for unit actors.

    =============================================================================================================================================================
                                                            L I S T   O F   F U N C T I O N S
    =============================================================================================================================================================

    CAT_Knockback(whichUnit, vx, vy, vz)                Applies a knockback to the specified unit. NOTE: 3D knockbacks are not yet implemented!
    CAT_UnitEnableFriction(whichUnit, enable)           Enables or disables friction for the specified unit when it is sliding due to a knockback. Uses a
                                                        reference counter.
    CAT_GetUnitKnockbackSpeed(whichUnit)                Returns the x-, y-, and z-velocities of the knockback currently applied ot the specified unit.
    CAT_GetUnitVelocity3D(whichObject)                  Returns the x, y, and z-velocity of the specified unit.
    CAT_GetUnitVelocity2D(whichObject)                  Returns the x, y-velocity of the specified unit.
    CAT_GetUnitHeight(whichUnit)                        Returns the collision height of a unit.

    =============================================================================================================================================================
    ]]

    local sqrt                              = math.sqrt
    local max                               = math.max
    local cos                               = math.cos
    local sin                               = math.sin
    local atan2                             = math.atan

    local mt                                = {__mode = "k"}
    local knockbackItem                     = true       ---@type item
    local HiddenItems                       = {}        ---@type item[]
    local knockbackSpeed                    = setmetatable({}, {
                                                __index = function(parent, parentKey)
                                                    parent[parentKey] = setmetatable({}, {
                                                        __index = function(child, childKey)
                                                            child[childKey] = 0
                                                            return 0
                                                        end
                                                    })
                                                    return parent[parentKey]
                                                end,
                                                __mode = "k"
                                            })

    local monitorUnitX                      = setmetatable({}, mt)
    local monitorUnitY                      = setmetatable({}, mt)
    local monitorUnitZ                      = setmetatable({}, mt)

    local unitVelocityX                     = setmetatable({}, mt)
    local unitVelocityY                     = setmetatable({}, mt)
    local unitVelocityZ                     = setmetatable({}, mt)

    local unitHasFriction                   = setmetatable({}, {__index = function(self, key) self[key] = 0 return 0 end, __mode = "k"})
    local unitOriginalPropWindow            = setmetatable({}, mt)

    local UNIT_MAX_SPEED                    = 522
    local UNIT_MAX_SPEED_SQUARED            = UNIT_MAX_SPEED^2
    local WORLD_MIN_X                       = nil       ---@type number
    local WORLD_MIN_Y                       = nil       ---@type number
    local MONITOR_INTERVAL

    local function InitMonitorUnitVelocity(unit)
        monitorUnitX[unit], monitorUnitY[unit], monitorUnitZ[unit] = ALICE_GetCoordinates3D(unit)
        unitVelocityX[unit], unitVelocityY[unit], unitVelocityZ[unit] = 0, 0, 0
    end

    local function MonitorUnitVelocity(unit)
        local x, y, z = ALICE_GetCoordinates3D(unit)
        unitVelocityX[unit], unitVelocityY[unit], unitVelocityZ[unit] = (x - monitorUnitX[unit])/MONITOR_INTERVAL, (y - monitorUnitY[unit])/MONITOR_INTERVAL, (z - monitorUnitZ[unit])/MONITOR_INTERVAL
        monitorUnitX[unit], monitorUnitY[unit], monitorUnitZ[unit] = x, y, z
        return MONITOR_INTERVAL
    end

    -- these methods crash for some reason
    local function HideItem(item)
        if item ~= knockbackItem and IsItemVisible(item) then
            HiddenItems[#HiddenItems + 1] = item
            SetItemVisible(item, false)
        end
    end

    local function IsPointPathable(x, y)
        ALICE_ForAllObjectsInRangeDo(HideItem, x, y, 50, "item")
        SetItemPosition(knockbackItem, x, y)

        local xi = GetItemX(knockbackItem)
        local yi = GetItemY(knockbackItem)
        local isPathable = not IsTerrainPathable(x , y , PATHING_TYPE_WALKABILITY) and x - xi < 1 and x - xi > -1 and y - yi < 1 and y - yi > -1

        SetItemPosition(knockbackItem, WORLD_MIN_X, WORLD_MIN_Y)
        for i = 1, #HiddenItems do
            SetItemVisible(HiddenItems[i], true)
            HiddenItems[i] = nil
        end

        return isPathable
    end

    local function InitApplyKnockback(u)
        local data = ALICE_PairLoadData()
        local id = GetUnitTypeId(u)
        data.friction = (CAT_Data.UNIT_TYPE_FRICTION[id] or CAT_Data.DEFAULT_UNIT_FRICTION)
        data.collisionSize = CAT_Data.WIDGET_TYPE_COLLISION_RADIUS[id] or BlzGetUnitCollisionSize(u)
    end

    local function ApplyKnockback(u)
        local data = ALICE_PairLoadData()
        local phi = atan2(knockbackSpeed[u].y, knockbackSpeed[u].x)
        local xu, yu = ALICE_GetCoordinates2D(u)
        local x = xu + knockbackSpeed[u].x*ALICE_Config.MIN_INTERVAL
        local y = yu + knockbackSpeed[u].y*ALICE_Config.MIN_INTERVAL

        local dx = (knockbackSpeed[u].x > 0 and 1 or -1)*data.collisionSize
        local dy = (knockbackSpeed[u].y > 0 and 1 or -1)*data.collisionSize

        if knockbackItem then
            if IsTerrainWalkable(x + dx, y + dy) then
                SetUnitX(u, x)
                SetUnitY(u, y)
            else
                if not IsTerrainWalkable(x + dx + 24, y + dy) and not IsTerrainWalkable(x + dx - 24, y + dy) then
                    if IsTerrainWalkable(x + dx, yu + dy) then
                        SetUnitX(u, x)
                        knockbackSpeed[u].y = 0
                    else
                        knockbackSpeed[u].x = 0
                        knockbackSpeed[u].y = 0
                    end
                elseif not IsTerrainWalkable(x + dx, y + dy + 24) and not IsTerrainWalkable(x + dx, y + dy - 24) then
                    if IsTerrainWalkable(xu + dx, y + dy) then
                        SetUnitY(u, y)
                        knockbackSpeed[u].x = 0
                    else
                        knockbackSpeed[u].x = 0
                        knockbackSpeed[u].y = 0
                    end
                end
            end
        else
            SetUnitX(u, x)
            SetUnitY(u, y)
        end

        local velocity = sqrt(knockbackSpeed[u].x^2 + knockbackSpeed[u].y^2)
        if unitHasFriction[u] >= 0 then
            velocity = max(0, velocity - data.friction*(CAT_Data.TERRAIN_TYPE_FRICTION[GetTerrainType(x, y)] or 1)*ALICE_Config.MIN_INTERVAL)
        end

        knockbackSpeed[u].x = velocity*cos(phi)
        knockbackSpeed[u].y = velocity*sin(phi)

        if velocity == 0 then
            ALICE_PairDisable()
        end
    end

    ---@param unit unit
    ---@return number, number, number
    function CAT_GetUnitVelocity3D(unit)
        if unitVelocityX[unit] then
            local totalSpeedSquared = unitVelocityX[unit]^2 + unitVelocityY[unit]^2 + unitVelocityZ[unit]^2
            --If unit could not have traveled that fast naturally, it was most likely a teleport. Then, do not use velocity.
            if totalSpeedSquared > UNIT_MAX_SPEED_SQUARED then
                local totalSpeed = sqrt(totalSpeedSquared)
                if knockbackSpeed[unit] then --Collisions CAT
                    local kbSpeed = sqrt(knockbackSpeed[unit].x^2 + knockbackSpeed[unit].y^2 + knockbackSpeed[unit].z^2)
                    if totalSpeed > kbSpeed + UNIT_MAX_SPEED then
                        return knockbackSpeed[unit].x, knockbackSpeed[unit].y, knockbackSpeed[unit].z
                    else
                        return unitVelocityX[unit], unitVelocityY[unit], unitVelocityZ[unit]
                    end
                else
                    return 0, 0, 0
                end
            else
                return unitVelocityX[unit], unitVelocityY[unit], unitVelocityZ[unit]
            end
        elseif knockbackSpeed[unit] then
            return knockbackSpeed[unit].x, knockbackSpeed[unit].y, knockbackSpeed[unit].z
        else
            return 0, 0, 0
        end
    end

    ---@param unit unit
    ---@return number, number
    function CAT_GetUnitVelocity2D(unit)
        if unitVelocityX[unit] then
            local totalSpeedSquared = unitVelocityX[unit]^2 + unitVelocityY[unit]^2
            --If unit could not have traveled that fast naturally, it was most likely a teleport. Then, do not use velocity.
            if totalSpeedSquared > UNIT_MAX_SPEED_SQUARED then
                local totalSpeed = sqrt(totalSpeedSquared)
                if knockbackSpeed[unit] then
                    local kbSpeed = sqrt(knockbackSpeed[unit].x^2 + knockbackSpeed[unit].y^2)
                    if totalSpeed > kbSpeed + UNIT_MAX_SPEED then
                        return knockbackSpeed[unit].x, knockbackSpeed[unit].y
                    else
                        return unitVelocityX[unit], unitVelocityY[unit]
                    end
                else
                    return 0, 0
                end
            else
                return unitVelocityX[unit], unitVelocityY[unit]
            end
        elseif knockbackSpeed[unit] then
            return knockbackSpeed[unit].x, knockbackSpeed[unit].y
        else
            return 0, 0
        end
    end

    --=============================================================================================================================================================================
    --Public Functions         
    --=============================================================================================================================================================================

    ---Applies a knockback to the specified unit. NOTE: 3D knockbacks are not yet implemented!
    ---@param whichUnit unit
    ---@param vx number
    ---@param vy number
    ---@param vz number
    function CAT_Knockback(whichUnit, vx, vy, vz)
        local identifier = ALICE_FindIdentifier(whichUnit, "unit", "corpse")
        if not ALICE_HasSelfInteraction(whichUnit, ApplyKnockback, identifier) then
            ALICE_AddSelfInteraction(whichUnit, ApplyKnockback, identifier)
        end

        knockbackSpeed[whichUnit].x = (knockbackSpeed[whichUnit].x) + vx
        knockbackSpeed[whichUnit].y = (knockbackSpeed[whichUnit].y) + vy
    end

    ---Returns the x-, y-, and z-velocities of the knockback currently applied ot the specified unit.
    ---@param unit unit
    ---@return number, number, number
    function CAT_GetUnitKnockbackSpeed(unit)
        return knockbackSpeed[unit].x, knockbackSpeed[unit].y, knockbackSpeed[unit].z
    end

    ---Enables or disables friction for the specified unit when it is sliding due to a knockback. Uses a reference counter.
    ---@param unit unit
    ---@param enable boolean
    function CAT_UnitEnableFriction(unit, enable)
        if enable then
            unitHasFriction[unit] = unitHasFriction[unit] + 1
            if unitHasFriction[unit] > 1 then
                print("|cffff0000Warning:|r Friction enabled with CAT_UnitEnableFriction, but it was not disabled.")
            end
        else
            unitHasFriction[unit] = unitHasFriction[unit] - 1
        end
    end

    ---Returns the collision height of a unit.
    ---@param unit unit
    ---@return number
    function CAT_GetUnitHeight(unit)
        local id = GetUnitTypeId(unit)
        return CAT_Data.WIDGET_TYPE_HEIGHT[id] or CAT_Data.DEFAULT_UNIT_HEIGHT_FACTOR*BlzGetUnitCollisionSize(unit)
    end

    --=============================================================================================================================================================================

    OnInit.global("CAT_Units", function()
        MONITOR_INTERVAL = (0.1 // ALICE_Config.MIN_INTERVAL)*ALICE_Config.MIN_INTERVAL

        if CAT_Data.MONITOR_UNIT_VELOCITY then
            ALICE_OnCreationAddSelfInteraction("unit", MonitorUnitVelocity)
        end

        ALICE_FuncSetInit(MonitorUnitVelocity, InitMonitorUnitVelocity)
        ALICE_FuncDistribute(MonitorUnitVelocity, 0.1)
        ALICE_FuncSetName(MonitorUnitVelocity, "MonitorUnitVelocty")
        ALICE_FuncSetName(ApplyKnockback, "ApplyKnockback")

        ALICE_FuncSetInit(ApplyKnockback, InitApplyKnockback)
    end)
end
