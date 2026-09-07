OnInit.global("MainMap", function()
    MAIN_MAP = {
        rect = gg_rct_Main_Map,
        vision = gg_rct_Main_Map_Vision,
        minX = GetRectMinX(gg_rct_Main_Map),
        minY = GetRectMinY(gg_rct_Main_Map),
        maxX = GetRectMaxX(gg_rct_Main_Map),
        maxY = GetRectMaxY(gg_rct_Main_Map),
        region = CreateRegion(),
    }

    RegionAddRect(MAIN_MAP.region, MAIN_MAP.rect)

    MAIN_MAP.centerX = (MAIN_MAP.minX + MAIN_MAP.maxX) / 2.
    MAIN_MAP.centerY = (MAIN_MAP.minY + MAIN_MAP.maxY) / 2.
end, Debug and Debug.getLine())
