OnInit.final("BuffsWorldFactions", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class HardHatBuff : Buff
    HardHatBuff = Buff.new()
    do
        local thistype = HardHatBuff
        thistype.NAME            = "Hard Hat"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHelmOfValor.blp"
        thistype.DESC            = "This unit has +^#mult% damage resist"
        thistype.DESC_FACTION    = "After standing still for 3 seconds gain |cffffcc0015%|r damage reduction."
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL
        thistype.CANNOT_PURGE    = true

       local function periodic(self)
            local u = Unit[self.target]

            if UnitAlive(self.target) and
                u.x == GetUnitX(self.target) and
                u.y == GetUnitY(self.target)
            then
                self.count = self.count + 1
                if self.count >= 3 then
                    u.dr = u.dr / self.mult
                    self.mult = 0.85
                    u.dr = u.dr * self.mult
                end
            else
                u.dr = u.dr / self.mult
                self.mult = 1.
                self.count = 0
            end
            self.timer = TQ:callDelayed(1, periodic, self)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.mult
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.mult = 1.
            self.count = 0
            self.timer = TQ:callDelayed(1, periodic, self)
        end
    end

end, Debug and Debug.getLine())
