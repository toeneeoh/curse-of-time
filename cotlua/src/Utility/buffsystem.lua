OnInit.global("BuffSystem", function(Require)
    Require('TimerQueue')
    Require('UnitEvent')

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

    --Determines the automatic Buff rawcode based on the Ability rawcode
    --If BUFF_OFFSET = 0x01000000, then Ability rawcode of FourCC('AXXX') will have Buff rawcode of FourCC('BXXX')
    local BUFF_OFFSET = 0x01000000 ---@type integer 
    local buffs = {}
    local count = array2d(0)

    ---@class Buff
    ---@field pid integer
    ---@field tpid integer
    ---@field target unit
    ---@field source unit
    ---@field RAWCODE integer
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
    ---@field timer TimerQueue
    Buff = {} ---@type Buff
    do
        local thistype = Buff
        thistype.timer = TimerQueue.create()

        --Buff defaults
        thistype.pid = 0 ---@type integer
        thistype.tpid = 0 ---@type integer
        thistype.target = nil ---@type unit 
        thistype.source = nil ---@type unit 
        thistype.RAWCODE = 0 ---@type integer 
        thistype.STACK_TYPE = 0 ---@type integer 
        thistype.DISPEL_TYPE = 0 ---@type integer 
        thistype.onApply = nil ---@type function
        thistype.onRemove = nil ---@type function

        --===============================================================
        --======================== BUFF CORE ============================
        --===============================================================    

        ---@type fun(self: Buff, source: unit, target: unit, apply: boolean, dur: number)
        function thistype:refresh(source, target, dur)
            local b = self:get(source, target)
            local oldsource = source

            if b then
                oldsource = b.source
                b:remove()
                b = self:add(oldsource, target)
                if dur then
                    b:duration(dur)
                end
            end
        end

        ---@type fun(self: Buff, source: unit, target: unit): Buff | nil
        function thistype:get(source, target)
            for i = 1, #buffs do
                if buffs[i].RAWCODE == self.RAWCODE and target == buffs[i].target and (source == nil or source == buffs[i].source) then
                    return buffs[i]
                end
            end

            return nil
        end

        ---@type fun(self: Buff, source: unit, target: unit):boolean
        function thistype:has(source, target)
            return self:get(source, target) ~= nil
        end

        function thistype:remove()
            local remove = false

            if self.STACK_TYPE == BUFF_STACK_FULL or self.STACK_TYPE == BUFF_STACK_PARTIAL then
                -- Update Buff count
                count[self.RAWCODE][self.target] = count[self.RAWCODE][self.target] - 1

                if count[self.RAWCODE][self.target] == 0 then
                    remove = true
                end
            elseif self.STACK_TYPE == BUFF_STACK_NONE then
                remove = true
            end

            if remove then
                UnitRemoveAbility(self.target, self.RAWCODE)
                UnitRemoveAbility(self.target, self.RAWCODE + BUFF_OFFSET)
            end

            if self.callback then
                thistype.timer:disableCallback(self.callback)
            end

            -- remove from buffs
            for i = 1, #buffs do
                if buffs[i] == self then
                    buffs[i] = buffs[#buffs]
                    buffs[#buffs] = nil
                    break
                end
            end

            if self.onRemove then
                self:onRemove()
            end

            self = nil
        end

        ---@type fun(self: Buff, dur: number)
        function thistype:duration(dur)
            if self.callback then
                thistype.timer:disableCallback(self.callback)
            end

            if dur then
                self.callback = thistype.timer:callDelayed(dur, self.remove, self)
            end
        end

        ---@type fun(self: Buff, source: unit, target: unit): Buff
        function thistype:check(source, target)
            local apply = false ---@type boolean 
            local similar = self:get(nil, target) ---@type Buff

            if self.STACK_TYPE == BUFF_STACK_FULL then
                --Update target buff count
                count[self.RAWCODE][target] = count[self.RAWCODE][target] + 1
                apply = true

            elseif self.STACK_TYPE == BUFF_STACK_PARTIAL then
                if not similar then
                    --Update target buff count
                    count[self.RAWCODE][target] = count[self.RAWCODE][target] + 1
                    apply = true
                else
                    self = similar
                end

            elseif self.STACK_TYPE == BUFF_STACK_NONE then
                if not similar then
                    apply = true
                else
                    self = similar
                end
            end

            self.source = source
            self.target = target

            if apply then
                --Append to buffs
                buffs[#buffs + 1] = self

                if GetUnitAbilityLevel(target, self.RAWCODE) == 0 then
                    UnitAddAbility(target, self.RAWCODE)
                    UnitMakeAbilityPermanent(target, true, self.RAWCODE)
                end

                if self.onApply then
                    self:onApply()
                end
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

        ---@type fun(self: Buff, source: unit, target: unit)
        function thistype:dispel(source, target)
            for i = 1, #buffs do
                if buffs[i].RAWCODE == self.RAWCODE and target == buffs[i].target and (source == nil or source == buffs[i].source) and not buffs[i].CANNOT_PURGE then
                    buffs[i]:remove()
                    break
                end
            end
        end

        function thistype:removeAll()
            local i = 1
            while i <= #buffs do
                if buffs[i].RAWCODE == self.RAWCODE then
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

            b.pid = GetPlayerId(GetOwningPlayer(source)) + 1
            b.tpid = GetPlayerId(GetOwningPlayer(target)) + 1

            return b
        end

        ---@type fun(self: Buff, source: unit, target: unit): Buff
        function thistype:add(source, target)
            local b = self:create(source, target)

            b = b:check(source, target)

            return b
        end

        RegisterPlayerUnitEvent(EVENT_PLAYER_UNIT_DEATH,
        function()
            thistype.dispelAll(GetTriggerUnit())
        end)
    end
end, Debug and Debug.getLine())
