if Debug then Debug.beginFile "CAT Collisions2D" end
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
                                                                  C O L L I S I O N S   2 D
    =============================================================================================================================================================

    This template contains various functions to detect and execute collisions between gizmos* and any type of object. Terrain collision is not part of this
    template. The functions are accessed by adding them to your gizmo class tables (for an example, see gizmos CAT).

        *Objects represented by a table with coordinate fields .x, .y, .z, velocity fields .vx, .vy, .vz, and a special effect .visual.


    To add collisions, add a collision check function to the ALICE interactions table of your gizmos. Each object type has its own collision check function.
    They are:

    CAT_GizmoCollisionCheck2D
    CAT_UnitCollisionCheck2D
    CAT_DestructableCollisionCheck2D
    CAT_ItemCollisionCheck2D

    Example:

    interactions = {
        unit = CAT_UnitCollisionCheck2D,
        destructable = CAT_DestructableCollisionCheck2D
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
        [{"ball", "soft"}] = CAT_GizmoBounce2D,
        spike = CAT_GizmoImpact2D,
        other = CAT_GizmoPassThrough2D
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

        CAT_GizmoCollisionCheck2D

        Callbacks:

            CAT_GizmoBounce2D                   Reflect the two gizmos.
            CAT_GizmoImpact2D                   Destroy the initiating gizmo and recoil the other.
            CAT_GizmoDevour2D                   Destroy the receiving gizmo and recoil the other.
            CAT_GizmoAnnihilate2D               Destroy both gizmos.
            CAT_GizmoPassThrough2D              Execute the callback function once, but do not destroy or recoil either.
            CAT_GizmoMultiPassThrough2D         Execute the callback function once each time the gizmo and the unit pass through each other.


    Gizmo-Unit Collisions:

        CAT_UnitCollisionCheck2D

        Callbacks:

            CAT_UnitBounce2D                    Reflect the gizmo on the unit and recoil the unit.
            CAT_UnitImpact2D                    Destroy the gizmo and recoil the unit.
            CAT_UnitDevour2D                    Kill the unit and recoil the gizmo.
            CAT_UnitAnnihilate2D                Destroy both the unit and the gizmo.
            CAT_UnitPassThrough2D               Execute the callback function once, but do not destroy or recoil either.
            CAT_UnitMultiPassThrough2D          Execute the callback function once each time the gizmo and the unit pass through each other.


    Gizmo-Destructable Collisions:

        CAT_DestructableCollisionCheck2D

        Callbacks:

            CAT_DestructableBounce2D            Reflect the gizmo on the destructable.
            CAT_DestructableImpact2D            Destroy the gizmo.
            CAT_DestructableDevour2D            Destroy the destructable and recoil the gizmo.
            CAT_DestructableAnnihilate2D        Destroy both the destructable and the gizmo.
            CAT_DestructablePassThrough2D       Execute the callback function once, but do not destroy or recoil either.
            CAT_DestructableMultiPassThrough2D  Execute the callback function once each time the gizmo and the destructable pass through each other.


    Gizmo-Item Collisions:

        CAT_ItemCollisionCheck2D

        Callbacks:

            CAT_ItemBounce2D                    Reflect the gizmo on the item.
            CAT_ItemImpact2D                    Destroy the gizmo.
            CAT_ItemDevour2D                    Destroy the item and recoil the gizmo.
            CAT_ItemAnnihilate2D                Destroy the item and the gizmo.
            CAT_ItemPassThrough2D               Execute the callback function once, but do not destroy or recoil either.
            CAT_ItemMultiPassThrough2D          Execute the callback function once each time the gizmo and the item pass through each other.

    --===========================================================================================================================================================
    ]]

    local INTERVAL                          = nil
    local UNIT_MAX_SPEED                    = 522

    local INF                               = math.huge

    local sqrt                              = math.sqrt
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

    local function GetBacktrackRatio(dist, collisionDist, dx, dy, dvx, dvy)
        if dvx == 0 and dvy == 0 then
            return 0
        end

        local lastStepDist = sqrt((dx - dvx*INTERVAL)^2 + (dy - dvy*INTERVAL)^2)
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
    local function GetGizmoCollisionPoint2D(A, B, ax, ay, bx, by)
        local collisionDist = A.collisionRadius + B.collisionRadius
        local collisionX = (ax*B.collisionRadius + bx*A.collisionRadius)/collisionDist
        local collisionY = (ay*B.collisionRadius + by*A.collisionRadius)/collisionDist

        return collisionX, collisionY, collisionDist
    end

    local function GizmoCollisionMath2D(A, B)
        local xa, ya, xb, yb = ALICE_PairGetCoordinates2D()
        local dx, dy = xa - xb, ya - yb
        local vxa, vya = CAT_GetObjectVelocity2D(A)
        local vxb, vyb = CAT_GetObjectVelocity2D(B)
        local dvx, dvy = vxa - vxb, vya - vyb
        local dist = sqrt(dx*dx + dy*dy)

        local perpendicularSpeed = -(dx*dvx + dy*dvy)/dist

        local totalSpeed = sqrt(dvx*dvx + dvy*dvy)
        local parallelSpeed = sqrt(totalSpeed^2 - perpendicularSpeed^2)

        local massA = CAT_GetObjectMass(A)
        local massB = CAT_GetObjectMass(B)
        local invMassSum = 1/(massA + massB)
        local centerOfMassVx, centerOfMassVy

        if massA == INF then
            if massB == INF then
                centerOfMassVx = (vxa*massA + vxb*massB)*invMassSum
                centerOfMassVy = (vya*massA + vyb*massB)*invMassSum
            else
                centerOfMassVx = vxa
                centerOfMassVy = vya
            end
        elseif massB == INF then
            centerOfMassVx = vxb
            centerOfMassVy = vyb
        elseif massA == 0 and massB == 0 then
            centerOfMassVx = (vxa + vxb)/2
            centerOfMassVy = (vya + vyb)/2
        else
            centerOfMassVx = (vxa*massA + vxb*massB)*invMassSum
            centerOfMassVy = (vya*massA + vyb*massB)*invMassSum
        end

        return perpendicularSpeed >= 0, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy
    end

    local function GizmoRecoilAndDisplace2D(object, x, y, recoilX, recoilY)
        if object.anchor then
            if type(object.anchor) == "table" then
                object.anchor.x,object.anchor.y = x, y
                object.anchor.vx, object.anchor.vy = object.anchor.vx + recoilX, object.anchor.vy + recoilY
            else
                SetUnitX(object.anchor, x)
                SetUnitY(object.anchor, y)
                CAT_Knockback(object.anchor, recoilX, recoilY, 0)
            end
        else
            object.x,object.y = x, y
            object.vx, object.vy = object.vx + recoilX, object.vy + recoilY
        end
    end

    local function GizmoRecoil2D(object, recoilX, recoilY)
        if object.anchor then
            if type(object.anchor) == "table" then
                object.anchor.vx, object.anchor.vy = object.anchor.vx + recoilX, object.anchor.vy + recoilY
            else
                CAT_Knockback(object.anchor, recoilX, recoilY, 0)
            end
        else
            object.vx, object.vy = object.vx + recoilX, object.vy + recoilY
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
    function CAT_GizmoBounce2D(A, B)
        local validCollision, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy = GizmoCollisionMath2D(A, B)

        if not validCollision then
            return
        end

        local elasticity = sqrt((A.elasticity or 1)*(B.elasticity or 1))
        local e = (1 + elasticity)

        local nx, ny = dx/dist, dy/dist

        local Advx = vxa - centerOfMassVx
        local Advy = vya - centerOfMassVy
        local Bdvx = vxb - centerOfMassVx
        local Bdvy = vyb - centerOfMassVy

        --Householder transformation.
        local H11 = 1 - e*nx^2
        local H12 = -e*nx*ny
        local H21 = H12
        local H22 = 1 - e*ny^2

        local collisionX, collisionY, collisionDist = GetGizmoCollisionPoint2D(A, B, xa, ya, xb, yb)
        local massRatio = GetMassRatio(massA, massB)

        local xNew, yNew, recoilX, recoilY
        local displacement = collisionDist - dist
        if massRatio < 1 then
            xNew = xa + 1.001*dx/dist*displacement*(1 - massRatio)
            yNew = ya + 1.001*dy/dist*displacement*(1 - massRatio)

            recoilX = H11*Advx + H12*Advy + centerOfMassVx - vxa
            recoilY = H21*Advx + H22*Advy + centerOfMassVy - vya

            GizmoRecoilAndDisplace2D(A, xNew, yNew, recoilX, recoilY)
        else
            A.vx, A.vy = 0, 0
        end

        if massRatio > 0 then
            xNew = xb - 1.001*dx/dist*displacement*massRatio
            yNew = yb - 1.001*dy/dist*displacement*massRatio

            recoilX = H11*Bdvx + H12*Bdvy + centerOfMassVx - vxb
            recoilY = H21*Bdvx + H22*Bdvy + centerOfMassVy - vyb

            GizmoRecoilAndDisplace2D(B, xNew, yNew, recoilX, recoilY)
        else
            B.vx, B.vy = 0, 0
        end

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            callback(A, B, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end
    end

    ---Optional fields:
    -- - mass
    -- - onGizmoCallback
    function CAT_GizmoImpact2D(A, B)
        local validCollision, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy = GizmoCollisionMath2D(A, B)

        local collisionX, collisionY, collisionDist = GetGizmoCollisionPoint2D(A, B, xa, ya, xb, yb)

        if massA > 0 then
            local unmoved
            --Avoid unpausing resting gizmo with only minor bounce.
            if B.isResting and perpendicularSpeed/2*A.mass/B.mass < B.friction*CAT_Data.STATIC_FRICTION_FACTOR*INTERVAL or (massB == INF and massA == INF) then
                unmoved = true
            end
            if not unmoved then
                local recoilX, recoilY
                local massRatio = GetMassRatio(massA, massB)
                if massRatio > 0 then
                    recoilX = dvx*massRatio
                    recoilY = dvy*massRatio
                    GizmoRecoil2D(B, recoilX, recoilY)
                end
            end
        end

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            callback(A, B, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        if HandleType[A.visual] == "effect" then
            local r = GetBacktrackRatio(dist, collisionDist, dx, dy, dvx, dvy)
            local xBacktracked, yBacktracked = A.x - r*A.vx*INTERVAL, A.y - r*A.vy*INTERVAL
            BlzSetSpecialEffectPosition(A.visual, xBacktracked, yBacktracked, A.z or GetTerrainZ(xBacktracked, yBacktracked))
        end
        ALICE_Kill(A)
    end

    ---Optional fields:
    -- - mass
    -- - onGizmoCallback
    function CAT_GizmoDevour2D(A, B)
        local validCollision, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy = GizmoCollisionMath2D(A, B)

        local collisionX, collisionY, collisionDist = GetGizmoCollisionPoint2D(A, B, xa, ya, xb, yb)

        if massA > 0 then
            local unmoved
            --Avoid unpausing resting gizmo with only minor bounce.
            if A.isResting and perpendicularSpeed/2*B.mass/A.mass < A.friction*CAT_Data.STATIC_FRICTION_FACTOR*INTERVAL or (massA == INF and massB == INF) then
                unmoved = true
            end
            if not unmoved then
                local recoilX, recoilY
                local massRatio = GetMassRatio(massA, massB)
                if massRatio > 0 then
                    recoilX = -dvx*(1 - massRatio)
                    recoilY = -dvy*(1 - massRatio)
                    GizmoRecoil2D(A, recoilX, recoilY)
                end
            end
        end

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            callback(A, B, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        if HandleType[B.visual] == "effect" then
            local r = GetBacktrackRatio(dist, collisionDist, dx, dy, dvx, dvy)
            local xBacktracked, yBacktracked = B.x - r*B.vx*INTERVAL, B.y - r*B.vy*INTERVAL
            BlzSetSpecialEffectPosition(A.visual, xBacktracked, yBacktracked, B.z or GetTerrainZ(xBacktracked, yBacktracked))
        end
        ALICE_Kill(B)
    end

    ---Optional fields:
    -- - onGizmoCallback
    function CAT_GizmoAnnihilate2D(A, B)
        local validCollision, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy = GizmoCollisionMath2D(A, B)

        local collisionX, collisionY, collisionDist = GetGizmoCollisionPoint2D(A, B, xa, ya, xb, yb)

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            callback(A, B, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        local r = GetBacktrackRatio(dist, collisionDist, dx, dy, dvx, dvy)
        local xBacktracked, yBacktracked
        if HandleType[A.visual] == "effect" then
            xBacktracked, yBacktracked = A.x - r*A.vx*INTERVAL, A.y - r*A.vy*INTERVAL
            BlzSetSpecialEffectPosition(A.visual, xBacktracked, yBacktracked, A.z or GetTerrainZ(xBacktracked, yBacktracked))
        end
        ALICE_Kill(A)
        if HandleType[B.visual] == "effect" then
            xBacktracked, yBacktracked = B.x - r*B.vx*INTERVAL, B.y - r*B.vy*INTERVAL
            BlzSetSpecialEffectPosition(A.visual, xBacktracked, yBacktracked, B.z or GetTerrainZ(xBacktracked, yBacktracked))
        end
        ALICE_Kill(B)
    end

    ---Required fields:
    -- - onGizmoCallback
    function CAT_GizmoPassThrough2D(A, B)
        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            local validCollision, xa, ya, xb, yb, dist,
            vxa, vya, vxb, vyb,
            dx, dy, dvx, dvy,
            massA, massB,
            perpendicularSpeed, totalSpeed, parallelSpeed,
            centerOfMassVx, centerOfMassVy = GizmoCollisionMath2D(A, B)

            local collisionX, collisionY, collisionDist = GetGizmoCollisionPoint2D(A, B, xa, ya, xb, yb)
            callback(A, B, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        ALICE_PairDisable()
    end

    ---Required fields:
    -- - onGizmoCallback
    function CAT_GizmoMultiPassThrough2D(A, B)
        local data = ALICE_PairLoadData()
        if data.insideCollisionRange then
            return
        end

        local callback = ALICE_FindField(A.onGizmoCallback, B)
        if callback then
            local validCollision, xa, ya, xb, yb, dist,
            vxa, vya, vxb, vyb,
            dx, dy, dvx, dvy,
            massA, massB,
            perpendicularSpeed, totalSpeed, parallelSpeed,
            centerOfMassVx, centerOfMassVy = GizmoCollisionMath2D(A, B)

            local collisionX, collisionY, collisionDist = GetGizmoCollisionPoint2D(A, B, xa, ya, xb, yb)
            callback(A, B, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        data.insideCollisionRange = true
    end

    --------------------
    --Collision Checks
    --------------------

    ---Required fields:
    -- - collisionRadius
    ---
    -- - Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision (male)
    function CAT_GizmoCollisionCheck2D(A, B)
        local dx, dy, dist
        if A.anchor or B.anchor then
            dist = ALICE_PairGetDistance2D()
        else
            dx = A.x - B.x
            dy = A.y - B.y
            dist = sqrt(dx*dx + dy*dy)
        end

        local collisionRange = A.collisionRadius + B.collisionRadius

        if dist < collisionRange and not (A.friendlyFire == false and ALICE_PairIsFriend()) then
            local callback = ALICE_FindField(A.onGizmoCollision, B)
            if callback then
                callback(A, B)
            end
            A.hasCollided = true
            B.hasCollided = true
        end

        if A.isResting and B.isResting then
            ALICE_PairPause()
        end

        return (dist - collisionRange)/((A.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED) + (B.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED))
    end

   --===========================================================================================================================================================
    --Gizmo-Widget Collisions
    --==========================================================================================================================================================

    local function WidgetCollisionMath2D(gizmo, widget)
        local data = ALICE_PairLoadData()
        local xa, ya, xb, yb = ALICE_PairGetCoordinates2D()
        local dx, dy = xa - xb, ya - yb
        local vxa, vya = CAT_GetObjectVelocity2D(gizmo)
        local vxb, vyb = CAT_GetObjectVelocity2D(widget)
        local dvx, dvy = vxa - vxb, vya - vyb
        local dist = sqrt(dx*dx + dy*dy)

        local nx, ny = dx/dist, dy/dist
        local collisionX, collisionY
        local overlap = data.radius + gizmo.collisionRadius - dist

        local perpendicularSpeed = -(nx*dvx + ny*dvy)

        collisionX = xb + nx*data.radius
        collisionY = yb + ny*data.radius

        local totalSpeed = sqrt(dvx*dvx + dvy*dvy)
        local parallelSpeed = sqrt(totalSpeed^2 - perpendicularSpeed^2)

        local massA = CAT_GetObjectMass(gizmo)
        local massB = CAT_GetObjectMass(widget)
        local massSum = massA + massB
        local centerOfMassVx, centerOfMassVy

        if massA == INF then
            if massB == INF then
                centerOfMassVx = (vxa*massA + vxb*massB)/massSum
                centerOfMassVy = (vya*massA + vyb*massB)/massSum
            else
                centerOfMassVx = vxa
                centerOfMassVy = vya
            end
        elseif massB == INF then
            centerOfMassVx = vxb
            centerOfMassVy = vyb
        else
            centerOfMassVx = (vxa*massA + vxb*massB)/massSum
            centerOfMassVy = (vya*massA + vyb*massB)/massSum
        end

        return perpendicularSpeed >= 0, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        nx, ny,
        collisionX, collisionY, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy
    end

    -------------
    --Callbacks
    -------------

    local function WidgetBounce2D(gizmo, widget)

        local isValidCollision, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        nx, ny,
        collisionX, collisionY, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy = WidgetCollisionMath2D(gizmo, widget)

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
        local Bdvx = vxb - centerOfMassVx
        local Bdvy = vyb - centerOfMassVy

        --Householder transformation.
        local H11 = 1 - e*nx^2
        local H12 = -e*nx*ny
        local H21 = H12
        local H22 = 1 - e*ny^2

        local massRatio = GetMassRatio(massA, massB)

        local xNew, yNew, recoilX, recoilY

        if massRatio < 1 then
            xNew = xa + 1.001*nx*overlap*(1 - massRatio)
            yNew = ya + 1.001*ny*overlap*(1 - massRatio)
            recoilX = H11*Advx + H12*Advy + centerOfMassVx - vxa
            recoilY = H21*Advx + H22*Advy + centerOfMassVy - vya

            GizmoRecoilAndDisplace2D(gizmo, xNew, yNew, recoilX, recoilY)
        end

        if massRatio > 0 then
            xNew = xb - 1.001*nx*overlap*massRatio
            yNew = yb - 1.001*ny*overlap*massRatio
            recoilX = H11*Bdvx + H12*Bdvy + centerOfMassVx - vxb
            recoilY = H21*Bdvx + H22*Bdvy + centerOfMassVy - vyb

            if isUnit then
                SetUnitX(widget, xNew)
                SetUnitY(widget, yNew)
                CAT_Knockback(widget, recoilX, recoilY, 0)
            end
        end

        if gizmo[damageName] then
            DamageWidget(gizmo, widget)
        end
        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end
    end

    local function WidgetImpact2D(gizmo, widget)
        local isValidCollision, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        nx, ny,
        collisionX, collisionY, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy = WidgetCollisionMath2D(gizmo, widget)

        if massA > 0 then
            local recoilX, recoilY
            local massRatio = GetMassRatio(massA, massB)
            if massRatio > 0 then
                recoilX = dvx*massRatio
                recoilY = dvy*massRatio
                if HandleType[widget] == "unit" then
                    CAT_Knockback(widget, recoilX, recoilY, 0)
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
            DamageWidget(gizmo, widget)
        end
        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        if HandleType[gizmo.visual] == "effect" then
            local r = GetBacktrackRatio(dist, dist + overlap, dx, dy, dvx, dvy)
            local xBacktracked, yBacktracked = gizmo.x - r*gizmo.vx*INTERVAL, gizmo.y - r*gizmo.vy*INTERVAL
            BlzSetSpecialEffectPosition(gizmo.visual, xBacktracked, yBacktracked, gizmo.z or GetTerrainZ(xBacktracked, yBacktracked))
        end
        ALICE_Kill(gizmo)
    end

    local function WidgetDevour2D(gizmo, widget)
        local isValidCollision, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        nx, ny,
        collisionX, collisionY, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy = WidgetCollisionMath2D(gizmo, widget)

        if massA > 0 then
            local recoilX, recoilY, recoilZ
            local massRatio = GetMassRatio(massA, massB)
            if massRatio > 0 then
                recoilX = -dvx*(1 - massRatio)
                recoilY = -dvy*(1 - massRatio)
                GizmoRecoil2D(gizmo, recoilX, recoilY)
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
            DamageWidget(gizmo, widget)
        end
        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            callback(gizmo, widget, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        ALICE_Kill(widget)
    end

    local function WidgetAnnihilate2D(gizmo, widget)
        local isValidCollision, xa, ya, xb, yb, dist,
        vxa, vya, vxb, vyb,
        dx, dy, dvx, dvy,
        nx, ny,
        collisionX, collisionY, overlap,
        massA, massB,
        perpendicularSpeed, totalSpeed, parallelSpeed,
        centerOfMassVx, centerOfMassVy = WidgetCollisionMath2D(gizmo, widget)

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
            callback(gizmo, widget, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        if HandleType[gizmo.visual] == "effect" then
            local r = GetBacktrackRatio(dist, dist + overlap, dx, dy, dvx, dvy)
            local xBacktracked, yBacktracked = gizmo.x - r*gizmo.vx*INTERVAL, gizmo.y - r*gizmo.vy*INTERVAL
            BlzSetSpecialEffectPosition(gizmo.visual, xBacktracked, yBacktracked, gizmo.z or GetTerrainZ(xBacktracked, yBacktracked))
        end
        ALICE_Kill(gizmo)
        ALICE_Kill(widget)
    end

    local function WidgetPassThrough2D(gizmo, widget)
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
            DamageWidget(gizmo, widget)
        end

        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            local isValidCollision, xa, ya, xb, yb, dist,
            vxa, vya, vxb, vyb,
            dx, dy, dvx, dvy,
            nx, ny,
            collisionX, collisionY, overlap,
            massA, massB,
            perpendicularSpeed, totalSpeed, parallelSpeed,
            centerOfMassVx, centerOfMassVy = WidgetCollisionMath2D(gizmo, widget)

            callback(gizmo, widget, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        ALICE_PairDisable()
    end

    local function WidgetMultiPassThrough2D(gizmo, widget)
        local data = ALICE_PairLoadData()
        if data.insideCollisionRange then
            return
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
            DamageWidget(gizmo, widget)
        end

        local callback = ALICE_FindField(gizmo[callbackName], widget)
        if callback then
            local isValidCollision, xa, ya, xb, yb, dist,
            vxa, vya, vxb, vyb,
            dx, dy, dvx, dvy,
            nx, ny,
            collisionX, collisionY, overlap,
            massA, massB,
            perpendicularSpeed, totalSpeed, parallelSpeed,
            centerOfMassVx, centerOfMassVy = WidgetCollisionMath2D(gizmo, widget)

            callback(gizmo, widget, collisionX, collisionY, perpendicularSpeed, parallelSpeed, totalSpeed, centerOfMassVx, centerOfMassVy)
        end

        data.insideCollisionRange = true
    end

    CAT_UnitBounce2D = WidgetBounce2D
    CAT_UnitImpact2D = WidgetImpact2D
    CAT_UnitDevour2D = WidgetDevour2D
    CAT_UnitAnnihilate2D = WidgetAnnihilate2D
    CAT_UnitPassThrough2D = WidgetPassThrough2D
    CAT_UnitMultiPassThrough2D = WidgetMultiPassThrough2D
    CAT_DestructableBounce2D = WidgetBounce2D
    CAT_DestructableImpact2D = WidgetImpact2D
    CAT_DestructableDevour2D = WidgetDevour2D
    CAT_DestructableAnnihilate2D = WidgetAnnihilate2D
    CAT_DestructablePassThrough2D = WidgetPassThrough2D
    CAT_DestructableMultiPassThrough2D = WidgetMultiPassThrough2D
    CAT_ItemBounce2D = WidgetBounce2D
    CAT_ItemImpact2D = WidgetImpact2D
    CAT_ItemDevour2D = WidgetDevour2D
    CAT_ItemAnnihilate2D = WidgetAnnihilate2D
    CAT_ItemPassThrough2D = WidgetPassThrough2D
    CAT_ItemMultiPassThrough2D = WidgetMultiPassThrough2D

   --===========================================================================================================================================================
    --Gizmo-Unit Collisions
    --==========================================================================================================================================================

    --------------------
    --Collision Checks
    --------------------

    local function InitUnitCollisionCheck2D(gizmo, unit)
        local data = ALICE_PairLoadData()
        local id = GetUnitTypeId(unit)
        local collisionSize = BlzGetUnitCollisionSize(unit)
        data.radius = CAT_Data.WIDGET_TYPE_COLLISION_RADIUS[id] or collisionSize
        data.collisionRange = data.radius + gizmo.collisionRadius
        gizmo.maxSpeed = gizmo.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED
    end

    ---Required fields:
    -- - collisionRadius
    ---
    ---Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision
    function CAT_UnitCollisionCheck2D(gizmo, unit)
        local data = ALICE_PairLoadData()
        local dist = ALICE_PairGetDistance2D()

        if dist < data.collisionRange and not (gizmo.friendlyFire == false and ALICE_PairIsFriend()) and (gizmo.onlyTarget == nil or unit == gizmo.target) then
            local callback = ALICE_FindField(gizmo.onUnitCollision, unit)
            gizmo.hasCollided = true
            if callback then
                callback(gizmo, unit)
            else
                ALICE_Kill(gizmo)
            end
        else
            data.insideCollisionRange = false
        end

        return (dist - data.collisionRange)/(gizmo.maxSpeed + UNIT_MAX_SPEED)
    end

   --===========================================================================================================================================================
    --Gizmo-Destructable Collisions
    --==========================================================================================================================================================

    --------------------
    --Collision Checks
    --------------------

    local function InitDestructableCollisionCheck2D(gizmo, destructable)
        local data = ALICE_PairLoadData()
        local id = GetDestructableTypeId(destructable)
        data.radius = CAT_Data.WIDGET_TYPE_COLLISION_RADIUS[id] or CAT_Data.DEFAULT_DESTRUCTABLE_COLLISION_RADIUS
        data.collisionRange = data.radius + gizmo.collisionRadius
        gizmo.maxSpeed = gizmo.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED
    end

    ---Required fields:
    -- - collisionRadius
    ---
    ---Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision
    function CAT_DestructableCollisionCheck2D(gizmo, destructable)
        local data = ALICE_PairLoadData()
        local dist = ALICE_PairGetDistance2D()

        if dist < data.collisionRange then
            local callback = ALICE_FindField(gizmo.onDestructableCollision, destructable)
            gizmo.hasCollided = true
            if callback then
                callback(gizmo, destructable)
            else
                ALICE_Kill(gizmo)
            end
        else
            data.insideCollisionRange = false
        end

        if gizmo.isResting then
            ALICE_PairPause()
        end

        return (dist - data.collisionRange)/gizmo.maxSpeed
    end

   --===========================================================================================================================================================
    --Gizmo-Item Collisions
    --==========================================================================================================================================================

    --------------------
    --Collision Checks
    --------------------

    local function InitItemCollisionCheck2D(gizmo, item)
        local data = ALICE_PairLoadData()
        local id = GetItemTypeId(item)
        data.collisionRange = (CAT_Data.WIDGET_TYPE_COLLISION_RADIUS[id] or CAT_Data.DEFAULT_ITEM_COLLISION_RADIUS) + gizmo.collisionRadius
        gizmo.maxSpeed = gizmo.maxSpeed or CAT_Data.DEFAULT_GIZMO_MAX_SPEED
    end

    ---Required fields:
    -- - collisionRadius
    ---
    -- - Optional fields:
    -- - maxSpeed
    -- - onGizmoCollision
    function CAT_ItemCollisionCheck2D(gizmo, item)
        local data = ALICE_PairLoadData()
        local dist = ALICE_PairGetDistance2D()

        if dist < data.collisionRange then
            local callback = ALICE_FindField(gizmo.onItemCollision, item)
            gizmo.hasCollided = true
            if callback then
                callback(gizmo, item)
            else
                ALICE_Kill(gizmo)
            end
        else
            data.insideCollisionRange = false
        end

        if gizmo.isResting then
            ALICE_PairPause()
        end

        return (dist - data.collisionRange)/gizmo.maxSpeed
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

        ALICE_FuncSetInit(CAT_UnitCollisionCheck2D, InitUnitCollisionCheck2D)
        ALICE_FuncSetInit(CAT_DestructableCollisionCheck2D, InitDestructableCollisionCheck2D)
        ALICE_FuncSetInit(CAT_ItemCollisionCheck2D, InitItemCollisionCheck2D)

        ALICE_FuncRequireFields({
            CAT_GizmoCollisionCheck2D,
            CAT_UnitCollisionCheck2D,
            CAT_DestructableCollisionCheck2D,
            CAT_ItemCollisionCheck2D,
        },
        true, true, "collisionRadius")

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

    OnInit.final("CAT_Collisions", InitCollisionsCAT)
end
