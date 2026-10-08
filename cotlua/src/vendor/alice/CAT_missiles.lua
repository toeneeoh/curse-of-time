if Debug then Debug.beginFile("CAT Missiles") end
do
    --[[
    ===============================================================================================================================================================================
                                                                        Complementary ALICE Template
                                                                                by Antares

                                    Requires:
                                    ALICE                               https://www.hiveworkshop.com/threads/a-l-i-c-e-interaction-engine.353126/
                                    Gizmos CAT
                                    PrecomputedHeightMap                https://www.hiveworkshop.com/threads/precomputed-synchronized-terrain-height-map.353477/
                                    TotalInitialization                 https://www.hiveworkshop.com/threads/total-initialization.317099/

    ===============================================================================================================================================================================
                                                                                M I S S I L E S
    ===============================================================================================================================================================================

    This template includes a several functions that move or accelerate gizmos*, allowing for the creation of missiles or projectiles. Only the ballistic move function is found in
    the Ballistics CAT. For an example of how to use a movement functions, see Gizmos CAT.

        *Objects represented by a table with coordinate fields .x, .y, .z, velocity fields .vx, .vy, .vz, and a special effect .visual.
    
    ===============================================================================================================================================================================
                                                                        L I S T   O F   F U N C T I O N S             
    ===============================================================================================================================================================================

                                    • All movement functions use the optional .visualZ field. You can use this field to shift the position of the
                                      special effect in z-direction.
                                    • All movement functions use the optional .launchOffset field. This shifts the position of the gizmo by that
                                      much in the direction of the movement.
    
    CAT_MoveAutoHeight                                          Linear movement along the terrain surface.
    CAT_Move2D                                                  Simplest movement function. Linear movement in the x-y plane.
    CAT_Move3D                                                  Linear movement in any direction.
    CAT_MoveArced                                               The missile moves towards the target location specified by the fields .targetX and .targetY with the velocity .speed.
                                                                The .arc field determines how curved the missile's path is. The optional .arcAngle field shifts the direction of the
                                                                missile's arc. With an arcAngle of 0, the missile arcs vertically, with 90 or -90, it arcs horizontally. A missile
                                                                using this movement function will move towards the location until it collides with something, ignoring all external
                                                                effects.
    CAT_MoveHoming2D                                            The missile follows an object specified by the .target field with a velocity .speed. You can limit the turn rate with
                                                                the optional .turnRate field. The value is expected to be in degrees per second. The optional .disconnectionDistance
                                                                field controls the maximum distance the unit can travel between two updates before the homing breaks. Gizmos using
                                                                homing movement will always move with the same speed, ignoring external effects.
    CAT_MoveArcedHoming                                         The same as MoveHoming2D, but movement in three dimensions. The additional .arc field determines how high the
                                                                missile flies as it travels towards the unit. The optional .arcAngle field shifts the direction of the missile's arc.
                                                                With an arcAngle of 0, the missile arcs vertically, with 90 or -90, it arcs horizontally. Attempts to turn towards the
                                                                unit will still be only in the x-y-plane.
    CAT_MoveHoming3D                                            The same as MoveHoming2D, but movement in three dimensions. The missile will use all three dimensions to find the
                                                                lowest turn angle towards the unit.

    -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    CAT_AccelerateHoming2D                                      Accelerates the gizmo towards the target unit set with the .target field. The acceleration is set with the
                                                                .acceleration field. The optional .deceleration field determines the acceleration the gizmo experiences when it is
                                                                currently not moving towards the gizmo. Will use acceleration if not set. The optional .maxSpeed field limits the
                                                                maximum velocity of the gizmo in direction of the target. This is not a movement function and must be paired with a
                                                                compatible movement function; one that reacts to external effects. Can be combined with CAT_OrientPropelled2D function
                                                                (Effects CAT).

    ===============================================================================================================================================================================
    ]]

    local sqrt                              = math.sqrt
    local atan2                             = math.atan
    local cos                               = math.cos
    local sin                               = math.sin
    local acos                              = math.acos
    local exp                               = math.exp
    local PI                                = bj_PI
    local TAU                               = 2*PI

    local INTERVAL                          = nil       ---@type number

    local moveableLoc                       = nil       ---@type location
    local GetTerrainZ                       = nil       ---@type function

    local function Cosh(x)
        return (exp(x) + exp(-x))/2
    end

    local function Sinh(x)
        return (exp(x) - exp(-x))/2
    end

    local function InitMoveGeneric(missile)
        missile.visualZ = missile.visualZ or 0
        if missile.launchOffset then
            CAT_LaunchOffset(missile)
        end
    end

    ---Required fields:
    -- - vx
    -- - vy
    ---
    ---Optional fields:
    -- - visualZ
    function CAT_MoveAutoHeight(missile)
        missile.x = missile.x + missile.vx*INTERVAL
        missile.y = missile.y + missile.vy*INTERVAL
        missile.z = GetTerrainZ(missile.x, missile.y)
        BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, missile.z + missile.visualZ)
    end

    local function InitMove2D(missile)
        missile.visualZ = (missile.visualZ or 0) + GetTerrainZ(missile.x, missile.y)
        if missile.launchOffset then
            CAT_LaunchOffset(missile)
        end
    end

    ---Required fields:
    -- - vx
    -- - vy
    ---
    ---Optional fields:
    -- - visualZ
    function CAT_Move2D(missile)
        missile.x = missile.x + missile.vx*INTERVAL
        missile.y = missile.y + missile.vy*INTERVAL
        BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, missile.visualZ)
    end

    ---Required fields:
    -- - vx
    -- - vy
    -- - vz
    ---
    ---Optional fields:
    -- - visualZ
    function CAT_Move3D(missile)
        missile.x = missile.x + missile.vx*INTERVAL
        missile.y = missile.y + missile.vy*INTERVAL
        missile.z = missile.z + missile.vz*INTERVAL
        BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, missile.z + missile.visualZ)
    end

    local function InitMoveArced(missile)
        missile.visualZ = (missile.visualZ or 0)
        missile.launchX = missile.x
        missile.launchY = missile.y
        missile.launchZ = missile.z or GetTerrainZ(missile.x, missile.y)
        missile.targetZ = missile.targetZ or GetTerrainZ(missile.targetX, missile.targetY)
        local dx, dy, dz = missile.targetX - missile.launchX, missile.targetY - missile.launchY, missile.targetZ - missile.launchZ
        local dist = sqrt(dx*dx + dy*dy + dz*dz)

        local phi = atan2(dy, dx)
        local theta = atan2(-dz, sqrt(dx*dx + dy*dy))

        local cosPhi = cos(phi)
        local sinPhi = sin(phi)
        local cosTheta = cos(theta)
        local sinTheta = sin(theta)

        missile.R11 = cosPhi*cosTheta
        missile.R12 = -sinPhi
        missile.R13 = cosPhi*sinTheta
        missile.R21 = sinPhi*cosTheta
        missile.R22 = cosPhi
        missile.R23 = sinPhi*sinTheta
        missile.R31 = -sinTheta
        missile.R32 = 0
        missile.R33 = cosTheta

        missile.arc = missile.arc
        missile.cosArcAngle = cos((missile.arcAngle or 0)*bj_DEGTORAD)
        missile.sinArcAngle = sin((missile.arcAngle or 0)*bj_DEGTORAD)
        missile.coshArc = Cosh(missile.arc)
        missile.travelDist = dist
        missile.dparam = 2*missile.speed*INTERVAL/dist

        local timeDilation = sqrt(1 + (2*missile.arc*Sinh(-1))^2) --param goes from -1 to 1.
        local param
        if missile.launchOffset then --If no launch offset is set, we need to fake a displacement to calculate velocity direction.
            param = -1 + missile.launchOffset/(missile.travelDist*timeDilation)
        else
            param = -1 + missile.dparam
        end
        local xPrime = missile.travelDist*(param + 1)/2
        local y = missile.travelDist*(missile.coshArc - Cosh(missile.arc*param))
        local yPrime = y*missile.sinArcAngle
        local zPrime = y*missile.cosArcAngle
        local xNew = missile.launchX + missile.R11*xPrime + missile.R12*yPrime + missile.R13*zPrime
        local yNew = missile.launchY + missile.R21*xPrime + missile.R22*yPrime + missile.R23*zPrime
        local zNew = missile.launchZ + missile.R31*xPrime + missile.R32*yPrime + missile.R33*zPrime
        dist = sqrt((xNew - missile.launchX)^2 + (yNew - missile.launchY)^2 + (zNew - missile.launchZ)^2)
        missile.vx = missile.speed*(xNew - missile.launchX)/dist
        missile.vy = missile.speed*(yNew - missile.launchY)/dist
        missile.vz = missile.speed*(zNew - missile.launchZ)/dist
        if missile.launchOffset then
            missile.x = xNew
            missile.y = yNew
            missile.z = zNew
            missile.param = param
            if missile.visual then
                BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, missile.z + missile.visualZ)
            end
        else
            missile.param = -1
        end
    end

    ---Required fields:
    -- - speed
    -- - arc
    -- - targetX
    -- - targetY
    ---
    ---Optional fields:
    -- - arcAngle
    -- - visualZ
    function CAT_MoveArced(missile)
        missile.param = missile.param + missile.dparam/sqrt(1 + (2*missile.arc*Sinh(missile.param))^2)
        local xLast, yLast, zLast = missile.x, missile.y, missile.z
        local xPrime = missile.travelDist*(missile.param + 1)/2
        local y      = missile.travelDist*(missile.coshArc - Cosh(missile.arc*missile.param))
        local yPrime = y*missile.sinArcAngle
        local zPrime = y*missile.cosArcAngle
        missile.x = missile.launchX + missile.R11*xPrime + missile.R12*yPrime + missile.R13*zPrime
        missile.y = missile.launchY + missile.R21*xPrime + missile.R22*yPrime + missile.R23*zPrime
        missile.z = missile.launchZ + missile.R31*xPrime + missile.R32*yPrime + missile.R33*zPrime
        missile.vx = (missile.x - xLast)/INTERVAL
        missile.vy = (missile.y - yLast)/INTERVAL
        missile.vz = (missile.z - zLast)/INTERVAL
        BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, missile.z + missile.visualZ)
    end

    local function InitMoveHoming2D(missile)
        missile.visualZ = missile.visualZ or 0
        missile.turnRate = missile.turnRate or math.huge
        missile.turnRateNormalized = bj_DEGTORAD*missile.turnRate*0.1
        missile.turnRadius = missile.speed/(bj_DEGTORAD*missile.turnRate)
        local x, y = ALICE_GetCoordinates2D(missile.target)
        missile.lastKnownTargetX, missile.lastKnownTargetY = x, y
        if missile.vx and missile.vy then
            missile.currentAngle = atan2(missile.vy, missile.vx)
        else
            missile.currentAngle = atan2(y - missile.y, x - missile.x)
        end
        if missile.launchOffset then
            CAT_LaunchOffset(missile)
        end
    end

    ---Required fields:
    -- - target
    -- - speed
    ---
    ---Optional fields:
    -- - turnRate
    -- - disconnectionDistance
    function CAT_MoveHoming2D(missile)
        if ALICE_PairCooldown(0.1) == 0 then
            local x, y = ALICE_GetCoordinates2D(missile.target)
            if x ~= 0 or y ~= 0 then
                if missile.disconnectionDistance then
                    local distSquared = (x - missile.lastKnownTargetX)^2 + (y - missile.lastKnownTargetY)^2
                    if distSquared < missile.disconnectionDistance^2 then
                        missile.lastKnownTargetX, missile.lastKnownTargetY = x, y
                    else
                        missile.target = nil
                    end
                else
                    missile.lastKnownTargetX, missile.lastKnownTargetY = x, y
                end
            end

            local angle = atan2(missile.lastKnownTargetY - missile.y, missile.lastKnownTargetX - missile.x)
            local currentAngle = missile.currentAngle
            local diff = angle - currentAngle
            local absDiff

            if diff < 0 then
                diff = diff + TAU
            elseif diff > TAU then
                diff = diff - TAU
            end
            if diff > PI then
                diff = diff - TAU
                absDiff = -diff
            else
                absDiff = diff
            end

            if absDiff < missile.turnRateNormalized then
                currentAngle = angle
            elseif diff < 0 then
                --Check if target is inside the circle that the missile cannot currently reach. If so, stop turning to gain distance.
                local turnLocAngle = currentAngle - PI/2
                local turnLocX = missile.x + missile.turnRadius*cos(turnLocAngle)
                local turnLocY = missile.y + missile.turnRadius*sin(turnLocAngle)
                local targetTurnLocDist = sqrt((turnLocX - missile.lastKnownTargetX)^2 + (turnLocY - missile.lastKnownTargetY)^2)
                if targetTurnLocDist > missile.turnRadius or (targetTurnLocDist > 0.9*missile.turnRadius and missile.isTurning) then
                    missile.isTurning = true
                    currentAngle = currentAngle - missile.turnRateNormalized
                    if currentAngle < 0 then
                        currentAngle = currentAngle + TAU
                    end
                else
                    missile.isTurning = false
                end
            else
                local turnLocAngle = currentAngle + PI/2
                local turnLocX = missile.x + missile.turnRadius*cos(turnLocAngle)
                local turnLocY = missile.y + missile.turnRadius*sin(turnLocAngle)
                local targetTurnLocDist = sqrt((turnLocX - missile.lastKnownTargetX)^2 + (turnLocY - missile.lastKnownTargetY)^2)
                if targetTurnLocDist > missile.turnRadius or (targetTurnLocDist > 0.9*missile.turnRadius and missile.isTurning) then
                    missile.isTurning = true
                    currentAngle = currentAngle + missile.turnRateNormalized
                    if currentAngle > TAU then
                        currentAngle = currentAngle - TAU
                    end
                else
                    missile.isTurning = false
                end
            end

            missile.vx = missile.speed*cos(currentAngle)
            missile.vy = missile.speed*sin(currentAngle)
            missile.currentAngle = currentAngle
        end
        missile.x = missile.x + missile.vx
        missile.y = missile.y + missile.vy
        BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, GetTerrainZ(missile.x, missile.y) + missile.visualZ)
    end

    local function InitMoveArcedHoming(missile)
        missile.visualZ = missile.visualZ or 0
        missile.turnRate = missile.turnRate or math.huge
        missile.turnRateNormalized = bj_DEGTORAD*missile.turnRate*0.1
        missile.turnRadius = missile.speed/(bj_DEGTORAD*missile.turnRate)
        missile.lastKnownTargetX, missile.lastKnownTargetY, missile.lastKnownTargetZ = ALICE_GetCoordinates3D(missile.target)
        missile.verticalArc = missile.arc*cos((missile.arcAngle or 0)*bj_DEGTORAD)
        missile.horizontalArc = missile.arc*sin((missile.arcAngle or 0)*bj_DEGTORAD)

        if missile.disconnectionDistance then
            missile.discDistSquared = missile.disconnectionDistance^2
        end
        if not missile.vx then
            local xu, yu, zu = ALICE_GetCoordinates3D(missile.target)
            local dx, dy = xu - missile.x, yu - missile.y
            local horizontalDist = sqrt(dx*dx + dy*dy)
            local dz = zu - missile.z + missile.arc*horizontalDist
            local dist = sqrt(horizontalDist^2 + dz*dz)
            missile.vx = dx/dist*missile.speed
            missile.vy = dy/dist*missile.speed
            missile.vz = dz/dist*missile.speed
        else
            local norm = missile.speed/sqrt(missile.vx^2 + missile.vy^2 + missile.vz^2)
            missile.vx, missile.vy, missile.vz = missile.vx*norm, missile.vy*norm, missile.vz*norm
        end
        if missile.launchOffset then
            CAT_LaunchOffset(missile)
        end
    end

    ---Required fields:
    -- - target
    -- - speed
    -- - arc
    ---
    ---Optional fields:
    -- - arcAngle
    -- - turnRate
    -- - disconnectionDistance
    function CAT_MoveArcedHoming(missile)
        if ALICE_PairCooldown(0.1) == 0 then
            local x, y, z = ALICE_GetCoordinates3D(missile.target)
            if x ~= 0 or y ~= 0 or z ~= 0 then
                if missile.disconnectionDistance then
                    local dx, dy, dz = x - missile.lastKnownTargetX, y - missile.lastKnownTargetY, z - missile.lastKnownTargetZ
                    local distSquared = dx*dx + dy*dy + dz*dz
                    if distSquared < missile.discDistSquared then
                        missile.lastKnownTargetX, missile.lastKnownTargetY, missile.lastKnownTargetZ = x, y, z
                    else
                        missile.target = nil
                    end
                else
                    missile.lastKnownTargetX, missile.lastKnownTargetY, missile.lastKnownTargetZ = ALICE_GetCoordinates3D(missile.target)
                end
            end

            local vx, vy, vz = missile.vx, missile.vy, missile.vz
            local dx, dy = missile.lastKnownTargetX - missile.x, missile.lastKnownTargetY - missile.y
            local horizontalDist = sqrt(dx*dx + dy*dy)

            local phi = atan2(dy, dx) + missile.horizontalArc
            local currentPhi = atan2(vy, vx)
            local diff = phi - currentPhi
            local absDiff

            if diff < 0 then
                diff = diff + TAU
            elseif diff > TAU then
                diff = diff - TAU
            end
            if diff > PI then
                diff = diff - TAU
                absDiff = -diff
            else
                absDiff = diff
            end

            if absDiff < missile.turnRateNormalized then
                currentPhi = phi
            elseif diff < 0 then
                --Check if target is inside the circle that the missile cannot currently reach. If so, stop turning to gain distance.
                local turnLocPhi = currentPhi - PI/2
                local turnLocX = missile.x + missile.turnRadius*cos(turnLocPhi)
                local turnLocY = missile.y + missile.turnRadius*sin(turnLocPhi)
                dx, dy = turnLocX - missile.lastKnownTargetX, turnLocY - missile.lastKnownTargetY
                local targetTurnLocHoriDist = sqrt(dx*dx + dy*dy)
                if targetTurnLocHoriDist > missile.turnRadius or (targetTurnLocHoriDist > 0.9*missile.turnRadius and missile.isTurning) then
                    missile.isTurning = true
                    currentPhi = currentPhi - missile.turnRateNormalized
                    if currentPhi < 0 then
                        currentPhi = currentPhi + TAU
                    end
                else
                    missile.isTurning = false
                end
            else
                local turnLocPhi = currentPhi + PI/2
                local turnLocX = missile.x + missile.turnRadius*cos(turnLocPhi)
                local turnLocY = missile.y + missile.turnRadius*sin(turnLocPhi)
                dx, dy = turnLocX - missile.lastKnownTargetX, turnLocY - missile.lastKnownTargetY
                local targetTurnLocHoriDist = sqrt(dx*dx + dy*dy)
                missile.isTurning = true
                if targetTurnLocHoriDist > missile.turnRadius or (targetTurnLocHoriDist > 0.9*missile.turnRadius and missile.isTurning) then
                    currentPhi = currentPhi + missile.turnRateNormalized
                    if currentPhi > TAU then
                        currentPhi = currentPhi - TAU
                    end
                else
                    missile.isTurning = false
                end
            end

            local dz = missile.lastKnownTargetZ - missile.z + missile.verticalArc*(horizontalDist + absDiff*missile.turnRadius)

            local theta = atan2(dz, horizontalDist)
            local currentTheta = atan2(vz, sqrt(vx*vx + vy*vy))

            diff = theta - currentTheta

            if diff < 0 then
                diff = diff + TAU
            elseif diff > TAU then
                diff = diff - TAU
            end
            if diff > PI then
                diff = diff - TAU
                absDiff = -diff
            else
                absDiff = diff
            end

            if absDiff < missile.turnRateNormalized then
                currentTheta = theta
            elseif diff < 0 then
                currentTheta = currentTheta - missile.turnRateNormalized
                if currentTheta < 0 then
                    currentTheta = currentTheta + TAU
                end
            else
                currentTheta = currentTheta + missile.turnRateNormalized
                if currentTheta > TAU then
                    currentTheta = currentTheta - TAU
                end
            end

            local cosCurrentTheta = cos(currentTheta)
            missile.vx = missile.speed*cos(currentPhi)*cosCurrentTheta
            missile.vy = missile.speed*sin(currentPhi)*cosCurrentTheta
            missile.vz = missile.speed*sin(currentTheta)
        end

        missile.x = missile.x + missile.vx*INTERVAL
        missile.y = missile.y + missile.vy*INTERVAL
        missile.z = missile.z + missile.vz*INTERVAL
        BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, missile.z + missile.visualZ)
    end

    local function InitMoveHoming3D(missile)
        missile.visualZ = missile.visualZ or 0
        missile.turnRate = missile.turnRate or math.huge
        missile.turnRateNormalized = bj_DEGTORAD*missile.turnRate*0.1
        missile.turnRadius = missile.speed/(bj_DEGTORAD*missile.turnRate)
        missile.lastKnownTargetX, missile.lastKnownTargetY, missile.lastKnownTargetZ = ALICE_GetCoordinates3D(missile.target)
        if not missile.vx then
            local xu, yu, zu = ALICE_GetCoordinates3D(missile.target)
            local dx, dy = xu - missile.x, yu - missile.y
            local horizontalDist = sqrt(dx*dx + dy*dy)
            local dz = zu - missile.z
            local dist = sqrt(horizontalDist^2 + dz*dz)
            missile.vx = dx/dist*missile.speed
            missile.vy = dy/dist*missile.speed
            missile.vz = dz/dist*missile.speed
        else
            local norm = missile.speed/sqrt(missile.vx^2 + missile.vy^2 + missile.vz^2)
            missile.vx, missile.vy, missile.vz = missile.vx*norm, missile.vy*norm, missile.vz*norm
        end
        if missile.launchOffset then
            CAT_LaunchOffset(missile)
        end
    end

    ---Required fields:
    -- - target
    -- - speed
    ---
    ---Optional fields:
    -- - turnRate
    -- - disconnectionDistance
    function CAT_MoveHoming3D(missile)
        if ALICE_PairCooldown(0.1) == 0 then
            local x, y, z = ALICE_GetCoordinates3D(missile.target)
            if x ~= 0 or y ~= 0 or z ~= 0 then
                if missile.disconnectionDistance then
                    local distSquared = (x - missile.lastKnownTargetX)^2 + (y - missile.lastKnownTargetY)^2 + (z - missile.lastKnownTargetZ)^2
                    if distSquared < missile.disconnectionDistance^2 then
                        missile.lastKnownTargetX, missile.lastKnownTargetY, missile.lastKnownTargetZ = x, y, z
                    else
                        missile.target = nil
                    end
                else
                    missile.lastKnownTargetX, missile.lastKnownTargetY, missile.lastKnownTargetZ = ALICE_GetCoordinates3D(missile.target)
                end
            end

            local vx, vy, vz = missile.vx, missile.vy, missile.vz
            local dx, dy, dz = missile.lastKnownTargetX - missile.x, missile.lastKnownTargetY - missile.y, missile.lastKnownTargetZ - missile.z
            local dist = sqrt(dx*dx + dy*dy + dz*dz)

            local angleDiff = acos((dx*vx + dy*vy + dz*vz)/(missile.speed*dist))

            local turnAngle
            if angleDiff >= missile.turnRateNormalized then
                turnAngle = -angleDiff
            else
                turnAngle = -missile.turnRateNormalized
            end

            local nx = vy*dz - vz*dy
            local ny = vz*dx - vx*dz
            local nz = vx*dy - vy*dx

            local invNorm = 1/sqrt(nx^2 + ny^2 + nz^2)
            if invNorm ~= math.huge then
                nx, ny, nz = nx*invNorm, ny*invNorm, nz*invNorm

                if dist < 2*missile.turnRadius then
                    --Check if target is inside the circle that the missile cannot currently reach. If so, stop turning to gain distance.
                    local ntpx = vz*ny - vy*nz
                    local ntpy = vx*nz - vz*nx
                    local ntpz = vy*nx - vx*ny

                    invNorm = missile.turnRadius/sqrt(ntpx^2 + ntpy^2 + ntpz^2)
                    ntpx, ntpy, ntpz = ntpx*invNorm + missile.x, ntpy*invNorm + missile.y, ntpz*invNorm + missile.z
                    local targetTurnLocDist = sqrt((missile.lastKnownTargetX - ntpx)^2 + (missile.lastKnownTargetY - ntpy)^2 + (missile.lastKnownTargetZ - ntpz)^2)
                    if targetTurnLocDist > missile.turnRadius or (targetTurnLocDist > 0.9*missile.turnRadius and missile.isTurning) then
                        missile.isTurning = true
                        missile.x = missile.x + missile.vx*INTERVAL
                        missile.y = missile.y + missile.vy*INTERVAL
                        missile.z = missile.z + missile.vz*INTERVAL
                        BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, missile.z + missile.visualZ)
                        return
                    else
                        missile.isTurning = false
                    end
                end

                local cosAngle = cos(turnAngle)
                local sinAngle = sin(turnAngle)
                local oneMinCos = 1 - cosAngle

                M11 = nx*nx*oneMinCos + cosAngle
                M12 = nx*ny*oneMinCos - nz*sinAngle
                M13 = nx*nz*oneMinCos + ny*sinAngle
                M21 = ny*nx*oneMinCos + nz*sinAngle
                M22 = ny*ny*oneMinCos + cosAngle
                M23 = ny*nz*oneMinCos - nx*sinAngle
                M31 = nz*nx*oneMinCos - ny*sinAngle
                M32 = nz*ny*oneMinCos + nx*sinAngle
                M33 = nz*nz*oneMinCos + cosAngle

                local newvx = vx*M11 + vy*M21 + vz*M31
                local newvy = vx*M12 + vy*M22 + vz*M32
                local newvz = vx*M13 + vy*M23 + vz*M33

                invNorm = missile.speed/sqrt(newvx*newvx + newvy*newvy + newvz*newvz)
                missile.vx, missile.vy, missile.vz = newvx*invNorm, newvy*invNorm, newvz*invNorm
            end
        end

        missile.x = missile.x + missile.vx*INTERVAL
        missile.y = missile.y + missile.vy*INTERVAL
        missile.z = missile.z + missile.vz*INTERVAL
        BlzSetSpecialEffectPosition(missile.visual, missile.x, missile.y, missile.z + missile.visualZ)
    end

    local function InitAccelerateHoming(missile)
        missile.deceleration = missile.deceleration or missile.acceleration
        missile.maxSpeed = missile.maxSpeed or math.huge
    end

    ---Required fields:
    -- - vx
    -- - vy
    -- - acceleration
    -- - target
    ---
    ---Optional fields:
    -- - deceleration
    -- - maxSpeed
    function CAT_AccelerateHoming2D(missile)
        if ALICE_PairCooldown(0.1) == 0 then
            local decelerationNormed = missile.deceleration*INTERVAL
            local x, y = ALICE_GetCoordinates2D(missile.target)
            if x ~= 0 or y ~= 0 then
                local dx = x - missile.x
                local dy = y - missile.y
                local dist = sqrt(dx*dx + dy*dy)
                local cosAngle = dx/dist
                local sinAngle = dy/dist
                local vxPrime = cosAngle * missile.vx + sinAngle * missile.vy
                local vyPrime = -sinAngle * missile.vx + cosAngle * missile.vy
                local axPrime
                local ayPrime

                if vxPrime > missile.maxSpeed then
                    axPrime = -missile.deceleration
                elseif vxPrime < 0 then
                    axPrime = missile.deceleration
                else
                    axPrime = missile.acceleration
                end
                if vyPrime > decelerationNormed then
                    ayPrime = -missile.deceleration
                elseif vyPrime > 0 then
                    ayPrime = -vyPrime/INTERVAL
                elseif vyPrime < -decelerationNormed then
                    ayPrime = missile.deceleration
                else
                    ayPrime = -vyPrime/INTERVAL
                end

                missile.ax = cosAngle * axPrime - sinAngle * ayPrime
                missile.ay = sinAngle * axPrime + cosAngle * ayPrime
            end
        end
        missile.vx = missile.vx + missile.ax*INTERVAL
        missile.vy = missile.vy + missile.ay*INTERVAL
    end

    local function InitMissilesCAT()
        Require("ALICE")
        Require("CAT_Gizmos")
        INTERVAL = ALICE_Config.MIN_INTERVAL
        ALICE_FuncSetInit(CAT_MoveAutoHeight, InitMoveGeneric)
        ALICE_FuncSetInit(CAT_Move2D, InitMove2D)
        ALICE_FuncSetInit(CAT_Move3D, InitMoveGeneric)
        ALICE_FuncSetInit(CAT_MoveHoming2D, InitMoveHoming2D)
        ALICE_FuncSetInit(CAT_MoveHoming3D, InitMoveHoming3D)
        ALICE_FuncSetInit(CAT_MoveArcedHoming, InitMoveArcedHoming)
        ALICE_FuncSetInit(CAT_AccelerateHoming2D, InitAccelerateHoming)
        ALICE_FuncSetInit(CAT_MoveArced, InitMoveArced)

        ALICE_FuncRequireFields(CAT_MoveAutoHeight, true, false, "x", "y", "vx", "vy")
        ALICE_FuncRequireFields(CAT_Move2D, true, false, "x", "y", "vx", "vy")
        ALICE_FuncRequireFields(CAT_Move3D, true, false, "x", "y", "z", "vx", "vy", "vz")
        ALICE_FuncRequireFields(CAT_MoveArced, true, false, "x", "y", "z", "targetX", "targetY", "speed", "arc")
        ALICE_FuncRequireFields(CAT_MoveHoming2D, true, false, "x", "y", "z", "target", "speed")
        ALICE_FuncRequireFields(CAT_MoveArcedHoming, true, false, "x", "y", "z", "target", "speed", "arc", {vx = {"vy", "vz"}})
        ALICE_FuncRequireFields(CAT_MoveHoming3D, true, false, "x", "y", "z", "target", "speed", {vx = {"vy", "vz"}})

        local precomputedHeightMap = Require.optionally("PrecomputedHeightMap")

        if precomputedHeightMap then
            GetTerrainZ = _G.GetTerrainZ
        else
            moveableLoc = Location(0, 0)
            GetTerrainZ = function(x, y)
                MoveLocation(moveableLoc, x, y)
                return GetLocationZ(moveableLoc)
            end
        end
    end

    OnInit.final("CAT_Missiles", InitMissilesCAT)
end
