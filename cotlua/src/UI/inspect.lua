--[[
    inspect.lua

    Adds custom UI buttons to inspect unit stats and player inventories
]]

OnInit.final("Inspect", function(Require)
    Require('Users')
    Require('Frames')
    Require('Events')

    local backdrop = BlzCreateFrameByType("BACKDROP", "", BlzGetOriginFrame(ORIGIN_FRAME_GAME_UI, 0), "", 0)
    BlzFrameSetSize(backdrop, 0.001, 0.001)
    BlzFrameSetTexture(backdrop, "trans32.blp", 0, true)
    BlzFrameSetAbsPoint(backdrop, FRAMEPOINT_BOTTOM, 0.518, 0.15)
    BlzFrameSetEnable(backdrop, false)

    local gap_x = 0.039
    local icon_size = 0.032
    local inspect_unit
    local inspect_inventory

    local function on_click()
        local f = BlzGetTriggerFrame()
        local p = GetTriggerPlayer()
        local pid = GetPlayerId(p) + 1
        local u = PLAYER_SELECTED_UNIT[pid]
        local tpid = GetPlayerId(GetOwningPlayer(u)) + 1

        BlzFrameSetEnable(f, false)
        BlzFrameSetEnable(f, true)

        if f == inspect_unit.frame then
            STAT_WINDOW.display(u, pid)
        elseif f == inspect_inventory.frame then
            INVENTORY.display(pid, tpid)
        end

        return false
    end

    inspect_unit = Button.create(backdrop, icon_size, icon_size, 0, 0, false)
    inspect_unit:icon("ReplaceableTextures\\WorldEditUI\\Editor-Random-Unit.blp")
    inspect_unit.tooltip:name("Inspect Unit 'Y'")
    inspect_unit.tooltip:icon("ReplaceableTextures\\WorldEditUI\\Editor-Random-Unit.blp")
    inspect_unit.tooltip:text("View the detailed stats of the currently selected unit.")
    inspect_unit:onClick(on_click)
    RegisterHotkeyTooltip(inspect_unit.tooltip.nameFrame, 6)

    inspect_inventory = Button.create(backdrop, icon_size, icon_size, gap_x, 0, false)
    inspect_inventory:icon("ReplaceableTextures\\WorldEditUI\\Editor-Random-Item.blp")
    inspect_inventory.tooltip:name("Inspect Inventory 'U'")
    inspect_inventory.tooltip:icon("ReplaceableTextures\\WorldEditUI\\Editor-Random-Item.blp")
    inspect_inventory.tooltip:text("View the inventory of the currently selected hero.")
    inspect_inventory:onClick(on_click)
    RegisterHotkeyTooltip(inspect_inventory.tooltip.nameFrame, 7)

    inspect_unit:visible(false)
    inspect_inventory:visible(false)

    local function on_select(pid, u)
        local tpid = GetPlayerId(GetOwningPlayer(u)) + 1

        if GetLocalPlayer() == Player(pid - 1) then
            inspect_inventory:visible((Hero[tpid] == u) or (Backpack[tpid] == u))
            inspect_unit:visible(BlzGetUnitBooleanField(u, UNIT_BF_IS_A_BUILDING) == false)
        end
    end

    local function on_cleanup(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            inspect_unit:visible(false)
            inspect_inventory:visible(false)
        end
    end

    local U = User.first
    while U do
        EVENT_ON_SELECT:register_action(U.id, on_select)
        EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
        U = U.next
    end

end, Debug and Debug.getLine())
