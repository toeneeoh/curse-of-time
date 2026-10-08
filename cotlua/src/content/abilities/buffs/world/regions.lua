OnInit.final("BuffsWorldRegions", function(Require)
    Require('BuffSystem')
    Require('UnitTable')
    Require('SpellTools')

    local TQ = TimerQueue

    ---@class Lava : Buff
    Lava = Buff.new()
    do
        local thistype = Lava
        thistype.NAME            = "Lava"
        thistype.ICON            = "ReplaceableTextures\\CommandButtons\\BTNLavaSpawn.blp"
        thistype.DESC            = "This unit is burning"
        thistype.AURA            = true
        thistype.DISPEL_TYPE     = BUFF_NEGATIVE
        thistype.STACK_TYPE      = BUFF_STACK_PARTIAL

        local function periodic(self)
            if not IsUnitInRegion(LAVA_REGION, self.target) then
                self:remove()
            else
                local dmg = BlzGetUnitMaxHP(self.target) / 40. + 1000.

                if BlzGetUnitZ(self.target) < 60. then
                    DamageTarget(DUMMY_UNIT, self.target, dmg, ATTACK_TYPE_NORMAL, PURE, "Lava")
                end

                self.timer = TQ:callDelayed(0.5, periodic, self)
            end
        end

        function thistype:onRemove()
            TQ:disableCallback(self.timer)
        end

        function thistype:onApply()
            self.timer = TQ:callDelayed(0.5, periodic, self)
        end
    end

end, Debug and Debug.getLine())
