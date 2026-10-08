OnInit.global("WorldDestructables", function(Require)
    Require('Geometry')

    local valid_trees = {
        ['ITtw'] = true, ['JTtw'] = true, ['FTtw'] = true, ['NTtw'] = true,
        ['B00B'] = true, ['B00H'] = true, ['ITtc'] = true, ['NTtc'] = true,
        ['WTst'] = true, ['WTtw'] = true,
        x = 0., y = 0., range = 0.,
    }

    function EnumDestroyTreesInRange()
        local destructable = GetEnumDestructable()
        local id = string.pack(">I4", GetDestructableTypeId(destructable))
        if valid_trees[id] and DistanceCoords(valid_trees.x, valid_trees.y,
            GetDestructableX(destructable), GetDestructableY(destructable)) <= valid_trees.range then
            KillDestructable(destructable)
        end
    end

    ---@type fun(x: number, y: number, range: number)
    function DestroyTreesInRange(x, y, range)
        local rect = Rect(x - range, y - range, x + range, y + range)
        valid_trees.x = x
        valid_trees.y = y
        valid_trees.range = range
        EnumDestructablesInRect(rect, nil, EnumDestroyTreesInRange)
        RemoveRect(rect)
    end
end)
