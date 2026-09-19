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
    BlzFrameSetPoint(blurb, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0.01, -0.105)
    BlzFrameSetEnable(blurb, false)
    BlzFrameSetSize(blurb, 0.19, 1.0)

    local status_title = BlzCreateFrame("TitleText", main, 0, 0)
    BlzFrameSetPoint(status_title, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0.01, -0.062)
    BlzFrameSetEnable(status_title, false)
    BlzFrameSetText(status_title, "|cffffcc00Faction Status|r")

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
        -0.09
    )

    local event_frame = BlzCreateFrameByType("FRAME", "", main, "", 0)
    BlzFrameSetPoint(event_frame, FRAMEPOINT_TOPRIGHT, main, FRAMEPOINT_TOPRIGHT, -0.01, -0.143)
    BlzFrameSetSize(event_frame, 0.24, 0.38)
    BlzFrameSetEnable(event_frame, false)

    local event_title = BlzCreateFrame("TitleText", event_frame, 0, 0)
    BlzFrameSetPoint(event_title, FRAMEPOINT_TOP, event_frame, FRAMEPOINT_TOP, -0.01, -0.05)
    BlzFrameSetEnable(event_title, false)
    BlzFrameSetText(event_title, "|cffffcc00Hourly Event|r")

    local event_blurb = BlzCreateFrameByType("TEXT", "", event_frame, "", 0)
    BlzFrameSetPoint(event_blurb, FRAMEPOINT_TOP, event_frame, FRAMEPOINT_TOP, -0.01, -0.095)
    BlzFrameSetSize(event_blurb, 0.2, 0.12)
    BlzFrameSetTextAlignment(event_blurb, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_TOP)
    BlzFrameSetEnable(event_blurb, false)
    BlzFrameSetText(event_blurb,
        "|cff808080Events become available after Chaos.|r")

    local function close(pid)
        if GetLocalPlayer() == Player(pid - 1) then
            BlzFrameSetVisible(main, false)
        end
    end

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
        0.015,
        0.015,
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
        "Reroll all quests once per rotation for a cost.\n|cffff0000Cancels any active quest!|r"
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
            desc = faction.desc,
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
        local reputation = Faction.getReputation(pid, faction.id)
        local rank = Faction.getRank(reputation)
        local next_threshold = Faction.getNextRankThreshold(reputation)
        local active_quest, progress = Quest.getActive(pid)
        local reputation_line
        if next_threshold then
            reputation_line = reputation .. " / " .. next_threshold
        else
            reputation_line = reputation .. " |cff80ff80(MAX)|r"
        end
        local quest_line = "|cff808080None selected|r"
        if active_quest then
            quest_line = active_quest.name .. "\n|cffffcc00Progress:|r "
                .. progress .. " / " .. active_quest.goal
        end
        buff_icon:icon(buff.ICON)
        BlzFrameSetText(buff_blurb, "|cffffcc00" .. buff.NAME .. "|r\n\n" .. buff.DESC_FACTION)
        BlzFrameSetTextAlignment(buff_blurb, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_CENTER)
        BlzFrameSetText(blurb, "|cffffcc00Rank:|r " .. rank .. " / " .. Faction.getMaxRank()
            .. "\n|cffffcc00Reputation:|r " .. reputation_line
            .. (next_threshold and "\n|cffffcc00Next Rank:|r "
                .. (next_threshold - reputation) .. " Reputation" or "")
            .. "\n|cffffcc00Faction Points:|r " .. GetCurrency(pid, FACTION)
            .. "\n\n|cffffcc00Active Quest|r\n" .. quest_line)
        BlzFrameSetTextAlignment(blurb, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_TOP)
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
        BlzFrameSetText(box.text, "|cffffcc00" .. quest.name .. "|r\n"
            .. progress .. " / " .. quest.goal)
        box.icon:setTooltipText(quest.desc .. "\n\n|cffffcc00Progress:|r "
            .. progress .. " / " .. quest.goal)
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
        BlzFrameSetText(event_blurb, FactionEvents.getStatus(pid))
    end

    TimerQueue:callPeriodically(1., nil, function()
        local user = User.first
        while user do
            if GetLocalPlayer() == user.player then
                view.refreshRotation(user.id)
                view.refreshEvent(user.id)
            end
            user = user.next
        end
    end)

    ---@cast view FactionViewAdapter
    Faction.bindView(view)
end, Debug and Debug.getLine())
