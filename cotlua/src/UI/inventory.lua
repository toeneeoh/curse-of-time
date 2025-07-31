--[[
    inventory.lua

    A library for recreating an inventory system using custom frames
]]
OnInit.final("Inventory", function(Require)
    Require('Users')
    Require('Frames')
    Require('Currency')

    local INVENTORY_WIDTH   = 0.1981
    local INVENTORY_GAPY    = 0.0312
    local INVENTORY_GAPX    = 0.0333
    local INVENTORY_TEXTURE = "inventory_row.tga"
    local POTION_TEXTURE    = "war3mapImported\\PotionBackdrop2.dds"
    local min_x     = 0.612
    local min_y     = 0.214
    local icon_size = 0.0266
    local FPS_32    = FPS_32

    local inventory_slots = {
        {0.0000, 0.1248},
        {0.0333, 0.1248},
        {0.0666, 0.1248},
        {0.0999, 0.1248},
        {0.1332, 0.1248},
        {0.1665, 0.1248},
        {0.2048, 0.1248}, -- POTION 1
        {0.2048, 0.0936}, -- POTION 2
        {0.0000, 0.0624},
        {0.0333, 0.0624},
        {0.0666, 0.0624},
        {0.0999, 0.0624},
        {0.1332, 0.0624},
        {0.1665, 0.0624},
        {0.0000, 0.0312},
        {0.0333, 0.0312},
        {0.0666, 0.0312},
        {0.0999, 0.0312},
        {0.1332, 0.0312},
        {0.1665, 0.0312},
        {0.0000, 0.0},
        {0.0333, 0.0},
        {0.0666, 0.0},
        {0.0999, 0.0},
        {0.1332, 0.0},
        {0.1665, 0.0},
    }

    local disabled_for_player = {}

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
        local threads = {} -- Tracks coroutine per player

        -- determines what item slot a user is highlighting
        ---@return integer
        local get_highlighted_slot = function(pid)
            local index = 0

            for i = 1, MAX_INVENTORY_SLOTS do
                if BlzFrameIsVisible(slots[i].tooltip.iconFrame) then
                    index = slots[i].index
                    break
                end
            end

            -- eventually syncs to context variable
            if GetLocalPlayer() == Player(pid - 1) then
                BlzSendSyncData("context", tostring(index))
            end

            return index
        end

        -- determines what item slot a user has their cursor over
        ---@return number, number, integer
        local get_hovered_slot = function(pid)
            local mouse_x = GetMouseFrameXStable() - min_x
            local mouse_y = GetMouseFrameYStable() - min_y
            local closest_slot = 0
            local closest_distance = 1000

            -- loop through each slot's position and calculate the distance to the mouse
            for i, pos in ipairs(inventory_slots) do
                local dx = mouse_x - pos[1]
                local dy = mouse_y - pos[2]
                local distance = math.sqrt(dx * dx + dy * dy)

                -- check if this slot is the closest
                if distance < closest_distance then
                    closest_distance = distance
                    closest_slot = i
                end
            end

            -- define a threshold distance to ensure the mouse is reasonably close to a slot
            local threshold_distance = 0.025

            if closest_distance > threshold_distance then
                closest_slot = 0
            end

            -- eventually syncs to target variable
            if GetLocalPlayer() == Player(pid - 1) then
                BlzSendSyncData("target", tostring(closest_slot) .. " " .. mouse_x .. " " .. mouse_y)
            end

            return mouse_x, mouse_y, closest_slot
        end

        -- frame setup
        local frame = BlzCreateFrame("ListBoxWar3", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
        BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPLEFT, 0.575, 0.41)
        BlzFrameSetSize(frame, INVENTORY_WIDTH + 0.072, 0.232)
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
            BlzFrameSetPoint(inv[i], FRAMEPOINT_TOPLEFT, inv[i - 1], FRAMEPOINT_BOTTOMLEFT, 0., (i == 1 and -icon_size) or 0.)
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

        BlzFrameSetVisible(frame, false)

        -- context menu setup
        local context_menu_backdrop = BlzCreateFrameByType("FRAME", "", frame, "", 0)
        BlzFrameSetTexture(context_menu_backdrop, "trans32.blp", 0, true)
        BlzFrameSetSize(context_menu_backdrop, 0.001, 0.001)
        BlzFrameSetEnable(context_menu_backdrop, false)
        BlzFrameSetVisible(context_menu_backdrop, false)
        local context_width = 0.055
        local context_height = 0.016
        local context_buttons = {}
        context_buttons[1] = SimpleButton.create(context_menu_backdrop, "inventorymenubuttons.dds", context_width, context_height, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0, 0)
        context_buttons[2] = SimpleButton.create(context_menu_backdrop, "inventorymenubuttons.dds", context_width, context_height, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0, 0)
        context_buttons[3] = SimpleButton.create(context_menu_backdrop, "inventorymenubuttons.dds", context_width, context_height, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0, 0)
        context_buttons[4] = SimpleButton.create(context_menu_backdrop, "inventorymenubuttons.dds", context_width, context_height, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0, 0)
        context_buttons[5] = SimpleButton.create(context_menu_backdrop, "inventorymenubuttons.dds", context_width, context_height, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0, 0)
        context_buttons[1]:text("Equip")
        context_buttons[2]:text("Unequip")
        context_buttons[3]:text("Drop")
        context_buttons[4]:text("Sell")
        context_buttons[5]:text("Details")
        local cost_frame = BlzCreateFrameByType("FRAME", "", context_buttons[4].frame, "", 0)
        BlzFrameSetSize(cost_frame, 0.001, 0.001)
        BlzFrameSetEnable(cost_frame, false)
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
        BlzFrameSetVisible(cost_frame, false)
        BlzFrameSetTooltip(context_buttons[4].frame, cost_frame)

        local context_functions = {
            function(pid) -- EQUIP
                if context[pid] > 0 then
                    local itm = Profile[pid].hero.items[context[pid]]

                    if itm then
                        itm:equip()
                    end
                    open_context_menu(pid, false)
                end
            end,
            function(pid) -- UNEQUIP
                if context[pid] > 0 then
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
                        local itm = items[context[pid]]
                        if itm then
                            itm:equip(index)
                        end
                    end
                    open_context_menu(pid, false)
                end
            end,
            function(pid) -- DROP
                if context[pid] > 0 then
                    local hero = Profile[pid].hero
                    local itm = hero.items[context[pid]]

                    if itm then
                        hero.item_to_drop = itm
                        IssuePointOrder(itm.holder, "robogoblin", GetUnitX(Hero[pid]), GetUnitY(Hero[pid]))
                    end
                    open_context_menu(pid, false)
                end
            end,
            function(pid) -- SELL
                if context[pid] > 0 then
                    local itm = Profile[pid].hero.items[context[pid]]
                    if itm then
                        SoundHandler("Abilities\\Spells\\Items\\ResourceItems\\ReceiveGold.flac", true, Player(pid - 1), itm.holder)
                        local _, gold, plat = GetItemSellPrice(itm)
                        AddCurrency(pid, GOLD, gold)
                        AddCurrency(pid, PLATINUM, plat)

                        itm:destroy(nil, nil, true)
                    end
                    open_context_menu(pid, false)
                end
            end,
            function(pid) -- DETAILS
                if context[pid] > 0 then
                    local itm = Profile[viewing[pid]].hero.items[context[pid]]
                    if itm then
                        itm:info(pid)
                    end
                    open_context_menu(pid, false)
                end
            end,
        }
        local on_context_push = function()
            local p = GetTriggerPlayer()
            local pid = GetPlayerId(p) + 1
            local f = BlzGetTriggerFrame()

            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)

            for i = 1, #context_buttons do
                local button = context_buttons[i]

                if button.frame == f then
                    context_functions[i](pid)
                    break
                end
            end

            return false
        end

        for i = 1, #context_buttons do
            context_buttons[i]:onClick(on_context_push)
        end

        local setabspoint = BlzFrameSetAbsPoint

        -- frame that follows the mouse (for item dragging)
        local tracker = BlzCreateFrameByType("BACKDROP", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
        BlzFrameSetEnable(tracker, false)
        BlzFrameSetSize(tracker, icon_size, icon_size)
        BlzFrameSetTexture(tracker, "trans32.blp", 0, true)
        -- BlzFrameSetVisible(tracker, true)
        -- BlzFrameSetLevel(tracker, 5)

        local count = 0
        local check_tracker = function()
            return count == 0
        end
        local update_tracker = function()
            setabspoint(tracker, FRAMEPOINT_CENTER, GetMouseFrameXStable(), GetMouseFrameYStable())
        end
        local hide_tracker = function(pid)
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetTexture(tracker, "trans32.blp", 0, true)
            end
        end

        INVENTORY.open = function(pid, tpid)
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetVisible(frame, true)
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
                TimerQueue:callPeriodically(FPS_32, check_tracker, update_tracker)
            end
        end

        INVENTORY.close = function(pid)
            if viewing[pid] ~= -1 then
                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetVisible(frame, false)
                end
                viewing[pid] = -1
                EVENT_ON_M1_DOWN:unregister_action(pid, on_m1_down)
                EVENT_ON_M1_UP:unregister_action(pid, on_m1_up)
                EVENT_ON_M2_DOWN:unregister_action(pid, on_m2_down)
                EVENT_ON_M2_UP:unregister_action(pid, on_m2_up)

                count = math.max(0, count - 1)
                context[pid] = 0
                target[pid] = 0
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

        INVENTORY.refresh = function(pid)
            POTION.refresh(pid)

            local U = User.first
            local items = Profile[pid].hero.items
            local players = {}
            while U do
                -- refresh for every player viewing the inventory
                if viewing[U.id] == pid then
                    players[#players + 1] = U.player
                end
                U = U.next
            end

            if TableHas(players, GetLocalPlayer()) then
                for i = 1, MAX_INVENTORY_SLOTS do
                    local itm = items[i]

                    if itm then
                        slots[i]:icon(BlzGetItemIconPath(itm.obj))
                        slots[i].tooltip:icon(BlzGetItemIconPath(itm.obj))
                        slots[i].tooltip:name(GetItemName(itm.obj))
                        slots[i].tooltip:text(BlzGetItemExtendedTooltip(itm.obj))
                        slots[i].tooltip:text(BlzGetItemExtendedTooltip(itm.obj))
                        slots[i]:visible(true)
                        slots[i]:charge(itm.charges)
                    else
                        slots[i]:visible(false)
                    end
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

        local pick_item = function(pid)
            local highlighted = get_highlighted_slot(pid)

            if highlighted > 0 then
                local new_slot = slots[highlighted]

                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetTexture(tracker, new_slot.texture, 0, true)
                    new_slot:visible(false)
                end

                local xPos = min_x - 0.4 + inventory_slots[new_slot.index][1]
                local yPos = min_y - 0.3 + inventory_slots[new_slot.index][2]
                StartMouseTracker(pid, xPos, yPos)
            end
        end

        local reset_cooldown = function(pid)
            move_item_cooldown[pid] = false
        end

        local function update_context_buttons(pid, slot)
            local items = Profile[pid].hero.items

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
                    local type = ItemData[items[slot.index].id][ITEM_TYPE]
                    for i = 1, BACKPACK_INDEX - 1 do
                        if items[i] == nil and VerifySlotForType(i, type) then
                            visible_buttons[#visible_buttons + 1] = 1 -- EQUIP
                            break
                        end
                    end
                end

                -- always allow dropping items
                visible_buttons[#visible_buttons + 1] = 3

                -- selling logic
                local total, gold, plat = GetItemSellPrice(items[slot.index])
                if RectContainsUnit(gg_rct_Town_Main, Hero[pid]) and total > 0 then
                    visible_buttons[#visible_buttons + 1] = 4
                    if GetLocalPlayer() == Player(pid - 1) then
                        BlzFrameSetText(cost_text, string.format("\x2501d", gold))
                        BlzFrameSetVisible(cost_icon2, false)
                        if plat > 0 then
                            BlzFrameSetVisible(cost_icon2, true)
                            BlzFrameSetText(cost_text2, string.format("\x2501d", plat))
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
                    BlzFrameClearAllPoints(button.frame) -- Clear previous attachment
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
            context[pid] = 0
            target[pid] = 0
            -- disable m1
            EVENT_ON_M1_DOWN:unregister_action(pid, on_m1_down)
            EVENT_ON_M1_UP:unregister_action(pid, on_m1_up)

            -- get context
            local highlighted = get_highlighted_slot(pid)

            -- open the menu
            if highlighted > 0 and open then
                local new_slot = slots[highlighted]
                update_context_buttons(pid, new_slot)

                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetVisible(context_menu_backdrop, true)
                    BlzFrameClearAllPoints(context_menu_backdrop)
                    BlzFrameSetPoint(context_menu_backdrop, FRAMEPOINT_TOPLEFT, new_slot.frame, FRAMEPOINT_TOPRIGHT, 0.005, 0.)
                    for _, v in ipairs(slots) do
                        v.tooltip:visible(false)
                    end
                end
            else
                -- reenable m1
                if pid == viewing[pid] then
                    EVENT_ON_M1_DOWN:register_action(pid, on_m1_down)
                    EVENT_ON_M1_UP:register_action(pid, on_m1_up)
                end
                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetVisible(context_menu_backdrop, false)
                    for _, v in ipairs(slots) do
                        v.tooltip:visible(true)
                    end
                end
            end
        end

        local function sync_context()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local data = BlzGetTriggerSyncData()
            context[pid] = tonumber(data)

            return false
        end

        local function sync_target()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local data = BlzGetTriggerSyncData()
            local index, x, y = string.match(data, "(\x25d+) (\x25-?[\x25d\x25.]+) (\x25-?[\x25d\x25.]+)")
            target[pid], x, y = tonumber(index), tonumber(x), tonumber(y)

            if threads[pid] then
                coroutine.resume(threads[pid], x, y)
            end

            return false
        end

        local function swap_slot_visuals(slot1, slot2)
            local texture1, texture2 = slot1.texture, slot2.texture
            local visible1, visible2 = slot1.isVisible, slot2.isVisible

            slot1:icon(texture2)
            slot2:icon(texture1)

            if not visible2 then
                slot1:visible(visible2)
            end
            if not visible1 then
                slot2:visible(visible1)
            end
        end

        local confirm_item = function(pid)
            if not context[pid] then
                return
            end

            local mouse_x, mouse_y = GetMouseX(pid), GetMouseY(pid)

            threads[pid] = coroutine.create(function()
                get_hovered_slot(pid) -- not sync safe
                local x, y = coroutine.yield() -- sync coords

                if x and x < -0.025 then -- drop
                    if context[pid] > 0 then
                        local hero = Profile[pid].hero
                        local itm = hero.items[context[pid]]

                        if itm then
                            hero.item_to_drop = itm
                            IssuePointOrder(itm.holder, "robogoblin", mouse_x, mouse_y)
                        end
                    end
                else
                    if context[pid] > 0 and target[pid] > 0 then
                        local items = Profile[pid].hero.items
                        local itm1 = items[context[pid]]
                        local itm2 = items[target[pid]]

                        if itm1:equip(target[pid]) then
                            if GetLocalPlayer() == Player(pid - 1) then
                                swap_slot_visuals(slots[context[pid]], slots[target[pid]])
                            end
                            if itm2 and itm1 ~= itm2 then -- if another item is there
                                if itm2:equip(context[pid]) then
                                    if GetLocalPlayer() == Player(pid - 1) then
                                        slots[target[pid]].tooltip:visible(true)
                                    end
                                end
                            end
                        end
                        open_context_menu(pid, false)
                    end
                end

                -- Final cleanup
                hide_tracker(pid)
                PauseMouseTracker(pid)
                context[pid] = 0
                target[pid] = 0
                INVENTORY.refresh(pid)

                -- Apply cooldown to prevent spam
                move_item_cooldown[pid] = true
                TimerQueue:callDelayed(0.1, reset_cooldown, pid)

                threads[pid] = nil -- Clear coroutine reference
            end)

            coroutine.resume(threads[pid])
        end

        -- mouse events
        on_m2_up = function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1

            if not disabled_for_player[pid] then
                open_context_menu(pid, true)
            end
        end

        on_m2_down = function()
            --local pid = GetPlayerId(GetTriggerPlayer()) + 1
        end

        on_m1_down = function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1

            if not disabled_for_player[pid] and not move_item_cooldown[pid] then
                pick_item(pid)
            end
        end

        on_m1_up = function()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1

            if not disabled_for_player[pid] then
                confirm_item(pid)
            end
        end

        local function on_cleanup(pid)
            thistype.close(pid)
        end

        SyncCallback("context", sync_context)
        SyncCallback("target", sync_target)

        local U = User.first
        while U do
            EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
            U = U.next
        end

        -- main equip slots
        for i = 1, 6 do
            slots[i] = Button.create(inv[0], icon_size, icon_size, 0.0032 + INVENTORY_GAPX * (i - 1), -0.0033, false)
            slots[i]:visible(false)
            slots[i].index = i
            if i > 3 then
                slots[i].tooltip:point(FRAMEPOINT_TOPRIGHT)
            end
        end

        -- unequip slots
        local index = BACKPACK_INDEX
        for j = 1, 3 do
            for i = 1, 6 do
                slots[index] = Button.create(inv[j], icon_size, icon_size, 0.0032 + INVENTORY_GAPX * (i - 1), -0.0033, false)
                slots[index]:visible(false)
                slots[index].index = index
                if i > 3 then
                    slots[index].tooltip:point(FRAMEPOINT_TOPRIGHT)
                end
                index = index + 1
            end
        end

        -- potions
        index = POTION_INDEX
        slots[index] = Button.create(pot[1], icon_size, icon_size, 0.0032, -0.0032, false)
        slots[index].tooltip:point(FRAMEPOINT_TOPRIGHT)
        slots[index]:visible(false)
        slots[index].index = index
        index = index + 1
        slots[index] = Button.create(pot[2], icon_size, icon_size, 0.0032, -0.0032, false)
        slots[index].tooltip:point(FRAMEPOINT_TOPRIGHT)
        slots[index]:visible(false)
        slots[index].index = index
    end
end, Debug and Debug.getLine())
