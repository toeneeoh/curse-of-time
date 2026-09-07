-- Faction membership and quest presentation.

OnInit.final("FactionView", function(Require)
    Require('Faction')
    Require('Frames')
    Require('Prompt')
    Require('SimpleButton')
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
    BlzFrameSetPoint(blurb, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0.01, -0.07)
    BlzFrameSetEnable(blurb, false)
    BlzFrameSetSize(blurb, 0.19, 1.0)

    local buff_frame = BlzCreateFrameByType("FRAME", "", main, "", 0)
    BlzFrameSetPoint(buff_frame, FRAMEPOINT_TOPRIGHT, main, FRAMEPOINT_TOPRIGHT, -0.02, 0.016)
    BlzFrameSetSize(buff_frame, 0.24, 0.38)
    BlzFrameSetEnable(buff_frame, false)

    local buff_title = BlzCreateFrame("TitleText", buff_frame, 0, 0)
    BlzFrameSetPoint(buff_title, FRAMEPOINT_TOP, buff_frame, FRAMEPOINT_TOP, 0., -0.046)
    BlzFrameSetEnable(buff_title, false)
    BlzFrameSetText(buff_title, "|cffffffffBuff|r")

    local buff_blurb = BlzCreateFrameByType("TEXT", "", buff_frame, "", 0)
    BlzFrameSetPoint(buff_blurb, FRAMEPOINT_TOP, buff_frame, FRAMEPOINT_TOP, 0., -0.15)
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
    BlzFrameSetText(event_title, "|cffffffffEvent|r")

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
    BlzFrameSetText(quest_title, "|cffffffffQuests|r")

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
        "Reroll all quests for a cost.\n|cffff0000Cancels any active quests!|r"
    )
    local reroll_icon = BlzCreateFrameByType("BACKDROP", "", reroll_quests.frame, "", 0)
    BlzFrameSetPoint(reroll_icon, FRAMEPOINT_LEFT, reroll_quests.frame, FRAMEPOINT_RIGHT, 0., 0.)
    BlzFrameSetSize(reroll_icon, 0.014, 0.014)
    BlzFrameSetTexture(reroll_icon, "ShopFactionPoints.dds", 0, true)
    local reroll_cost = BlzCreateFrameByType("TEXT", "", reroll_icon, "", 0)
    BlzFrameSetPoint(reroll_cost, FRAMEPOINT_LEFT, reroll_icon, FRAMEPOINT_RIGHT, 0.004, 0.)
    BlzFrameSetText(reroll_cost, "0")

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
        buff_icon:icon(buff.ICON)
        BlzFrameSetText(buff_blurb, "|cffffcc00" .. buff.NAME .. "|r\n\n" .. buff.DESC_FACTION)
        BlzFrameSetTextAlignment(buff_blurb, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_CENTER)
        BlzFrameSetText(blurb, "|cffffcc00Reputation:|r 0")
        BlzFrameSetText(title, "|cffffffff" .. faction.name .. "|r")
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

    ---@cast view FactionViewAdapter
    Faction.bindView(view)
end, Debug and Debug.getLine())
