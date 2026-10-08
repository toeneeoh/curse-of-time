-- Shared, lightweight location predicates for player services and protected
-- world-space behavior. Content modules should depend on this instead of the
-- full Town or Regions initializers when they only need an area query.

OnInit.final("WorldAreas", function()
    Town = {}

    ---@param unit unit?
    ---@return boolean
    function Town.isUnitInTown(unit)
        return unit ~= nil and RectContainsUnit(gg_rct_Town_Main, unit)
    end

    ---@param pid integer
    ---@return boolean
    function Town.isPlayerInTown(pid)
        return Town.isUnitInTown(Hero[pid])
    end

    ---Town, church, and tavern all permit non-combat character services such
    ---as repicking and summon respecialization.
    ---@param unit unit?
    ---@return boolean
    function Town.isUnitInServiceArea(unit)
        return unit ~= nil and
                   (RectContainsUnit(gg_rct_Town_Main, unit) or
                       RectContainsUnit(gg_rct_Church, unit) or
                       RectContainsUnit(gg_rct_Tavern, unit))
    end

    ---@param pid integer
    ---@return boolean
    function Town.isPlayerInServiceArea(pid)
        return Town.isUnitInServiceArea(Hero[pid])
    end

    ---@param x number
    ---@param y number
    ---@return boolean
    function Town.containsCoords(x, y)
        return RectContainsCoords(gg_rct_Town_Main, x, y)
    end

    PROTECTED_AREAS = {
        gg_rct_Town_Main,
    }

    ---Returns the protected area containing the coordinates, if any.
    ---@param x number
    ---@param y number
    ---@return rect?
    function GetProtectedAreaFromCoords(x, y)
        for index = 1, #PROTECTED_AREAS do
            local area = PROTECTED_AREAS[index]
            if RectContainsCoords(area, x, y) then return area end
        end
        return nil
    end

    ---@param x number
    ---@param y number
    ---@return boolean
    function IsProtectedArea(x, y)
        return GetProtectedAreaFromCoords(x, y) ~= nil
    end
end, Debug and Debug.getLine())
