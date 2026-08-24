do
    --[[
    =============================================================================================================================================================
                                                                Complementary ALICE Template

                                    ALICE                       https://www.hiveworkshop.com/threads/a-l-i-c-e-interaction-engine.353126/
                                    TotalInitialization         https://www.hiveworkshop.com/threads/total-initialization.317099/
                                    Units CAT
                                    Data CAT

    =============================================================================================================================================================
                                                                    I N T E R F A C E S
    =============================================================================================================================================================

    This snippet contains interfaces for gizmos and widgets.

    =============================================================================================================================================================
                                                            L I S T   O F   F U N C T I O N S
    =============================================================================================================================================================

    CAT_GetObjectVelocity2D(whichObject)                Returns the x, y-velocity of the specified object. Accepts widgets and gizmos.
    CAT_GetObjectVelocity3D(whichObject)                Returns the x, y, and z-velocity of the specified object. Accepts widgets and gizmos.
    CAT_GetObjectMass(whichObject)                      Returns the mass of the specified object. Accepts widgets and gizmos.

    =============================================================================================================================================================
    ]]

    local INF                               = math.huge

    ---Returns the mass of the specified object.
    ---@param object unit | destructable | item | table
    ---@return number
    function CAT_GetObjectMass(object)
        if type(object) == "table" then
            if object.mass then
                return object.mass
            elseif object.anchor then
                if type(object.anchor) == "table" then
                    return object.anchor.mass
                elseif HandleType[object.anchor] == "unit" then
                    return CAT_Data.UNIT_TYPE_MASS[GetUnitTypeId(object.anchor)] or CAT_Data.DEFAULT_UNIT_MASS
                else
                    return INF
                end
            else
                return 0
            end
        elseif HandleType[object] == "unit" then
            return CAT_Data.UNIT_TYPE_MASS[GetUnitTypeId(object)] or CAT_Data.DEFAULT_UNIT_MASS
        else
            return INF
        end
    end

    ---Returns the x, y, and z-velocity of the specified object.
    ---@param object unit | destructable | item | table
    ---@return number, number, number
    function CAT_GetObjectVelocity3D(object)
        if type(object) == "table" then
            if object.vx then
                return object.vx, object.vy, object.vz
            elseif object.anchor then
                if type(object.anchor) == "table" then
                    return object.anchor.vx, object.anchor.vy, object.anchor.vz
                elseif HandleType[object.anchor] == "unit" then
                    return CAT_GetUnitVelocity3D(object.anchor)
                else
                    return 0, 0, 0
                end
            else
                return 0, 0, 0
            end
        else
            if HandleType[object] == "unit" then
                return CAT_GetUnitVelocity3D(object)
            else
                return 0, 0, 0
            end
        end
    end

    ---Returns the x- and y-velocity of the specified object.
    ---@param object unit | destructable | item | table
    ---@return number, number
    function CAT_GetObjectVelocity2D(object)
        if type(object) == "table" then
            if object.vx then
                return object.vx, object.vy
            elseif object.anchor then
                if type(object.anchor) == "table" then
                    return object.anchor.vx, object.anchor.vy
                elseif HandleType[object.anchor] == "unit" then
                    return CAT_GetUnitVelocity2D(object.anchor)
                else
                    return 0, 0
                end
            else
                return 0, 0
            end
        else
            if HandleType[object] == "unit" then
                return CAT_GetUnitVelocity2D(object)
            else
                return 0, 0
            end
        end
    end

    OnInit.root("CAT_Interfaces", DoNothing)
end
