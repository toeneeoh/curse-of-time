OnInit.global("BuffSystem", function(Require)
    Require('TimerQueue')
    Require('UnitEvent')
    Require('BuffBar')

    -------------------------------//
    ----------- BUFF TYPES --------//
    -------------------------------//
    BUFF_NONE         = 0   ---@type integer 
    BUFF_POSITIVE     = 1     ---@type integer 
    BUFF_NEGATIVE     = 2 ---@type integer 

    -------------------------------//
    -------- BUFF STACK TYPES -----//
    -------------------------------//
    --Applying the same buff only refreshes the duration
    --If the buff is reapplied but from a different source, the Buff unit source gets replaced.
    BUFF_STACK_NONE   = 0 ---@type integer 

    --Each buff from different source stacks.
    --Re-applying the same buff from the same source only refreshes the duration
    BUFF_STACK_PARTIAL= 1 ---@type integer 

    --Each buff applied fully stacks.
    BUFF_STACK_FULL   = 2 ---@type integer 

    local buffs = {}
    local TQ = TimerQueue

    ---@class Buff
    ---@field pid integer
    ---@field tpid integer
    ---@field target unit
    ---@field source unit
    ---@field buffId integer
    ---@field STACK_TYPE integer
    ---@field DISPEL_TYPE integer
    ---@field onApply function
    ---@field onRemove function
    ---@field buffs table
    ---@field get function
    ---@field has function
    ---@field remove function
    ---@field removeAll function
    ---@field check function
    ---@field dispel function
    ---@field dispelBoth function
    ---@field dispelAll function
    ---@field add function
    ---@field create function
    ---@field duration function
    ---@field refresh function
    ---@field remaining function
    Buff = {} ---@type Buff
    do
        local thistype = Buff

        --===============================================================
        --======================== BUFF CORE ============================
        --===============================================================    

        ---@type fun(): Buff
        function Buff.new()
            local self = setmetatable({
                pid = 0,
                tpid = 0,
                STACK_TYPE = 0,
                DISPEL_TYPE = 0,
                ICON = "ReplaceableTextures\\CommandButtons\\BTNShoveler.blp",
                NAME = "Placeholder",
                DESC = "Placeholder",
            }, { __index = Buff })

            self.parent = self -- self reference

            return self
        end

        ---@type fun(self: Buff)
        function Buff:refresh()
            if self.onRemove then self:onRemove() end
            if self.onApply then self:onApply() end
        end

        ---@type fun(self: Buff, source: unit, target: unit): Buff?
        function Buff:get(source, target)
            local tbl = Unit[target].buffs

            if not tbl then
                return nil
            end

            -- search target's buffs over global
            for i = 1, #tbl do
                local b = tbl[i]

                if b.parent == self.parent and target == b.target and (source == nil or source == b.source) then
                    return b
                end
            end

            return nil
        end

        ---@type fun(self: Buff, source: unit, target: unit): boolean
        function Buff:has(source, target)
            return self:get(source, target) ~= nil
        end

        function thistype:remove()
            if self.internal_callback then
                TQ:disableCallback(self.internal_callback)
            end

            -- remove from buffs table
            for i = 1, #buffs do
                if buffs[i] == self then
                    buffs[i] = buffs[#buffs]
                    buffs[#buffs] = nil
                    break
                end
            end

            -- remove from buff bar
            UnitRemoveBuff(self.target, self)

            if self.onRemove then
                self:onRemove()
            end
        end

        ---@type fun(self: Buff, dur: number)
        function Buff:duration(dur)
            if self.internal_callback then
                TQ:disableCallback(self.internal_callback)
            end

            if dur then
                self.internal_callback = TQ:callDelayed(dur, self.remove, self)
            end

            -- refresh buff bar
            UnitRefreshBuff(self.target)
        end

        ---@type fun(self: Buff): number?
        function Buff:remaining()
            return TQ:getRemaining(self.internal_callback)
        end

        ---@type fun(self: Buff): number?
        function Buff:timeout()
            return TQ:getTimeout(self.internal_callback)
        end

        function Buff:check(source, target)
            local apply = false

            if self.STACK_TYPE == BUFF_STACK_FULL then
                apply = true

            elseif self.STACK_TYPE == BUFF_STACK_PARTIAL then
                local same = self:get(nil, target) ---@type Buff

                if same then
                    -- stronger buff takeover
                    if self.ablev and same.ablev and self.ablev > same.ablev then
                        same.ablev = self.ablev
                        same.source = source
                        same.target = target
                        same.pid = GetPlayerId(GetOwningPlayer(source)) + 1
                        same.tpid = GetPlayerId(GetOwningPlayer(target)) + 1

                        same:refresh()
                    end

                    return same
                else
                    apply = true
                end

            elseif self.STACK_TYPE == BUFF_STACK_NONE then
                local same = self:get(nil, target)

                if same then
                    self = same
                else
                    apply = true
                end
            end

            self.source = source
            self.target = target
            self.pid = GetPlayerId(GetOwningPlayer(source)) + 1
            self.tpid = GetPlayerId(GetOwningPlayer(target)) + 1

            if apply then
                buffs[#buffs + 1] = self

                if self.onApply then
                    self:onApply()
                end

                UnitAddBuff(target, self)
            end

            return self
        end

        --===============================================================
        --======================= BUFF DISPEL ===========================
        --===============================================================
        ---@param u unit
        ---@param dispelType integer
        function thistype.dispelType(u, dispelType)
            local i = 1
            while i <= #buffs do
                if buffs[i].target == u and buffs[i].DISPEL_TYPE == dispelType then
                    buffs[i]:remove()
                else
                    i = i + 1
                end
            end
        end

        ---@param u unit
        function thistype.dispelBoth(u)
            local i = 1
            while i <= #buffs do
                if buffs[i].target == u and (buffs[i].DISPEL_TYPE == BUFF_POSITIVE or buffs[i].DISPEL_TYPE == BUFF_NEGATIVE) then
                    buffs[i]:remove()
                else
                    i = i + 1
                end
            end
        end

        ---@param u unit
        ---@param override boolean
        function thistype.dispelAll(u, override)
            local i = 1
            while i <= #buffs do
                if buffs[i].target == u and (not buffs[i].CANNOT_PURGE or override) then
                    buffs[i]:remove()
                else
                    i = i + 1
                end
            end
        end

        ---@type fun(self: Buff, source: unit, target: unit): boolean
        function thistype:dispel(source, target)
            local tbl = Unit[target]

            if not tbl then
                return false
            end

            tbl = Unit[target].buffs

            if not tbl then
                return false
            end

            for i = 1, #tbl do
                local b = tbl[i]

                if b.parent == self and target == b.target and (source == nil or source == b.source) and not b.CANNOT_PURGE then
                    b:remove()
                    return true
                end
            end

            return false
        end

        -- remove all instances of a specific buff (ie. weather)
        function thistype:removeAll()
            local i = 1
            while i <= #buffs do
                if buffs[i].parent == self then
                    buffs[i]:remove()
                else
                    i = i + 1
                end
            end
        end

        --memoize metatables for inheritance
        local mts = {}

        ---@return Buff
        function thistype:create(source, target)
            mts[self] = mts[self] or { __index = self }

            local b = setmetatable({}, mts[self])

            b.parent = self
            b.pid = GetPlayerId(GetOwningPlayer(source)) + 1
            b.tpid = GetPlayerId(GetOwningPlayer(target)) + 1

            return b
        end

        ---@type fun(self: Buff, source: unit, target: unit, ablev: number?): Buff
        function Buff:add(source, target, ablev)
            ablev = ablev or 1

            -- check for existing buffs to refresh
            if self.STACK_TYPE ~= BUFF_STACK_FULL then
                local existing = self:get(nil, target)

                if existing then
                    if self.STACK_TYPE == BUFF_STACK_PARTIAL and ablev > (existing.ablev or 0) then
                        existing.ablev = ablev
                        existing.source = source
                        existing.target = target
                        existing.pid  = GetPlayerId(GetOwningPlayer(source)) + 1
                        existing.tpid = GetPlayerId(GetOwningPlayer(target)) + 1

                        existing:refresh()
                    end

                    return existing
                end
            end

            -- create a new buff otherwise
            local b = self:create(source, target) ---@type Buff
            b.ablev = ablev or 1

            b = b:check(source, target)

            return b
        end

        RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_DEATH,
        function()
            thistype.dispelAll(GetTriggerUnit())
        end)
    end
end, Debug and Debug.getLine())
