OnInit.final("BuffsBossesLove", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class HolyBlessing : Buff
    HolyBlessing = Buff.new()
    do
        local thistype = HolyBlessing
        thistype.NAME            = "Holy Blessing"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBerserkForTrolls.blp"
        thistype.DESC            = "This unit has +^$as% base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.as
        end

        function thistype:onApply()
            self.as = 2.
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.as
        end
    end

end, Debug and Debug.getLine())
