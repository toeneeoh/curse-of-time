OnInit.global("FrameHelpers", function()
    -- Tasyen/Bribe's main selected unit lookup.
    function GetMainSelectedUnit(...)
        local container_frame = BlzFrameGetChild(BlzFrameGetChild(BlzFrameGetParent(
            BlzGetFrameByName("SimpleInfoPanelUnitDetail", 0)), 5), 0)

        local function get_unit_sort_value(unit)
            return IsUnitType(unit, UNIT_TYPE_HERO) and GetHandleId(unit) or GetUnitTypeId(unit)
        end

        local units
        local function get_unit_at(index)
            return units[index + 1]
        end

        local filter = Filter(function()
            local unit = GetFilterUnit()
            local priority = BlzGetUnitRealField(unit, UNIT_RF_PRIORITY)
            local position = #units + 1

            for i = 1, position - 1 do
                local value = units[i]
                if BlzGetUnitRealField(value, UNIT_RF_PRIORITY) < priority
                    or (BlzGetUnitRealField(value, UNIT_RF_PRIORITY) == priority
                        and get_unit_sort_value(value) > get_unit_sort_value(unit)) then
                    position = i
                    break
                end
            end
            table.insert(units, position, unit)
        end)

        local frames = {}
        for index = 0, BlzFrameGetChildrenCount(container_frame) - 1 do
            local button_container = BlzFrameGetChild(container_frame, index)
            frames[index + 1] = BlzFrameGetChild(button_container, 0)
        end

        ---@param at_index? integer
        ---@param async? boolean
        function GetMainSelectedUnit(at_index, async)
            if async and not at_index and BlzFrameIsVisible(container_frame) then
                for i = 1, #frames do
                    if BlzFrameIsVisible(frames[i]) then
                        at_index = i - 1
                        break
                    end
                end
            end

            local which_filter
            local get_unit = FirstOfGroup
            if at_index then
                units = {}
                which_filter = filter
                get_unit = get_unit_at
            end
            GroupEnumUnitsSelected(bj_lastCreatedGroup, GetLocalPlayer(), which_filter)
            return get_unit(at_index or bj_lastCreatedGroup)
        end

        return GetMainSelectedUnit(...)
    end

    ---@param u unit
    function reselect(u)
        if GetLocalPlayer() == GetOwningPlayer(u) then
            ClearSelection()
            SelectUnit(u, true)
        end
    end

    local frame_create_context = 0

    ---@return integer
    function NextFrameCreateContext()
        frame_create_context = frame_create_context + 1
        return frame_create_context
    end

    ---@type fun(frame: framehandle, title: string, text: string, simple: boolean, point1: framepointtype|nil, point2: framepointtype|nil, x: number|nil, y: number|nil, margin: number|nil): table
    function FrameAddSimpleTooltip(frame, title, text, simple, point1, point2, x, y, margin)
        local tooltip = {}
        point1 = point1 or FRAMEPOINT_TOP
        point2 = point2 or FRAMEPOINT_BOTTOM
        x = x or 0.
        y = y or -0.008
        margin = margin or 0.008

        if simple then
            tooltip.frame = BlzCreateFrame("Leaderboard", frame, 0, 0)
            tooltip.tooltip = BlzCreateFrameByType("TEXT", "", tooltip.frame, "", 0)
            BlzFrameSetPoint(tooltip.tooltip, point1, frame, point2, x, y)
            BlzFrameSetPoint(tooltip.frame, FRAMEPOINT_TOPLEFT, tooltip.tooltip,
                FRAMEPOINT_TOPLEFT, -margin, margin)
            BlzFrameSetPoint(tooltip.frame, FRAMEPOINT_BOTTOMRIGHT, tooltip.tooltip,
                FRAMEPOINT_BOTTOMRIGHT, margin, -margin)
        else
            local context = NextFrameCreateContext()
            tooltip.frame = BlzCreateFrame("TooltipBoxFrame", frame, 0, context)
            tooltip.box = BlzGetFrameByName("TooltipBox", context)
            tooltip.line = BlzGetFrameByName("TooltipSeperator", context)
            tooltip.tooltip = BlzGetFrameByName("TooltipText", context)
            tooltip.iconFrame = BlzGetFrameByName("TooltipIcon", context)
            tooltip.nameFrame = BlzGetFrameByName("TooltipName", context)

            BlzFrameSetPoint(tooltip.tooltip, FRAMEPOINT_CENTER,
                BlzGetFrameByName("CommandButton_3", 0), FRAMEPOINT_TOPLEFT, -0.09, 0.045)
            BlzFrameSetSize(tooltip.iconFrame, 0.009, 0.009)
            BlzFrameSetTexture(tooltip.iconFrame, "trans32.blp", 0, true)
            BlzFrameSetText(tooltip.nameFrame, title)
            BlzFrameSetPoint(tooltip.box, FRAMEPOINT_TOPLEFT, tooltip.iconFrame,
                FRAMEPOINT_TOPLEFT, -0.005, 0.005)
            BlzFrameSetPoint(tooltip.box, FRAMEPOINT_BOTTOMRIGHT, tooltip.tooltip,
                FRAMEPOINT_BOTTOMRIGHT, 0.005, -0.005)
            BlzFrameSetSize(tooltip.tooltip, 0.275, 0)
            BlzFrameClearAllPoints(tooltip.nameFrame)
            BlzFrameSetPoint(tooltip.nameFrame, FRAMEPOINT_TOPLEFT, tooltip.iconFrame,
                FRAMEPOINT_TOPLEFT, 0, 0)
            BlzFrameSetScale(tooltip.nameFrame, 0.77)
        end

        BlzFrameSetText(tooltip.tooltip, text)
        BlzFrameSetTooltip(frame, tooltip.frame)
        return tooltip
    end
end)
