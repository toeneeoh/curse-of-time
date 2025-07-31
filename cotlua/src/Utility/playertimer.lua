--[[
    playertimer.lua

    Defines more specialized timers for use with spells and other unique situations where stronger callback control is required
    Player timers handle trouble when a player leaves or -repicks and will automatically clean up handles
]]

OnInit.global("PlayerTimer", function(Require)
    Require('TimerQueue')

    ---@class PlayerTimer
    ---@field create function
    ---@field destroy function
    ---@field timer TimerQueue
    ---@field ug group
    ---@field sfx effect
    ---@field curve BezierCurve
    ---@field lfx lightning
    ---@field source unit
    ---@field target unit
    ---@field range number
    ---@field agi number
    ---@field str number
    ---@field int number
    ---@field dur number
    ---@field tag any
    ---@field pid integer
    ---@field uid integer
    ---@field song integer
    ---@field dmg number
    ---@field dot number
    ---@field angle number
    ---@field aoe number
    ---@field x number
    ---@field y number
    ---@field speed number
    ---@field dist number
    ---@field armor number
    ---@field id number
    ---@field infused boolean
    ---@field limitbreak boolean
    ---@field cooldown number
    ---@field time number
    ---@field element number
    ---@field spell number
    ---@field pause boolean
    ---@field index integer
    ---@field flag integer
    ---@field onRemove function
    PlayerTimer = {}
    do
        local thistype = PlayerTimer
        local mt = { __index = PlayerTimer }

        ---@type fun(): PlayerTimer
        function thistype.create()
            local self = {
                dur = 0.,
                time = 0.,
                dmg = 0.,
                timer = TimerQueue.create()
            }

            setmetatable(self, mt)

            return self
        end

        function thistype:destroy()
            if self.onRemove then
                self:onRemove()
            end

            if self.ug then
                DestroyGroup(self.ug)
            end

            if self.sfx then
                DestroyEffect(self.sfx)
            end

            if self.lfx then
                DestroyLightning(self.lfx)
            end

            if self.timer then
                self.timer:destroy()
            end

            if self.curve then
                self.curve:destroy()
            end

            TimerList[self.pid]:removeTimer(self)
            setmetatable(self, nil)
        end
    end

    ---@class TimerList
    ---@field pid integer
    ---@field timers PlayerTimer[]
    ---@field removeTimer function
    ---@field get function
    ---@field has function
    ---@field stopAllTimers function
    ---@field add function
    ---@field create function
    TimerList = {} ---@type TimerList | TimerList[] | PlayerTimer[][]
    do
        local thistype = TimerList
        local mt = { __index = TimerList }

        -- Set metatable for the TimerList table
        setmetatable(thistype, {
            __index = function(tbl, key)
                local new = {
                    pid = key,
                    timers = {}
                }
                rawset(tbl, key, new)
                setmetatable(new, mt)
                return new
            end
        })

        ---@type fun(self: TimerList, pt: PlayerTimer)
        function thistype:removeTimer(pt)
            for i = 1, #self.timers do
                if self.timers[i] == pt then
                    self.timers[i] = self.timers[#self.timers]
                    self.timers[#self.timers] = nil
                    break
                end
            end
        end

        --[[returns first timer found
        source and target may be omitted if only looking by tag]]
        ---@type fun(self: TimerList, tag: any, source: unit?, target: unit?): PlayerTimer | nil
        function thistype:get(tag, source, target)
            for i = 1, #self.timers do
                if self.timers[i].tag == tag and (self.timers[i].target == target or not target) and (self.timers[i].source == source or not source) then
                    return self.timers[i]
                end
            end

            return nil
        end

        --source and target may be omitted if only looking by tag
        ---@type fun(self: TimerList, tag: any, source: unit?, target: unit?):boolean
        function thistype:has(tag, source, target)
            return self:get(tag, source, target) ~= nil
        end

        ---optional tag to only stop timers with such tag
        ---@type fun(self: TimerList, tag: any)
        function thistype:stopAllTimers(tag)
            local i = 1
            while i <= #self.timers do
                if (not tag) or self.timers[i].tag == tag then
                    self.timers[i]:destroy()
                else
                    i = i + 1
                end
            end
        end

        --PlayerTimer constructor
        ---@param self TimerList
        ---@return PlayerTimer
        function thistype:add()
            local pt = PlayerTimer.create()

            pt.pid = self.pid
            self.timers[#self.timers + 1] = pt

            return pt
        end
    end
end, Debug and Debug.getLine())
