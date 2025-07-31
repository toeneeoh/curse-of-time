if Debug then Debug.beginFile "CAT Ballistics" end
do
    --[[
    =============================================================================================================================================================
                                                                Complementary ALICE Template
                                                                        by Antares

                                    Requires:
                                    ALICE                       https://www.hiveworkshop.com/threads/a-l-i-c-e-interaction-engine.353126/
                                    Data CAT
                                    PrecomuptedHeightMap        https://www.hiveworkshop.com/threads/precomputed-synchronized-terrain-height-map.353477/
                                    TotalInitialization         https://www.hiveworkshop.com/threads/total-initialization.317099/

    =============================================================================================================================================================
                                                                   B A L L I S T I C S
    =============================================================================================================================================================

    This template includes a function for realistic, ballistic and sliding movement for gizmos* as well as some helper functions for ballistic movement. To add
    ballistic movement to a gizmo, add the CAT_MoveBallistic function to their self-interaction table (for an example, see gizmos CAT).

        *Objects represented by a table with coordinate fields .x, .y, .z, velocity fields .vx, .vy, .vz, and a special effect .visual.

    CAT_MoveBallistic requires the .collisionRadius field for ground-bound sliding movement. To become ground-bound, a gizmo requires CAT_TerrainCollisionCheck
    to be added to its self-iteraction table, and CAT_TerrainBounce set for its .onTerrainCollision field (gizmos CAT).

    A gizmo becomes ground-bound when it bounces off the surface with less than the CAT_Data.MINIMUM_BOUNCE_VELOCITY (Data CAT). While ground-bound, an object
    will slide realistically across the surface with a friction determined by the .friction field. The value is interpreted as the deceleration experienced per
    second. It is multiplied with CAT_Data.TERRAIN_TYPE_FRICTION, which can also be set in the Data CAT.
    
    Once a ground-bound gizmo has come to rest, its friction increases by the CAT_Data.STATIC_FRICTION_FACTOR (Data CAT) and a greater force is required to
    displace it again. The ballistic movement function writes values into the gizmo table to determine its current state. These values are used by other functions. 
    The .isResting field is used to detect if certain interactions can be paused to save computation resources. This means, that, even large numbers of resting
    gizmos do not affect performance in a significant way.

    This library, combined with the collisions library, is optimized towards allowing a large number of objects to sit idly on the map and not affect performance,
    while waiting for another object to collide with them.

    Sliding movement is currently bugged around cliffs.

    -------------------------------------------------------------------------------------------------------------------------------------------------------------

    Two helper functions for ballistic projectiles are included in this template.
    
    CAT_GetBallisticLaunchSpeedFromVelocity takes a velocity and returns the x, y, and z-velocities that would cause a ballistic projectile launched with the
    specified velocity from the launch coordinates to impact at the specified target coordinates. There are usually two solutions. The highArc flag specifies if
    the function should search for the solution with the higher angle first. It is possible that there is no solution for a given velocity. In that case, the
    function will return nil.

    CAT_GetBallisticLaunchSpeedFromAngle takes an angle and returns the x, y, and z-velocities that would cause the proctile launched at that angle from the launch
    coordinates to impact at the specified target coordinates. Unlike the from-velocity version, this function always has a solution as long as the vertical angle
    between the launch and target coordinates is not greater than the specified launch angle. In that case, the function will return nil.

    =============================================================================================================================================================
                                                            L I S T   O F   F U N C T I O N S
    =============================================================================================================================================================

    CAT_MoveBallistic
    CAT_GetBallisticLaunchSpeedFromVelocity(xLaunch, yLaunch, zLaunch, xTarget, yTarget, zTarget, velocity, highArc) -> vx, vy, vz
    CAT_GetBallisticLaunchSpeedFromAngle(xLaunch, yLaunch, zLaunch, xTarget, yTarget, zTarget, angle) -> vx, vy, vz

    =============================================================================================================================================================
    ]]

    local sqrt                              = math.sqrt
    local atan2                             = math.atan
    local cos                               = math.cos
    local sin                               = math.sin
    local tan                               = math.tan
    local abs                               = math.abs
    local PI                                = bj_PI

    local INTERVAL

    local PAUSEABLE_FUNCTIONS = {
        CAT_GizmoCollisionCheck3D,
        CAT_UnitCollisionCheck3D,
        CAT_DestructableCollisionCheck3D,
        CAT_ItemCollisionCheck3D,
        CAT_GizmoCollisionCheck2D,
        CAT_UnitCollisionCheck2D,
        CAT_DestructableCollisionCheck2D,
        CAT_ItemCollisionCheck2D,
        CAT_OrientRoll,
        CAT_Orient3D,
        CAT_Orient2D,
        CAT_AnimateShadow,
        CAT_MoveAttachedEffect,
        CAT_OutOfBoundsCheck,
    }

    local function InitMoveBallistic(gizmo)
        gizmo.visualZ = gizmo.visualZ or 0
        gizmo.isAirborne = gizmo.z ~= nil
        gizmo.vz = gizmo.vz or 0
        gizmo.vzOld = gizmo.vz
        gizmo.friction = gizmo.friction or 0
        gizmo.theta = atan2(gizmo.vz, sqrt(gizmo.vx^2 + gizmo.vy^2))
        if gizmo.launchOffset then
            CAT_LaunchOffset(gizmo)
        end
    end

    ---Required fields:
    -- - vx
    -- - vy
    -- - collisionRadius
    ---
    ----Optional fields:
    -- - vz
    -- - isResting
    -- - friction
    ---@param gizmo table
    function CAT_MoveBallistic(gizmo)
        if gizmo.isResting and gizmo.vx == 0 and gizmo.vy == 0 and gizmo.vz == 0 then
            return
        elseif gizmo.isAirborne then
            --Ballistic movement
            gizmo.x = gizmo.x + gizmo.vx*INTERVAL
            gizmo.y = gizmo.y + gizmo.vy*INTERVAL
            gizmo.z = gizmo.z + gizmo.vz*INTERVAL - 0.5*CAT_Data.GRAVITY*INTERVAL^2
            gizmo.vz = gizmo.vz - CAT_Data.GRAVITY*INTERVAL
            gizmo.vzOld = gizmo.vz
            BlzSetSpecialEffectPosition(gizmo.visual, gizmo.x, gizmo.y, gizmo.z + gizmo.visualZ)

            if gizmo.isResting then
                ALICE_Unpause(gizmo, PAUSEABLE_FUNCTIONS)
                gizmo.isResting = false
            end
        else
            --Check if object has received external force that could catapult it off the ground.
            if gizmo.vz > gizmo.vzOld + CAT_Data.MINIMUM_BOUNCE_VELOCITY or gizmo.vz < gizmo.vzOld - CAT_Data.MINIMUM_BOUNCE_VELOCITY/gizmo.elasticity then
                if gizmo.isResting then
                    ALICE_Unpause(gizmo, PAUSEABLE_FUNCTIONS)
                    gizmo.isResting = false
                end
                gizmo.isAirborne = true
                gizmo.lastTerrainCollisionCheck = ALICE_TimeElapsed
                ALICE_Unpause(gizmo, CAT_CheckTerrainCollision)
                ALICE_SetStationary(gizmo, false)
                gizmo.vzOld = gizmo.vz
                CAT_MoveBallistic(gizmo)
                return
            end

            --Ground movement
            local vHorizontal = sqrt(gizmo.vx^2 + gizmo.vy^2)
            if vHorizontal > 0 then

                --Determine if object is too fast to remain in contact with downwards curved surface.
                local freeFallCurvature = -CAT_Data.GRAVITY/(vHorizontal*vHorizontal)
                local deltaScanX = 2*gizmo.vx*INTERVAL
                local deltaScanY = 2*gizmo.vy*INTERVAL
                local deltaScanDist = sqrt(deltaScanX*deltaScanX + deltaScanY*deltaScanY)
                local z1 = GetTerrainZ(gizmo.x - deltaScanX, gizmo.y - deltaScanY)
                local z2 = GetTerrainZ(gizmo.x + deltaScanX, gizmo.y + deltaScanY)
                local z = GetTerrainZ(gizmo.x, gizmo.y)
                local curvature = (z2 + z1 - 2*z)*1/(128*deltaScanDist)

                if freeFallCurvature > curvature then
                    gizmo.isAirborne = true
                    gizmo.lastTerrainCollisionCheck = ALICE_TimeElapsed
                    ALICE_Unpause(gizmo, CAT_CheckTerrainCollision)
                    gizmo.x = gizmo.x + gizmo.vx*INTERVAL
                    gizmo.y = gizmo.y + gizmo.vy*INTERVAL
                    gizmo.z = gizmo.z + gizmo.vz*INTERVAL
                    BlzSetSpecialEffectPosition(gizmo.visual, gizmo.x, gizmo.y, gizmo.z + gizmo.visualZ)
                else
                    local frictionMultiplier = (freeFallCurvature - curvature)/freeFallCurvature --If the object is pressed against the surface due to its curvature, the friction increases.
                    local curvatureAngle
                    --Check if the curvature of the surface is so high that an object of its size would get reflected like it hit a wall.
                    if curvature > 0.0015 then --Don't run this calculation unless curvature is high enough (dz > ~50)
                        curvatureAngle = atan2(z2 - z, 32) - atan2(z - z1, 32) --Gradient angle difference between two neighboring tiles.
                        if CAT_Data.MAX_SLIDING_CURVATURE_RADIUS*(PI/2 - curvatureAngle)/curvatureAngle < gizmo.collisionRadius then
                            local xCollision, yCollision, zCollision = gizmo.x, gizmo.y, gizmo.z
                            local invVTotal = 1/sqrt(gizmo.vx^2 + gizmo.vy^2 + gizmo.vz^2)
                            local i = 1
                            repeat
                                xCollision = xCollision + 10*gizmo.vx*invVTotal
                                yCollision = yCollision + 10*gizmo.vy*invVTotal
                                zCollision = zCollision + 10*gizmo.vz*invVTotal
                                i = i + 1
                            until zCollision < GetTerrainZ(xCollision, yCollision) or i > 50
                            if i <= 50  then
                                CAT_TerrainBounce(gizmo, xCollision, yCollision, zCollision)
                                ALICE_Unpause(gizmo, CAT_CheckTerrainCollision)
                                gizmo.isAirborne = true
                                gizmo.lastTerrainCollisionCheck = ALICE_TimeElapsed
                                return
                            end
                        end
                    end
                    local x, y = gizmo.x, gizmo.y
                    local xGrad, yGrad = x - gizmo.vx*INTERVAL, y - gizmo.vy*INTERVAL
                    --Get surface orientation. Must be one movement step behind actual position so that vz does not go crazy on cliffs.
                    local gradientX = (GetTerrainZ(xGrad + 1, yGrad) - GetTerrainZ(xGrad - 1, yGrad))*0.5
                    local gradientY = (GetTerrainZ(xGrad, yGrad + 1) - GetTerrainZ(xGrad, yGrad - 1))*0.5
                    local gradientSquared = gradientX*gradientX + gradientY*gradientY
                    local oldvx = gizmo.vx
                    local oldvy = gizmo.vy
                    local oldTheta = gizmo.theta

                    --Gravitational force
                    local factor = sqrt(gradientSquared + 1)/CAT_Data.GRAVITY
                    local gx = gradientX/factor
                    local gy = gradientY/factor
                    local newvx = oldvx - gx*INTERVAL
                    local newvy = oldvy - gy*INTERVAL
                    local phi = atan2(newvy, newvx)
                    vHorizontal = sqrt(newvx*newvx + newvy*newvy)

                    --Surface friction
                    local textureFactor
                    if CAT_Data.DIFFERENT_SURFACE_FRICTIONS then
                        textureFactor = CAT_Data.TERRAIN_TYPE_FRICTION[GetTerrainType(x, y)] or 1
                    else
                        textureFactor = 1
                    end
                    local totalFriction = (gizmo.friction*textureFactor*frictionMultiplier)*INTERVAL
                    if vHorizontal < CAT_Data.STATIC_FRICTION_FACTOR*totalFriction then
                        vHorizontal = 0
                    else
                        vHorizontal = vHorizontal - totalFriction
                    end

                    gizmo.x = x + (oldvx + newvx)/2*INTERVAL
                    gizmo.y = y + (oldvy + newvy)/2*INTERVAL
                    gizmo.z = GetTerrainZ(gizmo.x, gizmo.y) + gizmo.collisionRadius
                    gizmo.vx = vHorizontal*cos(phi)
                    gizmo.vy = vHorizontal*sin(phi)
                    gizmo.vz = gradientX*gizmo.vx + gradientY*gizmo.vy
                    gizmo.theta = atan2(gizmo.vz, vHorizontal)

                    --Conversion of momentum on upward-curved surface.
                    if oldTheta < gizmo.theta - 0.001 then
                        local conversion = cos(gizmo.theta)/cos(oldTheta)
                        gizmo.vx = gizmo.vx*conversion
                        gizmo.vy = gizmo.vy*conversion
                    end

                    gizmo.vzOld = gizmo.vz
                    BlzSetSpecialEffectPosition(gizmo.visual, gizmo.x, gizmo.y, gizmo.z + gizmo.visualZ)
                end
                if gizmo.isResting then
                    ALICE_Unpause(gizmo, PAUSEABLE_FUNCTIONS)
                    ALICE_SetStationary(gizmo, false)
                    gizmo.isResting = false
                end
            elseif not gizmo.isResting then
                --If object has come to a full stop, check if it is stable, and if so, set it to resting.
                local x, y = gizmo.x, gizmo.y
                local gradientX = (GetTerrainZ(x + 16, y) - GetTerrainZ(x - 16, y))/32
                local gradientY = (GetTerrainZ(x, y + 16) - GetTerrainZ(x, y - 16))/32
                local gradientSquared = gradientX*gradientX + gradientY*gradientY
                local gx = gradientX/sqrt(gradientSquared + 1)*CAT_Data.GRAVITY
                local gy = gradientY/sqrt(gradientSquared + 1)*CAT_Data.GRAVITY
                local g = sqrt(gx*gx + gy*gy)
                local textureFactor = 1
                if CAT_Data.DIFFERENT_SURFACE_FRICTIONS then
                    textureFactor = CAT_Data.TERRAIN_TYPE_FRICTION[GetTerrainType(x, y)] or 1
                end
                if g > CAT_Data.STATIC_FRICTION_FACTOR*gizmo.friction*textureFactor then
                    local phi = atan2(gy, gx)
                    gizmo.vx = (g - gizmo.friction)*cos(phi)*INTERVAL
                    gizmo.vy = (g - gizmo.friction)*sin(phi)*INTERVAL
                    gizmo.vz = gradientX*gizmo.vx + gradientY*gizmo.vy
                    gizmo.vzOld = gizmo.vz
                    gizmo.x = x + gizmo.vx*INTERVAL/2
                    gizmo.y = y + gizmo.vy*INTERVAL/2
                    gizmo.z = GetTerrainZ(gizmo.x, gizmo.y) + gizmo.collisionRadius
                else
                    ALICE_SetStationary(gizmo, true)
                    gizmo.isResting = true
                    gizmo.vz = 0
                end
                BlzSetSpecialEffectPosition(gizmo.visual, gizmo.x, gizmo.y, gizmo.z + gizmo.visualZ)
            end
        end
    end

    ---Takes a velocity and returns the x, y, and z-velocities that would cause a ballistic projectile launched with the specified velocity from the launch coordinates to impact at the specified target coordinates. There are usually two solutions. The highArc flag specifies if the function should search for the solution with the higher angle first. It is possible that there is no solution for a given velocity. In that case, the function will return nil.
    ---@param xLaunch number
    ---@param yLaunch number
    ---@param zLaunch number
    ---@param xTarget number
    ---@param yTarget number
    ---@param zTarget number
    ---@param velocity number
    ---@param highArc? boolean
    ---@return number | nil, number | nil, number | nil
    function CAT_GetBallisticLaunchSpeedFromVelocity(xLaunch, yLaunch, zLaunch, xTarget, yTarget, zTarget, velocity, highArc)
        local dx = xTarget - xLaunch
        local dy = yTarget - yLaunch
        local dist = sqrt(dx^2 + dy^2)
        local stepSize = PI/8
        local epsilon = 0.01
        local goUp = not highArc

        local guess
        if highArc then
            guess = PI/2.001
        else
            guess = -PI/2.001
        end

        local zGuess = zLaunch + dist*tan(guess) - 0.5*CAT_Data.GRAVITY*(dist/(cos(guess)*velocity))^2
        local delta
        local deltaPrevious

        for __ = 1, 100 do
            if goUp then
                guess = guess + stepSize
            else
                guess = guess - stepSize
            end

            zGuess = zLaunch + dist*tan(guess) - 0.5*CAT_Data.GRAVITY*(dist/(cos(guess)*velocity))^2
            deltaPrevious = delta
            delta = zGuess - zTarget
            if abs(delta) < epsilon then
                break
            end
            if deltaPrevious and (delta > 0) ~= (deltaPrevious > 0) then
                goUp = not goUp
                stepSize = stepSize*(1 - abs(deltaPrevious)/(abs(deltaPrevious) + abs(delta)))
            end
        end

        if delta > epsilon or delta < -epsilon then
            return nil, nil, nil
        end

        return velocity*cos(guess)*dx/dist, velocity*cos(guess)*dy/dist, velocity*sin(guess)
    end

    ---Takes an angle and returns the x, y, and z-velocities that would cause the proctile launched at that angle from the launch coordinates to impact at the specified target coordinates. Unlike the from-velocity version, this function always has a solution as long as the vertical angle between the launch and target coordinates is not greater than the specified launch angle. In that case, the function will return nil.
    ---@param xLaunch number
    ---@param yLaunch number
    ---@param zLaunch number
    ---@param xTarget number
    ---@param yTarget number
    ---@param zTarget number
    ---@param angle number
    ---@return number | nil, number | nil, number | nil
    function CAT_GetBallisticLaunchSpeedFromAngle(xLaunch, yLaunch, zLaunch, xTarget, yTarget, zTarget, angle)
        local dx = xTarget - xLaunch
        local dy = yTarget - yLaunch
        local dz = zTarget - zLaunch
        local dist = sqrt(dx*dx + dy*dy)
        local cosAngle, sinAngle = cos(angle), sin(angle)
        local vSquared = (CAT_Data.GRAVITY*dist*dist/(2*cosAngle*cosAngle))/(dist*tan(angle) - dz)
        if vSquared < 0 then
            return nil, nil, nil
        end
        local velocity = sqrt(vSquared)
        return velocity*cosAngle*dx/dist, velocity*cosAngle*dy/dist, velocity*sinAngle
    end

    local function InitBallisticsCAT()
        Require "ALICE"
        Require "CAT_Data"
        Require "PrecomputedHeightMap"
        INTERVAL = ALICE_Config.MIN_INTERVAL
        ALICE_FuncSetInit(CAT_MoveBallistic, InitMoveBallistic)
        ALICE_FuncRequireFields(CAT_MoveBallistic, true, false,
            "x", "y", "z",
            "vx", "vy",
            "collisionRadius"
        )
    end

    OnInit.final("CAT_Ballistics", InitBallisticsCAT)
end
