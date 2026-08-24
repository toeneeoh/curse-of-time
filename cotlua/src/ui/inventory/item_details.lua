-- Item details presentation. Item runtime supplies display data only.

OnInit.final("ItemDetails", function(Require)
    Require('Frames')
    Require('Hotkeys')
    Require('SimpleButton')

    local WIDTH = 0.31
    local HEIGHT = 0.35
    local HEADER_HEIGHT = 0.06
    local PADDING = 0.018
    local VIEW_HEIGHT = HEIGHT - HEADER_HEIGHT - 0.018

    local frame = BlzCreateFrame("ListBoxWar3", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    local icon = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
    local title = BlzCreateFrame("TitleText", frame, 0, 0)
    local scroll_frame = BlzCreateFrameByType("BUTTON", "", frame, "", 0)
    local text = BlzCreateFrameByType("TEXT", "", scroll_frame, "", 0)
    local lines = {}
    local first = 1
    local has_more = false

    BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOP, 0.41, 0.52)
    BlzFrameSetSize(frame, WIDTH, HEIGHT)
    BlzFrameSetEnable(frame, false)
    BlzFrameSetLevel(frame, 20)

    BlzFrameSetSize(icon, 0.038, 0.038)
    BlzFrameSetPoint(icon, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, PADDING, -0.014)
    BlzFrameSetEnable(icon, false)

    BlzFrameSetPoint(title, FRAMEPOINT_LEFT, icon, FRAMEPOINT_RIGHT, 0.010, 0.)
    BlzFrameSetSize(title, WIDTH - 0.05, 0.)
    BlzFrameSetTextAlignment(title, TEXT_JUSTIFY_MIDDLE, TEXT_JUSTIFY_LEFT)
    BlzFrameSetScale(title, 0.8)
    BlzFrameSetEnable(title, false)

    BlzFrameSetPoint(scroll_frame, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, PADDING, -HEADER_HEIGHT)
    BlzFrameSetSize(scroll_frame, WIDTH - PADDING * 2., VIEW_HEIGHT)
    BlzFrameSetPoint(text, FRAMEPOINT_TOPLEFT, scroll_frame, FRAMEPOINT_TOPLEFT, 0., 0.)
    BlzFrameSetSize(text, WIDTH - PADDING * 2., 0.)
    BlzFrameSetFont(text, "MasterFont", 0.010, 0)
    BlzFrameSetTextAlignment(text, TEXT_JUSTIFY_TOP, TEXT_JUSTIFY_LEFT)
    BlzFrameSetEnable(text, false)
    BlzFrameSetVisible(frame, false)

    ItemDetails = {}

    function ItemDetails.hide(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, false)
        end
    end

    local function close()
        ItemDetails.hide(GetPlayerId(GetTriggerPlayer()) + 1)
    end

    SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015,
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.018, -0.018, close,
        "Close", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)
    AddToEsc(ItemDetails.hide)

    local function refresh()
        local visible = {}
        has_more = false

        for index = first, #lines do
            visible[#visible + 1] = lines[index]
            BlzFrameSetText(text, table.concat(visible, "|n"))

            if BlzFrameGetHeight(text) > VIEW_HEIGHT then
                visible[#visible] = nil
                has_more = true
                break
            end
        end

        if #visible == 0 and lines[first] then
            visible[1] = lines[first]
            has_more = first < #lines
        end

        BlzFrameSetText(text, table.concat(visible, "|n"))
    end

    local scroll_trigger = CreateTrigger()
    BlzTriggerRegisterFrameEvent(scroll_trigger, scroll_frame, FRAMEEVENT_MOUSE_WHEEL)
    TriggerAddAction(scroll_trigger, function()
        local trigger_frame = BlzGetTriggerFrame()
        BlzFrameSetEnable(trigger_frame, false)
        BlzFrameSetEnable(trigger_frame, true)

        if GetLocalPlayer() == GetTriggerPlayer() then
            local down = BlzGetTriggerFrameValue() < 0.

            if down and has_more then
                first = first + 1
                refresh()
            elseif not down and first > 1 then
                first = first - 1
                refresh()
            end
        end
    end)

    function ItemDetails.show(pid, name, item_icon, description)
        if GetLocalPlayer() ~= Player(pid - 1) then
            return
        end

        BlzFrameSetText(title, "|cffffffff" .. name .. "|r")
        BlzFrameSetTexture(icon, item_icon, 0, true)

        lines = {}
        for line in (description .. "|n"):gmatch("(.-)|n") do
            lines[#lines + 1] = line
        end
        first = 1
        refresh()
        BlzFrameSetVisible(frame, true)
    end
end, Debug and Debug.getLine())
