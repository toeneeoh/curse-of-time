OnInit.final("BuffsHeroesCrusader", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue
    local FPS_32 = FPS_32

    ---@class JusticeAuraBuff : Buff
    JusticeAuraBuff = Buff.new()
    do
        local thistype = JusticeAuraBuff
        thistype.NAME            = "Aura of Justice"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDevotionAura2.blp"
        thistype.DESC            = "This unit has +^#pr% physical resistance"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target].pr = Unit[self.target].pr / self.pr
        end

        function thistype:onApply()
            self.pr = math.max(0.91 - 0.01 * self.ablev, 0.85)

            Unit[self.target].pr = Unit[self.target].pr * self.pr
        end
    end

    ---@class SoulLinkBuff : Buff
    SoulLinkBuff = Buff.new()
    do
        local thistype = SoulLinkBuff
        thistype.NAME            = "Soul Link"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSpiritLink.blp"
        thistype.DESC            = "This unit's health and mana will be restored"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            EVENT_ON_FATAL_DAMAGE:unregister_unit_action(self.target, SOULLINK.onHit)
            FadeSFX(self.sfx, true)
            TQ:callDelayed(1.75, HideEffect, self.sfx)

            HP(self.source, self.target, math.max(0., self.hp - GetWidgetLife(self.target)), SOULLINK.tag)
            if not Unit[self.target].nomanaregen then
                MP(self.target, math.max(0., self.mana - GetUnitState(self.target, UNIT_STATE_MANA)))
            end

            TQ:disableCallback(self.timer)
            self.chain:destroy()

            DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\Items\\AIil\\AIilTarget.mdl", self.target, "origin"))
        end

        local function periodic(self, x, y)
            self.chain:update()

            self.timer = TQ:callDelayed(FPS_32, periodic, self, x, y)
        end

        function thistype:onApply()
            local angle  = math.rad(GetUnitFacing(self.target) - 180) ---@type number
            local x      = GetUnitX(self.target) + 75. * math.cos(angle) ---@type number
            local y      = GetUnitY(self.target) + 75. * math.sin(angle) ---@type number

            EVENT_ON_FATAL_DAMAGE:register_unit_action(self.target, SOULLINK.onHit)
            self.hp = GetWidgetLife(self.target)
            self.mana = GetUnitState(self.target, UNIT_STATE_MANA)

            BlzSetItemSkin(PATH_ITEM, BlzGetUnitSkin(self.target))
            self.sfx = AddSpecialEffect(BlzGetItemStringField(PATH_ITEM, ITEM_SF_MODEL_USED), x, y)
            BlzSetItemSkin(PATH_ITEM, BlzGetUnitSkin(DUMMY_UNIT))

            local chain = Chain.create{
                source = Chain.sfx(self.sfx, 50.),
                target = Chain.unit(self.target, 50.),
                length = 700.,
                segments = 10,
                color = {0.95, 0.90, 0.20, 1.},
                leash = false,
            }

            self.chain = chain

            DestroyEffect(AddSpecialEffect("Abilities\\Spells\\Items\\AIil\\AIilTarget.mdl", x, y))

            BlzSetSpecialEffectYaw(self.sfx, angle + bj_PI)
            BlzSetSpecialEffectColorByPlayer(self.sfx, GetOwningPlayer(self.target))
            BlzSetSpecialEffectColor(self.sfx, 255, 255, 0)
            BlzSetSpecialEffectAlpha(self.sfx, 100)

            periodic(self, x, y)
        end
    end

    ---@class LawOfMightBuff : Buff
    LawOfMightBuff = Buff.new()
    do
        local thistype = LawOfMightBuff
        thistype.NAME            = "Law of Might"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNArcaneMight2.blp"
        thistype.DESC            = "This unit has +$bonus $attr"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

            UnitAddBonus(self.target, self.main + 2, -self.bonus)
        end

        function thistype:onApply()
            self.main = HighestStat(self.target, true)
            self.attr = HighestStatName(self.target, true, true)

            self.bonus = R2I(GetHeroStat(self.main, self.target, true) * LAWOFMIGHT.pbonus(self.pid) * 0.01 * LBOOST[self.pid] + LAWOFMIGHT.fbonus(self.pid) * BOOST[self.pid])
            UnitAddBonus(self.target, self.main + 2, self.bonus)

            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Human\\InnerFire\\InnerFireTarget.mdl", "overhead")
        end
    end

    ---@class LawOfValorBuff : Buff
    LawOfValorBuff = Buff.new()
    do
        local thistype = LawOfValorBuff
        thistype.NAME            = "Law of Valor"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTN_CR_Favor.blp"
        thistype.DESC            = "This unit has +$regen regeneration and +$percent% healing"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        function thistype:onRemove()
            Unit[self.target]:removeEffect(self.sfx)

            Unit[self.target].regen_flat = Unit[self.target].regen_flat - self.regen
            Unit[self.target].regen_percent = Unit[self.target].regen_percent - self.percent * 0.01
        end

        function thistype:onApply()
            self.regen = LAWOFVALOR.regen(self.pid) * BOOST[self.pid]
            self.percent = R2I(LAWOFVALOR.amp(self.pid))

            Unit[self.target].regen_flat = Unit[self.target].regen_flat + self.regen
            Unit[self.target].regen_percent = Unit[self.target].regen_percent + self.percent * 0.01

            self.sfx = Unit[self.target]:addEffect("war3mapImported\\RunicShield.mdx", "chest")
        end
    end

    ---@class LawOfResonanceBuff : Buff
    LawOfResonanceBuff = Buff.new()
    do
        local thistype = LawOfResonanceBuff
        thistype.NAME            = "Law of Resonance"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNDuality.blp"
        thistype.DESC            = "This unit's attacks are echoed for ^$multiplier% damage"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target, amount, amount_after_red, damage_type)
            local self = thistype:get(nil, source)

            if damage_type == PHYSICAL then
                DamageTarget(source, target, amount_after_red * self.multiplier, ATTACK_TYPE_NORMAL, PURE, LAWOFRESONANCE.tag)
            end
        end

        function thistype:onRemove()
            EVENT_ON_HIT_AFTER_REDUCTIONS:unregister_unit_action(self.target, on_hit)
            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            EVENT_ON_HIT_AFTER_REDUCTIONS:register_unit_action(self.target, on_hit)
            self.multiplier = LAWOFRESONANCE.echo(self.pid) * 0.01

            self.sfx = Unit[self.target]:addEffect("Abilities\\Spells\\Other\\Parasite\\ParasiteTarget.mdl", "overhead")
            self.sfx.color = {60, 60, 255}
            self.sfx.timescale = 2.
        end
    end

end, Debug and Debug.getLine())
