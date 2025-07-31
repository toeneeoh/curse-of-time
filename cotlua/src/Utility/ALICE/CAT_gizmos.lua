if Debug then Debug.beginFile("CAT Gizmos") end
do
    --[[
    ===============================================================================================================================================================================
                                                                        Complementary ALICE Template
                                                                                by Antares

                                    Requires:
                                    ALICE                               https://www.hiveworkshop.com/threads/a-l-i-c-e-interaction-engine.353126/
                                    Data CAT
                                    PrecomputedHeightMap (optional)     https://www.hiveworkshop.com/threads/precomputed-synchronized-terrain-height-map.353477/
                                    TotalInitialization                 https://www.hiveworkshop.com/threads/total-initialization.317099/

    ===============================================================================================================================================================================
                                                                                  G I Z M O S
    ===============================================================================================================================================================================

    This template contains several functions that help with creating and managing gizmos*. It also includes the terrain collision check function.

        *Objects represented by a table with coordinate fields .x, .y, .z, velocity fields .vx, .vy, .vz, and a special effect .visual.

    How to create a gizmo:
    Create a table that contains coordinate and velocity fields. If you want 3D movement, you need to include z-coordinates and z-velocity, otherwise x and y suffice. Also create
    the .visual field in your gizmo for the special effect.

    To interface the gizmos with the functions in this template, add self-interactions to your gizmos. Function parameters are customized by editing table fields of your gizmo.
    Some parameters cannot be changed after creation, others can. In many cases, you can easily alter the implementation of a function to make a parameter changeable.

    Example:

    Football = {
        x = nil,
        y = nil,
        z = nil,
        vx = nil,
        vy = nil,
        vz = nil,
        visual = nil,
        --ALICE
        identifier = "football",
        interactions = {
            football = CAT_CollisionCheck3D,
            self = {
                CAT_MoveBallistic,
                CAT_CheckTerrainCollision
            }
        },
        --CAT
        onTerrainCollision = CAT_OnTerrainCollisionBounce,
        onTerrainCallback = BounceFootball,
        onGizmoCollision = CAT_GizmoBounce3D,
        friction = 100,
        elasticity = 0.7,
        collisionRadius = 35
    }

    Football.__index = Football

    function Football.create(x, y, z, vx, vy, vz)
        local new = {}
        setmetatable(new, Football)
        new.x, new.y, new.z = x, y, z
        new.vx, new.vy, new.vz = vx, vy, vz
        new.visual = AddSpecialEffect(effectPath, x, y)
        BlzSetSpecialEffectZ(effectPath, z)
        ALICE_Create(new)
    end

    ===============================================================================================================================================================================
                                                                        L I S T   O F   F U N C T I O N S             
    ===============================================================================================================================================================================

    CAT_Decay                                                   Makes your gizmo get destroyed after X seconds, where X is set through the .lifetime field of your gizmo table.
                                                                With the optional .onExpire field, you can set a callback function that is invoked when the gizmo decays.

    CAT_CheckTerrainCollision                                   When enabled, checks for terrain collision and invokes a callback function upon collision. The callback function is
                                                                retrieved from the .onTerrainCollision field. It is called with the parameters
                                                                (gizmo, normalSpeed, tangentialSpeed, totalSpeed). If the onTerrainCollision field is empty, ALICE_Kill will be
                                                                invoked instead. Requires the .collisionRadius field of your table to be set.
    CAT_TerrainBounce                                           A function for onTerrainCollision. Uses the .elasticity field to determine the elasticity of the collision. This
                                                                value is multiplied by the CAT_Data.TERRAIN_TYPE_ELASTICITY, which can be set in the Objects CAT.
    CAT_OutOfBoundsCheck                                        Checks if the gizmo has left the playable map area and destroys it if it does. You can set the .reflectsOnBounds
                                                                field of your gizmo table to true to make it reflect on the bounds instead of being destroyed. Uses the .maxSpeed
                                                                field to determine how often the out-of-bounds check is performed, or CAT_Data.DEFAULT_GIZMO_MAX_SPEED if not set.

    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    CAT_AutoZ(gizmo)                                            Initializes the gizmo's z-coordinate to GetTerrainZ(x, y) + gizmo.collisionRadius.

    CAT_SetGizmoBounds(xMin, yMin, xMax, yMax)                  Change the gizmo bounds for CAT_OutOfBoundsCheck. The default bounds are the world bounds. z-bounds are set in the
                                                                config.

    CAT_GlobalReplace(widgetId, widgetType, constructorFunc)    A function that allows you to place widgets using the World Editor and replace them on map initialization with
                                                                gizmos. The constructorFunc is the function creating your gizmo. It will be called with the parameters
                                                                (x, y, z, life, mana, owner, facing, unit) if the replaced widget is a unit, (x, y, z, life, widget) if the widget is
                                                                a destructable, and (x, y, z, widget) if it is an item.
    CAT_LaunchOffset(gizmo)                                     Shifts the position of the gizmo by its launchOffset field in the direction of its velocity.

    ===============================================================================================================================================================================
    ]]

    local sqrt                              = math.sqrt
    local min                               = math.min
    local atan2                             = math.atan

    local INTERVAL                          = nil       ---@type number

    local gizmoBoundMinX                   = nil       ---@type number
    local gizmoBoundMinY                   = nil       ---@type number
    local gizmoBoundMaxX                   = nil       ---@type number
    local gizmoBoundMaxY                   = nil       ---@type number

    local GetTerrainZ                       = nil       ---@type function
    local moveableLoc                       = nil       ---@type location

    --=============================================================================================================================================================================

    function CAT_Decay(gizmo)
        gizmo.lifetime = gizmo.lifetime - INTERVAL
        if gizmo.lifetime <= 0 then
            if gizmo.onExpire then
                gizmo:onExpire()
            end
            ALICE_Kill(gizmo)
        end
    end

    ---@param gizmo table
    ---@param x number
    ---@param y number
    function CAT_TerrainBounce(gizmo, x, y, z)
        --Get normal vector of surface.
        local z_x1 = GetTerrainZ(x - 4, y)
        local z_x2 = GetTerrainZ(x + 4, y)
        local z_y1 = GetTerrainZ(x, y - 4)
        local z_y2 = GetTerrainZ(x, y + 4)
        local dz_x = (z_x2 - z_x1)/8
        local dz_y = (z_y2 - z_y1)/8
        local vec1_z = dz_x
        local vec2_z = dz_y
        local vecN_x = -vec1_z
        local vecN_y = -vec2_z
        local vecN_z = 1
        local norm = sqrt(vecN_x^2 + vecN_y^2 + vecN_z^2)
        vecN_x = vecN_x/norm
        vecN_y = vecN_y/norm
        vecN_z = vecN_z/norm

        --object is coming from below the ground.
        local normalSpeed = -(vecN_x*gizmo.vx + vecN_y*gizmo.vy + vecN_z*gizmo.vz)
        if normalSpeed < 0 then
            return
        end

        local e = (1 + gizmo.elasticity*(CAT_Data.TERRAIN_TYPE_ELASTICITY[GetTerrainType(x, y)] or 1))

        --Householder transformation.
        local H11 = 1 - e*vecN_x^2
        local H12 = -e*vecN_x*vecN_y
        local H13 = -e*vecN_x*vecN_z
        local H21 = H12
        local H22 = 1 - e*vecN_y^2
        local H23 = -e*vecN_y*vecN_z
        local H31 = H13
        local H32 = H23
        local H33 = 1 - e*vecN_z^2

        if gizmo.onTerrainCallback ~= nil then
            local totalSpeed = sqrt(gizmo.vx^2 + gizmo.vy^2 + gizmo.vz^2)
            local tangentialSpeed = sqrt(totalSpeed^2 - normalSpeed^2)
            gizmo:onTerrainCallback(normalSpeed, tangentialSpeed, totalSpeed)
        end

        local newvx = H11*gizmo.vx + H12*gizmo.vy + H13*gizmo.vz
        local newvy = H21*gizmo.vx + H22*gizmo.vy + H23*gizmo.vz
        local newvz = H31*gizmo.vx + H32*gizmo.vy + H33*gizmo.vz

        gizmo.vx, gizmo.vy, gizmo.vz = newvx, newvy, newvz
        gizmo.vzOld = gizmo.vz
        gizmo.hasCollided = true

        local vHorizontal = sqrt(newvx^2 + newvy^2)
        local vTotal = sqrt(vHorizontal^2 + newvz^2)
        local overShoot = sqrt((x - gizmo.x)^2 + (y - gizmo.y)^2)*vTotal/(vHorizontal + 0.01)
        gizmo.x, gizmo.y, gizmo.z = x + gizmo.vx/vTotal*overShoot, y + gizmo.vy/vTotal*overShoot, gizmo.z + gizmo.vz/vTotal*overShoot

        if vecN_x*gizmo.vx + vecN_y*gizmo.vy + vecN_z*gizmo.vz < CAT_Data.MINIMUM_BOUNCE_VELOCITY then
            gizmo.theta = atan2(gizmo.vz, sqrt(gizmo.vx^2 + gizmo.vy^2))
            gizmo.isAirborne = false
        end
    end

    local function GetTerrainCollisionPoint(gizmo)
        local x, y, z = gizmo.x, gizmo.y, gizmo.z
        local interval = ALICE_TimeElapsed - (gizmo.lastTerrainCollisionCheck or ALICE_TimeElapsed)
        local dx, dy, dz = gizmo.vx*interval, gizmo.vy*interval, gizmo.vz*interval
        local dist = sqrt(dx^2 + dy^2 + dz^2)
        local iterations = math.log(dist/4, 2) // 1
        local p = 0.5
        local shift = 0.5

        for __ = 1, iterations do
            shift = 0.5*shift
            if z - p*dz > GetTerrainZ(x - p*dx, y - p*dy) then
                p = p - shift
            else
                p = p + shift
            end
        end
        return x - p*dx, y - p*dy
    end

    function CAT_CheckTerrainCollision(gizmo)
        if gizmo.isAirborne == false then
            ALICE_PairPause()
        end
        local height = GetTerrainZ(gizmo.x, gizmo.y)
        local dist = gizmo.z - height - gizmo.collisionRadius
        local vHorizontal = sqrt(gizmo.vx^2 + gizmo.vy^2)
        if dist < 0 then
            if gizmo.onTerrainCollision then
                gizmo:onTerrainCollision(GetTerrainCollisionPoint(gizmo))
            else
                ALICE_Kill(gizmo)
            end
            gizmo.lastTerrainCollisionCheck = ALICE_TimeElapsed
            return INTERVAL
        elseif vHorizontal - gizmo.vz < 200 then
            gizmo.lastTerrainCollisionCheck = ALICE_TimeElapsed
            return dist/600
        else
            gizmo.lastTerrainCollisionCheck = ALICE_TimeElapsed
            return dist/(3*(vHorizontal - gizmo.vz))
        end
    end

    ---@param gizmo table
    ---@param isVertical boolean
    ---@param coord number
    local function ReflectOnBounds(gizmo, isVertical, coord)
        if isVertical then
            gizmo.vy = -gizmo.vy
            gizmo.y = 2*coord - gizmo.y
        else
            gizmo.vx = -gizmo.vx
            gizmo.x = 2*coord - gizmo.x
        end
    end

    function CAT_OutOfBoundsCheck(gizmo)
        local nearestDist
        if gizmo.x < gizmoBoundMinX then
            if gizmo.reflectOnBounds then
                ReflectOnBounds(gizmo, false, gizmoBoundMinX)
            else
                ALICE_Kill(gizmo)
            end
            return 0
        else
            nearestDist = gizmo.x - gizmoBoundMinX
        end
        if gizmo.y < gizmoBoundMinY then
            if gizmo.reflectOnBounds then
                ReflectOnBounds(gizmo, true, gizmoBoundMinY)
            else
                ALICE_Kill(gizmo)
            end
            return 0
        else
            nearestDist = min(nearestDist, gizmo.y - gizmoBoundMinY)
        end
        if gizmo.x > gizmoBoundMaxX then
            if gizmo.reflectOnBounds then
                ReflectOnBounds(gizmo, false, gizmoBoundMaxX)
            else
                ALICE_Kill(gizmo)
            end
            return 0
        else
            nearestDist = min(nearestDist, gizmoBoundMaxX - gizmo.x)
        end
        if gizmo.y > gizmoBoundMaxY then
            if gizmo.reflectOnBounds then
                ReflectOnBounds(gizmo, true, gizmoBoundMaxY)
            else
                ALICE_Kill(gizmo)
            end
            return 0
        else
            nearestDist = min(nearestDist, gizmoBoundMaxY - gizmo.y)
        end
        if gizmo.z then
            if gizmo.z > CAT_Data.GIZMO_MAXIMUM_Z then
                ALICE_Kill(gizmo)
                return 0
            end
            if gizmo.z < CAT_Data.GIZMO_MINIMUM_Z then
                ALICE_Kill(gizmo)
                return 0
            end
        end

        if gizmo.isResting then
            ALICE_PairPause()
        end
        return nearestDist/(gizmo.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED)
    end

    ---Initializes the gizmo's z-coordinate to GetTerrainZ(x, y) + gizmo.collisionRadius.
    ---@param gizmo table
    function CAT_AutoZ(gizmo)
        gizmo.z = GetTerrainZ(gizmo.x, gizmo.y) + (gizmo.collisionRadius or 0)
    end

    ---Removes all widgets with the specified widgetId and calls the constructorFunc with the parameters func(x, y, z, life, mana, owner, facing). The last three parameters are nil if the widget is not a unit. 
    ---@param widgetId integer
    ---@param widgetType string
    ---@param constructorFunc function
    function CAT_GlobalReplace(widgetId, widgetType, constructorFunc)
        if widgetType == "unit" then
            local G = CreateGroup()
            GroupEnumUnitsInRect(G, bj_mapInitialPlayableArea, nil)
            local i = 0
            local u = BlzGroupUnitAt(G, i)
            while u do
                if GetUnitTypeId(u) == widgetId then
                    local x, y = GetUnitX(u), GetUnitY(u)
                    local z = GetTerrainZ(x, y) + GetUnitFlyHeight(u)
                    local life, mana = GetUnitState(u, UNIT_STATE_LIFE), GetUnitState(u, UNIT_STATE_MANA)
                    local owner = GetOwningPlayer(u)
                    local facing = GetUnitFacing(u)
                    constructorFunc(x, y, z, life, mana, owner, facing, u)
                    RemoveUnit(u)
                end
                i = i + 1
                u = BlzGroupUnitAt(G, i)
            end
            DestroyGroup(G)
        elseif widgetType == "destructable" then
            EnumDestructablesInRect(bj_mapInitialPlayableArea, nil, function()
                local d = GetEnumDestructable()
                if GetDestructableTypeId(d) == widgetId then
                    local x = GetDestructableX(d)
                    local y = GetDestructableY(d)
                    local z = GetTerrainZ(x, y)
                    local life = GetDestructableLife(d)
                    constructorFunc(x, y, z, life, d)
                    RemoveDestructable(d)
                end
            end)
        elseif widgetType == "item" then
            EnumItemsInRect(bj_mapInitialPlayableArea, nil, function()
                local i = GetEnumItem()
                if GetItemTypeId(i) == widgetId then
                    local x = GetItemX(i)
                    local y = GetItemY(i)
                    local z = GetTerrainZ(x, y)
                    constructorFunc(x, y, z, i)
                    RemoveItem(i)
                end
            end)
        end
    end

    ---Change the gizmo bounds for CAT_OutOfBoundsCheck. The default bounds are the world bounds. z-bounds are set in the config.
    ---@param minX number
    ---@param minY number
    ---@param maxX number
    ---@param maxY number
    function CAT_SetGizmoBounds(minX, minY, maxX, maxY)
        gizmoBoundMinX = minX
        gizmoBoundMinY = minY
        gizmoBoundMaxX = maxX
        gizmoBoundMaxY = maxY
    end

    ---Shifts the position of the gizmo by its launchOffset field in the direction of its velocity.
    ---@param gizmo table
    function CAT_LaunchOffset(gizmo)
        if gizmo.vz then
            local vTotal = sqrt(gizmo.vx^2 + gizmo.vy^2 + gizmo.vz^2)
            gizmo.x = gizmo.x + gizmo.launchOffset*gizmo.vx/vTotal
            gizmo.y = gizmo.y + gizmo.launchOffset*gizmo.vy/vTotal
            gizmo.z = gizmo.z + gizmo.launchOffset*gizmo.vz/vTotal
            if gizmo.visual then
                BlzSetSpecialEffectPosition(gizmo.visual, gizmo.x, gizmo.y, gizmo.z)
            end
        else
            local vTotal = sqrt(gizmo.vx^2 + gizmo.vy^2)
            gizmo.x = gizmo.x + gizmo.launchOffset*gizmo.vx/vTotal
            gizmo.y = gizmo.y + gizmo.launchOffset*gizmo.vy/vTotal
            if gizmo.visual then
                BlzSetSpecialEffectX(gizmo.visual, gizmo.x)
                BlzSetSpecialEffectY(gizmo.visual, gizmo.y)
            end
        end
    end

    local function InitGizmosCAT()
        Require("ALICE")
        local worldBounds = GetWorldBounds()
        CAT_SetGizmoBounds(GetRectMinX(worldBounds), GetRectMinY(worldBounds), GetRectMaxX(worldBounds), GetRectMaxY(worldBounds))
        RemoveRect(worldBounds)
        INTERVAL = ALICE_Config.MIN_INTERVAL
        local precomputedHeightMap = Require.optionally("PrecomputedHeightMap")
        if precomputedHeightMap then
            GetTerrainZ = _G.GetTerrainZ
        else
            moveableLoc = Location(0,0)
            GetTerrainZ = function(x, y)
                MoveLocation(moveableLoc, x, y)
                return GetLocationZ(moveableLoc)
            end
        end

        ALICE_FuncRequireFields(CAT_CheckTerrainCollision, true, false, "collisionRadius")
        ALICE_FuncRequireFields(CAT_Decay, true, false, "lifetime")
    end

    OnInit.final("CAT_Gizmos", InitGizmosCAT)

    --===========================================================================================================================================================
end
