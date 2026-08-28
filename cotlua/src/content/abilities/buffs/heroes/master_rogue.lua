OnInit.final("BuffsHeroesMasterRogue", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class PiercingStrikeBuff : Buff
    PiercingStrikeBuff = Buff.new()
    do
        local thistype = PiercingStrikeBuff
        thistype.NAME            = "Piercing Strike"
        thistype.ICON            = "ReplaceableTextures\\PassiveButtons\\PASShieldBreakGreen.tga"
        thistype.DESC            = "This unit has +$pen% armor penetration"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].armor_pen_percent = Unit[self.target].armor_pen_percent - self.pen
        end

        function thistype:onApply()
            self.pen = PIERCINGSTRIKE.pen(self.tpid)
            Unit[self.target].armor_pen_percent = Unit[self.target].armor_pen_percent + self.pen
        end
    end

    ---@class NerveGasDebuff : Buff
    NerveGasDebuff = Buff.new()
    do
        local thistype = NerveGasDebuff
        thistype.NAME            = "Nerve Gas"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNAcidBomb.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed, -^$as% attack speed, and -^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            local dmg = NERVEGAS.dmg(self.pid) * BOOST[self.pid] / (NERVEGAS.dur * LBOOST[self.pid] * 2.)

            DamageTarget(self.source, self.target, dmg, ATTACK_TYPE_NORMAL, MAGIC, "Nerve Gas")

            self.timer = TQ:callDelayed(0.5, periodic, self)
        end

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target].armor_percent = Unit[self.target].armor_percent + self.armor
            Unit[self.target]:removeEffect(self.sfx)
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))
            self.as = 0.3
            self.armor = 0.2

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            Unit[self.target].armor_percent = Unit[self.target].armor_percent - self.armor
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Other\\AcidBomb\\BottleImpact.mdl", "chest")

            self.timer = TQ:callDelayed(0.25, periodic, self)
        end
    end

end, Debug and Debug.getLine())
