OnInit.final("BuffsHeroesSavior", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local FPS_32 = FPS_32

    ---@class RighteousMightBuff : Buff
    RighteousMightBuff = Buff.new()
    do
        local thistype = RighteousMightBuff
        thistype.NAME            = "Righteous Might"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHolyAngel.blp"
        thistype.DESC            = "This unit has +^$dmg% attack damage, +^#mr% magic resist, and +^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function grow(self, size, dur)
            size = size + 0.008
            SetUnitScale(self.source, size, size, size)
            dur = dur - 1

            if dur > 0 then
                self.timer = TQ:callDelayed(FPS_32, grow, self, size, dur)
            else
                self.timer = nil
            end
        end

        function thistype:onRemove()
            local u = Unit[self.target]
            SetUnitScale(self.target, BlzGetUnitRealField(self.target, UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(self.target, UNIT_RF_SCALING_VALUE), BlzGetUnitRealField(self.target, UNIT_RF_SCALING_VALUE))
            u.mr = u.mr / self.mr
            u.damage_percent = u.damage_percent - self.dmg
            u.armor_percent = u.armor_percent - self.armor

            if self.timer then
                TQ:disableCallback(self.timer)
            end
        end

        function thistype:onApply()
            local u = Unit[self.target]
            local size = BlzGetUnitRealField(self.target, UNIT_RF_SCALING_VALUE)

            self.timer = TQ:callDelayed(FPS_32, grow, self, size, 60)
            self.mr = 0.2

            u.mr = u.mr * self.mr
            u.damage_percent = u.damage_percent + self.dmg
            u.armor_percent = u.armor_percent + self.armor
        end
    end

    ---@class SaviorThunderClap : Buff
    SaviorThunderClap = Buff.new()
    do
        local thistype = SaviorThunderClap
        thistype.NAME            = "Thunder Clap"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHoly Might.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self. as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.35
            self.ms = 0.35 * (math.min(1, Unit[self.target].ms_percent))
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", "overhead")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class LightSealBuff : Buff
    LightSealBuff = Buff.new()
    do
        local thistype = LightSealBuff
        thistype.NAME            = "Perserverance"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNCircleOfPower2.blp"
        thistype.DESC            = "This unit has +$strength strength and +^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function stack_expire(self)
            if self.charges > 0 then
                -- remove current contribution
                Unit[self.source].bonus_str     = Unit[self.source].bonus_str - self.strength
                Unit[self.source].armor_percent = Unit[self.source].armor_percent - self.armor

                self.charges = math.max(0, self.charges - 1)

                -- recompute bonuses
                self.strength = R2I(GetHeroStr(self.source, true) * 0.01 * self.charges)
                self.armor    = 0.01 * self.charges

                -- reapply new contribution (if any)
                Unit[self.source].bonus_str     = Unit[self.source].bonus_str + self.strength
                Unit[self.source].armor_percent = Unit[self.source].armor_percent + self.armor
                UnitRefreshBuff(self.source, self)

                if self.charges > 0 then
                    self.timer = TQ:callDelayed(5., stack_expire, self)
                    self:duration(5.05)
                else
                    self.timer = false
                    self:duration()
                end
            end
        end

        function thistype:addStack(u)
            local i = IsBoss(u) and 5 or 1

            local hp = GetWidgetLife(self.source)

            -- remove old contribution
            Unit[self.source].bonus_str     = Unit[self.source].bonus_str - self.strength
            Unit[self.source].armor_percent = Unit[self.source].armor_percent - self.armor

            self.charges  = math.min(self.charges + i, GetUnitAbilityLevel(self.source, LIGHTSEAL.id) * 10)

            -- recompute bonuses
            self.strength = R2I(GetHeroStr(self.source, true) * 0.01 * self.charges)
            self.armor    = 0.01 * self.charges -- +1% per charge

            -- apply new contribution
            Unit[self.source].bonus_str     = Unit[self.source].bonus_str + self.strength
            Unit[self.source].armor_percent = Unit[self.source].armor_percent + self.armor

            SetWidgetLife(self.source, hp)
            UnitRefreshBuff(self.source, self)

            if not self.timer then
                self.timer = TQ:callDelayed(5., stack_expire, self)
                self:duration(5.05)
            end
        end

        function thistype:onRemove()
            TQ:disableCallback(self.timer)

            Unit[self.source].bonus_str     = Unit[self.source].bonus_str - self.strength
            Unit[self.source].armor_percent = Unit[self.source].armor_percent - self.armor
        end

        function thistype:onApply()
            self.charges = 0
            self.strength = 0
            self.armor = 0
        end
    end

end, Debug and Debug.getLine())
