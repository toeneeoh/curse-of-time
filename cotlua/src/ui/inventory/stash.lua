-- Companion stash window with synchronized inventory transfers.
OnInit.final("StashUI", function(Require)
    Require('StashService')
    Require('Inventory')
    Require('Gluebutton')
    Require('SimpleButton')
    Require('Frames')
    Require('PlayerSync')
    Require('TextHelpers')
    Require('Audio')
    Require('ItemDetails')

    StashUI = {}

    local SLOT_SIZE = 0.0266
    local ROW_WIDTH = 0.1981
    local ROW_HEIGHT = 0.0312
    local FRAME_WIDTH = ROW_WIDTH + 0.072
    local FRAME_HEIGHT = 0.232
    local COLUMN_PITCH = ROW_WIDTH / STASH_COLUMNS
    local FRAME_LEFT = 0.575 - 0.006 - FRAME_WIDTH
    local FRAME_TOP = 0.408
    local ROW_LEFT = FRAME_LEFT + 0.02
    local FIRST_ROW_TOP = FRAME_TOP - 0.036
    local SLOT_LEFT_INSET = 0.0032
    local SLOT_TOP_INSET = 0.0023

    local frame = BlzCreateFrame("ListBoxWar3",
        BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    BlzFrameSetPoint(frame, FRAMEPOINT_TOPRIGHT, INVENTORY.frame,
                     FRAMEPOINT_TOPLEFT, -0.006, 0.)
    BlzFrameSetSize(frame, FRAME_WIDTH, FRAME_HEIGHT)
    BlzFrameSetEnable(frame, false)
    BlzFrameSetVisible(frame, false)

    local title = BlzCreateFrame("TitleText", frame, 0, 0)
    BlzFrameSetPoint(title, FRAMEPOINT_TOP, frame, FRAMEPOINT_TOP, 0., -0.013)
    BlzFrameSetText(title, "Stash")
    BlzFrameSetEnable(title, false)

    local rows = {}
    local locks = {}
    local slots = {}
    local plus_buttons = {}
    local open_for = __jarray(false)
    local dragging = __jarray(0)
    local ctrl_down = __jarray(false)
    local right_click_origin = __jarray(0)
    local context_slot = __jarray(0)

    local pixel_x = math.abs(BlzPixelToFrameX(1) - BlzPixelToFrameX(0))
    local pixel_y = math.abs(BlzPixelToFrameY(1) - BlzPixelToFrameY(0))

    for row = 1, STASH_MAX_ROWS do
        rows[row] = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
        BlzFrameSetPoint(rows[row], FRAMEPOINT_TOPLEFT, frame,
                         FRAMEPOINT_TOPLEFT, 0.02,
                         -0.036 - ROW_HEIGHT * (row - 1))
        BlzFrameSetSize(rows[row], ROW_WIDTH, ROW_HEIGHT)
        BlzFrameSetTexture(rows[row], "inventory_row.tga", 0, false)
        BlzFrameSetEnable(rows[row], false)

        locks[row] = BlzCreateFrameByType("BACKDROP", "", rows[row], "", 0)
        BlzFrameSetAllPoints(locks[row], rows[row])
        BlzFrameSetTexture(locks[row], "black.dds", 0, true)
        BlzFrameSetVertexColor(locks[row], BlzConvertColor(185, 0, 0, 0))
        BlzFrameSetEnable(locks[row], false)
        BlzFrameSetLevel(locks[row], 3)

        if row > 1 then
            local captured_row = row
            plus_buttons[row] = SimpleButton.create(
                frame, "inventorymenubuttons.dds", 0.022, 0.022,
                FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.224,
                -0.040 - ROW_HEIGHT * (row - 1), function()
                    local pid = GetPlayerId(GetTriggerPlayer()) + 1
                    if GetLocalPlayer() == GetTriggerPlayer() and
                        StashService.isInTown(pid) then
                        BlzSendSyncData("stash_action",
                                        "unlock:" .. captured_row)
                    else
                        StashUI.refresh(pid)
                    end
                end, "Unlock Stash Row")
            plus_buttons[row]:text("+")
        end

        for column = 1, STASH_COLUMNS do
            local stash_slot = (row - 1) * STASH_COLUMNS + column
            local button = Button.create(rows[row], SLOT_SIZE, SLOT_SIZE,
                SLOT_LEFT_INSET + COLUMN_PITCH * (column - 1),
                -SLOT_TOP_INSET, false)
            button.index = stash_slot
            button.rarityBorder = BlzCreateFrameByType("BACKDROP", "",
                                                        button.iconFrame, "", 0)
            BlzFrameSetPoint(button.rarityBorder, FRAMEPOINT_TOPLEFT,
                             button.iconFrame, FRAMEPOINT_TOPLEFT, -pixel_x,
                             pixel_y)
            BlzFrameSetPoint(button.rarityBorder, FRAMEPOINT_BOTTOMRIGHT,
                             button.iconFrame, FRAMEPOINT_BOTTOMRIGHT,
                             -pixel_x, pixel_y)
            BlzFrameSetEnable(button.rarityBorder, false)
            BlzFrameSetLevel(button.rarityBorder, 1)
            BlzFrameSetLevel(button.chargeFrame, 2)
            BlzFrameSetVisible(button.rarityBorder, false)
            button.tooltip:enableAttachments()
            button.tooltip:point(FRAMEPOINT_TOPLEFT)
            button:visible(false)
            slots[stash_slot] = button
        end
    end

    local messages = {
        not_in_town = "The stash can only be changed while you are in town.",
        no_backpack_slot = "There is no compatible empty backpack slot.",
        missing_source = "That item is no longer available.",
        locked_slot = "That stash row is locked.",
        currency = "You cannot afford the next stash row.",
        maxed = "Every stash row is already unlocked.",
        invalid_target = "That item cannot be moved to the selected slot.",
        stash_full = "Your unlocked stash rows are full.",
        occupied = "That stash slot is occupied.",
        unsellable = "That item cannot be sold.",
        destroy_failed = "That item could not be removed."
    }

    local context_frame = BlzCreateFrameByType("FRAME", "", frame, "", 0)
    BlzFrameSetSize(context_frame, 0.001, 0.001)
    BlzFrameSetEnable(context_frame, false)
    BlzFrameSetLevel(context_frame, 20)
    BlzFrameSetVisible(context_frame, false)
    local context_buttons = {}
    local context_names = {"Take", "Drop", "Sell", "Details"}
    for index, name in ipairs(context_names) do
        local button = SimpleButton.create(context_frame,
            "inventorymenubuttons.dds", 0.055, 0.016, FRAMEPOINT_TOPLEFT,
            FRAMEPOINT_TOPLEFT, 0., -0.016 * (index - 1))
        BlzFrameSetLevel(button.frame, 21)
        button:text(name)
        context_buttons[index] = button
    end

    local function set_tooltips_visible(visible)
        for _, slot in ipairs(slots) do slot.tooltip:visible(visible) end
    end

    local function close_context(pid)
        context_slot[pid] = 0
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(context_frame, false)
            set_tooltips_visible(true)
        end
    end

    local function show_result(pid, response)
        if response and not response.ok then
            local message = response.message or messages[response.code]
            if message then
                DisplayTimedTextToPlayer(Player(pid - 1), 0., 0., 12.,
                                         message)
                SoundHandler("Sound\\Interface\\Error.wav", false,
                             Player(pid - 1))
            end
        end
    end

    function StashUI.isOpen(pid)
        return open_for[pid] == true
    end

    function StashUI.isReadOnly(pid)
        return not StashService.isInTown(pid)
    end

    ---Returns -1 outside the stash frame, 0 over its non-slot chrome, or the
    ---1-based stash slot under the local cursor.
    function StashUI.getLocalHoveredSlot()
        local pixel_mouse_x = BlzGetMouseScreenPosX()
        local pixel_mouse_y = BlzGetMouseScreenPosY()
        local client_width = BlzGetLocalClientWidth()
        local client_height = BlzGetLocalClientHeight()
        if client_width <= 0 or client_height <= 0 or pixel_mouse_x < 0 or
            pixel_mouse_x > client_width or pixel_mouse_y < 0 or
            pixel_mouse_y > client_height then
            return -1
        end

        local x = BlzPixelToFrameX(pixel_mouse_x)
        local y = BlzPixelToFrameY(pixel_mouse_y)
        if x < FRAME_LEFT or x > FRAME_LEFT + FRAME_WIDTH or y > FRAME_TOP or
            y < FRAME_TOP - FRAME_HEIGHT then
            return -1
        end

        local half = SLOT_SIZE * 0.5
        for row = 1, STASH_MAX_ROWS do
            local center_y = FIRST_ROW_TOP - ROW_HEIGHT * (row - 1) -
                                 SLOT_TOP_INSET - half
            for column = 1, STASH_COLUMNS do
                local center_x = ROW_LEFT + SLOT_LEFT_INSET +
                                     COLUMN_PITCH * (column - 1) + half
                if math.abs(x - center_x) <= half and
                    math.abs(y - center_y) <= half then
                    return (row - 1) * STASH_COLUMNS + column
                end
            end
        end
        return 0
    end

    function StashUI.refresh(pid)
        if not open_for[pid] or GetLocalPlayer() ~= Player(pid - 1) then return end
        local hero = Profile[pid] and Profile[pid].hero
        if not hero then return end
        local read_only = StashUI.isReadOnly(pid)
        if read_only then close_context(pid) end
        local unlocked_rows = math.max(1,
            math.min(STASH_MAX_ROWS, hero.stash_rows or 1))
        local used = 0
        for slot = 1, MAX_STASH_SLOTS do
            local item = hero.stash[slot]
            if item then used = used + 1 end
            INVENTORY.renderItemButton(slots[slot], item, pid)
        end
        BlzFrameSetText(title, "Stash  " .. used .. " / " ..
                            unlocked_rows * STASH_COLUMNS ..
                            (read_only and "  |cff808080(Read Only)|r" or ""))
        for row = 1, STASH_MAX_ROWS do
            BlzFrameSetVisible(locks[row], row > unlocked_rows)
            if row > 1 then
                local show_plus = not read_only and row == unlocked_rows + 1
                plus_buttons[row]:visible(show_plus)
                if show_plus then
                    plus_buttons[row]:setTooltipText(
                        "Unlock Row " .. row .. ": " ..
                            RealToString(StashService.getRowPrice(row)) ..
                            " Gold")
                end
            end
        end
    end

    local function on_sync()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local data = BlzGetTriggerSyncData()
        local action, first, second = data:match("^(%a+):(%d+):?(%d*)$")
        first = tonumber(first)
        second = tonumber(second)
        local response
        if action == "withdraw" and first then
            response = StashService.withdraw(pid, first)
        elseif action == "deposit" and first then
            response = StashService.deposit(pid, first)
        elseif action == "transfer" and first and second then
            response = StashService.transfer(pid, first, second)
        elseif action == "move" and first and second then
            response = StashService.move(pid, first, second)
        elseif action == "drop" and first then
            response = StashService.drop(pid, first)
        elseif action == "sell" and first then
            response = StashService.sell(pid, first)
        elseif action == "unlock" and first then
            local quote = StashService.quoteRow(pid)
            if quote.ok and quote.row == first then
                response = StashService.purchaseRow(pid)
            else
                response = quote
            end
        end
        if action == "sell" and response and response.ok then
            SoundHandler(
                "Abilities\\Spells\\Items\\ResourceItems\\ReceiveGold.flac",
                true, Player(pid - 1), Hero[pid])
        end
        show_result(pid, response)
        StashUI.refresh(pid)
    end
    SyncCallback("stash_action", on_sync)

    local function context_clicked()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if StashUI.isReadOnly(pid) then
            close_context(pid)
            StashUI.refresh(pid)
            return
        end
        local clicked = BlzGetTriggerFrame()
        local selected = context_slot[pid]
        if selected <= 0 then return end
        for index, button in ipairs(context_buttons) do
            if clicked == button.frame then
                close_context(pid)
                if index == 4 then
                    local hero = Profile[pid] and Profile[pid].hero
                    local item = hero and hero.stash[selected]
                    if item then
                        local info = item:info()
                        ItemDetails.show(pid, info.name, info.icon,
                                         info.description)
                    end
                elseif GetLocalPlayer() == Player(pid - 1) then
                    local action = index == 1 and "withdraw" or
                                       index == 2 and "drop" or "sell"
                    BlzSendSyncData("stash_action",
                                    action .. ":" .. selected)
                end
                return
            end
        end
    end
    for _, button in ipairs(context_buttons) do
        button:onClick(context_clicked)
    end

    local function on_m1_down()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if not open_for[pid] then return end
        if StashUI.isReadOnly(pid) then
            close_context(pid)
            StashUI.refresh(pid)
            return
        end
        local stash_slot = GetLocalPlayer() == Player(pid - 1) and
                               StashUI.getLocalHoveredSlot() or 0
        local hero = Profile[pid] and Profile[pid].hero
        local item = hero and hero.stash[stash_slot]
        if not item then return end

        if ctrl_down[pid] then
            if GetLocalPlayer() == Player(pid - 1) then
                BlzSendSyncData("stash_action", "withdraw:" .. stash_slot)
            end
            return
        end

        dragging[pid] = stash_slot
        if GetLocalPlayer() == Player(pid - 1) then
            slots[stash_slot]:visible(false)
        end
        INVENTORY.showDragTracker(pid, BlzGetItemIconPath(item.obj))
    end

    local function on_m2_down()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if StashUI.isReadOnly(pid) then
            right_click_origin[pid] = 0
            close_context(pid)
            StashUI.refresh(pid)
            return
        end
        right_click_origin[pid] = open_for[pid] and
                                      (GetLocalPlayer() == Player(pid - 1) and
                                          StashUI.getLocalHoveredSlot() or 0) or 0
    end

    local function on_m2_up()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if StashUI.isReadOnly(pid) then
            right_click_origin[pid] = 0
            close_context(pid)
            StashUI.refresh(pid)
            return
        end
        local released = GetLocalPlayer() == Player(pid - 1) and
                             StashUI.getLocalHoveredSlot() or 0
        local selected = right_click_origin[pid]
        right_click_origin[pid] = 0
        local hero = Profile[pid] and Profile[pid].hero
        if selected > 0 and released == selected and hero and
            hero.stash[selected] then
            context_slot[pid] = selected
            if GetLocalPlayer() == Player(pid - 1) then
                set_tooltips_visible(false)
                BlzFrameClearAllPoints(context_frame)
                BlzFrameSetPoint(context_frame, FRAMEPOINT_TOPLEFT,
                                 slots[selected].frame, FRAMEPOINT_TOPRIGHT,
                                 0.005, 0.)
                BlzFrameSetVisible(context_frame, true)
            end
        else
            close_context(pid)
        end
    end

    local function on_m1_up()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local source = dragging[pid]
        if source <= 0 then return end
        dragging[pid] = 0
        INVENTORY.hideDragTracker(pid)

        if StashUI.isReadOnly(pid) then
            StashUI.refresh(pid)
            return
        end

        local stash_target = GetLocalPlayer() == Player(pid - 1) and
                                 StashUI.getLocalHoveredSlot() or 0
        local inventory_target = INVENTORY.getLocalInventoryHoveredSlot(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            if stash_target > 0 then
                BlzSendSyncData("stash_action",
                                "move:" .. source .. ":" .. stash_target)
            elseif inventory_target > 0 then
                BlzSendSyncData("stash_action",
                                "transfer:" .. inventory_target .. ":" ..
                                    source)
            elseif stash_target == -1 and inventory_target == -1 then
                BlzSendSyncData("stash_action", "drop:" .. source)
            else
                StashUI.refresh(pid)
            end
        end
    end

    function StashUI.close(pid)
        open_for[pid] = false
        dragging[pid] = 0
        EVENT_ON_M1_DOWN:unregister_action(pid, on_m1_down)
        EVENT_ON_M1_UP:unregister_action(pid, on_m1_up)
        EVENT_ON_M2_DOWN:unregister_action(pid, on_m2_down)
        EVENT_ON_M2_UP:unregister_action(pid, on_m2_up)
        close_context(pid)
        INVENTORY.hideDragTracker(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, false)
        end
    end

    function StashUI.open(pid)
        open_for[pid] = true
        EVENT_ON_M1_DOWN:unregister_action(pid, on_m1_down)
        EVENT_ON_M1_UP:unregister_action(pid, on_m1_up)
        EVENT_ON_M1_DOWN:register_action(pid, on_m1_down)
        EVENT_ON_M1_UP:register_action(pid, on_m1_up)
        EVENT_ON_M2_DOWN:unregister_action(pid, on_m2_down)
        EVENT_ON_M2_UP:unregister_action(pid, on_m2_up)
        EVENT_ON_M2_DOWN:register_action(pid, on_m2_down)
        EVENT_ON_M2_UP:register_action(pid, on_m2_up)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, true)
        end
        StashUI.refresh(pid)
    end

    function StashUI.display(pid)
        if open_for[pid] then StashUI.close(pid) else StashUI.open(pid) end
    end

    local function close_clicked()
        StashUI.close(GetPlayerId(GetTriggerPlayer()) + 1)
    end
    SimpleButton.create(frame,
        "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015,
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.02, -0.02,
        close_clicked, "Close Stash", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0.,
        0.01)

    local function control_state(pid, is_down)
        ctrl_down[pid] = is_down
    end
    RegisterHotkeyToFunc('CTRL', nil, control_state, nil, true)
    RegisterHotkeyToFunc('CTRL+CTRL', nil, control_state, nil, true)

    local function refresh_extended_tooltips(pid)
        StashUI.refresh(pid)
    end
    RegisterHotkeyToFunc('ALT', nil, refresh_extended_tooltips, nil, true)
    RegisterHotkeyToFunc('ALT+ALT', nil, refresh_extended_tooltips, nil, true)

    AddToEsc(StashUI.close)
    StashService.registerChangedAction(StashUI.refresh)
end, Debug and Debug.getLine())
