--[[
    potion.lua

    Adds custom UI buttons and functionality to potions
]]

OnInit.final("Potion", function(Require)
    Require('Hotkeys')
    Require('ItemLookup')

    local potion_button = {} ---@type Button[]
    local icon_size = 0.032

    local backdrop = BlzCreateFrameByType("BACKDROP", "", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), "", 0)
    BlzFrameSetSize(backdrop, 0.001, 0.001)
    BlzFrameSetTexture(backdrop, "trans32.blp", 0, true)
    BlzFrameSetAbsPoint(backdrop, FRAMEPOINT_BOTTOM, 0.133, 0.194)
    BlzFrameSetEnable(backdrop, false)

    local use_potion_factory

    do
        ---@type fun(pot: Item)
        local potion_effect = function(pot)
            local fheal = pot:getValue(ITEM_FLAT_HEAL, 0)
            local fmana = pot:getValue(ITEM_FLAT_MANA, 0)
            local pheal = pot:getValue(ITEM_PERCENT_HEAL, 0)
            local pmana = pot:getValue(ITEM_PERCENT_MANA, 0)

            local heal = fheal + (0.01 * pheal * Unit[Hero[pot.pid]].hp)
            local mana = fmana + (0.01 * pmana * Unit[Hero[pot.pid]].mana)

            if heal > 0 then
                HP(Hero[pot.pid], Hero[pot.pid], heal, GetObjectName(pot.id))
            end

            if mana > 0 then
                MP(Hero[pot.pid], mana)
            end
        end

        local index = 1
        use_potion_factory = function()
            local capture_index = index

            local f = function(pid, is_down)
                local pot = Profile[pid].hero.items[POTION_INDEX + capture_index - 1]

                if is_down and pot and potion_button[capture_index].charges > 0 then
                    if potion_button[capture_index].cooldown_time[pid] <= 0 then
                        pot.charges = pot.charges - 1
                        if GetLocalPlayer() == Player(pid - 1) then
                            potion_button[capture_index]:charge(pot.charges)
                        end
                        potion_button[capture_index]:cooldown(1., pid)
                        potion_effect(pot)
                        INVENTORY.refresh(pid)
                    end
                end
            end

            index = index + 1

            return f
        end
    end

    local use_potion, use_potion2 = use_potion_factory(), use_potion_factory()
    local pot_func = {use_potion, use_potion2}

    local function on_click()
        local f = BlzGetTriggerFrame()
        local p = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1

        BlzFrameSetEnable(f, false)
        BlzFrameSetEnable(f, true)

        for i = 1, #potion_button do
            if f == potion_button[i].frame then
                pot_func[i](pid, true)
            end
        end

        return false
    end

    potion_button[1] = Button.create(backdrop, icon_size, icon_size, 0, 0, false)
    potion_button[1]:onClick(on_click)
    potion_button[1]:use_cooldowns()
    potion_button[1]:visible(false)
    RegisterHotkeyToFunc('3', "Use Potion 1", use_potion, potion_button[1].tooltip.nameFrame)

    potion_button[2] = Button.create(backdrop, icon_size, icon_size, icon_size, 0, false)
    potion_button[2]:onClick(on_click)
    potion_button[2]:use_cooldowns()
    potion_button[2]:visible(false)
    RegisterHotkeyToFunc('4', "Use Potion 2", use_potion2, potion_button[2].tooltip.nameFrame)

    local function on_cleanup(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            potion_button[1]:visible(false)
            potion_button[2]:visible(false)
        end
    end

    local function on_setup(pid)
        for i = POTION_INDEX, POTION_INDEX + 1 do
            local pot = Profile[pid].hero.items[i]
            local index = i - POTION_INDEX + 1

            if pot then
                if GetLocalPlayer() == Player(pid - 1) then
                    potion_button[index]:visible(true)
                    potion_button[index]:charge(pot.charges)
                    potion_button[index].tooltip:name(GetObjectName(pot.id) .. " '" .. GetHotkeyForFunc(pid, pot_func[index]) .. "'")
                    potion_button[index]:icon(BlzGetAbilityIcon(pot.id))
                    potion_button[index].tooltip:icon(BlzGetAbilityIcon(pot.id))
                    potion_button[index].tooltip:text(BlzGetItemExtendedTooltip(pot.obj))
                end
            else
                if GetLocalPlayer() == Player(pid - 1) then
                    potion_button[index]:visible(false)
                end
            end
        end
    end

    POTION = {}
    POTION.refresh = function(pid)
        on_setup(pid)
    end

    local U = User.first
    while U do
        EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
        EVENT_ON_SETUP:register_action(U.id, on_setup)
        U = U.next
    end

    local function confirm_refill_potions()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            local price = dw.data[0] ---@type Item 

            if ChargePlayer(pid, price, "Your potions have been refilled.") then
                for i = POTION_INDEX, POTION_INDEX + 1 do
                    local pot = Profile[pid].hero.items[i]

                    if pot then
                        pot.charges = pot:getValue(ITEM_CHARGES, 0)
                    end
                end
                INVENTORY.refresh(pid)
            end
            dw:destroy()
        end

        return false
    end

    ITEM_LOOKUP[FourCC('I00J')] = function(p, pid) -- refill potions
        local price = 0
        for i = POTION_INDEX, POTION_INDEX + 1 do
            local pot = Profile[pid].hero.items[i]

            if pot then
                price = price + ItemData[pot.id][ITEM_LEVEL_REQUIREMENT] ^ 2 + pot:getValue(ITEM_FLAT_HEAL, 0) * 0.5 + pot:getValue(ITEM_FLAT_MANA, 0) * 0.5
            end
        end

        price = math.floor(price)

        if price > 0 then
            local dw = DialogWindow.create(pid, "|cffffffffRefill potions for |r" .. price .. " |cffffffffgold?|r", confirm_refill_potions)

            dw:addButton("Yes", price)
            dw:display()
        end
    end

end, Debug and Debug.getLine())