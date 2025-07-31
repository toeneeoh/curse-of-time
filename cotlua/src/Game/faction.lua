--[[
    faction.lua

    Implementation of factions
]]

OnInit.final("Faction", function(Require)
    Require('Events')
    Require('Buffs')
    local fl_type = FourCC('n000')
    local Faction, Quest

    ---@class Faction
    ---@field name string
    ---@field desc string
    ---@field create function
    ---@field addQuest function
    ---@field getFaction function
    ---@field refreshQuests function
    ---@field quests table
    ---@field main framehandle
    ---@field frame framehandle
    ---@field leader unit
    Faction = {} ---@type Faction | Faction[]
    do
        local thistype = Faction
        local mt = { __index = Faction }
        local player_faction = {}
        local temp_faction = {}
        local display_window ---@type function

        -- frame setup
        local main = BlzCreateFrameByType("FRAME", "", BlzGetFrameByName("ConsoleUIBackdrop", 0), "", 0)
        BlzFrameSetAbsPoint(main, FRAMEPOINT_TOP, 0.4, 0.53)
        --BlzFrameSetTexture(main, "trans32.blp", 0, true)
        BlzFrameSetSize(main, 0.75, 0.35)
        BlzFrameSetEnable(main, false)
        thistype.main = main

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

        local buff_icon = SimpleButton.create(buff_frame, "ReplaceableTextures\\CommandButtons\\BTNTemp.blp", 0.04, 0.04, FRAMEPOINT_TOP, FRAMEPOINT_TOP, 0., -0.09)

        local event_frame = BlzCreateFrameByType("FRAME", "", main, "", 0)
        BlzFrameSetPoint(event_frame, FRAMEPOINT_TOPRIGHT, main, FRAMEPOINT_TOPRIGHT, -0.01, -0.143)
        BlzFrameSetSize(event_frame, 0.24, 0.38)
        BlzFrameSetEnable(event_frame, false)

        local event_title = BlzCreateFrame("TitleText", event_frame, 0, 0)
        BlzFrameSetPoint(event_title, FRAMEPOINT_TOP, event_frame, FRAMEPOINT_TOP, -0.01, -0.05)
        BlzFrameSetEnable(event_title, false)
        BlzFrameSetText(event_title, "|cffffffffEvent|r")

        local function join_faction(pid)
            player_faction[pid] = temp_faction[pid]
            DisplayTextToForce(FORCE_PLAYING, User[pid - 1].nameColored .. " has joined the " .. player_faction[pid].name .. "!")
            temp_faction[pid] = nil
            display_window(player_faction[pid], pid)
            player_faction[pid].buff:add(Hero[pid], Hero[pid])

            return false
        end

        local close = function(pid)
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetVisible(main, false)
            end
        end

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
        local esc_button = SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.02, -0.02, onClose, "Close 'ESC'", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)
        AddToEsc(close) --- close window hotkey reference

        BlzFrameSetVisible(main, false)
        -- end frame setup

        display_window = function(fac, pid)
            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetVisible(main, true)
            end
            PLAYER_SELECTED_UNIT[pid] = nil

            Quest.setup(pid)
            fac:refresh(pid)
        end

        local function on_click(u, pid)
            local fac = thistype[u]

            -- ignore if no hero or not in range
            if not Hero[pid] or not IsUnitInRange(fac.leader, Hero[pid], 1000.) then
                return
            end

            if GetLocalPlayer() == Player(pid - 1) then
                SelectUnit(fac.leader, false)
            end

            if not player_faction[pid] then
                if PromptFrame.create(pid, { name = "|cffffffff" .. fac.name .. "|r", desc = fac.desc, func = join_faction }) then
                    temp_faction[pid] = fac
                end
            else
                display_window(fac, pid)
            end
        end

        function thistype.getFaction(pid)
            return player_faction[pid]
        end

        ---@type fun(self: Faction, pid: integer)
        function thistype:refreshQuests(pid)
            -- pick one random quest for each diff
            for i = 1, 3 do
                local quest = self:pickQuest(i)
                Quest.quests[pid][i] = quest

                -- update visual locally
                if GetLocalPlayer() == Player(pid - 1) then
                    Quest.boxes[i].icon:icon(quest.icon)
                    BlzFrameSetText(Quest.boxes[i].text, quest.name)
                    Quest.boxes[i].icon:setTooltipIcon(quest.icon)
                    Quest.boxes[i].icon:setTooltipText(quest.desc)
                    Quest.boxes[i].icon:setTooltipName(quest.name)
                end
            end
        end

        ---@type fun(self: Faction, quest: Quest)
        function thistype:addQuest(quest)
            self.quests[#self.quests + 1] = quest
        end

        ---@type fun(self: Faction, diff: integer): Quest
        function thistype:pickQuest(diff)
            local potential_quests = {}

            for _, v in ipairs(self.quests) do
                if v.diff == diff then
                    potential_quests[#potential_quests + 1] = v
                end
            end

            return potential_quests[math.random(1, #potential_quests)]
        end

        function thistype:refresh(pid)
            local buffid = player_faction[pid].buff.RAWCODE

            if GetLocalPlayer() == Player(pid - 1) then
                buff_icon:icon(BlzGetAbilityIcon(buffid))
                BlzFrameSetText(buff_blurb, "|cffffcc00" .. GetAbilityName(buffid) .. "|r\n\n" .. BlzGetAbilityExtendedTooltip(buffid, 0))
                BlzFrameSetTextAlignment(buff_blurb, TEXT_JUSTIFY_LEFT, TEXT_JUSTIFY_CENTER)
                BlzFrameSetText(blurb, "|cffffcc00Reputation:|r 0")
                BlzFrameSetText(title, "|cffffffff" .. player_faction[pid].name .. "|r")
            end
        end

        function thistype.create(name, x, y, buff, desc)
            local self = setmetatable({}, mt)

            self.leader = CreateUnit(Player(PLAYER_NEUTRAL_PASSIVE), fl_type, x, y, 270.)
            self.name = name
            self.quests = {}
            self.buff = buff
            self.desc = desc

            EVENT_ON_UNIT_SELECT:register_unit_action(self.leader, on_click)

            thistype[self.leader] = self

            return self
        end
    end

    local QUEST_DIFF_EASY = 1
    local QUEST_DIFF_MEDIUM = 2
    local QUEST_DIFF_HARD = 3

    ---@class Quest
    ---@field create function
    ---@field setup function
    ---@field name string
    ---@field desc string
    ---@field icon string
    ---@field diff integer
    ---@field boxes table[]
    ---@field quests Quest[]
    Quest = {}
    do
        local thistype = Quest
        local mt = { __index = Quest }
        local count = 1
        local boxes = {}
        local quests = {}
        local temp_quest = {}
        local active_quest = {}
        local quest_on_click_factory

        thistype.quests = quests
        thistype.boxes = boxes

        function thistype.create(name, desc, icon, diff)
            local self = setmetatable({}, mt)

            self.id = count
            self.name = name
            self.desc = desc
            self.icon = icon
            self.diff = diff

            thistype[count] = self
            count = count + 1

            return self
        end

        function thistype:on_accept(pid)
            print("quest accepted:", self.name, pid)
        end

        function thistype.setup(pid)
            if not quests[pid] then
                quests[pid] = {}
                Faction.getFaction(pid):refreshQuests(pid)
            end
        end

        local accept_quest = function(pid)
            local q = temp_quest[pid]
            active_quest[pid] = q
            temp_quest[pid] = nil

            for i = 1, 3 do
                if i ~= q.diff then
                    if GetLocalPlayer() == Player(pid - 1) then
                        boxes[i].icon:icon("ReplaceableTextures\\CommandButtonsDisabled\\DIS" .. quests[pid][i].icon:sub(36))
                        BlzFrameSetText(boxes[i].text, "|cff808080" .. quests[pid][i].name .. "|r")
                    end
                end
            end

            q:on_accept(pid)
        end

        do
            local index = 1
            quest_on_click_factory = function()
                local capture_index = index

                local f = function()
                    local f = BlzGetTriggerFrame()
                    local pid = GetPlayerId(GetTriggerPlayer()) + 1

                    if GetLocalPlayer() == Player(pid - 1) then
                        BlzFrameSetEnable(f, false)
                        BlzFrameSetEnable(f, true)
                    end

                    local q = quests[pid][capture_index]
                    if not active_quest[pid] then
                        if PromptFrame.create(pid, { name = q.name, desc = q.desc, func = accept_quest}) then
                            temp_quest[pid] = q
                        end
                    end
                end

                index = index + 1

                return f
            end
        end

        -- frame setup
        local quest_frame = BlzCreateFrameByType("FRAME", "", Faction.main, "", 0)
        BlzFrameSetPoint(quest_frame, FRAMEPOINT_TOPLEFT, Faction.main, FRAMEPOINT_TOPLEFT, 0.016, 0.011)
        BlzFrameSetSize(quest_frame, 0.24, 0.38)
        BlzFrameSetEnable(quest_frame, false)

        local quest_title = BlzCreateFrame("TitleText", quest_frame, 0, 0)
        BlzFrameSetPoint(quest_title, FRAMEPOINT_TOP, quest_frame, FRAMEPOINT_TOP, 0., -0.04)
        BlzFrameSetEnable(quest_title, false)
        BlzFrameSetText(quest_title, "|cffffffffQuests|r")

        local reroll_quests = SimpleButton.create(quest_frame, "ReplaceableTextures\\CommandButtons\\BTNConvert.blp", 0.025, 0.025, FRAMEPOINT_BOTTOM, FRAMEPOINT_BOTTOM, -0.005, 0.044, nil, "Reroll all quests for a cost.\n|cffff0000Cancels any active quests!|r")
        local reroll_icon = BlzCreateFrameByType("BACKDROP", "", reroll_quests.frame, "", 0)
        BlzFrameSetPoint(reroll_icon, FRAMEPOINT_LEFT, reroll_quests.frame, FRAMEPOINT_RIGHT, 0., 0.)
        BlzFrameSetSize(reroll_icon, 0.014, 0.014)
        BlzFrameSetTexture(reroll_icon, "ShopFactionPoints.dds", 0, true)
        local reroll_cost = BlzCreateFrameByType("TEXT", "", reroll_icon, "", 0)
        BlzFrameSetPoint(reroll_cost, FRAMEPOINT_LEFT, reroll_icon, FRAMEPOINT_RIGHT, 0.004, 0.)
        BlzFrameSetText(reroll_cost, "0")

        local diffs = {"easy", "medium", "hard"}
        local colors = {"|cff6be038", "|cffffcf3e", "|cffea1111"}

        for i = 1, 3 do
            local box = {}
            local parent = quest_frame
            local x_offset = 0.05
            local y_offset = -0.0175
            local framepoint = FRAMEPOINT_TOPLEFT
            if i ~= 1 then
                parent = boxes[i - 1].container
                x_offset = 0
                y_offset = 0
                framepoint = FRAMEPOINT_BOTTOMLEFT
            end
            box.container = BlzCreateFrameByType("FRAME", "", quest_frame, "", 0)
            BlzFrameSetPoint(box.container, FRAMEPOINT_TOPLEFT, parent, framepoint, x_offset, y_offset)
            BlzFrameSetTexture(box.container, "trans32.blp", 0, true)
            BlzFrameSetSize(box.container, 0.001, 0.075)
            BlzFrameSetEnable(box.container, false)

            box.icon = SimpleButton.create(box.container, "ReplaceableTextures\\CommandButtons\\BTNTemp.blp", 0.03, 0.03, FRAMEPOINT_TOPLEFT, FRAMEPOINT_BOTTOMLEFT, 0, 0)
            box.icon:makeTooltip(FRAMEPOINT_TOPRIGHT, 0.2)
            box.icon:onClick(quest_on_click_factory())

            box.text = BlzCreateFrameByType("TEXT", "", box.container, "", 0)
            BlzFrameSetScale(box.text, 0.9)
            BlzFrameSetPoint(box.text, FRAMEPOINT_LEFT, box.icon.frame, FRAMEPOINT_RIGHT, 0.004, 0)

            box.diff = BlzCreateFrame("TitleText", box.container, 0, 0)
            BlzFrameSetPoint(box.diff, FRAMEPOINT_TOP, box.icon.frame, FRAMEPOINT_BOTTOM, 0., -0.004)
            BlzFrameSetEnable(box.diff, false)
            BlzFrameSetScale(box.diff, 0.5)
            BlzFrameSetText(box.diff, colors[i] .. diffs[i] .. "|r")

            boxes[i] = box
        end
        --
    end

    local miner_guild = Faction.create("Cave Voyagers", 15000, 10500, HardHatBuff, "The Cave Voyagers are a mining faction that provide access to earth materials and a special defensive buff.|n|n|cffff0000All faction progress is saved and you may leave after 60 minutes.|r|n|nWill you join us?")
    local enter_colo = Quest.create("Enter Colosseum", "Your task is complete upon entering the Colosseum located in town.", "ReplaceableTextures\\CommandButtons\\BTNHelmutPurple.blp", QUEST_DIFF_EASY)
    local temp_mid = Quest.create("Temp medium", "Your task is blablablablablablablal", "ReplaceableTextures\\CommandButtons\\BTNTemp.blp", QUEST_DIFF_MEDIUM)
    local temp_hard = Quest.create("Temp hard", "Your task is blbalbalbalbalbalbalbal", "ReplaceableTextures\\CommandButtons\\BTNTemp.blp", QUEST_DIFF_HARD)
    miner_guild:addQuest(enter_colo)
    miner_guild:addQuest(temp_mid)
    miner_guild:addQuest(temp_hard)

end, Debug and Debug.getLine())
