do
    CAT_Data = {
        -------------------------------------------------------------------------------------------------------------------------------------------------------------
        --Sizes

        --Shifts the coordinates returned by ALICE up by half a widget's height so that it represents the center, not the origin. The Collisions CAT is expecting
        --center-point coordinates.
        CENTER_POINT_COORDINATES                = true      ---@constant boolean

        --By default, a unit's height is this factor times its collision size.
        ,DEFAULT_UNIT_HEIGHT_FACTOR             = 4.0       ---@constant number

        ,DEFAULT_DESTRUCTABLE_COLLISION_RADIUS  = 64        ---@constant number
        ,DEFAULT_DESTRUCTABLE_HEIGHT            = 250       ---@constant number

        ,DEFAULT_ITEM_COLLISION_RADIUS          = 40        ---@constant number
        ,DEFAULT_ITEM_HEIGHT                    = 40        ---@constant number

        --These tables allow you to overwrite the default values for specific widget types. Keys of these tables are fourCC codes.
        ,WIDGET_TYPE_COLLISION_RADIUS           = {}        ---@type table<string,number>
        ,WIDGET_TYPE_HEIGHT                     = {}        ---@type table<string,number>

        -------------------------------------------------------------------------------------------------------------------------------------------------------------
        --Physics

        ,DEFAULT_UNIT_ELASTICITY                = 0.5       ---@constant number
        ,DEFAULT_UNIT_MASS                      = 5         ---@constant number
        ,DEFAULT_UNIT_FRICTION                  = 600       ---@constant number
        ,DEFAULT_DESTRUCTABLE_ELASTICITY        = 0.2       ---@constant number

        ,DEFAULT_ITEM_ELASTICITY                = 0.2       ---@constant number

        --These tables allow you to overwrite the default values for specific widget types. Keys of these tables are fourCC codes.
        ,UNIT_TYPE_MASS                         = {}        ---@type table<string,number>
        ,UNIT_TYPE_FRICTION                     = {}        ---@type table<string,number>
        ,WIDGET_TYPE_ELASTICITY                 = {}        ---@type table<string,number>

        --Periodically check each unit's position so that the unit's velocity can be retrieved for collisions.
        ,MONITOR_UNIT_VELOCITY                  = true      ---@constant boolean

        -------------------------------------------------------------------------------------------------------------------------------------------------------------
        --For Gizmos

        --The maximum speed that a gizmo can reasonably achieve to determine the frequency with which collision checks must be performed. Can be overwritten with the
        --.maxSpeed field in a gizmo's class table.
        ,DEFAULT_GIZMO_MAX_SPEED                = 2000      ---@constant number

        --Sets the vertical bounds for the kill trigger in CAT_OutOfBoundsCheck.
        ,GIZMO_MAXIMUM_Z                        = 3000      ---@constant number
        ,GIZMO_MINIMUM_Z                        = -2000     ---@constant number

        -------------------------------------------------------------------------------------------------------------------------------------------------------------
        --For Ballistics

        --The friction increase for a sliding object when it comes to rest. High value can prevent jittering in tightly packed collisions.
        ,STATIC_FRICTION_FACTOR                 = 5         ---@constant number

        --If an airborne object would bounce off the surface with this much or less speed, it will become ground-bound instead.
        ,MINIMUM_BOUNCE_VELOCITY                = 5         ---@constant number

        --Strength of gravitational acceleration.
        ,GRAVITY                                = 800       ---@constant number

        --Determines how curved a surface must be before an object can no longer slide across it but is instead reflected as though it hit a wall. Higher value is
        --less forgiving.
        ,MAX_SLIDING_CURVATURE_RADIUS           = 80        ---@constant number

        -------------------------------------------------------------------------------------------------------------------------------------------------------------
        --Terrain Properties

        --You can adjust the friction of different terrain types by editing the TERRAIN_TYPE_FRICTION table. Disable if not needed to improve performance.
        ,DIFFERENT_SURFACE_FRICTIONS            = false     ---@constant boolean
        ,TERRAIN_TYPE_FRICTION                  = {}        ---@type table<string,number>
        ,TERRAIN_TYPE_ELASTICITY                = {}        ---@type table<string,number>
    }

    OnInit.root("CAT_Data", function()
        for __, table in pairs(CAT_Data) do
            if type(table) == "table" then
                for key, value in pairs(table) do
                    if type(key) == "string" then
                        table[FourCC(key)] = value
                    end
                end
            end
        end

        if CAT_Data.CENTER_POINT_COORDINATES then
            ALICE_OnCreationAddFlag("unit", "zOffset", function(host)
                return (CAT_Data.WIDGET_TYPE_HEIGHT[GetUnitTypeId(host)] or CAT_Data.DEFAULT_UNIT_HEIGHT_FACTOR*BlzGetUnitCollisionSize(host))/2
            end)
            ALICE_OnCreationAddFlag("destructable", "zOffset", function(host)
                return (CAT_Data.WIDGET_TYPE_HEIGHT[GetDestructableTypeId(host)] or CAT_Data.DEFAULT_DESTRUCTABLE_HEIGHT)/2
            end)
            ALICE_OnCreationAddFlag("item", "zOffset", function(host)
                return (CAT_Data.WIDGET_TYPE_HEIGHT[GetItemTypeId(host)] or CAT_Data.DEFAULT_DESTRUCTABLE_HEIGHT)/2
            end)
        end
    end)
end
