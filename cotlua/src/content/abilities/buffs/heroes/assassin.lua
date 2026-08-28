OnInit.final("BuffsHeroesAssassin", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit

    ---@class MarkedForDeathDebuff : Buff
    MarkedForDeathDebuff = Buff.new()
    do
        local thistype = MarkedForDeathDebuff
        thistype.NAME            = "Marked for Death"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSacrificialSkull.blp"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            local u = Unit[self.target]
            SetUnitPathing(self.target, true)

            u.ms_percent = u.ms_percent + self.ms

            self.sfx.scale = 0
            u:removeEffect(self.sfx)
        end

        function thistype:onApply()
            local u = Unit[self.target]
            SetUnitPathing(self.target, false)

            self.ms = 0.5 * (math.min(1, u.ms_percent))
            self.sfx = u:addEffect("Abilities\\Spells\\Human\\Banish\\BanishTarget.mdl", "chest")

            u.ms_percent = u.ms_percent - self.ms
        end
    end

    ---@class SmokebombBuff : Buff
    SmokebombBuff = Buff.new()
    do
        local thistype = SmokebombBuff
        thistype.NAME            = "Smoke Bomb"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSmokeBomb1.blp"
        thistype.DESC            = "This unit has +$evasion% evasion"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].evasion = Unit[self.target].evasion - self.evasion
        end

        function thistype:onApply()
            if self.source == self.target then
                self.evasion = self.evasion + (9 + GetUnitAbilityLevel(self.source, SMOKEBOMB.id)) * 2
            else
                self.evasion = self.evasion + 9 + GetUnitAbilityLevel(self.source, SMOKEBOMB.id)
            end

            Unit[self.target].evasion = Unit[self.target].evasion + self.evasion
        end
    end

    ---@class SmokebombDebuff : Buff
    SmokebombDebuff = Buff.new()
    do
        local thistype = SmokebombDebuff
        thistype.NAME            = "Smoke Bomb"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSmokeBomb1.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = (0.28 + 0.02 * GetUnitAbilityLevel(self.source, SMOKEBOMB.id)) * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

    ---@class BlinkStrikeBuff : Buff
    BlinkStrikeBuff = Buff.new()
    do
        local thistype = BlinkStrikeBuff
        thistype.NAME            = "Blink Strike"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBlinkStrike1.blp"
        thistype.DESC            = "This unit has +$evasion% evasion"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)
            Unit[self.target].evasion = Unit[self.target].evasion - self.evasion
        end

        function thistype:onApply()
            self.evasion = 30
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Windwalk.mdx", "origin")
            Unit[self.target].evasion = Unit[self.target].evasion + self.evasion
        end
    end

end, Debug and Debug.getLine())
