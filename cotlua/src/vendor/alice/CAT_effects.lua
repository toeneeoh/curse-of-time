if Debug then Debug.beginFile("CAT Effects") end
do
    --[[
    ============================================================================================================================================================================
                                                                    Complementary ALICE Template
                                                                            by Antares

                                    Requires:
                                    ALICE                       https://www.hiveworkshop.com/threads/a-l-i-c-e-interaction-engine.353126/
                                    PrecomuptedHeightMap        https://www.hiveworkshop.com/threads/precomputed-synchronized-terrain-height-map.353477/
                                    TotalInitialization         https://www.hiveworkshop.com/threads/total-initialization.317099/

    ============================================================================================================================================================================
                                                                            E F F E C T S
    ============================================================================================================================================================================

    This template contains various auxiliary functions to make your gizmos* look nice. Functions are added to a gizmo by adding it to the self-interaction table. Function
    parameters are customized by editing table fields of your gizmo. Some parameters are mutable, others are not. In many cases, you can easily alter the implementation of a
    function to make a parameter mutable.

        *Objects represented by a table with coordinate fields .x, .y, .z, velocity fields .vx, .vy, .vz, and a special effect .visual.

    ============================================================================================================================================================================
                                                                    L I S T   O F   F U N C T I O N S
    ============================================================================================================================================================================

    CAT_MoveEffect                                          A simple function that moves the gizmo's visual to its current location. Useful for gizmos anchored to a unit.
    CAT_AnimateShadow                                       Adds a shadow to your gizmo. Your gizmo table requires multiple fields to be set: shadowPath controls the path of the
                                                            shadow image. You can use the preset paths UNIT_SHADOW_PATH and FLYER_SHADOW_PATH. shadowWidth and shadowHeight control
                                                            the size of the shadow. shadowX and shadowY are optional parameters that control the offset of the shadow center.
                                                            shadowAlpha is an optional parameter that controls the maximum alpha of the shadow. Default 255.
    CAT_MoveSound                                           A function that attaches a looping 3D-sound to the gizmo. Requires the soundPath field. The optional soundVolume field
                                                            specifies the volume of the attached sound (0-100). soundFadeInTime and soundFadeOutTime specify the fade duration of
                                                            the sound. soundMinDist and soundMaxDist specify the sound distances of the 3D sound.
    CAT_Orient2D                                            Orients the special effect to always be aligned with its movement direction in 2 dimensions.
    CAT_Orient3D                                            Orients the special effect to always be aligned with its movement direction in 3 dimensions.
    CAT_OrientPropelled2D                                   Orients the special effect to always be aligned with its acceleration direction in 2 dimensions. Can be combined with
                                                            CAT_AccelerateHoming functions. If you use your own acceleration function, use .ax and .ay for the fields determining
                                                            the acceleration.
    CAT_OrientPropelled3D                                   The same as CAT_OrientPropelled2D, but takes z-acceleration into account.
    CAT_OrientRoll                                          Orients the special effect of your gizmo to look like it is rolling across the ground. Your gizmo table requires
                                                            the .collisionRadius field to be set. Optional field .rollSpeed. Default value 1.
    CAT_OrientProjectile                                    Orients the special effect with OrientEffect3D until it collides with something, after which OrientRoll will be used.

    CAT_InitRandomOrientation(gizmo)                        Initializes the gizmo's special effect to a random orientation. Not a self-interaction function! Call this function
                                                            on your gizmo during creation after creating the special effect.
    CAT_InitDirectedOrientation(gizmo)                      Initializes the gizmo's special effect to an orientation pointing towards its movement direction. Not a
                                                            self-interaction function! Call this function on your gizmo during creation after creating the special effect.

    CAT_AttachEffect(whichGizmo, whichEffect, zOffset)      Attaches an additional effect to the gizmo. Not a self-interaction function! Call this function at any time, but only
                                                            after registering your gizmo with ALICE.

    --==========================================================================================================================================================================
    ]]

    local sqrt                              = math.sqrt
    local atan2                             = math.atan
    local cos                               = math.cos
    local sin                               = math.sin
    local min                               = math.min

    local GetTerrainZ                       = nil       ---@type function
    local moveableLoc                       = nil       ---@type location

    UNIT_SHADOW_PATH                        = "ReplaceableTextures\\Shadows\\Shadow.blp"
    FLYER_SHADOW_PATH                       = "ReplaceableTextures\\Shadows\\ShadowFlyer.blp"

    local function ClearShadow(gizmo, __, __)
        DestroyImage(gizmo.shadow)
    end

    ---@param gizmo table
    local function InitAnimateShadow(gizmo)
        gizmo.shadowX = gizmo.shadowX or 0
        gizmo.shadowY = gizmo.shadowY or 0
        gizmo.shadow = CreateImage(gizmo.shadowPath, gizmo.shadowWidth, gizmo.shadowHeight, 0, gizmo.x + (gizmo.shadowX) - 0.5*gizmo.shadowWidth, gizmo.y + (gizmo.shadowY) - 0.5*gizmo.shadowHeight, 0, 0, 0, 0, 1)
        SetImageRenderAlways(gizmo.shadow, true)
        gizmo.shadowAlpha = gizmo.shadowAlpha or 255
        SetImageColor(gizmo.shadow, 255, 255, 255, gizmo.shadowAlpha)
        SetImageAboveWater(gizmo.shadow, false, true)
        gizmo.shadowAttenuation = 0.047*gizmo.shadowAlpha/min(gizmo.shadowHeight, gizmo.shadowWidth)
    end

    ---Required fields:
    -- - shadowPath
    -- - shadowWidth
    -- - shadowHeight
    ---
    ---Optional fields:
    -- - shadowX
    -- - shadowY
    -- - shadowAlpha
    ---@param gizmo table
    function CAT_AnimateShadow(gizmo)
        local terrainZ = GetTerrainZ(gizmo.x, gizmo.y)
        if gizmo.z then
            local alpha = gizmo.shadowAlpha - (gizmo.shadowAttenuation*(gizmo.z - terrainZ)) // 1
            if alpha < 0 then
                alpha = 0
            end
            SetImageColor(gizmo.shadow, 255, 255, 255, alpha)
        end
        SetImagePosition(gizmo.shadow, gizmo.x + gizmo.shadowX - 0.5*gizmo.shadowWidth, gizmo.y + gizmo.shadowY - 0.5*gizmo.shadowHeight, 0)
        if gizmo.isResting then
            ALICE_PairPause()
        end
    end

    local function InitMoveSound(gizmo)
        gizmo.sound = CreateSound(gizmo.soundPath, true, true, true, 10, 10, "DefaultEAXON")
        SetSoundDistances(gizmo.sound, gizmo.soundMinDist or 600, gizmo.soundMaxDist or 4000)
        SetSoundPosition(gizmo.sound, ALICE_GetCoordinates3D(gizmo))
        if gizmo.soundFadeInTime then
            SetSoundVolumeBJ(gizmo.sound, 0)
            gizmo.currentSoundVolume = 0
        else
            SetSoundVolumeBJ(gizmo.sound, gizmo.soundVolume or 100)
        end
        StartSound(gizmo.sound)
    end

    local function FadeOutSound(counter, whichSound, maxVolume, maxCounter)
        if counter < maxCounter then
            SetSoundVolumeBJ(whichSound, maxVolume*(1 - counter/maxCounter))
        else
            StopSound(whichSound, true, false)
        end
    end

    local function MoveSoundOnDestroy(gizmo)
        if gizmo.soundFadeOutTime then
            local maxCounter = (gizmo.soundFadeOutTime/ALICE_Config.MIN_INTERVAL) // 1
            ALICE_CallRepeated(FadeOutSound, maxCounter, nil, gizmo.sound, gizmo.soundVolume or 100, maxCounter)
        else
            StopSound(gizmo.sound, true, false)
        end
    end

    ---Required fields:
    -- - soundPath
    ---
    ---Optional fields:
    -- - soundVolume
    -- - soundMinDist
    -- - soundMaxDist
    -- - soundFadeInTime
    -- - soundFadeOutTime
    function CAT_MoveSound(gizmo)
        SetSoundPosition(gizmo.sound, ALICE_GetCoordinates3D(gizmo))
        if gizmo.soundFadeInTime then
            gizmo.currentSoundVolume = math.min(gizmo.soundVolume or 100, gizmo.currentSoundVolume + (gizmo.soundVolume or 100)*INTERVAL/gizmo.soundFadeInTime)
            SetSoundVolumeBJ(gizmo.sound, gizmo.currentSoundVolume)
        end
    end

    local function ClearAttachedEffect(gizmo)
        if IsHandle[gizmo.attachedEffect] then
            DestroyEffect(gizmo.attachedEffect)
        else
            for __, effect in ipairs(gizmo.attachedEffect) do
                DestroyEffect(effect)
            end
        end
    end

    function CAT_MoveAttachedEffect(gizmo)
        if IsHandle[gizmo.attachedEffect] then
            BlzSetSpecialEffectPosition(gizmo.attachedEffect, gizmo.x, gizmo.y, (gizmo.z or GetTerrainZ(gizmo.x, gizmo.y)) + gizmo.attachedEffectZ)
        else
            for index, effect in ipairs(gizmo.attachedEffect) do
                BlzSetSpecialEffectPosition(effect, gizmo.x, gizmo.y, (gizmo.z or GetTerrainZ(gizmo.x, gizmo.y)) + gizmo.attachedEffectZ[index])
            end
        end
        if gizmo.isResting then
            ALICE_PairPause()
        end
    end

    ---Attaches an additional effect to the gizmo. Not a self-interaction function! Call this function at any time, but only after registering your gizmo with ALICE.
    ---@param whichGizmo table
    ---@param whichEffect effect
    ---@param zOffset? number
    function CAT_AttachEffect(whichGizmo, whichEffect, zOffset)
        if whichGizmo.attachedEffect == nil then
            whichGizmo.attachedEffect = whichEffect
            whichGizmo.attachedEffectZ = zOffset or 0
            ALICE_AddSelfInteraction(whichGizmo, CAT_MoveAttachedEffect)
        elseif IsHandle[whichGizmo.attachedEffect] then
            whichGizmo.attachedEffect = {whichGizmo.attachedEffect, whichEffect}
            whichGizmo.attachedEffectZ = {whichGizmo.attachedEffectZ, zOffset or 0}
        else
            table.insert(whichGizmo.attachedEffect, whichEffect)
            table.insert(whichGizmo.attachedEffectZ, zOffset or 0)
        end
    end

    local function InitMoveEffect(gizmo)
        gizmo.visualZ = gizmo.visualZ or 0
    end

    ---Optional fields:
    -- - visualZ
    function CAT_MoveEffect(gizmo)
        local x, y, z = ALICE_GetCoordinates3D(gizmo)
        BlzSetSpecialEffectPosition(gizmo.visual, x, y, z + gizmo.visualZ)
    end

    local function InitOrient2D(gizmo)
        if gizmo.vx and gizmo.vy then
            CAT_Orient2D(gizmo)
        end
    end

    local function InitOrient3D(gizmo)
        if gizmo.vx and gizmo.vy and gizmo.vz then
            CAT_Orient3D(gizmo)
        end
    end

    local function InitOrientPropelled2D(gizmo)
        if gizmo.ax and gizmo.ay then
            CAT_OrientPropelled2D(gizmo)
        end
    end

    local function InitOrientPropelled3D(gizmo)
        if gizmo.ax and gizmo.ay and gizmo.az then
            CAT_OrientPropelled3D(gizmo)
        end
    end

    function CAT_Orient2D(gizmo)
        if gizmo.vx ~= 0 or gizmo.vy ~= 0 then
            BlzSetSpecialEffectYaw(gizmo.visual, atan2(gizmo.vy, gizmo.vx))
        end
        if gizmo.isResting then
            ALICE_PairPause()
        end
        return 0.1
    end

    function CAT_Orient3D(gizmo)
        if gizmo.vx ~= 0 or gizmo.vy ~= 0 or gizmo.vz ~= 0 then
            BlzSetSpecialEffectOrientation(gizmo.visual, atan2(gizmo.vy, gizmo.vx), atan2(-gizmo.vz, sqrt(gizmo.vx^2 + gizmo.vy^2)), 0)
        end
        if gizmo.isResting then
            ALICE_PairPause()
        end
        return 0.1
    end

    function CAT_OrientPropelled2D(gizmo)
        if gizmo.ax ~= 0 or gizmo.ay ~= 0 then
            BlzSetSpecialEffectYaw(gizmo.visual, atan2(gizmo.ay, gizmo.ax))
        end
        return 0.1
    end

    function CAT_OrientPropelled3D(gizmo)
        if gizmo.ax ~= 0 or gizmo.ay ~= 0 or gizmo.az ~= 0 then
            BlzSetSpecialEffectOrientation(gizmo.visual, atan2(gizmo.ay, gizmo.ax), atan2(-gizmo.az, sqrt(gizmo.ax^2 + gizmo.ay^2)), 0)
        end
        return 0.1
    end

    local function InitOrientation(gizmo)
        if gizmo.O11 then
            return
        end
        gizmo.O11 = 1
        gizmo.O12 = 0
        gizmo.O13 = 0
        gizmo.O21 = 0
        gizmo.O22 = 1
        gizmo.O23 = 0
        gizmo.O31 = 0
        gizmo.O32 = 0
        gizmo.O33 = 1

        BlzSetSpecialEffectOrientation(gizmo.visual, atan2(-gizmo.O12, gizmo.O11), atan2(gizmo.O13, sqrt(gizmo.O12^2 + gizmo.O11^2)), atan2(gizmo.O23, gizmo.O33))
    end

    ---Optional fields:
    -- - rollSpeed
    function CAT_OrientRoll(gizmo)
        local norm = sqrt(gizmo.vy^2 + gizmo.vx^2)

        if norm == 0 then
            if gizmo.isResting then
                ALICE_PairPause()
            end
            return
        end

        local nx, ny = gizmo.vy/norm, gizmo.vx/norm

        local alpha = INTERVAL*norm/gizmo.collisionRadius*(gizmo.rollSpeed or 1)

        local cosAngle = cos(alpha)
        local sinAngle = sin(alpha)
        local oneMinCos = 1 - cosAngle

        local M11 = nx*nx*oneMinCos + cosAngle
        local M12 = nx*ny*oneMinCos
        local M13 = ny*sinAngle
        local M21 = ny*nx*oneMinCos
        local M22 = ny*ny*oneMinCos + cosAngle
        local M23 = -nx*sinAngle
        local M31 = -ny*sinAngle
        local M32 = nx*sinAngle
        local M33 = cosAngle

        local O11 = gizmo.O11*M11 + gizmo.O12*M21 + gizmo.O13*M31
        local O12 = gizmo.O11*M12 + gizmo.O12*M22 + gizmo.O13*M32
        local O13 = gizmo.O11*M13 + gizmo.O12*M23 + gizmo.O13*M33
        local O21 = gizmo.O21*M11 + gizmo.O22*M21 + gizmo.O23*M31
        local O22 = gizmo.O21*M12 + gizmo.O22*M22 + gizmo.O23*M32
        local O23 = gizmo.O21*M13 + gizmo.O22*M23 + gizmo.O23*M33
        local O31 = gizmo.O31*M11 + gizmo.O32*M21 + gizmo.O33*M31
        local O32 = gizmo.O31*M12 + gizmo.O32*M22 + gizmo.O33*M32
        local O33 = gizmo.O31*M13 + gizmo.O32*M23 + gizmo.O33*M33

        gizmo.O11, gizmo.O12, gizmo.O13, gizmo.O21, gizmo.O22, gizmo.O23, gizmo.O31, gizmo.O32, gizmo.O33 = O11, O12, O13, O21, O22, O23, O31, O32, O33

        BlzSetSpecialEffectOrientation(gizmo.visual, atan2(-gizmo.O12, gizmo.O11), atan2(gizmo.O13, sqrt(gizmo.O12^2 + gizmo.O11^2)), atan2(gizmo.O23, gizmo.O33))
    end

    function CAT_OrientProjectile(gizmo)
        if not gizmo.hasCollided then
            CAT_Orient3D(gizmo)
        else
            CAT_InitRandomOrientation(gizmo)
            ALICE_PairSetInteractionFunc(CAT_OrientRoll)
            CAT_OrientRoll(gizmo)
        end
    end

    ---Initializes the gizmo's special effect to a random orientation. Not a self-interaction function! Call this function on your gizmo during creation after creating the special effect.
    ---@param gizmo table
    function CAT_InitRandomOrientation(gizmo)
        local nx = 1 - GetRandomReal(0, 2)
        local ny = 1 - GetRandomReal(0, 2)
        local nz = 1 - GetRandomReal(0, 2)
        local norm = sqrt(nx^2 + ny^2 + nz^2)

        if norm == 0 then
            return
        end

        nx, ny, nz = nx/norm, ny/norm, nz/norm

        local alpha = GetRandomReal(0, 2*bj_PI)
        local cosAngle = cos(alpha)
        local sinAngle = sin(alpha)
        local oneMinCos = 1 - cosAngle

        gizmo.O11 = nx*nx*oneMinCos + cosAngle
        gizmo.O12 = nx*ny*oneMinCos - nz*sinAngle
        gizmo.O13 = nx*nz*oneMinCos + ny*sinAngle
        gizmo.O21 = ny*nx*oneMinCos + nz*sinAngle
        gizmo.O22 = ny*ny*oneMinCos + cosAngle
        gizmo.O23 = ny*nz*oneMinCos - nx*sinAngle
        gizmo.O31 = nz*nx*oneMinCos - ny*sinAngle
        gizmo.O32 = nz*ny*oneMinCos + nx*sinAngle
        gizmo.O33 = nz*nz*oneMinCos + cosAngle

        BlzSetSpecialEffectOrientation(gizmo.visual, atan2(-gizmo.O12, gizmo.O11), atan2(gizmo.O13, sqrt(gizmo.O12^2 + gizmo.O11^2)), atan2(gizmo.O23, gizmo.O33))
    end

    ---Initializes the gizmo's special effect to an orientation pointing towards its movement direction. Not a self-interaction function! Call this function on your gizmo during creation after creating the special effect.
    ---@param gizmo table
    function CAT_InitDirectedOrientation(gizmo)
        local alpha = atan2(gizmo.vy, gizmo.vx)
        local cosAngle = cos(alpha)
        local sinAngle = sin(alpha)

        gizmo.O11 = cosAngle
        gizmo.O12 = -sinAngle
        gizmo.O13 = 0
        gizmo.O21 = sinAngle
        gizmo.O22 = cosAngle
        gizmo.O23 = 0
        gizmo.O31 = 0
        gizmo.O32 = 0
        gizmo.O33 = 1

        BlzSetSpecialEffectOrientation(gizmo.visual, atan2(-gizmo.O12, gizmo.O11), atan2(gizmo.O13, sqrt(gizmo.O12^2 + gizmo.O11^2)), atan2(gizmo.O23, gizmo.O33))
    end

    function InitEffectsCAT()
        Require("ALICE")
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

        INTERVAL = ALICE_Config.MIN_INTERVAL
        ALICE_FuncSetInit(CAT_AnimateShadow, InitAnimateShadow)
        ALICE_FuncSetInit(CAT_MoveSound, InitMoveSound)
        ALICE_FuncSetInit(CAT_MoveEffect, InitMoveEffect)
        ALICE_FuncSetInit(CAT_OrientRoll, InitOrientation)
        ALICE_FuncSetInit(CAT_Orient2D, InitOrient2D)
        ALICE_FuncSetInit(CAT_Orient3D, InitOrient3D)
        ALICE_FuncSetInit(CAT_OrientPropelled2D, InitOrientPropelled2D)
        ALICE_FuncSetInit(CAT_OrientPropelled3D, InitOrientPropelled3D)
        ALICE_FuncSetInit(CAT_OrientProjectile, InitOrient3D)
        ALICE_FuncSetOnDestroy(CAT_MoveAttachedEffect, ClearAttachedEffect)
        ALICE_FuncSetOnDestroy(CAT_AnimateShadow, ClearShadow)
        ALICE_FuncSetOnDestroy(CAT_MoveSound, MoveSoundOnDestroy)

        ALICE_FuncRequireFields(CAT_AnimateShadow, true, false, "shadowPath", "shadowWidth", "shadowHeight")
        ALICE_FuncRequireFields(CAT_MoveSound, true, false, "soundPath")
        ALICE_FuncRequireFields(CAT_OrientRoll, true, false, "collisionRadius")
        ALICE_FuncRequireFields(CAT_OrientProjectile, true, false, "collisionRadius")
    end

    OnInit.final("CAT_Effects", InitEffectsCAT)
end
