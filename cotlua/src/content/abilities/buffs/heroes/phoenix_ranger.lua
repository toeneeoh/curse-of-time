OnInit.final("BuffsHeroesPhoenixRanger", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class BurningDebuff : Buff
    BurningDebuff = Buff.new()
    do
        local thistype = BurningDebuff
        thistype.NAME            = "Burning"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNSearingArrows.blp"
        thistype.DESC            = "This unit is afflicted by Searing Arrows"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE
    end

    ---@class IgniteDebuff : Buff
    IgniteDebuff = Buff.new()
    do
        local thistype = IgniteDebuff
        thistype.NAME            = "Ignited"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNWallOfFire.blp"
        thistype.DESC            = "This unit is taking $dmg every second"
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function periodic(self)
            DamageTarget(self.source, self.target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, SEARINGARROWS.tag)

            self.callback = TQ:callDelayed(1., periodic, self)
        end

        function thistype:onRemove()
            TQ:disableCallback(self.callback)

            Unit[self.target]:removeEffect(self.sfx)
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Real Fire2.mdx", "origin")
            self.dmg = SEARINGARROWS.dot(self.pid)

            self.callback = TQ:callDelayed(0.5, periodic, self)
        end
    end

    ---@class FlamingBowBuff : Buff
    FlamingBowBuff = Buff.new()
    do
        local thistype = FlamingBowBuff
        thistype.NAME            = "Flaming Bow"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNInnerFire.blp"
        thistype.DESC            = "This unit has +^$attack% attack damage"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function on_hit(source, target)
            local self = FlamingBowBuff:get(nil, source)
            local increase = 0.01

            if self.attack < self.max then
                local u = Unit[self.target]
                if MULTISHOT.enabled[source] then
                    increase = increase / (1. + GetUnitAbilityLevel(self.target, MULTISHOT.id))
                end

                u.damage_percent = u.damage_percent - self.attack
                self.attack = math.min(self.attack + increase, self.max)
                u.damage_percent = u.damage_percent + self.attack
                UnitRefreshBuff(source, self)
            end
        end

        function thistype:onRemove()
            local u = Unit[self.target]
            EVENT_ON_HIT:unregister_unit_action(self.target, on_hit)
            UnitRemoveAbility(self.target, FourCC('A08B'))
            u:removeEffect(self.sfx)
            u.damage_percent = u.damage_percent - self.attack
        end

        function thistype:onApply()
            local u = Unit[self.target]
            EVENT_ON_HIT:register_unit_action(self.target, on_hit)
            self.attack = 0.5
            self.max = 0.8 + 0.02 * GetUnitAbilityLevel(self.target, FLAMINGBOW.id)

            u.damage_percent = u.damage_percent + self.attack
            self.sfx = u:addEffect("Soul Bow Enchantment Cinder.mdx", "weapon")
            UnitAddAbility(self.target, FourCC('A08B'))
        end
    end

end, Debug and Debug.getLine())
