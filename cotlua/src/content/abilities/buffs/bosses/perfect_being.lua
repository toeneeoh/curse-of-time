OnInit.final("BuffsBossesPerfectBeing", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class ProtectedExistenceBuff : Buff
    ProtectedExistenceBuff = Buff.new()
    do
        local thistype = ProtectedExistenceBuff
        thistype.NAME            = "Protected Existence"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSnakeShield.blp"
        thistype.DESC            = "This unit has +^#mr% magic resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].mr = Unit[self.target].mr / self.mr
            remove_demon_shield(self)
        end

        function thistype:onApply()
            self.mr = 0.666
            Unit[self.target].mr = Unit[self.target].mr * self.mr
            add_demon_shield(self)
        end
    end

end, Debug and Debug.getLine())
