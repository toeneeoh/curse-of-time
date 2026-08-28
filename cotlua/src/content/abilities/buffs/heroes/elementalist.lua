OnInit.final("BuffsHeroesElementalist", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local atan = math.atan

    ---@class EarthDebuff : Buff
    EarthDebuff = Buff.new()
    do
        local thistype = EarthDebuff
        thistype.NAME            = "Earth"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEarthSphere.blp"
        thistype.DESC            = "This unit has -^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.level = self.level or 1
            self.charges = self.level
            self.dr = (1. + 0.04 * self.level)
            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class FireElementBuff : Buff
    FireElementBuff = Buff.new()
    do
        local thistype = FireElementBuff
        thistype.NAME            = "Fire"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNFireSwirl.blp"
        thistype.DESC            = "This unit has +^$spellboost% spellboost"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            masterElement[self.tpid] = 0
            Unit[self.target]:removeEffect(self.sfx)
            Unit[self.target]:removeEffect(self.sfx2)
            Unit[self.target].spellboost = Unit[self.target].spellboost - self.spellboost
        end

        function thistype:onApply()
            self.spellboost = 0.15
            masterElement[self.tpid] = ELEMENTFIRE.value
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Fire Uber.mdx", "right hand")
            self.sfx2 = Unit[self.target]:addEffect("war3mapImported\\Fire Uber.mdx", "left hand")
            Unit[self.target].spellboost = Unit[self.target].spellboost + self.spellboost
        end
    end

    ---@class IceElementBuff : Buff
    IceElementBuff = Buff.new()
    do
        local thistype = IceElementBuff
        thistype.NAME            = "Ice"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNIceBlast.blp"
        thistype.DESC            = "This unit has +!$regen% max mana regeneration and slows nearby enemies"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            masterElement[self.tpid] = 0
            Unit[self.target].mana_regen_max = Unit[self.target].mana_regen_max - self.regen
            Unit[self.target]:removeEffect(self.sfx)
            Unit[self.target]:removeEffect(self.sfx2)
        end

        function thistype:onApply()
            self.regen = 1.5
            masterElement[self.tpid] = ELEMENTICE.value
            Unit[self.target].mana_regen_max = Unit[self.target].mana_regen_max + self.regen
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Water High.mdx", "right hand")
            self.sfx2 = Unit[self.target]:addEffect("war3mapImported\\Water High.mdx", "left hand")
        end
    end

    ---@class LightningElementBuff : Buff
    LightningElementBuff = Buff.new()
    do
        local thistype = LightningElementBuff
        thistype.NAME            = "Lightning"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNLightningOrb.blp"
        thistype.DESC            = "This unit has +^$ms% movespeed and shocks nearby enemies"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function on_hit(source, target)
            DamageTarget(source, target, GetWidgetLife(target) * 0.005, ATTACK_TYPE_NORMAL, PURE, ELEMENTLIGHTNING.tag)
        end

        local function periodic(self)
            if UnitAlive(self.target) then
                local ug = CreateGroup()
                local x = GetUnitX(self.target)
                local y = GetUnitY(self.target)

                MakeGroupInRange(self.tpid, ug, x, y, 900., Condition(FilterEnemy))

                local target = FirstOfGroup(ug)
                if target then
                    local dummy = Dummy.create(x, y, FourCC('A09W'), 1, 1.)
                    dummy:attack(target, self.target, on_hit)
                end

                DestroyGroup(ug)
            end

            self.timer = TQ:callDelayed(5., periodic, self)
        end

        function thistype:onRemove()
            masterElement[self.tpid] = 0
            Unit[self.target]:removeEffect(self.sfx)
            Unit[self.target]:removeEffect(self.sfx2)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms

            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            masterElement[self.tpid] = ELEMENTLIGHTNING.value
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Storm Cast.mdx", "right hand")
            self.sfx2 = Unit[self.target]:addEffect("war3mapImported\\Storm Cast.mdx", "left hand")
            self.ms = 0.4 * (math.min(1, Unit[self.target].ms_percent))
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms

            self.timer = TQ:callDelayed(5., periodic, self)
        end
    end

    ---@class EarthElementBuff : Buff
    EarthElementBuff = Buff.new()
    do
        local thistype = EarthElementBuff
        thistype.NAME            = "Earth"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNEarthSphere.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        function thistype:onRemove()
            masterElement[self.tpid] = 0
            Unit[self.target]:removeEffect(self.sfx)
            Unit[self.target]:removeEffect(self.sfx2)
            Unit[self.target].dr = Unit[self.target].dr / self.dr
        end

        function thistype:onApply()
            self.dr = 0.75
            masterElement[self.tpid] = ELEMENTEARTH.value
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Earth High.mdx", "right hand")
            self.sfx2 = Unit[self.target]:addEffect("war3mapImported\\Earth High.mdx", "left hand")
            Unit[self.target].dr = Unit[self.target].dr * self.dr
        end
    end

    ---@class GaiaArmorBuff : Buff
    GaiaArmorBuff = Buff.new()
    do
        local thistype = GaiaArmorBuff
        thistype.NAME            = "Gaia Armor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNMantleOfForestDefender.blp"
        thistype.DESC            = "This unit is protected from a fatal blow"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE
        thistype.callback        = {}

        local on_hit

        local function on_cleanup(pid)
            TQ:disableCallback(thistype.callback[pid])
        end

        local function fatal_cooldown(self)
            if GetUnitAbilityLevel(self.target, GAIAARMOR.id) >= 1 then
                thistype:add(self.target, self.target)
                EVENT_ON_FATAL_DAMAGE:register_unit_action(self.target, on_hit)
            end

            EVENT_ON_CLEANUP:unregister_action(self.pid, on_cleanup)
        end

        on_hit = function(target, source, amount, damage_type)
            local buff = thistype:get(nil, target) ---@type Buff

            if buff then
                buff:remove()
                amount.value = 0
                HP(target, target, BlzGetUnitMaxHP(target) * 0.2 * GetUnitAbilityLevel(target, GAIAARMOR.id), GAIAARMOR.tag)
                MP(target, BlzGetUnitMaxMana(target) * 0.2 * GetUnitAbilityLevel(target, GAIAARMOR.id))
                DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Other\\Doom\\DoomDeath.mdl", target, "origin"))

                local x = GetUnitX(target)
                local y = GetUnitY(target)
                local ug = CreateGroup()
                MakeGroupInRange(buff.pid, ug, x, y, 400., Condition(FilterEnemy))

                for u in each(ug) do
                    Stun:add(target, u):duration(4.)

                    local x2 = GetUnitX(u)
                    local y2 = GetUnitY(u)
                    local angle = atan(y2 - y, x2 - x)

                    CAT_Knockback(u, 1200. * math.cos(angle), 1200. * math.sin(angle), 0.)
                    CAT_UnitEnableFriction(u, true)
                    TQ:callDelayed(1., CAT_UnitEnableFriction, u, false)
                end

                DestroyGroup(ug)

                thistype.callback[buff.pid] = TQ:callDelayed(120., fatal_cooldown, buff)
                EVENT_ON_CLEANUP:register_action(buff.pid, on_cleanup)
            end

            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(target, on_hit)
        end

        function thistype:onRemove()
            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(self.target, on_hit)
        end

        function thistype:onApply()
            EVENT_ON_FATAL_DAMAGE:register_unit_action(self.target, on_hit)
        end
    end

    ---@class IceElementDebuff : Buff
    IceElementDebuff = Buff.new()
    do
        local thistype = IceElementDebuff
        thistype.NAME            = "Ice"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNIceBlast.blp"
        thistype.DESC            = "This unit has -^$ms% movespeed and -^$as% attack speed"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, self.as)
            Unit[self.target].ms_percent = Unit[self.target].ms_percent + self.ms
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.as = 0.25
            self.ms = 0.35 * (math.min(1, Unit[self.target].ms_percent))

            Unit[self.target].ms_percent = Unit[self.target].ms_percent - self.ms
            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Other\\FrostDamage\\FrostDamage.mdl", "chest")

            UnitAddBonus(self.target, BONUS_ATTACK_SPEED, - self.as)
        end
    end

end, Debug and Debug.getLine())
