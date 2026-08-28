OnInit.final("BuffsHeroesDarkSummoner", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class DemonicSacrificeBuff : Buff
    DemonicSacrificeBuff = Buff.new()
    do
        local thistype = DemonicSacrificeBuff
        thistype.NAME            = "Demonic Sacrifice"
        thistype.DESC            = "This unit has +^$spellboost% spellboost"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTurnUndead.blp"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
        end

        function thistype:onApply()
            self.spellboost = 0.15
            Unit[self.target].spellboost = Unit[self.target].spellboost + self.spellboost
        end
    end

end, Debug and Debug.getLine())
