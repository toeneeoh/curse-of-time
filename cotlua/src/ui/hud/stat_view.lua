--[[
    stat_view.lua

    This module defines the stat window for detailed information on heroes / units
]]

OnInit.final("StatView", function(Require)
    Require('StatValues')
    Require('Honor')
    Require('HonorMilestones')
    Require('Perks')
    Require('PerkTree')
    Require('Faction')
    Require('TimerQueue')

    ---@class STAT_WINDOW
    ---@field display function
    ---@field refresh function
    STAT_WINDOW = {}

    local ST = STAT_TAG
    local STAT_WINDOW = STAT_WINDOW

    local STAT_LOOKUP = {
        str = {ITEM_STRENGTH, ITEM_HEALTH, ITEM_DAMAGE},
        bonus_str = {ITEM_STRENGTH, ITEM_HEALTH, ITEM_DAMAGE},
        agi = {ITEM_AGILITY, ITEM_ARMOR, ITEM_DAMAGE},
        bonus_agi = {ITEM_AGILITY, ITEM_ARMOR, ITEM_DAMAGE},
        int = {ITEM_INTELLIGENCE, ITEM_MANA_REGENERATION, ITEM_DAMAGE},
        bonus_int = {ITEM_INTELLIGENCE, ITEM_MANA_REGENERATION, ITEM_DAMAGE},
        bonus_mana = ITEM_MANA,
        base_bat = ITEM_BASE_ATTACK_SPEED,
        bonus_bat = ITEM_BASE_ATTACK_SPEED,
        bonus_damage = ITEM_DAMAGE,
        damage_percent = ITEM_DAMAGE,
        bonus_armor = ITEM_ARMOR,
        armor_percent = ITEM_ARMOR,
        bonus_hp = ITEM_HEALTH,
        cc = ITEM_CRIT_CHANCE,
        cd_= ITEM_CRIT_DAMAGE,
        cc_percent = ITEM_CRIT_CHANCE_MULT,
        cd_percent = ITEM_CRIT_DAMAGE_MULT,
        ms = ITEM_MOVESPEED,
        ms_percent = ITEM_MOVESPEED,
        overmovespeed = ITEM_MOVESPEED,
        regen_= ITEM_REGENERATION,
        regen_percent = ITEM_REGENERATION,
        regen_max = ITEM_REGENERATION,
        mana_regen_= ITEM_MANA_REGENERATION,
        mana_regen_percent = ITEM_MANA_REGENERATION,
        mana_regen_max = ITEM_MANA_REGENERATION,
        nomanaregen = ITEM_MANA_REGENERATION,
        gold_rate = ITEM_GOLD_GAIN,
        xp_rate = XP_RATE,
    }

    local function owner_pid(u)
        return GetPlayerId(GetOwningPlayer(u)) + 1
    end

    local function faction_for(u)
        return Faction.getFaction(owner_pid(u))
    end

    local function faction_reputation(u)
        local faction = faction_for(u)
        return faction and Faction.getReputation(owner_pid(u), faction.id) or 0
    end

    local difficulty_names = { "Easy", "Medium", "Hard" }

    local tab_tags = {
        ST,
        {
            { tag = "|cffffcc00Gold|r", priority = 1, getter = function(u) return GetCurrency(owner_pid(u), GOLD) end},
            { tag = "|cffccccccPlatinum|r", priority = 1, getter = function(u) return GetCurrency(owner_pid(u), PLATINUM) end},
            { tag = "|cff6969ffCrystal|r", priority = 1, getter = function(u) return GetCurrency(owner_pid(u), CRYSTAL) end},
            { tag = "|cffffcc00Spendable Honor|r", priority = 1, getter = function(u) return GetCurrency(owner_pid(u), HONOR) end},
            { tag = "|cffffcc00Lifetime Honor|r", priority = 1, getter = function(u) return Honor.getTotal(owner_pid(u)) end},
            { tag = "|cffffcc00Allocated Honor|r", priority = 1, getter = function(u) return Honor.getAllocated(owner_pid(u)) end},
            { tag = "|cff80ff80Faction Points|r", priority = 1, getter = function(u) return Faction.getPoints(owner_pid(u)) end},
            { tag = "|cffffff00Gold Find|r", priority = 1, getter = function(u)
                local rate = Unit[u].gold_rate
                if math.abs(rate) < 0.0005 then rate = 0 end
                return rate .. "%"
            end},
            { tag = "|cffccccccCurrency Converter|r", priority = 1, getter = function(u)
                local pid = owner_pid(u)
                if not HasCurrencyConverter(pid) then return "Not Owned" end
                return IsCurrencyConverterEnabled(pid) and "Enabled" or "Disabled"
            end},
        },
        {
            { tag = "|cffffcc00Available Perk Points|r", priority = 1, getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return Perks.getAvailable(pid) end},
            { tag = "|cffffcc00Allocated Perk Points|r", priority = 1, getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return Perks.getSpent(pid) end},
            { tag = "|cffffcc00Total Perk Points|r", priority = 1, getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return Perks.getTotal(pid) end},
            { tag = "|cffffcc00Free Reset|r", priority = 1, getter = function(u) local pid = GetPlayerId(GetOwningPlayer(u)) + 1 return Perks.hasReset(pid) and "Available" or "Unavailable" end},
        },
        {}, -- lifetime Honor milestones use their own paginated renderer
        {
            { tag = "|cffffcc00Faction|r", priority = 1, getter = function(u)
                local faction = faction_for(u)
                return faction and faction.name or "None"
            end},
            { tag = "|cffffcc00Rank|r", priority = 1, getter = function(u)
                local faction = faction_for(u)
                return faction and (Faction.getRank(faction_reputation(u))
                    .. " / " .. Faction.getMaxRank()) or "-"
            end},
            { tag = "|cffffcc00Reputation|r", priority = 1, getter = function(u)
                local faction = faction_for(u)
                if not faction then return "-" end
                local reputation = faction_reputation(u)
                local threshold = Faction.getNextRankThreshold(reputation)
                return threshold and (reputation .. " / " .. threshold)
                    or (reputation .. " (MAX)")
            end},
            { tag = "|cff80ff80Faction Points|r", priority = 1, getter = function(u)
                return faction_for(u) and Faction.getPoints(owner_pid(u)) or "-"
            end},
            { tag = "|cffffcc00Active Quest|r", priority = 1, getter = function(u)
                local quest = Quest.getActive(owner_pid(u))
                return quest and quest.name or "None"
            end},
            { tag = "|cffffcc00Difficulty|r", priority = 1, getter = function(u)
                local quest = Quest.getActive(owner_pid(u))
                return quest and (difficulty_names[quest.diff] or "Unknown") or "-"
            end},
            { tag = "|cffffcc00Progress|r", priority = 1, getter = function(u)
                local quest, progress = Quest.getActive(owner_pid(u))
                return quest and (Quest.formatProgress(progress) .. " / " .. quest.goal) or "-"
            end},
            { tag = "|cffffcc00Quest Reward|r", priority = 1, getter = function(u)
                local quest = Quest.getActive(owner_pid(u))
                return quest and (quest.faction_points .. " Points / "
                    .. quest.reputation .. " Reputation") or "-"
            end},
        },
    }

    local perk_bonuses = {
        { "Primary Attribute", "primary_percent", 100., "%" },
        { "Total Damage", "damage_percent", 100., "%" },
        { "Critical Chance", "crit_chance", 1., "%" },
        { "Critical Damage", "crit_damage", 1., "%" },
        { "Spellboost", "spellboost", 100., "%" },
        { "Armor", "armor_percent", 100., "%" },
        { "Health Regeneration", "regen_percent", 100., "%" },
        { "Damage Reduction", "damage_reduction", 100., "%" },
        { "Movespeed", "movespeed", 1., "" },
        { "Gold Find", "gold_rate", 1., "%" },
        { "Shared Experience", "shared_xp", 100., "%" },
        { "New Character Levels", "inheritance", 5., "" },
        { "New Character Gold", "inheritance", 25000., "" },
        { "Kill Quest Auto Turn-In", "huntsman", 1., "" },
    }
    for _, definition in ipairs(perk_bonuses) do
        local bonus = definition
        tab_tags[3][#tab_tags[3] + 1] = {
            tag = bonus[1],
            priority = 1,
            getter = function(u)
                local pid = GetPlayerId(GetOwningPlayer(u)) + 1
                local value = Perks.getBonuses(pid)[bonus[2]] or 0
                if bonus[2] == "huntsman" then
                    return value > 0 and "Enabled" or "Disabled"
                end
                local result = math.floor(value * bonus[3] + .5)
                return (result > 0 and "+" or "") .. result .. bonus[4]
            end,
        }
    end

    local function build_tab_order(tab)
        local order = {}
        for i = 1, #tab do
            local p = tab[i].priority or 99
            order[p] = order[p] or {}
            order[p][#order[p] + 1] = i
        end
        return order
    end

    --#region frame setup
    local frame = BlzCreateFrame("ListBoxWar3", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)

    local MAX_ROWS = 32
    local CURRENCY_TAB = 2
    local PERKS_TAB = 3
    local HONOR_TAB = 4
    local FACTION_TAB = 5
    local MILESTONES_PER_PAGE = 7
    local tab_ui = {} -- tab_ui[page] = { rows = { [1]=slot,... }, order = ..., entries = ... }

    local function make_slot(parent, breakdown_parent, y)
        local tag_f = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        local val_f = BlzCreateFrameByType("TEXT", "", parent, "", 0)
        local separator = BlzCreateFrameByType("BACKDROP", "", parent, "", 0)

        BlzFrameSetPoint(tag_f, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, 0.015, y)
        BlzFrameSetTextAlignment(tag_f, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT)
        BlzFrameSetEnable(tag_f, false)

        BlzFrameSetPoint(val_f, FRAMEPOINT_TOPLEFT, parent, FRAMEPOINT_TOPLEFT, 0.113, y)
        BlzFrameSetTextAlignment(val_f, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_LEFT)
        BlzFrameSetEnable(val_f, false)
        BlzFrameSetSize(separator, 0.27, 0.001)
        BlzFrameSetTexture(separator, "replaceabletextures\\teamcolor\\teamcolor08", 0, true)
        BlzFrameSetEnable(separator, false)
        BlzFrameSetVisible(separator, false)

        -- breakdown icon (slot-based)
        local icon = BlzCreateFrameByType("BACKDROP", "", breakdown_parent, "", 0)
        local icon_frame = BlzCreateFrameByType("FRAME", "", breakdown_parent, "", 0)
        BlzFrameSetTexture(icon, "war3mapImported\\question.blp", 0, true)
        BlzFrameSetScale(icon, 0.6)
        BlzFrameSetSize(icon, 0.016, 0.016)
        BlzFrameSetAllPoints(icon_frame, icon)

        local tip = FrameAddSimpleTooltip(icon_frame, "", "", true, FRAMEPOINT_BOTTOMLEFT, FRAMEPOINT_TOPRIGHT, 0., 0.008, 0.01)

        BlzFrameSetVisible(icon, false) -- hidden by default

        return {
            tag = tag_f,
            val = val_f,
            separator = separator,
            icon = icon,
            tip = tip,
            has_breakdown = false,
            last_icon_x = nil,
            last_tag = nil,
            last_val = nil,
            last_tip = nil,
        }
    end

    -- separate breakdowns per tab (if they exist)
    local breakdown_frames = {
        BlzCreateFrameByType("FRAME", "", frame, "", 0),
        BlzCreateFrameByType("FRAME", "", frame, "", 0),
        BlzCreateFrameByType("FRAME", "", frame, "", 0),
        BlzCreateFrameByType("FRAME", "", frame, "", 0),
    }
    for i = 1, #breakdown_frames do
        BlzFrameSetTexture(breakdown_frames[i], "trans32.blp", 0, true)
        BlzFrameSetSize(breakdown_frames[i], 0.001, 0.001)
        BlzFrameSetEnable(breakdown_frames[i], false)
    end

    local function init_tab(page)
        local entries = tab_tags[page]
        tab_ui[page] = { entries = entries, order = build_tab_order(entries), rows = {} }

        for line = 1, MAX_ROWS do
            local y = -0.04 + (-line + 1) * 0.01
            if page == HONOR_TAB and line >= 4 then
                y = -0.08 - (line - 4) * 0.032
            end
            local slot = make_slot(frame, breakdown_frames[page], y)
            tab_ui[page].rows[line] = slot
            BlzFrameSetVisible(slot.tag, false)
            BlzFrameSetVisible(slot.val, false)

            if page == PERKS_TAB then
                BlzFrameClearAllPoints(slot.val)
                BlzFrameSetPoint(slot.val, FRAMEPOINT_TOPLEFT, frame,
                    FRAMEPOINT_TOPLEFT, 0.205, y)
            end

            if page == HONOR_TAB and line >= 4 then
                BlzFrameClearAllPoints(slot.icon)
                BlzFrameSetPoint(slot.icon, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, 0.016, y + 0.006)
                BlzFrameSetScale(slot.icon, 1.)
                BlzFrameSetSize(slot.icon, 0.024, 0.024)
                BlzFrameClearAllPoints(slot.tag)
                BlzFrameSetPoint(slot.tag, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, 0.048, y)
                BlzFrameClearAllPoints(slot.val)
                BlzFrameSetPoint(slot.val, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, 0.15, y)
                BlzFrameSetPoint(slot.separator, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_TOPLEFT, 0.015, y - 0.024)
            end
        end
    end

    for page = 1, #tab_tags do
        init_tab(page)
    end

    local tab_frame = BlzCreateFrame("ListBoxWar3", frame, 0, 0)
    local title = BlzCreateFrame("TitleText", frame, 0, 0)
    local viewing = {}

    -- initialize viewing tables
    for i = 1, PLAYER_CAP do
        viewing[i] = {unit = nil, page = 1, milestone_page = 1}
    end

    BlzFrameSetAbsPoint(frame, FRAMEPOINT_TOPLEFT, -0.05, 0.55)
    BlzFrameSetSize(frame, 0.3, 0.33)
    BlzFrameSetEnable(frame, false)

    BlzFrameSetPoint(title, FRAMEPOINT_TOP, frame, FRAMEPOINT_TOP, 0., -0.013)
    BlzFrameSetEnable(title, false)

    BlzFrameSetPoint(tab_frame, FRAMEPOINT_TOPLEFT, frame, FRAMEPOINT_BOTTOMLEFT, 0., 0.005)
    BlzFrameSetSize(tab_frame, 0.3, 0.05)
    BlzFrameSetEnable(tab_frame, false)

    -- hide by default
    BlzFrameSetVisible(frame, false)
    --#endregion frame setup

    local is_open = {}

    local on_refresh = function(target, stat)
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        if viewing[pid].unit ~= target then
            return
        end

        -- try to map event key -> STAT_TAG index
        local stat_idx = STAT_LOOKUP[stat]

        if type(stat_idx) == "table" then
            for _, key in ipairs(stat_idx) do
                STAT_WINDOW.refresh(pid, key)
            end
        elseif stat_idx then
            STAT_WINDOW.refresh(pid, stat_idx)
        else
            STAT_WINDOW.refresh(pid)
        end
    end

    local close = function(pid)
        is_open[pid] = false
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(frame, false)
        end

        -- no longer viewing stat window
        if viewing[pid].unit then
            EVENT_STAT_CHANGE:unregister_unit_action(viewing[pid].unit, on_refresh)
            viewing[pid].unit = nil
        end
    end
    AddToEsc(close) -- close window hotkey reference

    local onClose = function()
        local f = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(f, false)
            BlzFrameSetEnable(f, true)
        end

        close(pid)

        return false
    end

    -- escape button
    local esc_button = SimpleButton.create(frame, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.02, -0.02, onClose, "Close 'B'", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)
    RegisterHotkeyTooltip(esc_button, 6)

    local manage_perks = BlzCreateFrameByType("GLUETEXTBUTTON", "", frame,
        "ScriptDialogButton", 0)
    BlzFrameSetPoint(manage_perks, FRAMEPOINT_BOTTOM, frame, FRAMEPOINT_BOTTOM,
        0., 0.018)
    BlzFrameSetSize(manage_perks, 0.11, 0.026)
    BlzFrameSetText(manage_perks, "View Perks")
    BlzFrameSetVisible(manage_perks, false)
    local manage_perks_trigger = CreateTrigger()
    BlzTriggerRegisterFrameEvent(manage_perks_trigger, manage_perks,
        FRAMEEVENT_CONTROL_CLICK)
    TriggerAddCondition(manage_perks_trigger, Condition(function()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        BlzFrameSetEnable(manage_perks, false)
        BlzFrameSetEnable(manage_perks, true)
        local selected = viewing[pid].unit
        local target_pid = selected and owner_pid(selected) or pid
        PerkTree.display(pid, target_pid)
        return false
    end))

    local function ViewPlayersClick()
        local pid   = GetPlayerId(GetTriggerPlayer()) + 1 ---@type integer 
        local dw    = DialogWindow[pid] ---@type DialogWindow 
        local index = dw:getClickedIndex(GetClickedButton()) ---@type integer 

        if index ~= -1 then
            viewing[pid].unit = Hero[dw.data[index]]
            STAT_WINDOW.refresh(pid)

            dw:destroy()
        end

        return false
    end

    local function ViewPlayers()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local dw  = DialogWindow.create(pid, "", ViewPlayersClick) ---@type DialogWindow 
        local U   = User.first ---@type User 

        while U do
            if viewing[pid].unit ~= Hero[U.id] then
                dw:addButton(U.nameColored, U.id)
            end

            U = U.next
        end

        dw:display()

        return false
    end

    -- choose player button
    SimpleButton.create(esc_button.frame, "ReplaceableTextures\\CommandButtons\\BTNCycleRight.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPLEFT, 0, 0, ViewPlayers, "Select Player", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)

    local tabs = {
        SimpleButton.create(tab_frame, "ReplaceableTextures\\CommandButtons\\BTNHeroPanelStatsButton.dds", 0.026, 0.026, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.0125, -0.0125, nil, "View Stats", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
        SimpleButton.create(tab_frame, "ReplaceableTextures\\CommandButtons\\BTNHeroPanelCurrencyButton.dds", 0.026, 0.026, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.042, -0.0125, nil, "View Currency", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
        SimpleButton.create(tab_frame, "ReplaceableTextures\\CommandButtons\\BTNHeroPanelPerkButton.dds", 0.026, 0.026, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.0715, -0.0125, nil, "View Perks", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
        SimpleButton.create(tab_frame, "ReplaceableTextures\\CommandButtons\\BTNMedalionOfCourage.blp", 0.026, 0.026, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.101, -0.0125, nil, "View Honor Milestones", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
        SimpleButton.create(tab_frame, "ReplaceableTextures\\CommandButtons\\BTNHumanCaptureFlag.blp", 0.026, 0.026, FRAMEPOINT_TOPLEFT, FRAMEPOINT_TOPLEFT, 0.1305, -0.0125, nil, "View Faction", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01),
    }
    for index = 2, #tabs do tabs[index]:enable(false) end

    local function switch_tab()
        local trigger_frame = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local tpid = GetPlayerId(GetOwningPlayer(viewing[pid].unit)) + 1
        local index = 1
        for i = 1, #tabs do
            if tabs[i].frame == trigger_frame then
                index = i
                break
            end
        end

        viewing[pid].page = (tpid <= PLAYER_CAP and index) or 1 -- set page to stats for non-player units

        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(trigger_frame, false)
            BlzFrameSetEnable(trigger_frame, true)

            for i = 1, #tabs do
                tabs[i]:enable(false)
            end

            tabs[viewing[pid].page]:enable(true)
        end

        -- always rebuild from scratch for correct page visibility on all clients
        STAT_WINDOW.refresh(pid)
    end

    tabs[1]:onClick(switch_tab)
    tabs[2]:onClick(switch_tab)
    tabs[3]:onClick(switch_tab)
    tabs[4]:onClick(switch_tab)
    tabs[5]:onClick(switch_tab)

    local milestone_controls = BlzCreateFrameByType("FRAME", "", frame, "", 0)
    local milestone_page_text = BlzCreateFrameByType("TEXT", "", milestone_controls, "", 0)
    BlzFrameSetPoint(milestone_controls, FRAMEPOINT_BOTTOM, frame, FRAMEPOINT_BOTTOM, 0., 0.013)
    BlzFrameSetSize(milestone_controls, 0.11, 0.02)
    BlzFrameSetPoint(milestone_page_text, FRAMEPOINT_CENTER, milestone_controls, FRAMEPOINT_CENTER, 0., 0.)
    BlzFrameSetTextAlignment(milestone_page_text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_CENTER)
    BlzFrameSetEnable(milestone_page_text, false)

    local function change_milestone_page(direction)
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        local max_pages = math.max(1, math.ceil(#Honor.getMilestones() / MILESTONES_PER_PAGE))
        viewing[pid].milestone_page = math.max(1, math.min(max_pages,
            viewing[pid].milestone_page + direction))
        STAT_WINDOW.refresh(pid)
    end

    local previous_milestones = SimpleButton.create(milestone_controls,
        "ReplaceableTextures\\CommandButtons\\BTNCycleLeft.blp", 0.016, 0.016,
        FRAMEPOINT_LEFT, FRAMEPOINT_LEFT, 0., 0., function() change_milestone_page(-1) end,
        "Previous Milestones", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)
    local next_milestones = SimpleButton.create(milestone_controls,
        "ReplaceableTextures\\CommandButtons\\BTNCycleRight.blp", 0.016, 0.016,
        FRAMEPOINT_RIGHT, FRAMEPOINT_RIGHT, 0., 0., function() change_milestone_page(1) end,
        "Next Milestones", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)
    BlzFrameSetVisible(milestone_controls, false)

    local function set_if_changed(slot, field, f, s)
        if slot[field] ~= s then
            slot[field] = s
            BlzFrameSetText(f, s)
        end
    end

    local function set_tip_if_changed(slot, s)
        if slot.last_tip ~= s then
            slot.last_tip = s
            BlzFrameSetText(slot.tip.tooltip, s)
        end
    end

    local function render_honor_row(slot, tag, value, tooltip, icon)
        set_if_changed(slot, "last_tag", slot.tag, tag)
        set_if_changed(slot, "last_val", slot.val, value)
        BlzFrameSetVisible(slot.tag, true)
        BlzFrameSetVisible(slot.val, true)

        if tooltip and icon then
            set_tip_if_changed(slot, tooltip)
            BlzFrameSetTexture(slot.icon, icon, 0, true)
            BlzFrameSetVisible(slot.icon, true)
            BlzFrameSetVisible(slot.separator, true)
            slot.has_breakdown = true
        end
    end

    local function render_honor_page(pid, target_pid)
        local rows = tab_ui[HONOR_TAB].rows
        local total = Honor.getTotal(target_pid)
        local milestone_list = Honor.getMilestones()
        local max_pages = math.max(1, math.ceil(#milestone_list / MILESTONES_PER_PAGE))
        local page = math.max(1, math.min(max_pages, viewing[pid].milestone_page))
        viewing[pid].milestone_page = page

        BlzFrameSetVisible(milestone_controls, true)
        BlzFrameSetText(milestone_page_text, "Milestones " .. page .. "/" .. max_pages)
        previous_milestones:enable(page > 1)
        next_milestones:enable(page < max_pages)

        render_honor_row(rows[1], "|cffffcc00Lifetime Honor|r", tostring(total))
        local next_milestone = Honor.getNextMilestone(target_pid)
        if next_milestone then
            render_honor_row(rows[2], "|cffffcc00Next Milestone|r",
                total .. "/" .. next_milestone.honor)
        else
            render_honor_row(rows[2], "|cffffcc00Next Milestone|r", "Complete")
        end

        local first = (page - 1) * MILESTONES_PER_PAGE + 1
        local last = math.min(#milestone_list, first + MILESTONES_PER_PAGE - 1)
        local row = 4
        for index = first, last do
            local milestone = milestone_list[index]
            local unlocked = Honor.isMilestoneUnlocked(target_pid, milestone)
            local color = unlocked and "|cff00ff00" or "|cff777777"
            local status = unlocked and "Unlocked" or "Locked"
            render_honor_row(rows[row], "|cffffcc00" .. milestone.honor .. " Honor|r",
                color .. milestone.name .. "|r",
                color .. status .. "|r\n" .. milestone.description,
                milestone.icon or "ReplaceableTextures\\CommandButtons\\BTNChestOfGold.blp")
            row = row + 1
        end
    end

    -- Shared row rendering
    local function render_stat_row(u, page, row, idx)
        local T       = tab_ui[page]
        local entries = T.entries
        local rows    = T.rows
        local v       = entries[idx]
        local slot    = rows[row]

        local tag_s = v.alternate or v.tag or ""
        local num   = v.getter and v.getter(u) or ""
        local num_s = tostring(num)
        local val_s = num_s .. (v.suffix or "")

        -- update text only if changed
        set_if_changed(slot, "last_tag", slot.tag, tag_s)
        set_if_changed(slot, "last_val", slot.val, val_s)

        BlzFrameSetVisible(slot.tag, true)
        BlzFrameSetVisible(slot.val, true)

        -- breakdown handling
        if v.breakdown then
            local b = v.breakdown(u)
            set_tip_if_changed(slot, b)

            -- position icon near the value text
            local x = 0.01 + (v.suffix and 0.01 or 0) + num_s:len() * 0.0085
            if slot.last_icon_x ~= x then
                slot.last_icon_x = x
                BlzFrameClearAllPoints(slot.icon)
                BlzFrameSetPoint(slot.icon, FRAMEPOINT_TOPLEFT, slot.val, FRAMEPOINT_TOPLEFT, x, 0.0)
            end

            BlzFrameSetVisible(slot.icon, true)
            slot.has_breakdown = true
        else
            if slot.has_breakdown then
                slot.has_breakdown = false
                BlzFrameSetVisible(slot.icon, false)
                slot.last_tip    = nil
                slot.last_icon_x = nil
            end
        end
    end

    local function clear_all_rows()
        for page = 1, #tab_tags do
            local T = tab_ui[page]
            if T then
                local rows = T.rows
                if rows then
                    for l = 1, MAX_ROWS do
                        local slot = rows[l]
                        BlzFrameSetVisible(slot.tag, false)
                        BlzFrameSetVisible(slot.val, false)
                        BlzFrameSetVisible(slot.icon, false)
                        BlzFrameSetVisible(slot.separator, false)
                        slot.has_breakdown = false
                        slot.last_tip      = nil
                        slot.last_icon_x   = nil
                    end
                end
            end
        end
    end

    -- Full refresh: rebuilds all rows AND the stat->row index map
    local function full_refresh(pid)
        -- local-only safety + window visibility
        if GetLocalPlayer() ~= Player(pid - 1) or not is_open[pid] then
            return
        end

        local u = viewing[pid].unit
        if not u then
            return
        end

        local page = viewing[pid].page
        local T    = tab_ui[page]
        if not T then
            return
        end

        -- hard clear all rows for all pages
        clear_all_rows()

        -- update title
        local tpid = GetPlayerId(GetOwningPlayer(u)) + 1
        local name = (u == Hero[tpid] and User[tpid - 1].nameColored) or GetUnitName(u)
        BlzFrameSetText(title, name)
        BlzFrameSetVisible(manage_perks, page == PERKS_TAB)
        BlzFrameSetText(manage_perks, tpid == pid and "Manage Perks" or "View Perk Tree")

        -- hero vs non-hero gating
        local ishero = (u == Hero[tpid] and 3) or 2

        -- show correct breakdown frame for this page
        for i = 1, #breakdown_frames do
            BlzFrameSetVisible(breakdown_frames[i], i == page)
        end

        BlzFrameSetVisible(milestone_controls, page == HONOR_TAB)
        if page == HONOR_TAB then
            render_honor_page(pid, tpid)
            return
        end

        -- row index map: stat index -> row number (per page)
        T.row_index = T.row_index or {}
        local row_index = T.row_index
        -- clear previous mapping
        for k in pairs(row_index) do
            row_index[k] = nil
        end

        local line = 0
        local order = T.order

        -- walk through stats by priority buckets
        for priority = 1, ishero do
            local list = order[priority]
            if list then
                for li = 1, #list do
                    local idx = list[li]

                    line = line + 1
                    if line > MAX_ROWS then
                        break
                    end

                    row_index[idx] = line
                    render_stat_row(u, page, line, idx)
                end
            end

            if line > MAX_ROWS then
                break
            end
        end
    end

    -- Public API: optional stat_idx for single-stat refresh
    -- stat_idx is the STAT_TAG index (e.g. ITEM_HEALTH, ITEM_DAMAGE, ...)
    STAT_WINDOW.refresh = function(pid, stat_idx)
        -- no specific stat -> full refresh
        if not stat_idx then
            full_refresh(pid)
            return
        end

        -- local-only safety + window visibility
        if GetLocalPlayer() ~= Player(pid - 1) or not is_open[pid] then
            return
        end

        local u = viewing[pid].unit
        if not u then
            return
        end

        local page = viewing[pid].page
        local T    = tab_ui[page]
        if not T then
            return
        end

        -- only do targeted updates on stats tab for now
        if page ~= 1 then
            full_refresh(pid)
            return
        end

        local row_index = T.row_index
        local row       = row_index and row_index[stat_idx]

        -- if we don't know where this stat is (e.g. first time, unit changed, etc.) fallback
        if not row or row < 1 or row > MAX_ROWS then
            full_refresh(pid)
            return
        end

        -- keep title and breakdown frame up-to-date (cheap)
        local tpid = GetPlayerId(GetOwningPlayer(u)) + 1
        local name = (u == Hero[tpid] and User[tpid - 1].nameColored) or GetUnitName(u)
        BlzFrameSetText(title, name)
        for i = 1, #breakdown_frames do
            BlzFrameSetVisible(breakdown_frames[i], i == page)
        end

        -- update just this one row
        render_stat_row(u, page, row, stat_idx)
    end

    STAT_WINDOW.display = function(u, pid)
        local tpid = GetPlayerId(GetOwningPlayer(u)) + 1

        if viewing[pid].unit == u then
            close(pid)
        elseif u and not BlzGetUnitBooleanField(u, UNIT_BF_IS_A_BUILDING) then
            EVENT_STAT_CHANGE:unregister_unit_action(viewing[pid].unit, on_refresh)
            viewing[pid].unit = u
            viewing[pid].page = (tpid <= PLAYER_CAP and viewing[pid].page) or 1 -- set page to stats for non-player units
            EVENT_STAT_CHANGE:register_unit_action(u, on_refresh)

            is_open[pid] = true
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetVisible(frame, true)
                for i = 1, #tabs do
                    tabs[i]:enable(false)
                end
                tabs[viewing[pid].page]:enable(true)
            end

            STAT_WINDOW.refresh(pid)
        end
    end

    local function on_cleanup(pid)
        close(pid)
    end

    local U = User.first
    while U do
        EVENT_ON_CLEANUP:register_action(U.id, on_cleanup)
        U = U.next
    end


    Honor.registerChangedAction(function(changed_pid)
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        local selected = viewing[pid].unit
        if selected and (viewing[pid].page == HONOR_TAB
                or viewing[pid].page == CURRENCY_TAB)
            and GetPlayerId(GetOwningPlayer(selected)) + 1 == changed_pid then
            STAT_WINDOW.refresh(pid)
        end
    end)

    RegisterCurrencyChangedAction(function(changed_pid)
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        local selected = viewing[pid].unit
        if selected and viewing[pid].page == CURRENCY_TAB
            and GetPlayerId(GetOwningPlayer(selected)) + 1 == changed_pid then
            STAT_WINDOW.refresh(pid)
        end
    end)

    RegisterCurrencyConverterChangedAction(function(changed_pid)
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        local selected = viewing[pid].unit
        if selected and viewing[pid].page == CURRENCY_TAB
            and GetPlayerId(GetOwningPlayer(selected)) + 1 == changed_pid then
            STAT_WINDOW.refresh(pid)
        end
    end)

    Perks.registerChangedAction(function(changed_pid)
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        local selected = viewing[pid].unit
        if selected and viewing[pid].page == PERKS_TAB
            and GetPlayerId(GetOwningPlayer(selected)) + 1 == changed_pid then
            STAT_WINDOW.refresh(pid)
        end
    end)

    -- Quest progress can change without changing a conventional unit stat.
    -- Keep the inspected faction summary current while that tab is visible.
    TimerQueue:callPeriodically(1., nil, function()
        local pid = GetPlayerId(GetLocalPlayer()) + 1
        if is_open[pid] and viewing[pid].page == FACTION_TAB then
            STAT_WINDOW.refresh(pid)
        end
    end)

end, Debug and Debug.getLine())
