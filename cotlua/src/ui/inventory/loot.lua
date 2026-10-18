-- Fixed 12x6 companion panel. Pages and selection are presentation only;
-- requests identify a frozen record/revision, never a visible slot index.
OnInit.final("LootUI", function(Require)
    Require('LootService')
    Require('Inventory')
    Require('StashUI')
    Require('Gluebutton')
    Require('SimpleButton')
    Require('ItemDetails')
    Require('Mouse')
    Require('Events')
    LootUI = {}
    local UI, views, slots = LootUI, {}, {}
    local WIDTH, HEIGHT, ROW_WIDTH, SIZE = .4682, .232, .1981, .0266
    local HIGHLIGHT_RATIO = SIZE / .0375 -- shop selection border, scaled to these slots
    local HIGHLIGHT_GROWTH = 1.04
    local HIGHLIGHT_CENTER = SIZE * (HIGHLIGHT_GROWTH - 1.) / 2.
    local highlighted
    local LEFT, TOP, PAGE_SIZE = .575 - .006 - WIDTH, .408, 72
    local frame = BlzCreateFrame("ListBoxWar3", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    BlzFrameSetPoint(frame, FRAMEPOINT_TOPRIGHT, INVENTORY.frame, FRAMEPOINT_TOPLEFT, -.006, 0.)
    BlzFrameSetSize(frame, WIDTH, HEIGHT)
    BlzFrameSetEnable(frame, false)
    BlzFrameSetVisible(frame, false)
    local title = BlzCreateFrame("TitleText", frame, 0, 0)
    BlzFrameSetPoint(title, FRAMEPOINT_TOP, frame, FRAMEPOINT_TOP, 0., -.013)
    BlzFrameSetText(title, "ITEM BUNDLE")
    BlzFrameSetEnable(title, false)
    local function local_pid() return GetPlayerId(GetLocalPlayer()) + 1 end
    local function release()
        if GetLocalPlayer() == GetTriggerPlayer() then
            local f = BlzGetTriggerFrame(); BlzFrameSetEnable(f, false); BlzFrameSetEnable(f, true)
        end
    end
    function UI.isOpen(pid) return views[pid] ~= nil end
    function UI.close(pid)
        views[pid] = nil
        if GetLocalPlayer() == Player(pid - 1) then BlzFrameSetVisible(frame, false) end
    end
    function UI.containsLocalPoint()
        if not views[local_pid()] then return false end
        local x, y = BlzPixelToFrameX(BlzGetMouseScreenPosX()), BlzPixelToFrameY(BlzGetMouseScreenPosY())
        return x >= LEFT and x <= LEFT + WIDTH and y <= TOP and y >= TOP - HEIGHT
    end
    local function request(action)
        release()
        if GetLocalPlayer() ~= GetTriggerPlayer() then return false end
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local view = views[pid]
        -- Capture the identity/revision actually shown when the entry was
        -- selected. A refresh never silently retargets an action to new loot.
        if view and view.selected then
            BlzSendSyncData("loot_action", string.format("%s:%d:%d:%d", action, view.pile, view.selected, view.revision))
        end
        return false
    end
    for row = 1, 6 do
        -- Each asset contains six slots. Tile at the stash's native dimensions.
        local backgrounds = {}
        for half = 1, 2 do
            local background = BlzCreateFrameByType("BACKDROP", "", frame, "", 0)
            BlzFrameSetPoint(background, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT,
                .02 + ROW_WIDTH * (half - 1), -.036 - .0312 * (row - 1))
            BlzFrameSetSize(background, ROW_WIDTH, .0312)
            BlzFrameSetTexture(background, "inventory_row.tga", 0, false)
            BlzFrameSetEnable(background, false)
            backgrounds[half] = background
        end
        for column = 1, 12 do
            local index = (row - 1) * 12 + column
            local button = Button.create(backgrounds[math.ceil(column / 6)], SIZE, SIZE,
                .0032 + ROW_WIDTH / 6 * ((column - 1) % 6), -.0023, false)
            button.rarityBorder = BlzCreateFrameByType("BACKDROP", "", button.iconFrame, "", 0)
            BlzFrameSetAllPoints(button.rarityBorder, button.iconFrame)
            BlzFrameSetEnable(button.rarityBorder, false)
            BlzFrameSetLevel(button.rarityBorder, 1)
            BlzFrameSetLevel(button.chargeFrame, 2)
            -- A high sprite level inside the lower button subtree can still
            -- sit under rarity. Make the selection a higher sibling instead.
            BlzFrameSetParent(button.displayFrame, button.iconFrame)
            BlzFrameSetLevel(button.displayFrame, 3)
            BlzFrameSetEnable(button.displayFrame, false)
            button.tooltip:enableAttachments()
            -- This panel extends left; keep detailed tooltips toward inventory.
            button.tooltip:point(FRAMEPOINT_TOPRIGHT)
            button:visible(false)
            button:onClick(function()
                release()
                if GetLocalPlayer() ~= GetTriggerPlayer() then return false end
                local pid = GetPlayerId(GetTriggerPlayer()) + 1
                local view = views[pid]
                local value = view and view.shown[index]
                if value then
                    view.double_candidate = view.selected == value.id and view.revision == value.revision
                    view.selected, view.revision = value.id, value.revision
                    UI.refresh(pid)
                end
                return false
            end)
            button:onDoubleClick(function()
                local view = views[GetPlayerId(GetTriggerPlayer()) + 1]
                if not view or not view.double_candidate then release(); return false end
                return request("take")
            end)
            slots[index] = button
        end
    end
    SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", .018, .018,
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -.02, -.02, function()
            UI.close(GetPlayerId(GetTriggerPlayer()) + 1); return false
        end, "Close Loot", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., .01)
    local take = SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp", .029, .029,
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -.016, -.06, function() return request("take") end,
        "Take selected item (or double-click it)")
    SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNScrollOfTownPortal.blp", .029, .029,
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -.016, -.10, function()
            if GetLocalPlayer() ~= GetTriggerPlayer() then return false end
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local view = views[pid]
            local entry = view and view.selected and LootService.getEntry(view.selected)
            if entry and entry.pile.id == view.pile then
                local info = entry.item:info(pid)
                ItemDetails.show(pid, info.name, info.icon, info.description)
            end
            return false
        end, "Inspect selected item")
    local function page(delta)
        return function()
            if GetLocalPlayer() ~= GetTriggerPlayer() then return false end
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            local view = views[pid]
            if view then view.page = math.max(1, view.page + delta); view.selected = nil; UI.refresh(pid) end
            return false
        end
    end
    local previous = SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCycleLeft.blp", .02, .02,
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -.030, -.19, page(-1), "Previous page")
    local next_page = SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCycleRight.blp", .02, .02,
        FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -.006, -.19, page(1), "Next page")
    function UI.refresh(pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local view = views[pid]
        if not view then return end
        local pile = LootService.getPile(view.pile)
        if not pile then UI.close(pid); return end
        local pages = math.max(1, math.ceil(#pile.entries / PAGE_SIZE))
        view.page = math.min(view.page, pages); view.shown = {}
        local selected = view.selected and LootService.getEntry(view.selected)
        if not selected or selected.pile ~= pile or selected.revision ~= view.revision then
            view.selected, selected = nil, nil
        end
        local next_highlight
        for index, button in ipairs(slots) do
            local entry = pile.entries[(view.page - 1) * PAGE_SIZE + index]
            INVENTORY.renderItemButton(button, entry and entry.item, pid)
            if entry and entry.id == view.selected then next_highlight = button end
            button:available(not entry or not entry.item.owner or entry.item.owner == Player(pid - 1))
            if entry then
                view.shown[index] = {id = entry.id, revision = entry.revision}
                local bound = entry.item.owner
                local status = bound and (bound == Player(pid - 1) and "|cff40bf5fBound to you|r" or "|cffff5555Bound to another player|r") or "Unbound"
                button.tooltip:text((entry.item.alt_tooltip or entry.item.tooltip or "") .. "|n" .. status)
            end
        end
        if highlighted ~= next_highlight then
            if highlighted then highlighted:display(nil, 0, 0, 0, nil, nil, 0, 0) end
            highlighted = next_highlight
            if highlighted then
                highlighted:display("blue_energy_sprite.mdx", .00001, .00001, .675 * HIGHLIGHT_RATIO * HIGHLIGHT_GROWTH,
                    FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_BOTTOMLEFT,
                    -.0052 * HIGHLIGHT_RATIO - HIGHLIGHT_CENTER, -.0048 * HIGHLIGHT_RATIO - HIGHLIGHT_CENTER)
            end
        end
        take:enable(selected ~= nil and (not selected.item.owner or selected.item.owner == Player(pid - 1)))
        previous:enable(view.page > 1); next_page:enable(view.page < pages)
    end
    function UI.open(pid, pile)
        if not Hero[pid] or not Profile[pid] or not Profile[pid].playing then return end
        if not IsVisibleToPlayer(pile.x, pile.y, Player(pid - 1)) then return end
        StashUI.close(pid)
        INVENTORY.open(pid, pid) -- synchronized selection callback, including native refresh
        views[pid] = {pile = pile.id, page = 1, shown = {}}
        if GetLocalPlayer() == Player(pid - 1) then BlzFrameSetVisible(frame, true) end
        UI.refresh(pid)
    end
    RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_SELECTED, function()
        local pile = LootService.forUnit(GetTriggerUnit())
        if not pile then return end
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        UI.open(pid, pile)
        -- Native selection events, rather than local UI queries, update the
        -- map's selection history when control is returned to the hero.
        if Hero[pid] then SelectUnitForPlayerSingle(Hero[pid], Player(pid - 1)) end
    end)
    LootService.registerChanged(function(pile_id)
        local pid = local_pid()
        if views[pid] and views[pid].pile == pile_id then UI.refresh(pid) end
    end)
    for pid = 1, PLAYER_CAP do EVENT_ON_CLEANUP:register_action(pid, function() UI.close(pid) end) end
    AddToEsc(UI.close)
end, Debug and Debug.getLine())
