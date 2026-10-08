OnInit.final("BuffsBossesDemonPrince", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class DemonPrinceBloodlust : Buff
    DemonPrinceBloodlust = Buff.new()
    do
        local thistype = DemonPrinceBloodlust
        thistype.NAME            = "Bloodlust"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodLust.blp"
        thistype.DESC            = "This unit has +^$ms% movespeed and +^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end

        function thistype:onApply()
            self.as = 0.75
            self.ms = 0.5 * (math.min(1, Unit[self.target].ms_percent))

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end
    end

end, Debug and Debug.getLine())
