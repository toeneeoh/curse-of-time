OnInit.final("BuffsHeroesEliteMarksman", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class SingleShotDebuff : Buff
    SingleShotDebuff = Buff.new()
    do
        local thistype = SingleShotDebuff
        thistype.NAME            = "Crippled"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNGunHD.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Undead\\Cripple\\CrippleTarget.mdl", "chest")
            self.ms = 0.5 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

end, Debug and Debug.getLine())
