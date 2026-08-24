--[[
    inventory.lua

    A library for recreating an inventory system using custom frames
]]
OnInit.final("Inventory", function(Require)
    Require('InventoryService')
    Require('ItemDetails')
    Require('ItemEventRegistry')
    Require('Users')
    Require('Frames')
    Require('Currency')

    local INVENTORY_WIDTH   = 0.1981
    local INVENTORY_HEIGHT  = 0.232
    local INVENTORY_GAPY    = 0.0312
    local INVENTORY_GAPX    = 0.0333
    local INVENTORY_TEXTURE = "inventory_row.tga"
    local POTION_TEXTURE    = "war3mapImported\\PotionBackdrop2.dds"
    local INVENTORY_MIN_X   = 0.612
    local INVENTORY_MIN_Y   = 0.214
    local INVENTORY_SLOT_SIZE = 0.0266
    local DROP_ITEM_COMMAND = "robogoblin"

    local FPS_64 = FPS_32 * 0.5
    local concat = table.concat
    local frame_set_visible, frame_clear_all_points = BlzFrameSetVisible, BlzFrameClearAllPoints
    local get_x_stable, get_y_stable = GetMouseFrameXStable, GetMouseFrameYStable
    local setabspoint = BlzFrameSetAbsPoint

    local CONTEXT_BUTTON_WIDTH = 0.055
    local CONTEXT_BUTTON_HEIGHT = 0.016

    -- slot atlas
    -- fields: {x, y, kind}
    local inventory_slots = {
        {0.0000, 0.1248, "main"},
        {0.0333, 0.1248, "main"},
        {0.0666, 0.1248, "main"},
        {0.0999, 0.1248, "main", FRAMEPOINT_TOPRIGHT},
        {0.1332, 0.1248, "main", FRAMEPOINT_TOPRIGHT},
        {0.1665, 0.1248, "main", FRAMEPOINT_TOPRIGHT},

        {0.2048, 0.1248, "potion1", FRAMEPOINT_TOPRIGHT},
        {0.2048, 0.0936, "potion2", FRAMEPOINT_TOPRIGHT},

        {0.0000, 0.0624, "unequip1"},
        {0.0333, 0.0624, "unequip1"},
        {0.0666, 0.0624, "unequip1"},
        {0.0999, 0.0624, "unequip1", FRAMEPOINT_TOPRIGHT},
        {0.1332, 0.0624, "unequip1", FRAMEPOINT_TOPRIGHT},
        {0.1665, 0.0624, "unequip1", FRAMEPOINT_TOPRIGHT},

        {0.0000, 0.0312, "unequip2"},
        {0.0333, 0.0312, "unequip2"},
        {0.0666, 0.0312, "unequip2"},
        {0.0999, 0.0312, "unequip2", FRAMEPOINT_TOPRIGHT},
        {0.1332, 0.0312, "unequip2", FRAMEPOINT_TOPRIGHT},
        {0.1665, 0.0312, "unequip2", FRAMEPOINT_TOPRIGHT},

        {0.0000, 0.0,    "unequip3"},
        {0.0333, 0.0,    "unequip3"},
        {0.0666, 0.0,    "unequip3"},
        {0.0999, 0.0,    "unequip3", FRAMEPOINT_TOPRIGHT},
        {0.1332, 0.0,    "unequip3", FRAMEPOINT_TOPRIGHT},
        {0.1665, 0.0,    "unequip3", FRAMEPOINT_TOPRIGHT},
    }

    -- tracker is offset for some reason
    local MAGIC_X_OFFSET = 0.21
    local MAGIC_Y_OFFSET = -0.085

    ---@param slot integer
    ---@return number x, number y
    local slot_to_xy = function(slot)
        if inventory_slots[slot] then
            return inventory_slots[slot][1] + MAGIC_X_OFFSET, inventory_slots[slot][2] + MAGIC_Y_OFFSET
        end

        return 0, 0
    end

    local disabled_for_player = {}
    local alt_down = {} ---@type boolean[]

    ---@param pid integer
    ---@param disable boolean
    function DisableItems(pid, disable)
        disabled_for_player[pid] = disable

        if disable then
            INVENTORY.close(pid)
        end
    end

    INVENTORY = {}
    do
        local thistype = INVENTORY
        local context, target, slots = __jarray(0), __jarray(0), {} ---@type Button[]
        local viewing, move_item_cooldown = __jarray(-1), {}
        local on_m1_down, on_m2_down, on_m1_up, on_m2_up, open_context_menu
        local target_thread = {} -- used to sync context and target acquisition
        local synced_context, synced_target = {}, {}
        local pending_click  = {} -- stores index of context menu click
        local ui_mode = __jarray(0) -- 0 = normal, 1 = context menu open

        -- determines what item slot a user has their cursor over
        ---@return integer
        local get_hovered_slot = function()
            local x, y = get_x_stable(), get_y_stable()

            -- bail if mouse is outside inventory UI
            if x < INVENTORY_MIN_X - 0.03 or x > INVENTORY_MIN_X + INVENTORY_WIDTH + 0.03 or
            y < INVENTORY_MIN_Y - 0.03 or y > INVENTORY_MIN_Y + INVENTORY_HEIGHT - 0.03
            then
                return -1
            end

            local closest_slot = 0
            local closest_distance = 1000
            local mouse_x = x - INVENTORY_MIN_X
            local mouse_y = y - INVENTORY_MIN_Y
            local threshold_distance = 0.025 * 0.025

            -- loop through each slot's position and calculate the distance to the mouse
            for i = 1, #inventory_slots do
                local pos = inventory_slots[i]
                local dx = mouse_x - pos[1]
                local dy = mouse_y - pos[2]
                local distance = dx * dx + dy * dy

                -- check if this slot is the closest
                if distance < closest_distance then
                    closest_distance = distance
                    closest_slot = i
                end
            end

            if closest_distance > threshold_distance then
                return 0
            end

            return closest_slot
        end

        -- determines what item slot a user is highlighting
        ---@return integer
        local get_highlighted_slot = function(pid)
            local index = 0

            for i = 1, MAX_INVENTORY_SLOTS do
                if BlzFrameIsVisible(slots[i].tooltip.frame) then
                    index = slots[i].index
                    break
                end
            end

            return index
        end

        --#region frame setup
        local frame = BlzCreateFrame("ListBoxWar3", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
        BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPLEFT, 0.575, 0.408)
        BlzFrameSetSize(frame, INVENTORY_WIDTH + 0.072, INVENTORY_HEIGHT)
        BlzFrameSetEnable(frame, false)

        local title = BlzCreateFrame("TitleText", frame, 0, 0)
        BlzFrameSetPoint(title, FRAMEPOINT_TOP, frame, FRAMEPOINT_TOP, 0., -0.013)
        BlzFrameSetEnable(title, false)
        BlzFrameSetText(title, "Inventory")

        local inv = {}
        local inv_main = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
        BlzFrameSetPoint(inv_main, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, 0.02, -0.06)
        BlzFrameSetSize(inv_main, INVENTORY_WIDTH, INVENTORY_GAPY)
        BlzFrameSetTexture(inv_main, INVENTORY_TEXTURE, 0, false)
        BlzFrameSetEnable(inv_main, true)
        inv[0] = inv_main

        for i = 1, 3 do
            inv[i] = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
            BlzFrameSetPoint(inv[i], FRAMEPOINT_TOPLEFT, inv[i - 1], FRAMEPOINT_BOTTOMLEFT, 0., (i == 1 and -INVENTORY_SLOT_SIZE) or 0.)
            BlzFrameSetSize(inv[i], INVENTORY_WIDTH, INVENTORY_GAPY)
            BlzFrameSetTexture(inv[i], INVENTORY_TEXTURE, 0, false)
            BlzFrameSetEnable(inv[i], true)
        end

        local pot = {}
        for i = 1, 2 do
            pot[i] = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
            BlzFrameSetPoint(pot[i], FRAMEPOINT_TOPLEFT, inv_main, FRAMEPOINT_TOPRIGHT, 0.005, -INVENTORY_GAPY * (i - 1))
            BlzFrameSetSize(pot[i], INVENTORY_GAPX, INVENTORY_GAPY)
            BlzFrameSetTexture(pot[i], POTION_TEXTURE, 0, false)
            BlzFrameSetEnable(pot[i], true)
        end

        frame_set_visible(frame, false)

        -- context menu setup
        local context_menu_backdrop = BlzCreateFrameByType("FRAME", "", frame, "", 0)
        BlzFrameSetTexture(context_menu_backdrop, "trans32.blp", 0, true)
        BlzFrameSetSize(context_menu_backdrop, 0.001, 0.001)
        BlzFrameSetEnable(context_menu_backdrop, false)
        frame_set_visible(context_menu_backdrop, false)
        local context_buttons = {}
        local CONTEXT_IDS = { "Equip", "Unequip", "Drop", "Sell", "Details" }
        for i, name in ipairs(CONTEXT_IDS) do
            context_buttons[i] = SimpleButton.create(context_menu_backdrop, "inventorymenubuttons.dds", CONTEXT_BUTTON_WIDTH, CONTEXT_BUTTON_HEIGHT, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0, 0)
            context_buttons[i]:text(name)
        end
        -- map frames to index
        local frame_to_btn = {}
        for i = 1, #context_buttons do
            frame_to_btn[context_buttons[i].frame] = i
        end
        local cost_frame = BlzCreateFrameByType("FRAME", "", context_buttons[4].frame, "", 0)
        BlzFrameSetSize(cost_frame, 0.001, 0.001)
        BlzFrameSetEnable(cost_frame, false)
        local transparent_placeholder = BlzCreateFrameByType("FRAME", "", context_buttons[1].frame, "", 0)
        BlzFrameSetTexture(transparent_placeholder, "trans32.blp", 0, true)
        BlzFrameSetSize(transparent_placeholder, 0.001, 0.001)
        BlzFrameSetEnable(transparent_placeholder, false)
        frame_set_visible(transparent_placeholder, false)
        local cost_icon = BlzCreateFrameByType("BACKDROP", "", cost_frame, "", 0)
        local cost_icon2 = BlzCreateFrameByType("BACKDROP", "", cost_frame, "", 0)
        local cost_text = BlzCreateFrameByType("TEXT", "", cost_icon, "", 0)
        local cost_text2 = BlzCreateFrameByType("TEXT", "", cost_icon2, "", 0)
        BlzFrameSetPoint(cost_frame, FRAMEPOINT_TOPLEFT, context_buttons[4].frame, FRAMEPOINT_TOPRIGHT, 0., 0.)
        BlzFrameSetPoint(cost_icon, FRAMEPOINT_TOPLEFT, cost_frame, FRAMEPOINT_TOPRIGHT, 0., 0.)
        BlzFrameSetSize(cost_icon, 0.013, 0.013)
        BlzFrameSetTexture(cost_icon, CURRENCY_ICON[GOLD + 1], 0, true)
        BlzFrameSetPoint(cost_text, FRAMEPOINT_TOPLEFT, cost_icon, FRAMEPOINT_TOPRIGHT, 0.002, -0.002)
        BlzFrameSetTextAlignment(cost_text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT)
        BlzFrameSetPoint(cost_icon2, FRAMEPOINT_TOPLEFT, cost_icon, FRAMEPOINT_BOTTOMLEFT, 0., 0.)
        BlzFrameSetSize(cost_icon2, 0.013, 0.013)
        BlzFrameSetTexture(cost_icon2, CURRENCY_ICON[PLATINUM + 1], 0, true)
        BlzFrameSetPoint(cost_text2, FRAMEPOINT_TOPLEFT, cost_icon2, FRAMEPOINT_TOPRIGHT, 0.002, -0.002)
        BlzFrameSetTextAlignment(cost_text2, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT)
        frame_set_visible(cost_frame, false)
        BlzFrameSetTooltip(context_buttons[1].frame, transparent_placeholder)
        BlzFrameSetTooltip(context_buttons[2].frame, transparent_placeholder)
        BlzFrameSetTooltip(context_buttons[3].frame, transparent_placeholder)
        BlzFrameSetTooltip(context_buttons[4].frame, cost_frame)
        BlzFrameSetTooltip(context_buttons[5].frame, transparent_placeholder)

        local context_functions = {
            function(pid, slot) -- EQUIP
                local itm = Profile[pid].hero.items[slot]

                if itm then
                    itm:equip()
                end
            end,
            function(pid, slot) -- UNEQUIP
                local index = -1
                local items = Profile[pid].hero.items
                for i = BACKPACK_INDEX, MAX_INVENTORY_SLOTS do
                    local itm = items[i]
                    if itm == nil then
                        index = i
                        break
                    end
                end
                if index ~= -1 then
                    local itm = items[slot]
                    if itm then
                        itm:equip(index)
                    end
                end
            end,
            function(pid, slot) -- DROP
                local hero = Profile[pid].hero
                local itm = hero.items[slot]

                if itm then
                    itm:drop(GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
                end
            end,
            function(pid, slot) -- SELL
                local itm = Profile[pid].hero.items[slot]
                if itm then
                    SoundHandler("Abilities\\Spells\\Items\\ResourceItems\\ReceiveGold.flac", true, Player(pid - 1), itm.holder)
                    local _, gold, plat = GetItemSellPrice(itm)
                    AddCurrency(pid, GOLD, gold)
                    AddCurrency(pid, PLATINUM, plat)

                    itm:destroy(nil, nil, true)
                end
            end,
            function(pid, slot) -- DETAILS
                local itm = Profile[viewing[pid]].hero.items[slot]
                if itm then
                    local info = itm:info()
                    ItemDetails.show(pid, info.name, info.icon, info.description)
                end
            end,
        }

        local function clear_context(pid)
            context[pid] = 0
            target[pid] = 0
            synced_context[pid] = false
            synced_target[pid] = false
            pending_click[pid] = nil
        end

        local on_context_push = function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local f = BlzGetTriggerFrame()

            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)

            local btn_index = frame_to_btn[f]
            if not btn_index then return false end

            open_context_menu(pid, false)

            -- if not synced, queue pending click to execute at on_context_sync
            if not synced_context[pid] then
                --print("not synced yet!")
                if not pending_click[pid] then
                    pending_click[pid] = btn_index
                end
                return false
            elseif not pending_click[pid] and context[pid] > 0 then
                context_functions[btn_index](pid, context[pid])
                clear_context(pid)
            end

            return false
        end

        for i = 1, #context_buttons do
            context_buttons[i]:onClick(on_context_push)
        end

        local count = 0

        -- frame that follows the mouse (for item dragging)
        local tracker = BlzCreateFrameByType("BACKDROP", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
        BlzFrameSetEnable(tracker, false)
        BlzFrameSetSize(tracker, INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE)
        BlzFrameSetTexture(tracker, "trans32.blp", 0, true)
        -- frame_set_visible(tracker, true)
        -- BlzFrameSetLevel(tracker, 5)

        local function update_tracker()
            setabspoint(tracker, FRAMEPOINT_CENTER, get_x_stable(), get_y_stable())
            if count > 0 then
                TimerQueue:callDelayed(FPS_64, update_tracker)
            end
        end

        local hide_tracker = function(pid)
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetTexture(tracker, "trans32.blp", 0, true)
            end
        end

        --#endregion

        INVENTORY.open = function(pid, tpid)
            if GetLocalPlayer() == Player(pid - 1) then
                frame_set_visible(frame, true)
            end

            -- open may be called again without a close
            EVENT_ON_M1_DOWN:unregister_action(pid, on_m1_down)
            EVENT_ON_M1_UP:unregister_action(pid, on_m1_up)
            EVENT_ON_M2_DOWN:unregister_action(pid, on_m2_down)
            EVENT_ON_M2_UP:unregister_action(pid, on_m2_up)

            viewing[pid] = tpid

            if pid == tpid then -- only allow item movement if looking at your own inventory
                EVENT_ON_M1_DOWN:register_action(pid, on_m1_down)
                EVENT_ON_M1_UP:register_action(pid, on_m1_up)
            end

            EVENT_ON_M2_DOWN:register_action(pid, on_m2_down)
            EVENT_ON_M2_UP:register_action(pid, on_m2_up)

            thistype.refresh(tpid)

            count = count + 1
            if count == 1 then -- only run if atleast one player is looking at the inventory
                TimerQueue:callDelayed(FPS_64, update_tracker)
            end
        end

        INVENTORY.close = function(pid)
            if viewing[pid] ~= -1 then
                if GetLocalPlayer() == Player(pid - 1) then
                    frame_set_visible(frame, false)
                end
                viewing[pid] = -1
                EVENT_ON_M1_DOWN:unregister_action(pid, on_m1_down)
                EVENT_ON_M1_UP:unregister_action(pid, on_m1_up)
                EVENT_ON_M2_DOWN:unregister_action(pid, on_m2_down)
                EVENT_ON_M2_UP:unregister_action(pid, on_m2_up)

                count = math.max(0, count - 1)

                clear_context(pid)
                hide_tracker(pid)
                PauseMouseTracker(pid)
            end
        end
        AddToEsc(INVENTORY.close) -- close window hotkey reference

        INVENTORY.display = function(pid, tpid) -- display to, display target
            if Profile[tpid] and Profile[tpid].playing then
                if viewing[pid] == tpid then
                    thistype.close(pid)
                else
                    thistype.open(pid, tpid)
                end
            end
        end

        local function get_socket_subtext(socket)
            local data = ItemData[socket.id]
            local text = {}

            if socket.level > 0 then
                text[#text + 1] = RARITY_NAME[(socket.level + 3) // socket.rarity]
                text[#text + 1] = " +"
                text[#text + 1] = socket.level
                text[#text + 1] = "|n"
            end

            text[#text + 1] = TIER_NAME[data[ITEM_TIER]]
            text[#text + 1] = " "
            text[#text + 1] = TYPE_NAME[data[ITEM_TYPE]]

            local level_requirement = data[ITEM_LEVEL_REQUIREMENT]
            if level_requirement > 0 then
                text[#text + 1] = "|n|cffff0000Level Requirement: |r"
                text[#text + 1] = level_requirement
            end

            return concat(text)
        end

        local function update_socket_tooltips(tooltip, itm)
            for i = 1, 3 do
                local socket = itm and itm.sockets[i]

                if socket then
                    tooltip:attachment(
                        i,
                        GetItemName(socket.obj),
                        get_socket_subtext(socket),
                        BlzGetItemIconPath(socket.obj)
                    )
                else
                    tooltip:attachment(i)
                end
            end
        end

        INVENTORY.refresh = function(pid)
            if not pid or pid < 1 or not Profile[pid] or not Profile[pid].hero then
                return
            end

            POTION.refresh(pid)

            local me = GetPlayerId(GetLocalPlayer()) + 1

            if viewing[me] ~= pid then
                return
            end

            -- local block for players viewing this inventory
            local items = Profile[pid].hero.items
            for i = 1, MAX_INVENTORY_SLOTS do
                local itm = items[i]

                if itm then
                    local icon = BlzGetItemIconPath(itm.obj)
                    slots[i]:icon(icon)
                    slots[i].tooltip:icon(icon)
                    slots[i].tooltip:name(GetItemName(itm.obj))
                    slots[i].tooltip:text(alt_down[pid] and itm.alt_tooltip or itm.tooltip)
                    update_socket_tooltips(slots[i].tooltip, itm)
                    slots[i]:visible(true)
                    slots[i]:charge(itm.charges)
                else
                    update_socket_tooltips(slots[i].tooltip)
                    slots[i]:visible(false)
                end
            end
        end

        local onCloseButton = function()
            local f = BlzGetTriggerFrame()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1

            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetEnable(f, false)
                BlzFrameSetEnable(f, true)
            end

            thistype.close(pid)

            return false
        end

        -- escape button
        local esc_button = SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.02, -0.02, onCloseButton, "Close 'I'", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)
        RegisterHotkeyTooltip(esc_button, 4)

        local function send_context(pid, slot)
            -- set context asynchronously
            context[pid] = slot
            synced_context[pid] = false

            -- send payload
            if GetLocalPlayer() == Player(pid - 1) then
                BlzSendSyncData("context", string.format("%d", slot))
            end
        end

        local function send_target(pid, slot)
            -- set target asynchronously
            target[pid] = slot
            synced_target[pid] = false

            -- send payload
            if GetLocalPlayer() == Player(pid - 1) then
                BlzSendSyncData("target", tostring(slot))
            end
        end

        local pick_item = function(pid)
            local highlighted = get_highlighted_slot(pid)

            if highlighted > 0 then
                local new_slot = slots[highlighted]

                send_context(pid, highlighted)

                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetTexture(tracker, new_slot.texture, 0, true)
                    new_slot:visible(false)
                end

                local x, y = slot_to_xy(highlighted)
                StartMouseTracker(pid, x, y)
            end
        end

        local reset_cooldown = function(pid)
            move_item_cooldown[pid] = false
        end

        local function find_empty_equip_slot(it, items)
            local type = ItemData[it.id][ITEM_TYPE]
            local start_index, end_index = 1, 6
            if type == 11 then -- TODO: define potion type check somewhere
                start_index, end_index = POTION_INDEX, POTION_INDEX + 1
            end
            for i = start_index, end_index do
                if not items[i] then
                    return i
                end
            end

            return nil
        end

        local function update_context_buttons(pid, slot)
            local owner = viewing[pid]
            local items = Profile[owner].hero.items -- safe for read only
            local it = items[slot.index]

            for i = 1, #context_buttons do
                if GetLocalPlayer() == Player(pid - 1) then
                    context_buttons[i]:visible(false)
                end
            end

            -- determine which buttons should be shown
            local visible_buttons = {}

            -- buttons only shown to the owner
            if pid == viewing[pid] then
                -- unequip logic
                if slot.index < BACKPACK_INDEX then
                    for i = BACKPACK_INDEX, MAX_INVENTORY_SLOTS do
                        if items[i] == nil then
                            visible_buttons[#visible_buttons + 1] = 2 -- UNEQUIP
                            break
                        end
                    end
                else
                -- equip logic
                    local empty_slot = find_empty_equip_slot(it, items)
                    if it and empty_slot and ValidateItemSlot(it, empty_slot) then
                        visible_buttons[#visible_buttons + 1] = 1 -- EQUIP
                    end
                end

                -- always allow dropping items
                visible_buttons[#visible_buttons + 1] = 3

                -- selling logic
                if it then
                    local total, gold, plat = GetItemSellPrice(it)
                    if RectContainsUnit(gg_rct_Town_Main, Hero[pid]) and total > 0 then
                        visible_buttons[#visible_buttons + 1] = 4
                        if GetLocalPlayer() == Player(pid - 1) then
                            BlzFrameSetText(cost_text, string.format("%01d", gold))
                            local show_plat = plat > 0
                            frame_set_visible(cost_icon2, show_plat)
                            if show_plat then
                                BlzFrameSetText(cost_text2, string.format("%01d", plat))
                            end
                        end
                    end
                end
            end

            -- always allow viewing details
            visible_buttons[#visible_buttons + 1] = 5

            -- reattach and reposition visible buttons dynamically
            local previous_button = nil
            for i = 1, #visible_buttons do
                local button_index = visible_buttons[i]
                local button = context_buttons[button_index]

                if GetLocalPlayer() == Player(pid - 1) then
                    frame_clear_all_points(button.frame) -- Clear previous attachment
                    button:visible(true)
                    if previous_button then
                        -- attach below the last visible button
                        BlzFrameSetPoint(button.frame, FRAMEPOINT_TOPLEFT, previous_button.frame, FRAMEPOINT_BOTTOMLEFT, 0, 0)
                    else
                        -- first button, attach to the context menu frame
                        BlzFrameSetPoint(button.frame, FRAMEPOINT_TOPLEFT, context_menu_backdrop, FRAMEPOINT_TOPLEFT, 0, 0)
                    end
                end

                previous_button = button -- update the last attached button
            end
        end

        open_context_menu = function(pid, open)
            -- toggle context menu mode
            ui_mode[pid] = 1

            -- get context asynchronously
            local highlighted = get_highlighted_slot(pid)

            -- open context menu
            if highlighted > 0 and open then
                local new_slot = slots[highlighted]
                update_context_buttons(pid, new_slot)

                -- start context sync
                send_context(pid, highlighted)

                -- reposition and display context menu frame
                if GetLocalPlayer() == Player(pid - 1) then
                    frame_set_visible(context_menu_backdrop, true)
                    frame_clear_all_points(context_menu_backdrop)
                    BlzFrameSetPoint(context_menu_backdrop, FRAMEPOINT_TOPLEFT, new_slot.frame, FRAMEPOINT_TOPRIGHT, 0.005, 0.)
                    for _, v in ipairs(slots) do
                        v.tooltip:visible(false)
                    end
                end
            else
            -- close context menu
                -- toggle normal mode
                ui_mode[pid] = 0

                -- hide context menu frame
                if GetLocalPlayer() == Player(pid - 1) then
                    frame_set_visible(context_menu_backdrop, false)
                    for _, v in ipairs(slots) do
                        v.tooltip:visible(true)
                    end
                end
            end
        end

        local function on_context_sync()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local data = BlzGetTriggerSyncData()
            local slot_s = string.match(data, "(%d+)")
            local slot = tonumber(slot_s)
            --print("context:",slot_s)

            -- update context and flag as synced
            context[pid] = slot
            synced_context[pid] = true

            local pc = pending_click[pid]
            if pc then
                context_functions[pc](pid, slot)
                clear_context(pid)
            end

            return false
        end

        local function on_target_sync()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local data = BlzGetTriggerSyncData()
            local slot_s = string.match(data, "(%-?%d+)")
            local slot = tonumber(slot_s)
            --print("target:", slot_s)

            -- update target and flag as synced
            target[pid] = slot
            synced_target[pid] = true

            -- resume any threads yielding for target
            if target_thread[pid] then
                coroutine.resume(target_thread[pid], slot)
            end

            return false
        end

        -- paint a slot from an item (or hide if nil)
        local function apply_item_visual(slot_btn, itm)
            if not itm then
                update_socket_tooltips(slot_btn.tooltip)
                slot_btn:visible(false)
                return
            end
            local icon = BlzGetItemIconPath(itm.obj)
            slot_btn:icon(icon)
            slot_btn.tooltip:icon(icon)
            slot_btn.tooltip:name(GetItemName(itm.obj))
            slot_btn.tooltip:text(BlzGetItemExtendedTooltip(itm.obj))
            update_socket_tooltips(slot_btn.tooltip, itm)
            slot_btn:charge(itm.charges)
            slot_btn:visible(true)
        end

        ---@param pid integer
        ---@param a integer
        ---@param b integer
        local function swap_slot_visuals(pid, a, b)
            if a == b then return end
            local items = Profile[pid].hero.items
            local itmA, itmB = items[a], items[b]

            if GetLocalPlayer() == Player(pid - 1) then
                apply_item_visual(slots[a], itmB)
                apply_item_visual(slots[b], itmA)
            end
        end

        ---@type fun(pid: integer, itm: Item, slot: integer, ignore: Item, show_error: boolean): boolean
        local function validate_item_move(pid, itm, slot, ignore, show_error)
            local valid, err = ValidateItemSlot(itm, slot, ignore)

            if not valid then
                if show_error and err then
                    local p = Player(pid - 1)
                    DisplayTimedTextToPlayer(p, 0, 0, 15., err)
                    SoundHandler("Sound\\Interface\\Error.wav", false, p)
                end

                return false
            end

            return true
        end

        local confirm_item = function(pid)
            target_thread[pid] = coroutine.create(function()
                local hero = Profile[pid].hero
                local itm = hero.items[context[pid]]
                local itm2 = hero.items[target[pid]]
                local slot = get_hovered_slot() -- not sync safe
                local valid = false

                -- async visual swap
                if itm and slot > 0 then
                    itm2 = hero.items[slot]

                    local dragged_from_backpack = context[pid] >= BACKPACK_INDEX
                    local target_is_equipped_slot = slot < BACKPACK_INDEX
                    local target_has_item = itm2 ~= nil

                    if itm ~= itm2 then
                        if dragged_from_backpack and target_is_equipped_slot then
                            if target_has_item then
                                -- backpack -> occupied equipped slot
                                -- occupant leaves first, so ignore it
                                valid = validate_item_move(pid, itm2, context[pid], itm, false)

                                if valid then
                                    valid = validate_item_move(pid, itm, slot, itm2, true)
                                end
                            else
                                -- backpack -> empty equipped slot
                                -- no occupant leaves, so do NOT ignore anything
                                valid = validate_item_move(pid, itm, slot, nil, true)
                            end
                        else
                            valid = validate_item_move(pid, itm, slot, itm2, true)

                            if itm2 and valid then
                                valid = validate_item_move(pid, itm2, context[pid], itm, false)
                            end
                        end

                        if valid then
                            swap_slot_visuals(pid, context[pid], slot)
                        end
                    end
                end

                hide_tracker(pid)
                PauseMouseTracker(pid)

                -- start target sync
                send_target(pid, slot)

                -- yield for target sync
                slot = coroutine.yield()

                -- check for syncs (extra safe)
                if synced_context[pid] and synced_target[pid] then
                    itm = hero.items[context[pid]]

                    if slot == -1 then -- negative indicates bailed out of menu
                        if itm then
                            hero.item_to_drop = itm
                            IssuePointOrder(itm.holder, DROP_ITEM_COMMAND, GetMouseX(pid), GetMouseY(pid))
                        end
                    elseif slot > 0 and itm then
                        InventoryService.move(pid, context[pid], slot)
                    end
                end

                -- final cleanup
                clear_context(pid)
                thistype.refresh(pid)

                -- short cooldown to prevent spam
                move_item_cooldown[pid] = true
                TimerQueue:callDelayed(0.05, reset_cooldown, pid)

                target_thread[pid] = nil -- Clear coroutine reference
            end)

            coroutine.resume(target_thread[pid])
        end

        -- mouse events
        on_m2_up = function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1

            if not disabled_for_player[pid] then
                open_context_menu(pid, true)
            end
        end

        on_m2_down = function()
        end

        on_m1_down = function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1

            if ui_mode[pid] == 0 then
                if not disabled_for_player[pid] and not move_item_cooldown[pid] then
                    pick_item(pid)
                end
            end

            if ui_mode[pid] == 1 then
                -- close context menu if either of these frames are not visible, because mouse is outside
                if not BlzFrameIsVisible(cost_frame) and not BlzFrameIsVisible(transparent_placeholder) then
                    open_context_menu(pid, false)
                    clear_context(pid)
                end
            end
        end

        on_m1_up = function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1

            if ui_mode[pid] == 0 then
                if not disabled_for_player[pid] then
                    confirm_item(pid)
                end
            end
        end

        local function on_cleanup(pid)
            thistype.close(pid)
        end

        -- assign a prefix and function for BlzSendSyncData calls
        SyncCallback("context", on_context_sync)
        SyncCallback("target", on_target_sync)

        local U = User.first
        while U do
            EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
            U = U.next
        end

        -- hold alt for extended item tooltips
        local function extended_item_tooltip(pid, is_down)
            if alt_down[pid] ~= is_down then
                alt_down[pid] = is_down

                local target_pid = viewing[pid]
                if target_pid and target_pid > 0 then
                    thistype.refresh(target_pid)
                end
            end
        end

        RegisterHotkeyToFunc('ALT', nil, extended_item_tooltip, nil, true)
        RegisterHotkeyToFunc('ALT+ALT', nil, extended_item_tooltip, nil, true)

        -- slot initialization
        do
            local parent_table = {
                ["main"] = inv[0],
                ["potion1"] = pot[1],
                ["potion2"] = pot[2],
                -- unequip rows map to inv[1], inv[2], inv[3]
                ["unequip1"] = inv[1],
                ["unequip2"] = inv[2],
                ["unequip3"] = inv[3],
            }

            local function y_offset(kind)
                -- potions sit a hair higher in original code
                if kind == "potion1" or kind == "potion2" then
                    return -0.0032
                end
                return -0.0033
            end

            local function column_for(id, kind)
                if kind == "main" then
                    return id
                elseif kind == "potion1" or kind == "potion2" then
                    return 1
                else
                    -- flatten id to its position within the 18 unequip cells
                    -- unequip cells start at global index 9
                    local unequip_pos = id - 8 -- 1..18
                    return ((unequip_pos - 1) % 6) + 1
                end
            end

            for id, slot_meta in ipairs(inventory_slots) do
                local kind = slot_meta[3]

                local parent = parent_table[kind]
                local col    = column_for(id, kind)
                local offx   = 0.0032 + INVENTORY_GAPX * (col - 1)
                local offy   = y_offset(kind)

                slots[id] = Button.create(parent, INVENTORY_SLOT_SIZE, INVENTORY_SLOT_SIZE, offx, offy, false)
                slots[id].tooltip:enableAttachments()
                slots[id]:visible(false)
                slots[id].index = id

                slots[id].tooltip:point(FRAMEPOINT_TOPRIGHT)
            end
        end
    end

    RegisterItemChangedAction(INVENTORY.refresh)
end, Debug and Debug.getLine())
