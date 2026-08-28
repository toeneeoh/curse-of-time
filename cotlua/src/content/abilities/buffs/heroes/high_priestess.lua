OnInit.final("BuffsHeroesHighPriestess", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class ProtectionBuff : Buff
    ProtectionBuff = Buff.new()
    do
        local thistype = ProtectionBuff
        thistype.NAME            = "Protection"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHolybird.blp"
        thistype.DESC            = "This unit has +^#as% base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_expire(source)
            thistype:dispel(nil, source)
        end

        local function on_extend(source, amount, dur)
            local buff = thistype:get(nil, source)

            buff:duration(math.max(buff:remaining(), dur))
        end

        function thistype:onRemove()
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.as

            EVENT_ON_SHIELD_APPLY:unregister_unit_action(self.target, on_extend)
            EVENT_ON_SHIELD_EXPIRE:unregister_unit_action(self.target, on_expire)
        end

        function thistype:onApply()
            self.as = 1.1
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.as

            EVENT_ON_SHIELD_APPLY:register_unit_action(self.target, on_extend)
            EVENT_ON_SHIELD_EXPIRE:register_unit_action(self.target, on_expire)
        end
    end

    ---@class SanctifiedGroundDebuff : Buff
    SanctifiedGroundDebuff = Buff.new()
    do
        local thistype = SanctifiedGroundDebuff
        thistype.NAME            = "Sanctified Ground"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNHolyShock3.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$regen% healing"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].regen_percent = Unit[self.target].regen_percent + self.regen
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = SANCTIFIEDGROUND.ms * 0.01 * (math.min(1, Unit[self.target].ms_percent))
            self.regen = (IsBoss(self.target) and 0.5) or 1

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            Unit[self.target].regen_percent = Unit[self.target].regen_percent - self.regen
        end
    end

    ---@class DivineLightBuff : Buff
    DivineLightBuff = Buff.new()
    do
        local thistype = DivineLightBuff
        thistype.NAME            = "Divine Light"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDivineLight5.blp"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 25 + 25 * GetUnitAbilityLevel(self.source, DIVINELIGHT.id)

            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

end, Debug and Debug.getLine())
