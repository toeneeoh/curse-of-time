OnInit.final("PlayerAbilityControls", function(Require)
    Require("Spells")

    IS_HERO_PANEL_ON = {} ---@type boolean[] 

    ---@return boolean
    local function HeroPanelClick()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            local id = pid * PLAYER_CAP + dw.data[index] ---@type integer 

            IS_HERO_PANEL_ON[id] = (not IS_HERO_PANEL_ON[id])
            ShowHeroPanel(GetTriggerPlayer(), Player(dw.data[index] - 1), IS_HERO_PANEL_ON[id])

            dw:destroy()
        end

        return false
    end

    ---@param pid integer
    local function DisplayHeroPanel(pid)
        local dw = DialogWindow.create(pid, "", HeroPanelClick) ---@type DialogWindow 
        local U  = User.first ---@type User 

        while U do
            if pid ~= U.id and Profile[U.id].playing then
                dw:addButton(U.nameColored, U.id)
            end

            U = U.next
        end

        dw:display()
    end

    -- Runs upon selecting a backpack
    ---@return boolean
    function BackpackSkinClick()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 
        
        if index ~= -1 then
            index = dw.data[index]
            if CosmeticTable[User[pid - 1].name][index] == 0 and not CosmeticTable.skins[index].public then
                DisplayTextToPlayer(GetTriggerPlayer(), 0, 0, CosmeticTable.skins[index].error)
            else
                Profile[pid]:skin(index)
            end

            dw:destroy()
        end

        return false
    end

    -- Displays backpack selection dialog
    ---@param pid integer
    function BackpackSkin(pid)
        local name = User[pid - 1].name
        local dw   = DialogWindow.create(pid, "Select Appearance", BackpackSkinClick) ---@type DialogWindow 

        for i, v in ipairs(CosmeticTable.skins) do
            local text = ((v.req and CosmeticTable[name][i] > 0) and "|cff00ff00" .. v.name .. "|r") or v.name

            if CosmeticTable[name][i] > 0 or v.public == true then
                dw:addButton(text, i)
            end
        end

        dw:display()
    end

    -- Runs upon selecting a cosmetic
    ---@return boolean
    function CosmeticButtonClick()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            CosmeticTable.cosmetics[dw.data[index]]:effect(pid)

            dw:destroy()
        end

        return false
    end

    -- Displays cosmetic selection dialog
    ---@param pid integer
    function DisplaySpecialEffects(pid)
        local name = User[pid - 1].name
        local dw   = DialogWindow.create(pid, "", CosmeticButtonClick) ---@type DialogWindow 

        for i, v in ipairs(CosmeticTable.cosmetics) do
            if CosmeticTable[name][i + DONATOR_AURA_OFFSET] > 0 then
                dw:addButton(v.name, i)
            end
        end

        dw:display()
    end

    local mouse_move = function(pid, x, y, x2, y2)
        if IS_M2_DOWN[pid] and IsUnitSelected(Hero[pid], Player(pid - 1)) then
            local dist = DistanceCoords(x, y, x2, y2)

            if dist >= 3 then
                local ug = CreateGroup()
                GroupEnumUnitsInRange(ug, x, y, 15.0, Condition(ishostile))

                local target = FirstOfGroup(ug)
                if not target then
                    IssuePointOrder(Hero[pid], "smart", x, y)
                elseif GetUnitCurrentOrder(Hero[pid]) ~= OrderId("attack") then
                    IssueTargetOrder(Hero[pid], "attack", target)
                end

                DestroyGroup(ug)
            end
        end
    end

    local function unselect_bp(pid)
        local p = Player(pid - 1)

        if IsUnitSelected(Hero[pid], p) and IsUnitSelected(Backpack[pid], p) then
            if GetLocalPlayer() == p then
                SelectUnit(Backpack[pid], false)
            end
        end
    end

    DMG_NUMBERS = __jarray(0) ---@type integer[] 

    -- fairly simple spells
    UNIT_SPELLS = {
        [FourCC('A00I')] = function(_, pid) -- change hotkeys
            ChangeHotkeys(pid)
        end,

        [FourCC('A00Y')] = function(_, pid) -- Item drop toggle
            if IS_ITEM_DROP[pid] then
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, "Toggled Item Drops off.")
            else
                DisplayTimedTextToPlayer(Player(pid - 1), 0, 0, 10, "Toggled Item Drops on")
            end

            IS_ITEM_DROP[pid] = not IS_ITEM_DROP[pid]
        end,

        [FourCC('A00B')] = function(_, pid) -- Movement Toggle
            if EVENT_ON_MOUSE_MOVE:register_action(pid, mouse_move) then
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Movement Toggle enabled.")
            else
                EVENT_ON_MOUSE_MOVE:unregister_action(pid, mouse_move)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Movement Toggle disabled.")
            end
        end,

        [FourCC('A02T')] = function(_, pid) -- Hero Panels
            DisplayHeroPanel(pid)
        end,

        [FourCC('A031')] = function(_, pid) -- Damage Numbers
            if DMG_NUMBERS[pid] == 0 then
                DMG_NUMBERS[pid] = 1
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Damage Numbers for allied damage received disabled.")
            elseif DMG_NUMBERS[pid] == 1 then
                DMG_NUMBERS[pid] = 2
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Damage Numbers for all damage disabled.")
            else
                DMG_NUMBERS[pid] = 0
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Damage Numbers enabled.")
            end
        end,

        [FourCC('A067')] = function(_, pid) -- Deselect Backpack
            if EVENT_ON_SELECT:register_action(pid, unselect_bp) then
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Deselect Backpack enabled.")
            else
                EVENT_ON_SELECT:unregister_action(pid, unselect_bp)
                DisplayTextToPlayer(Player(pid - 1), 0, 0, "Deselect Backpack disabled.")
            end
        end,
        [FourCC('A0KX')] = function(_, pid) -- Change Skin
            BackpackSkin(pid)
        end,

        [FourCC('A04N')] = function(_, pid) -- Special Effects
            DisplaySpecialEffects(pid)
        end,
    }
end, Debug and Debug.getLine())


