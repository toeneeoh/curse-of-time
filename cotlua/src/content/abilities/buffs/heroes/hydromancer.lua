OnInit.final("BuffsHeroesHydromancer", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class InfusedWaterBuff : Buff
    InfusedWaterBuff = Buff.new()
    do
        local thistype = InfusedWaterBuff
        thistype.NAME            = "Infused Water"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNInfusedWater2.blp"
        thistype.DESC            = "This unit has +$ms movespeed and next spell cast is empowered"
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

    ---@class TidalWaveDebuff : Buff
    TidalWaveDebuff = Buff.new()
    do
        local thistype = TidalWaveDebuff
        thistype.NAME            = "Tidal Wave"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTidalWave4.blp"
        thistype.DESC            = "This unit has -^$percent% damage resist"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / (1 + self.percent)
        end
        function thistype:onApply()
            self.percent = self.percent or .15
            Unit[self.target].dr = Unit[self.target].dr * (1 + self.percent)
        end

    end

    ---@class SoakedDebuff : Buff
    SoakedDebuff = Buff.new()
    do
        local thistype = SoakedDebuff
        thistype.NAME            = "Soaked"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCrushingWave.blp"
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
            self.ms = 0.5 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Other\\FrostDamage\\FrostDamage.mdl", "chest")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

end, Debug and Debug.getLine())
