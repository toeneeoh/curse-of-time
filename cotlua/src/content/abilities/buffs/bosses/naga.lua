OnInit.final("BuffsBossesNaga", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class NagaThorns : Buff
    NagaThorns = Buff.new()
    do
        local thistype = NagaThorns
        thistype.NAME            = "Thorns"
        thistype.ICON            = "ReplaceableTextures\\PassiveButtons\\PASBTNThorns.blp"
        thistype.DESC            = "This unit returns massive damage when attacked"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function onStruck(target, source, damage_type)
            if damage_type == PHYSICAL then
                DamageTarget(target, source, BlzGetUnitMaxHP(source) * 0.4, ATTACK_TYPE_NORMAL, MAGIC)
            end
        end

        function thistype:onRemove()
            EVENT_ON_STRUCK:unregister_unit_action(self.target, onStruck)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Undead\\ThornyShield\\ThornyShieldTargetChestLeft.mdl", "chest")
            EVENT_ON_STRUCK:register_unit_action(self.target, onStruck)

            TQ:callDelayed(2.5, DestroyEffect, AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\ThornsAura\\ThornsAura.mdl", self.target, "origin"))
        end
    end

    ---@class NagaBerserkBuff : Buff
    NagaBerserkBuff = Buff.new()
    do
        local thistype = NagaBerserkBuff
        thistype.NAME            = "Berserk"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNBerserkForTrolls.blp"
        thistype.DESC            = "This unit has +^$as% attack speed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end

        function thistype:onApply()
            self.as = 8
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\BattleRoar\\RoarCaster.mdl", self.target, "chest"))
        end
    end

    ---@class SpiritCallSlow : Buff
    SpiritCallSlow = Buff.new()
    do
        local thistype = SpiritCallSlow
        thistype.NAME            = "Spirit Call"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNWisp.blp"
        thistype.DESC            = "This unit has -^%ms% movespeed"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
        end

        function thistype:onApply()
            self.ms = 0.3 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
        end
    end

end, Debug and Debug.getLine())
