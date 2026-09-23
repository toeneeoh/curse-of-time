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
        thistype.DESC_FACTION    = "After standing still for 3 seconds gain |cffffcc008%|r damage reduction. Improves to |cffffcc0011%|r at Rank 4 and |cffffcc0015%|r at Rank 7."
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
                    local reduction = thistype.getFactionReduction
                        and thistype.getFactionReduction(self.target) or 0.08
                    self.mult = 1. - reduction
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

    ---@class StormwatchBuff : Buff
    StormwatchBuff = Buff.new()
    do
        local thistype = StormwatchBuff
        thistype.NAME            = "Stormwise"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNMonsoon.blp"
        thistype.DESC            = "This unit is attuned to changing weather"
        thistype.DESC_FACTION    = "Reduces harmful weather effects by |cffffcc0015%|r and improves beneficial weather effects by |cffffcc0010%|r. Improves at Ranks 4 and 7."
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL
        thistype.CANNOT_PURGE    = true
    end

    ---@class AshenVanguardBuff : Buff
    AshenVanguardBuff = Buff.new()
    do
        local thistype = AshenVanguardBuff
        thistype.NAME            = "Battle Tested"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArcaniteMelee.blp"
        thistype.DESC            = "This unit has +^#mult% total damage"
        thistype.DESC_FACTION    = "Increases total damage by |cffffcc005%|r. Improves to |cffffcc008%|r at Rank 4 and |cffffcc0012%|r at Rank 7."
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL
        thistype.CANNOT_PURGE    = true

        function thistype:onRemove()
            Unit[self.target].dm = Unit[self.target].dm / self.mult
        end

        function thistype:onApply()
            local bonus = thistype.getFactionDamage
                and thistype.getFactionDamage(self.target) or 0.05
            self.mult = 1. + bonus
            Unit[self.target].dm = Unit[self.target].dm * self.mult
        end
    end

end, Debug and Debug.getLine())
