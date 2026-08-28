OnInit.final("BuffsHeroesThunderblade", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local Unit = Unit
    local TQ = TimerQueue

    ---@class OmnislashBuff : Buff
    OmnislashBuff = Buff.new()
    do
        local thistype = OmnislashBuff
        thistype.NAME            = "Omnislash"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNOmnislash5.blp"
        thistype.DESC            = "This unit has +^#dr% damage resist"
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_NONE

        local function periodic(self, override)
            if self.charges > 0 then
                self.charges = self.charges - 1
                local x, y = GetUnitX(self.target), GetUnitY(self.target)
                MakeGroupInRange(self.pid, self.ug, x, y, 600., Condition(FilterEnemy))

                local target
                if override then
                    target = override
                else
                    target = FirstOfGroup(self.ug)
                end

                if target then
                    local facing = GetUnitFacing(target)
                    SetUnitAnimation(self.target, "Attack Slam")
                    SetUnitXBounded(self.target, GetUnitX(target) + 60. * math.cos(bj_DEGTORAD * (facing - 180.)))
                    SetUnitYBounded(self.target, GetUnitY(target) + 60. * math.sin(bj_DEGTORAD * (facing - 180.)))
                    BlzSetUnitFacingEx(self.target, facing)
                    DamageTarget(self.target, target, self.dmg * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, OMNISLASH.tag)
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Spells\\NightElf\\Blink\\BlinkCaster.mdl", self.target, "chest"))
                    DestroyEffect(AddSpecialEffectTarget("Abilities\\Weapons\\Bolt\\BoltImpact.mdl", target, "chest"))
                else
                    self.charges = 0
                end

                UnitRefreshBuff(self.target, self)

                if self.charges <= 0 then
                    self:remove()
                else
                    self.callback = TQ:callDelayed(0.4, periodic, self)
                end
            end
        end

        function thistype:onRemove()
            Unit[self.target].dr = Unit[self.target].dr / self.dr

            TQ:disableCallback(self.callback)
            DestroyGroup(self.ug)
            reselect(self.target)
            SetUnitVertexColor(self.target, 255, 255, 255, 255)
            SetUnitTimeScale(self.target, 1.)
        end

        function thistype:onApply()
            self.dr = 0.2
            self.ug = CreateGroup()
            Unit[self.target].dr = Unit[self.target].dr * self.dr

            periodic(self, self.override)
        end
    end

    ---@class OverloadBuff : Buff
    OverloadBuff = Buff.new()
    do
        local thistype = OverloadBuff
        thistype.NAME            = "Overload"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNOverloadOn1.blp"
        thistype.DESC            = "This unit has +^#mm% magic damage while draining mana"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_POSITIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            local mana = GetUnitState(self.target, UNIT_STATE_MANA) ---@type number
            local maxmana = BlzGetUnitMaxMana(self.target) * 0.02 ---@type number

            if UnitAlive(self.target) and mana >= maxmana then
                SetUnitState(self.target, UNIT_STATE_MANA, mana - maxmana)
                self.timer = TQ:callDelayed(1., periodic, self)
            else
                self.timer = nil
                self:remove()
            end
        end

        function thistype:onRemove()
            Unit[self.target].mm = Unit[self.target].mm / self.mm
            IssueImmediateOrder(self.target, "unimmolation")
            Unit[self.target]:removeEffect(self.sfx)

            if self.timer then
                TQ:disableCallback(self.timer)
            end
        end

        function thistype:onApply()
            self.sfx = Unit[self.target]:addEffect("war3mapImported\\Windwalk Blue Soul.mdx", "origin")
            self.mm = OVERLOAD.mult(self.pid)
            Unit[self.target].mm = Unit[self.target].mm * self.mm

            self.timer = TQ:callDelayed(1., periodic, self)
        end
    end

end, Debug and Debug.getLine())
