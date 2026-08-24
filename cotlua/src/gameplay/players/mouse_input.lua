OnInit.final("Mouse", function(Require)
    Require('Users')
    Require('Variables')
    Require('Events')

    local mouse_x       = __jarray(0) ---@type number[] 
    local mouse_y       = __jarray(0) ---@type number[] 
    local click_counter = __jarray(0) ---@type integer[] 

    IS_M1_DOWN         = {} ---@type boolean[]
    IS_M2_DOWN         = {} ---@type boolean[]
    PLAYER_SELECTED_UNIT = {} ---@type unit[] 

    local player_selected_unit = PLAYER_SELECTED_UNIT
    local event_on_unit_select, event_on_select = EVENT_ON_UNIT_SELECT, EVENT_ON_SELECT

    function GetMouseX(pid)
        return mouse_x[pid]
    end

    function GetMouseY(pid)
        return mouse_y[pid]
    end

    local function select_delay(pid)
        local u = GetMainSelectedUnit()
        if u then
            BlzFrameSetVisible(HIDE_HEALTH_FRAME, (u and Unit[u] and Unit[u].hidehp))
            event_on_unit_select:trigger(u, pid)
            event_on_select:trigger(pid, u)
        end
    end

    ---@return boolean
    local function MouseUp()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local mouse = BlzGetTriggerPlayerMouseButton()

        if mouse == MOUSE_BUTTON_TYPE_LEFT then
            TimerQueue:callDelayed(0., select_delay, pid)

            EVENT_ON_M1_UP:trigger(pid)
            IS_M1_DOWN[pid] = false
        elseif mouse == MOUSE_BUTTON_TYPE_RIGHT then
            EVENT_ON_M2_UP:trigger(pid)
            IS_M2_DOWN[pid] = false
        end

        return false
    end

    ---@return boolean
    local function MouseDown()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1 ---@type integer 
        local mouse = BlzGetTriggerPlayerMouseButton()

        click_counter[pid] = click_counter[pid] + 1

        if mouse == MOUSE_BUTTON_TYPE_LEFT then
            EVENT_ON_M1_DOWN:trigger(pid)
            IS_M1_DOWN[pid] = true
        elseif mouse == MOUSE_BUTTON_TYPE_RIGHT then
            EVENT_ON_M2_DOWN:trigger(pid)
            IS_M2_DOWN[pid] = true
        end

        return false
    end

    local getmousex, getmousey = BlzGetTriggerPlayerMouseX, BlzGetTriggerPlayerMouseY
    local event_mouse_move = EVENT_ON_MOUSE_MOVE

    ---@return boolean
    local function MoveMouse()
        local x = getmousex() ---@type number 

        if x ~= 0 then
            local y = getmousey() ---@type number 
            local p   = GetTriggerPlayer()
            local pid = GetPlayerId(p) + 1 ---@type integer 

            event_mouse_move:trigger(pid, x, y, mouse_x[pid], mouse_y[pid])

            mouse_x[pid] = x
            mouse_y[pid] = y
        end

        return false
    end

    ---@return boolean
    local function OnSelect()
        local u   = GetTriggerUnit()
        local p   = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1 ---@type integer 

        player_selected_unit[pid] = u

        return false
    end

    local click     = CreateTrigger()
    local move      = CreateTrigger()
    local mousedown = CreateTrigger()
    local mouseup   = CreateTrigger()
    local u         = User.first ---@type User 

    while u do
        TriggerRegisterPlayerUnitEvent(click, u.player, EVENT_PLAYER_UNIT_SELECTED, nil)
        TriggerRegisterPlayerEvent(move, u.player, EVENT_PLAYER_MOUSE_MOVE)
        TriggerRegisterPlayerEvent(mousedown, u.player, EVENT_PLAYER_MOUSE_DOWN)
        TriggerRegisterPlayerEvent(mouseup, u.player, EVENT_PLAYER_MOUSE_UP)
        u = u.next
    end

    TriggerAddCondition(click, Filter(OnSelect))
    TriggerAddCondition(move, Filter(MoveMouse))
    TriggerAddCondition(mousedown, Filter(MouseDown))
    TriggerAddCondition(mouseup, Filter(MouseUp))
end, Debug and Debug.getLine())
