OnInit.final("BuffsSummons", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class MeatGolemThunderClap : Buff
    MeatGolemThunderClap = Buff.new()
    do
        local thistype = MeatGolemThunderClap
        thistype.NAME            = "Thunder Clap"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNThunderclap.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.3
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", "overhead")

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end
    end

end, Debug and Debug.getLine())
