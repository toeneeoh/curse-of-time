-- Optional interface tour. Frame creation is synchronized; presentation is local.
OnInit.final("Tutorial", function(Require)
    Require('Hotkeys')
    Require('Frames')
    Require('Profile')
    Require('Inventory')
    Require('StashUI')
    Require('StatView')
    Require('PerkTree')
    Require('Multiboard')
    Require('Potion')
    Require('TimerQueue')
    Require('HeroSelect')
    Require('PlayerCamera')

    Tutorial = {}
    local states, ui = {}, {}
    local render

    local function key(pid, name, fallback)
        for _, action in ipairs(GetHotkeyTable()) do
            if action.name == name then
                return "|cffffcc00" .. (GetHotkeyForFunc(pid, action.func) or fallback) .. "|r"
            end
        end
        return "|cffffcc00" .. fallback .. "|r"
    end

    local function close_opened(pid, state)
        for name in pairs(state.previews) do
            ({inventory = INVENTORY, stash = StashUI, stats = STAT_WINDOW, perks = PerkTree})[name].previewTutorial(pid, false)
        end
        state.previews = {}
        if state.opened.stash then StashUI.close(pid) end
        if state.opened.inventory then INVENTORY.close(pid) end
        if state.opened.stats then STAT_WINDOW.close(pid) end
        if state.opened.perks then PerkTree.close(pid) end
        state.opened = {}
    end

    local function preview(pid, state, name, api, page)
        state.previews[name] = true
        api.previewTutorial(pid, true, page)
    end

    local function has_hero(pid)
        return Hero[pid] and Profile[pid] and Profile[pid].playing and not SELECTING_HERO[pid]
    end

    local function inventory(pid, state)
        if not has_hero(pid) then preview(pid, state, "inventory", INVENTORY); return end
        if not INVENTORY.isOpen(pid) then state.opened.inventory = true end
        INVENTORY.open(pid, pid)
    end

    local function stats(pid, state, page)
        if not has_hero(pid) then preview(pid, state, "stats", STAT_WINDOW, page); return end
        if not STAT_WINDOW.isOpen(pid) then state.opened.stats = true end
        STAT_WINDOW.showTutorial(pid, page)
    end

    local steps = {
        {
            title = "Inventory",
            text = function(pid)
                return "Press " .. key(pid, "View Inventory", "I") .. " to open your inventory. " ..
                    "The top row is your equipped gear; the rows below hold spare items. " ..
                    "Your six equipped items also appear in Warcraft's normal item slots. " ..
                    "Select your backpack unit for its travel and utility abilities."
            end,
            open = inventory,
            target = function() return INVENTORY.getTutorialFrame("equipment") end,
        },
        {
            title = "Item controls",
            text = function()
                return "Hover an item for its tooltip. Hold |cffffcc00Alt|r for more detail. " ..
                    "|cffffcc00Right-click|r for the context menu. " ..
                    "You can drag items between slots; use the custom inventory to rearrange your gear." ..
                    "Try moving the sword and flask."
            end,
            open = inventory,
            target = function() return INVENTORY.getTutorialFrame("backpack") end,
        },
        {
            title = "Potions",
            text = function(pid)
                return "Place flasks in the two potion slots beside your equipment. " ..
                    "Use them with " .. key(pid, "Use Potion 1", "3") .. " and " .. key(pid, "Use Potion 2", "4") ..
                    ", or click their HUD buttons. Flasks have charges and a cooldown; refill them in town."
            end,
            open = inventory,
            target = function() return INVENTORY.getTutorialFrame("potions") end,
        },
        {
            title = "Stash",
            text = function()
                return "The |cffffcc00vault button|r opens your saved stash beside the inventory. " ..
                    "In town, |cffffcc00Ctrl-click|r or drag items between the two windows. " ..
                    "You can inspect your stash anywhere, but moving items requires town. Buy more rows with the |cffffcc00+|r buttons."
            end,
            open = function(pid, state)
                inventory(pid, state)
                if not has_hero(pid) then preview(pid, state, "stash", StashUI); return end
                if not StashUI.isOpen(pid) then state.opened.stash = true end
                StashUI.open(pid)
            end,
            target = function() return INVENTORY.getTutorialFrame("stash") end,
        },
        {
            title = "Stat View",
            text = function(pid)
                return "Press " .. key(pid, "View Stats", "B") .. " to see your stats. " ..
                    "Hover the |cffffcc00question marks|r for calculation breakdowns. " ..
                    "Select another unit and press " .. key(pid, "Inspect Stats", "Y") .. " to inspect its stats."
            end,
            open = function(pid, state) stats(pid, state, 1) end,
            target = function() return STAT_WINDOW.getTutorialFrame() end,
        },
        {
            title = "Profile",
            text = function()
                return "The |cffffcc00Profile|r tab gathers your currencies, playtime, and progression information. " ..
                    "Use the tabs at the top of Stat View to switch between stats, profile, perks, honor, and faction information."
            end,
            open = function(pid, state) stats(pid, state, 2) end,
            target = function() return STAT_WINDOW.getTutorialFrame() end,
        },
        {
            title = "Perks",
            text = function()
                return "Use the |cffffcc00Perks|r tab and its perk-tree button to open the talent tree. " ..
                    "Hover nodes to read their effects. Drag the tree to pan, scroll to zoom, and use the button beside Close to fullscreen it."
            end,
            open = function(pid, state)
                if not has_hero(pid) then preview(pid, state, "perks", PerkTree); return end
                if not PerkTree.isOpen(pid) then
                    state.opened.perks = true
                    PerkTree.display(pid, pid)
                end
            end,
            target = function() return PerkTree.getTutorialFrame() end,
        },
        {
            title = "Factions",
            text = function()
                return "The |cffffcc00Faction|r tab shows your faction, rank, points, and progress. " ..
                    "Faction quest and event information is available through its faction view. "
            end,
            open = function(pid, state) stats(pid, state, 5) end,
            target = function() return STAT_WINDOW.getTutorialFrame() end,
        },
        {
            title = "Multiboard",
            text = function(pid)
                return "The upper-right board has player, queue, boss, and damage pages. " ..
                    "Use its arrow or " .. key(pid, "Next Multiboard", "/") .. " to cycle pages; " ..
                    key(pid, "Minimize Multiboard", ".") .. " minimizes it. " ..
                    "The boss page shows fight information and drop previews."
            end,
            target = function() return MULTIBOARD.main end,
        },
        {
            title = "Hotkeys and help",
            text = function(pid)
                return "Your current key bindings are shown throughout this tutorial. " ..
                    "Type |cffffcc00-hotkeys|r to change them. Press " .. key(pid, "Close Windows", "ESC") ..
                    " to close menus. |cffffcc00Menus|r opens the standard Warcraft menus; " ..
                    "|cffffcc00F9|r lists commands and help. " ..
                    "Type |cffffcc00-new|r any time to restart the tutorial."
            end,
            target = function() return GetTutorialMenuFrame() end,
        },
        {
            title = "The fountain",
            text = function()
                return "Ready to begin? The |cffffcc00Fountain of Hope|r in town restores health and mana nearby. " ..
                    "|cffffcc00Mark Location|r also pings it on your minimap."
            end,
            location = function() return -270., 320. end,
        },
        {
            title = "Your first kill quest",
            text = function()
                return "From the fountain, look southeast for the |cffffcc00Huntsman|r. " ..
                    "Select him and choose the |cffffcc00Troll|r kill quest. " ..
                    "Your quest tracker shows progress; return to the quest giver to collect your reward."
            end,
            location = function()
                if GetUnitTypeId(gg_unit_h036_0002) ~= 0 then
                    return GetUnitX(gg_unit_h036_0002), GetUnitY(gg_unit_h036_0002)
                end
                return 666.6, -543.
            end,
        },
        {
            title = "Starting trolls",
            text = function()
                return "The starting |cffffcc00Trolls|r are south of town. " ..
                    "Pick up the Troll kill quest before heading out. " ..
                    "Use |cffffcc00Mark Location|r to find their area on the minimap."
            end,
            location = function()
                return GetRectCenterX(gg_rct_Troll_Demon_1), GetRectCenterY(gg_rct_Troll_Demon_1)
            end,
        },
        {
            title = "Starting shops",
            text = function()
                return "The |cffffcc00General Merchant|r and |cffffcc00Magic Merchant|r are northeast of the fountain. " ..
                    "Select a merchant to browse its shop and categories. " ..
                    "You are ready to explore! You can repeat this tutorial with |cffffcc00-new|r."
            end,
            location = function()
                return GetUnitX(gg_unit_n01A_0092), GetUnitY(gg_unit_n01A_0092)
            end,
        },
    }

    function Tutorial.close(pid)
        local state = states[pid]
        if state then
            close_opened(pid, state)
            INVENTORY.clearTutorialPractice(pid)
            RestorePlayerCameraPreview(pid)
            if state.hero_select and SELECTING_HERO[pid] then StartHeroSelect(pid) end
        end
        states[pid] = nil
        if ui.frame and GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(ui.frame, false)
            BlzFrameSetVisible(ui.highlight, false)
        end
    end

    function Tutorial.finish(pid)
        if not states[pid] then return end
        local needs_hero = not has_hero(pid)
        Tutorial.close(pid)
        if needs_hero then
            if Profile[pid] then
                -- Resume the actual selection flow, not only its backdrop.
                -- This also restores selection mode after developer/repick paths.
                Profile[pid]:hero_select()
            else
                -- Keep the existing confirmation before creating/overwriting
                -- a profile; never manufacture a profile just for the tour.
                Profile.new(pid)
            end
        end
    end

    local function mark(pid, step)
        if GetLocalPlayer() == Player(pid - 1) and step.location then
            local x, y = step.location()
            PingMinimapEx(x, y, 6., 255, 204, 0, false)
        end
    end

    local function enter(pid, index)
        local state = states[pid]
        if not state then return end
        if index > #steps then Tutorial.finish(pid); return end
        close_opened(pid, state)
        state.index = math.max(0, index)
        local step = steps[state.index]
        if state.index > 0 and SELECTING_HERO[pid] then
            state.hero_select = true
            HideHeroSelect(pid)
        end
        if step and step.open then step.open(pid, state) end
        if step and step.location then
            local x, y = step.location()
            PreviewPlayerCamera(pid, MAIN_MAP.rect, x, y)
        else
            RestorePlayerCameraPreview(pid)
        end
        render(pid)
    end

    function Tutorial.prompt(pid)
        Tutorial.close(pid)
        if GetLocalPlayer() == Player(pid - 1) then ClearTextMessages() end
        states[pid] = {index = 0, opened = {}, previews = {}}
        render(pid)
    end

    render = function(pid)
        if not ui.frame or GetLocalPlayer() ~= Player(pid - 1) then return end
        local state = states[pid]
        if not state then return end
        local step = steps[state.index]
        -- Keep both side-by-side stash windows and the central perk tree clear.
        BlzFrameClearAllPoints(ui.frame)
        BlzFrameSetAbsPoint(ui.frame, FRAMEPOINT_TOPLEFT,
            state.index == 7 and 0.57 or 0.25,
            state.index == 4 and 0.60 or 0.44)
        BlzFrameSetVisible(ui.highlight, false)
        BlzFrameSetText(ui.title, "|cffffcc00Tutorial|r" .. (step and
            " - " .. state.index .. "/" .. #steps or ""))
        BlzFrameSetText(ui.heading, step and step.title or "Start the tutorial?")
        BlzFrameSetText(ui.body, step and step.text(pid) or
            "A short tour of the menus, buttons, and useful hotkeys, followed by directions to the starting area. " ..
            "You can go Back, Skip, or leave with Escape at any time. " ..
            (Hero[pid] and "" or "No hero yet? Use -new profile to create a profile, then choose a hero."))
        BlzFrameSetText(ui.next, state.index == 0 and "Start" or state.index == #steps and "Finish" or "Next")
        BlzFrameSetEnable(ui.back, state.index > 0)
        BlzFrameSetVisible(ui.mark, step and step.location ~= nil or false)
        if step and (step.target or step.location) then
            local target = step.target and step.target() or BlzGetOriginFrame(ORIGIN_FRAME_MINIMAP, 0)
            if target and BlzFrameIsVisible(target) then
                BlzFrameClearAllPoints(ui.highlight)
                BlzFrameSetAllPoints(ui.highlight, target)
                BlzFrameSetVisible(ui.highlight, true)
            end
        end
        BlzFrameSetVisible(ui.frame, true)
    end

    -- Defer construction until initial UI setup has completed, on every client.
    TimerQueue:callDelayed(0., function()
        INVENTORY.prepareTutorialPractice()
        local parent = BlzGetFrameByName("ConsoleUIBackdrop", 0)
        ui.frame = BlzCreateFrame("ListBoxWar3", parent, 0, 0)
        -- Absolute Y is the top edge, not the bottom: leave the entire panel
        -- above the native portrait/inventory/command-card area.
        BlzFrameSetAbsPoint(ui.frame, FRAMEPOINT_TOPLEFT, 0.25, 0.44)
        BlzFrameSetSize(ui.frame, 0.31, 0.185)
        BlzFrameSetLevel(ui.frame, 100)
        BlzFrameSetEnable(ui.frame, false)
        BlzFrameSetVisible(ui.frame, false)
        local function text(y, height)
            local frame = BlzCreateFrameByType("TEXT", "", ui.frame, "", 0)
            BlzFrameSetPoint(frame, FRAMEPOINT_TOPLEFT, ui.frame, FRAMEPOINT_TOPLEFT, 0.015, y)
            BlzFrameSetSize(frame, 0.28, height)
            BlzFrameSetEnable(frame, false)
            return frame
        end
        ui.title, ui.heading, ui.body = text(-0.012, 0.015), text(-0.035, 0.015), text(-0.055, 0.092)
        ui.highlight = BlzCreateFrameByType("FRAME", "", parent, "", 0)
        BlzFrameSetEnable(ui.highlight, false)
        BlzFrameSetLevel(ui.highlight, 90)
        BlzFrameSetVisible(ui.highlight, false)
        for _, points in ipairs({
            {FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPRIGHT, true},
            {FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_BOTTOMRIGHT, true},
            {FRAMEPOINT_TOPLEFT, FRAMEPOINT_BOTTOMLEFT, false},
            {FRAMEPOINT_TOPRIGHT, FRAMEPOINT_BOTTOMRIGHT, false},
        }) do
            local border = BlzCreateFrameByType("BACKDROP", "", ui.highlight, "", 0)
            BlzFrameSetTexture(border, "ReplaceableTextures\\TeamColor\\TeamColor00.blp", 0, true)
            BlzFrameSetEnable(border, false)
            BlzFrameSetPoint(border, points[1], ui.highlight, points[1], 0., 0.)
            BlzFrameSetPoint(border, points[2], ui.highlight, points[2], 0., 0.)
            BlzFrameSetSize(border, points[3] and 0 or 0.002, points[3] and 0.002 or 0)
        end
        local function button(label, x, width, action)
            local frame = BlzCreateFrameByType("GLUETEXTBUTTON", "", ui.frame, "ScriptDialogButton", 0)
            BlzFrameSetPoint(frame, FRAMEPOINT_BOTTOMLEFT, ui.frame, FRAMEPOINT_BOTTOMLEFT, x, 0.012)
            BlzFrameSetSize(frame, width, 0.024)
            BlzFrameSetText(frame, label)
            local trigger = CreateTrigger()
            BlzTriggerRegisterFrameEvent(trigger, frame, FRAMEEVENT_CONTROL_CLICK)
            TriggerAddAction(trigger, function()
                local pid = GetPlayerId(GetTriggerPlayer()) + 1
                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetEnable(frame, false)
                    BlzFrameSetEnable(frame, true)
                end
                action(pid)
            end)
            return frame
        end
        ui.back = button("Back", 0.012, 0.052, function(pid)
            if states[pid] then enter(pid, states[pid].index - 1) end
        end)
        ui.next = button("Next", 0.069, 0.052, function(pid)
            if states[pid] then enter(pid, states[pid].index + 1) end
        end)
        ui.mark = button("Mark Location", 0.126, 0.105, function(pid)
            local state = states[pid]
            if state and steps[state.index] then mark(pid, steps[state.index]) end
        end)
        button("Skip", 0.236, 0.06, Tutorial.close)
        render(GetPlayerId(GetLocalPlayer()) + 1)
    end)

    AddToEsc(Tutorial.close)
    for pid = 1, PLAYER_CAP do EVENT_ON_CLEANUP:register_action(pid, Tutorial.close) end
end, Debug and Debug.getLine())
