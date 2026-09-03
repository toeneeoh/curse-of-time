OnInit.final("BuffsSummons", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class BloodDebtBuff : Buff
    BloodDebtBuff = Buff.new()
    do
        local thistype = BloodDebtBuff
        thistype.NAME            = "Blood Debt"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSacrificialSkull.blp"
        thistype.DESC            = "The next Demonic Sacrifice costs $cost% Max Health"
        thistype.DISPEL_TYPE     = BUFF_NONE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function decay(self)
            self.charges = math.max(0, self.charges - 1)
            self.cost = 20 + self.charges * 10
            UnitRefreshBuff(self.target, self)

            if self.charges > 0 then
                self.decay_callback = TQ:callDelayed(12., decay, self)
                self:duration(12.05)
            else
                self.decay_callback = nil
                self:remove()
            end
        end

        function thistype:addStack()
            self.charges = math.min(8, self.charges + 1)
            self.cost = 20 + self.charges * 10

            if self.decay_callback then
                TQ:disableCallback(self.decay_callback)
            end

            self.decay_callback = TQ:callDelayed(12., decay, self)
            self:duration(12.05)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            if self.decay_callback then
                TQ:disableCallback(self.decay_callback)
                self.decay_callback = nil
            end
        end

        function thistype:onApply()
            self.charges = 0
            self.cost = 20
        end
    end

    ---@class ReaverBloodFrenzyBuff : Buff
    ReaverBloodFrenzyBuff = Buff.new()
    do
        local thistype = ReaverBloodFrenzyBuff
        thistype.NAME            = "Blood Frenzy"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodLust.blp"
        thistype.DESC            = "This unit has +^#bat% base attack speed, +^$cleave% cleave damage, and +$width cleave end width"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:update(cost_percent, tier, dur)
            local unit = Unit[self.target]
            unit.bonus_bat = unit.bonus_bat * self.bat

            if tier >= 5 then
                self.bat = 1.0875 + cost_percent * 0.003125
                self.cleave_multiplier = 1. + cost_percent * 0.0075
                self.width = cost_percent * 1.5
            else
                self.bat = 1.05 + cost_percent * 0.0025
                self.cleave_multiplier = 1. + cost_percent * 0.005
                self.width = cost_percent
            end

            self.cleave = (self.cleave_multiplier - 1.) * 100.
            unit.bonus_bat = unit.bonus_bat / self.bat
            self:duration(dur)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.bat = 1.
            self.cleave = 0.
            self.cleave_multiplier = 1.
            self.width = 0.
            self.sfx = Unit[self.target]:addEffect(
                "Abilities\\Spells\\Undead\\VampiricAura\\VampiricAuraTarget.mdl", "origin")
        end
    end

    ---@class UnholyAscensionBuff : Buff
    UnholyAscensionBuff = Buff.new()
    do
        local thistype = UnholyAscensionBuff
        thistype.NAME            = "Unholy Ascension"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNAnnihilation.blp"
        thistype.DESC            = "This unit deals +^$damage% damage, has +^$reduction% damage resist, and +^$attack_speed% base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:update(damage, reduction, attack_speed, dur)
            local unit = Unit[self.target]

            unit.dm = unit.dm / self.damage_multiplier
            unit.dr = unit.dr / self.reduction_multiplier
            unit.bonus_bat = unit.bonus_bat * self.attack_speed_multiplier

            self.damage = damage
            self.reduction = reduction
            self.attack_speed = attack_speed
            self.damage_multiplier = 1. + damage
            self.reduction_multiplier = 1. - reduction
            self.attack_speed_multiplier = 1. + attack_speed

            unit.dm = unit.dm * self.damage_multiplier
            unit.dr = unit.dr * self.reduction_multiplier
            unit.bonus_bat = unit.bonus_bat / self.attack_speed_multiplier

            self:duration(dur)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            local unit = Unit[self.target]

            unit.dm = unit.dm / self.damage_multiplier
            unit.dr = unit.dr / self.reduction_multiplier
            unit.bonus_bat = unit.bonus_bat * self.attack_speed_multiplier
            unit:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.damage = 0.
            self.reduction = 0.
            self.attack_speed = 0.
            self.damage_multiplier = 1.
            self.reduction_multiplier = 1.
            self.attack_speed_multiplier = 1.
            self.sfx = Unit[self.target]:addEffect(
                "Abilities\\Spells\\Undead\\UnholyFrenzy\\UnholyFrenzyTarget.mdl", "origin")
        end
    end

    ---@class ReaverWarCryBuff : Buff
    ReaverWarCryBuff = Buff.new()
    do
        local thistype = ReaverWarCryBuff
        thistype.NAME            = "War Cry"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBattleRoar.blp"
        thistype.DESC            = "This unit has +^$ms% movespeed and +^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:update(ms, armor, dur)
            local unit = Unit[self.target]
            unit.ms_percent = unit.ms_percent - self.ms
            unit.armor_percent = unit.armor_percent - self.armor
            self.ms = ms
            self.armor = armor
            unit.ms_percent = unit.ms_percent + self.ms
            unit.armor_percent = unit.armor_percent + self.armor
            self:duration(dur)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            local unit = Unit[self.target]
            unit.ms_percent = unit.ms_percent - self.ms
            unit.armor_percent = unit.armor_percent - self.armor
        end

        function thistype:onApply()
            self.ms = 0.
            self.armor = 0.
        end
    end

    ---@class DreadfulWoundsDebuff : Buff
    DreadfulWoundsDebuff = Buff.new()
    do
        local thistype = DreadfulWoundsDebuff
        thistype.NAME            = "Dreadful Wounds"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHowlOfTerror.blp"
        thistype.DESC            = "This unit deals -$damage% damage"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:update(reduction, dur)
            local unit = Unit[self.target]
            unit.dm = unit.dm / self.multiplier
            self.multiplier = 1. - reduction
            self.damage = reduction * 100.
            unit.dm = unit.dm * self.multiplier
            self:duration(dur)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            Unit[self.target].dm = Unit[self.target].dm / self.multiplier
        end

        function thistype:onApply()
            self.damage = 0.
            self.multiplier = 1.
        end
    end

    ---@class SkullBruteBloodforgedBuff : Buff
    SkullBruteBloodforgedBuff = Buff.new()
    do
        local thistype = SkullBruteBloodforgedBuff
        thistype.NAME            = "Bloodforged"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNReincarnation.blp"
        thistype.DESC            = "Attacks restore 0.5% Max Health"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_hit(source, target, amount, amount_after_reduction)
            local buff = thistype:get(nil, source)
            if buff and amount_after_reduction > 0 then
                HP(buff.source, source, BlzGetUnitMaxHP(source) * 0.005, "Bloodforged")
            end
        end

        function thistype:onRemove()
            EVENT_ON_HIT_AFTER_REDUCTIONS:unregister_unit_action(self.target, on_hit)
        end

        function thistype:onApply()
            EVENT_ON_HIT_AFTER_REDUCTIONS:register_unit_action(self.target, on_hit)
        end
    end

    ---@class DestroyerContinuityBuff : Buff
    DestroyerContinuityBuff = Buff.new()
    do
        local thistype = DestroyerContinuityBuff
        thistype.NAME            = "Unstable Continuity"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSnakeShield.blp"
        thistype.DESC            = "This unit will block the next $charges fatal damage instances"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:grant(charges, dur)
            self.charges = math.max(self.charges, charges)
            self:duration(dur)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:consume()
            if self.charges <= 0 then return false end

            self.charges = self.charges - 1
            if self.charges > 0 then
                UnitRefreshBuff(self.target, self)
            else
                self:remove()
            end
            return true
        end

        function thistype:onApply()
            self.charges = 0
        end
    end

    ---@class SkullBruteThunderClap : Buff
    SkullBruteThunderClap = Buff.new()
    do
        local thistype = SkullBruteThunderClap
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
