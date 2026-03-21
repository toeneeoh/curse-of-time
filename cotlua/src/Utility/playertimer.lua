--[[
    playertimer.lua

    defines more specialized timers for use with spells and other unique situations where stronger
    callback control is required.

    player timers handle trouble when a player leaves or -repicks and will automatically clean up handles.
]]

OnInit.global("PlayerTimer", function(Require)
    Require('TimerQueue')

    local TQ = TimerQueue

    ---@param pt PlayerTimer
    local function PT_loopTick(pt)
        -- this is called by TQ with `pt` as arg
        if pt._destroyed then
            pt.cb = nil
            return
        end

        local fn = pt.loopFn
        if not fn then
            pt.cb = nil
            if pt.autoDestroy then
                pt:destroy()
            end
            return
        end

        -- fn should return false to stop
        local keep = fn(pt)
        if keep == false then
            pt.cb = nil
            if pt.autoDestroy then
                pt:destroy()
            end
            return
        end

        -- reschedule next tick
        local period = pt.period or 0.
        pt.cb = TQ:callDelayed(period, PT_loopTick, pt)
    end

    ---@param pt PlayerTimer
    local function PT_onceTick(pt)
        -- one-shot dispatch
        pt.cb = nil
        if pt._destroyed then
            return
        end

        local fn = pt.onceFn
        if fn then
            fn(pt)
        end

        if pt.autoDestroy then
            pt:destroy()
        end
    end

    ----------------------------------------------------------------
    -- PlayerTimer
    ----------------------------------------------------------------

    ---@class PlayerTimer
    ---@field create fun(): PlayerTimer
    ---@field destroy fun(self: PlayerTimer)
    ---@field after fun(self: PlayerTimer, delay: number, fn: fun(self: PlayerTimer))
    ---@field startLoop fun(self: PlayerTimer, period: number, fn: fun(self: PlayerTimer): boolean|nil)
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
    ---@field onRemove fun(self: PlayerTimer)|nil
    ---@field cb any            @handle returned by TQ:callDelayed
    ---@field loopFn fun(pt: PlayerTimer)|nil
    ---@field onceFn fun(pt: PlayerTimer)|nil
    ---@field period number|nil
    ---@field _destroyed boolean
    PlayerTimer = {}
    do
        local thistype = PlayerTimer
        local mt = { __index = thistype }

        ---create a new player timer (not yet in any TimerList)
        ---@return PlayerTimer
        function thistype.create()
            local self = {
                dur = 0.,
                time = 0.,
                dmg = 0.,
                cb = nil,
                loopFn = nil,
                onceFn = nil,
                period = nil,
                autoDestroy = true,
                _destroyed = false,
            }

            setmetatable(self, mt)
            return self
        end

        ---internal: cancel the outstanding callback (if any)
        ---@param self PlayerTimer
        function thistype:_cancelCallback()
            if self.cb then
                TQ:disableCallback(self.cb)
                self.cb = nil
            end
        end

        ---destroy this player timer and all resources attached to it
        ---@param self PlayerTimer
        function thistype:destroy()
            if self._destroyed then
                return
            end
            self._destroyed = true

            -- stop any pending timer callback first
            self:_cancelCallback()

            self.loopFn = nil
            self.onceFn = nil
            self.period = nil

            if self.onRemove then
                self:onRemove()
            end

            if self.ug then
                DestroyGroup(self.ug)
                self.ug = nil
            end

            if self.sfx then
                DestroyEffect(self.sfx)
                self.sfx = nil
            end

            if self.lfx then
                DestroyLightning(self.lfx)
                self.lfx = nil
            end

            if self.curve then
                self.curve:destroy()
                self.curve = nil
            end

            if self.pid then
                local list = TimerList[self.pid]
                if list then
                    list:removeTimer(self)
                end
            end

            setmetatable(self, nil)
        end

        ---schedule a one-shot callback after `delay` seconds
        ---fn is called as fn(self)
        ---
        ---if a callback is already pending, it is cancelled and replaced
        ---@param self PlayerTimer
        ---@param delay number
        ---@param fn fun(self: PlayerTimer)
        function thistype:after(delay, fn)
            if self._destroyed then
                return
            end

            self:_cancelCallback()

            self.onceFn = fn
            self.loopFn = nil
            self.period = nil

            self.cb = TQ:callDelayed(delay, PT_onceTick, self)
        end

        ---start a repeating loop every `period` seconds.
        ---
        ---fn is called as fn(self); if it returns false, the loop stops.
        ---existing pending loop callback (if any) is cancelled.
        ---@param self PlayerTimer
        ---@param period number
        ---@param fn fun(self: PlayerTimer): boolean|nil
        function thistype:startLoop(period, fn)
            if self._destroyed then
                return
            end

            self:_cancelCallback()

            self.loopFn = fn
            self.onceFn = nil
            self.period = period

            self.cb = TQ:callDelayed(period, PT_loopTick, self)
        end
    end

    ----------------------------------------------------------------
    -- TimerList
    ----------------------------------------------------------------

    ---@class TimerList
    ---@field pid integer
    ---@field timers PlayerTimer[]
    ---@field removeTimer fun(self: TimerList, pt: PlayerTimer)
    ---@field get fun(self: TimerList, tag: any, source: unit|nil, target: unit|nil): PlayerTimer|nil
    ---@field has fun(self: TimerList, tag: any, source: unit|nil, target: unit|nil): boolean
    ---@field stopAllTimers fun(self: TimerList, tag: any|nil)
    ---@field add fun(self: TimerList, tag: any|nil): PlayerTimer
    TimerList = {} ---@type TimerList | TimerList[] | PlayerTimer[][]
    do
        local thistype = TimerList
        local mt = { __index = thistype }

        -- lazily create per-player timer lists
        setmetatable(thistype, {
            __index = function(tbl, key)
                local new = {
                    pid = key,
                    timers = {},
                }
                rawset(tbl, key, new)
                setmetatable(new, mt)
                return new
            end
        })

        ---remove a specific PlayerTimer from this list
        ---@param self TimerList
        ---@param pt PlayerTimer
        function thistype:removeTimer(pt)
            local timers = self.timers
            for i = 1, #timers do
                if timers[i] == pt then
                    timers[i] = timers[#timers]
                    timers[#timers] = nil
                    break
                end
            end
        end

        --[[
            returns first timer found.

            `source` and `target` may be omitted if only looking by tag.
        ]]
        ---@param self TimerList
        ---@param tag any
        ---@param source unit|nil
        ---@param target unit|nil
        ---@return PlayerTimer|nil
        function thistype:get(tag, source, target)
            local timers = self.timers
            for i = 1, #timers do
                local pt = timers[i]
                if pt.tag == tag
                    and (not source or pt.source == source)
                    and (not target or pt.target == target)
                then
                    return pt
                end
            end
            return nil
        end

        ---check if any timer with given constraints exists
        ---@param self TimerList
        ---@param tag any
        ---@param source unit|nil
        ---@param target unit|nil
        ---@return boolean
        function thistype:has(tag, source, target)
            return self:get(tag, source, target) ~= nil
        end

        --[[
            stop all timers for this player.

            if `tag` is provided, only timers whose `pt.tag == tag` are destroyed.
        ]]
        ---@param self TimerList
        ---@param tag any|nil
        function thistype:stopAllTimers(tag)
            local timers = self.timers
            local i = 1
            while i <= #timers do
                local pt = timers[i]
                if (not tag) or pt.tag == tag then
                    pt:destroy()
                    -- destroy() swaps from end and shrinks list, so do not inc i
                else
                    i = i + 1
                end
            end
        end

        ---construct and register a new PlayerTimer for this player
        ---@param self TimerList
        ---@param tag any|nil
        ---@return PlayerTimer
        function thistype:add(tag)
            local pt = PlayerTimer.create()
            pt.pid = self.pid
            pt.tag = tag

            local timers = self.timers
            timers[#timers + 1] = pt

            return pt
        end
    end
end, Debug and Debug.getLine())
