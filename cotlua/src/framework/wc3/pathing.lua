--[[
    pathing.lua

    This module provides utilities for determining what kind of
    pathing an (x, y) coordinate on the map has.
]]

OnInit.global("Pathing", function()

    PATH_ITEM = CreateItem(FourCC('wolg'), 30000., 30000.)
    SetItemVisible(PATH_ITEM, false)
    TERRAIN_X = 0.
    TERRAIN_Y = 0.

    local MAX_RANGE     = 100.
    local Find          = Rect(0., 0., 128., 128.)
    local HiddenItems   = {}

---@type fun(x: number, y: number):boolean
function IsTerrainDeepWater(x, y)
    return not IsTerrainPathable(x, y, PATHING_TYPE_FLOATABILITY) and IsTerrainPathable(x, y, PATHING_TYPE_WALKABILITY)
end

---@type fun(x: number, y: number):boolean
function IsTerrainShallowWater(x, y)
    return not IsTerrainPathable(x, y, PATHING_TYPE_FLOATABILITY) and not IsTerrainPathable(x, y, PATHING_TYPE_WALKABILITY) and IsTerrainPathable(x, y, PATHING_TYPE_BUILDABILITY)
end

---@type fun(x: number, y: number):boolean
function IsTerrainLand(x, y)
    return IsTerrainPathable(x, y, PATHING_TYPE_FLOATABILITY)
end

---@type fun(x: number, y: number):boolean
function IsTerrainPlatform(x, y)
    return not IsTerrainPathable(x, y, PATHING_TYPE_FLOATABILITY) and not IsTerrainPathable(x, y, PATHING_TYPE_WALKABILITY) and not IsTerrainPathable(x, y, PATHING_TYPE_BUILDABILITY)
end

local function HideItems()
    local itm = GetEnumItem()

    if IsItemVisible(itm) then
        SetItemVisible(itm, false)
        HiddenItems[#HiddenItems + 1] = itm
    end
end

---@type fun(x: number, y: number):boolean
function IsTerrainWalkable(x, y)
    MoveRectTo(Find, x, y)
    EnumItemsInRect(Find, nil, HideItems)

    SetItemPosition(PATH_ITEM, x, y)

    TERRAIN_X = GetItemX(PATH_ITEM)
    TERRAIN_Y = GetItemY(PATH_ITEM)

    SetItemPosition(PATH_ITEM, 30000., 30000.)

    for i = 1, #HiddenItems do
        SetItemVisible(HiddenItems[i], true)
        HiddenItems[i] = nil
    end

    return (TERRAIN_X - x) ^ 2 + (TERRAIN_Y - y) ^ 2 <= MAX_RANGE and not IsTerrainPathable(x, y, PATHING_TYPE_WALKABILITY)
end

end, Debug and Debug.getLine())
