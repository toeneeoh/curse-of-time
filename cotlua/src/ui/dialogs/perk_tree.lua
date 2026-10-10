--[[
    perk_tree.lua

    Local presentation for the connected profile perk graph. Allocation clicks
    are explicitly synchronized after local gesture checks; panning and zooming
    remain local UI state.
]]

OnInit.final("PerkTree", function(Require)
    Require('Perks')
    Require('SimpleButton')
    Require('Events')
    Require('Mouse')
    Require('Users')
    Require('PlayerSync')

    PerkTree = {}
    local tutorial_preview = {}

    -- The fullscreen bounds span Stat View's left/bottom edges through the
    -- Inventory window's right/top edges.
    local NORMAL_FRAME_X, NORMAL_FRAME_TOP = 0.25, 0.55
    local NORMAL_FRAME_WIDTH, NORMAL_FRAME_HEIGHT = 0.3, 0.33
    local FULL_FRAME_X, FULL_FRAME_TOP = -0.05, 0.55
    local FULL_FRAME_WIDTH, FULL_FRAME_HEIGHT = 0.8951, 0.38
    local FRAME_X, FRAME_TOP = NORMAL_FRAME_X, NORMAL_FRAME_TOP
    local FRAME_WIDTH, FRAME_HEIGHT = NORMAL_FRAME_WIDTH, NORMAL_FRAME_HEIGHT
    local VIEW_X, VIEW_TOP = FRAME_X + 0.015, FRAME_TOP - 0.075
    local VIEW_WIDTH, VIEW_HEIGHT = FRAME_WIDTH - 0.03, FRAME_HEIGHT - 0.115
    local VIEW_CENTER_X, VIEW_CENTER_Y = VIEW_X + VIEW_WIDTH * .5,
        VIEW_TOP - VIEW_HEIGHT * .5
    local GRAPH_STEP = 0.065
    local MIN_ZOOM, MAX_ZOOM = .04, 1.55
    local EDGE_SIZE = .0014
    local COLOR_ALLOCATED = BlzConvertColor(255, 72, 255, 96)
    local COLOR_AVAILABLE = BlzConvertColor(255, 255, 204, 0)
    local COLOR_LOCKED = BlzConvertColor(255, 90, 90, 90)
    local COLOR_ROOT = BlzConvertColor(255, 190, 110, 255)
    local COLOR_ALTERNATE = BlzConvertColor(255, 95, 155, 205)

    local frame = BlzCreateFrame("ListBoxWar3",
        BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    local title = BlzCreateFrame("TitleText", frame, 0, 0)
    local points = BlzCreateFrameByType("TEXT", "", frame, "", 0)
    local help = BlzCreateFrameByType("TEXT", "", frame, "", 0)
    local reset_status = BlzCreateFrameByType("TEXT", "", frame, "", 0)
    local viewport = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
    local canvas = BlzCreateFrameByType("FRAME", "", frame, "", 0)
    local input = BlzCreateFrameByType("GLUEBUTTON", "", frame, "", 0)
    local node_frames = {}
    local node_icons = {}
    local edges = {}
    local branch_buttons = {}
    local branches = Perks.getBranches()
    local is_open = __jarray(false)
    local view_state = {}
    local node_cache = {}
    local styles = {}
    local style_dirty, style_target = true, nil
    local canvas_x, canvas_y
    local header_branch, header_target = false, nil

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
    BlzFrameSetVisible(help, false) -- Replaced by branch navigation.
    BlzFrameSetTextAlignment(help, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_CENTER)
    BlzFrameSetEnable(help, false)

    BlzFrameSetAbsPoint(viewport, FRAMEPOINT_TOPLEFT, VIEW_X, VIEW_TOP)
    BlzFrameSetSize(viewport, VIEW_WIDTH, VIEW_HEIGHT)
    BlzFrameSetTexture(viewport, "UI\\Widgets\\EscMenu\\Human\\human-options-menu-background.blp", 0, true)
    BlzFrameSetVertexColor(viewport, BlzConvertColor(215, 35, 35, 45))
    BlzFrameSetLevel(viewport, 31)
    BlzFrameSetEnable(viewport, false)
    BlzFrameSetSize(canvas, .001, .001)
    -- Frame levels order sibling subtrees, not only individual descendants.
    -- Keep the node subtree above the full-viewport mouse input catcher.
    BlzFrameSetLevel(canvas, 34)
    BlzFrameSetEnable(canvas, true)

    BlzFrameSetAllPoints(input, viewport)
    BlzFrameSetLevel(input, 33)
    BlzFrameSetEnable(input, true)

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

    local function reset_view(pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local state = state_for(pid)
        state.zoom, state.pan_x, state.pan_y, state.fitted = .85, 0., 0., true
        state.branch, state.dragging, state.dragged = nil, false, false
        state.mouse_x, state.mouse_y = nil, nil
    end

    local function node_size(node, zoom)
        return node.icon_size * zoom
    end

    local function disabled_icon(path)
        return (path:gsub("CommandButtons\\BTN", "CommandButtonsDisabled\\DISBTN", 1))
    end

    local function graph_position(state, node)
        return VIEW_CENTER_X + state.pan_x + node.x * GRAPH_STEP * state.zoom,
            VIEW_CENTER_Y + state.pan_y + node.y * GRAPH_STEP * state.zoom
    end

    local function inside_view(x, y, size, height)
        local half_x, half_y = size * .5, (height or size) * .5
        return x - half_x >= VIEW_X and x + half_x <= VIEW_X + VIEW_WIDTH
            and y - half_y >= VIEW_TOP - VIEW_HEIGHT and y + half_y <= VIEW_TOP
    end

    local function edge_color(edge)
        if styles[edge.parent.id].allocated and styles[edge.node.id].allocated then
            return COLOR_ALLOCATED
        end
        if styles[edge.node.id].available and styles[edge.parent.id].allocated then return COLOR_AVAILABLE end
        if edge.alternate then return COLOR_ALTERNATE end
        return COLOR_LOCKED
    end

    local function position_segment(segment, x, y, width, height)
        BlzFrameClearAllPoints(segment)
        BlzFrameSetPoint(segment, FRAMEPOINT_CENTER, canvas, FRAMEPOINT_CENTER, x, y)
        BlzFrameSetSize(segment, width, height)
    end

    local function clip_segment(segment, cached, x, y, width, height, origin_x, origin_y)
        -- Clip each leg independently in canvas coordinates. Endpoint icons
        -- may both be offscreen while a long connector crosses the viewport.
        local left = math.max(x - width * .5, VIEW_X - origin_x)
        local right = math.min(x + width * .5, VIEW_X + VIEW_WIDTH - origin_x)
        local bottom = math.max(y - height * .5, VIEW_TOP - VIEW_HEIGHT - origin_y)
        local top = math.min(y + height * .5, VIEW_TOP - origin_y)
        local visible = width > .000001 and height > .000001 and right > left and top > bottom
        if cached.visible ~= visible then
            BlzFrameSetVisible(segment, visible)
            cached.visible = visible
        end
        if visible then
            local cx, cy, w, h = (left + right) * .5, (bottom + top) * .5, right - left, top - bottom
            if cached.x ~= cx or cached.y ~= cy or cached.width ~= w or cached.height ~= h then
                position_segment(segment, cx, cy, w, h)
                cached.x, cached.y, cached.width, cached.height = cx, cy, w, h
            end
        end
        return visible
    end

    local function render(viewer_pid)
        if not is_open[viewer_pid]
            or GetLocalPlayer() ~= Player(viewer_pid - 1) then return end
        local state = state_for(viewer_pid)
        local target_pid = state.target_pid or viewer_pid
        local graph_nodes = Perks.getNodes()
        -- Snapshot allocations once per actual profile change. canAllocate()
        -- counts all allocated nodes; calling it for every edge on every drag
        -- tick made navigation quadratic in the number of perks.
        if style_dirty or style_target ~= target_pid then
            local spent, total = Perks.getSpent(target_pid), Perks.getTotal(target_pid)
            local budget = total > spent
            for id = 1, #graph_nodes do
                styles[id] = {allocated = Perks.hasNode(target_pid, id)}
            end
            for id, node in ipairs(graph_nodes) do
                local style = styles[id]
                style.available = id > 1 and not style.allocated and budget
                    and ((styles[node.parent] and styles[node.parent].allocated)
                        or (styles[node.alternate_parent] and styles[node.alternate_parent].allocated)) or false
                style.path = style.allocated and node_icons[id].normal or node_icons[id].disabled
                style.color = id == 1 and COLOR_ROOT or style.allocated and COLOR_ALLOCATED
                    or style.available and COLOR_AVAILABLE or COLOR_LOCKED
            end
            BlzFrameSetText(points, "Available: |cffffcc00" .. math.max(0, total - spent)
                .. "|r    Allocated: |cffffcc00" .. spent .. "|r    Total: |cffffcc00" .. total .. "|r")
            style_target, style_dirty = target_pid, false
        end

        -- Children keep relative anchors. Panning moves ONE canvas rather than
        -- clearing/rebuilding hundreds of individual native frame anchors.
        local origin_x, origin_y = VIEW_CENTER_X + state.pan_x, VIEW_CENTER_Y + state.pan_y
        if canvas_x ~= origin_x or canvas_y ~= origin_y then
            BlzFrameSetAbsPoint(canvas, FRAMEPOINT_CENTER, origin_x, origin_y)
            canvas_x, canvas_y = origin_x, origin_y
        end
        for id = 1, #graph_nodes do
            local node = graph_nodes[id]
            local button = node_frames[id]
            local x, y = graph_position(state, node)
            local size = node_size(node, state.zoom)
            local cached = node_cache[id] or {}
            node_cache[id] = cached
            local visible = inside_view(x, y, size)
            if cached.visible ~= visible then button:visible(visible); cached.visible = visible end
            if visible then
                if cached.zoom ~= state.zoom then
                    BlzFrameClearAllPoints(button.frame)
                    BlzFrameSetPoint(button.frame, FRAMEPOINT_CENTER, canvas, FRAMEPOINT_CENTER,
                        node.x * GRAPH_STEP * state.zoom, node.y * GRAPH_STEP * state.zoom)
                    BlzFrameSetSize(button.frame, size, size)
                    cached.zoom = state.zoom
                end
                local style = styles[id]
                if cached.path ~= style.path then button:icon(style.path); cached.path = style.path end
                if cached.color ~= style.color then button:iconColor(style.color); cached.color = style.color end
            end
        end
        for _, edge in ipairs(edges) do
            -- Subpixel backdrops can disappear at overview zoom. Keep a visible
            -- stroke independently of icon scaling; clipping still limits it.
            local scale, thickness = GRAPH_STEP * state.zoom, math.max(.0008, EDGE_SIZE * state.zoom)
            local visible = false
            for index, segment in ipairs(edge.segments) do
                local a, b = edge.route[index], edge.route[index + 1]
                local dx, dy = math.abs(a[1] - b[1]) * scale, math.abs(a[2] - b[2]) * scale
                local horizontal = dx > .000001
                local shown = clip_segment(segment.frame, segment.cache,
                    (a[1] + b[1]) * .5 * scale, (a[2] + b[2]) * .5 * scale,
                    horizontal and dx or thickness, horizontal and thickness or dy, origin_x, origin_y)
                visible = visible or shown
            end
            if visible then
                local color = edge_color(edge)
                if edge.color ~= color then
                    for _, segment in ipairs(edge.segments) do BlzFrameSetVertexColor(segment.frame, color) end
                    edge.color = color
                end
            end
        end
        if header_branch ~= state.branch or header_target ~= target_pid then
            for _, entry in ipairs(branch_buttons) do
                entry.button:iconColor(state.branch == entry.key and COLOR_AVAILABLE or BlzConvertColor(255, 255, 255, 255))
            end
            local user = User[target_pid - 1]
            local branch_title = ""
            for _, branch in ipairs(branches) do
                if branch.key == state.branch then branch_title = " - " .. branch.name end
            end
            BlzFrameSetText(title, target_pid == viewer_pid and "Perks" .. branch_title
                or ("Perks - " .. (user and user.nameColored or "Player") .. branch_title))
            header_branch, header_target = state.branch, target_pid
        end
    end

    local nodes = Perks.getNodes()
    local graph_extent = 1
    for _, node in ipairs(nodes) do
        graph_extent = math.max(graph_extent, math.abs(node.x), math.abs(node.y))
    end
    local branch_by_key = {}
    for _, branch in ipairs(branches) do branch_by_key[branch.key] = branch end
    for id = 1, #nodes do
        local node = nodes[id]
        local node_id = id
        local tooltip = "|cffffcc00" .. node.name .. "|r|n" .. node.description
        local branch = branch_by_key[node.branch]
        if branch then tooltip = tooltip .. "|n" .. branch.color .. branch.name .. "|r" end
        if id > 1 then
            tooltip = tooltip .. "|n|cffaaaaaaRequires: " .. nodes[node.parent].name
            if node.alternate_parent then tooltip = tooltip .. " or " .. nodes[node.alternate_parent].name end
            tooltip = tooltip .. "|nCost: 1 Perk Point|r"
        end
        local button = SimpleButton.create(canvas, node.icon, .023, .023,
            FRAMEPOINT_CENTER, FRAMEPOINT_CENTER, 0., 0.,
            id > 1 and function()
                local clicked = BlzGetTriggerFrame()
                BlzFrameSetEnable(clicked, false)
                BlzFrameSetEnable(clicked, true)
                local pid = GetPlayerId(GetTriggerPlayer()) + 1
                if GetLocalPlayer() ~= Player(pid - 1) or tutorial_preview[pid] then return end
                -- A frame control-click may still arrive after the cursor was
                -- used to pan away from a node. Treat that gesture only as UI
                -- navigation, never as an allocation request.
                if state_for(pid).dragged then return end
                if (state_for(pid).target_pid or pid) ~= pid then return end
                BlzSendSyncData("perk_tree", tostring(node_id))
            end or nil, tooltip, FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.008)
        BlzFrameSetLevel(button.frame, 35)
        node_frames[id] = button
        node_icons[id] = { normal = node.icon, disabled = disabled_icon(node.icon) }

        local function create_edge(parent_id)
            if not parent_id then return end
            local route, segments = node.routes[parent_id], {}
            for index = 1, #route - 1 do
                local segment = BlzCreateFrameByType("BACKDROP", "", canvas, "", 0)
                BlzFrameSetTexture(segment, "replaceabletextures\\teamcolor\\teamcolor08", 0, true)
                BlzFrameSetLevel(segment, 32)
                BlzFrameSetEnable(segment, false)
                segments[index] = {frame = segment, cache = {}}
            end
            edges[#edges + 1] = {
                node = node, parent = nodes[parent_id],
                route = route, segments = segments,
                alternate = parent_id == node.alternate_parent,
            }
        end
        create_edge(node.parent)
        create_edge(node.alternate_parent)
    end

    local function focus_branch(pid, key)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local state = state_for(pid)
        local min_x, max_x, min_y, max_y
        for _, node in ipairs(nodes) do
            if not key or node.branch == key then
                min_x, max_x = math.min(min_x or node.x, node.x), math.max(max_x or node.x, node.x)
                min_y, max_y = math.min(min_y or node.y, node.y), math.max(max_y or node.y, node.y)
            end
        end
        local zoom = math.min((VIEW_WIDTH - .035) / (math.max(1, max_x - min_x) * GRAPH_STEP),
            (VIEW_HEIGHT - .04) / (math.max(1, max_y - min_y) * GRAPH_STEP))
        state.zoom = math.max(MIN_ZOOM, math.min(.95, zoom))
        state.pan_x = -(min_x + max_x) * .5 * GRAPH_STEP * state.zoom
        state.pan_y = -(min_y + max_y) * .5 * GRAPH_STEP * state.zoom
        state.branch, state.fitted = key, true
        render(pid)
    end
    -- Compact local-only navigation. No new textures or FDF templates are needed.
    local navigation_widths = {.034, .047, .047, .073, .055}
    local navigation_x = .014
    for i = 0, #branches do
        local branch = branches[i]
        local key = branch and branch.key or nil
        local label = branch and branch.name or "All"
        local width = navigation_widths[i + 1]
        local button = SimpleButton.create(frame, "inventorymenubuttons.dds", width, .016,
            FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, navigation_x, -.055,
            function()
                local clicked = BlzGetTriggerFrame()
                BlzFrameSetEnable(clicked, false)
                BlzFrameSetEnable(clicked, true)
                focus_branch(GetPlayerId(GetTriggerPlayer()) + 1, key)
            end, branch and branch.description or "Show the entire tree. Drag to pan; mouse wheel to zoom.",
            FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., .008)
        button:text(label)
        BlzFrameSetScale(button.text_frame, .8)
        branch_buttons[#branch_buttons + 1] = {button = button, key = key}
        navigation_x = navigation_x + width + .004
    end
    -- Branch names live in the header/navigation, never behind graph nodes.

    local function close(pid)
        is_open[pid] = false
        state_for(pid).dragging = false
        if GetLocalPlayer() == Player(pid - 1) then BlzFrameSetVisible(frame, false) end
    end

    local close_button = SimpleButton.create(frame,
        "ReplaceableTextures\\CommandButtons\\BTNCancel.blp",
        0.018, 0.018, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.018, -0.018,
        function()
            local clicked = BlzGetTriggerFrame()
            BlzFrameSetEnable(clicked, false)
            BlzFrameSetEnable(clicked, true)
            close(GetPlayerId(GetTriggerPlayer()) + 1)
        end, "Close", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.008)

    local fullscreen_button

    local function apply_layout(pid)
        local fullscreen = state_for(pid).fullscreen == true
        FRAME_X = fullscreen and FULL_FRAME_X or NORMAL_FRAME_X
        FRAME_TOP = fullscreen and FULL_FRAME_TOP or NORMAL_FRAME_TOP
        FRAME_WIDTH = fullscreen and FULL_FRAME_WIDTH or NORMAL_FRAME_WIDTH
        FRAME_HEIGHT = fullscreen and FULL_FRAME_HEIGHT or NORMAL_FRAME_HEIGHT
        VIEW_X, VIEW_TOP = FRAME_X + 0.015, FRAME_TOP - 0.075
        VIEW_WIDTH, VIEW_HEIGHT = FRAME_WIDTH - 0.03, FRAME_HEIGHT - 0.115
        VIEW_CENTER_X = VIEW_X + VIEW_WIDTH * .5
        VIEW_CENTER_Y = VIEW_TOP - VIEW_HEIGHT * .5

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameClearAllPoints(frame)
            BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPLEFT, FRAME_X, FRAME_TOP)
            BlzFrameSetSize(frame, FRAME_WIDTH, FRAME_HEIGHT)
            BlzFrameClearAllPoints(viewport)
            BlzFrameSetAbsPoint(viewport, FRAMEPOINT_TOPLEFT, VIEW_X, VIEW_TOP)
            BlzFrameSetSize(viewport, VIEW_WIDTH, VIEW_HEIGHT)
            fullscreen_button:icon(fullscreen and
                "ReplaceableTextures\\CommandButtons\\BTNReplay-SpeedDown.blp" or
                "ReplaceableTextures\\CommandButtons\\BTNReplay-SpeedUp.blp")
            fullscreen_button:setTooltipText(fullscreen and "Restore Window" or
                                                 "Fullscreen")
        end
    end

    local function toggle_fullscreen()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if tutorial_preview[pid] then return end
        local clicked = BlzGetTriggerFrame()
        BlzFrameSetEnable(clicked, false)
        BlzFrameSetEnable(clicked, true)
        local state = state_for(pid)
        state.fullscreen = not state.fullscreen
        if state.fullscreen then
            local target_pid = state.target_pid
            CloseAllWindows(pid)
            state.target_pid = target_pid
            is_open[pid] = true
        end
        apply_layout(pid)
        focus_branch(pid, state.branch)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, true)
        end
        PerkTree.refresh(pid)
    end

    fullscreen_button = SimpleButton.create(close_button.frame,
        "ReplaceableTextures\\CommandButtons\\BTNReplay-SpeedUp.blp",
        0.018, 0.018, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPLEFT, -0.004, 0.,
        toggle_fullscreen, "Fullscreen", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0.,
        0.008)

    local reset = SimpleButton.create(frame,
        "ReplaceableTextures\\CommandButtons\\BTNReplay-Loop.blp",
        0.026, 0.026, FRAMEPOINT_BOTTOMRIGHT, FRAMEPOINT_BOTTOMRIGHT, -0.018, 0.015,
        function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local clicked = BlzGetTriggerFrame()
            BlzFrameSetEnable(clicked, false)
            BlzFrameSetEnable(clicked, true)
            if GetLocalPlayer() ~= Player(pid - 1) or tutorial_preview[pid] then return end
            if (state_for(pid).target_pid or pid) ~= pid then return end
            BlzSendSyncData("perk_tree", "reset")
        end, "Use your stored free reset to refund every allocated Perk Point.",
        FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.008)

    -- Only synchronized requests may mutate profile allocations. Never consult
    -- local drag, preview, or inspected-player state inside this callback.
    SyncCallback("perk_tree", function()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local request = BlzGetTriggerSyncData()
        local success, reason
        if request == "reset" then
            success, reason = Perks.reset(pid)
        else
            local id = tonumber(request)
            if not id or id % 1 ~= 0 or id < 2 or id > #nodes then return end
            success, reason = Perks.allocateNode(pid, id)
        end
        if not success and reason and reason ~= "ALLOCATED" then
            DisplayTimedTextToPlayer(Player(pid - 1), 0., 0., 5., reason)
        end
        PerkTree.refresh(pid)
    end)

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
            if dx == 0. and dy == 0. then return end
            if math.abs(dx) + math.abs(dy) >= .0005 then state.dragged = true end
            local limit = (graph_extent + 1) * GRAPH_STEP * state.zoom
            state.pan_x = math.max(-limit, math.min(limit, state.pan_x + dx))
            state.pan_y = math.max(-limit, math.min(limit, state.pan_y + dy))
        end
        state.mouse_x, state.mouse_y = x, y
        render(pid)
    end

    -- Player mouse-move events are synchronized and arrive too irregularly
    -- for smooth frame motion. Sample the asynchronous screen cursor at a
    -- stable UI rate instead; all mutations remain local presentation state.
    local drag_timer = CreateTimer()
    TimerStart(drag_timer, 1. / 32., true, function()
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        update_drag(pid)
    end)

    local function zoom_view()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if not is_open[pid] or GetLocalPlayer() ~= Player(pid - 1) then return end
        -- Read event/cursor data before releasing keyboard focus. Native frame
        -- focus transitions can temporarily invalidate screen-cursor readings.
        local delta = BlzGetTriggerFrameValue()
        local x, y = cursor_position()
        local f = BlzGetTriggerFrame()
        BlzFrameSetEnable(f, false)
        BlzFrameSetEnable(f, true)
        if delta == 0. then return end
        local state = state_for(pid)
        local old_zoom = state.zoom
        local factor = delta < 0 and .90 or 1.10
        local new_zoom = math.max(MIN_ZOOM, math.min(MAX_ZOOM, old_zoom * factor))
        -- Wheel events already identify the hovered frame. Missing cursor data
        -- should change the zoom around the viewport center, not discard it.
        if not x or not y or x < VIEW_X or x > VIEW_X + VIEW_WIDTH
            or y < VIEW_TOP - VIEW_HEIGHT or y > VIEW_TOP then
            x, y = VIEW_CENTER_X, VIEW_CENTER_Y
        end
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
        style_dirty = true
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
            BlzFrameSetText(reset_status, "|cffaaaaaaViewing another player's perks|r")
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
        apply_layout(pid)
        if not state.fitted and GetLocalPlayer() == Player(pid - 1) then
            -- Open at a usable scale near the entrances. "All" is an explicit
            -- overview; squeezing 240 choices into this window is too small
            -- for normal allocation. The outer clusters are reached by panning.
            reset_view(pid)
        end
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, is_open[pid])
        end
        PerkTree.refresh(pid)
    end

    AddToEsc(close)
    PerkTree.close = close
    function PerkTree.isOpen(pid) return is_open[pid] end
    function PerkTree.getTutorialFrame() return frame end
    function PerkTree.previewTutorial(pid, visible)
        tutorial_preview[pid] = visible
        if visible then
            is_open[pid] = true
            style_dirty = true
            state_for(pid).target_pid = pid
            apply_layout(pid)
            reset_view(pid)
            render(pid)
        else
            close(pid)
        end
        if GetLocalPlayer() == Player(pid - 1) then
            reset:visible(false)
            BlzFrameSetText(reset_status, "")
            BlzFrameSetVisible(frame, visible)
        end
    end
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
