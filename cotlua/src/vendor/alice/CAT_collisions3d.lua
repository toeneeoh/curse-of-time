if Debug then Debug.beginFile "CAT Collisions3D" end
do
    --[[
    =============================================================================================================================================================
                                                                Complementary ALICE Template
                                                                        by Antares

                            Requires:
                            ALICE                               https://www.hiveworkshop.com/threads/a-l-i-c-e-interaction-engine.353126/
                            Data CAT
                            Units CAT
                            Interfaces CAT
                            TotalInitialization                 https://www.hiveworkshop.com/threads/total-initialization.317099/
                            PrecomuptedHeightMap (optional)     https://www.hiveworkshop.com/threads/precomputed-synchronized-terrain-height-map.353477/

                            Knockback Item ('Ikno') (optional)

    =============================================================================================================================================================
                                                                  C O L L I S I O N S   3 D
    =============================================================================================================================================================

    This template contains various functions to detect and execute collisions between gizmos* and any type of object. Terrain collision is not part of this
    template. The functions are accessed by adding them to your gizmo class tables (for an example, see Gizmos CAT).

        *Objects represented by a table with coordinate fields .x, .y, .z, velocity fields .vx, .vy, .vz, and a special effect .visual.


    To add collisions, add a collision check function to the ALICE interactions table of your gizmos. Each object type has its own collision check function.
    They are:

    CAT_GizmoCollisionCheck3D
    CAT_UnitCollisionCheck3D
    CAT_DestructableCollisionCheck3D
    CAT_ItemCollisionCheck3D

    Example:

    interactions = {
        unit = CAT_UnitCollisionCheck3D,
        destructable = CAT_DestructableCollisionCheck3D
    }

    By default, collision checks will not discriminate between friend or foe. To disable friendly-fire, set the .friendlyFire field in your gizmo table to false
    and the .owner field to the owner of the gizmo. This works for unit and gizmo collision checks.

    You can also set the .onlyTarget field. This will disable collision checks with any unit that isn't set as the .target of the gizmo.

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    
    To execute code on collision, you need to define an onCollision function, where there are, again, different ones for each object type. The table fields you
    need to set for onCollision functions are:

    onGizmoCollision
    onUnitCollision
    onDestructableCollision
    onItemCollision

    You can use an onCollision function provided in this CAT or your own function. The preset functions are listed further down below.

    The value for any table field you set for this CAT can be either a function or a table. A table is set up similarly to how an ALICE interactions table is set
    up, where the keys denote the identifiers of the objects for which that function is used. You can use tables as keys, listing multiple identifiers, and you
    can also use the "other" keyword. If no onCollision function is provided, the gizmo will simply be destroyed on collision.

    Example:

    onGizmoCollision = {
        [{"ball", "soft"}] = CAT_GizmoBounce3D,
        spike = CAT_GizmoImpact3D,
        other = CAT_GizmoPassThrough3D
    }

    -------------------------------------------------------------------------------------------------------------------------------------------------------------

    For a simple projectile or missile dealing damage, you can use the onDamage feature without defining an onCollision function. The possible table fields are:

    onUnitDamage
    onDestructableDamage
    onItemDamage

    Each value can be a function or a number. A function is called with the arguments (gizmo, object) and the return value is used as the damage amount.

    Example:

    onUnitDamage = {
        "hero" = GetRandomDamageAmount,
        "nonhero" = 5,
    }

    You can customize the damage and attack types of the damage. The .onUnitAttackType field determines the attack type used. The default type is ATTACK_TYPE_NORMAL.
    The same for .onUnitDamageType. The default type is DAMAGE_TYPE_MAGIC.

    onDamage can be combined with onCollision functions. If you do, additional parameters are passed into a damage function related to the impact velocity of the
    collision:

    onDamageFunction(gizmo, object, perpendicularSpeed, parallelSpeed, totalSpeed)

    For onUnitDamage, the .source field must be set to specify the source of the damage.

    -------------------------------------------------------------------------------------------------------------------------------------------------------------

    The onCollision functions also allow you to define an additional callback function. There are no preset functions. The table fields for these callback functions
    are:

    onGizmoCallback
    onUnitCallback
    onDestructableCallback
    onItemCallback

    These table fields have no effect unless an onCollision function has been set. The callback function will be called with these input arguments:

    callback(
        gizmo, object,
        collisionPointX, collisionPointY, collisionPointZ,
        perpendicularSpeed, parallelSpeed, totalSpeed,
        centerOfMassVelocityX, centerOfMassVelocityY, centerOfMassVelocityZ
    )

    The main advantage of definining your custom callback function as an onCallback instead of an onCollision function is that the onCollision functions calculate
    additional parameters of the collision, such as impact velocity and exact impact point, before invoking the callback function.

    -------------------------------------------------------------------------------------------------------------------------------------------------------------

    !!!IMPORTANT!!! There are additional table fields that need to be set for collision checks to work correctly.

        • .collisionRadius must be set to define the radius of your gizmo. Their collision box is a sphere. The collision boxes of widgets are customized in the
          Data CAT.
        • .mass is necessary for knockbacks. The masses of units are customized in the Data CAT.
        • .maxSpeed controls how often a collision check is performed. It represents the maximum speed that the gizmo can reasonably reach. If not set, the
          default value, set in the Data CAT, will be used.
        • .elasticity is used by bounce functions. The default value is 1. The elasticity of widgets can be customized in the Data CAT. The elasticity of a
          collision is sqrt(elasticity 1 * elasticity 2).

    -------------------------------------------------------------------------------------------------------------------------------------------------------------
    Anchors:

    You can anchor a table to a widget. This will reroute the collision recoil to the anchor if it is a unit. You can also enable unit-widget collisions this way,
    although there may be some bugs and issues with this. If the table has a mass field, that value will be used to calculate the recoil. Otherwise, the unit's mass
    will be used. Other fields cannot be overwritten and must be provided.

    =============================================================================================================================================================
                                                            L I S T   O F   F U N C T I O N S
    =============================================================================================================================================================

    Gizmo-Gizmo Collisions:

        CAT_GizmoCollisionCheck3D
        CAT_GizmoCylindricalCollisionCheck3D    Models the receiving gizmo as a cylinder with a rounded top instead of a sphere. The receiving gizmo needs to have
                                                the collisionHeight field in its table.

        Callbacks:

            CAT_GizmoBounce3D                   Reflect the two gizmos.
            CAT_GizmoImpact3D                   Destroy the initiating gizmo and recoil the other.
            CAT_GizmoDevour3D                   Destroy the receiving gizmo and recoil the other.
            CAT_GizmoAnnihilate3D               Destroy both gizmos.
            CAT_GizmoPassThrough3D              Execute the callback function once, but do not destroy or recoil either.
            CAT_GizmoMultiPassThrough3D         Execute the callback function once each time the gizmo and the unit pass through each other.


    Gizmo-Unit Collisions:

        CAT_UnitCollisionCheck3D

        Callbacks:

            CAT_UnitBounce3D                    Reflect the gizmo on the unit and recoil the unit.
            CAT_UnitImpact3D                    Destroy the gizmo and recoil the unit.
            CAT_UnitDevour3D                    Kill the unit and recoil the gizmo.
            CAT_UnitAnnihilate3D                Destroy both the unit and the gizmo.
            CAT_UnitPassThrough3D               Execute the callback function once, but do not destroy or recoil either.
            CAT_UnitMultiPassThrough3D          Execute the callback function once each time the gizmo and the unit pass through each other.


    Gizmo-Destructable Collisions:

        CAT_DestructableCollisionCheck3D

        Callbacks:

            CAT_DestructableBounce3D            Reflect the gizmo on the destructable.
            CAT_DestructableImpact3D            Destroy the gizmo.
            CAT_DestructableDevour3D            Destroy the destructable and recoil the gizmo.
            CAT_DestructableAnnihilate3D        Destroy both the destructable and the gizmo.
            CAT_DestructablePassThrough3D       Execute the callback function once, but do not destroy or recoil either.
            CAT_DestructableMultiPassThrough3D  Execute the callback function once each time the gizmo and the destructable pass through each other.


    Gizmo-Item Collisions:

        CAT_ItemCollisionCheck3D

        Callbacks:

            CAT_ItemBounce3D                    Reflect the gizmo on the item.
            CAT_ItemImpact3D                    Destroy the gizmo.
            CAT_ItemDevour3D                    Destroy the item and recoil the gizmo.
            CAT_ItemAnnihilate3D                Destroy the item and the gizmo.
            CAT_ItemPassThrough3D               Execute the callback function once, but do not destroy or recoil either.
            CAT_ItemMultiPassThrough3D          Execute the callback function once each time the gizmo and the item pass through each other.
            
    --===========================================================================================================================================================
    ]]

    local INTERVAL                          = nil
    local UNIT_MAX_SPEED                    = 522

    local INF                               = math.huge

    local sqrt                              = math.sqrt
    local cos                               = math.cos
    local sin                               = math.sin
    local atan2                             = math.atan
    local GetTerrainZ                       = nil       ---@type function
    local moveableLoc                       = nil       ---@type location

    local function DamageWidget(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed)
        if HandleType[widget] == "unit" then
            local damage = ALICE_FindField(gizmo.onUnitDamage, widget)
            if type(damage) == "function" then
                UnitDamageTarget(gizmo.source, widget, damage(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed), false, false, gizmo.onUnitAttackType or ATTACK_TYPE_NORMAL, gizmo.onUnitDamageType or DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            else
                UnitDamageTarget(gizmo.source, widget, damage, false, false, gizmo.onUnitAttackType or ATTACK_TYPE_NORMAL, gizmo.onUnitDamageType or DAMAGE_TYPE_MAGIC, WEAPON_TYPE_WHOKNOWS)
            end
        elseif HandleType[widget] == "destructable" then
            local damage = ALICE_FindField(gizmo.onDestructableDamage, widget)
            if type(damage) == "function" then
                SetDestructableLife(widget, GetDestructableLife(widget) - damage(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed))
            else
                SetDestructableLife(widget, GetDestructableLife(widget) - damage)
            end
        else
            local damage = ALICE_FindField(gizmo.onItemDamage, widget)
            if type(damage) == "function" then
                SetWidgetLife(widget, GetWidgetLife(widget) - damage(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed))
            else
                SetWidgetLife(widget, GetWidgetLife(widget) - damage)
            end
        end
    end

    local function GetBacktrackRatio(dist, collisionDist, dx, dy, dz, dvx, dvy, dvz)
        if dvx == 0 and dvy == 0 and dvz == 0 then
            return 0
        end

        local lastStepDist = sqrt((dx - dvx*INTERVAL)^2 + (dy - dvy*INTERVAL)^2 + (dz - dvz*INTERVAL)^2)
        if lastStepDist > collisionDist then
            return (collisionDist - dist)/(lastStepDist - dist)
        else
            return 0
        end
    end

   --===========================================================================================================================================================
    --Gizmo-Gizmo Collisions
    --==========================================================================================================================================================

    ---@param A table
    ---@param B table
    local function GetGizmoCollisionPoint3D(A, B, ax, ay, az, bx, by, bz)
        local collisionDist = A.collisionRadius + B.collisionRadius
        local collisionX = (ax*B.collisionRadius + bx*A.collisionRadius)/collisionDist
        local collisionY = (ay*B.collisionRadius + by*A.collisionRadius)/collisionDist
        local collisionZ = (az*B.collisionRadius + bz*A.collisionRadius)/collisionDist

        return collisionX, collisionY, collisionZ, collisionDist
    end

    local function GizmoCollisionMath3D(A, B)
        local xa, ya, za, xb, yb, zb = ALICE_PairGetCoordinates3D()
        local dx, dy, dz = xa - xb, ya - yb, za - zb
        local vxa, vya, vza = CAT_GetObjectVelocity3D(A)
        local vxb, vyb, vzb = CAT_GetObjectVelocity3D(B)
        local dvx, dvy, dvz = vxa - vxb, vya - vyb, vza - vzb
        local dist = sqrt(dx*dx + dy*dy + dz*dz)

        local perpendicularSpeed = -(dx*dvx + dy*dvy + dz*dvz)/dist

        local totalSpeed = sqrt(dvx*dvx + dvy*dvy + dvz*dvz)
        local parallelSpeed = sqrt(totalSpeed^2 - perpendicularSpeed^2)

        local massA = CAT_GetObjectMass(A)
        local massB = CAT_GetObjectMass(B)
        local invMassSum = 1/(massA + massB)
        local centerOfMassVx, centerOfMassVy, centerOfMassVz

        if massA == INF then
            if massB == INF then
                centerOfMassVx = (vxa*massA + vxb*massB)*invMassSum
                centerOfMassVy = (vya*massA + vyb*massB)*invMassSum
                centerOfMassVz = (vza*massA + vzb*massB)*invMassSum
            else
                centerOfMassVx = vxa
                centerOfMassVy = vya
                centerOfMassVz = vza
            end
        elseif massB == INF then
            centerOfMassVx = vxb
            centerOfMassVy = vyb
            centerOfMassVz = vzb
        elseif massA == 0 and massB == 0 then
            centerOfMassVx = (vxa + vxb)/2
            centerOfMassVy = (vya + vyb)/2
            centerOfMassVz = (vza + vzb)/2
        else
            centerOfMassVx = (vxa*massA + vxb*massB)*invMassSum
            centerOfMassVy = (vya*massA + vyb*massB)*invMassSum
            centerOfMassVz = (vza*massA + vzb*massB)*invMassSum
        end

        return perpendicularSpeed >= 0, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz
    end

    local function GizmoRecoilAndDisplace3D(object, x, y, z, recoilX, recoilY, recoilZ)
        if object.anchor then
            if type(object.anchor) == "table" then
                object.anchor.x,object.anchor.y, object.anchor.z = x, y, z
                object.anchor.vx, object.anchor.vy, object.anchor.vz = object.anchor.vx + recoilX, object.anchor.vy + recoilY, object.anchor.vz + recoilZ
            else
                SetUnitX(object.anchor, x)
                SetUnitY(object.anchor, y)
                CAT_Knockback(object.anchor, recoilX, recoilY, recoilZ)
            end
        else
            object.x,object.y, object.z = x, y, z
            object.vx, object.vy, object.vz = object.vx + recoilX, object.vy + recoilY, object.vz + recoilZ
        end
    end

    local function GizmoRecoil3D(object, recoilX, recoilY, recoilZ)
        if object.anchor then
            if type(object.anchor) == "table" then
                object.anchor.vx, object.anchor.vy, object.anchor.vz = object.anchor.vx + recoilX, object.anchor.vy + recoilY, object.anchor.vz + recoilZ
            else
                CAT_Knockback(object.anchor, recoilX, recoilY, recoilZ)
            end
        else
            object.vx, object.vy, object.vz = object.vx + recoilX, object.vy + recoilY, object.vz + recoilZ
        end
    end

    local function GetMassRatio(massA, massB)
        --massA >>> massB -> 1
        --massB >>> massA -> 0
        if massA == 0 and massB == 0 then
            return 0.5
        elseif massA == INF then
            if massB == INF then
                return 0.5
            else
                return 1
            end
        else
            return massA/(massA + massB)
        end
    end

    -------------
    --Callbacks
    -------------

    ---Optional fields:
    -- - elasticity
    -- - mass
    -- - onGizmoCallback
    function CAT_GizmoBounce3D(A, B)
        local validCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = GizmoCollisionMath3D(A, B)

        if not validCollision then
            return
        end

        local elasticity = sqrt((A.elasticity or 1)*(B.elasticity or 1))
        local e = (1 + elasticity)

        local Aunmoved
        local Bunmoved
        --Avoid unpausing resting gizmo with only minor bounce.
        if A.isResting and perpendicularSpeed*e/2*B.mass/A.mass < A.friction*CAT_Data.STATIC_FRICTION_FACTOR*INTERVAL then
            Aunmoved = true
        end
        if B.isResting and perpendicularSpeed*e/2*A.mass/B.mass < B.friction*CAT_Data.STATIC_FRICTION_FACTOR*INTERVAL then
            Bunmoved = true
        end

        local nx, ny, nz = dx/dist, dy/dist, dz/dist

        local Advx = vxa - centerOfMassVx
        local Advy = vya - centerOfMassVy
        local Advz = vza - centerOfMassVz
        local Bdvx = vxb - centerOfMassVx
        local Bdvy = vyb - centerOfMassVy
        local Bdvz = vzb - centerOfMassVz

        --Householder transformation.
        local H11 = 1 - e*nx^2
        local H12 = -e*nx*ny
        local H13 = -e*nx*nz
        local H21 = H12
        local H22 = 1 - e*ny^2
        local H23 = -e*ny*nz
        local H31 = H13
        local H32 = H23
        local H33 = 1 - e*nz^2

        local collisionX, collisionY, collisionZ, collisionDist = GetGizmoCollisionPoint3D(A, B, xa, ya, za, xb, yb, zb)
        local massRatio
        if Aunmoved then
            massRatio = 1
        elseif Bunmoved then
            massRatio = 0
        else
            massRatio = GetMassRatio(massA, massB)
        end

        local xNew, yNew, zNew, recoilX, recoilY, recoilZ
        local displacement = collisionDist - dist
        if massRatio < 1 then
            xNew = xa + 1.001*dx/dist*displacement*(1 - massRatio)
            yNew = ya + 1.001*dy/dist*displacement*(1 - massRatio)
            zNew = za + 1.001*dz/dist*displacement*(1 - massRatio)
            if A.isAirborne == false and GetTerrainZ(xNew,yNew) - zNew > 64 then --Object is against a cliff and can't be displaced.
                massRatio = 1
            else
                recoilX = H11*Advx + H12*Advy + H13*Advz + centerOfMassVx - vxa
                recoilY = H21*Advx + H22*Advy + H23*Advz + centerOfMassVy - vya
                recoilZ = H31*Advx + H32*Advy + H33*Advz + centerOfMassVz - vza

                GizmoRecoilAndDisplace3D(A, xNew, yNew, zNew, recoilX, recoilY, recoilZ)
            end
        else
            A.vx, A.vy, A.vz = 0, 0, 0
        end

        if massRatio > 0 then
            xNew = xb - 1.001*dx/dist*displacement*massRatio
            yNew = yb - 1.001*dy/dist*displacement*massRatio
            zNew = zb - 1.001*dz/dist*displacement*massRatio

            if B.isAirborne ~= false or GetTerrainZ(xNew,yNew) - zNew < 64 then --Object is against a cliff and can't be displaced.
                recoilX = H11*Bdvx + H12*Bdvy + H13*Bdvz + centerOfMassVx - vxb
                recoilY = H21*Bdvx + H22*Bdvy + H23*Bdvz + centerOfMassVy - vyb
                recoilZ = H31*Bdvx + H32*Bdvy + H33*Bdvz + centerOfMassVz - vzb

                GizmoRecoilAndDisplace3D(B, xNew, yNew, zNew, recoilX, recoilY, recoilZ)
            end
        else
            B.vx, B.vy, B.vz = 0, 0, 0
        end

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            callback(A, B, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end
    end

    ---Optional fields:
    -- - mass
    -- - onGizmoCallback
    function CAT_GizmoImpact3D(A, B)
        local validCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = GizmoCollisionMath3D(A, B)

        local collisionX, collisionY, collisionZ, collisionDist = GetGizmoCollisionPoint3D(A, B, xa, ya, za, xb, yb, zb)

        if massA > 0 then
            local unmoved
            --Avoid unpausing resting gizmo with only minor bounce.
            if B.isResting and perpendicularSpeed/2*A.mass/B.mass < B.friction*CAT_Data.STATIC_FRICTION_FACTOR*INTERVAL or (massB == INF and massA == INF) then
                unmoved = true
            end
            if not unmoved then
                local recoilX, recoilY, recoilZ
                local massRatio = GetMassRatio(massA, massB)
                if massRatio > 0 then
                    recoilX = dvx*massRatio
                    recoilY = dvy*massRatio
                    recoilZ = dvz*massRatio
                    GizmoRecoil3D(B, recoilX, recoilY, recoilZ)
                end
            end
        end

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            callback(A, B, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        if HandleType[A.visual] == "effect" then
            local r = GetBacktrackRatio(dist, collisionDist, dx, dy, dz, dvx, dvy, dvz)
            local xBacktracked, yBacktracked, zBacktracked = A.x - r*A.vx*INTERVAL, A.y - r*A.vy*INTERVAL, A.z - r*A.vz*INTERVAL
            BlzSetSpecialEffectPosition(A.visual, xBacktracked, yBacktracked, zBacktracked)
        end
        ALICE_Kill(A)
    end

    ---Optional fields:
    -- - mass
    -- - onGizmoCallback
    function CAT_GizmoDevour3D(A, B)
        local validCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = GizmoCollisionMath3D(A, B)

        local collisionX, collisionY, collisionZ, collisionDist = GetGizmoCollisionPoint3D(A, B, xa, ya, za, xb, yb, zb)

        if massA > 0 then
            local unmoved
            --Avoid unpausing resting gizmo with only minor bounce.
            if A.isResting and perpendicularSpeed/2*B.mass/A.mass < A.friction*CAT_Data.STATIC_FRICTION_FACTOR*INTERVAL or (massA == INF and massB == INF) then
                unmoved = true
            end
            if not unmoved then
                local recoilX, recoilY, recoilZ
                local massRatio = GetMassRatio(massA, massB)
                if massRatio > 0 then
                    recoilX = -dvx*(1 - massRatio)
                    recoilY = -dvy*(1 - massRatio)
                    recoilZ = -dvz*(1 - massRatio)
                    GizmoRecoil3D(A, recoilX, recoilY, recoilZ)
                end
            end
        end

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            callback(A, B, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        if HandleType[B.visual] == "effect" then
            local r = GetBacktrackRatio(dist, collisionDist, dx, dy, dz, dvx, dvy, dvz)
            local xBacktracked, yBacktracked, zBacktracked = B.x - r*B.vx*INTERVAL, B.y - r*B.vy*INTERVAL, B.z - r*B.vz*INTERVAL
            BlzSetSpecialEffectPosition(A.visual, xBacktracked, yBacktracked, zBacktracked)
        end
        ALICE_Kill(B)
    end

    ---Optional fields:
    -- - onGizmoCallback
    function CAT_GizmoAnnihilate3D(A, B)
        local validCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = GizmoCollisionMath3D(A, B)

        local collisionX, collisionY, collisionZ, collisionDist = GetGizmoCollisionPoint3D(A, B, xa, ya, za, xb, yb, zb)

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            callback(A, B, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        local r = GetBacktrackRatio(dist, collisionDist, dx, dy, dz, dvx, dvy, dvz)
        local xBacktracked, yBacktracked, zBacktracked
        if HandleType[A.visual] == "effect" then
            xBacktracked, yBacktracked, zBacktracked = A.x - r*A.vx*INTERVAL, A.y - r*A.vy*INTERVAL, A.z - r*A.vz*INTERVAL
            BlzSetSpecialEffectPosition(A.visual, xBacktracked, yBacktracked, zBacktracked)
        end
        ALICE_Kill(A)
        if HandleType[B.visual] == "effect" then
            xBacktracked, yBacktracked = B.x - r*B.vx*INTERVAL, B.y - r*B.vy*INTERVAL
            BlzSetSpecialEffectPosition(A.visual, xBacktracked, yBacktracked, zBacktracked)
        end
        ALICE_Kill(B)
    end

    ---Required fields:
    -- - onGizmoCallback
    function CAT_GizmoPassThrough3D(A, B)
        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            local validCollision, xa, ya, za, xb, yb, zb, dist,
            vxa, vya, vza, vxb, vyb, vzb,
            dx, dy, dz, dvx, dvy, dvz,
            massA, massB,
            perpendicularSpeed, totalSpeed, parallelSpeed,
            centerOfMassVx, centerOfMassVy, centerOfMassVz = GizmoCollisionMath3D(A, B)

            local collisionX, collisionY, collisionZ, collisionDist = GetGizmoCollisionPoint3D(A, B, xa, ya, za, xb, yb, zb)
            callback(A, B, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        ALICE_PairDisable()
    end

    ---Required fields:
    -- - onGizmoCallback
    function CAT_GizmoMultiPassThrough3D(A, B)
        local data = ALICE_PairLoadData()
        if data.insideCollisionRange then
            return
        end
        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            local validCollision, xa, ya, za, xb, yb, zb, dist,
            vxa, vya, vza, vxb, vyb, vzb,
            dx, dy, dz, dvx, dvy, dvz,
            massA, massB,
            perpendicularSpeed, totalSpeed, parallelSpeed,
            centerOfMassVx, centerOfMassVy, centerOfMassVz = GizmoCollisionMath3D(A, B)

            local collisionX, collisionY, collisionZ, collisionDist = GetGizmoCollisionPoint3D(A, B, xa, ya, za, xb, yb, zb)
            callback(A, B, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        data.insideCollisionRange = true
    end

    --------------------
    --Collision Checks
    --------------------

    ---Required fields:
    -- - collisionRadius
    -- - collisionHeight (female)
    ---
    ---Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision (male)
    function CAT_GizmoCylindricalCollisionCheck3D(gizmo, cylinder)
        local dx, dy, dz, dist
        if gizmo.anchor or cylinder.anchor then
            local xa, ya, za, xb, yb, zb = ALICE_PairGetCoordinates3D()
            dx, dy, dz = xb - xa, yb - ya, zb - za
        else
            dx, dy, dz = cylinder.x - gizmo.x, cylinder.y - gizmo.y, cylinder.z - gizmo.z
        end
        local horiDist = sqrt(dx*dx + dy*dy)
        local collisionRange = gizmo.collisionRadius + cylinder.collisionRadius
        local maxdz = cylinder.collisionHeight/2 + gizmo.collisionRadius

        if horiDist < collisionRange and dz < maxdz and dz > -maxdz and not (gizmo.friendlyFire == false and ALICE_PairIsFriend()) then
            local dtop = cylinder.collisionHeight/2 - dz
            if dtop < cylinder.collisionRadius then
                dist = sqrt(horiDist*horiDist + (dtop - cylinder.collisionRadius)^2)
            else
                dist = horiDist
            end

            if dist < collisionRange then
                local callback = ALICE_FindField(gizmo.onGizmoCollision, cylinder)
                if callback then
                    callback(gizmo, cylinder)
                else
                    if gizmo.onUnitDamage then
                        DamageWidget(gizmo, cylinder)
                    end
                    ALICE_Kill(gizmo)
                end
            end
        else
            dist = sqrt(horiDist*horiDist + dz*dz)
        end

        return (horiDist - collisionRange)/((gizmo.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED) + (cylinder.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED))
    end

    ---Required fields:
    -- - collisionRadius
    ---
    ---Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision (male)
    function CAT_GizmoCollisionCheck3D(A, B)
        local dx, dy, dz, dist
        if A.anchor or B.anchor then
            dist = ALICE_PairGetDistance3D()
        else
            dx = A.x - B.x
            dy = A.y - B.y
            dz = A.z - B.z
            dist = sqrt(dx*dx + dy*dy + dz*dz)
        end

        local collisionRange = A.collisionRadius + B.collisionRadius

        if dist < collisionRange and not (A.friendlyFire == false and ALICE_PairIsFriend()) then
            local callback = ALICE_FindField(A.onGizmoCollision, B)
            A.hasCollided = true
            B.hasCollided = true
            if callback then
                callback(A, B)
            end
        end

        if A.isResting and B.isResting then
            ALICE_PairPause()
        end

        return (dist - collisionRange)/((A.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED) + (B.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED))
    end

   --===========================================================================================================================================================
    --Gizmo-Widget Collisions
    --==========================================================================================================================================================

    local function WidgetCollisionMath3D(gizmo, widget)
        local data = ALICE_PairLoadData()
        local xa, ya, za, xb, yb, zb = ALICE_PairGetCoordinates3D()
        local dx, dy, dz = xa - xb, ya - yb, za - zb
        local vxa, vya, vza = CAT_GetObjectVelocity3D(gizmo)
        local vxb, vyb, vzb = CAT_GetObjectVelocity3D(widget)
        local dvx, dvy, dvz = vxa - vxb, vya - vyb, vza - vzb
        local dist = sqrt(dx*dx + dy*dy + dz*dz)

        local nx, ny, nz
        local collisionX, collisionY, collisionZ
        local overlap

        local phi = atan2(dy, dx)
        local theta
        local dtop = data.height/2 - dz
        local dbottom = -dz - data.height/2
        if dtop < data.radius then
            theta = atan2(data.radius - dtop, sqrt(dx*dx + dy*dy))
            local cosTheta = cos(theta)
            nx = cos(phi)*cosTheta
            ny = sin(phi)*cosTheta
            nz = sin(theta)
            collisionZ = zb + data.height/2 - (1 - nz)*data.radius
            overlap = (data.radius + gizmo.collisionRadius) - sqrt(dx*dx + dy*dy + (data.radius - dtop)^2)
        elseif HandleType[widget] == "unit" and GetUnitFlyHeight(widget) > 0 and dbottom  < data.radius then
            theta = atan2(dbottom - data.radius, sqrt(dx*dx + dy*dy))
            local cosTheta = cos(theta)
            nx = cos(phi)*cosTheta
            ny = sin(phi)*cosTheta
            nz = sin(theta)
            collisionZ = zb - data.height/2 + (1 + nz)*data.radius
            overlap = (data.radius + gizmo.collisionRadius) - sqrt(dx*dx + dy*dy + (dbottom - data.radius)^2)
        else
            local horiDist = sqrt(dx*dx + dy*dy)
            nx = dx/horiDist
            ny = dy/horiDist
            nz = 0
            collisionZ = za
            overlap = data.radius + gizmo.collisionRadius - horiDist
        end

        local perpendicularSpeed = -(nx*dvx + ny*dvy + nz*dvz)

        collisionX = xb + nx*data.radius
        collisionY = yb + ny*data.radius

        local totalSpeed = sqrt(dvx*dvx + dvy*dvy + dvz*dvz)
        local parallelSpeed = sqrt(totalSpeed^2 - perpendicularSpeed^2)

        local massA = CAT_GetObjectMass(gizmo)
        local massB = CAT_GetObjectMass(widget)
        local massSum = massA + massB
        local centerOfMassVx, centerOfMassVy, centerOfMassVz

        if massA == INF then
            if massB == INF then
                centerOfMassVx = (vxa*massA + vxb*massB)/massSum
                centerOfMassVy = (vya*massA + vyb*massB)/massSum
                centerOfMassVz = (vza*massA + vzb*massB)/massSum
            else
                centerOfMassVx = vxa
                centerOfMassVy = vya
                centerOfMassVz = vza
            end
        elseif massB == INF then
            centerOfMassVx = vxb
            centerOfMassVy = vyb
            centerOfMassVz = vzb
        else
            centerOfMassVx = (vxa*massA + vxb*massB)/massSum
            centerOfMassVy = (vya*massA + vyb*massB)/massSum
            centerOfMassVz = (vza*massA + vzb*massB)/massSum
        end

        return perpendicularSpeed >= 0, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        nx, ny, nz,
        collisionX, collisionY, collisionZ, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz
    end

    -------------
    --Callbacks
    -------------

    local function WidgetBounce3D(gizmo, widget)

        local isValidCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        nx, ny, nz,
        collisionX, collisionY, collisionZ, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = WidgetCollisionMath3D(gizmo, widget)

        if not isValidCollision then
            return
        end

        local elasticity
        local callbackName
        local damageName
        local isUnit = false
        if HandleType[widget] == "unit" then
            isUnit = true
            elasticity = sqrt((gizmo.elasticity or 1)*(CAT_Data.WIDGET_TYPE_ELASTICITY[GetUnitTypeId(widget)] or CAT_Data.DEFAULT_UNIT_ELASTICITY))
            callbackName = "onUnitCallback"
            damageName = "onUnitDamage"
        elseif HandleType[widget] == "destructable" then
            elasticity = sqrt((gizmo.elasticity or 1)*(CAT_Data.WIDGET_TYPE_ELASTICITY[GetDestructableTypeId(widget)] or CAT_Data.DEFAULT_DESTRUCTABLE_ELASTICITY))
            callbackName = "onDestructableCallback"
            damageName = "onDestructableDamage"
        else
            elasticity = sqrt((gizmo.elasticity or 1)*(CAT_Data.WIDGET_TYPE_ELASTICITY[GetItemTypeId(widget)] or CAT_Data.DEFAULT_ITEM_ELASTICITY))
            callbackName = "onItemCallback"
            damageName = "onItemDamage"
        end
        local e = (1 + elasticity)

        local Advx = vxa - centerOfMassVx
        local Advy = vya - centerOfMassVy
        local Advz = vza - centerOfMassVz
        local Bdvx = vxb - centerOfMassVx
        local Bdvy = vyb - centerOfMassVy
        local Bdvz = vzb - centerOfMassVz

        --Householder transformation.
        local H11 = 1 - e*nx^2
        local H12 = -e*nx*ny
        local H13 = -e*nx*nz
        local H21 = H12
        local H22 = 1 - e*ny^2
        local H23 = -e*ny*nz
        local H31 = H13
        local H32 = H23
        local H33 = 1 - e*nz^2


        local massRatio = GetMassRatio(massA, massB)

        local xNew, yNew, zNew, recoilX, recoilY, recoilZ

        if massRatio < 1 then
            xNew = xa + 1.001*nx*overlap*(1 - massRatio)
            yNew = ya + 1.001*ny*overlap*(1 - massRatio)
            zNew = za + 1.001*nz*overlap*(1 - massRatio)
            recoilX = H11*Advx + H12*Advy + H13*Advz + centerOfMassVx - vxa
            recoilY = H21*Advx + H22*Advy + H23*Advz + centerOfMassVy - vya
            recoilZ = H31*Advx + H32*Advy + H33*Advz + centerOfMassVz - vza

            GizmoRecoilAndDisplace3D(gizmo, xNew, yNew, zNew, recoilX, recoilY, recoilZ)
        end

        if massRatio > 0 then
            xNew = xb - 1.001*nx*overlap*massRatio
            yNew = yb - 1.001*ny*overlap*massRatio
            zNew = zb - 1.001*nz*overlap*massRatio
            recoilX = H11*Bdvx + H12*Bdvy + H13*Bdvz + centerOfMassVx - vxb
            recoilY = H21*Bdvx + H22*Bdvy + H23*Bdvz + centerOfMassVy - vyb
            recoilZ = H31*Bdvx + H32*Bdvy + H33*Bdvz + centerOfMassVz - vzb

            if isUnit then
                SetUnitX(widget, xNew)
                SetUnitY(widget, yNew)
                CAT_Knockback(widget, recoilX, recoilY, recoilZ)
            end
        end

        if gizmo[damageName] then
            DamageWidget(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed)
        end
        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end
    end

    local function WidgetImpact3D(gizmo, widget)
        local isValidCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        nx, ny, nz,
        collisionX, collisionY, collisionZ, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = WidgetCollisionMath3D(gizmo, widget)

        if massA > 0 then
            local recoilX, recoilY, recoilZ
            local massRatio = GetMassRatio(massA, massB)
            if massRatio > 0 then
                recoilX = dvx*massRatio
                recoilY = dvy*massRatio
                recoilZ = dvz*massRatio
                if HandleType[widget] == "unit" then
                    CAT_Knockback(widget, recoilX, recoilY, recoilZ)
                end
            end
        end

        local callbackName
        local damageName
        if HandleType[widget] == "unit" then
            callbackName = "onUnitCallback"
            damageName = "onUnitDamage"
        elseif HandleType[widget] == "destructable" then
            callbackName = "onDestructableCallback"
            damageName = "onDestructableDamage"
        else
            callbackName = "onItemCallback"
            damageName = "onItemDamage"
        end

        if gizmo[damageName] then
            DamageWidget(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed)
        end
        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        if HandleType[gizmo.visual] == "effect" then
            local r = GetBacktrackRatio(dist, dist + overlap, dx, dy, dz, dvx, dvy, dvz)
            local xBacktracked, yBacktracked, zBacktracked = gizmo.x - r*gizmo.vx*INTERVAL, gizmo.y - r*gizmo.vy*INTERVAL, gizmo.z - r*gizmo.vz*INTERVAL
            BlzSetSpecialEffectPosition(gizmo.visual, xBacktracked, yBacktracked, zBacktracked)
        end
        ALICE_Kill(gizmo)
    end

    local function WidgetDevour3D(gizmo, widget)
        local isValidCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        nx, ny, nz,
        collisionX, collisionY, collisionZ, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = WidgetCollisionMath3D(gizmo, widget)

        if massA > 0 then
            local recoilX, recoilY, recoilZ
            local massRatio = GetMassRatio(massA, massB)
            if massRatio > 0 then
                recoilX = -dvx*(1 - massRatio)
                recoilY = -dvy*(1 - massRatio)
                recoilZ = -dvz*(1 - massRatio)
                GizmoRecoil3D(gizmo, recoilX, recoilY, recoilZ)
            end
        end

        local callbackName
        local damageName
        if HandleType[widget] == "unit" then
            callbackName = "onUnitCallback"
            damageName = "onUnitDamage"
        elseif HandleType[widget] == "destructable" then
            callbackName = "onDestructableCallback"
            damageName = "onDestructableDamage"
        else
            callbackName = "onItemCallback"
            damageName = "onItemDamage"
        end

        if gizmo[damageName] then
            DamageWidget(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed)
        end
        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        ALICE_Kill(widget)
    end

    local function WidgetAnnihilate3D(gizmo, widget)
        local isValidCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        nx, ny, nz,
        collisionX, collisionY, collisionZ, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = WidgetCollisionMath3D(gizmo, widget)

        local callbackName
        if HandleType[widget] == "unit" then
            callbackName = "onUnitCallback"
        elseif HandleType[widget] == "destructable" then
            callbackName = "onDestructableCallback"
        else
            callbackName = "onItemCallback"
        end

        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        if HandleType[gizmo.visual] == "effect" then
            local r = GetBacktrackRatio(dist, dist + overlap, dx, dy, dz, dvx, dvy, dvz)
            local xBacktracked, yBacktracked, zBacktracked = gizmo.x - r*gizmo.vx*INTERVAL, gizmo.y - r*gizmo.vy*INTERVAL, gizmo.z - r*gizmo.vz*INTERVAL
            BlzSetSpecialEffectPosition(gizmo.visual, xBacktracked, yBacktracked, zBacktracked)
        end
        ALICE_Kill(gizmo)
        ALICE_Kill(widget)
    end

    local function WidgetPassThrough3D(gizmo, widget)
        local isValidCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        nx, ny, nz,
        collisionX, collisionY, collisionZ, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = WidgetCollisionMath3D(gizmo, widget)

        local callbackName
        local damageName
        if HandleType[widget] == "unit" then
            callbackName = "onUnitCallback"
            damageName = "onUnitDamage"
        elseif HandleType[widget] == "destructable" then
            callbackName = "onDestructableCallback"
            damageName = "onDestructableDamage"
        else
            callbackName = "onItemCallback"
            damageName = "onItemDamage"
        end

        if gizmo[damageName] then
            DamageWidget(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed)
        end

        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        ALICE_PairDisable()
    end

    local function WidgetMultiPassThrough3D(gizmo, widget)
        local data = ALICE_PairLoadData()
        if data.insideCollisionRange then
            return
        end
        local isValidCollision, xa, ya, za, xb, yb, zb, dist,
        vxa, vya, vza, vxb, vyb, vzb,
        dx, dy, dz, dvx, dvy, dvz,
        nx, ny, nz,
        collisionX, collisionY, collisionZ, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy, centerOfMassVz = WidgetCollisionMath3D(gizmo, widget)

        local callbackName
        local damageName
        if HandleType[widget] == "unit" then
            callbackName = "onUnitCallback"
            damageName = "onUnitDamage"
        elseif HandleType[widget] == "destructable" then
            callbackName = "onDestructableCallback"
            damageName = "onDestructableDamage"
        else
            callbackName = "onItemCallback"
            damageName = "onItemDamage"
        end

        if gizmo[damageName] then
            DamageWidget(gizmo, widget, perpendicularSpeed, parallelSpeed, totalSpeed)
        end

        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, collisionZ, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy, centerOfMassVz)
        end

        data.insideCollisionRange = true
    end

    CAT_UnitBounce3D = WidgetBounce3D
    CAT_UnitImpact3D = WidgetImpact3D
    CAT_UnitDevour3D = WidgetDevour3D
    CAT_UnitAnnihilate3D = WidgetAnnihilate3D
    CAT_UnitPassThrough3D = WidgetPassThrough3D
    CAT_UnitMultiPassThrough3D = WidgetMultiPassThrough3D
    CAT_DestructableBounce3D = WidgetBounce3D
    CAT_DestructableImpact3D = WidgetImpact3D
    CAT_DestructableDevour3D = WidgetDevour3D
    CAT_DestructableAnnihilate3D = WidgetAnnihilate3D
    CAT_DestructablePassThrough3D = WidgetPassThrough3D
    CAT_DestructableMultiPassThrough3D = WidgetMultiPassThrough3D
    CAT_ItemBounce3D = WidgetBounce3D
    CAT_ItemImpact3D = WidgetImpact3D
    CAT_ItemDevour3D = WidgetDevour3D
    CAT_ItemAnnihilate3D = WidgetAnnihilate3D
    CAT_ItemPassThrough3D = WidgetPassThrough3D
    CAT_ItemMultiPassThrough3D = WidgetMultiPassThrough3D

   --===========================================================================================================================================================
    --Gizmo-Unit Collisions
    --==========================================================================================================================================================

    --------------------
    --Collision Checks
    --------------------

    local function InitUnitCollisionCheck3D(gizmo, unit)
        local data = ALICE_PairLoadData()
        local id = GetUnitTypeId(unit)
        local collisionSize = BlzGetUnitCollisionSize(unit)
        data.radius = CAT_Data.WIDGET_TYPE_COLLISION_RADIUS[id] or collisionSize
        data.height = CAT_GetUnitHeight(unit)
        data.collisionRange = data.radius + gizmo.collisionRadius
        data.maxdz = data.height/2 + gizmo.collisionRadius
        gizmo.maxSpeed = gizmo.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED
    end

    ---Required fields:
    -- - collisionRadius
    ---
    ---Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision
    function CAT_UnitCollisionCheck3D(gizmo, unit)
        local data = ALICE_PairLoadData()
        local dx, dy, dz
        if gizmo.x then
            local x, y, z = ALICE_GetCoordinates3D(unit)
            dx, dy, dz = x - gizmo.x, y - gizmo.y, z - gizmo.z
        else
            local xa, ya, za, xb, yb, zb = ALICE_PairGetCoordinates3D()
            dx, dy, dz = xb - xa, yb - ya, zb - za
        end
        local horiDist = sqrt(dx*dx + dy*dy)
        local dist

        if horiDist < data.collisionRange and dz < data.maxdz and dz > -data.maxdz and not (gizmo.friendlyFire == false and ALICE_PairIsFriend()) and (gizmo.onlyTarget == nil or unit == gizmo.target) then
            local dtop = data.height/2 - dz
            local dbottom = data.height/2 + dz
            if dtop < data.radius then
                dist = sqrt(horiDist*horiDist + (dtop - data.radius)^2)
            elseif dbottom < data.radius then
                if GetUnitFlyHeight(unit) > 0 then
                    dist = sqrt(horiDist*horiDist + (dbottom - data.radius)^2)
                else
                    dist = horiDist
                end
            else
                dist = horiDist
            end
            if dist < data.collisionRange then
                local callback = ALICE_FindField(gizmo.onUnitCollision, unit)
                gizmo.hasCollided = true
                if callback then
                    callback(gizmo, unit)
                else
                    if gizmo.onUnitDamage then
                        DamageWidget(gizmo, unit)
                    end
                    ALICE_Kill(gizmo)
                end
            else
                data.insideCollisionRange = false
            end
        else
            dist = sqrt(horiDist*horiDist + dz*dz)
            data.insideCollisionRange = false
        end

        return (horiDist - data.collisionRange)/(gizmo.maxSpeed + UNIT_MAX_SPEED)
    end

   --===========================================================================================================================================================
    --Gizmo-Destructable Collisions
    --==========================================================================================================================================================

    --------------------
    --Collision Checks
    --------------------

    local function InitDestructableCollisionCheck3D(gizmo, destructable)
        local data = ALICE_PairLoadData()
        local id = GetDestructableTypeId(destructable)
        data.radius = CAT_Data.WIDGET_TYPE_COLLISION_RADIUS[id] or CAT_Data.DEFAULT_DESTRUCTABLE_COLLISION_RADIUS
        data.height = CAT_Data.WIDGET_TYPE_HEIGHT[id] or CAT_Data.DEFAULT_DESTRUCTABLE_HEIGHT
        data.collisionRange = data.radius + gizmo.collisionRadius
        data.maxdz = data.height/2 + gizmo.collisionRadius
        gizmo.maxSpeed = gizmo.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED
        data.xDest, data.yDest, data.zDest = ALICE_GetCoordinates3D(destructable)
    end

    ---Required fields:
    -- - collisionRadius
    ---
    ---Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision
    function CAT_DestructableCollisionCheck3D(gizmo, destructable)
        local data = ALICE_PairLoadData()
        local dx, dy, dz
        if gizmo.x  then
            dx, dy, dz = data.xDest - gizmo.x, data.yDest - gizmo.y, data.zDest - gizmo.z
        else
            local x, y, z = ALICE_GetCoordinates3D(gizmo)
            dx, dy, dz = data.xDest - x, data.yDest - y, data.zDest - z
        end
        local horiDist = sqrt(dx*dx + dy*dy)
        local dist

        if horiDist < data.collisionRange and dz < data.maxdz and dz > -data.maxdz then
            local dtop = data.height/2 - dz
            if dtop < data.radius then
                dist = sqrt(horiDist*horiDist + (dtop - data.radius)^2)
            else
                dist = horiDist
            end
            if dist < data.collisionRange then
                local callback = ALICE_FindField(gizmo.onDestructableCollision, destructable)
                gizmo.hasCollided = true
                if callback then
                    callback(gizmo, destructable)
                else
                    if gizmo.onDestructableDamage then
                        DamageWidget(gizmo, destructable)
                    end
                    ALICE_Kill(gizmo)
                end
            else
                data.insideCollisionRange = false
            end
        else
            dist = sqrt(horiDist*horiDist + dz*dz)
            data.insideCollisionRange = false
        end

        if gizmo.isResting then
            ALICE_PairPause()
        end

        return (horiDist - data.collisionRange)/gizmo.maxSpeed
    end

   --===========================================================================================================================================================
    --Gizmo-Item Collisions
    --==========================================================================================================================================================

    --------------------
    --Collision Checks
    --------------------

    local function InitItemCollisionCheck3D(gizmo, item)
        local data = ALICE_PairLoadData()
        local id = GetItemTypeId(item)
        data.radius = CAT_Data.WIDGET_TYPE_COLLISION_RADIUS[id] or CAT_Data.DEFAULT_ITEM_COLLISION_RADIUS
        data.height = CAT_Data.WIDGET_TYPE_HEIGHT[id] or CAT_Data.DEFAULT_ITEM_HEIGHT
        data.collisionRange = data.radius + gizmo.collisionRadius
        data.maxdz = data.height/2 + gizmo.collisionRadius
        gizmo.maxSpeed = gizmo.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED
    end

    ---Required fields:
    -- - collisionRadius
    ---
    ---Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision
    function CAT_ItemCollisionCheck3D(gizmo, item)
        local data = ALICE_PairLoadData()
        local xa, ya, za, xb, yb, zb = ALICE_PairGetCoordinates3D()
        local dx, dy, dz = xb - xa, yb - ya, zb - za
        local horiDist = sqrt(dx*dx + dy*dy)
        local dist

        if horiDist < data.collisionRange and dz < data.maxdz and dz > -data.maxdz then
            local dtop = data.height/2 - dz
            if dtop < data.radius then
                dist = sqrt(horiDist*horiDist + (dtop - data.radius)^2)
            else
                dist = horiDist
            end
            if dist < data.collisionRange then
                local callback = ALICE_FindField(gizmo.onItemCollision, item)
                gizmo.hasCollided = true
                if callback then
                    callback(gizmo, item)
                else
                    if gizmo.onItemDamage then
                        DamageWidget(gizmo, item)
                    end
                    ALICE_Kill(gizmo)
                end
            else
                data.insideCollisionRange = false
            end
        else
            dist = sqrt(horiDist*horiDist + dz*dz)
            data.insideCollisionRange = false
        end

        if gizmo.isResting then
            ALICE_PairPause()
        end

        return (horiDist - data.collisionRange)/gizmo.maxSpeed
    end

   --===========================================================================================================================================================
    --Init
    --==========================================================================================================================================================

    local function InitCollisionsCAT()
        Require "ALICE"
        Require "CAT_Data"
        Require "CAT_Units"
        Require "CAT_Interfaces"
        INTERVAL = ALICE_Config.MIN_INTERVAL

        ALICE_FuncSetInit(CAT_UnitCollisionCheck3D, InitUnitCollisionCheck3D)
        ALICE_FuncSetInit(CAT_DestructableCollisionCheck3D, InitDestructableCollisionCheck3D)
        ALICE_FuncSetInit(CAT_ItemCollisionCheck3D, InitItemCollisionCheck3D)

        ALICE_FuncRequireFields({
            CAT_GizmoCollisionCheck3D,
            CAT_GizmoCylindricalCollisionCheck3D,
            CAT_GizmoCylindricalCollisionCheck3D,
            CAT_UnitCollisionCheck3D,
            CAT_DestructableCollisionCheck3D,
            CAT_ItemCollisionCheck3D
        },
        true, true, "collisionRadius")
        ALICE_FuncRequireFields(CAT_GizmoCylindricalCollisionCheck3D, false, true, "collisionHeight")

        local precomputedHeightMap = Require.optionally "PrecomputedHeightMap"

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

    OnInit.final("CAT_Collisions3D", InitCollisionsCAT)
end
