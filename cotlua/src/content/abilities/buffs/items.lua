OnInit.final("BuffsItems", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class EmpyreanSongBuff : Buff
    EmpyreanSongBuff = Buff.new()
    do
        local thistype = EmpyreanSongBuff
        thistype.NAME            = "Empyrean Song"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTribal Drum of War.blp"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 150
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

    ---@class BloodHornBuff : Buff
    BloodHornBuff = Buff.new()
    do
        local thistype = BloodHornBuff
        thistype.NAME            = "Blood Horn"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNUnholyAura.blp"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].ms_flat = Unit[self.target].ms_flat - self.ms
        end

        function thistype:onApply()
            self.ms = 75
            Unit[self.target].ms_flat = Unit[self.target].ms_flat + self.ms
        end
    end

    ---@class ResurgenceBuff : Buff
    ResurgenceBuff = Buff.new()
    do
        local thistype = ResurgenceBuff
        thistype.NAME            = "Resurgence"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDarkShield.blp"
        thistype.DESC            = "This unit has +!$regen% max health regeneration"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            local max_hp = Unit[self.target].hp
            local hp = math.min(5, (((max_hp - GetWidgetLife(self.target)) / max_hp) * 100.) // 15.)

            Unit[self.target].regen_max = Unit[self.target].regen_max - self.regen
            self.regen = self.item.cached_stats[ITEM_ABILITY] * hp
            self.charges = R2I(hp)
            Unit[self.target].regen_max = Unit[self.target].regen_max + self.regen
            self.timer = TQ:callDelayed(0.5, periodic, self)
            UnitRefreshBuff(self.target, self)
        end

        function thistype:onRemove()
            Unit[self.target].regen_max = Unit[self.target].regen_max - (self.regen or 0)
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.regen = 0
            self.hp = 0
            periodic(self)
        end
    end

    ---@class AzazothHammerStomp : Buff
    AzazothHammerStomp = Buff.new()
    do
        local thistype = AzazothHammerStomp
        thistype.NAME            = "Stomp"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNThunderclap.blp"
        thistype.DESC            = "This unit has -^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.35
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Orc\\StasisTrap\\StasisTotemTarget.mdl", "overhead")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end
    end

    ---@class InstillFearDebuff : Buff
    InstillFearDebuff = Buff.new()
    do
        local thistype = InstillFearDebuff
        thistype.NAME            = "Instill Fear"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDagger.blp"
        thistype.DESC            = "This unit takes +^$dm% total damage from the afflicter"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_FULL

        local function onStruck(target, source, amount, amount_after_red, damage_type)
            if thistype:has(source, target) then
                amount.value = amount.value * 1.15
            end
        end

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

            EVENT_ON_STRUCK_MULTIPLIER:unregister_unit_action(self.target, onStruck)
        end

        function thistype:onApply()
            self.dm = 0.15
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\NightElf\\shadowstrike\\shadowstrike.mdl", "overhead")

            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(self.target, onStruck)
        end
    end

    ---@class DarkestOfDarknessBuff : Buff
    DarkestOfDarknessBuff = Buff.new()
    do
        local thistype = DarkestOfDarknessBuff
        thistype.NAME            = "Darkest of Darkness"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEradication.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = 0.7
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\SoulArmor.mdx", "chest")

            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class VampiricPotion : Buff
    VampiricPotion = Buff.new()
    do
        local thistype = VampiricPotion
        thistype.NAME            = "Vampiric Potion"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNPotionOfVampirism.blp"
        thistype.DESC            = "This unit restores +^$leech% of damage dealt as health"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target, amount, amount_after_red)
            HP(source, source, amount_after_red * 0.05, "Vampiric Potion")
            DestroyEffect(AddSpecialEffectTarget("war3mapImported\\VampiricAuraTarget.mdx", source, "chest"))
        end

        function thistype:onRemove()
            EVENT_ON_HIT_AFTER_REDUCTIONS:unregister_unit_action(self.target, on_hit)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.leech = 0.05
            EVENT_ON_HIT_AFTER_REDUCTIONS:register_unit_action(self.target, on_hit)
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Items\\VampiricPotion\\VampPotionCaster.mdl", "origin")
        end
    end

    ---@class IntenseFocusBuff : Buff
    IntenseFocusBuff = Buff.new()
    do
        local thistype = IntenseFocusBuff
        thistype.NAME            = "Intense Focus"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNTrueShot.blp"
        thistype.DESC            = "This unit has +^#mult% total damage"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

       local function periodic(self)
            if UnitAlive(self.target) and
                Unit[self.target].x == GetUnitX(self.target) and
                Unit[self.target].y == GetUnitY(self.target)
            then
                self.charges = math.min(10, self.charges + 1)
                Unit[self.target].dm = Unit[self.target].dm / self.mult
                self.mult = 1. + self.charges * 0.01
                Unit[self.target].dm = Unit[self.target].dm * self.mult
            else
                Unit[self.target].dm = Unit[self.target].dm / self.mult
                self.mult = 1.
                self.charges = 0
            end
            UnitRefreshBuff(self.target, self)
            self.timer = TQ:callDelayed(1, periodic, self)
        end

        function thistype:onRemove()
            Unit[self.target].dm = Unit[self.target].dm / self.mult
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.charges = 0
            self.mult = 1.
            self.timer = TQ:callDelayed(1, periodic, self)
        end
    end

end, Debug and Debug.getLine())
