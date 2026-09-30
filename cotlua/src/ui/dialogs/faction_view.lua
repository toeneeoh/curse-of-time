-- Faction membership and quest presentation.

OnInit.final("FactionView", function(Require)
    Require('Faction')
    Require('FactionEvents')
    Require('Currency')
    Require('Frames')
    Require('Prompt')
    Require('SimpleButton')
    Require('TimerQueue')
    Require('Users')
    Require('Variables')

    local view = {}
    local boxes = {}

    local main = BlzCreateFrameByType("FRAME", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
    BlzFrameSetAbsPoint(main, FRAMEPOINT_TOP, 0.4, 0.53)
    BlzFrameSetSize(main, 0.75, 0.35)
    BlzFrameSetLevel(main, 10)
    BlzFrameSetEnable(main, false)

    local frame = BlzCreateFrameByType("BACKDROP", "", main, "", 0)
    BlzFrameSetPoint(frame, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0., 0.078)
    BlzFrameSetSize(frame, 0.84, 0.52)
    BlzFrameSetEnable(frame, false)
    BlzFrameSetTexture(frame, "war3mapImported\\faction_frame.dds", 0, true)

    local title = BlzCreateFrame("TitleText", main, 0, 0)
    BlzFrameSetPoint(title, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0., -0.029)
    BlzFrameSetEnable(title, false)

    local blurb = BlzCreateFrameByType("TEXT", "", main, "", 0)
    BlzFrameSetPoint(blurb, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0.01, -0.302)
    BlzFrameSetEnable(blurb, false)
    BlzFrameSetSize(blurb, 0.2, 0.075)
    BlzFrameSetScale(blurb, 0.9)

    local faction_icon = SimpleButton.create(
        main,
        "ReplaceableTextures\\CommandButtons\\BTNMedalionOfCourage.blp",
        0.05,
        0.05,
        FRAMEPOINT_TOP,
        FRAMEPOINT_TOP,
        0.,
        -0.065
    )
    BlzFrameSetEnable(faction_icon.frame, false)

    local bulletin = BlzCreateFrame("QuestButtonDisabledBackdropTemplate",
                                    main, 0, 0)
    BlzFrameSetPoint(bulletin, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP,
                     0., -0.124)
    BlzFrameSetSize(bulletin, 0.205, 0.076)
    BlzFrameSetEnable(bulletin, false)
    local bulletin_text = BlzCreateFrameByType("TEXT", "", bulletin, "", 0)
    BlzFrameSetPoint(bulletin_text, FRAMEPOINT_CENTER, bulletin,
                     FRAMEPOINT_CENTER, 0., 0.)
    BlzFrameSetSize(bulletin_text, 0.185, 0.058)
    BlzFrameSetTextAlignment(bulletin_text, TEXT_JUSTIFY_CENTER,
                             TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetScale(bulletin_text, 0.82)
    BlzFrameSetEnable(bulletin_text, false)

    local rank_icon = SimpleButton.create(
        main,
        "ReplaceableTextures\\CommandButtons\\BTNMedalionOfCourage.blp",
        0.04,
        0.04,
        FRAMEPOINT_TOP,
        FRAMEPOINT_TOP,
        0.,
        -0.244
    )
    rank_icon:makeTooltip(FRAMEPOINT_TOPLEFT, 0.2)
    rank_icon:setTooltipIcon(
        "ReplaceableTextures\\CommandButtons\\BTNMedalionOfCourage.blp")
    local rank_charge = BlzCreateFrameByType("BACKDROP", "", rank_icon.frame, "", 0)
    BlzFrameSetSize(rank_charge, 0.018, 0.018)
    BlzFrameSetTexture(rank_charge,
        "UI/Widgets/Console/Human/CommandButton/human-button-lvls-overlay.blp", 0, true)
    BlzFrameSetPoint(rank_charge, FRAMEPOINT_BOTTOMRIGHT,
        rank_icon.frame, FRAMEPOINT_BOTTOMRIGHT, 0.003, -0.003)
    local rank_count = BlzCreateFrameByType("TEXT", "", rank_icon.frame, "", 0)
    BlzFrameSetAllPoints(rank_count, rank_charge)
    BlzFrameSetTextAlignment(rank_count, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)

    local bounty_frame = BlzCreateFrameByType("FRAME", "", main, "", 0)
    BlzFrameSetPoint(bounty_frame, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP,
                     0., -0.29)
    BlzFrameSetSize(bounty_frame, 0.215, 0.07)
    BlzFrameSetEnable(bounty_frame, false)

    local bounty_title = BlzCreateFrame("TitleText", bounty_frame, 0, 0)
    BlzFrameSetPoint(bounty_title, FRAMEPOINT_TOP, bounty_frame,
                     FRAMEPOINT_TOP, 0., 0.)
    BlzFrameSetScale(bounty_title, 0.72)
    BlzFrameSetEnable(bounty_title, false)
    BlzFrameSetText(bounty_title, "|cffffcc00Vanguard Bounty|r")

    local bounty_bar_backdrop = BlzCreateFrame(
        "EscMenuControlBackdropTemplate", bounty_frame, 0, 0)
    BlzFrameSetPoint(bounty_bar_backdrop, FRAMEPOINT_TOP, bounty_frame,
                     FRAMEPOINT_TOP, 0., -0.021)
    BlzFrameSetSize(bounty_bar_backdrop, 0.19, 0.022)
    BlzFrameSetEnable(bounty_bar_backdrop, false)
    local bounty_bar = BlzCreateFrameByType("SIMPLESTATUSBAR", "",
                                            bounty_bar_backdrop, "", 0)
    BlzFrameSetPoint(bounty_bar, FRAMEPOINT_TOPLEFT, bounty_bar_backdrop,
                     FRAMEPOINT_TOPLEFT, 0.004, -0.004)
    BlzFrameSetPoint(bounty_bar, FRAMEPOINT_BOTTOMRIGHT, bounty_bar_backdrop,
                     FRAMEPOINT_BOTTOMRIGHT, -0.004, 0.004)
    BlzFrameSetTexture(bounty_bar,
                       "ui\\feedback\\xpbar\\human-bigbar-fill", 0, true)
    BlzFrameSetMinMaxValue(bounty_bar, 0., 12.)
    BlzFrameSetValue(bounty_bar, 0.)
    BlzFrameSetEnable(bounty_bar, false)
    local bounty_progress = BlzCreateFrameByType("TEXT", "",
                                                 bounty_bar_backdrop, "", 0)
    BlzFrameSetAllPoints(bounty_progress, bounty_bar_backdrop)
    BlzFrameSetTextAlignment(bounty_progress, TEXT_JUSTIFY_CENTER,
                             TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetScale(bounty_progress, 0.72)
    BlzFrameSetEnable(bounty_progress, false)

    local bounty_status = BlzCreateFrameByType("TEXT", "", bounty_frame, "", 0)
    BlzFrameSetPoint(bounty_status, FRAMEPOINT_BOTTOM, bounty_frame,
                     FRAMEPOINT_BOTTOM, 0., 0.002)
    BlzFrameSetSize(bounty_status, 0.21, 0.017)
    BlzFrameSetTextAlignment(bounty_status, TEXT_JUSTIFY_CENTER,
                             TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetScale(bounty_status, 0.7)
    BlzFrameSetEnable(bounty_status, false)
    BlzFrameSetVisible(bounty_frame, false)

    local bulletin_index = {}
    local bulletins = {
        [1] = {
            "A prospector insists the eastern tunnels are lucky. Nobody remembers which tunnels are east.",
            "A rich vein was discovered, then misplaced somewhere in the paperwork.",
            "The golem safety seminar has been postponed due to a golem.",
            "Quartermaster inventory remains, officially, mostly pickaxes.",
            "Miners report that the ominous rumbling is probably normal.",
        },
        [2] = {
            "Forecast: weather, followed by additional weather.",
            "Stormwatch denies aiming the Goblin Space Laser at the moon.",
            "Cloud observers report one especially suspicious cloud.",
            "Umbrella requisitions have risen for the seventh week running.",
            "A junior watcher predicted clear skies and has been reassigned.",
        },
        [3] = {
            "A Vanguard hunter claims the beast was much larger before witnesses arrived.",
            "The quartermaster reminds recruits that trophies are not legal tender.",
            "Another bounty board has been damaged by an enthusiastic applicant.",
            "Scouts report dangerous quarry. Morale has improved considerably.",
            "The Grand Hunt betting pool remains entirely unofficial.",
        },
    }

    local buff_frame = BlzCreateFrameByType("FRAME", "", main, "", 0)
    BlzFrameSetPoint(buff_frame, FRAMEPOINT_TOPRIGHT, main, FRAMEPOINT_TOPRIGHT, -0.02, 0.016)
    BlzFrameSetSize(buff_frame, 0.24, 0.38)
    BlzFrameSetEnable(buff_frame, false)

    local buff_title = BlzCreateFrame("TitleText", buff_frame, 0, 0)
    BlzFrameSetPoint(buff_title, FRAMEPOINT_TOP, buff_frame, FRAMEPOINT_TOP, 0., -0.046)
    BlzFrameSetEnable(buff_title, false)
    BlzFrameSetText(buff_title, "|cffffcc00Faction Blessing|r")

    local buff_blurb = BlzCreateFrameByType("TEXT", "", buff_frame, "", 0)
    BlzFrameSetPoint(buff_blurb, FRAMEPOINT_TOP, buff_frame, FRAMEPOINT_TOP, 0., -0.13)
    BlzFrameSetEnable(buff_blurb, false)
    BlzFrameSetSize(buff_blurb, 0.2, 1.0)

    local buff_icon = SimpleButton.create(
        buff_frame,
        "ReplaceableTextures\\CommandButtons\\BTNTemp.blp",
        0.04,
        0.04,
        FRAMEPOINT_TOP,
        FRAMEPOINT_TOP,
        0.,
        -0.08
    )
    buff_icon:makeTooltip(FRAMEPOINT_TOPLEFT, 0.2)

    local event_frame = BlzCreateFrameByType("FRAME", "", main, "", 0)
    BlzFrameSetPoint(event_frame, FRAMEPOINT_TOPRIGHT, main, FRAMEPOINT_TOPRIGHT, -0.01, -0.143)
    BlzFrameSetSize(event_frame, 0.24, 0.20)
    BlzFrameSetEnable(event_frame, false)

    local event_title = BlzCreateFrame("TitleText", event_frame, 0, 0)
    BlzFrameSetPoint(event_title, FRAMEPOINT_TOP, event_frame, FRAMEPOINT_TOP, -0.01, -0.05)
    BlzFrameSetEnable(event_title, false)
    BlzFrameSetText(event_title, "|cffffcc00Event|r")

    local event_blurb = BlzCreateFrameByType("TEXT", "", event_frame, "", 0)
    BlzFrameSetPoint(event_blurb, FRAMEPOINT_TOP, event_frame, FRAMEPOINT_TOP, -0.01, -0.13)
    BlzFrameSetSize(event_blurb, 0.2, 0.065)
    BlzFrameSetTextAlignment(event_blurb, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetEnable(event_blurb, false)
    BlzFrameSetText(event_blurb,
        "|cff808080Events become available after Chaos.|r")

    local event_icon = SimpleButton.create(
        event_frame,
        "ReplaceableTextures\\CommandButtons\\BTNTreasureChest.blp",
        0.04,
        0.04,
        FRAMEPOINT_TOP,
        FRAMEPOINT_TOP,
        -0.01,
        -0.08
    )
    event_icon:makeTooltip(FRAMEPOINT_TOPLEFT, 0.2)
    event_icon:setTooltipIcon(
        "ReplaceableTextures\\CommandButtons\\BTNTreasureChest.blp")
    event_icon:setTooltipName("Hold the Line")
    event_icon:setTooltipText(
        "Defend the Cave Voyagers' supply cache against five assault waves.")

    local event_timer = BlzCreateFrameByType("TEXT", "", event_frame, "", 0)
    BlzFrameSetPoint(event_timer, FRAMEPOINT_BOTTOM,
        event_frame, FRAMEPOINT_BOTTOM, -0.01, 0.012)
    BlzFrameSetSize(event_timer, 0.2, 0.02)
    BlzFrameSetTextAlignment(event_timer, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetEnable(event_timer, false)
    BlzFrameSetVisible(event_timer, false)

    local event_hud = BlzCreateFrame("QuestButtonDisabledBackdropTemplate",
        BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
    BlzFrameSetPoint(event_hud, FRAMEPOINT_TOP, RESOURCE_BAR, FRAMEPOINT_BOTTOM, 0., -0.006)
    BlzFrameSetSize(event_hud, 0.235, 0.052)
    BlzFrameSetLevel(event_hud, 5)
    BlzFrameSetEnable(event_hud, false)
    BlzFrameSetVisible(event_hud, false)
    local event_hud_text = BlzCreateFrameByType("TEXT", "", event_hud, "", 0)
    BlzFrameSetPoint(event_hud_text, FRAMEPOINT_CENTER, event_hud, FRAMEPOINT_CENTER, 0., 0.)
    BlzFrameSetSize(event_hud_text, 0.22, 0.045)
    BlzFrameSetTextAlignment(event_hud_text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetEnable(event_hud_text, false)

    local function close(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(main, false)
        end
    end
    view.close = close

    local function on_close()
        local clicked = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(clicked, false)
            BlzFrameSetEnable(clicked, true)
        end
        close(pid)
        return false
    end

    SimpleButton.create(
        main,
        "ReplaceableTextures\\CommandButtons\\BTNCancel.blp",
        0.018,
        0.018,
        FRAMEPOINT_TOPRIGHT,
        FRAMEPOINT_TOPRIGHT,
        -0.02,
        -0.02,
        on_close,
        "Close 'ESC'",
        FRAMEPOINT_BOTTOM,
        FRAMEPOINT_TOP,
        0.,
        0.01
    )
    AddToEsc(close)
    BlzFrameSetVisible(main, false)

    local quest_frame = BlzCreateFrameByType("FRAME", "", main, "", 0)
    BlzFrameSetPoint(quest_frame, FRAMEPOINT_TOPLEFT, main, FRAMEPOINT_TOPLEFT, 0.016, 0.011)
    BlzFrameSetSize(quest_frame, 0.24, 0.38)
    BlzFrameSetEnable(quest_frame, false)

    local quest_title = BlzCreateFrame("TitleText", quest_frame, 0, 0)
    BlzFrameSetPoint(quest_title, FRAMEPOINT_TOP, quest_frame, FRAMEPOINT_TOP, 0., -0.04)
    BlzFrameSetEnable(quest_title, false)
    BlzFrameSetText(quest_title, "|cffffcc00Quests|r")

    local reroll_quests = SimpleButton.create(
        quest_frame,
        "ReplaceableTextures\\CommandButtons\\BTNConvert.blp",
        0.025,
        0.025,
        FRAMEPOINT_BOTTOM,
        FRAMEPOINT_BOTTOM,
        -0.005,
        0.044,
        nil,
        "Reroll all quests once per rotation for a cost."
            .. "\n|cffff0000Unavailable after completing a quest and cancels any active quest!|r"
    )
    local reroll_icon = BlzCreateFrameByType("BACKDROP", "", reroll_quests.frame, "", 0)
    BlzFrameSetPoint(reroll_icon, FRAMEPOINT_LEFT, reroll_quests.frame, FRAMEPOINT_RIGHT, 0., 0.)
    BlzFrameSetSize(reroll_icon, 0.014, 0.014)
    BlzFrameSetTexture(reroll_icon, "ShopFactionPoints.dds", 0, true)
    local reroll_cost = BlzCreateFrameByType("TEXT", "", reroll_icon, "", 0)
    BlzFrameSetPoint(reroll_cost, FRAMEPOINT_LEFT, reroll_icon, FRAMEPOINT_RIGHT, 0.004, 0.)
    BlzFrameSetText(reroll_cost, tostring(Quest.getRerollCost()))
    reroll_quests:onClick(function()
        local clicked = BlzGetTriggerFrame()
        local pid = GetPlayerId(GetTriggerPlayer()) + 1
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetEnable(clicked, false)
            BlzFrameSetEnable(clicked, true)
        end
        Quest.reroll(pid)
    end)

    local rotation_text = BlzCreateFrameByType("TEXT", "", quest_frame, "", 0)
    BlzFrameSetPoint(rotation_text, FRAMEPOINT_BOTTOM, quest_frame, FRAMEPOINT_BOTTOM, 0., 0.02)
    BlzFrameSetTextAlignment(rotation_text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_MIDDLE)
    BlzFrameSetScale(rotation_text, 0.85)
    BlzFrameSetEnable(rotation_text, false)

    local difficulties = { "easy", "medium", "hard" }
    local colors = { "|cff6be038", "|cffffcf3e", "|cffea1111" }
    for index = 1, 3 do
        local capture_index = index
        local box = {}
        local parent = index == 1 and quest_frame or boxes[index - 1].container
        local point = index == 1 and FRAMEPOINT_TOPLEFT or FRAMEPOINT_BOTTOMLEFT
        local x_offset = index == 1 and 0.05 or 0.
        local y_offset = index == 1 and -0.0175 or 0.

        box.container = BlzCreateFrameByType("FRAME", "", quest_frame, "", 0)
        BlzFrameSetPoint(box.container, FRAMEPOINT_TOPLEFT, parent, point, x_offset, y_offset)
        BlzFrameSetTexture(box.container, "trans32.blp", 0, true)
        BlzFrameSetSize(box.container, 0.001, 0.075)
        BlzFrameSetEnable(box.container, false)

        box.icon = SimpleButton.create(
            box.container,
            "ReplaceableTextures\\CommandButtons\\BTNTemp.blp",
            0.03,
            0.03,
            FRAMEPOINT_TOPLEFT,
            FRAMEPOINT_BOTTOMLEFT,
            0,
            0
        )
        box.icon:makeTooltip(FRAMEPOINT_TOPRIGHT, 0.2)
        box.icon:onClick(function()
            local clicked = BlzGetTriggerFrame()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetEnable(clicked, false)
                BlzFrameSetEnable(clicked, true)
            end
            Quest.select(pid, capture_index)
        end)

        box.text = BlzCreateFrameByType("TEXT", "", box.container, "", 0)
        BlzFrameSetScale(box.text, 0.9)
        BlzFrameSetPoint(box.text, FRAMEPOINT_LEFT, box.icon.frame, FRAMEPOINT_RIGHT, 0.004, 0)

        box.diff = BlzCreateFrame("TitleText", box.container, 0, 0)
        BlzFrameSetPoint(box.diff, FRAMEPOINT_TOP, box.icon.frame, FRAMEPOINT_BOTTOM, 0., -0.004)
        BlzFrameSetEnable(box.diff, false)
        BlzFrameSetScale(box.diff, 0.5)
        BlzFrameSetText(box.diff, colors[index] .. difficulties[index] .. "|r")
        boxes[index] = box
    end

    function view.onSelected(faction, pid)
        if GetLocalPlayer() == Player(pid - 1) then
            SelectUnit(faction.leader, false)
        end
    end

    function view.promptJoin(faction, pid, callback)
        return PromptFrame.create(pid, {
            name = "|cffffffff" .. faction.name .. "|r",
            desc = faction.desc
                .. "\n\n|cffffcc00Joining begins a 10-minute faction-change cooldown.|r",
            func = callback,
        })
    end

    function view.promptSwitch(current, faction, pid, callback)
        return PromptFrame.create(pid, {
            name = "|cffffffffJoin " .. faction.name .. "?|r",
            desc = "Leave the " .. current.name .. " and join the " .. faction.name
                .. "? Your rank and unspent Faction Points in both factions are retained."
                .. " Any active faction quest will be abandoned."
                .. "\n\n|cffffcc00Changing factions begins a 10-minute cooldown.|r",
            func = callback,
        })
    end

    function view.display(faction, pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(main, true)
        end
        PLAYER_SELECTED_UNIT[pid] = nil
    end

    function view.refreshFaction(faction, pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local buff = faction.buff
        local lifetime_points = Faction.getReputation(pid, faction.id)
        local rank = Faction.getRank(lifetime_points)
        local next_threshold = Faction.getNextRankThreshold(lifetime_points)
        local switch_remaining = math.max(0, math.ceil(Faction.getSwitchRemaining(pid)))
        local switch_status = switch_remaining > 0
            and string.format("%d:%02d", switch_remaining // 60, switch_remaining % 60)
            or "|cff80ff80Ready|r"
        local lifetime_line
        if next_threshold then
            lifetime_line = lifetime_points .. " / " .. next_threshold
        else
            lifetime_line = lifetime_points .. " |cff80ff80(MAX)|r"
        end
        BlzFrameSetText(rank_count, "|cffffcc00" .. rank .. "|r")
        faction_icon:icon(faction.icon)
        local faction_bulletins = bulletins[faction.id]
        local current_bulletin = bulletin_index[pid] or 1
        BlzFrameSetText(bulletin_text, faction_bulletins[
                            (current_bulletin - 1) % #faction_bulletins + 1])
        rank_icon:setTooltipName("Rank " .. rank)
        rank_icon:setTooltipText(faction.name .. " Rank " .. rank .. " of "
            .. Faction.getMaxRank() .. ".\n\n|cffffcc00Lifetime Faction Points:|r "
            .. lifetime_line)
        buff_icon:icon(buff.ICON)
        buff_icon:setTooltipIcon(buff.ICON)
        buff_icon:setTooltipName(buff.NAME)
        buff_icon:setTooltipText(buff.DESC_FACTION)
        BlzFrameSetText(buff_blurb, "|cffffcc00" .. buff.NAME .. "|r\n\n" .. buff.DESC_FACTION)
        BlzFrameSetTextAlignment(buff_blurb, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_CENTER)
        local show_bounty = faction.id == 3 and AshenVanguardServices ~= nil
        BlzFrameSetVisible(bounty_frame, show_bounty)
        BlzFrameClearAllPoints(blurb)
        if show_bounty then
            local renown, required, stacks, maximum, remaining =
                AshenVanguardServices.getBountyState()
            BlzFrameSetMinMaxValue(bounty_bar, 0., required)
            BlzFrameSetValue(bounty_bar, math.min(renown, required))
            BlzFrameSetText(bounty_progress, "Hunt Renown: " ..
                                math.min(renown, required) .. " / " .. required)
            local bounty_state
            if rank < 4 then
                bounty_state = "Unlocks at Rank 4 | Stored: " .. stacks ..
                                   " / " .. maximum
            elseif stacks >= maximum then
                bounty_state = "Stored: " .. stacks .. " / " .. maximum ..
                                   " | |cff80ff80Full|r"
            elseif renown < required then
                bounty_state = "Stored: " .. stacks .. " / " .. maximum
            elseif remaining > 0. then
                local seconds = math.ceil(remaining)
                bounty_state = "Stored: " .. stacks .. " / " .. maximum ..
                                   " | Available in " ..
                                   string.format("%d:%02d", seconds // 60,
                                                 seconds % 60)
            else
                bounty_state = "Stored: " .. stacks .. " / " .. maximum ..
                                   " | |cff80ff80Ready at Quartermaster|r"
            end
            BlzFrameSetText(bounty_status, bounty_state)
            BlzFrameSetPoint(blurb, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP,
                             0.01, -0.367)
            BlzFrameSetScale(blurb, 0.78)
        else
            BlzFrameSetPoint(blurb, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP,
                             0.01, -0.302)
            BlzFrameSetScale(blurb, 0.9)
        end
        BlzFrameSetText(blurb, "|cffffcc00Lifetime Faction Points:|r " .. lifetime_line
            .. (next_threshold and "\n|cffffcc00Next Rank:|r "
                .. (next_threshold - lifetime_points) .. " Points" or "")
            .. "\n|cffffcc00Unspent Faction Points:|r " .. GetCurrency(pid, FACTION)
            .. "\n|cffffcc00Faction Change:|r " .. switch_status)
        BlzFrameSetTextAlignment(blurb, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
        BlzFrameSetText(title, "|cffffcc00" .. faction.name .. "|r")
    end

    function view.refreshQuest(pid, index, quest)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local box = boxes[index]
        box.icon:icon(quest.icon)
        BlzFrameSetText(box.text, quest.name)
        box.icon:setTooltipIcon(quest.icon)
        box.icon:setTooltipText(quest.desc)
        box.icon:setTooltipName(quest.name)
    end

    function view.refreshBulletin(pid)
        bulletin_index[pid] = (bulletin_index[pid] or 0) + 1
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local faction = Faction.getFaction(pid)
        if not faction then return end
        local faction_bulletins = bulletins[faction.id]
        BlzFrameSetText(bulletin_text, faction_bulletins[
                            (bulletin_index[pid] - 1) % #faction_bulletins + 1])
    end

    function view.promptQuest(quest, pid, callback)
        return PromptFrame.create(pid, {
            name = quest.name,
            desc = quest.desc,
            func = callback,
        })
    end

    function view.questAccepted(pid, accepted, quests)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        for index = 1, 3 do
            if index ~= accepted.diff then
                local quest = quests[index]
                boxes[index].icon:icon(
                    "ReplaceableTextures\\CommandButtonsDisabled\\DIS" .. quest.icon:sub(36)
                )
                BlzFrameSetText(boxes[index].text, "|cff808080" .. quest.name .. "|r")
            end
        end
    end

    function view.refreshProgress(pid, quest, progress)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local box = boxes[quest.diff]
        local display_progress = Quest.formatProgress(progress)
        BlzFrameSetText(box.text, "|cffffcc00" .. quest.name .. "|r\n"
            .. display_progress .. " / " .. quest.goal)
        box.icon:setTooltipText(quest.desc .. "\n\n|cffffcc00Progress:|r "
            .. display_progress .. " / " .. quest.goal)
    end

    function view.questCompleted(pid, quest)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local box = boxes[quest.diff]
        box.icon:icon("ReplaceableTextures\\CommandButtonsDisabled\\DIS" .. quest.icon:sub(36))
        BlzFrameSetText(box.text, "|cff808080" .. quest.name .. "\nCompleted|r")
        box.icon:setTooltipText(quest.desc .. "\n\n|cff80ff80Completed. A new quest arrives with the next rotation.|r")
    end

    function view.refreshRotation(pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local remaining = math.max(0, math.ceil(Quest.getRotationRemaining(pid)))
        local minutes = remaining // 60
        local seconds = remaining % 60
        BlzFrameSetText(rotation_text, string.format("Quests refresh in: %d:%02d", minutes, seconds))
        reroll_quests:enable(Quest.canReroll(pid))
    end

    function view.refreshEvent(pid)
        if GetLocalPlayer() ~= Player(pid - 1) then return end
        local presentation = FactionEvents.getPresentation(pid)
        if presentation then
            event_icon:icon(presentation.icon)
            event_icon:setTooltipIcon(presentation.icon)
            event_icon:setTooltipName(presentation.name)
            event_icon:setTooltipText(presentation.description)
        end
        BlzFrameSetText(event_blurb, FactionEvents.getStatus(pid))
        local countdown = FactionEvents.getCountdown(pid)
        BlzFrameSetVisible(event_timer, countdown ~= nil)
        if countdown then
            BlzFrameSetText(event_timer, countdown)
        end
        local hud_status = FactionEvents.getHudStatus(pid)
        BlzFrameSetVisible(event_hud, hud_status ~= nil)
        if hud_status then
            BlzFrameSetText(event_hud_text, hud_status)
        end
    end

    TimerQueue:callPeriodically(1., nil, function()
        local user = User.first
        while user do
            if GetLocalPlayer() == user.player then
                local faction = Faction.getFaction(user.id)
                if faction then
                    view.refreshFaction(faction, user.id)
                end
                view.refreshRotation(user.id)
                view.refreshEvent(user.id)
            end
            user = user.next
        end
    end)

    ---@cast view FactionViewAdapter
    Faction.bindView(view)
end, Debug and Debug.getLine())
