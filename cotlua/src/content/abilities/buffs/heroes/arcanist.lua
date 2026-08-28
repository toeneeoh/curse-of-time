OnInit.final("BuffsHeroesArcanist", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class ArcaneBarrageBuff : Buff
    ArcaneBarrageBuff = Buff.new()
    do
        local thistype = ArcaneBarrageBuff
        thistype.NAME            = "Arcane Barrage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArcaneStorm2.blp"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 150
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

    ---@class StasisFieldDebuff : Buff
    StasisFieldDebuff = Buff.new()
    do
        local thistype = StasisFieldDebuff
        thistype.NAME            = "Stasis Field"
        thistype.DESC            = "This unit cannot move"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArcaneBarrier2.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            SetUnitPropWindow(self.target, bj_DEGTORAD * 60.)
            SetUnitPathing(self.target, true)
        end

        function thistype:onApply()
            SetUnitPropWindow(self.target, 0)
        end
    end

    ---@class ArcanosphereDebuff : Buff
    ArcanosphereDebuff = Buff.new()
    do
        local thistype = ArcanosphereDebuff
        thistype.NAME            = "Arcanosphere"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSpaceTimeWarp.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = 0.75 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class ArcanosphereBuff : Buff
    ArcanosphereBuff = Buff.new()
    do
        local thistype = ArcanosphereBuff
        thistype.NAME            = "Arcanosphere"
        thistype.DESC            = "This unit always has $ms movespeed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSpaceTimeWarp.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].overmovespeed = nil
        end

        function thistype:onApply()
            self.ms = 1000
            Unit[self.target].overmovespeed = self.ms
        end
    end

end, Debug and Debug.getLine())
