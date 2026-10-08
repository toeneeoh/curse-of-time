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

        local function create_frames(self)
            self.minimize = BlzCreateFrameByType("GLUEBUTTON", "", BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), "ScoreScreenTabButtonTemplate", 0)
            self.minimize_frame = BlzCreateFrameByType("BACKDROP", "", self.minimize, "", 0)
            self.frame = BlzCreateFrame("ListBoxWar3", self.minimize_frame, 0, 0)
            self.text = BlzCreateFrameByType("TEXT", "", self.frame, "", 0)
            self.trig = CreateTrigger()

            BlzTriggerRegisterFrameEvent(self.trig, self.minimize, FRAMEEVENT_CONTROL_CLICK)
            TriggerAddAction(self.trig, function()
                if GetTriggerPlayer() == GetLocalPlayer() then
                    BlzFrameSetEnable(BlzGetTriggerFrame(), false)
                    BlzFrameSetEnable(BlzGetTriggerFrame(), true)

                    if BlzFrameIsVisible(self.frame) then
                        BlzFrameSetVisible(self.frame, false)
                        BlzFrameSetTexture(self.minimize_frame, "war3mapImported\\minimize.blp", 0, true)
                    else
                        BlzFrameSetVisible(self.frame, true)
                        BlzFrameSetTexture(self.minimize_frame, "war3mapImported\\expand.blp", 0, true)
                    end
                end
            end)

            BlzFrameSetSize(self.minimize, 0.015, 0.015)
            BlzFrameSetTexture(self.minimize_frame, "war3mapImported\\expand.blp", 0, true)
            BlzFrameSetTextAlignment(self.text, TEXT_JUSTIFY_CENTER, TEXT_JUSTIFY_CENTER)
            BlzFrameSetPoint(self.minimize, FRAMEPOINT_CENTER, BlzGetOriginFrame(ORIGIN_FRAME_WORLD_FRAME, 0), FRAMEPOINT_CENTER, 0, -0.154)
            BlzFrameSetAllPoints(self.minimize_frame, self.minimize)
            BlzFrameSetPoint(self.text, FRAMEPOINT_BOTTOM, self.minimize_frame, FRAMEPOINT_TOP, 0, 0.018)
            BlzFrameSetPoint(self.frame, FRAMEPOINT_TOPLEFT, self.text, FRAMEPOINT_TOPLEFT, -0.04, 0.02)
            BlzFrameSetPoint(self.frame, FRAMEPOINT_BOTTOMRIGHT, self.text, FRAMEPOINT_BOTTOMRIGHT, 0.04, -0.02)
            BlzFrameSetVisible(self.minimize, false)
        end

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
            if self.destroyed then
                return
            end

            self.destroyed = true
            TQ:disableCallback(self.timer)
            local pid = GetPlayerId(GetLocalPlayer()) + 1
            if TableHas(self.playerGroup, GetLocalPlayer()) or TableHas(self.playerGroup, pid) then
                BlzFrameSetVisible(self.minimize, false)
            end
            DestroyTrigger(self.trig)
            BlzDestroyFrame(self.minimize)
        end

        function thistype:stop()
            self.expire()
            self:destroy()
        end

        function thistype:update()
            BlzFrameSetText(self.text, self.title .. "|n" .. date("!%H:%M:%S", self.time))
        end

        function TimerFrame.create(title, time, onExpire, playerGroup)
            local self = setmetatable({
                running = true,
                expire = onExpire,
                time = time,
                title = title,
            }, mt)

            create_frames(self)

            -- deep copy of playerGroup
            self.playerGroup = {}
            for _, player in ipairs(playerGroup) do
                self.playerGroup[#self.playerGroup + 1] = player
            end

            local pid = GetPlayerId(GetLocalPlayer()) + 1
            if TableHas(playerGroup, GetLocalPlayer()) or TableHas(playerGroup, pid) then
                BlzFrameSetVisible(self.minimize, true)
            end

            self:update()
            self.timer = TQ:callDelayed(1, thistype.run, self)

            return self
        end
    end

end, Debug and Debug.getLine())
