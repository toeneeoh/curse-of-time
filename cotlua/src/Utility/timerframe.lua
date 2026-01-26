OnInit.global("TimerFrame", function(Require)
    Require('TimerQueue')
    local TQ = TimerQueue

    ---@class TimerFrame
    ---@field running boolean
    ---@field stop function
    ---@field create function
    ---@field update function
    ---@field destroy function
    ---@field expire function
    ---@field frame framehandle
    ---@field text framehandle
    ---@field timer integer
    ---@field time integer
    ---@field title string
    ---@field trig trigger
    ---@field minimize framehandle
    ---@field minimize_frame framehandle
    ---@field playerGroup table
    TimerFrame = {}
    do
        local thistype = TimerFrame
        local mt = { __index = thistype }
        local date = os.date

        -- #region frame setup
        local minimize = BlzCreateFrameByType("GLUEBUTTON", "", BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), "ScoreScreenTabButtonTemplate", 0)
        local minimize_frame = BlzCreateFrameByType("BACKDROP", "", minimize, "", 0)
        local frame = BlzCreateFrame("ListBoxWar3", minimize_frame, 0, 0)
        local text = BlzCreateFrameByType("TEXT", "", frame, "", 0)

        local trig = CreateTrigger()
        BlzTriggerRegisterFrameEvent(trig, minimize, FRAMEEVENT_CONTROL_CLICK)

        local show_hide = function()
            if GetTriggerPlayer() == GetLocalPlayer() then
                BlzFrameSetEnable(BlzGetTriggerFrame(), false)
                BlzFrameSetEnable(BlzGetTriggerFrame(), true)

                if BlzFrameIsVisible(frame) then
                    BlzFrameSetVisible(frame, false)
                    BlzFrameSetTexture(minimize_frame, "war3mapImported\\minimize.blp", 0, true)
                else
                    BlzFrameSetVisible(frame, true)
                    BlzFrameSetTexture(minimize_frame, "war3mapImported\\expand.blp", 0, true)
                end
            end
        end

        BlzFrameSetSize(minimize, 0.015, 0.015)
        BlzFrameSetTexture(minimize_frame, "war3mapImported\\expand.blp", 0, true)
        BlzFrameSetTextAlignment(text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_CENTER)
        BlzFrameSetPoint(minimize, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), FRAMEPOINT_CENTER, 0, -0.154)
        BlzFrameSetAllPoints(minimize_frame, minimize)
        BlzFrameSetPoint(text, FRAMEPOINT_BOTTOM, minimize_frame, FRAMEPOINT_TOP, 0, 0.018)
        BlzFrameSetPoint(frame, FRAMEPOINT_TOPLEFT, text, FRAMEPOINT_TOPLEFT, -0.04, 0.02)
        BlzFrameSetPoint(frame, FRAMEPOINT_BOTTOMRIGHT, text, FRAMEPOINT_BOTTOMRIGHT, 0.04, -0.02)
        BlzFrameSetVisible(minimize, false)

        TriggerAddAction(trig, show_hide)
        -- #endregion

        function thistype:run()
            self.time = self.time - 1

            if self.time < 0 then
                self:stop()
            else
                self:update()
                self.timer = TQ:callDelayed(1, thistype.run, self)
            end
        end

        function thistype:destroy()
            TQ:disableCallback(self.timer)
            local pid = GetPlayerId(GetLocalPlayer()) + 1
            if TableHas(self.playerGroup, GetLocalPlayer()) or TableHas(self.playerGroup, pid) then
                BlzFrameSetVisible(minimize, false)
            end
            setmetatable(self, nil)
        end

        function thistype:stop()
            self.expire()
            self:destroy()
        end

        function thistype:update()
            BlzFrameSetText(text, self.title .. "|n" .. date("!%H:%M:%S", self.time))
        end

        function TimerFrame.create(title, time, onExpire, playerGroup)
            local self = setmetatable({
                running = true,
                expire = onExpire,
                time = time,
                title = title,
            }, mt)

            -- deep copy of playerGroup
            self.playerGroup = {}
            for _, player in ipairs(playerGroup) do
                self.playerGroup[#self.playerGroup + 1] = player
            end

            local pid = GetPlayerId(GetLocalPlayer()) + 1
            if TableHas(playerGroup, GetLocalPlayer()) or TableHas(playerGroup, pid) then
                BlzFrameSetVisible(minimize, true)
            end

            self:update()
            self.timer = TQ:callDelayed(1, thistype.run, self)

            return self
        end
    end

end, Debug and Debug.getLine())
