--[[
    perk_tree.lua

    Local presentation for the connected profile perk graph. Allocation clicks
    are synchronized frame events; panning and zooming remain local UI state.
]]

OnInit.final("PerkTree", function(Require)
    Require('Perks')
    Require('SimpleButton')
    Require('Events')
    Require('Mouse')
    Require('Users')

    PerkTree = {}

    -- Match StatView's 0.30 x 0.33 footprint and begin at its right edge.
    local FRAME_X, FRAME_TOP = 0.25, 0.55
    local FRAME_WIDTH, FRAME_HEIGHT = 0.3, 0.33
    local VIEW_X, VIEW_TOP = FRAME_X + 0.015, FRAME_TOP - 0.075
    local VIEW_WIDTH, VIEW_HEIGHT = 0.27, 0.215
    local VIEW_CENTER_X, VIEW_CENTER_Y = VIEW_X + VIEW_WIDTH * .5,
        VIEW_TOP - VIEW_HEIGHT * .5
    local GRAPH_STEP = 0.043
    local MIN_ZOOM, MAX_ZOOM = .65, 1.55
    local EDGE_SIZE = .0014
    local COLOR_ALLOCATED = BlzConvertColor(255, 72, 255, 96)
    local COLOR_AVAILABLE = BlzConvertColor(255, 255, 204, 0)
    local COLOR_LOCKED = BlzConvertColor(255, 90, 90, 90)
    local COLOR_ROOT = BlzConvertColor(255, 190, 110, 255)

    local frame = BlzCreateFrame("ListBoxWar3",
        BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    local title = BlzCreateFrame("TitleText", frame, 0, 0)
    local points = BlzCreateFrameByType("TEXT", "", frame, "", 0)
    local help = BlzCreateFrameByType("TEXT", "", frame, "", 0)
    local reset_status = BlzCreateFrameByType("TEXT", "", frame, "", 0)
    local viewport = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
    local input = BlzCreateFrameByType("BUTTON", "", viewport, "", 0)
    local node_frames = {}
    local node_icons = {}
    local edges = {}
    local is_open = __jarray(false)
    local view_state = {}

    BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPLEFT, FRAME_X, FRAME_TOP)
    BlzFrameSetSize(frame, FRAME_WIDTH, FRAME_HEIGHT)
    BlzFrameSetLevel(frame, 30)
    BlzFrameSetEnable(frame, false)
    BlzFrameSetVisible(frame, false)

    BlzFrameSetPoint(title, FRAMEPOINT_TOP, frame, FRAMEPOINT_TOP, 0., -0.014)
    BlzFrameSetText(title, "Perks")
    BlzFrameSetEnable(title, false)

    BlzFrameSetPoint(points, FRAMEPOINT_TOP, frame, FRAMEPOINT_TOP, 0., -0.037)
    BlzFrameSetSize(points, 0.27, 0.018)
    BlzFrameSetTextAlignment(points, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
    BlzFrameSetEnable(points, false)

    BlzFrameSetPoint(help, FRAMEPOINT_TOP, frame, FRAMEPOINT_TOP, 0., -0.055)
    BlzFrameSetSize(help, 0.27, 0.016)
    BlzFrameSetText(help, "Drag to pan  |  Mouse wheel to zoom")
    BlzFrameSetTextAlignment(help, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
    BlzFrameSetEnable(help, false)

    BlzFrameSetAbsPoint(viewport, FRAMEPOINT_TOPLEFT, VIEW_X, VIEW_TOP)
    BlzFrameSetSize(viewport, VIEW_WIDTH, VIEW_HEIGHT)
    BlzFrameSetTexture(viewport, "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp", 0, true)
    BlzFrameSetVertexColor(viewport, BlzConvertColor(215, 35, 35, 45))
    BlzFrameSetLevel(viewport, 31)
    BlzFrameSetEnable(viewport, false)

    BlzFrameSetAllPoints(input, viewport)
    BlzFrameSetLevel(input, 33)

    BlzFrameSetPoint(reset_status, FRAMEPOINT_BOTTOMLEFT, frame, FRAMEPOINT_BOTTOMLEFT,
        0.015, 0.018)
    BlzFrameSetSize(reset_status, 0.20, 0.018)
    BlzFrameSetTextAlignment(reset_status, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_LEFT)
    BlzFrameSetEnable(reset_status, false)

    local function state_for(pid)
        local state = view_state[pid]
        if not state then
            state = { pan_x = 0., pan_y = 0., zoom = 1., dragging = false }
            view_state[pid] = state
        end
        return state
    end

    local function node_size(node, zoom)
        local size = node.keystone and .038 or node.notable and .031 or .023
        return size * math.max(.82, zoom)
    end

    local function disabled_icon(path)
        return (path:gsub("CommandButtons\\BTN", "CommandButtonsDisabled\\DISBTN", 1))
    end

    local function graph_position(state, node)
        return VIEW_CENTER_X + state.pan_x + node.x * GRAPH_STEP * state.zoom,
            VIEW_CENTER_Y + state.pan_y + node.y * GRAPH_STEP * state.zoom
    end

    local function inside_view(x, y, size)
        local half = size * .5
        return x - half >= VIEW_X and x + half <= VIEW_X + VIEW_WIDTH
            and y - half >= VIEW_TOP - VIEW_HEIGHT and y + half <= VIEW_TOP
    end

    local function edge_color(target_pid, edge)
        if Perks.hasNode(target_pid, edge.parent.id)
            and Perks.hasNode(target_pid, edge.node.id) then
            return COLOR_ALLOCATED
        end
        local available = Perks.canAllocate(target_pid, edge.node.id)
        if available and Perks.hasNode(target_pid, edge.parent.id) then return COLOR_AVAILABLE end
        return COLOR_LOCKED
    end

    local function position_segment(segment, x, y, width, height)
        BlzFrameClearAllPoints(segment)
        BlzFrameSetAbsPoint(segment, FRAMEPOINT_CENTER, x, y)
        BlzFrameSetSize(segment, math.max(width, .0003), math.max(height, .0003))
    end

    local function render(viewer_pid)
        if not is_open[viewer_pid]
            or GetLocalPlayer() ~= Player(viewer_pid - 1) then return end
        local state = state_for(viewer_pid)
        local target_pid = state.target_pid or viewer_pid

        for index = 1, #edges do
            local edge = edges[index]
            local x1, y1 = graph_position(state, edge.parent)
            local x2, y2 = graph_position(state, edge.node)
            local visible = inside_view(x1, y1, node_size(edge.parent, state.zoom))
                and inside_view(x2, y2, node_size(edge.node, state.zoom))
            local color = edge_color(target_pid, edge)
            local middle_x = (x1 + x2) * .5
            position_segment(edge.horizontal, middle_x, y1, math.abs(x2 - x1), EDGE_SIZE)
            position_segment(edge.vertical, x2, (y1 + y2) * .5, EDGE_SIZE, math.abs(y2 - y1))
            BlzFrameSetVertexColor(edge.horizontal, color)
            BlzFrameSetVertexColor(edge.vertical, color)
            BlzFrameSetVisible(edge.horizontal, visible and math.abs(x2 - x1) > .0003)
            BlzFrameSetVisible(edge.vertical, visible and math.abs(y2 - y1) > .0003)
        end

        local graph_nodes = Perks.getNodes()
        for id = 1, #graph_nodes do
            local node = graph_nodes[id]
            local button = node_frames[id]
            local x, y = graph_position(state, node)
            local size = node_size(node, state.zoom)
            BlzFrameClearAllPoints(button.frame)
            BlzFrameSetAbsPoint(button.frame, FRAMEPOINT_CENTER, x, y)
            BlzFrameSetSize(button.frame, size, size)
            local allocated = Perks.hasNode(target_pid, id)
            local available = Perks.canAllocate(target_pid, id)
            button:icon(allocated and node_icons[id].normal or node_icons[id].disabled)
            button:iconColor(id == 1 and COLOR_ROOT
                or allocated and COLOR_ALLOCATED
                or available and COLOR_AVAILABLE or COLOR_LOCKED)
            button:visible(inside_view(x, y, size))
        end

        BlzFrameSetText(points, "Available: |cffffcc00" .. Perks.getAvailable(target_pid)
            .. "|r    Allocated: |cffffcc00" .. Perks.getSpent(target_pid)
            .. "|r    Total: |cffffcc00" .. Perks.getTotal(target_pid) .. "|r")
        local user = User[target_pid - 1]
        BlzFrameSetText(title, target_pid == viewer_pid and "Perks"
            or ("Perks - " .. (user and user.nameColored or "Player")))
    end

    local nodes = Perks.getNodes()
    for id = 1, #nodes do
        local node = nodes[id]
        local node_id = id
        local tooltip = "|cffffcc00" .. node.name .. "|r|n" .. node.description
        if id > 1 then tooltip = tooltip .. "|n|cffaaaaaaCost: 1 Perk Point|r" end
        local button = SimpleButton.create(viewport, node.icon, .023, .023,
            FRAMEPOINT_CENTER, FRAMEPOINT_CENTER, 0., 0.,
            id > 1 and function()
                local pid = GetPlayerId(GetTriggerPlayer()) + 1
                -- A frame control-click may still arrive after the cursor was
                -- used to pan away from a node. Treat that gesture only as UI
                -- navigation, never as an allocation request.
                if state_for(pid).dragged then return end
                if (state_for(pid).target_pid or pid) ~= pid then return end
                local success, reason = Perks.allocateNode(pid, node_id)
                if not success and reason and reason ~= "ALLOCATED" then
                    DisplayTimedTextToPlayer(Player(pid - 1), 0., 0., 4., reason)
                end
                PerkTree.refresh(pid)
            end or nil, tooltip, FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.008)
        BlzFrameSetLevel(button.frame, 35)
        node_frames[id] = button
        node_icons[id] = { normal = node.icon, disabled = disabled_icon(node.icon) }

        local function create_edge(parent_id)
            if not parent_id then return end
            local horizontal = BlzCreateFrameByType("BACKDROP", "", viewport, "", 0)
            local vertical = BlzCreateFrameByType("BACKDROP", "", viewport, "", 0)
            BlzFrameSetTexture(horizontal, "replaceabletextures\\teamcolor\\teamcolor08", 0, true)
            BlzFrameSetTexture(vertical, "replaceabletextures\\teamcolor\\teamcolor08", 0, true)
            BlzFrameSetLevel(horizontal, 32)
            BlzFrameSetLevel(vertical, 32)
            BlzFrameSetEnable(horizontal, false)
            BlzFrameSetEnable(vertical, false)
            edges[#edges + 1] = {
                node = node, parent = nodes[parent_id],
                horizontal = horizontal, vertical = vertical,
            }
        end
        create_edge(node.parent)
        create_edge(node.alternate_parent)
    end

    local function close(pid)
        is_open[pid] = false
        state_for(pid).dragging = false
        if GetLocalPlayer() == Player(pid - 1) then BlzFrameSetVisible(frame, false) end
    end

    SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp",
        0.018, 0.018, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.018, -0.018,
        function()
            close(GetPlayerId(GetTriggerPlayer()) + 1)
        end, "Close", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.008)

    local reset = SimpleButton.create(frame,
        "ReplaceableTextures\\CommandButtons\\BTNReplay-Loop.blp",
        0.026, 0.026, FRAMEPOINT_BOTTOMRIGHT, FRAMEPOINT_BOTTOMRIGHT, -0.018, 0.015,
        function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            if (state_for(pid).target_pid or pid) ~= pid then return end
            local success, reason = Perks.reset(pid)
            if not success and reason then
                DisplayTimedTextToPlayer(Player(pid - 1), 0., 0., 5., reason)
            end
            PerkTree.refresh(pid)
        end, "Use your stored free reset to refund every allocated Perk Point.",
        FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.008)

    local function cursor_position()
        local pixel_x, pixel_y = BlzGetMouseScreenPosX(), BlzGetMouseScreenPosY()
        local width, height = BlzGetLocalClientWidth(), BlzGetLocalClientHeight()
        if width <= 0 or height <= 0 or pixel_x < 0 or pixel_x > width
            or pixel_y < 0 or pixel_y > height then return nil, nil end
        return BlzPixelToFrameX(pixel_x), BlzPixelToFrameY(pixel_y)
    end

    local function start_drag(pid)
        if not is_open[pid] or GetLocalPlayer() ~= Player(pid - 1) then return end
        local x, y = cursor_position()
        if not x or not y then return end
        if x >= VIEW_X and x <= VIEW_X + VIEW_WIDTH
            and y <= VIEW_TOP and y >= VIEW_TOP - VIEW_HEIGHT then
            local state = state_for(pid)
            state.dragging = true
            state.dragged = false
            state.mouse_x, state.mouse_y = x, y
        end
    end

    local function stop_drag(pid)
        if GetLocalPlayer() == Player(pid - 1) then state_for(pid).dragging = false end
    end

    local function update_drag(pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local state = state_for(pid)
        if not state.dragging then return end
        local x, y = cursor_position()
        if not x or not y then return end
        if state.mouse_x then
            local dx, dy = x - state.mouse_x, y - state.mouse_y
            if math.abs(dx) + math.abs(dy) >= .0005 then state.dragged = true end
            state.pan_x = math.max(-.30, math.min(.30, state.pan_x + dx))
            state.pan_y = math.max(-.25, math.min(.25, state.pan_y + dy))
        end
        state.mouse_x, state.mouse_y = x, y
        render(pid)
    end

    -- Player mouse-move events are synchronized and arrive too irregularly
    -- for smooth frame motion. Sample the asynchronous screen cursor at a
    -- stable UI rate instead; all mutations remain local presentation state.
    local drag_timer = CreateTimer()
    TimerStart(drag_timer, 1. / 64., true, function()
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        update_drag(pid)
    end)

    local function zoom_view()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local f = BlzGetTriggerFrame()
        BlzFrameSetEnable(f, false)
        BlzFrameSetEnable(f, true)
        local state = state_for(pid)
        local old_zoom = state.zoom
        local factor = BlzGetTriggerFrameValue() < 0 and .90 or 1.10
        local new_zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, old_zoom * factor))
        local x, y = cursor_position()
        if not x or not y then return end
        local relative_x, relative_y = x - VIEW_CENTER_X, y - VIEW_CENTER_Y
        state.pan_x = relative_x - (relative_x - state.pan_x) * new_zoom / old_zoom
        state.pan_y = relative_y - (relative_y - state.pan_y) * new_zoom / old_zoom
        state.zoom = new_zoom
        render(pid)
    end

    local function on_click()
        local f = BlzGetTriggerFrame()
        BlzFrameSetEnable(f, false)
        BlzFrameSetEnable(f, true)
    end

    local wheel_trigger = CreateTrigger()
    local click_trigger = CreateTrigger()
    BlzTriggerRegisterFrameEvent(wheel_trigger, input, FRAMEEVENT_MOUSE_WHEEL)
    for id = 1, #node_frames do
        BlzTriggerRegisterFrameEvent(wheel_trigger, node_frames[id].frame, FRAMEEVENT_MOUSE_WHEEL)
    end
    BlzTriggerRegisterFrameEvent(click_trigger, input, FRAMEEVENT_CONTROL_CLICK)
    TriggerAddAction(wheel_trigger, zoom_view)
    TriggerAddAction(click_trigger, on_click)

    ---@param pid integer
    function PerkTree.refresh(pid)
        if not is_open[pid] or GetLocalPlayer() ~= Player(pid - 1) then return end
        render(pid)
        local target_pid = state_for(pid).target_pid or pid
        local owned = target_pid == pid
        local available = owned and Perks.hasReset(pid)
        reset:visible(owned)
        reset:enable(available and Perks.getSpent(pid) > 0)
        if owned then
            BlzFrameSetText(reset_status,
                available and "|cff00ff00Free Reset Available|r"
                    or "|cff777777No Reset Available|r")
        else
            BlzFrameSetText(reset_status, "|cffaaaaaaRead-only inspection|r")
        end
    end

    ---@param pid integer Viewer player id.
    ---@param target_pid? integer Player whose allocations should be displayed.
    function PerkTree.display(pid, target_pid)
        target_pid = target_pid or pid
        local state = state_for(pid)
        local same_target = state.target_pid == target_pid
        state.target_pid = target_pid
        is_open[pid] = not (is_open[pid] and same_target)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, is_open[pid])
        end
        PerkTree.refresh(pid)
    end

    AddToEsc(close)
    Perks.registerChangedAction(function(changed_pid)
        for viewer_pid = 1, PLAYER_CAP do
            if is_open[viewer_pid]
                and (state_for(viewer_pid).target_pid or viewer_pid) == changed_pid then
                PerkTree.refresh(viewer_pid)
            end
        end
    end)
    for pid = 1, PLAYER_CAP do
        EVENT_ON_M1_DOWN:register_action(pid, start_drag)
        EVENT_ON_M2_DOWN:register_action(pid, start_drag)
        EVENT_ON_M1_UP:register_action(pid, stop_drag)
        EVENT_ON_M2_UP:register_action(pid, stop_drag)
        EVENT_ON_CLEANUP:register_action(pid, close)
    end
end, Debug and Debug.getLine())
