-- Always-viewable stash with town-only item movement and row upgrades.
OnInit.final("StashUI", function(Require)
    Require('StashService')
    Require('Inventory')
    Require('Gluebutton')
    Require('SimpleButton')
    Require('Frames')
    Require('PlayerSync')
    Require('TextHelpers')
    Require('Audio')

    StashUI = {}

    local SLOT_SIZE = 0.0266
    local ROW_WIDTH = 0.1981
    local ROW_HEIGHT = 0.0312
    local COLUMN_PITCH = ROW_WIDTH / STASH_COLUMNS
    local frame = BlzCreateFrame("ListBoxWar3",
        BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPLEFT, 0.575, 0.408)
    BlzFrameSetSize(frame, ROW_WIDTH + 0.072, 0.276)
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

    local pixel_x = math.abs(BlzPixelToFrameX(1) - BlzPixelToFrameX(0))
    local pixel_y = math.abs(BlzPixelToFrameY(1) - BlzPixelToFrameY(0))

    local function set_rarity_border(slot, item)
        if item then
            local rarity = ItemRuntime.getRarityIndex(item)
            BlzFrameSetTexture(slot.rarityBorder,
                               SPRITE_RARITY[rarity] or SPRITE_RARITY[0], 0,
                               true)
            BlzFrameSetVisible(slot.rarityBorder, true)
        else
            BlzFrameSetVisible(slot.rarityBorder, false)
        end
    end

    for row = 1, STASH_MAX_ROWS do
        rows[row] = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
        BlzFrameSetPoint(rows[row], FRAMEPOINT_TOPLEFT, frame,
                         FRAMEPOINT_TOPLEFT, 0.02,
                         -0.055 - ROW_HEIGHT * (row - 1))
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
                -0.059 - ROW_HEIGHT * (row - 1), function()
                    local pid = GetPlayerId(GetTriggerPlayer()) + 1
                    if GetLocalPlayer() == GetTriggerPlayer() then
                        BlzSendSyncData("stash_action",
                                        "unlock:" .. captured_row)
                    end
                end, "Unlock Stash Row")
            plus_buttons[row]:text("+")
        end

        for column = 1, STASH_COLUMNS do
            local stash_slot = (row - 1) * STASH_COLUMNS + column
            local button = Button.create(rows[row], SLOT_SIZE, SLOT_SIZE,
                0.0032 + COLUMN_PITCH * (column - 1), -0.0023, false)
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
            button.tooltip:point(FRAMEPOINT_TOPRIGHT)
            button:onClick(function()
                local pid = GetPlayerId(GetTriggerPlayer()) + 1
                if GetLocalPlayer() == GetTriggerPlayer() then
                    BlzSendSyncData("stash_action",
                                    "withdraw:" .. stash_slot)
                end
            end)
            button:visible(false)
            slots[stash_slot] = button
        end
    end

    local messages = {
        not_in_town = "The stash can only be changed while you are in town.",
        no_backpack_slot = "There is no compatible empty backpack slot.",
        missing_source = "That stash item is no longer available.",
        locked_slot = "That stash row is locked.",
        currency = "You cannot afford the next stash row.",
        maxed = "Every stash row is already unlocked.",
        invalid_target = "That item cannot be withdrawn to your backpack."
    }

    local function show_result(pid, response)
        if response and not response.ok then
            local message = messages[response.code]
            if message then
                DisplayTimedTextToPlayer(Player(pid - 1), 0., 0., 12.,
                                         message)
                SoundHandler("Sound\\Interface\\Error.wav", false,
                             Player(pid - 1))
            end
        end
    end

    function StashUI.refresh(pid)
        if not open_for[pid] or GetLocalPlayer() ~= Player(pid - 1) then return end
        local hero = Profile[pid] and Profile[pid].hero
        if not hero then return end
        local unlocked_rows = math.max(1,
            math.min(STASH_MAX_ROWS, hero.stash_rows or 1))
        local used = 0
        for slot = 1, MAX_STASH_SLOTS do
            local item = hero.stash[slot]
            local button = slots[slot]
            if item then
                used = used + 1
                local icon = BlzGetItemIconPath(item.obj)
                button:icon(icon)
                button.tooltip:icon(icon)
                button.tooltip:name(GetItemName(item.obj))
                button.tooltip:text((item.tooltip or "") ..
                    "|n|cff808080Click to withdraw while in town.|r")
                button:charge(item.charges)
                set_rarity_border(button, item)
                button:visible(true)
            else
                set_rarity_border(button)
                button:visible(false)
            end
        end
        BlzFrameSetText(title, "Stash  " .. used .. " / " ..
                            unlocked_rows * STASH_COLUMNS)
        for row = 1, STASH_MAX_ROWS do
            BlzFrameSetVisible(locks[row], row > unlocked_rows)
            if row > 1 then
                local show_plus = row == unlocked_rows + 1
                plus_buttons[row]:visible(show_plus)
                if show_plus then
                    local price = StashService.getRowPrice(row)
                    plus_buttons[row]:setTooltipText(
                        "Unlock Row " .. row .. ": " ..
                            RealToString(price) .. " Gold")
                end
            end
        end
    end

    local function on_sync()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local action, value = BlzGetTriggerSyncData():match("^(%a+):(%d+)$")
        value = tonumber(value)
        local response
        if action == "withdraw" and value then
            response = StashService.withdraw(pid, value)
        elseif action == "unlock" and value then
            local quote = StashService.quoteRow(pid)
            if quote.ok and quote.row == value then
                response = StashService.purchaseRow(pid)
            else
                response = quote
            end
        end
        show_result(pid, response)
        StashUI.refresh(pid)
    end
    SyncCallback("stash_action", on_sync)

    function StashUI.close(pid)
        open_for[pid] = false
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, false)
        end
    end

    function StashUI.open(pid)
        open_for[pid] = true
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
        close_clicked, "Close", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)

    local function inventory_clicked()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        StashUI.close(pid)
        INVENTORY.open(pid, pid)
    end
    local inventory_tab = SimpleButton.create(
        frame, "inventorymenubuttons.dds", 0.055, 0.017,
        FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_BOTTOMLEFT, 0.02, 0.013,
        inventory_clicked, "Return to Inventory", FRAMEPOINT_BOTTOM,
        FRAMEPOINT_TOP, 0., 0.006)
    inventory_tab:text("Inventory")

    AddToEsc(StashUI.close)
    StashService.registerChangedAction(StashUI.refresh)
end, Debug and Debug.getLine())
