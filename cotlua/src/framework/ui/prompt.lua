OnInit.final("Prompt", function(Require)

    Require("SimpleButton")

    ---@class PromptFrame
    PromptFrame = {}
    do
        local prompt_queue = {}

        -- frame setup
        local main = BlzCreateFrame("QuestButtonDisabledBackdropTemplate", BlzGetFrameByName("ConsoleUIBackdrop", 0), 0, 0)
        BlzFrameSetAbsPoint(main, FRAMEPOINT_TOP, 0.4, 0.48)
        BlzFrameSetSize(main, 0.25, 0.20)
        BlzFrameSetEnable(main, false)
        BlzFrameSetLevel(main, 20)

        local title = BlzCreateFrame("TitleText", main, 0, 0)
        BlzFrameSetPoint(title, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0., -0.028)
        BlzFrameSetEnable(title, false)

        local blurb = BlzCreateFrameByType("TEXT", "", main, "", 0)
        BlzFrameSetPoint(blurb, FRAMEPOINT_TOP, main, FRAMEPOINT_TOP, 0., -0.06)
        BlzFrameSetEnable(blurb, false)
        BlzFrameSetSize(blurb, 0.2, 1.0)

        BlzFrameSetVisible(main, false)
        --

        local function refresh(pid)
            local q = prompt_queue[pid][1]

            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetText(title, "|cffffffff" .. q.name .. "|r")
                BlzFrameSetText(blurb, q.desc)
                BlzFrameSetVisible(main, true)
            end
        end

        local close = function(pid)
            -- shift queue positions
            local q = prompt_queue[pid]
            for i = 1, #q do
                q[i] = q[i + 1]
            end

            if q[1] then
                refresh(pid)
            else
                if GetLocalPlayer() == Player(pid - 1) then
                    BlzFrameSetVisible(main, false)
                end
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

        local onAccept = function()
            local f = BlzGetTriggerFrame()
            local pid = GetPlayerId(GetTriggerPlayer()) + 1

            if GetLocalPlayer() == Player(pid - 1) then
                BlzFrameSetEnable(f, false)
                BlzFrameSetEnable(f, true)
            end

            prompt_queue[pid][1].func(pid)
            close(pid)

            return false
        end

        local accept = SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNcheck.blp", 0.025, 0.025, FRAMEPOINT_TOP, FRAMEPOINT_TOP, 0., -0.15, onAccept)
        local exit = SimpleButton.create(main, "ReplaceableTextures\\CommandButtons\\BTNCancel.blp", 0.015, 0.015, FRAMEPOINT_TOPRIGHT, FRAMEPOINT_TOPRIGHT, -0.02, -0.02, onClose, "Close", FRAMEPOINT_BOTTOM, FRAMEPOINT_TOP, 0., 0.01)

        ---@type fun(pid: integer, t: table): boolean
        function PromptFrame.create(pid, t)
            if not prompt_queue[pid] then
                prompt_queue[pid] = {}
            end

            -- ignore duplicate functions
            local q = prompt_queue[pid]
            for i = 1, #q do
                if q[i].func == t.func then
                    return false
                end
            end

            -- add to queue
            prompt_queue[pid][#prompt_queue[pid] + 1] = t

            refresh(pid)

            return true
        end
    end
end, Debug and Debug.getLine())
