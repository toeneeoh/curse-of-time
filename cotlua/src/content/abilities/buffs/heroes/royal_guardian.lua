OnInit.final("BuffsHeroesRoyalGuardian", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class FightMeBuff : Buff
    FightMeBuff = Buff.new()
    do
        local thistype = FightMeBuff
        thistype.NAME            = "Fight Me"
        thistype.DESC            = "This unit is immune to damage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNWarCry.blp"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_struck(target, source, amount_ref)
            amount_ref.value = 0.
        end

        function thistype:onRemove()
            EVENT_ON_STRUCK_MULTIPLIER:unregister_unit_action(self.target, on_struck)
        end

        function thistype:onApply()
            EVENT_ON_STRUCK_MULTIPLIER:register_unit_action(self.target, on_struck)
        end
    end

    ---@class FightMeCasterBuff : Buff
    FightMeCasterBuff = Buff.new()
    do
        local thistype = FightMeCasterBuff
        thistype.NAME            = "Fight Me"
        thistype.DESC            = "This unit gives nearby allies damage immunity"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNWarCry.blp"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function aura_target(object, source, player)
            if UnitAlive(object) and IsUnitAlly(object, player) and object ~= source then
                FightMeBuff:add(source, object):duration(2.)
            end
        end

        function thistype:onRemove()
            TQ:disableCallback(self.timer)
            Unit[self.target]:removeEffect(self.sfx)
        end

        local function periodic(self)
            ALICE_EnumObjectsInRange(GetUnitX(self.source), GetUnitY(self.source), 900. * LBOOST[self.pid], "unit", aura_target, self.target, GetOwningPlayer(self.target))

            self.timer = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Orc\\Voodoo\\VoodooAura.mdl", "origin")

            periodic(self)
        end
    end

    ---@class RoyalPlateBuff : Buff
    RoyalPlateBuff = Buff.new()
    do
        local thistype = RoyalPlateBuff
        thistype.NAME            = "Royal Plate"
        thistype.DESC            = "This unit has +$armor armor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArmor Gold.blp"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].bonus_armor = Unit[self.target].bonus_armor - self.armor
        end

        function thistype:onApply()
            self.armor = ROYALPLATE.armor(self.tpid) * BOOST[self.tpid]

            if Unit[self.target].shield_count > 0 then
                self.armor = self.armor * 1.3
            end

            Unit[self.target].bonus_armor = Unit[self.target].bonus_armor + self.armor
        end
    end

    ---@class ProvokeDebuff : Buff
    ProvokeDebuff = Buff.new()
    do
        local thistype = ProvokeDebuff
        thistype.NAME            = "Provoked"
        thistype.DESC            = "This unit deals -^#dm% total damage"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNInnerFire.blp"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dm = Unit[self.target].dm / self.dm
        end

        function thistype:onApply()
            self.dm = 0.75
            Unit[self.target].dm = Unit[self.target].dm * self.dm
        end
    end

    ---@class SteedChargeBuff : Buff
    SteedChargeBuff = Buff.new()
    do
        local thistype = SteedChargeBuff
        thistype.NAME            = "Steed Charge"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSteedCharge.dds"
        thistype.DESC            = "This unit has +$ms movespeed"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            local u = Unit[self.target]

            u.ms_flat = u.ms_flat - self.ms
            u:morph(HERO_ROYAL_GUARDIAN)
        end

        function thistype:onApply()
            local u = Unit[self.target]
            self.ms = 100
            u.ms_flat = u.ms_flat + self.ms

            u:morph(FourCC('H04Y'))
        end
    end

    ---@class ProtectedBuff : Buff
    ProtectedBuff = Buff.new()
    do
        local thistype = ProtectedBuff
        thistype.NAME            = "Protected"
        thistype.ICON            = "ReplaceableTextures\\PassiveButtons\\PASShield.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = (0.93 - 0.02 * self.ablev)

            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

end, Debug and Debug.getLine())
