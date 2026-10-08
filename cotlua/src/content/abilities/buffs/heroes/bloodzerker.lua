OnInit.final("BuffsHeroesBloodzerker", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local FPS_32 = FPS_32

    ---@class UndyingRageBuff : Buff
    UndyingRageBuff = Buff.new()
    do
        local thistype = UndyingRageBuff
        thistype.NAME            = "Undying Rage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNtaur.blp"
        thistype.DESC            = "This unit cannot die"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        ---@param dmg number
        function thistype:addRegen(dmg)
            self.totalRegen = MathClamp(self.totalRegen + dmg / BlzGetUnitMaxHP(self.target) * 100., -100., 100)
        end

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)
            DestroyTextTag(self.text)

            if self.totalRegen >= 0 then
                HP(self.target, self.target, BlzGetUnitMaxHP(self.target) * 0.01 * self.totalRegen, UNDYINGRAGE.tag)
            else
                DamageTarget(self.target, self.target, BlzGetUnitMaxHP(self.target) * 0.01 * -self.totalRegen, ATTACK_TYPE_NORMAL, PURE, UNDYINGRAGE.tag)
            end

            Unit[self.target].hidehp = false
            TQ:disableCallback(self.timer)
        end

        local function periodic(self)
            SetTextTagText(self.text, (R2I(self.totalRegen)) .. "%", 0.025)
            local red, green, blue = HealthGradient(self.totalRegen, false)
            SetTextTagColor(self.text, red, green, blue, 255)
            SetTextTagPosUnit(self.text, self.target, -200.)

            --percent
            self:addRegen(Unit[self.target].regen * FPS_32)

            SetWidgetLife(self.target, math.max(10., BlzGetUnitMaxHP(self.target) * 0.0001))
            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end

        function thistype:onApply()
            self.text = CreateTextTag()
            self.totalRegen = 0.
            SetTextTagText(self.text, (R2I(self.totalRegen)) .. "%", 0.025)
            SetTextTagColor(self.text, R2I(Pow(100 - self.totalRegen, 1.1)), R2I(SquareRoot(math.max(0, self.totalRegen) * 500)), 0, 255)

            Unit[self.target].hidehp = true

            self.sfx = Unit[self.target]:addEffect("war3mapImported\\DemonicAdornment.mdx", "head")

            self.timer = TQ:callDelayed(FPS_32, periodic, self)
        end
    end

    ---@class RampageBuff : Buff
    RampageBuff = Buff.new()
    do
        local thistype = RampageBuff
        thistype.NAME            = "Rampage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodRampage5.blp"
        thistype.DESC            = "This unit has +$ms movespeed, +$pen% armor penetration, and is draining health"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            local u = Unit[self.target]
            u.ms_flat = u.ms_flat - self.ms
            u.armor_pen_percent = u.armor_pen_percent - self.pen

            TQ:disableCallback(self.timer)
            u:removeEffect(self.sfx)
        end

        local function periodic(self)
            DamageTarget(self.source, self.source, 0.08 * GetWidgetLife(self.source), ATTACK_TYPE_NORMAL, PURE, "Rampage")
            self.timer = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onApply()
            local u = Unit[self.target]
            self.pen = RAMPAGE.pen(self.tpid)
            self.ms = 100
            u.armor_pen_percent = u.armor_pen_percent + self.pen
            u.ms_flat = u.ms_flat + self.ms

            self.sfx = u:addEffect("war3mapImported\\Windwalk Blood.mdx", "origin")
            periodic(self)
        end
    end

    ---@class BloodFrenzyBuff : Buff
    BloodFrenzyBuff = Buff.new()
    do
        local thistype = BloodFrenzyBuff
        thistype.NAME            = "Blood Frenzy"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBloodFrenzy3.blp"
        thistype.DESC            = "This unit has +^#bat% base attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat * self.bat
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Orc\\Bloodlust\\BloodlustTarget.mdl", "chest")
            self.bat = 1.5

            Unit[self.target].bonus_bat = Unit[self.target].bonus_bat / self.bat
            DamageTarget(self.source, self.source, 0.15 * BlzGetUnitMaxHP(self.source), ATTACK_TYPE_NORMAL, PURE, BLOODFRENZY.tag)
        end
    end

    ---@class BloodCurdlingScreamDebuff : Buff
    BloodCurdlingScreamDebuff = Buff.new()
    do
        local thistype = BloodCurdlingScreamDebuff
        thistype.NAME            = "Blood Curdling Scream"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBlood-CurdlingScream2.blp"
        thistype.DESC            = "This unit has -^$armor% armor"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL
        thistype.armor         = 0

        function thistype:onRemove()
            Unit[self.target].armor_percent = Unit[self.target].armor_percent + self.armor
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.armor = 0.12 + 0.02 * GetUnitAbilityLevel(self.source, FourCC('A06H'))
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Other\\HowlOfTerror\\HowlTarget.mdl", "chest")

            Unit[self.target].armor_percent = Unit[self.target].armor_percent - self.armor
        end
    end

end, Debug and Debug.getLine())
